#!/usr/bin/env bash
# tests/memory.sh — vikix memory: a warning when memory runs low, once, and
# again, urgently, when it's nearly full; the bar's field; the programs left
# over told from those in use; and clean ending only the ones surely left.
#
# The levels and the left-over rules run against a made-up /proc
# (VIKIX_PROC), with a made-up notify-send writing the warnings down; clean
# runs against real processes of the test's own (VIKIX_MEMORY_ONLY keeps it
# to them). Nothing is shown on screen.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset CLAUDE_PID CLAUDECODE   # an agent's shell: the test's own processes would count as an agent's
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
strays=()
trap 'kill "${strays[@]}" 2>/dev/null || true; rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
mkdir -p "$t/bin" "$t/proc/pressure" "$t/x11" "$t/state"
touch "$t/warnings" "$t/x11/X0"
# notify-send's last two arguments are the title and the text.
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
urgent=; [ "\$3" = -u ] && urgent="URGENT "
while [ \$# -gt 2 ]; do shift; done
echo "\$urgent\$1 | \$2" >> "$t/warnings"
EOF
chmod +x "$t/bin/notify-send"
export PATH="$t/bin:$PATH" VIKIX_PROC="$t/proc" VIKIX_X11_DIR="$t/x11" XDG_STATE_HOME="$t/state" DISPLAY=:0 VIKIX_MEMORY_WINDOWS=""
mem() { python3 "$here/bin/vikix-memory" "$@"; }
field() { cat "$t/state/vikix/memory" 2>/dev/null; }
uid=$(id -u)
ticks=$(getconf CLK_TCK)
echo "100000.00 90000.00" > "$t/proc/uptime"

# memory FREE% [SWAP-FREE%] [STALL]: 16 GB of memory, 16 of swap.
memory() {
  local total=16000000 swap=16000000
  printf 'MemTotal: %d kB\nMemAvailable: %d kB\nSwapTotal: %d kB\nSwapFree: %d kB\n' \
    "$total" $((total * $1 / 100)) "$swap" $((swap * ${2:-100} / 100)) > "$t/proc/meminfo"
  printf 'some avg10=0.00 avg60=0.00 avg300=0.00 total=0\nfull avg10=%s avg60=0.00 avg300=0.00 total=0\n' "${3:-0.00}" > "$t/proc/pressure/memory"
}

# proc PID PPID TTY AGE-SECONDS MB "ARG ARG..." [ENV=VALUE...]: a process of yours.
proc() {
  local pid=$1 ppid=$2 tty=$3 age=$4 mb=$5 args=$6; shift 6
  local d="$t/proc/$pid" name=${args%% *}
  mkdir -p "$d"
  printf '%d (%s) S %d %d %d %d 0 0 0 0 0 0 0 0 0 0 20 0 1 0 %d 0 0\n' \
    "$pid" "${name##*/}" "$ppid" "$pid" "$pid" "$tty" $(((100000 - age) * ticks)) > "$d/stat"
  printf 'Name:\t%s\nUid:\t%d\t%d\t%d\t%d\nVmRSS:\t%d kB\nVmSwap:\t0 kB\n' "${name##*/}" "$uid" "$uid" "$uid" "$uid" $((mb * 1024)) > "$d/status"
  printf 'Pss:  %d kB\n' $((mb * 1024)) > "$d/smaps_rollup"
  printf '%s' "$args" | tr ' ' '\0' > "$d/cmdline"
  : > "$d/environ"
  local e; for e in "$@"; do printf '%s\0' "$e" >> "$d/environ"; done
}

# --- The levels: once each, and again only after memory came back ---------------
proc 100 1 0 5000 3000 "qemu-system-x86_64 -name guest=windows,debug-threads=on" DISPLAY=:0
proc 101 50 0 5000 900 "/usr/lib/firefox/firefox" DISPLAY=:0
proc 102 101 0 5000 400 "/usr/lib/firefox/firefox -contentproc" DISPLAY=:0
proc 103 50 0 5000 200 "python3 /home/u/.local/bin/vikix-mcp" DISPLAY=:0
memory 60; mem watch --once > /dev/null
check "with memory to spare, nothing should be said: $(cat "$t/warnings")" test ! -s "$t/warnings"
check "and the bar's field should say ok: $(field)" grep -q '^ok 40 ' "$t/state/vikix/memory"
memory 14; mem watch --once > /dev/null
check "under 15% free it should warn: $(cat "$t/warnings")" grep -q '^Memory is low (86%) | 2.1 GB free' "$t/warnings"
check "naming the biggest, a program's processes together: $(cat "$t/warnings")" \
  grep -q 'Biggest: virtual machine windows 2.9 GB, firefox ×2 1.3 GB, vikix-mcp 200 MB' "$t/warnings"
check "the bar's field should say low: $(field)" grep -q '^low 86 ' "$t/state/vikix/memory"
memory 12; mem watch --once > /dev/null
check "still low: not said twice" test "$(wc -l < "$t/warnings")" = 1
memory 6; mem watch --once > /dev/null
check "under 7% it should warn again, urgently: $(tail -1 "$t/warnings")" grep -q '^URGENT Memory is nearly full (94%)' "$t/warnings"
memory 5; mem watch --once > /dev/null
check "nearly full: not said twice" test "$(wc -l < "$t/warnings")" = 2
memory 16; mem watch --once > /dev/null
check "just above the level it should stay low (no flicker): $(field)" grep -q '^low ' "$t/state/vikix/memory"
memory 40; mem watch --once > /dev/null
check "with memory back, ok: $(field)" grep -q '^ok ' "$t/state/vikix/memory"
memory 13; mem watch --once > /dev/null
check "low again after coming back: said again" test "$(grep -c '^Memory is low' "$t/warnings")" = 2
memory 40; mem watch --once > /dev/null
memory 20 100 35.50; mem watch --once > /dev/null
check "the machine stalling for memory is nearly full, whatever is free: $(tail -1 "$t/warnings")" \
  test "$(grep -c '^URGENT' "$t/warnings")" = 2
memory 40; mem watch --once > /dev/null
memory 25 4; mem watch --once > /dev/null
check "swap all but full, with little free, is low: $(field)" grep -q '^low ' "$t/state/vikix/memory"
out=$(memory 14; mem)
check "vikix memory should say it all: $out" grep -q 'LOW' <<<"$out"
check "the biggest programs, in order" grep -A2 'The biggest programs' <<<"$out" | grep -q 'firefox ×2'

# --- Left over, told from in use --------------------------------------------------
memory 60; : > "$t/warnings"; rm -f "$t/state/vikix/memory"
proc 200 1 0 7200 15 "Xvfb :99 -screen 0 1280x800x24"                       # its starter gone, old
proc 201 1 0 7000 80 "emacs -Q --daemon=test" DISPLAY=:99                   # on that screen
proc 210 300 0 7200 15 "Xvfb :98 -screen 0 1280x800x24"                     # its starter (300) is there
proc 300 50 0 7300 5 "bash tests/soak.sh"
proc 211 300 0 7000 60 "stumpwm" DISPLAY=:98                                # a test under way
proc 220 1 0 60 15 "Xvfb :97 -screen 0 1280x800x24"                         # a minute old: a test starting
proc 230 1 0 9000 40 "sbcl --load build.lisp" DISPLAY=:643                  # its screen is gone
proc 240 1 0 9000 30 "emacs --batch -l x.el" "HOME=/tmp/test-home.abc" DISPLAY=:0
proc 250 1 0 9000 25 "sshd -f /tmp/x/sshd_config" CLAUDE_PID=99999 DISPLAY=:0     # an agent's, its session gone
proc 251 1 0 9000 25 "python3 server.py" CLAUDE_PID=50 CLAUDECODE=1 DISPLAY=:0    # an agent's, still there
proc 50 1 0 99000 300 "claude"
proc 252 1 0 9000 500 "/usr/lib/firefox/firefox" CLAUDE_PID=99999 DISPLAY=:0      # an agent started it; it has a window
proc 260 1 34816 9000 10 "sleep 1000" DISPLAY=:643                         # in a terminal
proc 270 1 0 9000 10 "dropbox" DISPLAY=:0                                   # a daemon of yours
out=$(VIKIX_MEMORY_WINDOWS="252" mem left)
sure=$(sed -n '/^Left over/,/^Maybe/p' <<<"$out")
maybe=$(sed -n '/^Maybe/,$p' <<<"$out")
check "a hidden screen whose starter is gone should be left over: $out" grep -q 'Xvfb :99.*\[200,' <<<"$sure"
check "and what's on it" grep -q 'emacs -Q --daemon=test.*\[201,' <<<"$sure"
check "a program on a screen that no longer exists" grep -q 'sbcl.*\[230,' <<<"$sure"
check "a test's program, its home temporary" grep -q 'emacs --batch.*\[240,' <<<"$sure"
check "an agent's left-behind programs should only be maybes: $maybe" test "$(grep -c '\[25[01],' <<<"$maybe")" = 2
check "and say which: its session ended" grep -A1 '\[250,' <<<"$maybe" | grep -q "session that has ended"
for pid in 210 211 300 220 252 260 270 50 100; do
  check "process $pid is in use and shouldn't be listed: $out" bash -c "! grep -q '\[$pid,' <<<\"\$1\"" _ "$out"
done
mem watch --once > /dev/null
check "four left over shouldn't be news yet: $(cat "$t/warnings")" test ! -s "$t/warnings"
check "but counted for the bar: $(field)" grep -q '^ok 40 4 165 0$' "$t/state/vikix/memory"
proc 231 1 0 9000 400 "sbcl --load soak.lisp" DISPLAY=:643
mem watch --once > /dev/null
check "piled up (5, or 300 MB), it should say so once: $(cat "$t/warnings")" grep -q '^Left-over programs | 5 programs nobody uses hold 565 MB' "$t/warnings"
mem watch --once > /dev/null
check "and not again while they're there" test "$(wc -l < "$t/warnings")" = 1
check "the field should remember it said so: $(field)" grep -q ' 1$' "$t/state/vikix/memory"

# --- clean: real processes of the test's own --------------------------------------
unset VIKIX_PROC VIKIX_X11_DIR
( DISPLAY=:7431 setsid sleep 30731 > /dev/null 2>&1 & )      # a screen that isn't there
( DISPLAY=:0 setsid sleep 30732 > /dev/null 2>&1 & )          # your screen: in use
stray=$(pgrep -n -f '^sleep 30731$'); kept=$(pgrep -n -f '^sleep 30732$'); strays=("$stray" "$kept")
out=$(VIKIX_MEMORY_ONLY="$stray $kept" VIKIX_MEMORY_LEFT_AFTER=0 mem clean < /dev/null) || true
check "without a terminal and without --yes, clean should end nothing: $out" kill -0 "$stray"
out=$(VIKIX_MEMORY_ONLY="$stray $kept" mem clean --yes)
check "a program younger than 10 minutes is a test running: left alone ($out)" kill -0 "$stray"
out=$(VIKIX_MEMORY_ONLY="$stray $kept" VIKIX_MEMORY_LEFT_AFTER=0 mem clean --yes)
check "clean --yes should end the one surely left over: $out" bash -c "! kill -0 $stray 2>/dev/null"
check "and say so: $out" grep -q 'Ended 1 of 1' <<<"$out"
check "and leave the one on your screen" kill -0 "$kept"

# --- Wired into the desktop ---------------------------------------------------------
check "vikix-session should start the watcher" grep -q 'vikix-memory" watch' "$here/bin/vikix-session"
check "vikix memory should reach it" grep -q 'memory) *shift; exec "$VIKIX_DIR/bin/vikix-memory"' "$here/bin/vikix"
check "the bar should have its field" grep -q '%Y%G%Q' "$here/config/stumpwm/vikix/modeline.lisp"
check "Super+m should have it" grep -q '(vikix-in-terminal "vikix memory clean")' "$here/config/stumpwm/vikix/commands.lisp"

# The bar's words, from the watcher's line: the two Lisp functions alone, in
# plain sbcl, with stand-ins for what they call.
if command -v sbcl > /dev/null; then
  cat > "$t/bar.lisp" <<'LISP'
(defpackage :stumpwm (:use :cl)) (in-package :stumpwm)
(defvar *vikix-memory* nil)
(defun split-string (s sep) (declare (ignore sep))
  (loop with start = 0 for end = (position #\Space s :start start)
        collect (subseq s start end) while end do (setf start (1+ end))))
(defun vikix-colour (name) (string-downcase name))
(defun vikix-ml-clickable (id arg text) (declare (ignore id arg)) text)
;;FUNCTIONS
(dolist (line (list "ok 40 0 0 0" "low 86 0 0 0" "critical 94 2 30 0" "ok 40 6 500 1" "low 88 6 500 1" "" "nonsense"))
  (setf *vikix-memory* (vikix-memory-read line))
  (format t "~a => ~a~%" line (vikix-mode-line-memory nil)))
LISP
  # The two functions' own text (the files around them need StumpWM to be read).
  { sed -n '/^(defun vikix-memory-read /,/^$/p' "$here/config/stumpwm/vikix/commands.lisp"
    sed -n '/^(defun vikix-mode-line-memory /,/^$/p' "$here/config/stumpwm/vikix/modeline.lisp"; } > "$t/functions.lisp"
  sed -i "s|;;FUNCTIONS|(load \"$t/functions.lisp\")|" "$t/bar.lisp"
  out=$(sbcl --noinform --no-sysinit --no-userinit --non-interactive --load "$t/bar.lisp" 2>&1) || true
  want='ok 40 0 0 0 => 
low 86 0 0 0 => ^(:push)^(:fg "accent")mem 86%  ^(:pop)
critical 94 2 30 0 => ^(:push)^(:fg "alert")mem 94%  ^(:pop)
ok 40 6 500 1 => ^(:push)^(:fg "accent")left 6  ^(:pop)
low 88 6 500 1 => ^(:push)^(:fg "accent")mem 88% left 6  ^(:pop)
 => 
nonsense => '
  check "the bar's words for each line of the watcher's:
$out" test "$out" = "$want"
fi

[ "$fail" = 0 ] && echo "memory: warns once when low and again when nearly full, the bar's field, left-over programs told from those in use, clean ends only the sure ones"
exit "$fail"
