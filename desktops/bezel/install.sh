#!/usr/bin/env bash
# desktops/bezel/install.sh — instala el escritorio bezel (Hyprland + Quickshell)
# con Alacritty y la paleta Catppuccin Mocha.
#
# Uso: desktops/bezel/install.sh [opciones]
#   -y, --yes        aceptar las respuestas por defecto del instalador de bezel
#   --greeter        instalar también su pantalla de inicio de sesión (greetd, usa sudo)
#   --patch-only     descargar y parchear bezel, pero no ejecutar su instalador
#   --uninstall      desinstalar bezel y restaurar tu configuración anterior
#   -h, --help       mostrar esta ayuda
#
# No se copia código de bezel (GPL-3.0) a este repo: se descarga el original,
# fijado a un commit probado, a ~/.local/share/dotfiles/bezel-hyprland y se le
# aplican los parches de patch.sh. Bezel sustituye tu configuración de Hyprland,
# Quickshell y GTK/Qt; lo anterior se guarda en ~/.local/state/bezel/backup/.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEZEL_URL="https://github.com/vmaltarello/bezel-hyprland"
# Commit probado. Para actualizar, cambia el hash y comprueba que patch.sh siga encajando.
BEZEL_REF="b1dd73c9d596d11d46497b4b2dda4504544da919"
BEZEL_DIR="${BEZEL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/bezel-hyprland}"
# Componentes opcionales de bezel que se instalan. Neovim, starship y Zed quedan fuera
# porque ya tienes tu propia configuración de Neovim y de prompt.
COMPONENTS="yazi,btop,lazygit,zathura,imv"

ASSUME_YES=0
GREETER=0
PATCH_ONLY=0
UNINSTALL=0

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m✔\033[0m %s\n' "$*"; }
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
      --greeter) GREETER=1 ;;
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
  # --patch-only no instala nada ni usa sudo, así que no exige root ni Arch
  if ((!PATCH_ONLY)); then
    [[ $EUID -ne 0 ]] || die "No lo ejecutes como root; usará sudo cuando haga falta."
    [[ -f /etc/arch-release ]] || die "Bezel solo funciona en Arch Linux."
  fi
}

# Deja BEZEL_DIR exactamente en BEZEL_REF, sin restos de parches anteriores
fetch_upstream() {
  info "Descargando bezel ($BEZEL_REF)..."
  if [[ ! -d $BEZEL_DIR/.git ]]; then
    mkdir -p "$BEZEL_DIR"
    git -C "$BEZEL_DIR" init -q
    git -C "$BEZEL_DIR" remote add origin "$BEZEL_URL"
  fi
  git -C "$BEZEL_DIR" fetch -q --depth 1 origin "$BEZEL_REF"
  git -C "$BEZEL_DIR" checkout -q --force FETCH_HEAD
  git -C "$BEZEL_DIR" clean -fdq
  ok "bezel en $BEZEL_DIR"
}

run_installer() {
  local args=(--only "$COMPONENTS")
  ((ASSUME_YES)) && args+=(--yes)
  ((GREETER)) && args+=(--greeter)
  info "Ejecutando el instalador de bezel..."
  "$BEZEL_DIR/install.sh" "${args[@]}"
}

uninstall() {
  [[ -x $BEZEL_DIR/uninstall.sh ]] || die "No encuentro $BEZEL_DIR/uninstall.sh; ¿está instalado?"
  "$BEZEL_DIR/uninstall.sh"
}

main() {
  parse_args "$@"
  check_system

  if ((UNINSTALL)); then
    uninstall
    return
  fi

  fetch_upstream
  "$HERE/patch.sh" "$BEZEL_DIR"

  if ((PATCH_ONLY)); then
    ok "Parches aplicados. Revísalos con: git -C $BEZEL_DIR diff --stat"
    return
  fi

  run_installer
}

main "$@"
