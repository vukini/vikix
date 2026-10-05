#!/usr/bin/env bash
# tests/gestures.sh — vikix gestures: three fingers swept on the touchpad
# move the focus.
#
#   A sweep's movement becomes steps: one for each stretch of the way, along
#   the axis it started on; as it comes the focus goes the way the fingers
#   do (the way the touchpad scrolls, where it can be asked), and with
#   natural = yes fingers to the left bring what's on the right; two
#   fingers do nothing here (they are the strip's, in viri.lisp); the
#   settings file is read (fingers, distance), and nonsense in it ignored;
#   off and on are a file, and off stops this desktop's listener only (a
#   test's "off" once stopped the real one); the command's page is in shape. Whether it can
#   listen is tried on a hidden X server, where there is one. No touchpad
#   is needed: the movements are made up.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
pids=()
cleanup() {
  local p
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  rm -rf "$t"
}
trap cleanup EXIT
export XDG_CONFIG_HOME="$t/config"
mkdir -p "$XDG_CONFIG_HOME/vikix"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
g="$here/bin/vikix-gestures"
steps() { printf '%s\n' "$@" | "$g" --feed | tr '\n' ' ' | sed 's/ $//'; }

# As it comes: a step for each 120 of the way, and (no touchpad to ask here)
# the focus going the way the fingers do.
asit=$(unset DISPLAY; steps 'begin 3' 'update -130 0' 'update -130 0' end)
check "as it comes, fingers to the left go to the window on the left, a step each 120: $asit" test "$asit" = "left left"
# The rest with the settings said, so that a new default changes nothing below.
printf 'distance = 200\nnatural = yes\n' > "$XDG_CONFIG_HOME/vikix/gestures"

check "a sweep of three fingers to the left is a step to the right for each stretch: $(steps 'begin 3' 'update -120 5' 'update -120 3' 'update -250 0' end)" \
  test "$(steps 'begin 3' 'update -120 5' 'update -120 3' 'update -250 0' end)" = "right right"
check "to the right, steps to the left" test "$(steps 'begin 3' 'update 450 0' end)" = "left left"
check "up and down the same way, and the axis it started on is kept" \
  test "$(steps 'begin 3' 'update 10 -210' 'update 300 -200' end)" = "down down"
check "a short one does nothing" test -z "$(steps 'begin 3' 'update -150 0' end)"
check "two fingers scroll, as always: nothing here" test -z "$(steps 'begin 2' 'update -900 0' end)"
check "each sweep starts afresh" test "$(steps 'begin 3' 'update -150 0' end 'begin 3' 'update -150 0' end)" = ""

printf 'fingers = 4\ndistance = 100   # quicker\nnatural = no\nnonsense = 7\ndistance = many\n' > "$XDG_CONFIG_HOME/vikix/gestures"
check "the settings: four fingers, a shorter stretch, the focus going the fingers' way" \
  test "$(steps 'begin 4' 'update -250 0' end) / $(steps 'begin 3' 'update -250 0' end)" = "left left / "
rm "$XDG_CONFIG_HOME/vikix/gestures"

check "off is a file, and says so" grep -q 'off' <<<"$("$g" off; ls "$XDG_CONFIG_HOME/vikix/")"
check "and while it's there the listener leaves at once" timeout 10 "$g" --watch
check "the command says how it is" grep -q 'Touchpad sweeps: off' <<<"$("$g")"
rm -f "$XDG_CONFIG_HOME/vikix/gestures-off"

# Which listeners are this desktop's: a stand-in for one, with this test's
# settings folder, is seen and stopped; one with another folder (as the real
# desktop's is, from here) and a program that only mentions the words are left.
mkdir -p "$t/bin" "$t/other"
printf 'import time\ntime.sleep(120)\n' > "$t/bin/vikix-gestures"
python3 "$t/bin/vikix-gestures" --watch >/dev/null 2>&1 & mine=$!; pids+=("$mine")
XDG_CONFIG_HOME="$t/other" python3 "$t/bin/vikix-gestures" --watch >/dev/null 2>&1 & other=$!; pids+=("$other")
python3 -c 'import time; time.sleep(120)' vikix-gestures --watch >/dev/null 2>&1 & mention=$!; pids+=("$mention")
sleep 0.5
check "a listener of this desktop is seen: $("$g" | head -1)" grep -q 'Touchpad sweeps: listening' <<<"$("$g")"
"$g" off >/dev/null; sleep 0.5
check "off stops it" bash -c "! kill -0 $mine 2>/dev/null"
check "and leaves another desktop's listener, and a program that only mentions one" kill -0 "$other" "$mention"
rm -f "$XDG_CONFIG_HOME/vikix/gestures-off"
check "its page is in shape" python3 "$here/lib/man.py" --check "$g"

# Listening: on a hidden X server of its own, never the desktop's.
if command -v Xvfb >/dev/null && command -v xdpyinfo >/dev/null; then
  n=$(( 500 + RANDOM % 300 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  Xvfb ":$n" -screen 0 640x480x24 -nolisten tcp >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 30); do DISPLAY=":$n" xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  check "it can hear the X server's touchpad gestures: $(DISPLAY=":$n" "$g" --check 2>&1)" env DISPLAY=":$n" "$g" --check
  listening="and listening on a hidden X server"
else
  listening="(no Xvfb here: listening not tried)"
fi

[ "$fail" = 0 ] && echo "gestures: a sweep becomes steps along its axis, the settings, off and on, whose listener is whose, the page, $listening"
exit "$fail"
