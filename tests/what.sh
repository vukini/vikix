#!/usr/bin/env bash
# tests/what.sh — "what is this?" (bin/vikix-what, what.lisp, config/what).
#
#   Without a screen: Vikix's pages pass their own check (a paragraph that
#   fits a card, every guide heading and file they name there), and a page
#   that names a chapter, a file outside Vikix or a heading that isn't there
#   is refused: the pages point at Vikix's guides, the manuals and its own
#   files, never at anyone's books; a process's card says how long it has
#   run, what started it, the port it listens on and to whom, and the
#   package its program came from; a port's who listens; a service's (a
#   made-up runit) its process, boot and run file; a command's where it is
#   and its package, a shell's own word; a file's type, size and repository;
#   a bare name that fits more than one thing lists the others; the
#   battery's card reads the kernel's files; memory's and the clock's are
#   read; a name nothing has is said; a card as data; an explanation opens
#   the guide's built page at its heading, a file of Vikix's to read in
#   Emacs; your own pages (what= in ~/.config/vikix/docs) give the paragraph
#   and chapters of a made-up book, opened at the section, checked, and
#   gaps lists what has none; the card on the desktop says & and < plainly,
#   and Enter opens the first explanation.
#
#   In a real StumpWM on a hidden screen: every field of the bar is an
#   area with its name; "this" is the field the pointer is on (the clock, a
#   field that is showing, a workspace's number, a window's title), else
#   the window in front; Super+Alt+? and a click on a field with no click
#   of its own ask for that thing's card; the desktop says of a window its
#   class, workspace, how it is held, its process and what runs in a
#   terminal, of a key what it runs, whose it is and where it is written,
#   of a field what it shows; vikix what prints the cards from it.
#
# The second part needs Xvfb, xdotool, alacritty and Vikix's own StumpWM,
# as viri does; without them it says so and stops there.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"

t0=$(mktemp -d)
trap 'for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t0"' EXIT
mkdir -p "$t0/bin" "$t0/home/.local/share/vikix/guide" "$t0/home/.config/vikix" "$t0/power/BAT0" "$t0/xbps" "$t0/pages" \
         "$t0/sv/quokka/log" "$t0/service" "$t0/books/unix-by-hand" "$t0/books/what"

# Stand-ins, so nothing of this reaches the desktop: the menu, notifications,
# Emacs, the docs browser, and a desktop that doesn't answer.
cat > "$t0/bin/rofi" <<S
#!/bin/sh
while [ \$# -gt 0 ]; do [ "\$1" = -mesg ] && printf '%s\n' "\$2" > "$t0/mesg"; shift; done
cat > "$t0/rows"
cat "$t0/pick" 2>/dev/null
S
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "%s"\n' "$t0/told" > "$t0/bin/notify-send"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\n' "$t0/emacs" > "$t0/bin/emacsclient"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "%s"\n' "$t0/opened" > "$t0/bin/docs-open"
printf '#!/bin/sh\nexit 1\n' > "$t0/bin/no-desktop"
chmod +x "$t0/bin/"*
what() {
  HOME="$t0/home" XDG_DATA_HOME="$t0/home/.local/share" XDG_CONFIG_HOME="$t0/home/.config" XDG_CACHE_HOME="$t0/home/.cache" \
    PATH="$t0/bin:$PATH" VIKIX_EVAL="${desk:-$t0/bin/no-desktop}" \
    VIKIX_DOCS_OPEN="$t0/bin/docs-open" VIKIX_WHAT_POWER="$t0/power" VIKIX_WHAT_XBPS_DB="$t0/xbps" \
    VIKIX_WHAT_SV="$t0/sv" VIKIX_WHAT_SERVICES="$t0/service" \
    python3 "$here/bin/vikix-what" "$@" 2>&1 || true
}

# --- The pages --------------------------------------------------------------
out=$(what check)
check "Vikix's pages pass their own check: $(tail -1 <<<"$out")" grep -qE '^[0-9]+ pages, 0 problems$' <<<"$out"
check "every field of the bar, and every kind, has a page" \
  bash -c "! grep -q 'no page' <<<\"\$1\"" _ "$(what kinds)"
cp "$here"/config/what/*.md "$t0/pages/"
bad() {   # bad NAME LINES...: a page of that name with those lines added; what check says of it
  cp "$here/config/what/process.md" "$t0/pages/$1.md"; printf '%s\n' "${@:2}" >> "$t0/pages/$1.md"
  VIKIX_WHAT_PAGES="$t0/pages" what check | grep "^config/what/$1.md" || true
  rm -f "$t0/pages/$1.md"
}
check "a page that names a chapter is refused: Vikix's pages never point at anyone's books: $(bad book 'chapter: some-book/ch04.md#processes')" \
  grep -q 'chapter: is no line of Vikix.s pages' <<<"$(bad book 'chapter: some-book/ch04.md#processes')"
check "one that names a file outside Vikix is refused" grep -q 'is outside Vikix' <<<"$(bad out 'source: /etc/passwd')"
check "and one that climbs out of it" grep -q 'is outside Vikix' <<<"$(bad up 'source: ../../etc/passwd')"
check "a guide's heading that isn't there is found" grep -q 'has no heading "No such heading"' <<<"$(bad head 'guide: fixing.md#No such heading')"
printf '%s\n' "$(printf 'word %.0s' $(seq 1 70))" '' 'manual: ps(1)' > "$t0/pages/long.md"
check "a paragraph too long for a card is found" grep -q 'long.md: the paragraph is 70 words; a card holds 60' <<<"$(VIKIX_WHAT_PAGES="$t0/pages" what check)"
rm -f "$t0/pages/long.md"

# --- A process ---------------------------------------------------------------
# One that listens, to this machine only; its program "came from" a made-up package.
python3 -c '
import socket, sys, time
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen(1)
print(s.getsockname()[1], flush=True); time.sleep(300)' > "$t0/port" &
pids+=($!); lpid=$!
for _ in $(seq 1 40); do [ -s "$t0/port" ] && break; sleep 0.1; done
lport=$(cat "$t0/port")
printf '<plist>\n<string>%s</string>\n</plist>\n' "$(readlink -f "/proc/$lpid/exe")" > "$t0/xbps/.madeup-python-files.plist"
out=$(what process "$lpid")
check "a process by its number: its name and number: $(head -1 <<<"$out")" grep -qE "^python3?[.0-9]*, a process \(number $lpid\)$" <<<"$(head -1 <<<"$out")"
check "how long it has run, and what started it: $(sed -n 2p <<<"$out")" grep -qE '^  running for [0-9]+ s, started by ' <<<"$out"
check "the memory it uses" grep -qE '^  uses [0-9.]+ (kB|MB|GB) of memory' <<<"$out"
if command -v ss >/dev/null; then
  check "the port it listens on, and that only this machine reaches it: $(grep 'listens' <<<"$out" || true)" \
    grep -q "^  listens on port $lport (this machine only)$" <<<"$out"
fi
check "the package its program came from, found in xbps's lists of files" grep -q 'from the package madeup-python$' <<<"$out"
check "the paragraph on what a process is" grep -q 'A process is a program while it runs' <<<"$out"
check "the guide first among what to read, then the things beside it: $(grep -E '^  1 ' <<<"$out")" \
  bash -c 'grep -qE "^  1  The guide: When something breaks, The desktop feels slow$" <<<"$1" && grep -q "Also: the package madeup-python" <<<"$1" && grep -q "Also: what started it, " <<<"$1"' _ "$out"
check "a card holds six facts at most" test "$(sed -n '2,/^$/p' <<<"$out" | grep -c '^  ')" -le 6
name=$(head -1 <<<"$out" | cut -d, -f1)
check "the same process by its name" grep -q ", a process (number " <<<"$(what "$name")"
check "what a process is, with none in hand" grep -qx 'A process' <<<"$(what process | head -1)"
json=$(what process "$lpid" --json)
check "--json is the card as data" python3 -c '
import json, sys
card = json.loads(sys.argv[1])
assert card["kind"] == "process" and card["name"] == sys.argv[2] and card["paragraph"] and card["facts"], card
assert card["rows"][0]["guide"].endswith("docs/fixing.md") and card["rows"][0]["heading"] == "The desktop feels slow", card["rows"][0]
' "$json" "$lpid"
out=$(what no-such-thing-here)
check "a name nothing has is said: $out" grep -q 'nothing here is called no-such-thing-here' <<<"$out"
check "three words say what it takes" grep -q 'vikix what \[KIND\] \[NAME\]' <<<"$(what a b c)"

# --- A port, a service, a command, a file ------------------------------------------
if command -v ss >/dev/null; then
  out=$(what port "$lport")
  check "a port: who listens on it, and to whom: $(sed -n 2p <<<"$out")" \
    grep -q "^  python3[.0-9]* (process $lpid) listens on it, TCP, to this machine only$" <<<"$out"
  check "and the process is a row of the card" grep -q "^  [0-9]*  Also: the process python3[.0-9]* (number $lpid)$" <<<"$out"
  check "a port nothing listens on says so" grep -qx '  nothing listens on it now' <<<"$(what port 1)"
  check "and its usual use, from /etc/services: $(what port 22 | grep usual)" grep -q 'its usual use, by /etc/services: ssh' <<<"$(what port 22)"
fi
# A runit service, made up: runsv NAME with the service's process under it.
printf '#!/bin/sh\n# the quokka service\nexec sleep 300\n' > "$t0/sv/quokka/run"; chmod +x "$t0/sv/quokka/run"
ln -s "$t0/sv/quokka" "$t0/service/quokka"
printf '#!/bin/sh\nsleep 300 & wait $!\n' > "$t0/bin/runsv"; chmod +x "$t0/bin/runsv"
"$t0/bin/runsv" quokka & pids+=($!); runsv=$!
sleep 0.3
out=$(what service quokka)
check "a service: up, its process, since when: $(sed -n 2p <<<"$out")" grep -qE '^  up, for [0-9]+ s: runit keeps sleep \(process [0-9]+\) running$' <<<"$out"
check "that it starts at boot, and its run file's last line" \
  bash -c 'grep -q "^  starts at boot: it is linked in " <<<"$1" && grep -qx "  its run file ends with: exec sleep 300" <<<"$1" && grep -qx "  keeps a log of its own (svlogd)" <<<"$1"' _ "$out"
check "the run file is a row to open, and the process another" \
  bash -c 'grep -q "  The run file: .*/sv/quokka/run$" <<<"$1" && grep -q "  Also: its process, sleep (number " <<<"$1"' _ "$out"
check "a bare name is the service first, with the process as a row: $(what quokka | head -1)" grep -qx 'quokka, a service' <<<"$(what quokka | head -1)"
pkill -P "$runsv" 2>/dev/null || true; kill "$runsv" 2>/dev/null || true; sleep 0.3
check "a service that is down says so" grep -qx '  not running, and runit doesn'"'"'t watch it' <<<"$(what service quokka)"
check "a service that isn't there is nothing" grep -q 'nothing here is called service wombat' <<<"$(what service wombat)"
out=$(what command grep)
check "a command: where it is: $(sed -n 2p <<<"$out")" grep -qE '^  it is /(usr/)?bin/grep' <<<"$out"
check "a bare name is the command before the package: $(what grep | head -1)" grep -qx 'grep, a command' <<<"$(what grep | head -1)"
check "a word of the shell's own: $(what command cd | sed -n 2p)" grep -qx '  a builtin of the shell, not a program on the PATH' <<<"$(what command cd)"
printf 'hello\n' > "$t0/books/note.txt"
out=$(what file "$t0/books/note.txt")
check "a file: its type and size: $(sed -n 2p <<<"$out")" grep -qE '^  text/plain, 6 bytes, changed 20' <<<"$out"
check "and the file itself to open" grep -q "  The file itself: .*/books/note.txt$" <<<"$out"
check "a folder: what it holds: $(what file "$t0/books" | sed -n 2p)" grep -qE '^  holds [0-9]+ entries$' <<<"$(what file "$t0/books")"
check "a path is tried as a file by itself" grep -q ', a file$' <<<"$(what "$t0/books/note.txt" | head -1)"

# --- Your own pages, and the chapters of a made-up book ---------------------------------
cat > "$t0/books/unix-by-hand/ch04-processes.md" <<'M'
# 4. Processes

## A program that is running

Every process has a number.

## What starts them

The first starts the rest.
M
printf 'own=%s\nwhat=%s\n' "$t0/books" "$t0/books/what" > "$t0/home/.config/vikix/docs"
printf 'A process, in my words.\n\nchapter: unix-by-hand/ch04-processes.md#A program that is running\nsee: port\n' > "$t0/books/what/process.md"
printf 'chapter: unix-by-hand/ch04-processes.md#What starts them\n' > "$t0/books/what/service-quokka.md"
out=$(what process "$lpid")
check "your paragraph replaces Vikix's" grep -qx '  A process, in my words.' <<<"$out"
check "your chapter comes first, Vikix's guide after it: $(grep -E '^  [12]  ' <<<"$out" | tr '\n' '|')" \
  bash -c 'grep -qx "  1  The chapter: 4. Processes, A program that is running" <<<"$1" && grep -qx "  2  The guide: When something breaks, The desktop feels slow" <<<"$1"' _ "$out"
check "and your see: line is a row" grep -q 'Also: what a port is' <<<"$out"
check "a page for one thing by name: $(what service quokka | grep chapter)" grep -q '  1  The chapter: 4. Processes, What starts them' <<<"$(what service quokka)"
: > "$t0/opened"
what process "$lpid" --open 1 >/dev/null; sleep 0.3
check "a chapter opens as the catalogue opens it, at the section: $(cat "$t0/opened")" grep -qE '^file://.*\.html#a-program-that-is-running$' "$t0/opened"
printf 'Not a page: a note on these pages.\n' > "$t0/books/what/README.md"
check "your pages pass the check with Vikix's, a README among them not a page: $(what check | tail -1)" grep -qE '^[0-9]+ pages, 0 problems$' <<<"$(what check)"
printf 'chapter: nowhere.md#x\nchapter: unix-by-hand/ch04-processes.md#No such\n' > "$t0/books/what/port.md"
out=$(what check)
check "a chapter outside your own folders, or a section that isn't there, is found" \
  bash -c 'grep -q "port.md: chapter: nowhere.md isn.t under a folder own= names" <<<"$1" && grep -q "port.md: chapter: ch04-processes.md has no section \"No such\"" <<<"$1"' _ "$out"
rm -f "$t0/books/what/port.md"
out=$(what gaps)
check "gaps: what has your paragraph, a chapter, or neither: $(grep -E '^  (process|port|service quokka) ' <<<"$out" | tr -s ' ' | tr '\n' '|')" \
  bash -c 'grep -qE "^  process +yours +yes " <<<"$1" && grep -qE "^  port +Vikix.s +none " <<<"$1" && grep -qE "^  service quokka +Vikix.s +yes " <<<"$1" && grep -qE "^[0-9]+ of [0-9]+ have no chapter yet$" <<<"$1"' _ "$out"
rm -f "$t0/home/.config/vikix/docs"

# --- The bar's fields, from the kernel's files ---------------------------------
printf '84\n' > "$t0/power/BAT0/capacity"; printf 'Discharging\n' > "$t0/power/BAT0/status"
printf '12400000\n' > "$t0/power/BAT0/power_now"; printf '45000000\n' > "$t0/power/BAT0/energy_full"
printf '50000000\n' > "$t0/power/BAT0/energy_full_design"; printf '41\n' > "$t0/power/BAT0/cycle_count"
out=$(what battery)
check "the battery: its charge, what it is doing and at what power: $(sed -n 2p <<<"$out")" grep -qx '  84% full, discharging, at 12 W' <<<"$out"
check "and how it has worn" bash -c 'grep -qx "  holds 90% of what it held when new" <<<"$1" && grep -qx "  charged and emptied about 41 times so far" <<<"$1"' _ "$out"
check "the bar's own word for it does as well (bat)" grep -q '^The battery, a field of the bar$' <<<"$(what bat)"
check "with no desktop to ask, nothing is said of what the bar shows" bash -c '! grep -q "the bar shows" <<<"$1"' _ "$out"
check "memory: how much is in use: $(what memory | sed -n 2p)" grep -qE '^  [0-9.]+ (MB|GB) of [0-9.]+ (MB|GB) in use; [0-9]+% is free for programs$' <<<"$(what memory)"
check "the clock: the day, and how long the machine has been up" grep -qE '^  the machine has been up for ' <<<"$(what clock)"

# --- Opening an explanation ----------------------------------------------------
# A built page of the guide, as makeinfo makes them: the heading's id.
printf '<html><h2 id="When-something-breaks">x</h2><h3 class="section" id="The-desktop-feels-slow">y</h3></html>\n' \
  > "$t0/home/.local/share/vikix/guide/When-something-breaks.html"
what process "$lpid" --open 1 >/dev/null
check "the guide opens at its built page, at the heading: $(cat "$t0/opened" 2>/dev/null)" \
  grep -qx "file://$t0/home/.local/share/vikix/guide/When-something-breaks.html#The-desktop-feels-slow" "$t0/opened"
check "and is noted for vikix day as a document opened" grep -q 'docs/fixing.md' "$t0/home/.local/state/vikix/day/docs.log"
n=$(what battery | grep -E '^ +[0-9]+  The source: ' | awk '{print $1}')
what battery --open "$n" >/dev/null
check "a file of Vikix's opens in Emacs to read, not to change: $(cat "$t0/emacs" 2>/dev/null)" \
  grep -q "(view-file \"$here/config/stumpwm/vikix/modeline.lisp\")" "$t0/emacs"
check "an explanation the card doesn't have is said" grep -q 'the card has [0-9]* explanations' <<<"$(what battery --open 99)"

# --- The card on the desktop -----------------------------------------------------
# A stand-in desktop with a window whose title would break the markup.
cat > "$t0/bin/desk" <<S
#!/bin/sh
case "\$1" in
  *'"window"'*) printf 'id\t77\nclass\tA&B\ntitle\tNotes <draft> & more\npid\t$lpid\nworkspace\t3\nhow\tfloating\nfront\tyes\nrule\t(when-window (:class "A&B") (float))\n' ;;
  *'"here"'*) printf 'kind\twindow\nname\t77\n' ;;
esac
S
chmod +x "$t0/bin/desk"
printf '0\n' > "$t0/pick"; : > "$t0/opened"
desk="$t0/bin/desk" what --card >/dev/null
check "the card's words say & and < plainly, as the menu needs: $(head -2 "$t0/mesg" | tr '\n' ' ')" \
  bash -c 'grep -qx "<b>A&amp;B, a window</b>" "$1" && grep -qx "its title: Notes &lt;draft&gt; &amp; more" "$1"' _ "$t0/mesg"
check "a window's card: its workspace and how it is held, its program, the rule that ran" \
  bash -c 'grep -qx "on workspace 3, floating, in front" "$1" && grep -q "^its program is .* (process '"$lpid"'), which uses " "$1" && grep -q "^a rule ran for it: (when-window" "$1"' _ "$t0/mesg"
check "its rows: the guide first, then its process and its workspace: $(head -1 "$t0/rows")" \
  bash -c 'head -1 "$1" | grep -q "^The guide: Your first hour, What you.re looking at$" && grep -q "^Also: the process .* (number '"$lpid"')$" "$1" && grep -qx "Also: the workspace 3" "$1"' _ "$t0/rows"
check "Enter opens the first explanation" grep -q 'Your-first-hour\|first-hour.md' "$t0/opened" "$t0/emacs"
desk="$t0/bin/desk" what --card no-such-thing-here >/dev/null
check "on the desktop, a name nothing has is a notification, not silence" grep -q 'Nothing here is called no-such-thing-here' "$t0/told"

[ "$fail" = 0 ] || { echo "what: the part without a screen failed"; exit 1; }
first=$(sed '/^# --- In a real StumpWM/q' "$0" | grep -c '^check ')

# --- In a real StumpWM, on a hidden screen ------------------------------------------
kill "$lpid" 2>/dev/null || true
wm_setup "what (the part without a screen passed; the desktop's part)"
rm -rf "$t0"   # wm_setup's trap removes its own folder; the first part's is done with
# The key and a click start vikix-what: a stand-in that notes what it was asked.
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\n' "$t/asked" > "$t/bin/vikix-what"; chmod +x "$t/bin/vikix-what"
export PATH="$t/bin:$PATH"
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
lines() { ask "(progn (princ (vikix-what-lines $1)) (values))"; }
got() { lines "$1" | awk -F'\t' -v k="$2" '$1 == k { print $2 }'; }
cli() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_WHAT_POWER=/nonexistent python3 "$here/bin/vikix-what" "$@" 2>&1 || true; }
# The middle of the bar's area for THING (a Lisp test of an area's id and args), on the screen.
point() {
  local at
  at=$(ask "(let* ((ml (head-mode-line (current-head)))
                   (area (find-if (lambda (a) $1) (mode-line-on-click-bounds ml))))
              (when area
                (princ (format nil \"~d ~d\"
                               (+ (xlib:drawable-x (mode-line-window ml)) (floor (+ (first area) (second area)) 2))
                               (+ (xlib:drawable-y (mode-line-window ml)) (floor (+ (third area) (fourth area)) 2))))))")
  [ -n "$at" ] || return 1
  # shellcheck disable=SC2086  # two numbers, meant as two words
  xdotool mousemove $at; sleep 0.3
}
asked() { tail -1 "$t/asked" 2>/dev/null || true; }
asked_n() { if [ -f "$t/asked" ]; then wc -l < "$t/asked"; else echo 0; fi; }
# press WHAT...: xdotool WHAT, then wait until the stand-in was started (a busy machine takes its time).
press() {
  local before; before=$(asked_n)
  xdotool "$@"
  for _ in $(seq 1 40); do [ "$(asked_n)" -gt "$before" ] && break; sleep 0.25; done
}

win "Notes"
# A field that shows: three updates waiting, in the file the bar's rounds read.
echo "3 0 0" > "$home/.local/state/vikix/updates"
ask '(progn (vikix-updates-refresh) (update-all-mode-lines))' >/dev/null; sleep 0.5
check "the clock and a field that is showing are areas of the bar, by name" \
  yes '(let ((names (loop for a in (mode-line-on-click-bounds (head-mode-line (current-head))) when (eq (fifth a) :vikix-ml-what) collect (first (sixth a))))) (and (member "clock" names :test (function equal)) (member "updates" names :test (function equal))))'
xdotool mousemove 640 400; sleep 0.3
id=$(ask '(princ (xlib:window-id (window-xwin (current-window))))')
check "away from the bar, \"this\" is the window in front: $(lines '"here"' | tr '\t\n' ' ,')" \
  test "$(got '"here"' kind) $(got '"here"' name)" = "window $id"
point '(equal (sixth a) (list "clock"))'
check "on the clock, it is the clock: $(got '"here"' kind)" test "$(got '"here"' kind)" = clock
point '(equal (sixth a) (list "updates"))'
check "on a field that is showing, that field" test "$(got '"here"' kind)" = updates
point '(eq (fifth a) :ml-on-click-switch-to-group)'
check "on a workspace's number, that workspace: $(lines '"here"' | tr '\t\n' ' ,')" \
  test "$(got '"here"' kind) $(got '"here"' name)" = "workspace 1"
point '(eq (fifth a) :ml-on-click-focus-window)'
check "on a window's title, that window" test "$(got '"here"' kind) $(got '"here"' name)" = "window $id"

# The key, and a click.
point '(equal (sixth a) (list "clock"))'
press key super+alt+question
check "Super+Alt+? asks for the card of what the pointer is on: $(asked)" test "$(asked)" = "--card clock"
xdotool mousemove 640 400; sleep 0.3
press key super+alt+question
check "and of the window in front, away from the bar: $(asked)" test "$(asked)" = "--card window $id"
point '(equal (sixth a) (list "updates"))'
press click 1
check "a click on a field with no click of its own asks for its card: $(asked)" test "$(asked)" = "--card updates"
check "the key is in the registry, and Super+m has it under Help" \
  yes '(and (find "s-M-?" *vikix-bindings* :key (function first) :test (function equal)) (find (quote vikix-what) *vikix-menu* :key (function second)))'

# What the desktop says of a thing.
check "of a window: its class, its workspace, how it is held: $(lines '"window" nil' | tr '\t\n' ' ,' | cut -c1-120)" \
  test "$(got '"window" nil' class) $(got '"window" nil' workspace) $(got '"window" nil' how)" = "viritest 1 a tile"
wpid=$(got '"window" nil' pid); job=$(got '"window" nil' job)
check "its process, and what runs in a terminal: $wpid, $job ($(cat "/proc/${job:-0}/comm" 2>/dev/null))" \
  bash -c '[ -d "/proc/$1" ] && [ "$(cat "/proc/$2/comm")" = sleep ]' _ "${wpid:-0}" "${job:-0}"
check "a window that isn't there is nothing" test -z "$(lines '"window" 1')"
check "of a key: what it runs, said as the keyboard has it: $(got '"key" "s-M-?"' said) runs $(got '"key" "s-M-?"' runs)" \
  test "$(got '"key" "s-M-?"' said) $(got '"key" "s-M-?"' runs)" = "Super+Alt+? vikix-what"
check "whose it is, and where it is written: $(got '"key" "s-M-?"' whose), $(basename "$(got '"key" "s-M-?"' file)") line $(got '"key" "s-M-?"' line)" \
  bash -c '[ "$1" = "Vikix'"'"'s key" ] && [ "$2" = registry.lisp ] && [ "$3" -gt 0 ]' _ "$(got '"key" "s-M-?"' whose)" "$(basename "$(got '"key" "s-M-?"' file)")" "$(got '"key" "s-M-?"' line)"
check "how often it was pressed: $(got '"key" "s-M-?"' pressed)" test "$(got '"key" "s-M-?"' pressed)" = 2
check "a key nothing is bound to is nothing" test -z "$(lines '"key" "s-M-F35"')"
check "of a field: what it shows, without the colours: $(got '"updates"' shows)" test "$(got '"updates"' shows)" = "updates 3"
check "a field showing nothing is still a field" test "$(lines '"awake"' | tr '\t\n' ' ,')" = "field awake,"
check "a name that is no field is nothing" test -z "$(lines '"nonsense"')"

# vikix what, from the desktop's answers.
xdotool mousemove 640 400; sleep 0.3
out=$(cli)
check "vikix what alone is the window in front: $(head -1 <<<"$out")" grep -qx 'viritest, a window' <<<"$(head -1 <<<"$out")"
check "with its title, where it is and what runs in it" \
  bash -c 'grep -qx "  its title: Notes" <<<"$1" && grep -qx "  on workspace 1, a tile, in front" <<<"$1" && grep -q "^  running in it now: sleep (process " <<<"$1"' _ "$out"
out=$(cli Super+Alt+?)
check "a key as it is said: $(head -2 <<<"$out" | tr '\n' ' ')" \
  bash -c 'grep -qx "Super+Alt+?, a key" <<<"$1" && grep -q "^  runs vikix-what: What is this?" <<<"$1" && grep -q "^  Vikix.s key, written in .*registry.lisp, line [0-9]*$" <<<"$1" && grep -qx "  you have pressed it twice (vikix used)" <<<"$1"' _ "$out"
check "and the line it is written at is among what to open" grep -qE '^ +[0-9]+  The line it is written at: registry.lisp, line [0-9]+$' <<<"$out"
check "a key written StumpWM's way is the same key" grep -qx 'Super+Alt+?, a key' <<<"$(cli s-M-? | head -1)"
out=$(cli updates)
check "a field: what the bar shows for it now: $(sed -n 2p <<<"$out")" grep -qx '  the bar shows: updates 3' <<<"$out"
check "one that shows nothing says so" grep -qx '  the bar shows nothing for it now' <<<"$(cli awake)"
check "a workspace: its windows and how they are held: $(cli workspace 1 | sed -n 2p)" \
  grep -qx '  1 window on it, held as tiles, and it is the one in view' <<<"$(cli workspace 1)"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report what "$first checks without a screen (the pages and their rule, a process, the battery, opening, the card), then on a hidden desktop: the bar's fields as areas, what the pointer is on, the key and a click, a window, a key and a field as the desktop says them, vikix what from them"
exit "$fail"
