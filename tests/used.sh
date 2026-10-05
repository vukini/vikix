#!/usr/bin/env bash
# tests/used.sh — what gets used: counts of keys and commands (vikix used).
#
#   With a made file and a stand-in for the desktop: `vikix used` shows the
#   keys most used first, as the keyboard says them, with what each does,
#   then the menu entries and the rest, and how many keys were never
#   pressed; `never` lists those; `all` says when each was last used; a
#   desktop that can't be asked still shows the counts; `forget` then
#   removes the file.
#
#   In a real StumpWM on a hidden screen (skipped without Xvfb, xdotool,
#   alacritty and Vikix's StumpWM): a key pressed twice is counted twice
#   under the name it is bound by; a menu entry, a rule, a palette pick and
#   an agent's command are counted; a typed command by its name alone,
#   without what followed it; a script's command isn't counted; no
#   window's title is in the file; the counts are written by a timer and
#   as the desktop ends, and read back; forget starts again.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/vikix-test-bus   # never the real session's notifications
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
said=()

# --- With a made file and a stand-in for the desktop ----------------------------------
mkdir -p "$t/vikix/bin" "$t/state/vikix"
cp "$here/bin/vikix-used" "$t/vikix/bin/"
cat > "$t/vikix/bin/vikix-eval" <<END
#!/usr/bin/env python3
import os, sys
open("$t/asked", "a").write(sys.argv[1] + "\\n")
if os.path.exists("$t/desktop-gone"):
    sys.exit(2)
if "vikix-used-keys" in sys.argv[1]:
    print("s-RET\\tSuper+Return\\texec alacritty\\tTerminal")
    print("s-C-g\\tSuper+Ctrl+g\\ttoggle-gaps\\tGaps around windows on/off")
    print("s-f\\tSuper+f\\tfullscreen\\tFullscreen on/off")
    print("C-t A\\tCtrl+t A\\tvikix-sticky\\tKeep this window on every workspace")
if "vikix-used-forget" in sys.argv[1]:
    open("$t/state/vikix/used", "w").write("since\\t4000190000\\n")
print("=> T")
END
chmod +x "$t/vikix/bin/"*
now=$(( $(date +%s) + 2208988800 ))
tab=$'\t'
cat > "$t/state/vikix/used" <<END
since${tab}$(( now - 3 * 86400 ))
key${tab}3${tab}$(( now - 86400 ))${tab}$(( now - 86400 ))${tab}s-f${tab}fullscreen
key${tab}41${tab}$(( now - 2 * 86400 ))${tab}$(( now - 60 ))${tab}s-RET${tab}exec alacritty
key${tab}2${tab}$(( now - 60 ))${tab}$(( now - 60 ))${tab}s-M-x${tab}exec something-of-mine
menu${tab}5${tab}$(( now - 60 ))${tab}$(( now - 60 ))${tab}Reload config
asked${tab}1${tab}$(( now - 60 ))${tab}$(( now - 60 ))${tab}vikix-gaps-toggle
palette${tab}7${tab}$(( now - 60 ))${tab}$(( now - 60 ))${tab}window
a broken line
key${tab}many${tab}1${tab}1${tab}s-q${tab}delete
END
used() { XDG_STATE_HOME="$t/state" python3 "$t/vikix/bin/vikix-used" "$@"; }

out=$(used)
check "it says since when it has counted: $(head -1 <<<"$out")" grep -qE '^Counting since [0-9]+ [A-Z][a-z]+ [0-9]{4} \(4 days\)\.$' <<<"$out"
check "the keys most used first, as the keyboard says them, with what each does" \
  test "$(grep -E '^ +[0-9]+  Super' <<<"$out" | sed -E 's/ +/ /g' | tr '\n' '|')" = " 41 Super+Return Terminal| 3 Super+f Fullscreen on/off| 2 Super+Alt+x exec something-of-mine|"
check "then the menu entries, the palette and the typed commands" bash -c "grep -A1 '^Menu entries' <<<\"\$1\" | grep -qE '^ +5  Reload config' && grep -A1 '^Picks in the palette' <<<\"\$1\" | grep -qE '^ +7  window' && grep -A1 '^Commands you typed' <<<\"\$1\" | grep -qE '^ +1  vikix-gaps-toggle'" _ "$out"
check "and how many keys were never pressed: $(tail -1 <<<"$out")" grep -qx '2 of 4 keys never pressed: vikix used never' <<<"$out"
check "a line that isn't a count is passed over" test -z "$(grep -E 'broken|many' <<<"$out" || true)"
check "the desktop is asked to write its counts down first" grep -q 'vikix-used-write' "$t/asked"
out=$(used never)
check "never lists the keys never pressed, with what each does: $(tail -n +2 <<<"$out" | sed -E 's/ +/ /g' | tr '\n' '|')" \
  test "$(tail -n +2 <<<"$out" | sed -E 's/ +/ /g' | tr '\n' '|')" = " Super+Ctrl+g Gaps around windows on/off| Ctrl+t A Keep this window on every workspace|"
out=$(used all)
check "all says when each was last used" bash -c "grep -qE 'Super\+f .*yesterday$' <<<\"\$1\" && grep -qE 'Super\+Return .*today$' <<<\"\$1\"" _ "$out"
touch "$t/desktop-gone"
out=$(used)
check "a desktop that can't be asked still shows the counts, with the command each key is bound to" \
  bash -c "grep -qE '^ +41  Super\+Return +exec alacritty' <<<\"\$1\" && grep -q \"can't be asked for its keys\" <<<\"\$1\"" _ "$out"
check "and never says it can't list them" bash -c "! XDG_STATE_HOME='$t/state' python3 '$t/vikix/bin/vikix-used' never 2>/dev/null"
used forget >/dev/null
check "forget, without a desktop, removes the file" test ! -e "$t/state/vikix/used"
rm -f "$t/desktop-gone"
used forget >/dev/null
check "forget, with one, has the desktop start again" bash -c "grep -q 'vikix-used-forget' '$t/asked' && [ \"\$(cat '$t/state/vikix/used')\" = \"since${tab}4000190000\" ]"
check "with nothing counted it says so" grep -q 'none pressed yet' <<<"$(used)"
check "an unknown word is refused" bash -c "! XDG_STATE_HOME='$t/state' python3 '$t/vikix/bin/vikix-used' nonsense 2>/dev/null"
check "vikix used is the command" grep -q 'used)        shift; exec "$VIKIX_DIR/bin/vikix-used" "$@" ;;' "$here/bin/vikix"
[ "$fail" = 0 ] && said+=("the most used keys first with what each does, the keys never pressed, when each was last used, counts shown without a desktop, forget")

# --- In a real StumpWM on a hidden screen ---------------------------------------------
on_screen() {
  local wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm} ql=$HOME/quicklisp need
  for need in Xvfb xdotool alacritty xdpyinfo; do
    command -v "$need" >/dev/null || { echo "(the part on a screen needs $need; skipped here)"; return 0; }
  done
  [ -x "$wm" ] || { echo "(the part on a screen needs Vikix's StumpWM; skipped here)"; return 0; }
  local n port home file
  n=$(( 3300 + RANDOM % 400 ))
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
  printf '%s\n' '(when-window (:class "usedrule") (workspace 3))' > "$home/.stumpwm.d/rules.lisp"
  [ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
  echo "used-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
  touch "$home/.local/state/vikix/welcome"
  printf '#!/bin/sh\nexit 0\n' > "$t/path/notify-send"; printf '#!/bin/sh\n[ "$1" = is-paused ] && echo false\nexit 0\n' > "$t/path/dunstctl"
  chmod +x "$t/path/notify-send" "$t/path/dunstctl"
  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  PATH="$t/path:$PATH" HOME=$home XDG_STATE_HOME='' VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
  pids+=($!)
  ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
  local until=$((SECONDS + 60)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
  [ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start"; fail=1; return 0; }
  win() {   # win CLASS TITLE
    LIBGL_ALWAYS_SOFTWARE=1 alacritty --class "$1" --title "$2" -e sleep infinity >/dev/null 2>&1 &
    pids+=($!)
    for _ in $(seq 1 40); do
      [ "$(ask "(princ (if (find \"$2\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
      sleep 0.25
    done
    sleep 0.3
  }
  count() { ask "(princ (vikix-used-count $1 \"$2\"))"; }
  used() { HOME=$home XDG_STATE_HOME='' VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-used" "$@"; }
  file="$home/.local/state/vikix/used"

  win usedtest "A private title 4711"
  xdotool key super+ctrl+g; sleep 0.5; xdotool key super+ctrl+g; sleep 0.5
  check "a key pressed twice is counted twice, under the name it is bound by: $(count :key "s-C-g${tab}toggle-gaps")" \
    test "$(count :key "s-C-g${tab}toggle-gaps")" = 2
  ask '(vikix-menu-do (list "A menu entry" (quote (values))))' >/dev/null
  check "a menu entry is counted" test "$(count :menu "A menu entry")" = 1
  ask '(progn (eval-command "echo a secret word 9182" t) (values))' >/dev/null
  check "a typed command by its name alone, without what followed it" test "$(count :asked echo)" = 1
  ask '(progn (eval-command "vikix-gaps-toggle" nil) (eval-command "vikix-gaps-toggle" nil) (values))' >/dev/null
  check "a command a script asked for isn't counted" test "$(count :asked vikix-gaps-toggle)" = 0
  win usedrule "Ruled 4711"; sleep 0.5
  check "a rule that ran is counted, by its words: $(ask '(maphash (lambda (k v) (when (eql 0 (search "rule" k)) (princ k))) *vikix-used*)')" \
    test "$(ask '(princ (loop for k being the hash-keys of *vikix-used* count (and (eql 0 (search "rule" k)) (search "usedrule" k))))')" = 1
  ask '(vikix-palette-run "command" "gaps")' >/dev/null; sleep 0.5
  ask "(vikix-palette-run \"window\" (princ-to-string (window-id (current-window))))" >/dev/null
  check "a pick in the palette is counted: a command by its name, a window as a window" \
    test "$(count :palette "command gaps") $(count :palette window)" = "1 1"
  ask '(vikix-agent-run "gaps")' >/dev/null
  check "a command an agent ran is counted: $(count :agent gaps)" test "$(count :agent gaps)" = 1

  check "the timer that writes them is whole seconds, and the desktop's end writes them too" \
    test "$(ask '(princ (list (timer-p *vikix-used-timer*) (integerp *vikix-used-every*) (and (find (quote vikix-used-write) *quit-hook*) t)))')" = "(T T T)"
  ask '(vikix-used-tick)' >/dev/null
  check "the timer writes what changed" grep -q "^key${tab}2${tab}[0-9]*${tab}[0-9]*${tab}s-C-g${tab}toggle-gaps$" "$file"
  check "no window's title and nothing typed is in the file" bash -c "! grep -q -e 4711 -e 9182 -e secret '$file'"
  ask '(progn (clrhash *vikix-used*) (setf *vikix-used-read* nil *vikix-used-since* nil) (values))' >/dev/null
  check "a desktop that starts again reads them back: $(count :key "s-C-g${tab}toggle-gaps")" \
    test "$(count :key "s-C-g${tab}toggle-gaps") $(count :menu "A menu entry")" = "2 1"
  local out; out=$(used)
  check "vikix used, against the real desktop, shows the key and what it does" \
    grep -qE '^ +2  Super\+Ctrl\+g +Gaps around windows on/off' <<<"$out"
  check "and counts the keys never pressed: $(tail -1 <<<"$out")" grep -qE '^[0-9]+ of [0-9]+ keys never pressed: vikix used never$' <<<"$out"
  check "never leaves out the key that was pressed, and has one that wasn't" \
    bash -c "o=\$(HOME='$home' XDG_STATE_HOME='' VIKIX_SWANK_PORT=$port python3 '$here/bin/vikix-used' never); ! grep -q '  Super+Ctrl+g ' <<<\"\$o\" && grep -q '  Super+Return ' <<<\"\$o\""
  used forget >/dev/null
  check "forget starts again: the file is one line, and the count is none" \
    test "$(wc -l < "$file") $(count :key "s-C-g${tab}toggle-gaps")" = "1 0"
  check "nothing went wrong in the desktop meanwhile" test -z "$(grep -i 'vikix-used.*error\|error.*vikix-used' "$t/wm.log" || true)"
  [ "$fail" = 0 ] && said+=("on a screen: a key, a menu entry, a rule, palette picks and an agent's command counted, a typed command by name alone, written and read back, no titles kept")
}
on_screen

[ "$fail" = 0 ] && echo "used: ${said[*]}"
exit "$fail"
