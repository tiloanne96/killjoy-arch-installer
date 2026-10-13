#!/usr/bin/env bash
# arch-install.sh — instala Arch Linux completo desde el ISO live, con estos dotfiles.
#
# Uso (como root, desde el ISO de Arch con internet):
#   ./arch-install.sh [opciones]
#
# Sin opciones lo pregunta todo. Los valores por defecto (kernel zen, teclado
# US, disco completo…) están en installer/defaults.conf.
#
#   --disk /dev/X          disco donde instalar (si no, se elige de una lista; para
#                          verlos a mano: lsblk -p)
#   --mode whole|dualboot  whole: borra TODO el disco. dualboot: usa solo el
#                          espacio libre y no toca las particiones existentes
#   --fs btrfs|ext4        sistema de archivos de la raíz
#   --desktop NOMBRE       none, bezel, dhruv, docky, lucid o suzuha
#   --dev LISTA            entornos y servicios: go, rust, ruby, node, java, python,
#                          mobile, docker, redis, all o none (por ejemplo go,ruby,docker)
#   --hostname NOMBRE      nombre del equipo
#   --user NOMBRE          usuario con sudo (si no, se pregunta)
#   --password-file FILE   primera línea = contraseña del usuario (si no, se pide)
#   --root lock|password   lock: root bloqueado, se usa sudo (por defecto);
#                          password: root con contraseña propia además de sudo
#   --root-password-file F primera línea = contraseña de root (con --root password)
#   --kernel PAQUETE       linux-zen, linux, linux-lts o linux-hardened
#   --keymap MAPA          teclado (us por defecto)
#   --timezone ZONA        por ejemplo America/Tijuana
#   --confirm-disk /dev/X  confirma el borrado sin preguntar (instalación desatendida)
#   --no-gpu-drivers       no instalar drivers de GPU detectados (mesa/nvidia)
#   --dry-run              hace las preguntas, muestra el resumen y sale sin tocar nada
#   -h, --help             mostrar esta ayuda
#
# Qué hace:
#   1. Detecta si arrancaste en UEFI o en BIOS (MBR), y comprueba internet y herramientas.
#   2. Particiona. UEFI: EFI + raíz (whole), o raíz en el espacio libre reutilizando
#      la EFI existente (dualboot). BIOS: una sola partición raíz con tabla MBR (o GPT con
#      partición bios_grub si el disco pasa de 2 TiB); GRUB va al MBR del disco.
#   3. Formatea (btrfs con subvolúmenes @, @home, @log, @pkg, @snapshots, o ext4) y monta.
#   4. pacstrap del sistema base con el kernel elegido, microcódigo y drivers de GPU.
#   5. Configura idioma, teclado, usuario, zram, GRUB (con os-prober en dualboot)
#      y NetworkManager (installer/chroot-setup.sh).
#   6. Copia estos dotfiles a ~/.dotfiles. La parte pesada (paquetes, Neovim,
#      escritorio) se termina en el primer inicio de sesión
#      (installer/first-login.sh), con el sistema ya arrancado.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MNT=/mnt

# shellcheck source=/dev/null
source "$REPO_DIR/installer/defaults.conf"

DISK=
NEW_HOSTNAME=
USERNAME=
PASSWORD_FILE=
DESKTOP_NAME=
ROOT_MODE=
DEV_LANGS=
DEV_FLAG=0
DEV_NAMES=(go rust ruby node java python mobile docker redis)
ROOT_PASSWORD_FILE=
ROOT_PASSWORD=
MODE_FLAG=0
USER_RE='^[a-z_][a-z0-9_-]{0,30}$'
CONFIRM_DISK=
GPU_DRIVERS=1
DRY_RUN=0
LAPTOP=0
BOOT_MODE=
ESP_PART=
ROOT_PART=
FORMAT_ESP=1
USER_PASSWORD=

# shellcheck source=installer/ui.sh
source "$REPO_DIR/installer/ui.sh"

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

parse_args() {
  while (($# > 0)); do
    case $1 in
      --disk | --mode | --fs | --desktop | --hostname | --user | --password-file | --root | --root-password-file | --dev | --kernel | --keymap | --timezone | --confirm-disk)
        (($# >= 2)) || die "$1 necesita un valor"
        case $1 in
          --disk) DISK=$2 ;;
          --mode)
            INSTALL_MODE=$2
            MODE_FLAG=1
            ;;
          --fs) FILESYSTEM=$2 ;;
          --desktop) DESKTOP_NAME=$2 ;;
          --hostname) NEW_HOSTNAME=$2 ;;
          --user) USERNAME=$2 ;;
          --password-file) PASSWORD_FILE=$2 ;;
          --root) ROOT_MODE=$2 ;;
          --dev)
            DEV_LANGS=$2
            DEV_FLAG=1
            [[ $DEV_LANGS != none ]] || DEV_LANGS=
            ;;
          --root-password-file) ROOT_PASSWORD_FILE=$2 ;;
          --kernel) KERNEL=$2 ;;
          --keymap) KEYMAP=$2 ;;
          --timezone) TIMEZONE=$2 ;;
          --confirm-disk) CONFIRM_DISK=$2 ;;
        esac
        shift
        ;;
      --no-gpu-drivers) GPU_DRIVERS=0 ;;
      --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
    shift
  done
}

# ---------------------------------------------------------------- preguntas

# ask VAR "texto" [defecto]: pregunta solo si VAR está vacía
ask() {
  local var=$1 prompt=$2 def=${3:-} reply
  [[ -z ${!var:-} ]] || return 0
  read -r -p "$PROMPT$prompt${def:+ [$def]}: " reply || die "Falta un valor para: $prompt (usa las opciones de la línea de comandos)"
  printf -v "$var" '%s' "${reply:-$def}"
  [[ -n ${!var} ]] || die "Falta un valor para: $prompt"
}

# Disco del que arrancó el ISO, para no ofrecerlo (vacío si no se detecta)
live_disk() {
  local src parent
  src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null) || return 0
  [[ -n $src ]] || return 0
  parent=$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)
  if [[ -n $parent ]]; then echo "/dev/$parent"; else echo "$src"; fi
}

# El usuario se pide hasta que sea válido: así un error de tecleo no tumba el
# instalador cuando ya contestaste todo lo demás.
ask_username() {
  while [[ -z $USERNAME ]]; do
    read -r -p "${PROMPT}Nombre de usuario (minúsculas, sin espacios): " USERNAME || die "Falta el usuario (usa --user)"
    if ! [[ $USERNAME =~ $USER_RE ]]; then
      warn "No es válido: usa minúsculas, números, - y _, empezando por una letra."
      USERNAME=
    fi
  done
}

# Lista los discos con tamaño, bus, modelo y los sistemas de archivos que
# contienen (un disco con NTFS suele tener Windows), y deja elegir por número.
choose_disk() {
  [[ -z $DISK ]] || return 0
  local live line dev fs hint n def=
  live=$(live_disk)
  local -a disks=()
  heading "Disco"
  echo "${C_DIM}Si el tuyo no sale, mira lsblk -p en otra consola (Alt+F2).${C_RESET}"
  while read -r line; do
    [[ $line =~ NAME=\"([^\"]*)\"\ SIZE=\"([^\"]*)\"\ TRAN=\"([^\"]*)\"\ MODEL=\"([^\"]*)\" ]] || continue
    dev=${BASH_REMATCH[1]}
    [[ $dev == "$live" ]] && continue
    fs=$(lsblk -nro FSTYPE "$dev" 2>/dev/null | sort -u | grep . | tr '\n' ' ' || true)
    hint=
    [[ -z $fs ]] || hint="  [${fs% }]"
    [[ $fs != *ntfs* ]] || hint+="  ← tiene NTFS (¿Windows?)"
    disks+=("$dev")
    printf '  %s%d)%s %-14s %8s  %-6s %s%s%s%s\n' "$C_BRAND" "${#disks[@]}" "$C_RESET" "$dev" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]:--}" "${BASH_REMATCH[4]}" "$C_DIM" "$hint" "$C_RESET"
  done < <(lsblk -dpP -o NAME,SIZE,TRAN,MODEL -e 7,11)
  ((${#disks[@]} > 0)) || die "No encontré ningún disco donde instalar."
  ((${#disks[@]} > 1)) || def=1
  read -r -p "${PROMPT}Disco [1-${#disks[@]}]${def:+ [$def]}: " n || die "Falta el disco (usa --disk)"
  n=${n:-$def}
  if ! [[ $n =~ ^[0-9]+$ ]] || ((n < 1 || n > ${#disks[@]})); then die "Elección no válida: $n"; fi
  DISK=${disks[n - 1]}
}

choose_mode() {
  if ((MODE_FLAG)); then return 0; fi
  local def=1 n=
  [[ $INSTALL_MODE != dualboot ]] || def=2
  heading "Modo de instalación"
  item 1 "Disco completo: borra TODO el disco"
  item 2 "Dual-boot: usa solo el espacio libre y conserva lo que ya hay"
  read -r -p "${PROMPT}Modo [1-2] [$def]: " n || n=
  n=${n:-$def}
  case $n in
    1) INSTALL_MODE=whole ;;
    2) INSTALL_MODE=dualboot ;;
    *) die "Elección no válida: $n" ;;
  esac
}

choose_desktop() {
  [[ -z $DESKTOP_NAME ]] || return 0
  local -a opts=(none)
  local d
  for d in "$REPO_DIR"/desktops/*/install.sh; do
    opts+=("$(basename "$(dirname "$d")")")
  done
  heading "Escritorio"
  local i
  for i in "${!opts[@]}"; do
    item "$((i + 1))" "${opts[i]}"
  done
  echo "${C_DIM}  none = solo terminal con Neovim, Alacritty y Oh My Bash${C_RESET}"
  local n
  read -r -p "${PROMPT}Escritorio [1-${#opts[@]}] [1]: " n || die "Falta el escritorio (usa --desktop)"
  n=${n:-1}
  if ! [[ $n =~ ^[0-9]+$ ]] || ((n < 1 || n > ${#opts[@]})); then die "Elección no válida: $n"; fi
  DESKTOP_NAME=${opts[n - 1]}
}

choose_dev() {
  if ((DEV_FLAG)); then return 0; fi
  local labels=("Go" "Rust" "Ruby" "Node.js" "Java" "Python" "Móvil (Android Studio, Flutter, Kotlin)" "Docker + Compose" "Redis")
  local i reply='' tok
  heading "Entornos de desarrollo y servicios"
  for i in "${!labels[@]}"; do
    item "$((i + 1))" "${labels[i]}"
  done
  echo "${C_DIM}  Varios separados por coma (1,3,4), a = todos, Enter = ninguno${C_RESET}"
  read -r -p "${PROMPT}Entornos [ninguno]: " reply || reply=
  reply=${reply// /,}
  [[ -n $reply ]] || return 0
  if [[ $reply == a || $reply == all ]]; then
    DEV_LANGS=all
    return 0
  fi
  local -a picked=()
  IFS=',' read -r -a toks <<<"$reply"
  for tok in "${toks[@]}"; do
    [[ -n $tok ]] || continue
    if ! [[ $tok =~ ^[0-9]+$ ]] || ((tok < 1 || tok > ${#DEV_NAMES[@]})); then die "Elección no válida: $tok"; fi
    picked+=("${DEV_NAMES[tok - 1]}")
  done
  DEV_LANGS=$(IFS=,; echo "${picked[*]}")
}

choose_root() {
  [[ -z $ROOT_MODE ]] || return 0
  local n=
  heading "Cuenta root"
  item 1 "Bloqueada: se administra con sudo (lo habitual)"
  item 2 "Con contraseña propia, además de sudo"
  read -r -p "${PROMPT}Root [1-2] [1]: " n || n=
  case ${n:-1} in
    1) ROOT_MODE=lock ;;
    2) ROOT_MODE=password ;;
    *) die "Elección no válida: $n" ;;
  esac
}

# read_secret VARIABLE "cuenta" [archivo]: lee una contraseña del archivo o la pide dos veces
read_secret() {
  local var=$1 label=$2 file=${3:-} first again
  if [[ -n $file ]]; then
    [[ -r $file ]] || die "No puedo leer $file"
    IFS= read -r first <"$file" || true
    [[ -n $first ]] || die "La primera línea de $file está vacía"
    printf -v "$var" '%s' "$first"
    return
  fi
  read -r -s -p "${PROMPT}Contraseña de $label: " first || die "Falta la contraseña de $label (usa --password-file / --root-password-file)"
  echo
  read -r -s -p "${PROMPT}Repite la contraseña: " again || die "Falta repetir la contraseña"
  echo
  [[ -n $first ]] || die "La contraseña no puede estar vacía"
  [[ $first == "$again" ]] || die "Las contraseñas no coinciden"
  printf -v "$var" '%s' "$first"
}

read_passwords() {
  read_secret USER_PASSWORD "$USERNAME" "$PASSWORD_FILE"
  if [[ $ROOT_MODE == password ]]; then
    read_secret ROOT_PASSWORD root "$ROOT_PASSWORD_FILE"
  fi
}

# ------------------------------------------------------------ comprobaciones

validate_choices() {
  case $INSTALL_MODE in whole | dualboot) ;; *) die "--mode debe ser whole o dualboot (no $INSTALL_MODE)" ;; esac
  case $FILESYSTEM in btrfs | ext4) ;; *) die "--fs debe ser btrfs o ext4 (no $FILESYSTEM)" ;; esac
  case $KERNEL in linux | linux-zen | linux-lts | linux-hardened) ;; *) die "Kernel no admitido: $KERNEL (linux, linux-zen, linux-lts o linux-hardened)" ;; esac
  [[ $DESKTOP_NAME == none || -f $REPO_DIR/desktops/$DESKTOP_NAME/install.sh ]] ||
    die "Escritorio desconocido: $DESKTOP_NAME"
  [[ -e /usr/share/zoneinfo/$TIMEZONE ]] || die "Zona horaria desconocida: $TIMEZONE"
  if [[ -n $DEV_LANGS && $DEV_LANGS != all ]]; then
    local d
    IFS=',' read -r -a _devs <<<"$DEV_LANGS"
    for d in "${_devs[@]}"; do
      [[ " ${DEV_NAMES[*]} " == *" $d "* ]] || die "Entorno desconocido: $d (${DEV_NAMES[*]}, all o none)"
    done
  fi
  case $ROOT_MODE in lock | password) ;; *) die "--root debe ser lock o password (no $ROOT_MODE)" ;; esac
  [[ $USERNAME =~ $USER_RE ]] || die "Nombre de usuario no válido: $USERNAME (minúsculas, números, - y _)"
  [[ $NEW_HOSTNAME =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || die "Nombre de equipo no válido: $NEW_HOSTNAME"
  [[ -b $DISK ]] || die "$DISK no es un disco"
  [[ $DISK != "$(live_disk)" ]] || die "$DISK es el disco del que arrancó el ISO"
  [[ $(lsblk -dno TYPE "$DISK") == disk ]] || die "$DISK no es un disco completo (¿pusiste una partición?)"
}

# UEFI si el ISO arrancó en UEFI (existe /sys/firmware/efi); si no, BIOS/MBR.
# Para forzar UEFI en una máquina virtual: VirtualBox → Sistema → "Habilitar EFI";
# VMware → Firmware: UEFI; virt-manager → Firmware: UEFI.
detect_boot_mode() {
  if [[ -d /sys/firmware/efi ]]; then BOOT_MODE=uefi; else BOOT_MODE=bios; fi
}

preflight() {
  [[ $EUID -eq 0 ]] || die "Ejecútalo como root desde el ISO de Arch."
  local cmd
  for cmd in sgdisk parted partprobe lsblk findmnt wipefs pacstrap genfstab arch-chroot curl blockdev; do
    command -v "$cmd" >/dev/null || die "Falta el comando $cmd (¿estás en el ISO de Arch?)"
  done
  if [[ $BOOT_MODE == uefi ]]; then
    command -v mkfs.fat >/dev/null || die "Falta mkfs.fat"
  else
    warn "Arrancaste en modo BIOS (no UEFI): se instalará con arranque BIOS/MBR."
  fi
  if [[ $FILESYSTEM == btrfs ]]; then
    command -v mkfs.btrfs >/dev/null || die "Falta mkfs.btrfs"
  else
    command -v mkfs.ext4 >/dev/null || die "Falta mkfs.ext4"
  fi
  curl -fsI --max-time 10 https://archlinux.org >/dev/null 2>&1 ||
    die "Sin internet. En wifi usa iwctl (station wlan0 connect SSID) y repite."
  ! mountpoint -q "$MNT" || die "$MNT ya está montado. Desmóntalo con: umount -R $MNT"
}

# ------------------------------------------------------------ particionado

# part_path DISCO N: /dev/sda -> /dev/sda1, /dev/nvme0n1 -> /dev/nvme0n1p1
part_path() {
  if [[ $1 =~ [0-9]$ ]]; then echo "${1}p$2"; else echo "$1$2"; fi
}

# Números de partición existentes, uno por línea
part_numbers() { sgdisk -p "$1" | awk '$1 ~ /^[0-9]+$/ && $6 ~ /^[0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ { print $1 }'; }

# Primer número de partición libre
free_part_number() {
  local n=1 used
  used=$(part_numbers "$1")
  while grep -qx "$n" <<<"$used"; do n=$((n + 1)); done
  echo "$n"
}

MBR_LIMIT=2199023255552 # 2 TiB: lo máximo que direcciona una tabla MBR

partition_whole() {
  info "Particionando $DISK (se borra todo)"
  wipefs -af "$DISK" >/dev/null
  sgdisk --zap-all "$DISK" >/dev/null
  FORMAT_ESP=0
  ESP_PART=
  if [[ $BOOT_MODE == uefi ]]; then
    sgdisk -n "1:0:+${ESP_SIZE_MIB}M" -t 1:ef00 -c 1:EFI "$DISK" >/dev/null
    sgdisk -n 2:0:0 -t 2:8300 -c 2:archroot "$DISK" >/dev/null
    ESP_PART=$(part_path "$DISK" 1)
    ROOT_PART=$(part_path "$DISK" 2)
    FORMAT_ESP=1
  elif (($(blockdev --getsize64 "$DISK") > MBR_LIMIT)); then
    # BIOS con un disco de más de 2 TiB: GPT y una partición bios_grub para GRUB
    sgdisk -n 1:0:+1M -t 1:ef02 -c 1:biosgrub "$DISK" >/dev/null
    sgdisk -n 2:0:0 -t 2:8300 -c 2:archroot "$DISK" >/dev/null
    ROOT_PART=$(part_path "$DISK" 2)
  else
    # BIOS: MBR clásico con una sola partición raíz marcada como de arranque
    parted -s "$DISK" mklabel msdos mkpart primary 1MiB 100% set 1 boot on
    ROOT_PART=$(part_path "$DISK" 1)
  fi
}

# Tamaño (MiB) del mayor bloque de espacio libre del disco
largest_free_mib() {
  parted -m -s "$1" unit MiB print free 2>/dev/null |
    awk -F: '$5 ~ /^free/ { gsub(/[^0-9.]/, "", $4); if ($4 + 0 > max) max = $4 + 0 } END { printf "%d\n", max }'
}

# Números de partición de una tabla (GPT o MBR), uno por línea
parted_numbers() { parted -m -s "$1" print 2>/dev/null | awk -F: '$1 ~ /^[0-9]+$/ { print $1 }'; }

# Dual-boot con tabla MBR (BIOS): la raíz va en el mayor espacio libre como
# partición primaria. GRUB sustituye el código de arranque del MBR y luego
# os-prober añade el otro sistema al menú.
partition_dualboot_mbr() {
  local start end before after n
  read -r start end < <(parted -m -s "$DISK" unit MiB print free 2>/dev/null |
    awk -F: '$5 ~ /^free/ { gsub(/MiB/, "", $2); gsub(/MiB/, "", $3); sz = $4; gsub(/[^0-9.]/, "", sz)
      if (sz + 0 > max) { max = sz + 0; s = $2 + 0; e = $3 + 0 } }
      # parted toma el final como último MiB incluido, de ahí el e - 1
      END { s = (s == int(s)) ? s : int(s) + 1; if (s < 1) s = 1; printf "%d %d\n", s, e - 1 }')
  before=$(parted_numbers "$DISK")
  info "Creo la raíz como partición primaria entre ${start} MiB y ${end} MiB"
  parted -s "$DISK" mkpart primary "${start}MiB" "${end}MiB" ||
    die "parted no pudo crear la partición (¿ya hay 4 primarias, o el espacio libre está dentro de una partición extendida?)"
  after=$(parted_numbers "$DISK")
  n=$(comm -13 <(sort <<<"$before") <(sort <<<"$after") | head -n1)
  [[ -n $n ]] || die "No encontré la partición recién creada en $DISK"
  ROOT_PART=$(part_path "$DISK" "$n")
  FORMAT_ESP=0
  ESP_PART=
  warn "GRUB reemplazará el código de arranque del MBR de $DISK; os-prober añadirá el otro sistema al menú."
}

partition_dualboot() {
  local pttype free_mib esp_num root_num
  pttype=$(blkid -p -o value -s PTTYPE "$DISK" 2>/dev/null || true)
  if [[ $BOOT_MODE == uefi ]]; then
    [[ $pttype == gpt ]] || die "$DISK no tiene tabla GPT; en UEFI el modo dualboot solo admite GPT."
  else
    [[ $pttype == gpt || $pttype == dos ]] || die "$DISK no tiene tabla de particiones GPT ni MBR."
  fi
  free_mib=$(largest_free_mib "$DISK")
  info "Mayor bloque de espacio libre en $DISK: $((free_mib / 1024)) GiB"
  ((free_mib >= MIN_ROOT_GIB * 1024)) ||
    die "No hay $MIN_ROOT_GIB GiB libres seguidos en $DISK. Reduce una partición desde el otro sistema (Windows: Administración de discos) y repite."

  if [[ $pttype == dos ]]; then
    partition_dualboot_mbr
    return
  fi

  if [[ $BOOT_MODE == uefi ]]; then
    esp_num=$(sgdisk -p "$DISK" | awk '$6 == "EF00" { print $1; exit }')
    if [[ -n $esp_num ]]; then
      ESP_PART=$(part_path "$DISK" "$esp_num")
      [[ $(blkid -o value -s TYPE "$ESP_PART" 2>/dev/null || true) == vfat ]] ||
        die "La partición EFI $ESP_PART no es FAT32; no la toco."
      FORMAT_ESP=0
      ok "Reutilizo la partición EFI existente: $ESP_PART (no se formatea)"
    else
      info "No hay partición EFI; creo una de ${ESP_SIZE_MIB} MiB"
      esp_num=$(free_part_number "$DISK")
      sgdisk -n "$esp_num:0:+${ESP_SIZE_MIB}M" "$DISK" >/dev/null
      sgdisk -t "$esp_num:ef00" "$DISK" >/dev/null
      sgdisk -c "$esp_num:EFI" "$DISK" >/dev/null
      ESP_PART=$(part_path "$DISK" "$esp_num")
      FORMAT_ESP=1
    fi
  else
    # BIOS con GPT: GRUB necesita una partición bios_grub (tipo EF02) donde incrustarse
    ESP_PART=
    FORMAT_ESP=0
    if [[ -n $(sgdisk -p "$DISK" | awk '$6 == "EF02" { print $1; exit }') ]]; then
      ok "Ya existe una partición bios_grub; la reutilizo"
    else
      info "Creo una partición bios_grub de 1 MiB para GRUB"
      esp_num=$(free_part_number "$DISK")
      sgdisk -n "$esp_num:0:+1M" "$DISK" >/dev/null
      sgdisk -t "$esp_num:ef02" "$DISK" >/dev/null
      sgdisk -c "$esp_num:biosgrub" "$DISK" >/dev/null
    fi
  fi

  root_num=$(free_part_number "$DISK")
  info "Creo la raíz en el mayor espacio libre (partición $root_num)"
  sgdisk --largest-new="$root_num" "$DISK" >/dev/null
  sgdisk -t "$root_num:8300" "$DISK" >/dev/null
  sgdisk -c "$root_num:archroot" "$DISK" >/dev/null
  ROOT_PART=$(part_path "$DISK" "$root_num")
}

partition_disk() {
  case $INSTALL_MODE in
    whole) partition_whole ;;
    dualboot) partition_dualboot ;;
  esac
  partprobe "$DISK" || true
  udevadm settle 2>/dev/null || true
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -b $ROOT_PART && ( -z $ESP_PART || -b $ESP_PART ) ]] && return 0
    sleep 1
  done
  die "El kernel no creó ${ROOT_PART} ${ESP_PART} tras particionar."
}

# ------------------------------------------------------- formato y montaje

format_and_mount() {
  info "Formateando y montando"
  if ((FORMAT_ESP)) && [[ -n $ESP_PART ]]; then
    mkfs.fat -F 32 -n EFI "$ESP_PART" >/dev/null
  fi

  if [[ $FILESYSTEM == btrfs ]]; then
    local mopts=noatime,compress=zstd:1,space_cache=v2
    mkfs.btrfs -f -L archroot "$ROOT_PART" >/dev/null
    mount "$ROOT_PART" "$MNT"
    local sv
    for sv in @ @home @log @pkg @snapshots; do
      btrfs subvolume create "$MNT/$sv" >/dev/null
    done
    umount "$MNT"
    mount -o "$mopts,subvol=@" "$ROOT_PART" "$MNT"
    mkdir -p "$MNT/home" "$MNT/var/log" "$MNT/var/cache/pacman/pkg" "$MNT/.snapshots"
    mount -o "$mopts,subvol=@home" "$ROOT_PART" "$MNT/home"
    mount -o "$mopts,subvol=@log" "$ROOT_PART" "$MNT/var/log"
    mount -o "$mopts,subvol=@pkg" "$ROOT_PART" "$MNT/var/cache/pacman/pkg"
    mount -o "$mopts,subvol=@snapshots" "$ROOT_PART" "$MNT/.snapshots"
  else
    mkfs.ext4 -F -L archroot "$ROOT_PART" >/dev/null
    mount "$ROOT_PART" "$MNT"
  fi

  # La EFI va en /efi y los kernels en /boot (dentro de la raíz): así una EFI
  # pequeña, como la de Windows, no se llena con kernels e initramfs.
  if [[ $BOOT_MODE == uefi ]]; then
    mkdir -p "$MNT/efi"
    mount "$ESP_PART" "$MNT/efi"
    ok "Raíz ($FILESYSTEM) en $ROOT_PART, EFI en $ESP_PART"
  else
    ok "Raíz ($FILESYSTEM) en $ROOT_PART (arranque BIOS: sin partición EFI)"
  fi
}

# ------------------------------------------------------------------ sistema

detect_hardware() {
  UCODE=
  if grep -q GenuineIntel /proc/cpuinfo; then
    UCODE=intel-ucode
  elif grep -q AuthenticAMD /proc/cpuinfo; then
    UCODE=amd-ucode
  fi

  GPU_PKGS=()
  if ((GPU_DRIVERS)) && command -v lspci >/dev/null; then
    local gpus
    gpus=$(lspci -nn | grep -Ei 'vga|3d controller|display controller' || true)
    grep -qi 'intel' <<<"$gpus" && GPU_PKGS+=(mesa vulkan-intel)
    grep -Eqi 'amd|ati|radeon' <<<"$gpus" && GPU_PKGS+=(mesa vulkan-radeon)
    if grep -qi 'nvidia' <<<"$gpus"; then
      GPU_PKGS+=(nvidia-open-dkms nvidia-utils)
      warn "GPU NVIDIA detectada: instalo nvidia-open-dkms (solo para tarjetas Turing/RTX 20 o más nuevas)."
      warn "Con una tarjeta anterior usa --no-gpu-drivers y elige el driver a mano."
    fi
    if ((${#GPU_PKGS[@]} == 0)); then
      GPU_PKGS+=(mesa)
    fi
  fi

  if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
    LAPTOP=1
  fi

  # Herramientas de invitado si esto es una máquina virtual: ajustan la resolución
  # al tamaño de la ventana y comparten el portapapeles
  GUEST_PKGS=()
  GUEST_SERVICES=
  case $(systemd-detect-virt 2>/dev/null || true) in
    oracle)
      GUEST_PKGS=(virtualbox-guest-utils)
      GUEST_SERVICES="vboxservice.service"
      ;;
    vmware)
      GUEST_PKGS=(open-vm-tools)
      GUEST_SERVICES="vmtoolsd.service vmware-vmblock-fuse.service"
      ;;
    kvm | qemu)
      GUEST_PKGS=(qemu-guest-agent spice-vdagent)
      GUEST_SERVICES="qemu-guest-agent.service"
      ;;
  esac
  if ((${#GUEST_PKGS[@]})); then
    info "Máquina virtual detectada: añado ${GUEST_PKGS[*]}"
  fi
}

install_base() {
  info "Instalando el sistema base (pacstrap)"
  local pkgs=(
    base base-devel "$KERNEL" "${KERNEL}-headers" linux-firmware
    grub os-prober networkmanager sudo
    git neovim man-db man-pages bash-completion zram-generator
    pipewire pipewire-alsa pipewire-pulse wireplumber
  )
  [[ $BOOT_MODE != uefi ]] || pkgs+=(efibootmgr)
  [[ -z $UCODE ]] || pkgs+=("$UCODE")
  [[ $FILESYSTEM != btrfs ]] || pkgs+=(btrfs-progs)
  [[ $INSTALL_MODE != dualboot ]] || pkgs+=(ntfs-3g)
  [[ $DESKTOP_NAME == none ]] || pkgs+=(greetd greetd-tuigreet)
  pkgs+=("${GPU_PKGS[@]}" "${GUEST_PKGS[@]}")

  pacstrap -K "$MNT" "${pkgs[@]}"
  genfstab -U "$MNT" >>"$MNT/etc/fstab"
  ok "Sistema base instalado"
}

copy_dotfiles() {
  info "Copiando los dotfiles a ~/.dotfiles"
  mkdir -p "$MNT/home/$USERNAME/.dotfiles"
  cp -a "$REPO_DIR/." "$MNT/home/$USERNAME/.dotfiles/"
  # Si el repo pasó por un medio sin permisos (FAT, Windows, zip sin modos), se restauran
  find "$MNT/home/$USERNAME/.dotfiles" -type f \( -name '*.sh' -o -path '*/bin/*' \) -exec chmod +x {} +
  arch-chroot "$MNT" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.dotfiles"
}

# Argumentos que usará install.sh en el primer inicio de sesión
pending_args() {
  local args=(--yes)
  [[ $DESKTOP_NAME == none ]] || args+=(--desktop "$DESKTOP_NAME")
  [[ -z $DEV_LANGS ]] || args+=(--dev "$DEV_LANGS")
  ((LAPTOP)) && args+=(--laptop)
  echo "${args[*]}"
}

configure_system() {
  info "Configurando el sistema"
  install -m 755 "$REPO_DIR/installer/chroot-setup.sh" "$MNT/root/chroot-setup.sh"
  install -m 644 "$REPO_DIR/installer/ui.sh" "$MNT/root/ui.sh"
  arch-chroot "$MNT" env \
    KERNEL="$KERNEL" KEYMAP="$KEYMAP" TIMEZONE="$TIMEZONE" LOCALE="$LOCALE" \
    EXTRA_LOCALES="$EXTRA_LOCALES" NEW_HOSTNAME="$NEW_HOSTNAME" USERNAME="$USERNAME" \
    INSTALL_MODE="$INSTALL_MODE" FILESYSTEM="$FILESYSTEM" DESKTOP_NAME="$DESKTOP_NAME" \
    BOOT_MODE="$BOOT_MODE" GRUB_DISK="$DISK" GUEST_SERVICES="$GUEST_SERVICES" \
    PENDING_ARGS="$(pending_args)" ROOT_LOCK="$([[ $ROOT_MODE == lock ]] && echo 1 || echo 0)" \
    /root/chroot-setup.sh
  rm -f "$MNT/root/chroot-setup.sh" "$MNT/root/ui.sh"
  # Después de crear el usuario: useradd -m no copia /etc/skel si el home ya existe
  copy_dotfiles
  # La contraseña va por stdin: no queda en variables de entorno ni en `ps`
  printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | arch-chroot "$MNT" chpasswd
  if [[ $ROOT_MODE == password ]]; then
    printf 'root:%s\n' "$ROOT_PASSWORD" | arch-chroot "$MNT" chpasswd
  fi
  ok "Sistema configurado"
}

# --------------------------------------------------------------- resumen

summary() {
  local root_txt="con contraseña"
  [[ $ROOT_MODE != lock ]] || root_txt="bloqueado, se usa sudo"
  heading "Resumen de la instalación"
  printf '  %s%s%s %s (%s)  ·  Arranque: %s\n' "$C_DIM" "Disco        " "$C_RESET" "$DISK" "$INSTALL_MODE" "${BOOT_MODE^^}"
  printf '  %s%s%s %s  ·  Kernel: %s  ·  Teclado: %s\n' "$C_DIM" "Raíz         " "$C_RESET" "$FILESYSTEM" "$KERNEL" "$KEYMAP"
  printf '  %s%s%s %s  ·  Usuario: %s (con sudo)\n' "$C_DIM" "Equipo       " "$C_RESET" "$NEW_HOSTNAME" "$USERNAME"
  printf '  %s%s%s %s\n' "$C_DIM" "Root         " "$C_RESET" "$root_txt"
  printf '  %s%s%s %s  ·  Idioma: %s\n' "$C_DIM" "Zona horaria " "$C_RESET" "$TIMEZONE" "$LOCALE"
  printf '  %s%s%s %s\n' "$C_DIM" "Escritorio   " "$C_RESET" "$DESKTOP_NAME"
  printf '  %s%s%s %s\n' "$C_DIM" "Desarrollo   " "$C_RESET" "${DEV_LANGS:-ninguno}"
  if [[ $INSTALL_MODE == whole ]]; then
    printf '\n%sSe BORRARÁ TODO el contenido de %s:%s\n' "$C_ERR" "$DISK" "$C_RESET"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
  else
    printf '\nSolo se usa el espacio libre de %s; las particiones existentes no se tocan.\n' "$DISK"
    lsblk -o NAME,SIZE,FSTYPE,LABEL "$DISK"
  fi
  echo
}

confirm() {
  if [[ -n $CONFIRM_DISK ]]; then
    [[ $CONFIRM_DISK == "$DISK" ]] || die "--confirm-disk ($CONFIRM_DISK) no coincide con el disco ($DISK)"
    return
  fi
  local reply
  if [[ $INSTALL_MODE == whole ]]; then
    read -r -p "${PROMPT}Para continuar escribe la ruta del disco, tal como sale arriba ($DISK): " reply || die "Sin confirmación"
    [[ $reply == "$DISK" ]] || die "Cancelado."
  else
    read -r -p "${PROMPT}¿Continuar? [s/N]: " reply || die "Sin confirmación"
    [[ $reply == s || $reply == S ]] || die "Cancelado."
  fi
}

# Portada: KILLJOY INSTALLER en letras de bloque (el arte está escrito aquí, no se
# genera al ejecutar). Según el ancho de la terminal va en una línea, en dos o, si no
# cabe, como texto simple. Los anchos están fijos y las líneas ya van rellenas:
# ${#var} y printf '%-*s' cuentan bytes, no columnas, cuando el locale no es UTF-8
# (es lo normal en el ISO).
banner() {
  [[ -t 1 && ${TERM:-dumb} != dumb ]] || return 0
  local cols=${COLUMNS:-}
  [[ -n $cols ]] || cols=$(tput cols 2>/dev/null || echo 80)
  local -a killjoy=(
    '██╗  ██╗██╗██╗     ██╗          ██╗ ██████╗ ██╗   ██╗'
    '██║ ██╔╝██║██║     ██║          ██║██╔═══██╗╚██╗ ██╔╝'
    '█████╔╝ ██║██║     ██║          ██║██║   ██║ ╚████╔╝ '
    '██╔═██╗ ██║██║     ██║     ██   ██║██║   ██║  ╚██╔╝  '
    '██║  ██╗██║███████╗███████╗╚█████╔╝╚██████╔╝   ██║   '
    '╚═╝  ╚═╝╚═╝╚══════╝╚══════╝ ╚════╝  ╚═════╝    ╚═╝   '
  )
  local -a installer=(
    '██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ '
    '██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗'
    '██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝'
    '██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗'
    '██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║'
    '╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝'
  )
  local kw=53 iw=70
  local -a block=()
  local width n
  if ((cols < iw + 2)); then
    printf '\n  %sKILLJOY INSTALLER%s\n\n' "$C_BRAND" "$C_RESET"
    return 0
  fi
  if ((cols >= kw + iw + 8)); then
    # Todo en una línea
    width=$((kw + iw + 3))
    for n in "${!killjoy[@]}"; do
      block+=("${killjoy[n]}   ${installer[n]}")
    done
  else
    # KILLJOY encima, centrada sobre INSTALLER
    width=$iw
    for n in "${!killjoy[@]}"; do
      block+=("$(printf '%*s' $(((iw - kw) / 2)) '')${killjoy[n]}")
    done
    block+=("")
    block+=("${installer[@]}")
  fi
  local pad=$(((cols - width) / 2)) line
  printf '\033[H\033[2J\n'
  for line in "${block[@]}"; do
    printf '%*s%s%s%s\n' "$pad" '' "$C_BRAND" "$line" "$C_RESET"
  done
  printf '\n'
}

main() {
  parse_args "$@"
  detect_boot_mode
  banner
  ((DRY_RUN)) || preflight
  ask_username
  ask NEW_HOSTNAME "Nombre del equipo" "$DEFAULT_HOSTNAME"
  choose_disk
  choose_mode
  choose_desktop
  choose_dev
  choose_root
  validate_choices
  summary
  if ((DRY_RUN)); then
    ok "--dry-run: no se modificó nada."
    exit 0
  fi
  read_passwords
  confirm

  timedatectl set-ntp true || warn "No se pudo activar la sincronización de hora"
  detect_hardware
  partition_disk
  format_and_mount
  install_base
  configure_system

  sync
  umount -R "$MNT"
  cat <<EOF

Instalación terminada. Siguientes pasos:
  1. Quita el USB y reinicia:  reboot
  2. Inicia sesión como $USERNAME en la consola. Se terminará la instalación
     (paquetes, Neovim, Oh My Bash${DESKTOP_NAME:+ y escritorio $DESKTOP_NAME}); necesita internet:
     por cable funciona solo; con wifi usa nmtui cuando te lo pida.
  3. Si falla algo, se repite al volver a iniciar sesión, o a mano con
     ~/.dotfiles/installer/first-login.sh
EOF
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
