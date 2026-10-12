#!/usr/bin/env bash
# patch.sh <directorio-de-docky>
#
# Adapta un checkout de Volcha-Z/Docky.rs a esta configuración:
#   1. Apagar, reiniciar y suspender usan systemctl en lugar de sudo (el original
#      depende de una regla de sudoers sin contraseña y de `zzz`, que solo existe
#      en Void Linux).
#   2. La sincronización de colores con el wallpaper escribe el tema de Alacritty
#      en lugar del de kitty.
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
[[ -n $TARGET ]] || die "uso: patch.sh <directorio-de-docky>"
[[ -f $TARGET/Cargo.toml && -f $TARGET/src/power.rs ]] || die "$TARGET no parece un checkout de Docky.rs"
command -v perl >/dev/null 2>&1 || die "falta perl (pacman -S perl)"

# replace <archivo> <desde> <hasta>: reemplazo literal; falla si no encuentra el texto
replace() {
  local file=$1 from=$2 to=$3
  [[ -f $file ]] || die "no existe ${file#"$TARGET"/}"
  FROM=$from TO=$to perl -0777 -i -pe '
    BEGIN { $n = 0 }
    $n += s/\Q$ENV{FROM}\E/$ENV{TO}/g;
    END { $? = 1 unless $n }
  ' "$file" || die "el parche no encaja en ${file#"$TARGET"/}: «$from». ¿Cambió el repo? Revisa DOCKY_REF."
}

echo "Parche 1/2: energía con systemctl"
replace "$TARGET/src/power.rs" 'Command::new("sudo").args(["-n", "zzz"])' 'Command::new("systemctl").arg("suspend")'
replace "$TARGET/src/power.rs" 'Command::new("sudo").args(["-n", "reboot"])' 'Command::new("systemctl").arg("reboot")'
replace "$TARGET/src/power.rs" 'Command::new("sudo").args(["-n", "poweroff"])' 'Command::new("systemctl").arg("poweroff")'
replace "$TARGET/src/power.rs" '// ----- needs nopasswd sudoers -----' '// ----- logind permite estas acciones a la sesión activa, sin sudo -----'

echo "Parche 2/2: colores de Alacritty en lugar de kitty"
# Se conserva todo el cálculo de colores (matugen o la paleta del dock) y se
# cambia solo la salida, que va al final del script
sync="$TARGET/sync-kitty-theme.sh"
[[ -f $sync ]] || die "no existe sync-kitty-theme.sh"
# shellcheck disable=SC2016  # las comillas simples son literales a propósito
grep -q 'mkdir -p "$HOME/.config/kitty"' "$sync" || die "el parche no encaja en sync-kitty-theme.sh. ¿Cambió el repo? Revisa DOCKY_REF."
perl -0777 -i -pe 's/mkdir -p "\$HOME\/\.config\/kitty".*\z//s' "$sync"
cat "$HERE/alacritty-sync.tail.sh" >>"$sync"
