#!/usr/bin/env bash
# components/wallpaper-picker/install.sh — instala hyprquickpaper, un selector de
# wallpapers con teclado (Quickshell), y lo deja listo con swaybg.
#
# Uso: components/wallpaper-picker/install.sh [opciones]
#   -y, --yes      no pedir confirmación a pacman
#   --uninstall    borrar el selector (no toca tus wallpapers)
#   -h, --help     mostrar esta ayuda
#
# Funciona en Hyprland, niri, sway y river (cualquier compositor con
# wlr-layer-shell); en X11 y KDE no. No hace falta si usas desktops/dhruv, que ya
# trae su propio selector.
#
# Descarga ujjalsigdel/hyprquickpaper (MIT), fijado a un commit probado, a
# ~/.local/share/dotfiles/hyprquickpaper y deja su configuración lista. No se
# edita ningún archivo de tu compositor: al final se imprimen las líneas de
# atajo y de inicio que tienes que añadir. Los comandos son:
#   wallpaper-picker             abrir el selector (bin/wallpaper-picker)
#   wallpaper-picker settings    elegir el diseño
#   wallpaper-restore            volver a poner el último wallpaper al iniciar sesión

set -euo pipefail


HQP_URL="https://github.com/ujjalsigdel/hyprquickpaper"
# Commit probado. Para actualizar, cambia el hash y revisa los ajustes de configure().
HQP_REF="0c2de83fe2734ea938ea06727b2722f275f7c412"
HQP_DIR="${HQP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/hyprquickpaper}"
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers}"

PACKAGES=(quickshell qt6-5compat jq imagemagick swaybg)

ASSUME_YES=0
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
  [[ $EUID -ne 0 ]] || die "No lo ejecutes como root; usará sudo cuando haga falta."
  [[ -f /etc/arch-release ]] || die "Este script está pensado para Arch Linux."
}

install_packages() {
  info "Instalando paquetes con pacman..."
  local flags=(--needed)
  if ((ASSUME_YES)); then
    flags+=(--noconfirm)
  fi
  sudo pacman -Syu "${flags[@]}" "${PACKAGES[@]}"
}

# Deja HQP_DIR exactamente en HQP_REF. config.json es lo único que el selector
# modifica (al cambiar de diseño), así que se conserva entre ejecuciones.
fetch_upstream() {
  local saved=""
  info "Descargando hyprquickpaper ($HQP_REF)..."
  if [[ -f $HQP_DIR/config.json ]]; then
    saved="$(mktemp)"
    cp "$HQP_DIR/config.json" "$saved"
  fi
  if [[ ! -d $HQP_DIR/.git ]]; then
    mkdir -p "$HQP_DIR"
    git -C "$HQP_DIR" init -q
    git -C "$HQP_DIR" remote add origin "$HQP_URL"
  fi
  git -C "$HQP_DIR" fetch -q --depth 1 origin "$HQP_REF"
  git -C "$HQP_DIR" checkout -q --force FETCH_HEAD
  git -C "$HQP_DIR" clean -fdq
  if [[ -n $saved ]]; then
    mv "$saved" "$HQP_DIR/config.json"
    ok "Conservada tu configuración anterior"
  else
    configure
  fi
  ok "Selector en $HQP_DIR"
}

# Ajustes iniciales de config.json; solo se aplican la primera vez
configure() {
  local config="$HQP_DIR/config.json" tmp
  tmp="$(mktemp)"
  # swaybg explícito: con "auto" el primer wallpaper fallaría porque todavía no
  # hay ningún demonio en marcha. El color de borde es el mauve de Catppuccin.
  jq --arg dir "$WALLPAPERS_DIR/" '
      .wallpaper_path = $dir
      | .wallpaper_tool = "swaybg"
      | .border_color = "#cba6f7"
      | .notify_on_apply = false
    ' "$config" >"$tmp" || die "No pude ajustar config.json"
  mv "$tmp" "$config"
}

make_thumbnails() {
  mkdir -p "$WALLPAPERS_DIR"
  if ! find "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | grep -q .; then
    warn "No hay imágenes en $WALLPAPERS_DIR; copia ahí tus wallpapers."
    return
  fi
  info "Generando miniaturas..."
  bash "$HQP_DIR/cache.sh" "$HQP_DIR" >/dev/null ||
    warn "No terminé de generar las miniaturas; se harán al abrir el selector."
}

print_next_steps() {
  cat <<EOM

Listo. Falta añadir a tu compositor un atajo y el arranque (no edito tu configuración):

  Hyprland (hyprland.lua):
    hl.bind("SUPER + W", hl.dsp.exec_cmd("wallpaper-picker"))
    hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("wallpaper-picker settings"))
    hl.on("hyprland.start", function() hl.exec_cmd("wallpaper-restore") end)

  Hyprland (hyprland.conf):
    bind = SUPER, W, exec, wallpaper-picker
    bind = SUPER SHIFT, W, exec, wallpaper-picker settings
    exec-once = wallpaper-restore

  niri (config.kdl):
    binds { Mod+W { spawn "wallpaper-picker"; } }
    spawn-at-startup "wallpaper-restore"

Teclas del selector: h/l o flechas para moverte, u/d para saltar, Enter para
aplicar y Esc para cerrar. Wallpapers en: $WALLPAPERS_DIR
Videos: instala ffmpeg y mpvpaper (AUR).
EOM
}

uninstall() {
  rm -rf "$HQP_DIR"
  ok "Selector borrado. Tus wallpapers siguen en $WALLPAPERS_DIR"
  warn "Quita de tu compositor los atajos y wallpaper-restore."
}

main() {
  parse_args "$@"
  if ((UNINSTALL)); then
    uninstall
    return
  fi
  check_system
  install_packages
  fetch_upstream
  make_thumbnails
  print_next_steps
}

main "$@"
