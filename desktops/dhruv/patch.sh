#!/usr/bin/env bash
# patch.sh <directorio-del-shell>
#
# Adapta un checkout de dhruvsharma/shell a esta configuración:
#   1. kitty → Alacritty en el shell (actualizaciones, notas, mascota, editor de atajos).
#   2. Su instalador usa --noconfirm cuando se le pasa --yes.
#
# Son reemplazos de texto literal sobre un commit concreto. Si el repo original
# cambia y alguno no encaja, el script se detiene con un error en lugar de
# dejar una instalación a medias.

set -euo pipefail

die() {
  printf '\033[1;31m✘\033[0m %s\n' "$*" >&2
  exit 1
}

TARGET="${1:-}"
[[ -n $TARGET ]] || die "uso: patch.sh <directorio-del-shell>"
[[ -f $TARGET/quickshell/shell.qml ]] || die "$TARGET no parece un checkout de dhruvsharma/shell"
command -v perl >/dev/null 2>&1 || die "falta perl (pacman -S perl)"

QS="$TARGET/quickshell"

# replace <archivo> <desde> <hasta>: reemplazo literal; falla si no encuentra el texto
replace() {
  local file=$1 from=$2 to=$3
  [[ -f $file ]] || die "no existe ${file#"$TARGET"/}"
  FROM=$from TO=$to perl -0777 -i -pe '
    BEGIN { $n = 0 }
    $n += s/\Q$ENV{FROM}\E/$ENV{TO}/g;
    END { $? = 1 unless $n }
  ' "$file" || die "el parche no encaja en ${file#"$TARGET"/}: «$from». ¿Cambió el repo? Revisa DHRUV_REF."
}

echo "Parche 1/2: kitty → Alacritty"
# Alacritty acepta --hold y -e igual que kitty
replace "$QS/services/Updates.qml" 'property string terminal: "kitty"' 'property string terminal: "alacritty"'
replace "$QS/services/Pet.qml" '["kitty", "--hold", "-e", "sh", "-c", cmd]' '["alacritty", "--hold", "-e", "sh", "-c", cmd]'
replace "$QS/services/Pet.qml" 'name: "Terminal", icon: "terminal", cmd: "kitty"' 'name: "Terminal", icon: "terminal", cmd: "alacritty"'
replace "$QS/services/Notes.qml" '["kitty", "--hold", "-e", "sh", "-c", finalCommand]' '["alacritty", "--hold", "-e", "sh", "-c", finalCommand]'
replace "$QS/modules/keybinds/BindEditor.qml" 'Command, e.g. kitty -e btop' 'Command, e.g. alacritty -e btop'
# Su lista de paquetes pide kitty; aquí va Alacritty
replace "$QS/install.sh" 'python-gobject mpv kitty' 'python-gobject mpv alacritty'

echo "Parche 2/2: instalador sin preguntas con --yes"
# Su --yes solo omite sus propias preguntas; pacman y el ayudante del AUR seguirían preguntando
# shellcheck disable=SC2016  # las comillas simples son literales a propósito
replace "$QS/install.sh" 'sudo pacman -S --needed "${pkgs[@]}"' 'sudo pacman -S --needed $( ((ASSUME_YES)) && echo --noconfirm ) "${pkgs[@]}"'
# shellcheck disable=SC2016  # las comillas simples son literales a propósito
replace "$QS/install.sh" '"$aur" -S --needed "${AUR_PKGS[@]}"' '"$aur" -S --needed $( ((ASSUME_YES)) && echo --noconfirm ) "${AUR_PKGS[@]}"'
