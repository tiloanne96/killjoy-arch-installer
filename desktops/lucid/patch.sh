#!/usr/bin/env bash
# patch.sh <directorio-de-lucid>
#
# Adapta un checkout de Sn3akyy1/lucid a esta configuración:
#   1. La terminal es Alacritty en lugar de kitty: el atajo de terminal (F9, y
#      además SUPER+Q como en el resto de escritorios de este repo), el editor de
#      respaldo del explorador y los paquetes que instala su instalador.
#   2. Alacritty sigue los colores del tema o del wallpaper: se añade una
#      plantilla de matugen que escribe ~/.config/alacritty/dynamic.toml, y se
#      registra donde Lucid registra las suyas (instalador y Ajustes → Tema).
#   3. Su instalador ya no instala fish ni starship: usas Oh My Bash.
#
# Son reemplazos de texto literal sobre un commit concreto. Si el repo original
# cambia y alguno no encaja, el script se detiene con un error en lugar de
# dejar una instalación a medias.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"

die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

TARGET="${1:-}"
[[ -n $TARGET ]] || die "uso: patch.sh <directorio-de-lucid>"
[[ -f $TARGET/shell.qml && -f $TARGET/install.sh ]] || die "$TARGET no parece un checkout de Lucid"
command -v perl >/dev/null 2>&1 || die "falta perl (pacman -S perl)"

# replace <archivo> <desde> <hasta>: reemplazo literal; falla si no encuentra el texto
replace() {
  local file=$1 from=$2 to=$3
  [[ -f $file ]] || die "no existe ${file#"$TARGET"/}"
  FROM=$from TO=$to perl -0777 -i -pe '
    BEGIN { $n = 0 }
    $n += s/\Q$ENV{FROM}\E/$ENV{TO}/g;
    END { $? = 1 unless $n }
  ' "$file" || die "el parche no encaja en ${file#"$TARGET"/}: «$from». ¿Cambió el repo? Revisa LUCID_REF."
}

echo "Parche 1/3: Alacritty como terminal"
replace "$TARGET/support/hypr/modules/binds.lua" 'keys = "F9", type = "exec", cmd = "kitty"' 'keys = "F9", type = "exec", cmd = "alacritty"'
replace "$TARGET/support/hypr/keybinds.json" '"desc": "Terminal", "category": "Function keys", "type": "exec", "cmd": "kitty", "opts": { "locked": true } },' '"desc": "Terminal", "category": "Function keys", "type": "exec", "cmd": "alacritty", "opts": { "locked": true } },
    { "id": "terminal-q", "keys": "SUPER + Q", "desc": "Terminal", "category": "Apps", "type": "exec", "cmd": "alacritty" },'
replace "$TARGET/Keybinds.qml" 'exec kitty -e' 'exec alacritty -e'
replace "$TARGET/install.sh" '    kitty nautilus playerctl gnome-calculator
    starship fish ttf-jetbrains-mono-nerd' '    alacritty nautilus playerctl gnome-calculator
    ttf-jetbrains-mono-nerd'
replace "$TARGET/install.sh" 'for c in kitty nautilus playerctl' 'for c in alacritty nautilus playerctl'

echo "Parche 2/3: colores de Alacritty con matugen"
cp "$REPO_DIR/desktops/matugen-alacritty.toml" "$TARGET/support/matugen/templates/alacritty.toml"
replace "$TARGET/install.sh" "    add_template kitty          \"\$TPL/kitty.conf\"              '~/.config/kitty/matugen-colors.conf' \"cmd:kitty\" 'killall -SIGUSR1 kitty 2>/dev/null || true'
" "    add_template kitty          \"\$TPL/kitty.conf\"              '~/.config/kitty/matugen-colors.conf' \"cmd:kitty\" 'killall -SIGUSR1 kitty 2>/dev/null || true'
    add_template alacritty      \"\$TPL/alacritty.toml\"          '~/.config/alacritty/dynamic.toml' \"cmd:alacritty\"
"
replace "$TARGET/support/lucid/templates.py" '        ("starship", "Starship prompt"' '        ("alacritty", "Alacritty", "alacritty.toml", "~/.config/alacritty/dynamic.toml", "cmd:alacritty", ""),
        ("starship", "Starship prompt"'

echo "Parche 3/3: sin el aspecto de kitty, fish y starship"
# El instalador pregunta antes de aplicar «el aspecto» (kitty, starship, VSCode,
# GTK); install.sh de este repo lo desactiva con --no-look. Aquí solo se comprueba
# que esa opción exista, para que un cambio del original no la deje sin efecto.
grep -q -- '--no-look)' "$TARGET/install.sh" || die "install.sh ya no tiene --no-look. ¿Cambió el repo? Revisa LUCID_REF."
