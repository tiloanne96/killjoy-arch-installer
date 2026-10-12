# ~/.bashrc — Oh My Bash + herramientas de desarrollo
# Overrides específicos de cada máquina: ~/.bashrc.local (no se versiona)

# Las variables de Oh My Bash (OSH_THEME, plugins…) las lee oh-my-bash.sh, no este archivo
# shellcheck disable=SC2034

# No hacer nada si la sesión no es interactiva
case $- in
  *i*) ;;
  *) return ;;
esac

# ── Oh My Bash ───────────────────────────────────────────────────────────────
export OSH="$HOME/.oh-my-bash"

# Temas: https://github.com/ohmybash/oh-my-bash/wiki/Themes
# agnoster requiere una Nerd Font (la instala install.sh)
OSH_THEME="agnoster"

OMB_USE_SUDO=true                  # Esc Esc antepone sudo al comando
OMB_PROMPT_SHOW_PYTHON_VENV=true
DISABLE_AUTO_UPDATE="true"         # actualiza manualmente con: omb update

completions=(git ssh)
aliases=(general)
plugins=(git bashmarks)

if [[ -r "$OSH/oh-my-bash.sh" ]]; then
  # shellcheck disable=SC1091
  source "$OSH/oh-my-bash.sh"
fi

# ── Entorno ──────────────────────────────────────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim
export MANPAGER='nvim +Man!'
export SUDO_PROMPT="[sudo] %u: "

for dir in "$HOME/.local/bin" "$HOME/go/bin" "$HOME/.cargo/bin"; do
  if [[ -d $dir && ":$PATH:" != *":$dir:"* ]]; then
    PATH="$dir:$PATH"
  fi
done
export PATH

# ── Historial ────────────────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE="ls:ll:cd:pwd:exit:history:clear:cls"   # no guardar comandos triviales
HISTTIMEFORMAT="%F %T "
shopt -s histappend cmdhist checkwinsize globstar autocd cdspell dirspell 2>/dev/null

# ── Alias ────────────────────────────────────────────────────────────────────
alias vim='nvim'
alias vi='nvim'
alias v='nvim'

alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias cls='clear'

# Actualiza los paquetes oficiales y, si tienes yay, también los del AUR
update() {
  sudo pacman -Syu || return
  if command -v yay >/dev/null 2>&1; then
    yay -Syu
  fi
}

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons'
fi

# cat con resaltado de sintaxis; base16 usa los colores de la terminal
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --theme=base16 --style=plain --paging=never'
fi

# ── fzf (tema Catppuccin Mocha) ──────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS=" \
--height=40% --layout=reverse --border \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
  eval "$(fzf --bash)"   # Ctrl+R historial, Ctrl+T archivos, Alt+C directorios
fi

# ── Navegación y versiones de lenguajes ──────────────────────────────────────
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"   # z <dir>
command -v mise   >/dev/null 2>&1 && eval "$(mise activate bash)" # Ruby, Node, Go…

# ── tmux ─────────────────────────────────────────────────────────────────────
# tm: elige un directorio de zoxide con fzf y abre (o retoma) su sesión de tmux
tm() {
  local cmd dir name
  for cmd in tmux fzf zoxide; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "tm necesita $cmd" >&2; return 1; }
  done
  dir="$(zoxide query --list | fzf --prompt='sesión> ')" || return 0
  [[ -n $dir ]] || return 0
  name="$(basename "$dir")"
  name="${name//[.:]/_}"   # tmux no admite '.' ni ':' en el nombre
  # El prefijo '=' exige coincidencia exacta del nombre
  tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$dir"
  if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t "=$name"
  else
    tmux attach-session -t "=$name"
  fi
}

# ── Overrides locales ────────────────────────────────────────────────────────
# shellcheck disable=SC1090,SC1091
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
