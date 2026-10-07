#!/usr/bin/env bash
# tests/house.sh — the office's house rules (bin/vikix-agents touch, clash,
# crossings), without a screen: a made-up /proc with three agents, a
# repository with two worktrees, and the hook Claude Code runs before an edit.
#
#   An edit with nobody else on the file says nothing and is noted in the
#   journal; a file another agent has changed in its worktree makes the
#   hook ask, naming that agent (from an argument, and from the hook's JSON
#   on stdin; a tool without a file is let be); a file in another agent's
#   folder is a crossing: allowed, told to the agent, recorded (not one into an
#   agent in the home folder, which owns nothing); two agents
#   editing one file in one working copy is a clash through the journal;
#   vikix agents clash lists the files and shows both changes; the listing
#   marks them; the journal keeps only the agents still running; a process
#   with no agent above it is nothing to rule on; vikix agent gives Claude
#   Code the hook from config/claude/office.json. No desk, no work: an edit
#   of a project's repository is refused off a desk (with how to sit down),
#   and in the project's own folder from any desk; a repository that is no
#   project is not ruled; a Bash command is refused when it would write
#   there (sed -i, a redirection, git commit), not when it reads; vikix
#   agents sit seats the agent at a worktree (made, or the one there; a
#   repository wants a topic; alone, the desk it is in; no agent above:
#   refused), after which its edits there pass, the listing shows it at
#   the desk and an unseated one as "no desk", the seats keep only the
#   agents still running, and close refuses while a seated agent works
#   there. Antigravity CLI's hook (toolCall on stdin) is answered in its
#   shape: a decision with a reason, a crossing asking, nothing to say
#   "ask" (agy's own way; the decision is required, and an empty object
#   denied the call), run_command and a relative TargetFile judged the same.
#   vikix agents close removes
#   a desk's worktree and its branch when the work is in: refused with an
#   agent at work there or files uncommitted (--force throws them away), a
#   branch not merged is kept and said, the desk by its folder, topic,
#   branch or PROJECT TOPIC, asked on the desktop or listed without one.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
unset XDG_STATE_HOME
mkdir -p "$HOME" "$t/src"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# A repository and two worktrees of it: a desk each.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
printf 'one\ntwo\n' > ch1.md; echo notes > notes.md; git add ch1.md notes.md; git commit -q -m first
git worktree add -q "$t/src/book-a" -b a; git worktree add -q "$t/src/book-b" -b b
cd "$here"

# A made-up /proc: PID NAME FOLDER makes an agent process in it.
mkdir -p "$t/proc"; echo "5000.00 1.00" > "$t/proc/uptime"
proc() {
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
proc 1001 claude "$t/src/book-a"
proc 1002 codex "$t/src/book-b"
proc 1003 claude "$t/src/book-a"

agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1; }
touch_as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" touch "$@" 2>&1 < /dev/null; }
journal="$HOME/.local/state/vikix/office/journal.jsonl"

out=$(touch_as 1001 "$t/src/book-a/ch1.md")
check "an edit nobody else is on says nothing: '$out'" test -z "$out"
check "and is noted in the journal" grep -q '"kind": "edit".*"pid": 1001.*book-a/ch1.md' "$journal"

printf 'one\ntwo by b\n' > "$t/src/book-b/ch1.md"
out=$(touch_as 1001 "$t/src/book-a/ch1.md")
check "a file another agent has changed in its worktree makes the hook ask: $out" \
  grep -q '"permissionDecision": "ask"' <<<"$out"
check "naming that agent and where" grep -q 'codex 1002 (.*book-b) has changed it in .*book-b, uncommitted' <<<"$out"
check "and how to see both" grep -q 'vikix agents clash .*ch1.md' <<<"$out"
check "the clash is recorded" grep -q 'claude 1001 and codex 1002 on' <<<"$(VIKIX_RECORDS_DB=$t/records.db python3 "$here/bin/vikix-records" list office --kind clash)"
out=$(printf '{"tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s/ch1.md","old_string":"x"}}' "$t/src/book-a" "$t/src/book-a" \
      | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "the same from the hook's JSON on stdin: $(head -c 60 <<<"$out")" grep -q '"permissionDecision": "ask"' <<<"$out"
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "a tool without a file is let be: '$out'" test -z "$out"

out=$(touch_as 1001 "$t/src/book-b/notes.md")
check "a file in another agent's folder is a crossing, told to the agent: $(head -c 80 <<<"$out")" \
  grep -q '"additionalContext": "Vikix office: .*book-b/notes.md is in .*book-b, the folder codex 1002 works in, not yours' <<<"$out"
check "allowed, not asked" not grep -q permissionDecision <<<"$out"
check "and recorded: $(agents crossings | head -2 | tail -1)" grep -q 'claude 1001 edited .*book-b/notes.md, in codex 1002' <<<"$(agents crossings)"
check "the journal has it as a crossing" grep -q '"kind": "crossing".*"with": "codex 1002"' "$journal"

# Antigravity CLI (its program is agy) asks with its own JSON, and is answered in its shape.
proc 1008 agy "$t/src/book-a"
agy_as() {   # agy_as PID JSON
  printf '%s' "$2" | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" touch 2>&1
}
out=$(agy_as 1008 "{\"toolCall\":{\"name\":\"replace_file_content\",\"args\":{\"TargetFile\":\"$t/src/book-a/ch1.md\"}},\"workspacePaths\":[\"$t/src/book-a\"]}")
check "agy's edit of a file another agent changed is asked in agy's shape, with the reason: $out" \
  grep -q '^{"decision": "ask", "reason": "Vikix office: another agent is on this file. .*codex 1002 (.*book-b) has changed it in .*book-b, uncommitted.*"}$' <<<"$out"
check "the journal knows it as antigravity" grep -q '"agent": "antigravity", "pid": 1008' "$journal"
out=$(agy_as 1008 "{\"toolCall\":{\"name\":\"write_to_file\",\"args\":{\"TargetFile\":\"$t/src/book-a/new.md\"}},\"workspacePaths\":[\"$t/src/book-a\"]}")
check "nothing to say is agy's own way, ask (its decision is required; an empty object denied the call): '$out'" test "$out" = '{"decision": "ask"}'
out=$(agy_as 1008 "{\"toolCall\":{\"name\":\"view_file\",\"args\":{\"AbsolutePath\":\"$t/src/book-a/ch1.md\"}}}")
check "a tool without a file to change: ask, agy's own way: '$out'" test "$out" = '{"decision": "ask"}'
out=$(agy_as 1008 "{\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"ls\",\"Cwd\":\"$t/src/book-a\"}}}")
check "a command that only reads: ask, agy's own way: '$out'" test "$out" = '{"decision": "ask"}'
out=$(agy_as 1008 "{\"toolCall\":{\"name\":\"write_to_file\",\"args\":{\"TargetFile\":\"$t/src/book-b/plan.md\"}}}")
check "a crossing asks there, with the reason, since agy's hooks can't tell the agent without deciding: $out" \
  grep -q '^{"decision": "ask", "reason": "Vikix office: .*book-b/plan.md is in .*book-b, the folder codex 1002 works in, not yours' <<<"$out"
check "and is recorded as antigravity's" grep -q 'antigravity 1008 edited .*book-b/plan.md, in codex 1002' <<<"$(agents crossings)"
rm -r "$t/proc/1008"

proc 1004 claude "$HOME"
out=$(touch_as 1001 "$HOME/plan.md")
check "an agent in the home folder owns no folder: no crossing into it: '$out'" test -z "$out"
rm -rf "$t/proc/1004"
out=$(touch_as 1003 "$t/src/book-a/ch1.md")
check "two agents editing one file in one working copy is a clash through the journal: $(head -c 120 <<<"$out")" \
  grep -q '"permissionDecision": "ask".*claude 1001 (.*book-a) edited it too, [0-9]* s ago' <<<"$out"

out=$(agents clash)
check "vikix agents clash lists the file with the agents on it: $(tr '\n' ' ' <<<"$out")" \
  grep -q '^1 file with two agents on it:' <<<"$out"
check "the file, then each agent" grep -q '^  ch1.md$' <<<"$out"
check "claude's row" grep -q 'claude 1001 .*book-a: edited it' <<<"$out"
check "codex's row" grep -q 'codex 1002 .*book-b: changed in .*book-b' <<<"$out"
out=$(agents clash "$t/src/book-a/ch1.md")
check "with the file, each agent's change in full: $(grep -c '^== ' <<<"$out") agents" test "$(grep -c '^== ' <<<"$out")" -ge 2
check "codex's diff is there" grep -q '^+two by b' <<<"$out"
check "the one that hasn't changed it yet is said so" grep -q 'the edit is still to come' <<<"$out"
check "and whose say it is" grep -q 'Which stays is yours to say' <<<"$out"
out=$(agents clash "$t/src/book-a/notes.md")
check "a file no two are on: $out" grep -q '^No two agents are on .*notes.md' <<<"$out"

# The listing, with a stand-in desktop that knows no windows.
printf '#!/bin/sh\necho "=> NIL"\n' > "$t/eval"; chmod +x "$t/eval"
out=$(VIKIX_EVAL=$t/eval agents)
check "vikix agents says how many files two are on: $(head -1 <<<"$out")" grep -q '^3 agents, 1 file two are on:$' <<<"$out"
check "and marks the file under the agents: $(grep 'on ch1.md' <<<"$out" | head -1)" \
  grep -q '^           on ch1.md with .*codex 1002.* too (vikix agents clash ch1.md)$' <<<"$out"
check "--json has them" python3 -c '
import json, sys
agents = json.load(sys.stdin)
a = next(x for x in agents if x["pid"] == 1002)
assert a["clashes"] == [{"file": "ch1.md", "with": ["claude 1001", "claude 1003"]}], a["clashes"]' <<<"$(VIKIX_EVAL=$t/eval agents --json)"

rm -rf "$t/proc/1003"
touch_as 1001 "$t/src/book-a/ch1.md" >/dev/null
check "the journal keeps only the agents still running" not grep -q '"pid": 1003' "$journal"
check "and still the others" grep -q '"pid": 1001' "$journal"

out=$(python3 "$here/bin/vikix-agents" touch "$t/src/book-a/ch1.md" 2>&1 < /dev/null)
check "a process with no agent above it is nothing to rule on: '$out'" test -z "$out"
out=$(agents crossings --limit x || true)
check "crossings with a bad limit says what it takes: $out" grep -q 'vikix agents crossings \[--limit N\]' <<<"$out"

# A failure with no terminal to read it in (the menu) is said on the desktop.
mkdir -p "$t/bin"; printf '#!/bin/sh\necho "$*" > %s/notified\n' "$t" > "$t/bin/notify-send"; chmod +x "$t/bin/notify-send"
PATH="$t/bin:$PATH" DISPLAY=:7 python3 "$here/bin/vikix-agents" crossings --limit x 2>/dev/null </dev/null || true
check "a failure from the menu is said in a notification: $(cat "$t/notified" 2>/dev/null)" grep -q 'vikix agents vikix agents crossings' "$t/notified"

check "config/claude/office.json is the hook, on edits and Bash" python3 -c '
import json
h = json.load(open("'"$here"'/config/claude/office.json"))["hooks"]["PreToolUse"]
assert h[0]["matcher"] == "Edit|Write|MultiEdit|NotebookEdit|Bash", h
assert h[0]["hooks"][0]["command"] == "vikix agents touch", h'
check "vikix agent gives Claude Code the hook, unless VIKIX_OFFICE=0" \
  grep -q 'VIKIX_OFFICE:-1.*!= 0.*\]' "$here/bin/vikix-agent"
check "with --settings, so nothing is written to the user's settings" \
  grep -q -- '--settings "$VIKIX_DIR/config/claude/office.json"' "$here/bin/vikix-agent"

# --- No desk, no work: a project's repository is changed from a desk alone --------------------
# The repository is a project (a log), found through vikix project's config.
mkdir -p "$HOME/.config/vikix"; printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
( cd "$t/src/book" && echo '# Log' > log.md && git add log.md && git commit -q -m log )
seats="$HOME/.local/state/vikix/office/seats.jsonl"
bash_as() {   # bash_as PID CWD COMMAND: the hook's JSON for a Bash command
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$2" "$3" \
    | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" touch 2>&1
}
proc 1006 claude "$HOME"
out=$(touch_as 1006 "$t/src/book-a/ch1.md")
check "an edit of a project's repository off a desk is refused: $(head -c 80 <<<"$out")" grep -q '"permissionDecision": "deny"' <<<"$out"
check "saying so, and how to sit down" grep -q 'you are not at a desk.*vikix agents sit book TOPIC.*/book-TOPIC on the branch TOPIC' <<<"$out"
check "and the refusal is recorded" grep -q 'claude 1006 was refused .*book-a/ch1.md: off a desk' <<<"$(VIKIX_RECORDS_DB=$t/records.db python3 "$here/bin/vikix-records" list office --kind refused)"
proc 1016 agy "$HOME"
out=$(agy_as 1016 "{\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"sed -i 1d ./ch1.md\",\"Cwd\":\"$t/src/book-a\"}}}")
check "agy's command that would write there, off a desk, is denied in agy's shape: $(head -c 120 <<<"$out")" \
  grep -q '^{"decision": "deny", "reason": "Vikix office: .*book-a/ch1.md is in the project book, and you are not at a desk.*vikix agents sit book TOPIC.*(This command would write there.)"}$' <<<"$out"
out=$(agy_as 1016 "{\"toolCall\":{\"name\":\"write_to_file\",\"args\":{\"TargetFile\":\"ch2.md\"}},\"workspacePaths\":[\"$t/src/book-a\"]}")
check "a TargetFile relative to the workspace is judged where it is: $(head -c 100 <<<"$out")" grep -q '^{"decision": "deny", "reason": "Vikix office: .*book-a/ch2.md is in the project book' <<<"$out"
rm -r "$t/proc/1016"
out=$(touch_as 1001 "$t/src/book/ch1.md")
check "the project's own folder is refused from a desk too: $(head -c 80 <<<"$out")" \
  grep -q '"permissionDecision": "deny".*the project.s own folder, which is for merging only.*Your desk is .*/book-a' <<<"$out"
git -C "$t" init -q other; echo x > "$t/other/x.md"
out=$(touch_as 1006 "$t/other/x.md")
check "a repository that is no project is not ruled: '$out'" test -z "$out"
out=$(bash_as 1001 "$t/src/book-a" "sed -i s/one/two/ $t/src/book/ch1.md")
check "a Bash command that would write in the project's own folder is refused: $(head -c 60 <<<"$out")" \
  grep -q '"permissionDecision": "deny".*for merging only.*This command would write there' <<<"$out"
out=$(bash_as 1001 "$t/src/book-a" "grep -i one $t/src/book/ch1.md 2>/dev/null; git -C $t/src/book worktree list")
check "one that reads there is not: '$out'" test -z "$out"
out=$(bash_as 1006 "$HOME" "cd $t/src/book-a && git commit -m x")
check "a Bash command off a desk that would commit is refused, with how to sit down: $(head -c 60 <<<"$out")" \
  grep -q '"permissionDecision": "deny".*you are not at a desk.*vikix agents sit book TOPIC' <<<"$out"
out=$(bash_as 1001 "$t/src/book-a" "git commit -m x")
check "at a desk, naming nothing, it passes: '$out'" test -z "$out"
out=$(bash_as 1001 "$t/src/book" "printf x > ch1.md")
check "naming nothing but in the project's own folder, a write is refused: $(head -c 60 <<<"$out")" grep -q '"permissionDecision": "deny"' <<<"$out"
out=$(VIKIX_AGENT_PID=1006 agents sit book c2)
check "vikix agents sit seats the agent at a worktree made for it: $out" \
  grep -q 'claude 1006 is seated at .*/book-c2: a new worktree on the branch c2. Work there (cd .*/book-c2) and commit there, on the branch c2' <<<"$out"
check "the worktree is there" test "$(git -C "$t/src/book-c2" rev-parse --abbrev-ref HEAD 2>/dev/null)" = c2
out=$(touch_as 1006 "$t/src/book-c2/notes.md")
check "seated, its edits at the desk pass: '$out'" test -z "$out"
out=$(touch_as 1006 "$t/src/book-a/ch1.md")
check "and one into another desk is a crossing or a clash, not refused: $(head -c 60 <<<"$out")" not grep -q '"deny"' <<<"$out"
proc 1007 claude "$HOME"
out=$(VIKIX_EVAL=$t/eval agents)
check "the listing shows the seated agent at its desk: $(grep 1006 <<<"$out" || grep book-c2 <<<"$out")" grep -qE '^  claude +.*/book-c2 \(c2, nothing uncommitted\) ' <<<"$out"
check "and an unseated one as having no desk: $(grep '~ ' <<<"$out" | head -1)" grep -qE '^  claude +~ \(no desk\) ' <<<"$out"
check "a desk's row says nothing of it" grep -qE '/book-a \(a, [a-z0-9 ]+\) ' <<<"$out"
check "--json has the desk" python3 -c '
import json, sys
agents = json.load(sys.stdin)
assert next(a for a in agents if a["pid"] == 1006)["desk"].endswith("/book-c2")
assert next(a for a in agents if a["pid"] == 1007)["desk"] is None' <<<"$(VIKIX_EVAL=$t/eval agents --json)"
out=$(VIKIX_AGENT_PID=1007 agents sit book || true)
check "a repository's desk wants a topic: $out" grep -q "a repository's desk is a worktree of it: vikix agents sit book TOPIC" <<<"$out"
# (sit alone looks at the shell's folder first: these run from home, not from this repository's worktree.)
out=$(cd "$HOME" && VIKIX_AGENT_PID=1007 agents sit || true)
check "sit alone, off a desk: $out" grep -q 'your folder is not in a desk' <<<"$out"
out=$(cd "$t/src/book-a" && VIKIX_AGENT_PID=1007 agents sit)
check "sit alone from a shell in a desk (the agent's own folder elsewhere): that desk: $out" \
  grep -q 'claude 1007 is seated at .*/book-a: the desk you are in, a worktree on the branch a' <<<"$out"
out=$(bash_as 1001 "$t/src/book-a" "sed -i s/one/two/ $t/src/book/ch1.md")
check "a Bash refusal names the file, not the sed pattern: $(head -c 100 <<<"$out")" grep -q 'Vikix office: .*/book/ch1.md is in' <<<"$out"
out=$(cd "$HOME" && VIKIX_AGENT_PID=1001 agents sit)
check "sit alone, in a desk: that one: $out" grep -q 'claude 1001 is seated at .*/book-a: the desk you are in, a worktree on the branch a' <<<"$out"
out=$(cd "$HOME" && python3 "$here/bin/vikix-agents" sit book x 2>&1 </dev/null || true)
check "no agent above it: refused: $out" grep -q 'no agent runs this shell' <<<"$out"
# A helper an agent started under its own name (Claude Code's daemon runs the shell
# commands): what it does is the agent's, so a seat taken through it is the agent's.
proc 1010 claude "$HOME"
printf '1010 (claude) S 1007 1010 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' > "$t/proc/1010/stat"
out=$(VIKIX_AGENT_PID=1010 agents sit book c4)
check "a seat taken through the agent's helper is the agent's: $out" grep -q 'claude 1007 is seated at .*/book-c4' <<<"$out"
out=$(touch_as 1007 "$t/src/book-c4/notes.md")
check "and the agent's own edits there pass: '$out'" test -z "$out"
rm -r "$t/proc/1010"; close() { python3 "$here/bin/vikix-agents" close "$@" 2>&1 </dev/null || true; }
rm -r "$t/proc/1007"; close c4 >/dev/null; proc 1007 claude "$HOME"
rm -r "$t/proc/1006"
out=$(VIKIX_AGENT_PID=1007 agents sit book c3)
check "the seats keep only the agents still running: $(cat "$seats")" bash -c "grep -q '\"pid\": 1007' '$seats' && ! grep -q '\"pid\": 1006' '$seats'"
close() { python3 "$here/bin/vikix-agents" close "$@" 2>&1 </dev/null || true; }
out=$(close c3)
check "close refuses while a seated agent works there: $out" grep -q 'claude 1007 still at work in .*/book-c3' <<<"$out"
rm -r "$t/proc/1007"
out=$(close c3); out2=$(close c2)
check "and takes the desks down after: $out / $out2" bash -c "[ ! -e '$t/src/book-c3' ] && [ ! -e '$t/src/book-c2' ]"

# --- Closing a desk: the worktree and the branch go, once the work is in ----------------------
close() { python3 "$here/bin/vikix-agents" close "$@" 2>&1 </dev/null || true; }
proc 1005 claude "$t/src/book-a"   # a second agent at the first desk

out=$(close book-a)
check "a desk with agents at work is refused, naming them: $out" grep -q 'claude 1001, claude 1005 still at work in .*/book-a: let it finish' <<<"$out"
out=$(DISPLAY='' close)
check "without a desk named, and no desktop to ask on, the desks are listed: $out" \
  bash -c 'grep -q "The desks:" <<<"$1" && grep -q "book-a  (branch a, in; nothing uncommitted; at work: claude 1001, claude 1005)" <<<"$1" && grep -q "say which: vikix agents close DESK" <<<"$1"' _ "$out"
out=$(close zzz)
check "a desk that isn't says which there are: $out" grep -q 'no desk called zzz; the desks: .*/book-a, .*/book-b' <<<"$out"
rm -r "$t/proc/1002"
out=$(close b)
check "files uncommitted refuse the closing: $out" grep -q '1 file uncommitted in .*/book-b: commit there first, or --force' <<<"$out"
out=$(close book b)
check "as PROJECT TOPIC too: $out" grep -q '1 file uncommitted in .*/book-b' <<<"$out"
( cd "$t/src/book-b" && git commit -qam "by b" )
out=$(close b)
check "closed by its branch; a branch not merged yet is kept and said: $out" \
  grep -q 'the desk is closed: .*/book-b removed; the branch b is kept: not in main yet. Merge it, then git branch -d b in' <<<"$out"
check "the worktree is gone, the branch stays" bash -c "[ ! -e '$t/src/book-b' ] && git -C '$t/src/book' show-ref -q refs/heads/b"
git -C "$t/src/book" worktree add -q "$t/src/book-c" -b c
# From the menu: a stand-in rofi picks the last line (book-c), and the outcome is a notification.
printf '#!/bin/sh\nawk '"'"'END { print NR - 1 }'"'"'\n' > "$t/bin/rofi"; chmod +x "$t/bin/rofi"
rm -f "$t/notified"
out=$(PATH="$t/bin:$PATH" DISPLAY=:7 close)
check "asked on the desktop, a merged desk goes with its branch, and it is said in a notification: $out / $(cat "$t/notified" 2>/dev/null)" \
  bash -c "[ ! -e '$t/src/book-c' ] && ! git -C '$t/src/book' show-ref -q refs/heads/c && grep -q 'the desk is closed: .*/book-c removed, the branch c deleted' '$t/notified'"
rm -r "$t/proc/1001" "$t/proc/1005"; echo half > "$t/src/book-a/draft.md"
out=$(cd "$t/src/book-a" && close a --force)
check "--force throws uncommitted files away, and says when the terminal was in it: $out" \
  grep -q 'the desk is closed: .*/book-a removed, the branch a deleted. This terminal was in it: cd somewhere else' <<<"$out"
out=$(close)
check "no desk left: $out" grep -q 'no desk to close: no project has a worktree beside it' <<<"$out"

[ $fail = 0 ] && echo "house: ok (the hook says nothing, asks, or tells of a crossing, in Claude Code's shape or agy's; off a desk or in the project's own folder it refuses, Bash writes too; sit seats an agent; clash lists and shows; the listing marks; the journal is pruned; close removes a desk once its work is in)"
exit $fail
