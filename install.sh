#!/usr/bin/env bash
# install.sh — instala estos dotfiles en Arch Linux.
#
# Uso: ./install.sh [opciones]
#   -y, --yes          no pedir confirmación a pacman (--noconfirm)
#   --no-packages      no instalar paquetes, solo enlazar la configuración
#   --no-omb           no clonar Oh My Bash
#   --desktop NOMBRE   instalar además un escritorio: bezel, dhruv, docky, lucid (Hyprland) o suzuha (Niri)
#   --wallpapers       con --desktop dhruv, copiar su colección de wallpapers
#   --wallpaper-picker instalar un selector de wallpapers (no con dhruv, docky, lucid ni suzuha)
#   --dev LISTA        entornos y servicios: go, rust, ruby, node, java, python, mobile, docker, redis o all
#   --laptop           instalar TLP (ahorro de energía) y brightnessctl
#   -h, --help         mostrar esta ayuda
#
# Qué hace:
#   1. Sincroniza e instala los paquetes necesarios con pacman. Usa -Syu porque
#      en Arch instalar sin actualizar antes puede causar actualizaciones parciales.
#   2. Clona Oh My Bash en ~/.oh-my-bash (si no existe).
#   3. Con --desktop, instala el escritorio elegido (desktops/<nombre>/).
#   4. Con --laptop, instala y activa TLP.
#   5. Con --wallpaper-picker, instala el selector de wallpapers.
#   6. Enlaza la configuración y los scripts de bin/ (en ~/.local/bin) con
#      symlinks; lo que ya exista se respalda en ~/.dotfiles-backup/<fecha>/.
#
# Como se usan symlinks, este repositorio debe quedarse donde está
# (por ejemplo ~/.dotfiles).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

ASSUME_YES=0
INSTALL_PACKAGES=1
INSTALL_OMB=1
LAPTOP=0
WALLPAPERS=0
WALLPAPER_PICKER=0
DESKTOP=
DEV_LANGS=

PACKAGES=(
  # Base
  git base-devel curl unzip
  # Editor, terminal y fuente
  neovim alacritty ttf-jetbrains-mono-nerd
  # Herramientas que usa la configuración
  ripgrep fd fzf bat eza zoxide tree-sitter-cli shellcheck lazygit
  # Formateadores (conform.nvim)
  stylua shfmt prettier ruff
  # Portapapeles de Neovim (Wayland / X11)
  wl-clipboard xclip
  # Mason necesita node y npm para varios servidores LSP
  nodejs npm
  # tmux (función `tm`), explorador de archivos y temperaturas (sysreport)
  tmux yazi lm_sensors
  # Scripts de bin/: capturas y grabación de pantalla en Wayland
  grim slurp wf-recorder libnotify jq
)

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  # Imprime el bloque de comentarios inicial (sin el shebang)
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

parse_args() {
  while (($# > 0)); do
    case $1 in
      -y | --yes) ASSUME_YES=1 ;;
      --no-packages) INSTALL_PACKAGES=0 ;;
      --no-omb) INSTALL_OMB=0 ;;
      --laptop) LAPTOP=1 ;;
      --wallpapers) WALLPAPERS=1 ;;
      --wallpaper-picker) WALLPAPER_PICKER=1 ;;
      --dev)
        (($# >= 2)) || die "--dev necesita una lista (por ejemplo go,rust o all)"
        DEV_LANGS=$2
        shift
        ;;
      --desktop)
        (($# >= 2)) || die "--desktop necesita un nombre (bezel, dhruv, docky, lucid o suzuha)"
        DESKTOP=$2
        shift
        ;;
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
  [[ -f /etc/arch-release ]] || die "Este script está pensado para Arch Linux."
  [[ $EUID -ne 0 ]] || die "No lo ejecutes como root; usará sudo cuando haga falta."
}

install_packages() {
  info "Instalando paquetes con pacman..."
  local flags=(--needed)
  if ((ASSUME_YES)); then
    flags+=(--noconfirm)
  fi
  sudo pacman -Syu "${flags[@]}" "${PACKAGES[@]}"
  fc-cache -f >/dev/null 2>&1 || true
  ok "Paquetes instalados"
}

install_omb() {
  local dir="$HOME/.oh-my-bash"
  if [[ -d $dir ]]; then
    ok "Oh My Bash ya está en $dir"
    return
  fi
  info "Clonando Oh My Bash..."
  git clone --depth=1 https://github.com/ohmybash/oh-my-bash.git "$dir"
  ok "Oh My Bash instalado"
}

# TLP gestiona la batería; no debe convivir con power-profiles-daemon ni con
# el servicio de rfkill de systemd (así lo indica su documentación).
install_laptop() {
  info "Configurando el ahorro de energía (TLP)..."
  if pacman -Qq power-profiles-daemon >/dev/null 2>&1; then
    warn "power-profiles-daemon está instalado y choca con TLP; no se instala TLP."
    warn "Quita uno de los dos (sudo pacman -Rns power-profiles-daemon) y repite con --laptop."
    return
  fi
  local flags=(--needed)
  if ((ASSUME_YES)); then
    flags+=(--noconfirm)
  fi
  sudo pacman -Syu "${flags[@]}" tlp brightnessctl
  sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
  sudo systemctl enable --now tlp.service
  ok "TLP activo"
}

# link <origen> <destino>: crea un symlink y respalda lo que hubiera en destino.
link() {
  local src=$1 dest=$2

  if [[ -L $dest && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    ok "Ya enlazado: $dest"
    return
  fi

  if [[ -e $dest || -L $dest ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")"
    warn "Respaldo de $dest en $BACKUP_DIR/"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  ok "Enlazado: $dest -> $src"
}

# Cada escritorio vive en desktops/<nombre>/install.sh
check_desktop() {
  if ((WALLPAPER_PICKER)) && [[ $DESKTOP == dhruv || $DESKTOP == docky || $DESKTOP == suzuha || $DESKTOP == lucid ]]; then
    die "$DESKTOP ya trae su propio selector de wallpapers; quita --wallpaper-picker"
  fi
  if ((WALLPAPERS)) && [[ $DESKTOP != dhruv ]]; then
    die "--wallpapers solo se puede usar con --desktop dhruv"
  fi
  [[ -z $DESKTOP || -x $REPO_DIR/desktops/$DESKTOP/install.sh ]] && return
  die "Escritorio desconocido: $DESKTOP (disponibles: $(find "$REPO_DIR/desktops" -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null))"
}

install_desktop() {
  info "Instalando el escritorio $DESKTOP..."
  local args=()
  if ((ASSUME_YES)); then
    args+=(--yes)
  fi
  if ((WALLPAPERS)); then
    args+=(--wallpapers)
  fi
  "$REPO_DIR/desktops/$DESKTOP/install.sh" "${args[@]}"
}

install_dev() {
  info "Instalando entornos de desarrollo ($DEV_LANGS)..."
  local args=(--lang "$DEV_LANGS")
  if ((ASSUME_YES)); then
    args+=(--yes)
  fi
  "$REPO_DIR/components/dev/install.sh" "${args[@]}"
}

install_wallpaper_picker() {
  info "Instalando el selector de wallpapers..."
  local args=()
  if ((ASSUME_YES)); then
    args+=(--yes)
  fi
  "$REPO_DIR/components/wallpaper-picker/install.sh" "${args[@]}"
}

link_configs() {
  info "Enlazando configuración..."
  # dynamic.toml lo rellena matugen si usas un escritorio con tema dinámico; no se
  # versiona. Alacritty lo importa, así que tiene que existir aunque esté vacío.
  [[ -e $REPO_DIR/alacritty/dynamic.toml ]] || : >"$REPO_DIR/alacritty/dynamic.toml"
  link "$REPO_DIR/bash/.bashrc" "$HOME/.bashrc"
  link "$REPO_DIR/alacritty" "$HOME/.config/alacritty"
  link "$REPO_DIR/nvim" "$HOME/.config/nvim"
  link "$REPO_DIR/tmux" "$HOME/.config/tmux"

  # Scripts: un symlink por archivo en ~/.local/bin (ya está en el PATH de .bashrc)
  local script
  for script in "$REPO_DIR"/bin/*; do
    link "$script" "$HOME/.local/bin/$(basename "$script")"
  done
}

main() {
  parse_args "$@"
  check_system
  check_desktop

  ((INSTALL_PACKAGES)) && install_packages
  ((INSTALL_OMB)) && install_omb
  if [[ -n $DESKTOP ]]; then
    install_desktop
  fi
  if ((LAPTOP)); then
    install_laptop
  fi
  if ((WALLPAPER_PICKER)); then
    install_wallpaper_picker
  fi
  if [[ -n $DEV_LANGS ]]; then
    install_dev
  fi
  link_configs

  cat <<'EOF'

Listo. Siguientes pasos:
  1. Abre una terminal nueva (idealmente Alacritty) para cargar Oh My Bash.
  2. Ejecuta `nvim`: lazy.nvim instalará los plugins y Mason los servidores LSP.
  3. Revisa que todo esté bien con :checkhealth dentro de Neovim.
EOF
}

main "$@"
