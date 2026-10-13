#!/usr/bin/env bash
# first-login.sh — termina la instalación en el primer inicio de sesión.
#
# arch-install.sh deja un sistema base que arranca y un archivo con los
# argumentos para install.sh en ~/.local/state/dotfiles/pending-install. Este
# script los ejecuta con el sistema ya arrancado (con systemd y sesión de
# usuario reales). Si algo falla, el archivo se queda y se repite al volver a
# iniciar sesión, o a mano con ~/.dotfiles/installer/first-login.sh.
set -uo pipefail

PENDING="$HOME/.local/state/dotfiles/pending-install"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=installer/ui.sh
source "$REPO_DIR/installer/ui.sh"

[[ -f $PENDING ]] || {
  echo "No hay ninguna instalación pendiente."
  exit 0
}

has_network() { curl -fsI --max-time 8 https://archlinux.org >/dev/null 2>&1; }

until has_network; do
  warn "Sin conexión a internet."
  echo "Conéctate (para wifi: nmtui) y pulsa Enter para reintentar, o escribe 'q' para dejarlo para luego."
  read -r reply || exit 1
  if [[ $reply == q ]]; then
    echo "Pendiente. Se repetirá al iniciar sesión, o ejecuta: $REPO_DIR/installer/first-login.sh"
    exit 0
  fi
done

read -r -a args <"$PENDING"
info "Terminando la instalación: install.sh ${args[*]}"
if ! bash "$REPO_DIR/install.sh" "${args[@]}"; then
  warn "La instalación falló. Revisa el mensaje de arriba."
  warn "Se repetirá al volver a iniciar sesión, o ejecuta: $REPO_DIR/installer/first-login.sh"
  exit 1
fi

rm -f "$PENDING"
ok "Instalación terminada"

# Con escritorio hay pantalla de inicio de sesión (greetd); se activa solo si
# todo salió bien, para no dejar el equipo arrancando en algo roto.
if pacman -Qq greetd >/dev/null 2>&1 && [[ -f /etc/greetd/config.toml ]]; then
  sudo systemctl enable greetd.service && ok "Pantalla de inicio de sesión activada"
  echo "Reinicia para entrar al escritorio:  sudo reboot"
fi
