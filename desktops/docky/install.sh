#!/usr/bin/env bash
# desktops/docky/install.sh — instala Docky.rs, un dock y barra para Hyprland escrito
# en Rust, con Alacritty como terminal y colores que salen del wallpaper.
#
# Uso: desktops/docky/install.sh [opciones]
#   -y, --yes        no pedir confirmación a pacman
#   --no-build       no compilar (descarga, parchea y configura Hyprland)
#   --patch-only     descargar y parchear, pero no instalar nada
#   --uninstall      quitar Docky.rs y devolver Alacritty a Catppuccin Mocha
#   -h, --help       mostrar esta ayuda
#
# Es el más ligero de los escritorios: un solo binario de unos 13 MB con dock,
# lanzador de apps, portapapeles, capturas, selector de wallpapers, widgets, OSD
# y demonio de notificaciones. No se puede usar a la vez que bezel o dhruv.
#
# No se copia código de Volcha-Z/Docky.rs (MIT) a este repo: se descarga el
# original, fijado a un commit probado, a ~/.local/share/dotfiles/docky, se le
# aplican los parches de patch.sh y se compila ahí. Respecto a su instalador
# original, este no crea reglas de sudoers, no detiene otros demonios de
# notificaciones y no crea un hyprland.lua si ya tienes un hyprland.conf.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
BASE="$REPO_DIR/desktops/hyprland-base.lua"

DOCKY_URL="https://github.com/Volcha-Z/Docky.rs"
# Commit probado. Para actualizar, cambia el hash y comprueba que patch.sh siga encajando.
DOCKY_REF="072343acea32e43c56c4b908405d07b44c6f998c"
DOCKY_DIR="${DOCKY_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/docky}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

PACKAGES=(
  rust wayland wayland-protocols libxkbcommon fontconfig freetype2 pkgconf
  wireplumber pipewire pipewire-pulse libpulse dbus python
  curl playerctl brightnessctl bluez-utils alacritty
  adwaita-fonts ttf-jetbrains-mono wf-recorder
)

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

# Deja DOCKY_DIR exactamente en DOCKY_REF, sin restos de parches anteriores.
# `clean` no borra target/ (está en su .gitignore), así que se conserva la compilación.
fetch_upstream() {
  info "Descargando Docky.rs ($DOCKY_REF)..."
  if [[ ! -d $DOCKY_DIR/.git ]]; then
    mkdir -p "$DOCKY_DIR"
    git -C "$DOCKY_DIR" init -q
    git -C "$DOCKY_DIR" remote add origin "$DOCKY_URL"
  fi
  git -C "$DOCKY_DIR" fetch -q --depth 1 origin "$DOCKY_REF"
  git -C "$DOCKY_DIR" checkout -q --force FETCH_HEAD
  git -C "$DOCKY_DIR" clean -fdq
  ok "Docky.rs en $DOCKY_DIR"
}

install_packages() {
  info "Instalando paquetes con pacman..."
  local flags=(--needed) pkgs=("${PACKAGES[@]}")
  if ((ASSUME_YES)); then
    flags+=(--noconfirm)
  fi
  # -Syu sincroniza antes de instalar; así pacman -Si ya ve los paquetes nuevos
  sudo pacman -Syu "${flags[@]}" "${pkgs[@]}"
  install_matugen "${flags[@]}"
  install_wallpaper_daemon "${flags[@]}"
}

# Los colores del wallpaper necesitan matugen: del repo si existe, si no con cargo
install_matugen() {
  command -v matugen >/dev/null 2>&1 && return
  if pacman -Si matugen >/dev/null 2>&1; then
    sudo pacman -S "$@" matugen
  else
    info "Instalando matugen con cargo..."
    cargo install matugen --locked
  fi
}

# awww (antes swww) pinta el wallpaper. El nombre del paquete depende de la fecha.
install_wallpaper_daemon() {
  command -v awww >/dev/null 2>&1 && return
  local pkg=""
  if pacman -Si awww >/dev/null 2>&1; then
    pkg=awww
  elif pacman -Si swww >/dev/null 2>&1; then
    pkg=swww
  fi
  if [[ -n $pkg ]]; then
    sudo pacman -S "$@" "$pkg"
  elif command -v yay >/dev/null 2>&1; then
    yay -S --needed awww
  elif command -v paru >/dev/null 2>&1; then
    paru -S --needed awww
  else
    warn "awww no está en los repositorios oficiales y no hay yay ni paru."
    warn "Instálalo a mano (https://codeberg.org/LGFae/awww); sin él no se cambia el wallpaper."
    return
  fi
  # Docky.rs llama a awww y awww-daemon; si solo existe swww, se crean alias
  if ! command -v awww >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v swww)" "$HOME/.local/bin/awww"
    ln -sf "$(command -v swww-daemon)" "$HOME/.local/bin/awww-daemon"
    ok "Alias awww -> swww en ~/.local/bin"
  fi
}

build() {
  info "Compilando Docky.rs (puede tardar unos minutos)..."
  (cd "$DOCKY_DIR" && cargo build --release)
  [[ -x $DOCKY_DIR/target/release/dockyrs ]] || die "La compilación no generó target/release/dockyrs"
  ok "Compilado: $DOCKY_DIR/target/release/dockyrs"
}

# Base de Hyprland solo si no hay configuración propia. Con un hyprland.conf
# existente, crear hyprland.lua haría que Hyprland lo ignorara.
install_hypr_base() {
  local dst="$CONFIG_HOME/hypr"
  if [[ -f $dst/hyprland.lua ]]; then
    ok "Ya tienes $dst/hyprland.lua"
    return
  fi
  if [[ -f $dst/hyprland.conf ]]; then
    warn "Tienes $dst/hyprland.conf pero no hyprland.lua; no creo uno para no desactivarlo."
    warn "Añade require(\"dockyrs\") a tu configuración en Lua (ver $dst/dockyrs.lua)."
    return
  fi
  mkdir -p "$dst"
  # Sin el arranque de Quickshell ni los atajos de volumen (los trae el drop-in de Docky)
  sed -e '/^-- @media-begin/,/^-- @media-end/d' \
    -e '/^-- @start-begin/,/^-- @start-end/d' \
    -e 's/^require("quickshell")$/require("dockyrs")/' \
    "$BASE" >"$dst/hyprland.lua"
  ok "Base de Hyprland instalada en $dst/hyprland.lua"
}

# Atajos y arranque de Docky.rs, con las rutas de este equipo
install_hypr_dropin() {
  local dst="$CONFIG_HOME/hypr" template
  mkdir -p "$dst"
  template="$(<"$HERE/dockyrs.lua.in")"
  printf '%s\n' "${template//@DIR@/$DOCKY_DIR}" >"$dst/dockyrs.lua"
  ok "Atajos escritos en $dst/dockyrs.lua"
  if [[ -f $dst/hyprland.lua ]] && ! grep -q 'require("dockyrs")' "$dst/hyprland.lua"; then
    printf '\nrequire("dockyrs")\n' >>"$dst/hyprland.lua"
    ok "Añadido require(\"dockyrs\") a $dst/hyprland.lua"
  fi
}

uninstall() {
  pkill -x dockyrs 2>/dev/null || true
  pkill -x dockyrs-notifyd 2>/dev/null || true
  rm -rf "$DOCKY_DIR"
  rm -f "$CONFIG_HOME/hypr/dockyrs.lua"
  # Alacritty vuelve a Catppuccin Mocha
  : >"$REPO_DIR/alacritty/dynamic.toml"
  ok "Docky.rs quitado y Alacritty de vuelta en Catppuccin Mocha"
  warn "No toqué hyprland.lua: quita la línea require(\"dockyrs\") a mano."
  warn "Tu configuración de Docky.rs sigue en ~/.config/dockyrs."
}

main() {
  parse_args "$@"
  check_system

  if ((UNINSTALL)); then
    uninstall
    return
  fi

  fetch_upstream
  "$HERE/patch.sh" "$DOCKY_DIR"

  if ((PATCH_ONLY)); then
    ok "Parches aplicados. Revísalos con: git -C $DOCKY_DIR diff --stat"
    return
  fi

  install_packages
  if ((!NO_BUILD)); then
    build
  fi
  mkdir -p "$HOME/Pictures/Wallpapers"
  install_hypr_base
  install_hypr_dropin

  cat <<EOM

Listo. Siguientes pasos:
  1. Inicia Hyprland (desde una TTY o tu gestor de inicio de sesión).
  2. Copia tus wallpapers a ~/Pictures/Wallpapers y ábrelos con SUPER+W.
  3. SUPER+D abre el lanzador, SUPER+V el portapapeles y SUPER+, el menú del dock.
     F8 y F9 hacen capturas y F10 graba la pantalla.
Docky.rs trae su propio demonio de notificaciones: si ya tienes otro (dunst,
mako…), quítalo para que no compitan.
EOM
}

main "$@"
