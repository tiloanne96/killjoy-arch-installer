#!/usr/bin/env bash
# desktops/dhruv/install.sh — instala el rice Hyprland + Quickshell de dhruvsharma
# con Alacritty como terminal y colores que salen del wallpaper (matugen).
#
# Uso: desktops/dhruv/install.sh [opciones]
#   -y, --yes        no pedir confirmación (pacman y el instalador original)
#   --extras         instalar también ollama, github-cli y los entornos de Python
#                    de los lectores de anime, manga y novela
#   --github USER    usuario de GitHub para el widget de contribuciones
#   --wallpapers     copiar su colección de wallpapers a ~/Pictures/wallpapers
#                    (unos 730 MB; no se incluye en este repo)
#   --patch-only     descargar y parchear, pero no instalar nada
#   --uninstall      quitar el shell y devolver Alacritty a Catppuccin Mocha
#   -h, --help       mostrar esta ayuda
#
# No se copia código de dhruvsharma/shell (GPL-3.0 o posterior) a este repo: se
# descarga el original, fijado a un commit probado, a
# ~/.local/share/dotfiles/dhruv-shell y se le aplican los parches de patch.sh.
# Los colores de Quickshell, Alacritty y los bordes de Hyprland se regeneran
# con matugen cada vez que cambias el wallpaper (comando setwall).
#
# No se puede usar a la vez que desktops/bezel: los dos reemplazan Quickshell.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
BASE="$REPO_DIR/desktops/hyprland-base.lua"

DHRUV_URL="https://github.com/dhrruvsharma/shell"
# Commit probado. Para actualizar, cambia el hash y comprueba que patch.sh siga encajando.
DHRUV_REF="e91da907aa9c62652b3234a626ed089b93b46ee5"
DHRUV_DIR="${DHRUV_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/dhruv-shell}"

WALLPAPERS_URL="https://github.com/dhrruvsharma/wallpapers"
WALLPAPERS_REF="f6a1c60221682fd681616b25ad7fb3eb15d28025"
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

ASSUME_YES=0
EXTRAS=0
GITHUB_USER=
WALLPAPERS=0
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
      --extras) EXTRAS=1 ;;
      --github)
        (($# >= 2)) || die "--github necesita un usuario"
        GITHUB_USER=$2
        shift
        ;;
      --wallpapers) WALLPAPERS=1 ;;
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
    [[ -f /etc/arch-release ]] || die "Este rice solo funciona en Arch Linux."
  fi
}

# fetch <url> <sha> <directorio>: deja el directorio exactamente en ese commit,
# sin restos de parches anteriores
fetch() {
  local url=$1 ref=$2 dir=$3
  if [[ ! -d $dir/.git ]]; then
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$ref"
  git -C "$dir" checkout -q --force FETCH_HEAD
  git -C "$dir" clean -fdq
}

fetch_upstream() {
  info "Descargando dhruvsharma/shell ($DHRUV_REF)..."
  fetch "$DHRUV_URL" "$DHRUV_REF" "$DHRUV_DIR"
  ok "Shell en $DHRUV_DIR"
}

# Base de Hyprland solo si no hay configuración propia. Con un hyprland.conf
# existente, crear hyprland.lua haría que Hyprland lo ignorara.
install_hypr_base() {
  local dst="$CONFIG_HOME/hypr"
  if [[ -f $dst/hyprland.lua ]]; then
    ok "Ya tienes $dst/hyprland.lua; el instalador original añadirá solo sus atajos"
    return
  fi
  if [[ -f $dst/hyprland.conf ]]; then
    warn "Tienes $dst/hyprland.conf pero no hyprland.lua; no creo uno para no desactivarlo."
    warn "Convierte tu configuración a Lua o copia $BASE a $dst/ por tu cuenta."
    return
  fi
  mkdir -p "$dst"
  cp "$BASE" "$dst/hyprland.lua"
  ok "Base de Hyprland instalada en $dst/hyprland.lua"
}

run_installer() {
  local args=()
  if ((ASSUME_YES)); then args+=(--yes); fi
  if ((EXTRAS)); then args+=(--extras); fi
  if [[ -n $GITHUB_USER ]]; then args+=(--github "$GITHUB_USER"); fi
  info "Ejecutando el instalador original..."
  bash "$DHRUV_DIR/quickshell/install.sh" "${args[@]}"
}

# register_template <nombre> <entrada> <salida> [comando]: añade [templates.<nombre>]
# a la configuración de matugen si no existe; el comando se ejecuta tras generarla
register_template() {
  local name=$1 input=$2 output=$3 hook=${4:-}
  local conf="$CONFIG_HOME/matugen/config.toml"
  mkdir -p "$(dirname "$conf")"
  if grep -qs "^\[templates\.$name\]" "$conf"; then
    return
  fi
  printf '\n[templates.%s]\ninput_path  = "%s"\noutput_path = "%s"\n' "$name" "$input" "$output" >>"$conf"
  if [[ -n $hook ]]; then
    printf 'post_hook   = "%s"\n' "$hook" >>"$conf"
  fi
  ok "Plantilla de matugen registrada: $name"
}

# Alacritty y los bordes de Hyprland siguen el wallpaper
setup_theming() {
  mkdir -p "$CONFIG_HOME/matugen/templates"
  cp "$REPO_DIR/desktops/matugen-alacritty.toml" "$CONFIG_HOME/matugen/templates/alacritty.toml"
  register_template alacritty \
    "$CONFIG_HOME/matugen/templates/alacritty.toml" \
    "$CONFIG_HOME/alacritty/dynamic.toml"
  # La plantilla de colores de Hyprland viene en el repo original
  register_template hyprland_lua \
    "$DHRUV_DIR/matugen/templates/hyprland.lua" \
    "$CONFIG_HOME/hypr/colors.lua" \
    "hyprctl reload"
}

fetch_wallpapers() {
  local git_dir tmp
  git_dir="$(mktemp -d)"
  mkdir -p "$WALLPAPERS_DIR"
  # El árbol de trabajo temporal está en el mismo disco, así que mover es instantáneo
  tmp="$WALLPAPERS_DIR/.dhruv-wallpapers-tmp"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  info "Descargando wallpapers (unos 730 MB)..."
  git --git-dir="$git_dir" init -q
  git --git-dir="$git_dir" remote add origin "$WALLPAPERS_URL"
  git --git-dir="$git_dir" fetch -q --depth 1 origin "$WALLPAPERS_REF"
  git --git-dir="$git_dir" --work-tree="$tmp" checkout -q --force FETCH_HEAD
  # No se pisa nada que ya tengas con el mismo nombre
  local entry dest skipped=0
  for entry in "$tmp"/*; do
    [[ -e $entry ]] || continue
    dest="$WALLPAPERS_DIR/$(basename "$entry")"
    if [[ -e $dest ]]; then
      skipped=$((skipped + 1))
    else
      mv "$entry" "$dest"
    fi
  done
  rm -rf "$tmp" "$git_dir"
  ok "Wallpapers en $WALLPAPERS_DIR"
  if ((skipped)); then
    warn "$skipped archivos ya existían y se dejaron como estaban"
  fi
}

uninstall() {
  local qs="$CONFIG_HOME/quickshell" backup
  if [[ -L $qs && "$(readlink -f "$qs")" == "$(readlink -f "$DHRUV_DIR/quickshell")" ]]; then
    rm "$qs"
    ok "Quitado $qs"
    # El instalador original respalda una configuración anterior como quickshell.bak-<fecha>
    backup="$(find "$CONFIG_HOME" -maxdepth 1 -name 'quickshell.bak-*' | sort | tail -n 1)"
    if [[ -n $backup ]]; then
      mv "$backup" "$qs"
      ok "Restaurado $backup"
    fi
  fi
  rm -f "$HOME/.local/bin/setwall"
  # Alacritty vuelve a Catppuccin Mocha
  : >"$REPO_DIR/alacritty/dynamic.toml"
  ok "Alacritty vuelve a Catppuccin Mocha"
  warn "No toqué ~/.config/hypr ni ~/.config/matugen. Quita a mano require(\"quickshell\")"
  warn "de hyprland.lua y las plantillas alacritty y hyprland_lua de matugen/config.toml."
}

main() {
  parse_args "$@"
  check_system

  if ((UNINSTALL)); then
    uninstall
    return
  fi

  fetch_upstream
  bash "$HERE/patch.sh" "$DHRUV_DIR"

  if ((PATCH_ONLY)); then
    ok "Parches aplicados. Revísalos con: git -C $DHRUV_DIR diff --stat"
    return
  fi

  # El instalador original usa pacman -S sin -y; sincronizar antes evita
  # actualizaciones parciales
  info "Actualizando el sistema..."
  if ((ASSUME_YES)); then
    sudo pacman -Syu --noconfirm
  else
    sudo pacman -Syu
  fi

  install_hypr_base
  run_installer
  setup_theming
  if ((WALLPAPERS)); then
    fetch_wallpapers
  fi

  cat <<EOM

Listo. Siguientes pasos:
  1. Inicia Hyprland (desde una TTY o tu gestor de inicio de sesión).
  2. Elige un wallpaper con SUPER+W, o desde la terminal: setwall <archivo>
     Eso cambia el fondo y regenera los colores del shell, Alacritty y los bordes.
  3. SUPER+R abre el launcher y SUPER+Q una terminal.
EOM
}

main "$@"
