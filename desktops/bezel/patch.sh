#!/usr/bin/env bash
# patch.sh <directorio-de-bezel>
#
# Adapta un checkout de bezel-hyprland a esta configuración:
#   1. kitty → Alacritty (terminal, lanzadores de la barra, reglas de ventana).
#   2. Paleta de bezel → Catppuccin Mocha (ver palette.map).
#
# Los parches son reemplazos de texto literal sobre un commit concreto. Si bezel
# cambia y alguno no encaja, el script se detiene con un error en lugar de
# dejar una instalación a medias.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

TARGET="${1:-}"
[[ -n $TARGET ]] || die "uso: patch.sh <directorio-de-bezel>"
[[ -d $TARGET/config/quickshell ]] || die "$TARGET no parece un checkout de bezel-hyprland"
command -v perl >/dev/null 2>&1 || die "falta perl (pacman -S perl)"

CFG="$TARGET/config"

# replace <archivo> <desde> <hasta>: reemplazo literal; falla si no encuentra el texto
replace() {
  local file=$1 from=$2 to=$3
  [[ -f $file ]] || die "no existe ${file#"$TARGET"/}"
  FROM=$from TO=$to perl -0777 -i -pe '
    BEGIN { $n = 0 }
    $n += s/\Q$ENV{FROM}\E/$ENV{TO}/g;
    END { $? = 1 unless $n }
  ' "$file" || die "el parche no encaja en ${file#"$TARGET"/}: «$from». ¿Cambió bezel? Revisa BEZEL_REF."
}

echo "Parche 1/2: kitty → Alacritty"

# Hyprland: terminal y gestor de archivos
replace "$CFG/hypr/hyprland.lua" '"kitty -1",' '"alacritty",'
replace "$CFG/hypr/hyprland.lua" '"kitty -1 --class yazi -e yazi"' '"alacritty --class yazi -e yazi"'
replace "$CFG/hypr/bezel/init.lua" '"kitty -1",' '"alacritty",'
replace "$CFG/hypr/bezel/init.lua" '"kitty -1 --class yazi -e yazi"' '"alacritty --class yazi -e yazi"'
replace "$CFG/hypr/bezel/init.lua" '-- -1: one kitty process for all windows (less RAM)' '-- patched: kitty -> Alacritty'
# El "swallow" (un visor de imágenes ocupa el lugar de la terminal) usa la clase de la ventana
replace "$CFG/hypr/bezel/look.lua" '"^(kitty|yazi)$"' '"^(Alacritty|yazi)$"'

# Quickshell: comandos lanzados desde la barra, el launcher y las actualizaciones.
# Se conserva la clase "kitty-float", que es solo un nombre y la usan las reglas de ventana.
replace "$CFG/quickshell/config/Config.qml" '"kitty -1 --class kitty-float -e ' '"alacritty --class kitty-float -e '
replace "$CFG/quickshell/modules/shell/Launcher.qml" '["kitty", "-1", "--class", "kitty-float", "-e"' '["alacritty", "--class", "kitty-float", "-e"'
replace "$CFG/quickshell/services/Updates.qml" '["kitty", "--class", "kitty-float", "-e"' '["alacritty", "--class", "kitty-float", "-e"'
replace "$CFG/quickshell/services/Apps.qml" '["kitty", "-1", "-e",' '["alacritty", "-e",'

# Paquetes y componentes del instalador de bezel
replace "$TARGET/packages/core.txt" $'\nkitty\n' $'\nalacritty\n'
replace "$TARGET/lib/common.sh" ' quickshell/ kitty/ gtk-3.0/' ' quickshell/ gtk-3.0/'
replace "$TARGET/lib/common.sh" 'Quickshell shell, kitty, GTK/Qt theme' 'Quickshell shell, GTK/Qt theme (Alacritty as terminal)'
rm -rf "$CFG/kitty"

echo "Parche 2/2: paleta Catppuccin Mocha"
grep -rIlZE '#[0-9a-fA-F]{6}|rgba?\(' "$CFG" | xargs -0 perl "$HERE/recolor.pl" "$HERE/palette.map"

# imv escribe los colores sin '#', un formato que recolor.pl no reconoce.
# Son los mismos valores de palette.map (1e2430 → 1e1e2e, 151923 → 181825).
replace "$CFG/imv/config" 'background = 1e2430' 'background = 1e1e2e'
replace "$CFG/imv/config" 'overlay_background_color = 151923' 'overlay_background_color = 181825'
