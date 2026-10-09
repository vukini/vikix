#!/usr/bin/env bash
# tests/palette.sh — the palette (Super+Space): one box for everything.
#
#   With stand-ins for the desktop and the projects: it offers windows
#   first, then projects, then commands, web apps and layouts, each row
#   saying what it is; a pick goes back to the desktop as its kind and id
#   (a project is opened by vikix project); a desktop that doesn't answer
#   leaves the projects; and it never offers itself. The sigils: > finds
#   the menu's entries and the commands, @ the projects and the desks,
#   # the docs (vikix docs find), ? the card or why's lines, / a file in
#   a made-up home (hidden folders left out); a doc opens through vikix
#   docs (Ctrl+Enter the other way), a file through xdg-open (Ctrl+Enter
#   shown in its folder), a desk's window goes to the desktop by its
#   number; words with no sigil list the rows again with the hint, a
#   sigil with no hit says so; and no sigil is !, the launcher's own.
#
#   In a real StumpWM on a hidden screen (skipped without Xvfb, xdotool,
#   alacritty, rofi and Vikix's StumpWM): the desktop lists its windows on
#   every workspace and its commands with their keys; through the real
#   launcher, a window's name and Enter goes to it on another workspace, and
#   a command's words and Enter runs it; Super+Space opens it.

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

# --- With stand-ins -------------------------------------------------------------------
mkdir -p "$t/vikix/bin"
cp "$here/bin/vikix-palette" "$t/vikix/bin/"
cat > "$t/vikix/bin/vikix-eval" <<END
#!/usr/bin/env python3
import sys
open("$t/asked", "a").write(sys.argv[1] + "\\n")
if "$t" and __import__("os").path.exists("$t/desktop-silent"):
    __import__("time").sleep(5)
if 'vikix-palette-lines "menu"' in sys.argv[1]:
    print("menu\\tScreens: save this layout\\tScreens: save this layout\\tmenu · System")
    print("menu\\tFocus time: 25 minutes\\tFocus time: 25 minutes\\tmenu · Notifications")
    print("=> ; no values")
elif 'vikix-palette-lines "desk"' in sys.argv[1]:
    print("desk\\t8388614\\twifi-fix · Claude\\tdesk on 3 · working")
    print("=> ; no values")
elif "vikix-palette-lines" in sys.argv[1]:
    print("window\\t4194310\\tnotes.org - Emacs\\twindow on 2")
    print("window\\t6291460\\tvukini@x1: ~\\tthis window")
    print("command\\tgaps\\tGaps around windows on/off\\tcommand · Super+Ctrl+g")
    print("command\\treload\\tReload config\\tcommand")
    print("webapp\\tteams\\tTeams\\tweb app · Super+Alt+t")
    print("layout\\twriting\\twriting\\tlayout: put this workspace back as it")
    print("=> ; no values")
END
cat > "$t/vikix/bin/vikix-project" <<END
#!/bin/sh
echo "vikix-project \$*" >> "$t/asked"
[ "\$1" = list ] && printf '%s\n' 'vikix                                    2026-10-05 (today)        the palette' 'living-series/living-in-sql   48%  2026-10-04 (yesterday)    read the EPUB'
exit 0
END
cat > "$t/vikix/bin/vikix-docs" <<END
#!/bin/sh
echo "vikix-docs \$*" >> "$t/asked"
[ "\$1" = find ] && printf '%s\n' 'vikix:/x/docs/fixing.md	vikix	Fixing things	When the desktop...' 'man:1/swank	man	swank(1)	...'
exit 0
END
cat > "$t/vikix/bin/vikix-why" <<END
#!/bin/sh
echo "vikix-why \$*" >> "$t/asked"
printf '%s\n' '22:00:21  Super+1 ran gselect 1  ·  keys.lisp' '22:00:20  A rule ran (each 2 :hours ...)  ×49  ·  rules.lisp:36'
END
cat > "$t/vikix/bin/vikix-what" <<END
#!/bin/sh
echo "vikix-what \$*" >> "$t/asked"
END
mkdir -p "$t/path" "$t/home/notes/.hidden" "$t/home/src/vikix/bin"
printf '#!/bin/sh\necho "xdg-open $*" >> "%s/asked"\n' "$t" > "$t/path/xdg-open"
printf '#!/bin/sh\necho "gdbus $*" >> "%s/asked"\nexit 1\n' "$t" > "$t/path/gdbus"
chmod +x "$t/path/xdg-open" "$t/path/gdbus"
touch "$t/home/notes/palette-notes.org" "$t/home/notes/.hidden/palette-secret.org" "$t/home/src/vikix/bin/vikix-palette"
chmod +x "$t/vikix/bin/"*
pal() { HOME=$t/home PATH="$t/path:$PATH" python3 "$t/vikix/bin/vikix-palette" "$@"; }

out=$(pal --list)
check "it offers the windows first, then the projects, then the rest: $(cut -d' ' -f1 <<<"$out" | tr '\n' ' ')" \
  test "$(sed 's/  ·  .*//' <<<"$out" | tr '\n' '|')" = "notes.org - Emacs|vukini@x1: ~|vikix|living-series/living-in-sql|Gaps around windows on/off|Reload config|Teams|writing|"
check "each row says what it is" bash -c "grep -qx 'notes.org - Emacs  ·  window on 2' <<<\"\$1\" && grep -qx 'Gaps around windows on/off  ·  command · Super+Ctrl+g' <<<\"\$1\" && grep -qx 'vikix  ·  project · next: the palette' <<<\"\$1\" && grep -qx 'Teams  ·  web app · Super+Alt+t' <<<\"\$1\"" _ "$out"
rows=$(pal --rofi | tr '\0\037' '|^')
check "for the launcher, a row carries what comes back when it is picked: $(grep 'notes.org' <<<"$rows")" grep -q 'notes.org - Emacs  ·  window on 2|info^window	4194310^meta^window' <<<"$rows"
check "and the hint names the sigils" grep -q 'message^>  menu and commands  ·  @  projects and desks  ·  #  docs and notes  ·  ?  what is this  ·  /  a file' <<<"$rows"
check "no sigil is the launcher's own !" test -z "$(grep -o 'SIGILS = {[^}]*}' "$here/bin/vikix-palette" | grep -F '"!"' || true)"

# --- The sigils -----------------------------------------------------------------------
out=$(pal --list '>focus')
check "> finds the menu's entries and the commands with the words: $(tr '\n' '|' <<<"$out")" test "$(tr '\n' '|' <<<"$out")" = "Focus time: 25 minutes  ·  menu · Notifications|"
out=$(pal --list '>gaps')
check "> finds a command too: $out" grep -qx 'Gaps around windows on/off  ·  command · Super+Ctrl+g' <<<"$out"
out=$(pal --list '@')
check "@ lists the projects and the desks: $(tr '\n' '|' <<<"$out")" test "$(sed 's/  ·  .*//' <<<"$out" | tr '\n' '|')" = "vikix|living-series/living-in-sql|wifi-fix · Claude|"
out=$(pal --list '@wifi')
check "@ with words keeps what has them: $out" test "$out" = "wifi-fix · Claude  ·  desk on 3 · working"
: > "$t/asked"
out=$(pal --list '#swank password')
check "# asks vikix docs find, and shows the hits by source: $(tr '\n' '|' <<<"$out")" bash -c "grep -qx 'vikix-docs find swank password --tsv --limit 30' '$t/asked' && [ \"\$(tr '\n' '|' <<<\"\$1\")\" = 'Fixing things  ·  docs · vikix|swank(1)  ·  docs · man|' ]" _ "$out"
out=$(pal --list '? battery')
check "? with a name is the card: $out" test "$out" = "What is battery?  ·  what is this · the card"
out=$(pal --list '?')
check "? alone is what the desktop did lately: $(head -1 <<<"$out")" grep -qx 'Super+1 ran gselect 1  ·  keys.lisp  ·  why · 22:00:21' <<<"$out"
if command -v fd >/dev/null; then
  out=$(pal --list '/palette')
  check "/ finds files by name under the home folder, hidden folders left out: $(tr '\n' '|' <<<"$out")" \
    bash -c "grep -qx '~/notes/palette-notes.org  ·  file' <<<\"\$1\" && grep -qx '~/src/vikix/bin/vikix-palette  ·  file' <<<\"\$1\" && ! grep -q secret <<<\"\$1\"" _ "$out"
  out=$(pal --list '/palette notes')
  # shellcheck disable=SC2088  # the row shows ~ as the palette prints it
  check "/ with more words keeps the paths that have them: $out" test "$out" = "~/notes/palette-notes.org  ·  file"
fi
rows=$(pal --rofi '#swank' | tr '\0\037' '|^')
check "in the launcher, a sigil's hits come with a message: $(head -1 <<<"$rows")" bash -c "grep -q 'message^2 for #swank' <<<\"\$1\" && grep -q 'Fixing things  ·  docs · vikix|info^doc	vikix:/x/docs/fixing.md' <<<\"\$1\"" _ "$rows"
rows=$(pal --rofi 'nothing of the kind' | tr '\0\037' '|^')
check "words with no sigil list the rows again, with the hint" bash -c "grep -q 'message^>  menu' <<<\"\$1\" && grep -q 'notes.org - Emacs' <<<\"\$1\"" _ "$rows"
rows=$(pal --rofi '#' | tr '\0\037' '|^')
check "a sigil alone asks for words: $(head -1 <<<"$rows")" grep -q 'message^# wants words after it' <<<"$rows"
: > "$t/asked"
ROFI_INFO=$'doc\tman:1/swank' pal --rofi "x" >/dev/null; sleep 0.3
check "a picked doc opens through vikix docs: $(cat "$t/asked")" grep -qx 'vikix-docs open man:1/swank' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'doc\tman:1/swank' ROFI_RETV=10 pal --rofi "x" >/dev/null; sleep 0.3
check "Ctrl+Enter opens it the other way: $(cat "$t/asked")" grep -qx 'vikix-docs open man:1/swank --other' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'file\t/x/notes/a.org' pal --rofi "x" >/dev/null; sleep 0.3
check "a picked file opens with xdg-open: $(cat "$t/asked")" grep -qx 'xdg-open /x/notes/a.org' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'file\t/x/notes/a.org' ROFI_RETV=10 pal --rofi "x" >/dev/null; sleep 0.3
check "Ctrl+Enter shows it in its folder: FileManager1 asked, the folder opened when nobody answers: $(tr '\n' '|' < "$t/asked")" \
  bash -c "grep -q 'gdbus call --session --dest org.freedesktop.FileManager1 .*ShowItems' '$t/asked' && grep -qx 'xdg-open /x/notes' '$t/asked'"
: > "$t/asked"
ROFI_INFO=$'what\tbattery' pal --rofi "x" >/dev/null; sleep 0.3
check "a picked card is vikix what's: $(cat "$t/asked")" grep -qx 'vikix-what battery --card' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'desk\t8388614' pal --rofi "x" >/dev/null
check "a picked desk goes to the desktop by its window's number: $(cat "$t/asked")" grep -qx '(vikix-palette-run "desk" "8388614")' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'menu\tScreens: save this layout' pal --rofi "x" >/dev/null
check "a picked entry of the menu, by its label: $(cat "$t/asked")" grep -qx '(vikix-palette-run "menu" "Screens: save this layout")' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'why\t' pal --rofi "x" >/dev/null
check "a picked line of why opens its choices on the desktop: $(cat "$t/asked")" grep -qx '(vikix-palette-run "why" "")' "$t/asked"

: > "$t/asked"
out=$(ROFI_INFO=$'window\t4194310' pal --rofi "notes.org - Emacs  ·  window on 2")
check "a picked window goes back to the desktop, by its number: $(cat "$t/asked")" grep -qx '(vikix-palette-run "window" "4194310")' "$t/asked"
check "and nothing more is listed, so the box closes" test -z "$out"
: > "$t/asked"
ROFI_INFO=$'command\tgaps' pal --rofi "Gaps" >/dev/null
check "a picked command, by its name: $(cat "$t/asked")" grep -qx '(vikix-palette-run "command" "gaps")' "$t/asked"
: > "$t/asked"
ROFI_INFO=$'project\tliving-series/living-in-sql' pal --rofi "x" >/dev/null; sleep 0.3
check "a picked project is opened by vikix project: $(cat "$t/asked")" grep -qx 'vikix-project open living-series/living-in-sql' "$t/asked"
touch "$t/desktop-silent"
start=$SECONDS; out=$(pal --list)
check "a desktop that doesn't answer leaves the projects, within three seconds: $((SECONDS - start)) s, $(wc -l <<<"$out") rows" \
  bash -c "[ $((SECONDS - start)) -le 3 ] && [ \"\$(sed 's/  ·  .*//' <<<\"\$1\" | tr '\n' '|')\" = 'vikix|living-series/living-in-sql|' ]" _ "$out"
rm -f "$t/desktop-silent"
check "Super+Space is its key, and Super+d the plain launcher still" bash -c "grep -q ':run \"exec vikix-palette\" :key \"s-SPC\"' '$here/config/stumpwm/vikix/registry.lisp' && grep -q ':run \"exec rofi -show drun\" :key \"s-d\"' '$here/config/stumpwm/vikix/registry.lisp'"
[ "$fail" = 0 ] && said+=("windows, projects, commands, web apps and layouts offered, a pick sent back by kind and id, the projects alone when the desktop is silent; the sigils > @ # ? / search and open")

# --- In a real StumpWM, through the real launcher -----------------------------------
on_screen() {
  local wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm} ql=$HOME/quicklisp need
  for need in Xvfb xdotool alacritty xdpyinfo rofi; do
    command -v "$need" >/dev/null || { echo "(the part on a screen needs $need; skipped here)"; return 0; }
  done
  [ -x "$wm" ] || { echo "(the part on a screen needs Vikix's StumpWM; skipped here)"; return 0; }
  local n port home
  n=$(( 2900 + RANDOM % 400 ))
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
  [ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
  echo "palette-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
  touch "$home/.local/state/vikix/welcome"
  # The key runs "vikix-palette" from PATH: this checkout's.
  ln -s "$here/bin/vikix-palette" "$t/path/vikix-palette"
  printf '#!/bin/sh\nexit 0\n' > "$t/path/notify-send"; printf '#!/bin/sh\n[ "$1" = is-paused ] && echo false\nexit 0\n' > "$t/path/dunstctl"
  chmod +x "$t/path/notify-send" "$t/path/dunstctl"
  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  PATH="$t/path:$PATH" HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
  pids+=($!)
  ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
  local until=$((SECONDS + 60)); while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
  [ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start"; fail=1; return 0; }
  win() {
    LIBGL_ALWAYS_SOFTWARE=1 alacritty --class palettetest --title "$1" -e sleep infinity >/dev/null 2>&1 &
    pids+=($!)
    for _ in $(seq 1 40); do
      [ "$(ask "(princ (if (find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
      sleep 0.25
    done
    sleep 0.3
  }
  in_front() { ask '(princ (list (group-number (current-group)) (and (current-window) (window-title (current-window)))))'; }
  box() {   # box WORDS: the palette, WORDS typed, Enter
    xdotool key super+space
    sleep 2.5; xdotool type --delay 40 "$1"; sleep 0.8; xdotool key Return; sleep 2
  }
  win Alphawin
  ask '(switch-to-group (find 2 (screen-groups (current-screen)) :key (function group-number)))' >/dev/null
  win Bravowin
  local listed; listed=$(HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-palette" --list)
  check "the desktop lists its windows on every workspace: $(grep -c 'window' <<<"$listed")" bash -c "grep -qx 'Alphawin  ·  window on 1 · palettetest' <<<\"\$1\" && grep -qx 'Bravowin  ·  this window' <<<\"\$1\"" _ "$listed"
  check "and its commands, with their keys" grep -qx 'Gaps around windows on/off  ·  command · Super+Ctrl+g' <<<"$listed"
  check "it doesn't offer itself" test -z "$(grep -i 'everything in one box' <<<"$listed" || true)"
  box Alphawin
  check "Super+Space, a window's name, Enter: you are at it, on its workspace: $(in_front)" test "$(in_front)" = "(1 Alphawin)"
  local gaps; gaps=$(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')
  box "Gaps around"
  check "a command's words, Enter: it runs: gaps were $gaps, are $(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')" \
    test "$(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')" != "$gaps"
  listed=$(HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-palette" --list '>power')
  check "> asks the desktop for the menu's entries, with their sections: $(head -2 <<<"$listed" | tr '\n' '|')" grep -q '  ·  menu · Power' <<<"$listed"
  gaps=$(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')
  xdotool key super+space; sleep 2.5; xdotool type --delay 40 '>gaps'; sleep 0.8; xdotool key Return; sleep 2.5
  xdotool type --delay 40 'Gaps around'; sleep 0.8; xdotool key Return; sleep 2
  check "Super+Space, >gaps, Enter, then the hit, Enter: the command runs: gaps were $gaps, are $(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')" \
    test "$(ask '(princ (symbol-value (find-symbol "*GAPS-ON*" :swm-gaps)))')" != "$gaps"
  check "nothing failed on the way" test -z "$(ls "$home/.local/state/vikix/errors/" 2>/dev/null)"
  [ "$fail" = 0 ] && said+=("and through the real launcher: a window on another workspace, a command, a > search then its hit")
  return 0
}
on_screen

[ "$fail" = 0 ] && echo "palette: ${said[*]}"
exit "$fail"
