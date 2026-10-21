#!/usr/bin/env bash
# tests/session.sh — vikix-session falls back to the StumpWM before when the
# new one dies at once, and only then.
#
# The session is run whole, in a made-up home, with a PATH of stand-ins
# only (every program it starts is missing or stood in for: nothing of the
# real desktop, pipewire or dunst, is touched), and ~/.local/bin/stumpwm a
# script that does what the case asks. The StumpWM before, stumpwm.prev,
# is started when the new one exits non-zero within VIKIX_WM_FAIL_SECONDS
# (20 at a login; 3 here), with a notification and a note for vikix
# doctor; not after a clean exit, not after a desktop that ran a while,
# and not when there is no image before. The note goes at the next login.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR SSH_AUTH_SOCK
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
export HOME="$t/home"
export DISPLAY=:7 DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/bus   # a display and a bus that aren't there
bin="$HOME/.local/bin"; state="$HOME/.local/state/vikix"
mkdir -p "$bin" "$t/bin"
# The PATH: the few tools the script and the checks use, and a stand-in
# for notify-send, so the fallback can tell. Every other program is "not
# found", which the session (no set -e) goes past.
for tool in date mkdir chmod mv readlink dirname cat printf grep kill sleep rm stat timeout; do
  p=$(command -v "$tool" 2>/dev/null) || continue
  [ -x "$p" ] && ln -sf "$p" "$t/bin/$tool"
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$HOME/notified"\n' > "$t/bin/notify-send"
chmod +x "$t/bin/notify-send"
export PATH="$t/bin"
export VIKIX_WM_FAIL_SECONDS=3
wm() {   # wm STATUS [SECONDS] — ~/.local/bin/stumpwm exits with STATUS, after SECONDS
  printf '#!/bin/sh\necho "new stumpwm ran"\n%s\nexit %s\n' "${2:+sleep $2}" "$1" > "$bin/stumpwm"; chmod +x "$bin/stumpwm"
}
prev() { printf '#!/bin/sh\necho "the stumpwm before ran"\nexit 0\n' > "$bin/stumpwm.prev"; chmod +x "$bin/stumpwm.prev"; }
session() { rm -f "$HOME/notified"; timeout --kill-after=5s 60s /bin/sh "$here/bin/vikix-session" || true; }   # its status is its last kill's
log="$state/session.log"

# The new image dies at once: the one before runs, you're told, the doctor's note is there.
wm 1; prev
session
check "the new StumpWM should have been started" grep -q 'new stumpwm ran' "$log"
check "the StumpWM before should run when the new one dies at once" grep -q 'the stumpwm before ran' "$log"
check "the session should say what it did" grep -q 'starting the one before' "$log"
check "you should be told" grep -q 'The new StumpWM' "$HOME/notified"
check "the note for vikix doctor should be written" grep -q '^status=1$' "$state/stumpwm-fallback"
check "the note should say when" grep -q '^at=20' "$state/stumpwm-fallback"
check "the note should be yours alone" test "$(stat -c %a "$state/stumpwm-fallback")" = 600

# A clean exit (logging out) starts nothing again, and takes the note away.
wm 0
session
check "a clean exit shouldn't start the StumpWM before" test "$(grep -c 'the stumpwm before ran' "$log")" = 0
check "a clean exit should leave no note" test ! -e "$state/stumpwm-fallback"
check "a clean exit should tell nothing" test ! -e "$HOME/notified"

# A desktop that ran a while and then died is not started again.
wm 1 4
session
check "a desktop that ran a while shouldn't be started again" test "$(grep -c 'the stumpwm before ran' "$log")" = 0
check "and leaves no note" test ! -e "$state/stumpwm-fallback"

# No image before: nothing to fall back to.
rm -f "$bin/stumpwm.prev"
wm 1
session
check "without an image before, the session ends as it did" grep -q 'StumpWM exited with status 1' "$log"
check "and starts nothing else" test "$(grep -c 'starting the one before' "$log")" = 0
check "and leaves no note" test ! -e "$state/stumpwm-fallback"

# The previous session's log is kept, and the logs are yours alone.
check "the previous log should be kept" test -f "$log.old"
check "the log should be yours alone" test "$(stat -c %a "$log")" = 600

[ "$fail" = 0 ] && echo "session: vikix-session starts the StumpWM before only when the new one dies at once, and says so"
exit "$fail"
