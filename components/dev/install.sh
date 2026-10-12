#!/usr/bin/env bash
# components/dev/install.sh — instala entornos de desarrollo por lenguaje, más Docker y Redis.
#
# Uso: components/dev/install.sh --lang LISTA [opciones]
#   --lang LISTA   separados por comas: go, rust, ruby, node, java, python, mobile,
#                  docker (con compose y buildx), redis, o all (todos)
#   --list         mostrar qué instala cada uno y salir
#   -y, --yes      no pedir confirmación a pacman ni al instalar el ayudante del AUR
#   -h, --help     mostrar esta ayuda
#
# Qué hace:
#   1. Instala los paquetes de cada lenguaje con pacman (y mise, para fijar
#      versiones por proyecto; .bashrc ya lo activa).
#   2. Los paquetes que no están en los repositorios oficiales (Android Studio,
#      Flutter) salen del AUR con yay o paru. Si no hay ninguno, ofrece instalar
#      yay-bin; en el AUR cualquiera puede publicar, así que revisa el PKGBUILD
#      que te enseña makepkg antes de aceptar.
#   3. Deja cada toolchain usable sin sudo: rustup con la versión estable,
#      npm con prefijo en ~/.local, gems en el directorio del usuario, Java con
#      archlinux-java.
#   4. docker y redis: activa el servicio (enable --now). Docker además añade a tu
#      usuario al grupo docker, que equivale a tener root en la máquina: quien
#      pertenece a él puede montar / en un contenedor. Si no lo quieres, quita
#      al usuario del grupo (sudo gpasswd -d $USER docker) y usa sudo docker.
#      Si redis no está en los repositorios instala valkey, que es compatible.
#
# Neovim instala solo los servidores LSP de Go, Rust y Ruby en el siguiente
# arranque cuando encuentra el toolchain (ver README).

set -euo pipefail

ASSUME_YES=0
LANGS=()
SKIPPED=() # paquetes que no se pudieron instalar
DOCKER_RELOGIN=0

# Paquetes oficiales y del AUR por lenguaje. Los nombres no se pudieron
# comprobar contra los repositorios desde mi entorno de pruebas: el script
# consulta `pacman -Si` y avisa de los que no existan en vez de fallar.
declare -A PKGS=(
  [go]="go"
  [rust]="rustup"
  [ruby]="ruby ruby-bundler libyaml"
  [node]="nodejs npm pnpm"
  [java]="jdk21-openjdk maven gradle"
  [python]="python python-pip python-pipx uv"
  [mobile]="android-tools scrcpy kotlin jdk17-openjdk"
  [docker]="docker docker-compose docker-buildx"
  [redis]="redis"
)
declare -A AUR_PKGS=(
  [mobile]="android-studio flutter"
)
COMMON_PKGS=(base-devel git mise)
ALL_LANGS=(go rust ruby node java python mobile docker redis)
REDIS_UNIT=redis.service

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

list_langs() {
  local l
  for l in "${ALL_LANGS[@]}"; do
    printf '  %-8s %s' "$l" "${PKGS[$l]}"
    [[ -z ${AUR_PKGS[$l]:-} ]] || printf '  (AUR: %s)' "${AUR_PKGS[$l]}"
    echo
  done
  printf '  %-8s %s\n' "(todos)" "mise, base-devel, git"
}

parse_args() {
  local list=
  while (($# > 0)); do
    case $1 in
      --lang)
        (($# >= 2)) || die "--lang necesita una lista (por ejemplo go,rust o all)"
        list=$2
        shift
        ;;
      --list)
        list_langs
        exit 0
        ;;
      -y | --yes) ASSUME_YES=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
    shift
  done
  [[ -n $list ]] || die "Falta --lang (usa --list para ver los lenguajes)"
  local item
  if [[ $list == all ]]; then
    LANGS=("${ALL_LANGS[@]}")
    return
  fi
  IFS=',' read -r -a items <<<"$list"
  for item in "${items[@]}"; do
    [[ -n ${PKGS[$item]:-} ]] || die "Lenguaje desconocido: $item (disponibles: ${ALL_LANGS[*]})"
    LANGS+=("$item")
  done
}

check_system() {
  [[ -f /etc/arch-release ]] || die "Este script está pensado para Arch Linux."
  [[ $EUID -ne 0 ]] || die "No lo ejecutes como root; usará sudo cuando haga falta."
}

aur_helper() { command -v yay 2>/dev/null || command -v paru 2>/dev/null || true; }

# Instala yay-bin desde el AUR si no hay ayudante. makepkg no corre como root.
ensure_aur_helper() {
  [[ -z $(aur_helper) ]] || return 0
  warn "No hay yay ni paru y hacen falta para: $*"
  if ((!ASSUME_YES)); then
    local reply
    read -r -p "¿Instalar yay-bin desde el AUR? [s/N]: " reply || reply=
    [[ $reply == s || $reply == S ]] || return 1
  fi
  local tmp mk=(-si)
  ((ASSUME_YES)) && mk+=(--noconfirm)
  tmp=$(mktemp -d)
  info "Construyendo yay-bin en $tmp"
  if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
    (cd "$tmp/yay-bin" && makepkg "${mk[@]}"); then
    ok "yay instalado"
    return 0
  fi
  warn "No se pudo instalar yay-bin"
  return 1
}

# Separa los paquetes que están en los repos oficiales de los que no
split_available() {
  local pkg
  OFFICIAL=()
  MISSING=()
  for pkg in "$@"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      OFFICIAL+=("$pkg")
    else
      MISSING+=("$pkg")
    fi
  done
}

install_packages() {
  local pkgs=("${COMMON_PKGS[@]}") aur=() l
  for l in "${LANGS[@]}"; do
    # shellcheck disable=SC2206
    pkgs+=(${PKGS[$l]})
    # shellcheck disable=SC2206
    [[ -z ${AUR_PKGS[$l]:-} ]] || aur+=(${AUR_PKGS[$l]})
  done

  # Sin bases de datos sincronizadas, `pacman -Si` daría todo por inexistente. Se
  # refrescan justo antes del -Syu de abajo, así que no queda una actualización parcial.
  sudo pacman -Sy
  split_available "${pkgs[@]}"
  # redis cambió de licencia y no siempre está en los repositorios; valkey es su
  # sustituto compatible (mismo protocolo y mismos clientes)
  local m rest=()
  for m in "${MISSING[@]}"; do
    if [[ $m == redis ]] && pacman -Si valkey >/dev/null 2>&1; then
      warn "redis no está en los repositorios oficiales; instalo valkey, compatible con Redis"
      OFFICIAL+=(valkey)
      REDIS_UNIT=valkey.service
    else
      rest+=("$m")
    fi
  done
  MISSING=("${rest[@]}")
  if ((${#MISSING[@]})); then
    warn "No están en los repositorios oficiales: ${MISSING[*]}"
    # Los intentamos por el AUR junto con los demás
    aur+=("${MISSING[@]}")
  fi

  local flags=(--needed)
  ((ASSUME_YES)) && flags+=(--noconfirm)
  info "Instalando con pacman: ${OFFICIAL[*]}"
  sudo pacman -Syu "${flags[@]}" "${OFFICIAL[@]}"
  ok "Paquetes oficiales instalados"

  if ((${#aur[@]})); then
    if ensure_aur_helper "${aur[*]}"; then
      local helper
      helper=$(aur_helper)
      info "Instalando desde el AUR con $(basename "$helper"): ${aur[*]}"
      if ! "$helper" -S "${flags[@]}" "${aur[@]}"; then
        warn "Algún paquete del AUR falló; repite con: $(basename "$helper") -S ${aur[*]}"
        SKIPPED+=("${aur[@]}")
      fi
    else
      warn "Sin ayudante del AUR no se instalan: ${aur[*]}"
      warn "Instala yay o paru y ejecuta: yay -S ${aur[*]}"
      SKIPPED+=("${aur[@]}")
    fi
  fi
}

# ---------------------------------------------------------------- toolchains

has() { [[ " ${LANGS[*]} " == *" $1 "* ]]; }

post_rust() {
  command -v rustup >/dev/null 2>&1 || return 0
  if rustup show active-toolchain >/dev/null 2>&1; then
    ok "rustup ya tiene un toolchain activo"
  else
    info "Instalando el toolchain estable de Rust"
    rustup default stable
  fi
  # rust-analyzer lo usa Neovim; rust-src le da navegación a la biblioteca estándar
  rustup component add rust-analyzer rust-src >/dev/null 2>&1 ||
    warn "No se pudieron añadir rust-analyzer/rust-src; Neovim los instalará con Mason"
}

post_node() {
  command -v npm >/dev/null 2>&1 || return 0
  # Sin esto `npm install -g` intenta escribir en /usr y pide sudo
  if [[ -z $(npm config get prefix --location=user 2>/dev/null | grep -v '^undefined$' || true) ]]; then
    info "npm: instalaciones globales en ~/.local (sin sudo)"
    npm config set prefix "$HOME/.local" --location=user
  fi
}

post_java() {
  command -v archlinux-java >/dev/null 2>&1 || return 0
  local want=java-21-openjdk
  if archlinux-java status 2>/dev/null | grep -q "$want"; then
    info "Java por defecto: $want"
    sudo archlinux-java set "$want" || warn "No se pudo fijar $want como Java por defecto"
  fi
}

post_python() {
  command -v pipx >/dev/null 2>&1 && pipx ensurepath >/dev/null 2>&1 || true
}

# enable_service UNIDAD: lo activa al arranque y, si systemd está corriendo, lo arranca ya
enable_service() {
  sudo systemctl enable "$1" || {
    warn "No se pudo activar $1"
    return 0
  }
  if [[ -d /run/systemd/system ]]; then
    sudo systemctl start "$1" || warn "No se pudo arrancar $1; mira: systemctl status $1"
  fi
}

post_docker() {
  enable_service docker.service
  local user
  user=$(id -un)
  # (sin pipe con grep -q: con pipefail, el SIGPIPE de tr daría falso aunque coincida)
  if [[ " $(id -nG "$user") " == *" docker "* ]]; then
    ok "$user ya está en el grupo docker"
  else
    info "Añadiendo a $user al grupo docker (equivale a root; ver --help)"
    sudo usermod -aG docker "$user"
    DOCKER_RELOGIN=1
  fi
}

post_redis() {
  enable_service "$REDIS_UNIT"
}

post_mobile() {
  # Android Studio instala el SDK en ~/Android/Sdk; .bashrc añade platform-tools
  # al PATH cuando existe. Con 17 y 21 instalados, Android usa el JDK de Studio.
  info "Móvil: abre Android Studio una vez para descargar el SDK; Flutter: flutter doctor"
}

main() {
  parse_args "$@"
  check_system
  install_packages
  local l
  for l in "${LANGS[@]}"; do
    if declare -F "post_$l" >/dev/null; then
      "post_$l"
    fi
  done
  if ((${#SKIPPED[@]})); then
    warn "Entornos instalados (${LANGS[*]}), pero faltan: ${SKIPPED[*]}"
  else
    ok "Entornos listos: ${LANGS[*]}"
  fi
  if has ruby; then
    echo "Ruby: instala gems sin sudo con 'gem install --user-install' o usa 'bundle config set path vendor/bundle'."
  fi
  if ((DOCKER_RELOGIN)); then
    echo "Docker: cierra sesión y vuelve a entrar para usarlo sin sudo (o ejecuta 'newgrp docker')."
  fi
  echo "Versiones por proyecto: 'mise use go@1.23', 'mise use node@22'… (ya activado en .bashrc)."
}

main "$@"
