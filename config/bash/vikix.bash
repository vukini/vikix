# ~/.config/vikix/vikix.bash — managed by Vikix (a symlink into the checkout).
#
# Read by ~/.bashrc for every interactive shell. Each alias is only set
# when its program is installed, so nothing here breaks a bare system.
# Your own aliases go in ~/.bashrc, outside the "vikix" block — they
# load after this file, so they win.
#
# Type `alias` to see everything that is defined.

case $- in *i*) ;; *) return ;; esac     # interactive shells only

have() { command -v "$1" >/dev/null 2>&1; }

# --- editors ---------------------------------------------------------------
export EDITOR=${EDITOR:-nvim} VISUAL=${VISUAL:-nvim}
have nvim  && alias v='nvim'
# e: open a file in Emacs, starting an Emacs server first if none is running
have emacs && alias e='emacsclient -c -a ""'

# --- listing ---------------------------------------------------------------
if have eza; then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'           # long
  alias la='eza -la --git --group-directories-first'          # long, with hidden files
  alias lt='eza --tree --level=2 --group-directories-first'   # tree, two levels
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi
alias grep='grep --color=auto'
have bat && alias b='bat'                # cat with colour; plain `cat` is left alone

# --- moving around ---------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'

# --- packages (xbps) -------------------------------------------------------
alias xi='sudo xbps-install -S'          # install:        xi firefox
alias xu='sudo xbps-install -Su'         # update everything
alias xr='sudo xbps-remove -R'           # remove, with what it pulled in
alias xs='xbps-query -Rs'                # search the repositories
alias xl='xbps-query -f'                 # list an installed package's files

# --- services (runit) ------------------------------------------------------
alias svls='ls /var/service'             # which services are switched on
sv-on()  { sudo ln -s "/etc/sv/$1" /var/service/; }   # sv-on bluetoothd
sv-off() { sudo rm "/var/service/$1"; }              # sv-off bluetoothd

# --- git -------------------------------------------------------------------
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'

# --- the AI agent ----------------------------------------------------------
# a: Claude Code, here in this folder, after a snapshot of your files
# (vikix changes shows what it changed, vikix undo takes it back)
alias a='vikix agent'

# --- Lisp ------------------------------------------------------------------
have rlwrap && have sbcl && alias sbcl='rlwrap sbcl'   # history and arrow keys at the REPL

# --- fzf: Ctrl+R searches history, Ctrl+T picks a file ---------------------
for f in /usr/share/fzf/key-bindings.bash /usr/share/fzf/completion.bash; do
  # shellcheck disable=SC1090  # files from the fzf package, not this repo
  [ -f "$f" ] && . "$f"
done
unset f

# --- prompt: folder, then git branch when inside a repo ---------------------
__vikix_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) && printf ' (%s)' "$b"
}
PS1='\[\e[36m\]\w\[\e[33m\]$(__vikix_branch)\[\e[0m\] \$ '
