#!/usr/bin/env bash
# chroot-setup.sh — configura el sistema recién instalado. Lo ejecuta
# arch-install.sh dentro de arch-chroot; no está pensado para usarse a mano.
#
# Variables esperadas: KERNEL KEYMAP TIMEZONE LOCALE EXTRA_LOCALES NEW_HOSTNAME
# USERNAME INSTALL_MODE FILESYSTEM DESKTOP_NAME ROOT_LOCK (1 = bloquear root)
# BOOT_MODE (uefi o bios) GRUB_DISK (disco donde va GRUB en BIOS) PENDING_ARGS
set -euo pipefail

# shellcheck source=installer/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

for v in KERNEL KEYMAP TIMEZONE LOCALE NEW_HOSTNAME USERNAME INSTALL_MODE FILESYSTEM DESKTOP_NAME ROOT_LOCK BOOT_MODE GRUB_DISK; do
  [[ -n ${!v:-} ]] || {
    echo "Falta la variable $v" >&2
    exit 1
  }
done
EXTRA_LOCALES=${EXTRA_LOCALES:-}
PENDING_ARGS=${PENDING_ARGS:-}
GUEST_SERVICES=${GUEST_SERVICES:-}

info "Zona horaria y reloj"
[[ -e /usr/share/zoneinfo/$TIMEZONE ]] || {
  echo "Zona horaria desconocida: $TIMEZONE" >&2
  exit 1
}
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc || warn "No se pudo ajustar el reloj de hardware (normal en algunas máquinas virtuales)"

info "Idioma y teclado"
for loc in $LOCALE $EXTRA_LOCALES; do
  # Descomenta la línea "<locale> <charset>" de /etc/locale.gen
  sed -i "s/^#\(${loc//./\\.} .*\)$/\1/" /etc/locale.gen
  grep -q "^${loc//./\\.} " /etc/locale.gen || warn "El locale $loc no existe en /etc/locale.gen"
done
locale-gen
echo "LANG=$LOCALE" >/etc/locale.conf
echo "KEYMAP=$KEYMAP" >/etc/vconsole.conf
# Distribución para Wayland/X11: sin esto `localectl` dice «(unset)» y los escritorios
# (Hyprland) se quejan de «Invalid keyboard layout». Del nombre de la consola se saca el de X.
case $KEYMAP in
  la-latin1) X_LAYOUT=latam ;;
  uk) X_LAYOUT=gb ;;
  *) X_LAYOUT=${KEYMAP%%-*} ;;
esac
install -d /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/00-keyboard.conf <<XKB
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$X_LAYOUT"
EndSection
XKB

info "Nombre del equipo"
echo "$NEW_HOSTNAME" >/etc/hostname
cat >/etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $NEW_HOSTNAME.localdomain $NEW_HOSTNAME
HOSTS

info "pacman: colores y descargas en paralelo"
sed -i -e 's/^#Color$/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

info "Usuario $USERNAME"
useradd -m -G wheel -s /bin/bash "$USERNAME"
install -d -m 750 /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel >/dev/null
# Con ROOT_LOCK=1 root queda bloqueado y se administra con sudo; si no,
# arch-install.sh le pone contraseña después
if [[ $ROOT_LOCK == 1 ]]; then
  passwd -l root >/dev/null
fi

info "zram en lugar de swap en disco"
cat >/etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
ZRAM

info "Servicios"
systemctl enable NetworkManager.service systemd-timesyncd.service fstrim.timer
# Servicios de las herramientas de máquina virtual (si arch-install.sh las instaló)
for unit in ${GUEST_SERVICES:-}; do
  systemctl enable "$unit" || warn "No se pudo activar $unit"
done

info "Gestor de arranque (GRUB)"
if [[ $INSTALL_MODE == dualboot ]]; then
  # Sin esto GRUB no añade Windows ni otros sistemas al menú
  if grep -q '^#\?GRUB_DISABLE_OS_PROBER' /etc/default/grub; then
    sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  else
    echo 'GRUB_DISABLE_OS_PROBER=false' >>/etc/default/grub
  fi
fi
if [[ $BOOT_MODE == uefi ]]; then
  # Nunca --removable: pisaría BOOTX64.EFI, que puede ser el de Windows
  grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch --recheck
else
  # BIOS: GRUB va al disco entero (MBR o hueco de incrustación), no a una partición
  grub-install --target=i386-pc --recheck "$GRUB_DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg
if [[ $INSTALL_MODE == dualboot ]] && ! grep -qi 'windows' /boot/grub/grub.cfg; then
  warn "GRUB no detectó otro sistema en este momento. Tras el primer arranque ejecuta:"
  warn "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
fi

if [[ $DESKTOP_NAME != none ]]; then
  info "Pantalla de inicio de sesión (greetd + tuigreet)"
  cat >/etc/greetd/config.toml <<'GREETD'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --asterisks --remember --remember-session --sessions /usr/share/wayland-sessions"
user = "greeter"
GREETD
  # Se activa al terminar la instalación del escritorio (installer/first-login.sh);
  # si esa instalación falla, el equipo sigue arrancando en la consola.
fi

info "Instalación pendiente del primer inicio de sesión"
home="/home/$USERNAME"
install -d -o "$USERNAME" -g "$USERNAME" "$home/.local/state/dotfiles"
printf '%s\n' "$PENDING_ARGS" >"$home/.local/state/dotfiles/pending-install"
cat >>"$home/.bash_profile" <<'HOOK'

# arch-install.sh: termina la instalación (paquetes, dotfiles y escritorio) en el
# primer inicio de sesión en una consola. Se repite hasta que termine bien.
if [[ -f ~/.local/state/dotfiles/pending-install && -t 0 && $(tty) == /dev/tty* ]]; then
  bash ~/.dotfiles/installer/first-login.sh
fi
HOOK
chown -R "$USERNAME:$USERNAME" "$home/.local" "$home/.bash_profile"
echo "Configuración del sistema lista"
