#!/usr/bin/env bash
# desktops/suzuha/install.sh — instala suzuha, un shell de escritorio escrito en
# Rust con amane, para el compositor Niri. Alacritty sigue los colores del
# wallpaper.
#
# Uso: desktops/suzuha/install.sh [opciones]
#   -y, --yes        no pedir confirmación a pacman
#   --no-build       no compilar (descarga, parchea y configura Niri)
#   --patch-only     descargar y parchear, pero no instalar nada
#   --uninstall      quitar suzuha y devolver Alacritty a Catppuccin Mocha
#   -h, --help       mostrar esta ayuda
#
# amane (MIT) es la librería con la que se escribe el shell; suzuha (sin
# licencia) es la configuración de su autor, hecha con amane. No se copia código
# de ninguno a este repo: se descargan los originales, fijados a un commit
# probado, a ~/.local/share/dotfiles/{amane,suzuha}; a suzuha se le aplican los
# parches de patch.sh; y se compilan ahí. No se puede usar a la vez que bezel,
# dhruv o docky, y necesita una GPU con Vulkan.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
BASE="$REPO_DIR/desktops/niri-base.kdl"

AMANE_URL="https://github.com/MystiaFin/amane"
SUZUHA_URL="https://github.com/MystiaFin/suzuha"
# Commits probados. Para actualizar, cambia el hash y comprueba que patch.sh siga encajando.
AMANE_REF="56c2c5f445b0e4b68fbdfb61637ac0ccc0c0ee1e"
SUZUHA_REF="62118f30ba8a8db250b0fe547429ec450002730e"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles"
AMANE_DIR="${AMANE_DIR:-$DATA_HOME/amane}"
SUZUHA_DIR="${SUZUHA_DIR:-$DATA_HOME/suzuha}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_DIR="$HOME/.local/bin"
AMANE_BIN="$BIN_DIR/amane"
# Marca qué commit de amane está instalado, para no recompilarlo en cada ejecución
AMANE_STAMP="$STATE_HOME/dotfiles/suzuha-amane-ref"

# Librerías de amane (su install.sh usa esta misma lista), Niri y lo que suzuha usa
PACKAGES=(
  rust gcc pkgconf wayland libxkbcommon fontconfig freetype2 expat
  vulkan-icd-loader libpulse pam
  niri alacritty curl wl-clipboard wf-recorder libnotify
  pipewire pipewire-pulse wireplumber brightnessctl playerctl
  cava ffmpeg imagemagick
  ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
)
# Paquetes cuyo nombre o repositorio no he podido comprobar: se buscan en pacman y,
# si no están, en el AUR con yay o paru
OPTIONAL_PACKAGES=(ttf-poppins ttf-material-design-icons-webfont xdg-desktop-portal-gnome)

ASSUME_YES=0
NO_BUILD=0
PATCH_ONLY=0
UNINSTALL=0

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

parse_args() {
  while (($# > 0)); do
    case $1 in
      -y | --yes) ASSUME_YES=1 ;;
      --no-build) NO_BUILD=1 ;;
      --patch-only) PATCH_ONLY=1 ;;
      --uninstall) UNINSTALL=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
    shift
  done
}

check_system() {
  command -v git >/dev/null 2>&1 || die "Falta git (pacman -S git)."
  command -v perl >/dev/null 2>&1 || die "Falta perl (pacman -S perl)."
  # --patch-only y --uninstall no instalan paquetes, así que no exigen root ni Arch
  if ((!PATCH_ONLY && !UNINSTALL)); then
    [[ $EUID -ne 0 ]] || die "No lo ejecutes como root; usará sudo cuando haga falta."
    [[ -f /etc/arch-release ]] || die "Este script está pensado para Arch Linux."
  fi
}

# fetch <url> <sha> <directorio>: lo deja exactamente en ese commit, sin restos de
# parches anteriores. `clean` no borra target/ si está en su .gitignore.
fetch() {
  local url=$1 ref=$2 dir=$3
  info "Descargando $(basename "$url") ($ref)..."
  if [[ ! -d $dir/.git ]]; then
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$ref"
  git -C "$dir" checkout -q --force FETCH_HEAD
  git -C "$dir" clean -fdq
  ok "$(basename "$url") en $dir"
}

# aur_helper: imprime yay o paru si existe
aur_helper() {
  command -v yay 2>/dev/null || command -v paru 2>/dev/null || true
}

install_packages() {
  info "Instalando paquetes con pacman..."
  local flags=(--needed)
  ((ASSUME_YES)) && flags+=(--noconfirm)
  # -Syu sincroniza antes de instalar; así pacman -Si ya ve los paquetes nuevos
  sudo pacman -Syu "${flags[@]}" "${PACKAGES[@]}"

  local pkg helper missing=()
  helper="$(aur_helper)"
  for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      sudo pacman -S "${flags[@]}" "$pkg"
    elif [[ -n $helper ]]; then
      "$helper" -S --needed "$pkg" || missing+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]})); then
    warn "No pude instalar: ${missing[*]} (instálalos desde el AUR)."
    warn "suzuha usa las fuentes Poppins y Material Design Icons; sin ellas el texto o los iconos salen mal."
  fi
}

# amane dibuja con Vulkan: sin un controlador de tu GPU, el shell no arranca
check_vulkan() {
  if ! compgen -G "/usr/share/vulkan/icd.d/*.json" >/dev/null; then
    warn "No encuentro ningún controlador Vulkan. Instala el de tu GPU:"
    warn "  AMD: vulkan-radeon · Intel: vulkan-intel · NVIDIA: nvidia-utils"
  fi
}

# El CLI de amane va a ~/.local/bin, que ya está en el PATH de las sesiones normales.
install_amane() {
  if [[ -x $AMANE_BIN && -f $AMANE_STAMP && "$(<"$AMANE_STAMP")" == "$AMANE_REF" ]]; then
    ok "amane ya está instalado en $AMANE_BIN"
    return
  fi
  info "Compilando el CLI de amane (puede tardar unos minutos)..."
  cargo install --path "$AMANE_DIR/cli" --locked --force --root "$HOME/.local"
  [[ -x $AMANE_BIN ]] || die "cargo no dejó $AMANE_BIN"
  mkdir -p "$(dirname "$AMANE_STAMP")"
  printf '%s\n' "$AMANE_REF" >"$AMANE_STAMP"
  ok "amane instalado en $AMANE_BIN"
}

# Apunta amane a la copia de suzuha y compila el shell (queda en ~/.cache/amane)
build_shell() {
  if [[ -f $STATE_HOME/amane/config-path && "$(<"$STATE_HOME/amane/config-path")" != "$SUZUHA_DIR" ]]; then
    warn "amane apuntaba a otra configuración ($(<"$STATE_HOME/amane/config-path")); ahora apunta a suzuha."
  elif [[ ! -f $STATE_HOME/amane/config-path && -f $CONFIG_HOME/amane/src/main.rs ]]; then
    warn "Tienes un shell propio en $CONFIG_HOME/amane; amane usará suzuha en su lugar."
  fi
  "$AMANE_BIN" target "$SUZUHA_DIR"
  info "Compilando suzuha (la primera vez tarda varios minutos)..."
  "$AMANE_BIN" compile
  [[ -x $HOME/.cache/amane/amane-shell ]] || die "La compilación no generó ~/.cache/amane/amane-shell"
  ok "Shell compilado"
}

# Configuración de Niri solo si no hay una propia
install_niri_config() {
  local dst="$CONFIG_HOME/niri/config.kdl"
  if [[ -f $dst ]]; then
    ok "Ya tienes $dst; no la toco."
    warn "Para usar suzuha añade a tu configuración de Niri (ejemplo en $BASE):"
    warn "  spawn-at-startup \"$AMANE_BIN\" \"run\""
    warn "  layer-rule { match namespace=\"^wallpaper\$\"; place-within-backdrop true; }"
    warn "  environment { TERMINAL \"alacritty\"; }"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  sed "s|@BIN@|$BIN_DIR|g" "$BASE" >"$dst"
  ok "Configuración de Niri escrita en $dst"
}

uninstall() {
  pkill -x amane-shell 2>/dev/null || true
  if [[ -f $STATE_HOME/amane/config-path && "$(<"$STATE_HOME/amane/config-path")" == "$SUZUHA_DIR" ]]; then
    rm -f "$STATE_HOME/amane/config-path"
  fi
  rm -rf "$SUZUHA_DIR" "$AMANE_DIR" "$HOME/.cache/amane" "$AMANE_STAMP"
  rm -f "$AMANE_BIN"
  # Alacritty vuelve a Catppuccin Mocha
  : >"$REPO_DIR/alacritty/dynamic.toml"
  ok "suzuha y amane quitados, y Alacritty de vuelta en Catppuccin Mocha"
  warn "No toqué $CONFIG_HOME/niri/config.kdl: quita de ahí el arranque de amane a mano."
  warn "Los ajustes del shell siguen en $STATE_HOME/amane."
}

main() {
  parse_args "$@"
  check_system

  if ((UNINSTALL)); then
    uninstall
    return
  fi

  fetch "$AMANE_URL" "$AMANE_REF" "$AMANE_DIR"
  fetch "$SUZUHA_URL" "$SUZUHA_REF" "$SUZUHA_DIR"
  bash "$HERE/patch.sh" "$SUZUHA_DIR"

  if ((PATCH_ONLY)); then
    ok "Parches aplicados. Revísalos con: git -C $SUZUHA_DIR diff --stat"
    return
  fi

  install_packages
  check_vulkan
  mkdir -p "$HOME/Pictures/Wallpapers"
  install_niri_config
  if ((!NO_BUILD)); then
    install_amane
    build_shell
  fi

  cat <<EOM

Listo. Siguientes pasos:
  1. Inicia Niri (desde una TTY con \`niri-session\` o desde tu gestor de inicio de sesión).
  2. Copia tus wallpapers a ~/Pictures/Wallpapers y ábrelos con SUPER+SHIFT+W.
  3. SUPER+ESPACIO abre el lanzador (con > entras en modo comandos), SUPER+A el
     centro de control, SUPER+N el panel de utilidades y SUPER+SHIFT+S los ajustes.
Si cambias suzuha, vuelve a compilar con: amane compile
EOM
}

main "$@"
