#!/usr/bin/env bash
# tests/nightlight.sh — vikix-nightlight starts gammastep at login unless
# it was switched off, toggles it, remembers off across logins, stops it
# with TERM (so the colours come back), and ignores a stale pid file.
#
# A stand-in gammastep writes down that it started and that it was
# stopped, and changes nothing on the screen.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/bin/gammastep" 2>/dev/null || true; rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/config/gammastep"
cat > "$t/bin/gammastep" <<FAKE
#!/bin/sh
echo started >> "$t/log"
trap 'echo stopped >> "$t/log"; exit 0' TERM
while :; do sleep 0.1; done
FAKE
chmod +x "$t/bin/gammastep"
cp "$here/config/gammastep/config.ini" "$t/config/gammastep/"
export PATH="$t/bin:$PATH" XDG_STATE_HOME="$t/state" XDG_CONFIG_HOME="$t/config"
nl() { sh "$here/bin/vikix-nightlight" "$@"; }
count() { grep -c "^$1" "$t/log" 2>/dev/null || true; }
settle() { sleep 0.3; }
fail=0
check() { eval "$1" || { echo "FAIL: $2"; fail=1; }; }

# A pid file left by a crash doesn't count.
mkdir -p "$t/state/vikix"; echo 999999 > "$t/state/vikix/nightlight.pid"
check '! nl status >/dev/null' "a stale pid file counted as on"

nl start; settle
check 'nl status >/dev/null' "start at login didn't start gammastep"
check '[ "$(nl status)" = "on (warm from 19:00 to 7:00)" ]' "status didn't read the times from the config: $(nl status)"
nl start; settle
check '[ "$(count started)" = 1 ]' "a second start ran a second gammastep"

out=$(nl toggle); settle
check '[ "$(count stopped)" = 1 ]' "toggle didn't stop gammastep with TERM"
check '! nl status >/dev/null' "still on after toggling off"
check '[ "$out" = "Night light: off, until you switch it on" ]' "toggle off said: $out"

nl start; settle     # the next login
check '[ "$(count started)" = 1 ]' "switched off, it started again at the next login"

out=$(nl toggle); settle
check 'nl status >/dev/null' "toggle didn't switch it back on"
check '[ "$out" = "Night light: on (warm from 19:00 to 7:00)" ]' "toggle on said: $out"
nl off >/dev/null; nl start; settle
check '! nl status >/dev/null' "off didn't last to the next login"

[ "$fail" = 0 ] && echo "nightlight: starts at login unless switched off; toggles; stops with TERM; ignores stale pids"
exit "$fail"
