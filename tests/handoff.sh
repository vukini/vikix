#!/usr/bin/env bash
# tests/handoff.sh — a desk's record across sessions (lib/handoff.py,
# vikix agents handoff), without a screen: a made-up home, a repository
# with a worktree for a desk, and a made-up /proc for the agents.
#
#   A desk gets a record when the user sets a task; the agent's status,
#   account and next step say who wrote them; its estimate of how long,
#   barring a major issue, is counted down from when it was written (left,
#   over, and how it ended once finished), and one that names no duration
#   is refused; a check keeps the commit it
#   ran on and whether the tree was dirty, and is stale once the code
#   moved on (a commit, or other uncommitted changes); a session id is
#   kept by provider, Claude Code's from the hook's own input; the record
#   survives the agent's exit and a stale pid, and the worktree's removal;
#   twenty-five writers at once lose nothing; a generic provider uses the
#   same commands; a credential, an unknown field, a bad session id or a
#   record id that is a path are refused; --json has the freshness; the
#   listing names every desk; close marks the record closed and keeps it;
#   handoff forget removes the record of a desk whose folder is gone, and
#   refuses a desk that stands, one with an agent still in it, and a desk
#   with no record. A worker reports: an agent's status coming to review,
#   waiting or finished is a notification (not a status that stayed, nor
#   the user's own change); a note for the desk's agent (vikix agents
#   tell) waits in the handoff, is refused when it looks like a credential,
#   and is delivered by the hook at the agent's next edit, once.
#   vikix agents resume shows the handoff and resumes the session the
#   record names when the provider's store still has it (claude --resume,
#   codex resume, opencode --session, agy --conversation), else starts fresh and says why; a
#   conversation the store has for the folder is suggested, never taken;
#   never a second agent at a desk unasked. vikix agents hooks says what
#   holds the rules for each provider and links the Codex and OpenCode
#   adapters; touch --for gemini answers in Gemini's shape, --for opencode
#   refuses a clash once and lets the same edit through. A desk gives the
#   agent the user's SSH agent only when asked: --push, or yes to the
#   picker's last question; the picker asks it after the agent.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/proc" "$t/bin"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# A project's repository and a desk, a worktree of it.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; printf 'one\n' > ch1.md; git add log.md ch1.md; git commit -q -m first
git worktree add -q "$t/src/book-a" -b a
cd "$here"

proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
proc 1001 claude "$t/src/book-a"
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
records="$HOME/.local/state/vikix/office/desks"

out=$(agents handoff a)
check "a desk without a record says how to start one: $out" grep -q 'has no record yet: vikix agents handoff set --task' <<<"$out"
out=$(agents handoff set --desk a --task "Fix the typos in chapter one")
check "the user sets the task: $out" grep -q 'book-a: handoff updated by user$' <<<"$out"
check "the record is one file in the office's desks, named by the desk's id" test "$(ls "$records"/*.json | wc -l)" = 1
out=$(as 1001 handoff set --status working --summary "Read ch1; fixed 3 typos" --next "run the spell check")
check "the agent at the desk sets its handoff, from its seat, signed: $out" grep -q 'updated by claude 1001, status working' <<<"$out"
out=$(as 1001 handoff set --estimate "40 min, if the spell check needs no new words")
check "the agent says how long, from now: $out" grep -q 'updated by claude 1001, status working, estimate 40 min from now$' <<<"$out"
out=$(as 1001 handoff set --estimate "soon")
check "an estimate that names no duration is refused: $out" grep -q 'an estimate says how long the work will take, barring a major issue' <<<"$out"
check "the page counts it down, with its words and who said it" \
  grep -q '^Estimate (claude 1001, just now): 40 min, if the spell check needs no new words; 40 min left of 40 min$' <<<"$(agents handoff a)"
# The clock runs from when the estimate was written: fifty minutes on, it is ten over.
python3 - "$records" <<'PY'
import glob, json, sys
path = glob.glob(sys.argv[1] + "/*.json")[0]
rec = json.load(open(path)); rec["handoff"]["estimate"]["at"] -= 50 * 60
json.dump(rec, open(path, "w"))
PY
check "fifty minutes on, the page says how far over" grep -q '; 10 min over its 40 min$' <<<"$(agents handoff a)"
check "and the listing of desks says it too: $(agents handoff list)" grep -q 'working, .*: Fix the typos in chapter one  (10 min over its 40 min)$' <<<"$(agents handoff list)"
out=$(as 1001 handoff set --status finished)
check "finished, the estimate is judged against the time it took: $(agents handoff a | grep ^Estimate)" \
  grep -q '; finished in 50 min against 40 min, 10 min over$' <<<"$(agents handoff a)"
printf '#!/bin/sh\necho "$*" > %s/notified\n' "$t" > "$t/bin/notify-send"; chmod +x "$t/bin/notify-send"
PATH="$t/bin:$PATH" DISPLAY=:7 as 1001 handoff set --status review --next "try it on the laptop" >/dev/null
check "an agent's status coming to review is told on the desktop: $(cat "$t/notified" 2>/dev/null)" \
  grep -q 'Agent at .*/book-a: ready for review try it on the laptop' "$t/notified"
rm -f "$t/notified"
PATH="$t/bin:$PATH" DISPLAY=:7 as 1001 handoff set --next "run the spell check" >/dev/null
check "a status that stayed is not told again" test ! -e "$t/notified"
PATH="$t/bin:$PATH" DISPLAY=:7 agents handoff set --desk a --status waiting >/dev/null
check "nor the user's own change" test ! -e "$t/notified"
as 1001 handoff set --status working >/dev/null
out=$(as 1001 handoff check tests/run.sh house --ok --note "4 s")
check "a check keeps the commit and the clean tree, read by Vikix: $out" grep -qE 'passed tests/run.sh house on [0-9a-f]{7}, clean tree \(claude 1001\)' <<<"$out"
out=$(agents handoff a)
check "the record shows the task as the user's, the handoff as the agent's: $out" \
  bash -c 'grep -q "^Task (user, just now): Fix the typos" <<<"$1" && grep -q "^Status: working (claude 1001" <<<"$1" && grep -q "^  Read ch1; fixed 3 typos" <<<"$1" && grep -q "^  run the spell check" <<<"$1"' _ "$out"
check "the check is fresh while nothing changed" grep -q 'tests/run.sh house .*clean tree)  fresh$' <<<"$out"
check "the desk's git state now, and who is there, with what holds the rules, honestly" \
  bash -c 'grep -q "^Now: a at .*, nothing uncommitted" <<<"$1" && grep -q "^At the desk now: claude 1001" <<<"$1" && grep -q "pre-edit hooks expected from vikix agent, none seen yet" <<<"$1" && grep -q "no filesystem enforcement" <<<"$1"' _ "$out"

# Stale checks: other uncommitted changes, then a commit.
echo two >> "$t/src/book-a/ch1.md"
out=$(agents handoff a)
check "a check is stale once the tree has changes it didn't see: $out" grep -q 'stale: uncommitted changes since it ran on a clean tree' <<<"$out"
out=$(as 1001 handoff check 'tests/run.sh lint' --failed)
check "a check on a dirty tree says so: $out" grep -q 'failed tests/run.sh lint on .*, tree dirty' <<<"$out"
check "and is fresh for these very changes" grep -q 'FAILED  tests/run.sh lint .*tree dirty)  fresh$' <<<"$(agents handoff a)"
echo three >> "$t/src/book-a/ch1.md"
check "other uncommitted changes make it stale" grep -q 'FAILED  tests/run.sh lint .*stale: the uncommitted changes differ' <<<"$(agents handoff a)"
git -C "$t/src/book-a" commit -qam "ch1"
out=$(agents handoff a)
check "a commit makes every older check stale, naming both commits: $out" grep -qE 'stale: the code moved on \([0-9a-f]{7} then, [0-9a-f]{7} now\)' <<<"$out"
check "--json carries the estimate's minutes and where it stands" python3 -c '
import json, sys
r = json.loads(sys.argv[1])
assert r["handoff"]["estimate"]["minutes"] == 40 and r["handoff"]["estimate"]["by"] == "claude 1001", r["handoff"]
' "$(agents handoff a --json)"
check "--json carries the freshness and the state now" python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["version"] == 1 and r["task"]["by"] == "user" and r["handoff"]["status"]["by"] == "claude 1001", r
assert all(c["freshness"].startswith("stale") for c in r["checks"]), r["checks"]
assert r["now"]["dirty"] == 0 and r["now"]["commit"], r["now"]
assert r["desk"]["id"] and "pid" not in r["desk"], r["desk"]' <<<"$(agents handoff a --json)"

# Sessions: by hand, and Claude Code's from the hook's own input.
out=$(as 1001 handoff session claude 0f1e2d3c-aaaa-bbbb-cccc-123456789abc)
check "a session id is noted by provider: $out" grep -q 'claude session 0f1e2d3c-aaaa-bbbb-cccc-123456789abc noted' <<<"$out"
printf '{"session_id":"11111111-2222-3333-4444-555555555555","tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' \
  "$t/src/book-a" "$t/src/book-a" | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch >/dev/null 2>&1 || true
check "the hook notes Claude Code's session id on the agent's desk, once" \
  test "$(agents handoff a --json | python3 -c 'import json,sys; print(sum(1 for s in json.load(sys.stdin)["sessions"] if s["id"].startswith("1111")))')" = 1
printf '{"session_id":"11111111-2222-3333-4444-555555555555","tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' \
  "$t/src/book-a" "$t/src/book-a" | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch >/dev/null 2>&1 || true
check "the same session again is not a second line" \
  test "$(agents handoff a --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sessions"]))')" = 2
check "the hook's proposed edits now count for the protection shown" grep -q 'claude 1001: pre-edit and pre-shell hooks (vikix agents touch): 2 edits proposed' <<<"$(agents handoff a)"
# Antigravity's hook carries the conversation id instead; noted the same way, as what agy --conversation resumes.
proc 1009 agy "$t/src/book-a"
printf '{"toolCall":{"name":"replace_file_content","args":{"TargetFile":"%s/ch1.md"}},"workspacePaths":["%s"],"conversationId":"aaaaaaaa-1111-2222-3333-444444444444"}' \
  "$t/src/book-a" "$t/src/book-a" | VIKIX_AGENT_PID=1009 python3 "$here/bin/vikix-agents" touch >/dev/null 2>&1 || true
check "the hook notes Antigravity's conversation id on the desk too: $(agents handoff a | grep Sessions)" \
  grep -q 'antigravity aaaaaaaa-1111-2222-3333-444444444444' <<<"$(agents handoff a)"
rm -r "$t/proc/1009"

# A note for the desk's agent: waits in the handoff, delivered by the hook.
out=$(agents tell a "look at chapter two first")
check "a note for the desk's agent: $out" grep -q 'book-a: noted for its agent, delivered at its next tool call' <<<"$out"
check "the handoff shows it waiting" grep -q '^  user (just now): look at chapter two first$' <<<"$(agents handoff a)"
out=$(agents tell a "the key is sk-ant-abcdefghijklmnopqrst")
check "a credential in a note is refused: $out" grep -q 'looks like it holds a credential' <<<"$out"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' "$t/src/book-a" "$t/src/book-a" \
      | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "delivered by the hook at the agent's next edit, signed and timed: $out" \
  grep -q '"additionalContext": "Vikix office, notes for you at this desk (vikix agents tell): \[user, [0-9][0-9]:[0-9][0-9]\] look at chapter two first"' <<<"$out"
check "and gone from the desk" not grep -q 'Notes waiting' <<<"$(agents handoff a)"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/ch1.md"},"cwd":"%s"}' "$t/src/book-a" "$t/src/book-a" \
      | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" touch 2>&1)
check "once: the next edit says nothing: '$out'" test -z "$out"

# Refusals: a credential, an unknown field, a bad session id, an id that is a path.
out=$(agents handoff set --desk a --summary "the key is ANTHROPIC_API_KEY=sk-ant-abcdefghijklmnopqrst")
check "a credential is refused, and nothing kept: $out" \
  bash -c 'grep -q "looks like it holds a credential" <<<"$1" && ! grep -rq "sk-ant" "$2"' _ "$out" "$records"
out=$(echo '{"stat": "working"}' | VIKIX_AGENT_PID=1001 python3 "$here/bin/vikix-agents" handoff set --desk a --from - 2>&1 || true)
check "an unknown field in --from is refused, naming the fields: $out" grep -q 'unknown field: stat (the fields: check, estimate, next, session, status, summary, task)' <<<"$out"
out=$(agents handoff set --desk a --status 'done')
check "a status outside the four is refused: $out" grep -q 'a status is one of working, waiting, review, finished' <<<"$out"
out=$(agents handoff session --desk a codex '../../etc/passwd')
check "a session id that is a path is refused: $out" grep -q 'a session id is letters, digits, dots, dashes' <<<"$out"
out=$(agents handoff session --desk a other 'thread-42')
check "a generic provider uses the same command: $out" grep -q 'other session thread-42 noted' <<<"$out"
check "a record id with a slash is no record" python3 -c '
import sys, importlib.util
spec = importlib.util.spec_from_file_location("h", sys.argv[1]); h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
for bad in ("../x", "abc", "/etc/passwd", "0123456789ab/"):
    try: h.record_path(bad); sys.exit(1)
    except h.HandoffError: pass' "$here/lib/handoff.py"

# --from with the whole shape, as a generic agent would write it.
printf '{"status":"review","summary":"all typos fixed","next":"merge","check":{"name":"spell","ok":true,"note":"0 left"},"session":{"provider":"other","id":"sess-9"}}' > "$t/h.json"
out=$(agents handoff set --desk a --from "$t/h.json")
check "--from FILE sets status, summary, next, a check and a session at once: $out" grep -q 'updated by user, status review' <<<"$out"
check "and the page shows them" bash -c 'grep -q "^Status: review (user" <<<"$1" && grep -q "passed  spell" <<<"$1" && grep -q "other sess-9" <<<"$1"' _ "$(agents handoff a)"

# Twenty-five writers at once: every line lands, the task stays.
before=$(agents handoff a --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["log"]))')
for i in $(seq 1 25); do (agents handoff set --desk a --summary "writer $i" >/dev/null) & done; wait
# The record keeps its last forty log lines (LOG_MAX), so the count stops there.
after=$(agents handoff a --json | python3 -c 'import json,sys; r=json.load(sys.stdin); print(len(r["log"]), r["task"]["text"][:3], sum(1 for e in r["log"][-25:] if e["what"] == "summary"))')
check "twenty-five writers at once lose nothing: $before then $after" test "$after" = "$(( before + 25 > 40 ? 40 : before + 25 )) Fix 25"

# The agent exits (its pid is stale), the desk stays, the record stays; then the worktree goes.
rm -r "$t/proc/1001"
out=$(agents handoff a)
check "after the agent's exit the record is there, with nobody at the desk: $out" \
  bash -c 'grep -q "^Task (user" <<<"$1" && ! grep -q "At the desk now" <<<"$1"' _ "$out"
check "the listing names the desk with its status" grep -q 'book-a  review, just now: Fix the typos' <<<"$(agents handoff list)"
out=$(agents handoff set --desk a --status waiting)
check "a stale pid in the sessions stops nothing: $out" grep -q 'status waiting' <<<"$out"
proc 1002 codex "$t/src/book-a"
check "another provider at the same desk reads the same record, and is shown with instructions only" \
  bash -c 'grep -q "^At the desk now: codex 1002" <<<"$1" && grep -q "codex 1002: instructions only, unless its hook is installed" <<<"$1"' _ "$(as 1002 handoff)"
rm -r "$t/proc/1002"
git -C "$t/src/book-a" checkout -q -- . 2>/dev/null || true
agents close a >/dev/null
check "the worktree is gone" test ! -e "$t/src/book-a"
out=$(agents handoff a)
check "a closed desk's record is kept, by name, and says so: $out" \
  bash -c 'grep -q "closed just now: the record is kept" <<<"$1" && grep -q "^Task (user, .*): Fix the typos" <<<"$1"' _ "$out"
check "the listing says the folder is gone and when it closed" grep -q 'book-a (folder gone)  waiting, .*\[closed just now\]' <<<"$(agents handoff list)"
out=$(agents handoff zzz)
check "a desk that isn't: $out" grep -q 'no desk called zzz' <<<"$out"
out=$(cd "$t" && agents handoff)
check "from nowhere, with no desk named, it says so: $out" grep -q 'no desk here: say which' <<<"$out"

# --- Taking a desk up again: resumed where the provider can, fresh and said why otherwise --------
git -C "$t/src/book" worktree add -q "$t/src/book-c" -b c
printf '#!/bin/sh\necho "AGENT ARGS: $*"\n' > "$t/bin/agent"; chmod +x "$t/bin/agent"
resume() { VIKIX_AGENT_CMD="$t/bin/agent" python3 "$here/bin/vikix-agents" resume "$@" 2>&1 </dev/null || true; }
agents handoff set --desk c --task "Chapter three" >/dev/null
agents tell c "start with the index" >/dev/null
out=$(resume c --here --use claude)
check "a desk with no session noted starts fresh, and says so, after the handoff: $out" \
  bash -c 'grep -q "^Task (user, .*): Chapter three" <<<"$1" && grep -q "^fresh conversation with claude at .*/book-c: no claude session is noted on this desk" <<<"$1" && grep -q "^AGENT ARGS: $" <<<"$1"' _ "$out"
check "the notes waiting are read out, for an agent whose hook can't carry them" grep -q "^  user (just now): start with the index$" <<<"$out"
agents handoff session --desk c claude 0f1e2d3c-aaaa-bbbb-cccc-123456789abc >/dev/null
out=$(resume c --here --use claude)
check "a session whose store is gone starts fresh, naming the store: $out" \
  grep -q "fresh conversation with claude .*: claude's session 0f1e2d3c-aaaa-bbbb-cccc-123456789abc is gone from ~/.claude/projects" <<<"$out"
mkdir -p "$HOME/.claude/projects/-x"; : > "$HOME/.claude/projects/-x/0f1e2d3c-aaaa-bbbb-cccc-123456789abc.jsonl"
out=$(resume c --here --use claude)
check "the session its store still has is resumed, with claude --resume ID: $out" \
  bash -c 'grep -q "^resumed: claude session 0f1e2d3c-aaaa-bbbb-cccc-123456789abc at .*/book-c, its conversation continues" <<<"$1" && grep -q "^AGENT ARGS: --use claude --resume 0f1e2d3c-aaaa-bbbb-cccc-123456789abc$" <<<"$1"' _ "$out"
out=$(resume c --here)
check "without --use the last session's provider is taken" grep -q "^AGENT ARGS: --use claude --resume 0f1e2d3c" <<<"$out"
out=$(resume c --here --fresh)
check "--fresh starts a new conversation all the same: $out" bash -c 'grep -q "a fresh conversation was asked for" <<<"$1" && grep -q "^AGENT ARGS: $" <<<"$1"' _ "$out"
check "the record logs what happened" grep -q '"what": "resumed: claude 0f1e2d3c' "$records"/*.json
# Codex: a rollout file in its store, found by the id; one on disk for the folder is suggested, never taken.
mkdir -p "$HOME/.codex/sessions/2026/10/06"
printf '{"type":"session_meta","payload":{"id":"01a111e5-f7bf-7871-823c-70aee4f44f19","cwd":"%s"}}\n' "$t/src/book-c" \
  > "$HOME/.codex/sessions/2026/10/06/rollout-2026-10-06T19-47-26-01a111e5-f7bf-7871-823c-70aee4f44f19.jsonl"
out=$(resume c --here --use codex)
check "codex with nothing noted: fresh, and the conversation its store has for this folder is suggested, not taken: $out" \
  bash -c 'grep -q "^fresh conversation with codex" <<<"$1" && grep -q "codex.s own store has a conversation in this folder: 01a111e5-f7bf-7871-823c-70aee4f44f19" <<<"$1" && grep -q "nothing is resumed unasked" <<<"$1" && grep -q "^AGENT ARGS: --use codex$" <<<"$1"' _ "$out"
agents handoff session --desk c codex 01a111e5-f7bf-7871-823c-70aee4f44f19 >/dev/null
out=$(resume c --here --use codex)
check "noted, it is resumed with codex resume ID: $out" grep -q "^AGENT ARGS: --use codex resume 01a111e5-f7bf-7871-823c-70aee4f44f19$" <<<"$out"
# OpenCode: its SQLite store.
mkdir -p "$HOME/.local/share/opencode"
python3 -c '
import sqlite3, sys
c = sqlite3.connect(sys.argv[1]); c.execute("create table session (id text, directory text, time_updated integer)")
c.execute("insert into session values (?, ?, ?)", ("ses_abc123", sys.argv[2], 1759780000000)); c.commit()' "$HOME/.local/share/opencode/opencode.db" "$t/src/book-c"
agents handoff session --desk c opencode ses_abc123 >/dev/null
out=$(resume c --here --use opencode)
check "opencode's session, in its database, is resumed with --session ID: $out" grep -q "^AGENT ARGS: --use opencode --session ses_abc123$" <<<"$out"
agents handoff session --desk c opencode ses_gone >/dev/null
out=$(resume c --here --use opencode)
check "one its database hasn't: fresh, saying so: $out" grep -q "opencode's session ses_gone is gone from ~/.local/share/opencode/opencode.db" <<<"$out"
# Antigravity: a conversation folder in its brain, found by the id; the last one for the folder, from its cache, is suggested.
mkdir -p "$HOME/.gemini/antigravity-cli/cache"
printf '{"%s": "5e5e5e5e-1111-2222-3333-444444444444"}\n' "$t/src/book-c" > "$HOME/.gemini/antigravity-cli/cache/last_conversations.json"
out=$(resume c --here --use antigravity)
check "antigravity with nothing noted: fresh, and the folder's last conversation from its cache is suggested, not taken: $out" \
  bash -c 'grep -q "^fresh conversation with antigravity" <<<"$1" && grep -q "antigravity.s own store has a conversation in this folder: 5e5e5e5e-1111-2222-3333-444444444444" <<<"$1" && grep -q "^AGENT ARGS: --use antigravity$" <<<"$1"' _ "$out"
agents handoff session --desk c antigravity 5e5e5e5e-1111-2222-3333-444444444444 >/dev/null
out=$(resume c --here --use antigravity)
check "noted but gone from its brain: fresh, naming the store: $out" grep -q "antigravity's session 5e5e5e5e-1111-2222-3333-444444444444 is gone from ~/.gemini/antigravity-cli/brain" <<<"$out"
mkdir -p "$HOME/.gemini/antigravity-cli/brain/5e5e5e5e-1111-2222-3333-444444444444/.system_generated/logs"
out=$(resume c --here --use antigravity)
check "in its brain, it is resumed with agy --conversation ID: $out" \
  bash -c 'grep -q "^resumed: antigravity session 5e5e5e5e-1111-2222-3333-444444444444 at .*/book-c" <<<"$1" && grep -q "^AGENT ARGS: --use antigravity --conversation 5e5e5e5e-1111-2222-3333-444444444444$" <<<"$1" && ! grep -q unverified <<<"$1"' _ "$out"
# A provider with no resume: fresh, with the handoff; gemini's is unverified and said so.
agents handoff session --desk c other thread-1 >/dev/null
out=$(resume c --here --use other)
check "a generic provider starts fresh with the handoff: $out" bash -c 'grep -q "other can.t resume a session by id" <<<"$1" && grep -q "^AGENT ARGS: --use other$" <<<"$1"' _ "$out"
agents handoff session --desk c gemini abcd-1234 >/dev/null
out=$(resume c --here --use gemini)
check "gemini's store can't be vouched for here: fresh, and said: $out" grep -q "whether gemini still has abcd-1234 can't be known" <<<"$out"
# Never a second agent at the desk unasked; a desk whose folder is gone.
proc 1005 claude "$t/src/book-c"
out=$(resume c --here)
check "an agent at the desk already: refused, with the way to it: $out" grep -q 'claude 1005 is at this desk already: go to it (vikix agents, Super+m), or --another' <<<"$out"
out=$(resume c --here --another --use claude)
check "--another starts a second one there" grep -q "^AGENT ARGS: --use claude --resume 0f1e2d3c" <<<"$out"
rm -r "$t/proc/1005"
out=$(resume a --here)
check "a desk whose folder is gone says how to make it again, and keeps the record: $out" grep -q 'book-a is gone: vikix agents desk book a makes the worktree again (the record is kept' <<<"$out"

# --- The hooks each provider has, honestly; the adapters ---------------------------------------
out=$(agents hooks)
check "hooks says what holds the rules for each provider: $out" \
  bash -c 'grep -q "^claude .*given to Claude Code by vikix agent" <<<"$1" && grep -q "^codex .*unverified on this machine" <<<"$1" && grep -q "^gemini .*not installed by Vikix since that file is yours" <<<"$1" && grep -q "^aider .*no hooks: instructions only" <<<"$1" && grep -q "not installed (vikix agents hooks opencode --install" <<<"$1"' _ "$out"
out=$(agents hooks opencode --install)
check "--install links OpenCode's plugin into its plugins folder: $out" \
  test "$(readlink "$HOME/.config/opencode/plugins/vikix-office.js")" = "$here/config/opencode/vikix-office.js"
check "and codex's hook file" bash -c 'python3 "$1/bin/vikix-agents" hooks codex --install >/dev/null 2>&1; test "$(readlink "$HOME/.codex/hooks.json")" = "$1/config/codex/hooks.json"' _ "$here"
rm "$HOME/.codex/hooks.json"; echo '{}' > "$HOME/.codex/hooks.json"
out=$(agents hooks codex --install)
check "a file of the user's own in the way is left alone: $out" bash -c 'grep -q "is there and isn.t Vikix.s: left alone" <<<"$1" && [ "$(cat "$HOME/.codex/hooks.json")" = "{}" ]' _ "$out"
check "the adapters are valid JSON naming vikix agents touch --for their provider" python3 -c '
import json, sys
for name in ("codex", "gemini"):
    h = json.load(open(f"{sys.argv[1]}/config/{name}/hooks.json"))["hooks"]
    (event, rules), = h.items()
    assert rules[0]["hooks"][0]["command"] == f"vikix agents touch --for {name}", (name, rules)' "$here"
check "OpenCode's plugin asks touch --for opencode and throws on deny and ask" \
  bash -c 'grep -q "\"agents\", \"touch\", \"--for\", \"opencode\"" "$1" && grep -q "permissionDecision === \"deny\" || out.permissionDecision === \"ask\"" "$1"' _ "$here/config/opencode/vikix-office.js"
# touch --for gemini answers in Gemini's shape; --for opencode refuses a clash once, then lets the same edit through.
proc 1006 gemini "$t/src/book"
out=$(printf '{"tool_name":"write_file","tool_input":{"file_path":"%s/log.md"},"cwd":"%s"}' "$t/src/book" "$t/src/book" | VIKIX_AGENT_PID=1006 python3 "$here/bin/vikix-agents" touch --for gemini 2>&1)
check "--for gemini: decision and reason, BeforeTool's shape: $out" python3 -c '
import json, sys; a = json.loads(sys.argv[1]); assert a["decision"] == "deny" and "not at a desk" in a["reason"], a' "$out"
git -C "$t/src/book" worktree add -q "$t/src/book-d" -b d
proc 1007 opencode "$t/src/book-d"; proc 1008 claude "$t/src/book-c"
echo "by c" >> "$t/src/book-c/log.md"
edit_d() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/log.md"},"cwd":"%s"}' "$t/src/book-d" "$t/src/book-d" | VIKIX_AGENT_PID=1007 python3 "$here/bin/vikix-agents" touch --for opencode 2>&1; }
out=$(edit_d)
check "--for opencode: a clash is refused once, with the reason and the way through: $out" \
  grep -q '"permissionDecision": "ask".*claude 1008 .*the same edit within ten minutes goes through' <<<"$out"
out=$(edit_d)
check "the same edit again goes through, quietly: '$out'" test -z "$out"
rm -r "$t/proc/1006" "$t/proc/1007" "$t/proc/1008"

# --- Forgetting the record of a desk whose folder is gone ---------------------------------------
out=$(agents handoff forget)
check "forget with no desk named lists the records whose folder is gone, and asks which: $out" \
  bash -c 'grep -q "book-a  waiting, .*\[closed " <<<"$1" && grep -q "say which: vikix agents handoff forget DESK" <<<"$1"' _ "$out"
out=$(agents handoff forget c)
check "a desk that stands is refused, with close as the way: $out" \
  grep -q 'book-c is there: a desk that stands is closed, not forgotten (vikix agents close book-c' <<<"$out"
proc 1009 claude "$t/src/book-a (deleted)"   # a shell still in the removed folder, as /proc names it
out=$(agents handoff forget a)
check "an agent still in the removed folder: refused: $out" grep -q 'claude 1009 still at work in .*book-a, gone as it is' <<<"$out"
rm -r "$t/proc/1009"
out=$(agents handoff forget d)
check "a desk with no record: nothing to forget: $out" grep -q 'book-d has no record: nothing to forget' <<<"$out"
id=$(python3 -c 'import json, sys, glob
for f in glob.glob(sys.argv[1] + "/*.json"):
    r = json.load(open(f))
    if r["desk"]["worktree"].endswith("book-a"): print(r["desk"]["id"])' "$records")
out=$(agents handoff forget a)
check "forget a: the record goes, and says what stayed: $out" \
  bash -c 'grep -q "forgotten: the record of .*book-a (a, waiting, closed " <<<"$1" && grep -q "no file, no branch, no conversation" <<<"$1"' _ "$out"
check "the record file is gone, its lock kept ($id)" bash -c '[ -n "$2" ] && [ ! -e "$1/$2.json" ] && [ -e "$1/$2.json.lock" ]' _ "$records" "$id"
check "the listing no longer names it" not grep -q 'book-a' <<<"$(agents handoff list)"
out=$(agents handoff forget a)
check "forgetting it again: no such desk: $out" grep -q 'no desk called a' <<<"$out"
out=$(agents handoff forget)
check "nothing left to forget is said: $out" grep -q 'No record of a desk whose folder is gone: nothing to forget' <<<"$out"

# --- Pushing as the user: only when asked, by --push or the picker's last question ----------------
printf '#!/bin/sh\necho "AGENT SSH: ${VIKIX_AGENT_SSH-unset}"\n' > "$t/bin/agent-ssh"; chmod +x "$t/bin/agent-ssh"
desk() { VIKIX_AGENT_CMD="$t/bin/agent-ssh" python3 "$here/bin/vikix-agents" desk "$@" 2>&1 </dev/null || true; }
out=$(desk book c --here)
check "a desk started plainly keeps the SSH agent from the agent: $out" grep -q '^AGENT SSH: unset$' <<<"$out"
out=$(desk book c --here --push)
check "--push hands it over, and says so: $out" \
  bash -c 'grep -q "^AGENT SSH: 1$" <<<"$1" && grep -q "a desk for the agent: .*, and it may push as you" <<<"$1"' _ "$out"
# The picker: rofi is a stand-in answering by prompt, the project (the first), the topic c, the agent (yours).
printf '#!/bin/sh\np=; while [ $# -gt 0 ]; do [ "$1" = -p ] && p=$2; shift; done\necho "$p" >> %s\ncase $p in "Agent on") echo 0;; Topic) echo c;; Agent) echo 0;; Push) cat %s;; esac\n' \
  "$t/rofi-asked" "$t/push-answer" > "$t/bin/rofi"; chmod +x "$t/bin/rofi"
picker() { rm -f "$t/rofi-asked"; echo "$1" > "$t/push-answer"; DISPLAY=:7 PATH="$t/bin:$PATH" desk --here; }
out=$(picker 0)
check "the picker asks about pushing last, after the agent: $(tr '\n' ' ' < "$t/rofi-asked")" \
  bash -c '[ "$(tail -1 "$1")" = Push ] && grep -qx Agent "$1"' _ "$t/rofi-asked"
check "no keeps the SSH agent back: $out" grep -q '^AGENT SSH: unset$' <<<"$out"
out=$(picker 1)
check "yes hands it over: $out" grep -q '^AGENT SSH: 1$' <<<"$out"
printf '#!/bin/sh\nexit 1\n' > "$t/bin/rofi"
out=$(DISPLAY=:7 PATH="$t/bin:$PATH" desk --here)
check "the picker closed at any question starts nothing: '$out'" not grep -q 'AGENT SSH' <<<"$out"

[ $fail = 0 ] && echo "handoff: ok (a desk's task, handoff, checks and sessions kept apart and across sessions; stale checks said; writers at once lose nothing; refusals; a gone desk's record forgotten, a standing one refused; resume where the provider can, fresh and said why otherwise; the hooks each has)"
exit $fail
