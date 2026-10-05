#!/usr/bin/env bash
# tests/office.sh — the office (agents.lisp, bin/vikix-agents): the agents
# at work on the desktop, in a real StumpWM on a hidden screen.
#
#   A terminal with an agent in it is found, one with a shell's job isn't:
#   the agent the terminal started itself, one a script started, by its
#   name; its folder, its workspace, how long it has run; what it is doing
#   from its window's title as Claude Code keeps it (at its prompt, working)
#   and from the agent-waiting plugin's note (waits for your yes, with what
#   it asked); its window carries its name; the menu goes to the one picked;
#   vikix agents prints them with each folder's branch and how many files
#   wait uncommitted there, an agent with no window of its own last, and
#   --json the same as data; none running is said.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM, as viri does;
# without them it says so and stops there. Its own screen, port and home.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup office
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
agents() { ask '(progn (setf *print-pretty* nil) (format t "~{~a~^ | ~}" (mapcar (lambda (a) (format nil "~a ~a ~a ~(~a~)" (getf a :name) (file-namestring (string-right-trim "/" (getf a :folder))) (group-name (window-group (getf a :window))) (getf a :state))) (vikix-agents))))'; }
cli() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-agents" "$@" 2>&1 || true; }

# Stand-in agents: programs called as the real ones are, that only stay.
mkdir -p "$t/bin" "$t/proj-a" "$t/proj-b" "$home/.local/state/vikix/agents"
for name in claude codex gemini; do
  printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$t/bin/$name"; chmod +x "$t/bin/$name"
done
git -C "$t/proj-a" init -q -b topic; git -C "$t/proj-a" config user.name T; git -C "$t/proj-a" config user.email t@example.com
echo one > "$t/proj-a/one"; git -C "$t/proj-a" add one; git -C "$t/proj-a" commit -q -m first
echo changed >> "$t/proj-a/one"; echo new > "$t/proj-a/two"

# agent TITLE DIR COMMAND...: a terminal titled TITLE, in DIR, running COMMAND.
agent() {
  local title=$1 dir=$2; shift 2
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class officetest --title "$title" --working-directory "$dir" -e "$@" >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do
    [ "$(ask "(princ (if (find \"$title\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)) 1 0))")" = 1 ] && break
    sleep 0.25
  done
  sleep 0.5
}

# (Another /proc for this one: the machine's own agents, on the real desktop,
# have no window here and would be listed as such.)
check "none running is said: $(VIKIX_PROC=/nonexistent cli | head -1)" grep -q '^No agent is running here' <<<"$(VIKIX_PROC=/nonexistent cli)"
win Shell
agent "✳ Books" "$t/proj-a" "$t/bin/claude"
check "a terminal with an agent in it is found, by its name, folder and workspace; a shell's isn't: $(agents)" \
  test "$(agents)" = "claude proj-a 1 idle"
key super+2
agent "◐ Tests running" "$t/proj-b" "$t/bin/claude"
agent "codex" "$t/proj-b" sh -c "$t/bin/codex"
check "one working, and one a script started, each on its workspace: $(agents)" \
  test "$(agents)" = "claude proj-a 1 idle | claude proj-b 2 working | codex proj-b 2 running"
check "how long each has run is known" yes '(every (lambda (a) (< 0 (getf a :seconds) 300)) (vikix-agents))'
check "its window carries its name (_VIKIX_AGENT)" \
  yes '(equal (sb-ext:octets-to-string (coerce (xlib:get-property (window-xwin (getf (first (vikix-agents)) :window)) :_VIKIX_AGENT) (quote (vector (unsigned-byte 8))))) "claude")'

# The agent-waiting plugin's note for a window: it waits for you.
id=$(ask '(princ (xlib:window-id (window-xwin (find "✳ Books" (screen-windows (current-screen)) :key (function window-title) :test (function equal)))))')
printf 'ask %s\n%s\nMay I run the tests?\n' "$(date +%s)" "$t/proj-a" > "$home/.local/state/vikix/agents/$id"
check "a note that it asks: it waits for your yes: $(agents)" grep -q '^claude proj-a 1 asks |' <<<"$(agents)"
line=$(ask '(princ (vikix-agent-line (first (vikix-agents))))')
check "its line says so, with what it asked: $line" grep -q 'waits for your yes .*May I run the tests?' <<<"$line"

# The menu: pick one, and you are at its window.
ask '(run-commands "vikix-agents-pick")' >/dev/null &
sleep 1.5; xdotool key Return; wait $! 2>/dev/null || true; sleep 0.5
check "the menu goes to the one picked: workspace $(ask '(princ (group-name (current-group)))'), $(ask '(princ (window-title (current-window)))')" \
  yes '(and (equal (group-name (current-group)) "1") (equal (window-title (current-window)) "✳ Books"))'
check "Super+m has it, under AI" yes '(find (quote vikix-agents-pick) *vikix-menu* :key (function second))'

# vikix agents, in a terminal.
"$t/bin/gemini" & pids+=($!)      # one with no window of its own
sleep 0.5
out=$(cli)
check "vikix agents says how many, and how many wait: $(head -1 <<<"$out")" grep -qE '^[0-9]+ agents, 1 waiting for you:$' <<<"$(head -1 <<<"$out")"
check "each with its folder's branch and what waits uncommitted there: $(grep 'proj-a' <<<"$out" | head -1)" \
  grep -qE '^  claude +.*proj-a \(topic, 2 uncommitted\) +workspace 1 +[0-9]+ (s|min) +waits for your yes$' <<<"$out"
check "under it what it asked" grep -qx '           May I run the tests?' <<<"$out"
check "a folder that isn't a repository is only named: $(grep 'codex' <<<"$out")" grep -qE '^  codex +.*proj-b +workspace 2 ' <<<"$out"
check "one with no window of its own is listed too: $(grep -A1 gemini <<<"$out" | tr '\n' ' ')" \
  bash -c "grep -A1 '^  gemini ' <<<\"\$1\" | grep -q 'no window of its own: started by'" _ "$out"
json=$(cli --json)
check "--json is the same as data" python3 -c '
import json, sys
agents = json.loads(sys.argv[1])
a = next(a for a in agents if a["folder"].endswith("proj-a"))
assert a["agent"] == "claude" and a["branch"] == "topic" and a["uncommitted"] == 2 and a["state"] == "asks", a
assert a["workspace"] == "1" and a["said"] == "May I run the tests?" and a["seconds"] > 0, a
' "$json"
check "vikix agents with a word it doesn't know says what it takes" grep -q 'vikix agents \[--json\]' <<<"$(cli nonsense)"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report office "agents found in their terminals by name, folder and workspace, what each is doing from its title and its note, its window marked, the menu to one, vikix agents with branches and uncommitted files, one without a window, --json"
exit "$fail"
