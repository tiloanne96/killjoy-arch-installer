#!/usr/bin/env bash
# desktops/lucid/install.sh — instala Lucid, un shell de escritorio para Hyprland
# hecho con Quickshell (Material 3, colores del wallpaper): barra, dock con
# lanzador, centro de control, selector de wallpapers, pantalla de bloqueo,
# widgets de escritorio y una app de Ajustes. Alacritty sigue sus colores.
#
# Uso: desktops/lucid/install.sh [opciones]
#   -y, --yes          no preguntar (acepta lo que pregunta el instalador de Lucid)
#   --apps             instalar también las apps que el dock trae ancladas
#                      (Zen, VSCodium, Spotify, Steam, Vesktop, Proton VPN…)
#   --no-wallpapers    no copiar sus wallpapers (unos 180 MB) a ~/Pictures/wallpapers
#   --patch-only       descargar y parchear, pero no instalar nada
#   --uninstall        quitar Lucid y devolver Alacritty a Catppuccin Mocha
#   -h, --help         mostrar esta ayuda
#
# Lucid (MIT) trae su propio instalador y una configuración completa de
# Hyprland (atajos, reglas, blur y arranque). No se copia código a este repo: se
# descarga el original, fijado a un commit probado, a ~/.local/share/dotfiles/lucid,
# se le aplican los parches de patch.sh y se ejecuta su instalador con estas
# opciones: --no-look (no toca kitty, starship, VSCode ni el tema GTK), --no-plugins
# (no compila el cursor que se inclina) y, salvo con --apps, --no-apps.
#
# Ojo: su configuración de Hyprland sustituye a la tuya. La tuya se copia antes a
# ~/.config/hypr.backup-<fecha>. No se puede usar a la vez que bezel, dhruv, docky
# o suzuha.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"

LUCID_URL="https://github.com/Sn3akyy1/lucid"
# Commit probado. Para actualizar, cambia el hash y comprueba que patch.sh siga encajando.
LUCID_REF="e662954f73a39275f214923bb4dab6c85b3800ba"
LUCID_DIR="${LUCID_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/lucid}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

ASSUME_YES=0
WITH_APPS=0
NO_WALLPAPERS=0
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
      --apps) WITH_APPS=1 ;;
      --no-wallpapers) NO_WALLPAPERS=1 ;;
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

# Deja LUCID_DIR exactamente en LUCID_REF, sin restos de parches anteriores
fetch_upstream() {
  info "Descargando Lucid ($LUCID_REF)..."
  if [[ ! -d $LUCID_DIR/.git ]]; then
    mkdir -p "$LUCID_DIR"
    git -C "$LUCID_DIR" init -q
    git -C "$LUCID_DIR" remote add origin "$LUCID_URL"
  fi
  git -C "$LUCID_DIR" fetch -q --depth 1 origin "$LUCID_REF"
  git -C "$LUCID_DIR" checkout -q --force FETCH_HEAD
  git -C "$LUCID_DIR" clean -fdq
  ok "Lucid en $LUCID_DIR"
}

# Su plantilla de matugen escribe ~/.config/alacritty/dynamic.toml. Si ese
# directorio no existe, el instalador de Lucid lo crearía como directorio normal y
# luego install.sh de este repo lo apartaría a una copia de seguridad; por eso se
# enlaza antes al de este repo.
prepare_alacritty() {
  if [[ ! -e $CONFIG_HOME/alacritty && ! -L $CONFIG_HOME/alacritty ]]; then
    mkdir -p "$CONFIG_HOME"
    [[ -e $REPO_DIR/alacritty/dynamic.toml ]] || : >"$REPO_DIR/alacritty/dynamic.toml"
    ln -s "$REPO_DIR/alacritty" "$CONFIG_HOME/alacritty"
    ok "Enlazado: $CONFIG_HOME/alacritty -> $REPO_DIR/alacritty"
  fi
}

run_upstream() {
  local flags=(--no-look --no-plugins)
  ((WITH_APPS)) || flags+=(--no-apps)
  ((NO_WALLPAPERS)) && flags+=(--no-wallpapers)
  ((ASSUME_YES)) && flags+=(--yes)

  # -Syu sincroniza antes; su instalador desconfía de una base de datos de pacman vieja
  info "Actualizando el sistema..."
  if ((ASSUME_YES)); then
    sudo pacman -Syu --noconfirm
  else
    sudo pacman -Syu
  fi

  prepare_alacritty
  info "Ejecutando el instalador de Lucid (${flags[*]})..."
  "$LUCID_DIR/install.sh" "${flags[@]}"
}

uninstall() {
  [[ -x $LUCID_DIR/uninstall.sh ]] || fetch_upstream
  local flags=()
  ((ASSUME_YES)) && flags+=(--yes)
  "$LUCID_DIR/uninstall.sh" "${flags[@]}"
  # Alacritty vuelve a Catppuccin Mocha
  : >"$REPO_DIR/alacritty/dynamic.toml"
  ok "Alacritty de vuelta en Catppuccin Mocha"
  warn "Tu configuración de Hyprland sigue siendo la de Lucid; la anterior está en ~/.config/hypr.backup-*."
  warn "$LUCID_DIR no se borró: puedes quitarlo cuando quieras."
}

main() {
  parse_args "$@"
  check_system

  if ((UNINSTALL)); then
    uninstall
    return
  fi

  fetch_upstream
  "$HERE/patch.sh" "$LUCID_DIR"

  if ((PATCH_ONLY)); then
    ok "Parches aplicados. Revísalos con: git -C $LUCID_DIR diff --stat"
    return
  fi

  run_upstream

  cat <<EOM

Listo. Siguientes pasos:
  1. Ejecuta \`hyprctl reload\` o cierra sesión y vuelve a entrar.
  2. Elige un wallpaper en Ajustes → General (SUPER+S) o con SUPER+B: eso genera la paleta.
  3. SUPER abre el lanzador, SUPER+Q o F9 una terminal, SUPER+/ muestra todos los atajos,
     SUPER+Escape la pantalla de sesión y F10 bloquea.
EOM
}

main "$@"
