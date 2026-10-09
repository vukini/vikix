#!/usr/bin/env bash
# tests/reload.sh — a reload that compiles only what changed, and a bar
# that doesn't hold the desktop (init.lisp, modeline.lisp), in a real
# StumpWM on a hidden screen.
#
#   The first load reads every file from its text and compiles Vikix's in
#   the background; the next loads them from their compiled copies, all but
#   errors.lisp and registry.lisp, and your files, which are always read
#   from their text; it is written down file by file (vikix times files)
#   and as a reload in the times log. A changed file and those after it are
#   read from their text once, the ones before it from their copies. A
#   mistake in one of Vikix's files still costs only its form, with its
#   line, copy or no copy; a copy that is broken is thrown away and the
#   text loaded. Rules and commands still know the file they're written in.
#   The bar's programs run in a thread of their own: one that takes three
#   seconds doesn't hold the desktop, its value arrives, and a reload keeps
#   one such thread.
#
# Needs Xvfb, alacritty and Vikix's own StumpWM; skipped, saying so,
# without them.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
ql=$HOME/quicklisp
for need in Xvfb alacritty xdpyinfo; do
  command -v "$need" >/dev/null || { echo "reload: needs $need and an X server; skipped"; exit 0; }
done
[ -x "$wm" ] || { echo "reload: needs Vikix's StumpWM ($wm); skipped"; exit 0; }

t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# Stand-ins: the bar's volume program takes three seconds to answer.
mkdir -p "$t/bin"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/notify-send"
printf '#!/bin/sh\n[ "$1" = is-paused ] && echo false\nexit 0\n' > "$t/bin/dunstctl"
printf '#!/bin/sh\nsleep 3\necho 42%%\n' > "$t/bin/pamixer"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
unset VIKIX_FASL_DIR                # this test's own copies, in its made-up home: it watches them being made

n=$(( 2100 + RANDOM % 400 ))
while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
pids+=($!)

home="$t/home"
layer="$home/.stumpwm.d/vikix"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$layer/swank.lisp"
[ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
echo "reload-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"     # no welcome terminal
# vikix-version climbs three folders up from the layer (config/stumpwm/vikix/
# in the checkout) to VERSION: here that is $t, since the layer is a copy.
echo 9.9.9 > "$t/VERSION"
printf '(in-package :stumpwm)\n(when-window (:class "ReloadTest") (title "ruled"))\n' > "$home/.stumpwm.d/rules.lisp"
printf '(in-package :stumpwm)\n(setf *vikix-errors-ask* nil)\n(defvar *reload-test-loads* 0)\n(incf *reload-test-loads*)\n' > "$home/.stumpwm.d/user.lisp"

for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)

ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
answers() { local until=$((SECONDS + $1)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && return 0; sleep 0.5; done; return 1; }
answers 60 || { echo "FAIL: the test StumpWM didn't start: $(grep -v '^;' "$t/wm.log" | tail -5)"; exit 1; }
times="$home/.local/state/vikix/load-times"
by() { awk -v how="$1" 'NR > 1 && $2 == how { print $3 }' "$times" | sort | tr '\n' ' '; }
ms() { awk -v how="$1" 'NR > 1 && $2 == how { s += $1 } END { print s + 0 }' "$times"; }
layer_files=$(ask '(princ (length *vikix-files*))')
copies() { find "$home/.cache/vikix/fasl" -name '*.fasl' 2>/dev/null | wc -l; }
made() { local until=$((SECONDS + 90)); while [ "$SECONDS" -lt "$until" ]; do [ "$(copies)" -ge "$1" ] && [ "$(ask '(princ (length *vikix-to-compile*))')" = 0 ] && return 0; sleep 1; done; return 1; }
reload() { ask '(loadrc)' >/dev/null; answers 60 || true; sleep 0.5; }

# --- The first load, and the copies -------------------------------------------------
check "the first load reads every file of Vikix's from its text: $(by compiled)" test -z "$(by compiled)"
check "and yours as yours: $(by yours)" test "$(by yours)" = "rules.lisp user.lisp "
check "it is written down as the start: $(head -1 "$times")" grep -q ' start$' <<<"$(head -1 "$times")"
text_ms=$(ms source)
check "the copies are made in the background, one a file but errors.lisp and registry.lisp: $(copies) of $((layer_files - 2))" made $((layer_files - 2))

# --- A reload from the copies --------------------------------------------------------
reload
check "a reload reads Vikix's files from their copies, all but those two: from text: $(by source)" test "$(by source)" = "errors.lisp registry.lisp "
check "and yours from their text still: $(by yours)" test "$(by yours)" = "rules.lisp user.lisp "
check "your user.lisp was loaded again" test "$(ask '(princ *reload-test-loads*)')" = 2
check "it is quicker than the text was: $(ms compiled) ms now, $text_ms ms then" test "$(( $(ms compiled) + $(ms source) ))" -lt "$text_ms"
check "it is in the times log as a reload: $(tail -1 "$home/.local/state/vikix/times.log")" grep -q ' reload [0-9.]*$' "$home/.local/state/vikix/times.log"
check "vikix-version reads the checkout's VERSION: $(ask '(princ (vikix-version))')" test "$(ask '(princ (vikix-version))')" = 9.9.9
ask '(vikix-reload)' >/dev/null; answers 60 || true; sleep 0.5
said=$(ask '(princ (first (first (screen-last-msg (current-screen)))))')
check "Super+m's Reload config says which version runs now, and how long it took: $said" grep -qE '^Vikix 9\.9\.9 reloaded in [0-9.]+ s$' <<<"$said"
check "your rule and Vikix's rules know whose they are: $(ask '(princ (remove-duplicates (mapcar (function vikix-rule-owner) *vikix-rules*) :test (function equal)))')" \
  grep -q 'rules.lisp' <<<"$(ask '(princ (remove-duplicates (mapcar (function vikix-rule-owner) *vikix-rules*) :test (function equal)))')"
check "no rule thinks it was written in a compiled copy" test "$(ask '(princ (count-if (lambda (r) (search "fasl" (or (vikix-rule-file r) ""))) *vikix-rules*))')" = 0
check "a command still knows its file and its line: $(ask '(princ (let ((c (first *vikix-commands*))) (list (file-namestring (getf c :file)) (integerp (getf c :line)))))')" \
  test "$(ask '(princ (let ((c (first *vikix-commands*))) (list (file-namestring (getf c :file)) (integerp (getf c :line)))))')" = "(registry.lisp T)"
out=$(HOME=$home python3 "$here/bin/vikix-times" files)
check "vikix times files shows it, file by file: $(head -2 <<<"$out" | tr '\n' ' ')" bash -c "grep -q 'The last reload took' <<<\"\$1\" && grep -q 'windows.lisp .*from its compiled copy' <<<\"\$1\" && grep -q 'user.lisp .*yours' <<<\"\$1\"" _ "$out"

# --- A change ---------------------------------------------------------------------------
echo ";; changed" >> "$layer/windows.lisp"
reload
check "a changed file is read from its text: $(by source)" grep -q 'windows.lisp' <<<"$(by source)"
check "and so are those after it (a macro of its may have changed): $(by source)" grep -q 'keys.lisp' <<<"$(by source)"
check "the files before it come from their copies: $(by compiled)" grep -q 'theme.lisp' <<<"$(by compiled)"
check "the copies are made again, the old ones thrown away: $(copies)" made $((layer_files - 2))
sleep 2
check "one copy a file, no more: $(copies)" test "$(copies)" = $((layer_files - 2))
reload
check "and the next reload is from the copies again: from text: $(by source)" test "$(by source)" = "errors.lisp registry.lisp "

# --- A mistake in one of Vikix's files -----------------------------------------------
printf '(reload-test-no-such-function 1)\n(defvar *reload-test-after* :loaded)\n' >> "$layer/day.lisp"
reload
check "a mistake in a file costs only its form: the one after it loaded" test "$(ask '(princ (and (boundp (quote *reload-test-after*)) *reload-test-after*))')" = LOADED
check "and is written down with its file and line" test -n "$(grep -l 'in day.lisp, line' "$home"/.local/state/vikix/errors/*.txt 2>/dev/null | head -1)"
made $((layer_files - 2)) || true; sleep 2
before=$(ls "$home/.local/state/vikix/errors/" | wc -l)
reload
check "with a copy made of the file with the mistake, it still costs only its form: day.lisp from $(awk '$3 == "day.lisp" { print $2 }' "$times")" \
  bash -c "[ \"\$(awk '\$3 == \"day.lisp\" { print \$2 }' '$times')\" = source ] && [ $(ls "$home/.local/state/vikix/errors/" | wc -l) -gt $before ]"
check "the files after it are still loaded: the desktop has its keys" test "$(ask '(princ (lookup-key *top-map* (kbd "s-RET")))')" = vikix-terminal

# --- A copy that is broken -----------------------------------------------------------------
broken=$(find "$home/.cache/vikix/fasl" -name 'theme-*.fasl' | head -1)
[ -n "$broken" ] && echo "not a compiled file" > "$broken"
reload
check "a broken copy is thrown away and the text loaded: theme.lisp from $(awk '$3 == "theme.lisp" { print $2 }' "$times")" \
  test "$(awk '$3 == "theme.lisp" { print $2 }' "$times")" = source
check "the desktop is whole after it" test "$(ask '(princ (length *vikix-bindings*))')" -gt 50

# --- The bar's own thread -----------------------------------------------------------------
check "the bar's rounds are made by one thread of their own" test "$(ask '(princ (count "vikix-bar" (sb-thread:list-all-threads) :key (function sb-thread:thread-name) :test (function equal)))')" = 1
rounds=$(ask '(princ *vikix-bar-rounds*)')
ask '(vikix-bar-kick)' >/dev/null
start=$(date +%s%N); one=$(ask '(princ 1)'); took=$(( ($(date +%s%N) - start) / 1000000 ))
check "a program of the bar's that takes three seconds doesn't hold the desktop: it answered in $took ms" bash -c "[ '$one' = 1 ] && [ $took -lt 1500 ]"
for _ in $(seq 1 20); do [ "$(ask '(princ *vikix-bar-rounds*)')" -gt "$rounds" ] && break; sleep 0.5; done
check "and its value arrives all the same: $(ask '(princ *vikix-volume*)')" test "$(ask '(princ *vikix-volume*)')" = "42%"
check "the main thread's bar timer only notes where the bar is" test "$(ask '(princ (timer-function *vikix-bar-timer*))')" = VIKIX-PUBLISH-WORKAREA
check "nothing went into a debugger on the way" test -z "$(grep -il 'debugger invoked\|unhandled' "$t/wm.log" 2>/dev/null)"

[ "$fail" = 0 ] && echo "reload: Vikix's files from compiled copies made in the background, a changed file and those after it from text once, a mistake or a broken copy costing no more than before, and the bar's programs in a thread of their own"
exit "$fail"
