# ~/.config/vikix/vikix.bash — managed by Vikix (a symlink into the checkout).
#
# Read by ~/.bashrc for every interactive shell. Each alias is only set
# when its program is installed, so nothing here breaks a bare system.
# The line that reads this file sits at the top of ~/.bashrc, so your own
# aliases, anywhere below it, load later and win.
#
# Type `alias` to see everything that is defined.

case $- in *i*) ;; *) return ;; esac     # interactive shells only

have() { command -v "$1" >/dev/null 2>&1; }

# --- history ---------------------------------------------------------------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups         # no duplicates, nor lines starting with a space
shopt -s histappend                      # several terminals add to one history
shopt -s checkwinsize                    # keep LINES/COLUMNS right after a resize

# --- editors ---------------------------------------------------------------
export EDITOR=${EDITOR:-nvim} VISUAL=${VISUAL:-nvim}
if have nvim; then
  alias v='nvim'
  alias nvd='nvim -d'                    # diff two files side by side
fi
if have emacs; then
  # e: open a file in Emacs, starting an Emacs server first if none is running
  alias e='emacsclient -c -a ""'
  alias eq='emacs -Q -nw'                # Emacs with no config: for debugging it
  alias ekill="emacsclient -e '(kill-emacs)'"
fi
alias r='source ~/.bashrc'               # reload after editing it

# emacs-restart: stop the Emacs daemon and start a new one, e.g. after
# changing the config. Refuses while a buffer has unsaved changes.
# (The new daemon is not part of the login session, so it outlives a
# logout; logging out and in restarts Emacs too.)
emacs-restart() {
  local unsaved i=0
  unsaved=$(emacsclient -e '(delq nil (mapcar (lambda (b)
                              (and (buffer-file-name b) (buffer-modified-p b)
                                   (buffer-file-name b)))
                            (buffer-list)))' 2>/dev/null)
  if [ -n "$unsaved" ] && [ "$unsaved" != nil ]; then
    echo "unsaved buffers, not restarting: $unsaved" >&2
    return 1
  fi
  emacsclient -e '(kill-emacs)' >/dev/null 2>&1
  while pgrep -u "$USER" -f 'emacs.*--(fg-)?daemon' >/dev/null; do
    i=$((i + 1))
    [ "$i" -gt 40 ] && { echo "the Emacs daemon did not stop" >&2; return 1; }
    sleep 0.25
  done
  echo "starting Emacs (config errors, if any, show here)"
  emacs --daemon && emacsclient -e '(format "Emacs %s, config loaded in %s" emacs-version (emacs-init-time))'
}

# --- listing ---------------------------------------------------------------
if have eza; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l --git --group-directories-first --icons=auto'    # long
  alias la='eza -la --git --group-directories-first --icons=auto'   # long, with hidden files
  alias lt='eza --tree --level=2 --group-directories-first'         # tree, two levels
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi
alias grep='grep --color=auto'
have bat && alias b='bat'                # cat with colour; plain `cat` is left alone

# --- moving around ---------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias cd-='cd -'                         # back to the previous folder
alias d='dirs -v'                        # the folder stack, numbered (pushd/popd)
# z: cd by a remembered part of the name (z proj); zi picks from a list
have zoxide && eval "$(zoxide init bash)"

# y: yazi, the file manager; quit with q and the shell is left in the
# folder you were looking at (Q quits without moving). A function, not an
# alias: only the shell itself can change its own folder.
if have yazi; then
  y() {
    local tmp cwd
    tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
    yazi "$@" --cwd-file="$tmp"
    cwd=$(command cat -- "$tmp" 2>/dev/null)
    rm -f -- "$tmp"
    if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then builtin cd -- "$cwd"; fi
  }
fi

# --- files and processes ---------------------------------------------------
alias mkd='mkdir -p'
alias cpr='cp -r'
alias chx='chmod +x'
alias xo='xdg-open'                      # open with the usual program
alias psg='ps aux | grep'                # psg firefox
alias hg='history | grep'                # hg xbps

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
# Not `gs` or `gp`: those are Ghostscript and PARI/GP, real commands.
alias g='git'
alias gst='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gcm='git commit -m'                # gcm "message"
alias gca='git commit -a -m'             # every changed file, with a message
alias gamend='git commit --amend --no-edit'
alias gundo='git reset --soft HEAD~1'    # undo the last commit, keep its changes staged
alias gwip='git add -A && git commit -m wip'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch -vv'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -30'
alias gps='git push'
alias gpl='git pull --ff-only'
alias gf='git fetch --all --prune'
alias gr='git remote -v'
alias gsh='git stash'
alias gshp='git stash pop'
have lazygit && alias lg='lazygit'       # git in a terminal UI

# --- the AI agent ----------------------------------------------------------
# a: Claude Code, here in this folder, after a snapshot of your files
# (vikix changes shows what it changed, vikix undo takes it back)
alias a='vikix agent'

# --- languages -------------------------------------------------------------
have rlwrap && have sbcl && alias sbcl='rlwrap sbcl'   # history and arrow keys at the REPL
alias activate='. .venv/bin/activate'    # the Python virtual environment in this folder

# --- fzf: Ctrl+T picks a file, Alt+C a folder ------------------------------
for f in /usr/share/fzf/key-bindings.bash /usr/share/fzf/completion.bash; do
  # shellcheck disable=SC1090  # files from the fzf package, not this repo
  [ -f "$f" ] && . "$f"
done
unset f

# --- atuin: Ctrl+R searches all your history, across terminals -------------
# Loaded after fzf, so Ctrl+R is atuin's. The Up arrow keeps its usual
# meaning. atuin needs bash-preexec to see each command as it runs.
if have atuin && [ -f /usr/bin/bash-preexec.sh ]; then
  # shellcheck disable=SC1091  # from the bash-preexec package
  . /usr/bin/bash-preexec.sh
  eval "$(atuin init bash --disable-up-arrow)"
fi

# --- prompt: folder, then git branch when inside a repo ---------------------
__vikix_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) && printf ' (%s)' "$b"
}
PS1='\[\e[36m\]\w\[\e[33m\]$(__vikix_branch)\[\e[0m\] \$ '
