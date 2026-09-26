#!/usr/bin/env bash
# 60-login — how you get from the login prompt to StumpWM.
#
# No display manager: you log in on the text console and Vikix starts
# X for you, but only on tty1. The other consoles (Ctrl+Alt+F2 ...) stay
# plain text, so if the desktop ever fails to start you can still log in
# there and fix it.
#
# Marked blocks (re-running replaces them, never duplicates):
#   ~/.bash_profile  vikix path    puts ~/.local/bin on PATH
#                    vikix bashrc  reads ~/.bashrc, if the profile doesn't already
#                    vikix startx  starts X after login on tty1
#   ~/.bashrc        vikix         reads ~/.config/vikix/vikix.bash (aliases, prompt)

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

profile="$HOME/.bash_profile"

# shellcheck disable=SC2016  # the $ signs are for the profile, not for now
ensure_block "$profile" path \
'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH'

# A login shell reads only ~/.bash_profile, so it has to pull in ~/.bashrc
# for the aliases. Void's default profile already does; add it if yours doesn't.
# shellcheck disable=SC2016
if grep -v '^[[:space:]]*#' "$profile" 2>/dev/null | grep -q '\.bashrc'; then
  :   # already reads it
else
  ensure_block "$profile" bashrc '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'
fi

# shellcheck disable=SC2016
ensure_block "$HOME/.bashrc" aliases \
'[ -f "$HOME/.config/vikix/vikix.bash" ] && . "$HOME/.config/vikix/vikix.bash"'

# shellcheck disable=SC2016
ensure_block "$profile" startx \
'if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
  exec startx
fi'

say "log in on tty1 and the desktop starts"
