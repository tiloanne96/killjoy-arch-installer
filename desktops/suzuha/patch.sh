#!/usr/bin/env bash
# patch.sh <directorio-de-suzuha>
#
# Adapta un checkout de MystiaFin/suzuha a esta configuración:
#   1. Alacritty entra en la integración de terminales (que solo conocía kitty y
#      foot): escribe ~/.config/alacritty/dynamic.toml con los colores del shell.
#   2. Esa integración viene activada, para que Alacritty siga al wallpaper.
#   3. El selector de proyectos de tmux abre Alacritty con -e (el original usaba
#      `--`, que es la sintaxis de foot).
#
# Son reemplazos de texto literal sobre un commit concreto. Si el repo original
# cambia y alguno no encaja, el script se detiene con un error en lugar de
# dejar una instalación a medias.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

TARGET="${1:-}"
[[ -n $TARGET ]] || die "uso: patch.sh <directorio-de-suzuha>"
[[ -f $TARGET/src/integrations/terminal.rs ]] || die "$TARGET no parece un checkout de suzuha"
command -v perl >/dev/null 2>&1 || die "falta perl (pacman -S perl)"

# replace <archivo> <desde> <hasta>: reemplazo literal; falla si no encuentra el texto
replace() {
  local file=$1 from=$2 to=$3
  [[ -f $file ]] || die "no existe ${file#"$TARGET"/}"
  FROM=$from TO=$to perl -0777 -i -pe '
    BEGIN { $n = 0 }
    $n += s/\Q$ENV{FROM}\E/$ENV{TO}/g;
    END { $? = 1 unless $n }
  ' "$file" || die "el parche no encaja en ${file#"$TARGET"/}: «$from». ¿Cambió el repo? Revisa SUZUHA_REF."
}

terminal="$TARGET/src/integrations/terminal.rs"

echo "Parche 1/3: Alacritty en la integración de terminales"
replace "$terminal" 'use super::{hex, state_home, write};' 'use super::{config_home, hex, state_home, write};'
replace "$terminal" '    write(&foot, &foot_config(theme, &colors));
' '    write(&foot, &foot_config(theme, &colors));
    write(&format!("{}/alacritty/dynamic.toml", config_home()), &alacritty_config(theme, &colors));
'
cat "$HERE/alacritty.rs.in" >>"$terminal"
replace "$TARGET/src/settings/pages/integrations.rs" '"Kitty and foot"' '"Alacritty, kitty and foot"'

echo "Parche 2/3: integración de terminales activada por defecto"
replace "$TARGET/src/settings/store.rs" '("integration_terminal", "false")' '("integration_terminal", "true")'

echo "Parche 3/3: selector de proyectos de tmux con Alacritty"
replace "$TARGET/src/overlay/launcher/results.rs" "{terminal} -- tmux attach-session" "{terminal} -e tmux attach-session"
