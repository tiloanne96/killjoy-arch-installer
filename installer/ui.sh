#!/usr/bin/env bash
# ui.sh — paleta y mensajes comunes del instalador. Se carga con `source`.
#
# Paleta inspirada en Killjoy (Valorant): amarillo eléctrico sobre negro y grises.
# En la consola del kernel (TERM=linux), que solo tiene 16 colores, usa el amarillo
# brillante; en terminales de 256 colores usa tonos más finos. Sin terminal o con
# NO_COLOR definida no pinta nada.

# Las variables de la paleta las usan los scripts que cargan este archivo
# shellcheck disable=SC2034

if [[ -t 1 && -t 2 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  if [[ $TERM == linux ]]; then
    C_BRAND=$'\033[1;93m' # amarillo Killjoy
    C_DIM=$'\033[0;90m'   # gris
    C_OK=$'\033[1;92m'
    C_WARN=$'\033[0;33m'
    C_ERR=$'\033[1;91m'
  else
    C_BRAND=$'\033[1;38;5;220m' # amarillo Killjoy
    C_DIM=$'\033[38;5;244m'     # gris
    C_OK=$'\033[1;38;5;114m'
    C_WARN=$'\033[38;5;208m' # naranja, para no confundirlo con el amarillo de marca
    C_ERR=$'\033[1;38;5;203m'
  fi
else
  C_RESET='' C_BOLD='' C_BRAND='' C_DIM='' C_OK='' C_WARN='' C_ERR=''
fi

info() { printf '%s::%s %s%s%s\n' "$C_BRAND" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok() { printf '%s✔%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die() {
  printf '%s✘%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2
  exit 1
}

# heading "Texto": título de una sección de menú
heading() { printf '\n%s▌ %s%s\n' "$C_BRAND" "$*" "$C_RESET"; }

# item N "texto": opción numerada de un menú
item() { printf '  %s%s)%s %s\n' "$C_BRAND" "$1" "$C_RESET" "$2"; }

# Marca que va delante de lo que se pregunta
PROMPT="${C_BRAND}›${C_RESET} "
