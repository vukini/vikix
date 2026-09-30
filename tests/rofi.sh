#!/usr/bin/env bash
# tests/rofi.sh — vikix-rofi opens the emoji picker and the calculator with
# Vikix's keys, the calculator's Enter really copies the answer, and a
# missing plugin gives a notification instead of a silent failure.
#
# rofi, xclip and notify-send are stand-ins that write down what they were
# asked; the plugins are empty files in a made-up folder.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/plugins"
log="$t/log"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
# rofi: one argument per line, so the test can pick them out.
stub rofi        "for a; do echo \"\$a\"; done > $t/rofi-args"
stub xclip       "echo \"xclip \$*\" >> $log; cat > $t/clipboard"
stub notify-send "echo \"notify \$*\" >> $log"
export PATH="$t/bin:$PATH" VIKIX_ROFI_PLUGINS="$t/plugins"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
pick() { : > "$log"; rm -f "$t/rofi-args"; sh "$here/bin/vikix-rofi" "$@"; }
# arg NAME — the value rofi got after the option NAME
arg() { grep -A1 -x -- "$1" "$t/rofi-args" | sed -n 2p; }

# --- a plugin missing ---------------------------------------------------------
if pick emoji 2>/dev/null; then echo "FAIL: without rofi-emoji it should fail"; fail=1; fi
check "without rofi-emoji rofi shouldn't start" test ! -e "$t/rofi-args"
check "without rofi-emoji it should say what to install" grep -q 'notify.*rofi-emoji' "$log"
if pick calc 2>/dev/null; then echo "FAIL: without rofi-calc it should fail"; fail=1; fi
check "without rofi-calc it should say what to install" grep -q 'notify.*rofi-calc' "$log"

# --- with the plugins -----------------------------------------------------------
touch "$t/plugins/emoji.so" "$t/plugins/libcalc.so"
pick emoji
check "the emoji mode isn't shown" test "$(arg -show)" = emoji
check "Ctrl+c doesn't copy the emoji" test "$(arg -kb-custom-1)" = Control+c
check "rofi's own copy key still takes Ctrl+c" test -z "$(arg -kb-secondary-copy)"

pick calc
check "the calc mode isn't shown" test "$(arg -show)" = calc
check "Enter doesn't run the copy command" test "$(arg -kb-accept-custom)" = Return,KP_Enter
check "Ctrl+Enter doesn't keep the answer in the history" test "$(arg -kb-accept-entry)" = Control+Return
# The command rofi-calc would run on Enter, with an answer filled in.
command=$(arg -calc-command)
sh -c "${command//\{result\}/40.8}"
check "the answer doesn't go to the clipboard" grep -qx 'xclip -selection clipboard' "$log"
check "the clipboard should hold the answer and nothing more" test "$(od -An -c "$t/clipboard" | tr -d ' ')" = 40.8

if pick nonsense 2>/dev/null; then echo "FAIL: an unknown mode should fail"; fail=1; fi

[ "$fail" = 0 ] && echo "rofi: emoji and calculator open with Vikix's keys; Enter copies the answer; a missing plugin is named"
exit "$fail"
