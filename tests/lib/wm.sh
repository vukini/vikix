# tests/lib/wm.sh — a real StumpWM with this checkout's layer, on a hidden
# screen, for the tests that need windows (viri, layouts). Sourced:
#
#   wm_setup NAME   checks what's needed (Xvfb, xdotool, alacritty, Vikix's
#                   StumpWM) or says "NAME: ... skipped" and exits 0; makes a
#                   free screen, a free Swank port and a home of its own
#                   ($home: add files to it now, rules.lisp, layouts ...)
#   wm_start        starts StumpWM there and waits until it answers
#   ask FORM        Lisp in it, the answer printed (as vikix eval prints it)
#   win TITLE [CLASS]   an alacritty window called TITLE (of class CLASS,
#                   viritest by default), once StumpWM has it
#   key KEYS        xdotool key, then a moment
#   check WHAT CMD  CMD, or "FAIL: WHAT" (and $fail set)
#   wm_report NAME LINE   the summary, or StumpWM's last log lines on failure
#
# Never the desktop's: its own screen, port and home. The caller has set
# here (the checkout) and the isolation lines every test starts with.

wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
wm_ql=$HOME/quicklisp
fail=0
pids=()

check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# The processes ended, then the folder: StumpWM still writes its state
# (used, resume) as it quits, and an rm racing it has failed on a folder
# not yet empty, which failed the test; so a moment for them to go, and a
# second try.
wm_cleanup() {
  local p alive
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  for _ in 1 2 3 4 5 6; do
    alive=0
    for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && alive=1; done
    [ "$alive" = 0 ] && break
    sleep 0.5
  done
  rm -rf "$t" 2>/dev/null || { sleep 1; rm -rf "$t"; }
}

wm_setup() {
  local name=$1 need n
  for need in Xvfb xdotool alacritty; do
    command -v "$need" >/dev/null || { echo "$name: needs $need and an X server; skipped"; exit 0; }
  done
  [ -x "$wm" ] || { echo "$name: needs Vikix's StumpWM ($wm); skipped"; exit 0; }
  t=$(mktemp -d)
  trap wm_cleanup EXIT
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
  if [ -d "$wm_ql" ]; then ln -s "$wm_ql" "$home/quicklisp"; fi
  echo "wm-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
  touch "$home/.local/state/vikix/welcome"     # no welcome terminal
}

wm_start() {
  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
  pids+=($!)
  for _ in $(seq 1 60); do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
  [ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start: $(tail -5 "$t/wm.log")"; exit 1; }
}

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "$1" 2>&1 | grep -v '^=> ' || true; }

win() {   # win TITLE [CLASS]
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class "${2:-viritest}" --title "$1" -e sleep 300 >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do
    [ "$(ask "(princ (if (find \"$1\" (group-windows (current-group)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
    sleep 0.25
  done
  sleep 0.3
}

key() { xdotool key "$1"; sleep 0.5; }

wm_report() {
  if [ "$fail" != 0 ]; then
    echo "--- the test StumpWM's last words ($(kill -0 "${pids[1]}" 2>/dev/null && echo running || echo gone)):"
    tail -25 "$t/wm.log" | sed 's/^/    /'
  else
    echo "$1: $2"
  fi
}
