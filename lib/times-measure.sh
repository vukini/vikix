#!/usr/bin/env bash
# lib/times-measure.sh — how long the desktop takes, measured on a hidden
# screen (Xvfb) with Vikix's own StumpWM and this checkout's config, in a
# home of its own: never the desktop you're using. `vikix times measure`
# and tests/times.sh run it. Prints one line a measure, in seconds:
#
#   start    StumpWM started to the desktop ready (its config loaded)
#   reload   Super+m's Reload config (vikix-reload: every file again)
#   key      a key pressed to its command running (the median of 5)
#   emacs    an Emacs frame asked for (emacsclient -c) to its window on
#            the screen, with StumpWM answering again (Emacs without your
#            config: what's measured is the window manager's part)
#   answer   StumpWM's main thread answering a question over Swank, after
#            all that (the median of 5): a slow one means it's kept busy
#
# Needs Xvfb, xdotool and Vikix's StumpWM (~/.local/bin/stumpwm); emacs for
# the emacs line. Exits 2 (saying why) when one is missing.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
for need in Xvfb xdotool xdpyinfo; do
  command -v "$need" >/dev/null || { echo "times: needs $need and an X server" >&2; exit 2; }
done
[ -x "$wm" ] || { echo "times: needs Vikix's StumpWM ($wm)" >&2; exit 2; }

t=$(mktemp -d)
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  [ -n "${emacs_name:-}" ] && HOME="$t/home" emacsclient -s "$emacs_name" -e '(kill-emacs)' >/dev/null 2>&1 || true
  rm -rf "$t"
}
trap cleanup EXIT
now() { date +%s.%N; }
secs() { python3 -c 'import sys; print(f"{float(sys.argv[2]) - float(sys.argv[1]):.2f}")' "$1" "$2"; }
median() { python3 -c 'import sys, statistics; print(f"{statistics.median(map(float, sys.argv[1:])):.3f}")' "$@"; }

# A free screen and a free port: tests run side by side.
n=$(( 100 + RANDOM % 400 ))
while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
pids+=($!)

home="$t/home"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
[ -d "$HOME/quicklisp" ] && ln -s "$HOME/quicklisp" "$home/quicklisp"
echo "times-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal
log="$home/.local/state/vikix/times.log"

for _ in $(seq 1 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
VIKIX_SESSION_START=$(now) HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)

ask() { HOME=$home VIKIX_SWANK_PORT=$port timeout 20 python3 "$here/bin/vikix-eval" "$1" 2>&1 | grep -v '^=> ' || true; }
for _ in $(seq 1 120); do grep -q ' login ' "$log" 2>/dev/null && break; sleep 0.25; done
grep -q ' login ' "$log" 2>/dev/null || { echo "times: the test StumpWM didn't get ready: $(tail -5 "$t/wm.log")" >&2; exit 1; }
echo "start $(awk '$2 == "login" {print $3}' "$log" | tail -1)"
for _ in $(seq 1 60); do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done

# Reload: the command itself notes how long loadrc took.
ask '(run-commands "vikix-reload")' >/dev/null
for _ in $(seq 1 120); do grep -q ' reload ' "$log" && break; sleep 0.25; done
echo "reload $(awk '$2 == "reload" {print $3}' "$log" | tail -1)"

# A key: Super+F12 bound to a command that writes the time it ran.
mark="$t/key-ran"
ask "(progn (defcommand vikix-times-ping () () (with-open-file (o \"$mark\" :direction :output :if-exists :supersede) (multiple-value-bind (s us) (sb-ext:get-time-of-day) (format o \"~d.~6,'0d\" s us)))) (define-key *top-map* (kbd \"s-F12\") \"vikix-times-ping\"))" >/dev/null
keys=()
for _ in 1 2 3 4 5; do
  rm -f "$mark"; t0=$(now)
  xdotool key super+F12
  for _ in $(seq 1 100); do [ -s "$mark" ] && break; sleep 0.02; done
  [ -s "$mark" ] && keys+=("$(secs "$t0" "$(cat "$mark")")")
done
[ "${#keys[@]}" -gt 0 ] && echo "key $(median "${keys[@]}")"

# An Emacs frame, from a daemon of its own (no config of yours).
if command -v emacs >/dev/null && command -v emacsclient >/dev/null; then
  emacs_name="vikix-times-$n"
  HOME=$home emacs -Q --daemon="$emacs_name" >/dev/null 2>&1
  t0=$(now)
  HOME=$home emacsclient -s "$emacs_name" -c -n -F '((name . "times-frame"))' >/dev/null 2>&1 || true
  for _ in $(seq 1 200); do
    [ "$(ask '(princ (if (find "times-frame" (all-windows) :key (function window-title) :test (function equal)) 1 0))')" = 1 ] && break
    sleep 0.05
  done
  echo "emacs $(secs "$t0" "$(now)")"
fi

answers=()
for _ in 1 2 3 4 5; do
  t0=$(now); [ "$(ask '(princ 1)')" = 1 ] && answers+=("$(secs "$t0" "$(now)")")
done
[ "${#answers[@]}" -gt 0 ] && echo "answer $(median "${answers[@]}")"
