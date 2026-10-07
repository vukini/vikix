#!/usr/bin/env bash
# tests/office.sh — the office (agents.lisp, bin/vikix-agents): the agents
# at work on the desktop, in a real StumpWM on a hidden screen.
#
#   A terminal with an agent in it is found, one with a shell's job isn't:
#   the agent the terminal started itself, one a script started, by its
#   name (Antigravity CLI's program agy shown as antigravity); its folder,
#   its workspace, how long it has run; what it is doing
#   from its window's title as Claude Code keeps it (at its prompt, working)
#   and from the agent-waiting plugin's note (waits for your yes, with what
#   it asked); its window carries its name; the menu goes to the one picked;
#   vikix agents prints them with each folder's branch and how many files
#   wait uncommitted there, an agent with no window of its own last, and
#   --json the same as data; none running is said. vikix agents desk gives
#   an agent a workspace to itself and a git worktree of its project on a
#   branch of the topic (used again when it is there; a collection's
#   project in the collection's worktree; no worktree for a folder that is
#   no repository, or without a topic; a folder in the way left alone),
#   --here in this terminal, and asks for the project, the topic and the
#   agent when they aren't given (--use and --local reach vikix agent).
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
# To a workspace, asked of StumpWM itself: a key sent to a busy hidden screen is sometimes lost.
go() { ask "(run-commands \"gselect $1\")" >/dev/null; sleep 0.3; }
cli() {
  # Only fixture processes belong to this Office. The real machine's agents
  # otherwise appear as windowless agents and can add unrelated file clashes.
  python3 - "$t" <<'PY'
import os
from pathlib import Path
import sys
root = Path(sys.argv[1])
proc = root / 'proc'
proc.mkdir(exist_ok=True)
for link in proc.iterdir():
    link.unlink()
(proc / 'uptime').symlink_to('/proc/uptime')
for entry in Path('/proc').iterdir():
    if not entry.name.isdigit():
        continue
    try:
        cwd = os.readlink(entry / 'cwd')
        if cwd == str(root) or cwd.startswith(str(root) + '/'):
            (proc / entry.name).symlink_to(entry)
    except OSError:
        pass
PY
  HOME=$home VIKIX_PROC=${VIKIX_PROC:-$t/proc} VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-agents" "$@" 2>&1 || true
}

# Stand-in agents: programs called as the real ones are, that only stay.
mkdir -p "$t/bin" "$t/proj-a" "$t/proj-b" "$home/.local/state/vikix/agents"
for name in claude codex gemini agy; do
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
go 2
agent "◐ Tests running" "$t/proj-b" "$t/bin/claude"
agent "[ ! ] Action Required | Build the Office | proj-b" "$t/proj-b" sh -c "$t/bin/codex"
check "one working, and one a script started, each on its workspace; Codex's title says it waits for you: $(agents)" \
  test "$(agents)" = "claude proj-a 1 idle | claude proj-b 2 working | codex proj-b 2 asks"
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
# One with no window of its own; in the test's folder, not this checkout's,
# where a run of the tests would make the listing call it "testing".
# On a terminal of its own (script gives it one): a provider's program with
# no controlling terminal and no window is a daemon, not an agent.
(cd "$t" && exec script -qfc "exec $t/bin/gemini" /dev/null) </dev/null >/dev/null 2>&1 & pids+=($!)
sleep 0.5
# (The stand-in itself, under script's pty: ended by its own number at the end.)
while read -r p; do pids+=("$p"); done < <(pgrep -f "$t/bin/gemini" || true)
out=$(cli)
# (The machine's own agents are counted too, and when two of them are on one
# file the line says so: that part is theirs, not this test's.)
check "vikix agents says how many, and how many wait: $(head -1 <<<"$out")" grep -qE '^[0-9]+ agents, 2 waiting for you(, [0-9]+ files? two are on)?:$' <<<"$(head -1 <<<"$out")"
check "each with its folder's branch and what waits uncommitted there: $(grep 'proj-a' <<<"$out" | head -1)" \
  grep -qE '^  claude +.*proj-a \(topic, 2 uncommitted, no desk\) +workspace 1 +[0-9]+ (s|min) +waits for your yes$' <<<"$out"
check "under it what it asked" grep -qx '           May I run the tests?' <<<"$out"
check "a folder that isn't a repository is only named, with no desk: $(grep 'codex' <<<"$out")" grep -qE '^  codex +.*proj-b \(no desk\) +workspace 2 +[0-9]+ (s|min) +waits for your yes$' <<<"$out"
check "one with no window of its own is listed too: $(grep -A1 gemini <<<"$out" | tr '\n' ' ')" \
  bash -c "grep -A1 '^  gemini ' <<<\"\$1\" | grep -q 'no window of its own: started by'" _ "$out"
# Antigravity CLI's program is agy: found by that name, shown as antigravity, in Lisp and in the terminal.
agent "agy" "$t/proj-b" "$t/bin/agy"
check "an agy in a terminal is the agent antigravity: $(agents)" grep -qE 'antigravity proj-b [0-9] running' <<<"$(agents)"
check "its window carries that name" \
  yes '(let ((a (find "antigravity" (vikix-agents) :key (lambda (a) (getf a :name)) :test (function equal)))) (and a (equal (sb-ext:octets-to-string (coerce (xlib:get-property (window-xwin (getf a :window)) :_VIKIX_AGENT) (quote (vector (unsigned-byte 8))))) "antigravity")))'
check "vikix agents lists it as antigravity: $(cli | grep antigravity)" grep -qE '^  antigravity +.*proj-b \(no desk\) +workspace [0-9] ' <<<"$(cli)"
kill "${pids[-1]}" 2>/dev/null || true; sleep 0.5
json=$(cli --json)
check "--json is the same as data" python3 -c '
import json, sys
agents = json.loads(sys.argv[1])
a = next(a for a in agents if a["folder"].endswith("proj-a"))
assert a["agent"] == "claude" and a["branch"] == "topic" and a["uncommitted"] == 2 and a["state"] == "asks", a
assert a["workspace"] == "1" and a["said"] == "May I run the tests?" and a["seconds"] > 0, a
' "$json"
# --- A desk: a workspace and a worktree for one agent ------------------------------------------
# Projects as vikix project finds them: a repository, one inside a
# collection's repository, and a folder that is no repository.
mkdir -p "$home/src/books" "$home/src/series/book-a" "$home/src/plain"
for d in books series series/book-a plain; do printf '# Log: %s\n' "$d" > "$home/src/$d/log.md"; done
for d in books series; do
  git -C "$home/src/$d" init -q -b main; git -C "$home/src/$d" config user.name T; git -C "$home/src/$d" config user.email t@example.com
  git -C "$home/src/$d" add -A; git -C "$home/src/$d" commit -q -m first
done
export LIBGL_ALWAYS_SOFTWARE=1     # the desk's terminal is alacritty, on this hidden screen
desk() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_AGENT_CMD="${AGENT_CMD:-$t/bin/claude}" python3 "$here/bin/vikix-agents" desk "$@" 2>&1 || true; }
# Until an agent works in a folder ending so (its terminal takes a moment).
at_desk() { for _ in $(seq 1 40); do grep -q " $1 " <<<" $(agents) " && return 0; sleep 0.25; done; return 0; }

out=$(desk books "Fix typos")
check "a desk is a worktree beside the project, on a branch of the topic: $out" \
  test "$(git -C "$home/src/books-fix-typos" rev-parse --abbrev-ref HEAD 2>/dev/null)" = fix-typos
check "and it says so, with the workspace: $out" grep -q 'a desk for the agent: in ~/src/books-fix-typos, a new worktree on the branch fix-typos, on workspace 3$' <<<"$out"
at_desk "claude books-fix-typos 3 running"
check "the agent works there, on a workspace to itself: $(agents)" grep -q 'claude books-fix-typos 3 running' <<<"$(agents)"
check "vikix agents shows its branch: $(cli | grep fix-typos)" grep -qE 'books-fix-typos \(fix-typos, nothing uncommitted\) +workspace 3 ' <<<"$(cli)"
out=$(desk books fix-typos)
check "a desk that is there is used again, not made twice: $out" grep -q 'the worktree that was there (branch fix-typos), on workspace 4$' <<<"$out"
check "one worktree for it still" test "$(git -C "$home/src/books" worktree list | grep -c fix-typos)" = 1
out=$(desk book-a notes)
at_desk "claude book-a 5 running"
check "a project inside a collection: its own folder in the collection's worktree: $out" \
  bash -c "[ -f '$home/src/series-notes/book-a/log.md' ] && grep -q 'in ~/src/series-notes/book-a, a new worktree on the branch notes' <<<\"\$1\"" _ "$out"
out=$(desk plain anything)
check "a project that is no repository: the agent works in its folder, and it's said: $out" \
  grep -q "plain isn't a git repository, so it has no worktrees" <<<"$out"
out=$(desk books)
check "a repository named without a topic is refused, since its own folder is for merging only: $out" \
  grep -q "a repository's desk is a worktree of it, and books is one: give a topic (vikix agents desk books TOPIC)" <<<"$out"
out=$(desk plain)
check "a project that is no repository, without a topic: its own folder: $out" grep -q 'a desk for the agent: in ~/src/plain, on workspace' <<<"$out"
mkdir "$home/src/books-taken"
out=$(desk books taken)
check "a folder in the way that is no worktree is left alone: $out" grep -q "is there already, and isn't a worktree" <<<"$out"
out=$(desk books '!!!')
check "a topic that gives no name is refused: $out" grep -q 'gives no name for a branch' <<<"$out"
printf '#!/bin/sh\npwd\n' > "$t/bin/where"; chmod +x "$t/bin/where"
out=$(AGENT_CMD="$t/bin/where" desk books in-place --here)
check "--here starts it in this terminal, in the worktree: $(tail -1 <<<"$out")" test "$(tail -1 <<<"$out")" = "$home/src/books-in-place"
# Asked on the desktop: a stand-in rofi picks the project called books, types a topic, and picks
# the agent $t/agent-pick names (the first row, yours, when the file is empty).
cat > "$t/bin/rofi" <<R
#!/bin/sh
case " \$* " in
  *" -p Agent -mesg "*) grep -n "^\$(cat "$t/agent-pick")" | head -1 | cut -d: -f1 | awk '{ print \$1 - 1 }' ;;
  *" -format i "*) grep -n '^books ' | head -1 | cut -d: -f1 | awk '{ print \$1 - 1 }' ;;
  *) cat >/dev/null; echo "From the menu" ;;
esac
R
chmod +x "$t/bin/rofi"
printf '#!/bin/sh\necho "$*" > "%s"\nexec "%s"\n' "$t/desk.args" "$t/bin/claude" > "$t/bin/argsaver"; chmod +x "$t/bin/argsaver"
: > "$t/agent-pick"
out=$(PATH="$t/bin:$PATH" AGENT_CMD="$t/bin/argsaver" desk)
check "without a project it asks which, then for a topic, then which agent: $out" grep -q 'in ~/src/books-from-the-menu, a new worktree on the branch from-the-menu, on workspace' <<<"$out"
sleep 0.5
check "yours, the first row, adds nothing: '$(cat "$t/desk.args" 2>/dev/null)'" test -z "$(cat "$t/desk.args" 2>/dev/null)"
echo "codex " > "$t/agent-pick"
out=$(PATH="$t/bin:$PATH" AGENT_CMD="$t/bin/argsaver" desk)
check "another agent picked reaches vikix agent as --use, and is said: $out" grep -q 'from-the-menu), codex, on workspace' <<<"$out"
sleep 0.5
check "... as --use codex: '$(cat "$t/desk.args" 2>/dev/null)'" test "$(cat "$t/desk.args" 2>/dev/null)" = "--use codex"
mkdir -p "$home/.local/bin"; cp "$t/bin/codex" "$home/.local/bin/codex"     # installed: its local row is offered
echo "codex        on a model" > "$t/agent-pick"
out=$(PATH="$t/bin:$PATH" AGENT_CMD="$t/bin/argsaver" desk)
sleep 0.5
check "the local row adds --local: '$(cat "$t/desk.args" 2>/dev/null)'" test "$(cat "$t/desk.args" 2>/dev/null)" = "--use codex --local"
check "Super+m has it, under AI" yes '(find (quote (run-shell-command "vikix-agents desk")) *vikix-menu* :key (function second) :test (function equal))'
# --task: the task is the agent's first prompt, in the shape its provider takes; aider gets none.
: > "$t/desk.args"
out=$(AGENT_CMD="$t/bin/argsaver" desk books with-task --use codex --task "Fix the index")
sleep 0.5
check "--task is the agent's first prompt, after its own words, and said: $out" \
  bash -c 'grep -q "with-task, codex, the task its first prompt, on workspace" <<<"$1" && [ "$(head -1 "$2")" = "--use codex Fix the index" ] && grep -q "read the handoff before you start" "$2"' _ "$out" "$t/desk.args"
check "and the task is in the record too" grep -q 'books-with-task  no status, just now: Fix the index' <<<"$(cli handoff list)"
: > "$t/desk.args"
out=$(AGENT_CMD="$t/bin/argsaver" desk books with-task-oc --use opencode --task "Fix the index")
sleep 0.5
check "opencode takes it as --prompt: '$(head -1 "$t/desk.args")'" test "$(head -1 "$t/desk.args")" = "--use opencode --prompt Fix the index"
: > "$t/desk.args"
out=$(AGENT_CMD="$t/bin/argsaver" desk books with-task-aider --use aider --task "Fix the index")
sleep 0.5
check "aider takes no first prompt: nothing added, and said: $out '$(cat "$t/desk.args")'" \
  bash -c 'grep -q "aider, the task in its handoff (aider takes no first prompt)" <<<"$1" && [ "$(cat "$2")" = "--use aider" ]' _ "$out" "$t/desk.args"

check "vikix agents with a word it doesn't know says what it takes" grep -q 'vikix agents \[--json|desk|sit|close|desks|handoff|resume|hooks|clash|crossings\]' <<<"$(cli nonsense)"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report office "agents found in their terminals by name, folder and workspace, what each is doing from its title and its note, its window marked, the menu to one, vikix agents with branches and uncommitted files, one without a window, --json; a desk: a workspace and a worktree for one agent, the task its first prompt"
exit "$fail"
