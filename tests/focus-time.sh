#!/usr/bin/env bash
# tests/focus-time.sh — focus time (Super+m, Notifications): minutes with do not
# disturb on by itself, then a break, in a real StumpWM on a hidden screen
# (skipped without Xvfb and Vikix's StumpWM). A stand-in dunstctl notes
# what it is told; a clock the test moves stands in for the minutes.
#
#   The entry starts 25 minutes: do not disturb on, the bar says focus 25 and
#   counts down; at the end do not disturb is off again, a notification
#   says so, the bar says break 5; at the break's end another, and the
#   field is gone. The entry again stops it, with do not disturb put back.
#   Do not disturb already on stays on. 50 minutes get a break of 10; a
#   number of your own; off; nonsense refused; the timer is whole seconds
#   and gone when nothing is on; in the menu under Notifications, with 50;
#   an agent may run it; what is this knows the field.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
for need in Xvfb xdpyinfo; do command -v "$need" >/dev/null || { echo "focus-time: needs $need; skipped"; exit 0; }; done
[ -x "$wm" ] || { echo "focus-time: needs Vikix's StumpWM; skipped"; exit 0; }
t=$(mktemp -d); pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

n=$(( 4100 + RANDOM % 400 ))
while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
pids+=($!)
home="$t/home"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix" "$t/path"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
[ -d "$HOME/quicklisp" ] && ln -s "$HOME/quicklisp" "$home/quicklisp"
echo "focus-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"
# dunstctl: paused as the test's file says, and set-paused writes it; notify-send notes its words.
cat > "$t/path/dunstctl" <<END
#!/bin/sh
case "\$1" in
  is-paused) cat "$t/paused" ;;
  set-paused) echo "\$2" > "$t/paused"; echo "set-paused \$2" >> "$t/told" ;;
  count) echo 0 ;;
esac
exit 0
END
printf '#!/bin/sh\necho "notify-send $*" >> "%s/told"\n' "$t" > "$t/path/notify-send"
chmod +x "$t/path/"*
echo false > "$t/paused"; : > "$t/told"
for _ in $(seq 1 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
PATH="$t/path:$PATH" HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)
ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
until=$((SECONDS + 60)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
[ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start: $(tail -5 "$t/wm.log")"; exit 1; }

# The clock is the test's: minutes pass when it says.
ask '(progn (defvar *ft-clock* (get-universal-time)) (setf *vikix-focus-now* (lambda () *ft-clock*)) (values))' >/dev/null
pass() { ask "(progn (incf *ft-clock* (* 60 $1)) (vikix-focus-tick) (values))" >/dev/null; sleep 0.3; }
field() { ask '(princ (vikix-mode-line-focus nil))' | sed 's/\^([^)]*)//g; s/  *$//'; }
paused() { cat "$t/paused"; }
told() { tr '\n' '|' < "$t/told"; }

start() { ask '(run-commands "vikix-focus-time")' >/dev/null; sleep 0.5; }
start
check "the entry starts focus time: do not disturb on, the bar says focus 25: paused $(paused), field '$(field)'" \
  bash -c "[ '$(paused)' = true ] && [ '$(field)' = 'focus 25' ]"
check "the timer is whole seconds" test "$(ask '(princ (timer-p *vikix-focus-timer*))')" = T
pass 10
check "ten minutes on it says focus 15: '$(field)'" test "$(field)" = "focus 15"
pass 15
check "at the end: do not disturb off, a notification, the bar says break 5: paused $(paused), '$(field)', told $(told)" \
  bash -c "[ '$(paused)' = false ] && [ '$(field)' = 'break 5' ] && grep -q 'notify-send -a Vikix -- Focus time over: 25 minutes A break of 5' '$t/told'"
pass 5
check "the break over: another notification, the field gone, the timer too: '$(field)' $(ask '(princ (list *vikix-focus* *vikix-focus-timer*))')" \
  bash -c "[ -z '$(field)' ] && grep -q 'notify-send -a Vikix -- Break over' '$t/told' && [ '$(ask '(princ (list *vikix-focus* *vikix-focus-timer*))')' = '(NIL NIL)' ]"
check "do not disturb was switched on once and off once: $(told | grep -o 'set-paused [a-z]*' | tr '\n' ' ')" \
  test "$(grep -c 'set-paused' "$t/told")" = 2

# Stopped by hand, with do not disturb put back.
: > "$t/told"
start
check "started again: paused $(paused), '$(field)'" bash -c "[ '$(paused)' = true ] && [ '$(field)' = 'focus 25' ]"
start
check "the entry again stops it: do not disturb off, the field gone: paused $(paused), '$(field)'" bash -c "[ '$(paused)' = false ] && [ -z '$(field)' ]"

# Do not disturb already on stays on.
echo true > "$t/paused"; : > "$t/told"
ask '(progn (vikix-quiet-refresh) (run-commands "vikix-focus-time 50") (values))' >/dev/null; sleep 0.5
check "50 minutes: focus 50, and do not disturb, already on, isn't touched: '$(field)' told '$(told)'" bash -c "[ '$(field)' = 'focus 50' ] && [ ! -s '$t/told' ]"
pass 50
check "a break of 10 after 50, and do not disturb left on: '$(field)' paused $(paused)" bash -c "[ '$(field)' = 'break 10' ] && [ '$(paused)' = true ]"
ask '(run-commands "vikix-focus-time off")' >/dev/null; sleep 0.3
check "off stops the break too: '$(field)'" test -z "$(field)"
echo false > "$t/paused"; ask '(vikix-quiet-refresh)' >/dev/null
ask '(run-commands "vikix-focus-time 7")' >/dev/null; sleep 0.3
check "a number of your own: '$(field)'" test "$(field)" = "focus 7"
ask '(run-commands "vikix-focus-time off")' >/dev/null; sleep 0.3
ask '(run-commands "vikix-focus-time soon")' >/dev/null; sleep 0.3
check "nonsense is refused, nothing started: '$(field)'" test -z "$(field)"

check "the menu has it under Notifications, 25 and 50, and an agent may run it" \
  bash -c "[ \"\$(bash '$here/lib/registry.sh' agent | grep -c focus-time)\" = 1 ] && [ \"\$(bash '$here/lib/registry.sh' menu | grep -c 'Focus time')\" = 2 ]"
check "what is this knows the field, with its card" bash -c "[ -f '$here/config/what/focus.md' ] && [ \"\$(ask '(princ (vikix-what-field-shows \"focus\"))')\" = '' ]"
check "nothing went wrong in the desktop meanwhile" test -z "$(ls "$home/.local/state/vikix/errors/" 2>/dev/null || true)"

[ "$fail" = 0 ] && echo "focus-time: 25 minutes with do not disturb on by itself, counted down, then a break of 5, each said; stopped by the entry with do not disturb put back; do not disturb already on left on; 50 and a break of 10; a number of your own; off; nonsense refused; the menu, the agent, the card"
exit "$fail"
