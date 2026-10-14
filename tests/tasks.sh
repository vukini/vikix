#!/usr/bin/env bash
# tests/tasks.sh — the office's tasks (lib/tasks.py; vikix agents tasks,
# task, events, exited), without a screen: a made-up home, a repository
# with worktrees for desks, a stand-in agent and a made-up /proc.
#
#   A task from each way in has an id, its origin and a launch number:
#   desk --task, worker (the task before it blocked on its worker, kept),
#   a session at a desk with a task (a launch of it, no new task), resume
#   (the next number; another provider is a handoff between them), sit
#   --task (the agent's own, running with no number: the office never
#   started it), handoff --task (the words of a task that has one change,
#   its id stays; a new one at a desk with an agent runs unnumbered); the
#   launcher's exit line ends the launch with its code and blocks the task
#   on its worker, never completing it; the SessionEnd hook the same; the
#   agent's four words read into the table (working, waiting, review,
#   finished; parked blocked), a word that asks for the state it is in
#   moves nothing; the tester's failure blocks a task whose worker is gone
#   and sends one in review back to work while the worker is there; the
#   release completes with the version; close completes a merged branch
#   and cancels a forced one. Every transition in the table, and a refused
#   one; the sequence never repeats across twenty launches at once; a
#   credential is refused everywhere: every text the module takes (the
#   words, the project, the topic, the source, who, a reason, what blocks,
#   a launch's provider, how and mode, how a worker left, the worker's
#   choices, the words changed under a record), the arms (handoff --task,
#   worker, desk --task) before any record is made, and the words of a
#   record from before, withheld at adoption; an unknown key in a record
#   is refused. Records from before are adopted with what
#   they knew (the handoff status read into a state, a history entry with
#   none cancelled, a desk the release closed completed) and the rest
#   unknown, never invented; adopted once, the ids written back into the
#   desk record and nothing else of it touched. The worker's state is read
#   from the agent's row and the launches, with its source and how sure.
#   The event log has every kind the design names, and by the end holds
#   every kind phase 1 writes; a task's history is read back from it, a
#   desk's, all, since when.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME VIKIX_AGENT_SSH VIKIX_TASK_ORIGIN
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc" VIKIX_TESTER=0
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/proc" "$t/bin"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; git add log.md; git commit -q -m first
for d in c d e f g; do git worktree add -q "$t/src/book-$d" -b "$d"; done
cd "$here"
# The agent: says its words, and ends with the code the file asks (0 by default).
printf '#!/bin/sh\necho "AGENT ARGS: $*"\nexit "$(cat %s 2>/dev/null || echo 0)"\n' "$t/exit-code" > "$t/bin/agent"; chmod +x "$t/bin/agent"
export VIKIX_AGENT_CMD="$t/bin/agent"
proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
as() { local pid=$1; shift; VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
tasks="$HOME/.local/state/vikix/office/tasks"
events() { cat "$HOME"/.local/state/vikix/office/events-*.jsonl 2>/dev/null || true; }
field() {   # field TASK-ID EXPR: a python expression over the record t
  python3 -c 'import json, sys; t = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$tasks/$1.json" "$2"
}
task_of() {   # task_of DESK: the id of the desk's task, from its record
  agents handoff "$1" --json | python3 -c 'import json, sys; print(json.load(sys.stdin).get("task", {}).get("id", ""))'
}
py() { python3 -B -c "import sys; sys.path.insert(0, '$here/lib'); import tasks as T, handoff as H
$1" "${@:2}" || true; }   # a refusal is an answer, not the test's end
export -f agents as events field task_of py
export here tasks VIKIX_PROC

# --- A task from each way in ---------------------------------------------------------------
out=$(agents desk book a --task "Write chapter one" --here --use claude)
check "desk --task starts a worker, the task its first prompt: $out" grep -q "^AGENT ARGS: --use claude Write chapter one$" <<<"$out"
a=$(task_of a)
check "the desk's record points at a task record by id: '$a'" grep -qE '^t-[0-9]{8}-[0-9a-f]{6}$' <<<"$a"
check "the task: yours, the words, the desk, launch #1 by desk --task" \
  test "$(field "$a" 't["origin"]["kind"], t["title"], t["desk"]["branch"], t["launch"]["seq"], t["launch"]["how"], t["launch"]["provider"]')" = "('user', 'Write chapter one', 'a', 1, 'desk --task', 'claude')"
# The stand-in ended at once, with 0: the launcher's exit line reached the task.
check "the launcher's exit line ends the launch with its code and blocks the task on its worker (never completed)" \
  test "$(field "$a" 't["status"]["value"], t["blocked"]["on"], t["launches"][-1]["code"], t["done"]')" = "('blocked', 'worker', 0, None)"
check "the worker's state is read from the launch: exited, reliable, the exit line" \
  test "$(py 'print(T.worker_state(None, T.load(sys.argv[1]))["state"], T.worker_state(None, T.load(sys.argv[1]))["sure"])' "$a")" = "exited reliable"
echo 2 > "$t/exit-code"
out=$(agents worker c "Chapter two" --here --use claude --push --no-tests)
c=$(task_of c)
check "worker: a task of its own, launch #2, the worker's choices kept: $out" \
  test "$(field "$c" 't["launch"]["seq"], t["worker"]["push"], t["worker"]["no_tests"], t["worker"]["use"]')" = "(2, True, True, 'claude')"
check "an exit code other than 0 is failed in the worker's state" \
  test "$(py 'w = T.worker_state(None, T.load(sys.argv[1])); print(w["state"], w["code"], w["sure"])' "$c")" = "failed 2 reliable"
rm -f "$t/exit-code"
py 'T.move(sys.argv[1], "running", "user", "started again by hand")' "$c"   # as if its worker were still at it
out=$(agents worker c "Chapter two, the index" --here)
c2=$(task_of c)
check "a second worker on another task: a new task, and the one before blocked on worker, kept" \
  bash -c '[ "$1" != "$2" ] && [ "$(field "$1" "t[\"status\"][\"value\"], t[\"blocked\"][\"on\"], t[\"status\"][\"reason\"]")" = "('"'"'blocked'"'"', '"'"'worker'"'"', '"'"'another task started at its desk'"'"')" ]' _ "$c" "$c2"
check "and the desk's history entry names the task it folded" \
  test "$(agents handoff c --json | python3 -c 'import json, sys; print(json.load(sys.stdin)["workers"][-1]["task_id"])')" = "$c"
check "the new one is #3" test "$(field "$c2" 't["launch"]["seq"]')" = 3
out=$(agents worker c --here)
check "a session at the desk launches the open task again (#4), no new task: $out" \
  bash -c '[ "$(task_of c)" = "$1" ] && [ "$(field "$1" "t[\"launch\"][\"seq\"], t[\"launch\"][\"how\"], len(t[\"launches\"])")" = "(4, '"'"'session'"'"', 2)" ]' _ "$c2"
out=$(agents resume c --here --use codex)
check "resume: the next number, and another provider is a handoff between them: $out" \
  test "$(field "$c2" 't["launch"]["seq"], t["launch"]["provider"], t["launch"]["how"]')" = "(5, 'codex', 'resume')"
check "the events say so" bash -c 'grep -q "\"kind\": \"handed off\".*\"from\": \"claude\", \"to\": \"codex\"" <<<"$(events)"'
# An agent sits down itself, with its task: the office never started it, so no number.
proc 1010 claude "$t/src/book-d"
out=$(cd "$t/src/book-d" && as 1010 sit book d --task "Chapter four, on my own")
d=$(task_of d)
check "sit --task: the agent's own task, running, with no launch number: $out" \
  test "$(field "$d" 't["origin"]["kind"], t["origin"]["by"], t["status"]["value"], t["launch"]["seq"], t["launch"]["how"]')" = "('agent', 'claude 1010', 'running', None, 'sit')"
check "the page says the launch order is unknown" grep -q '^Launch: launch order unknown claude' <<<"$(agents task "$d")"
# handoff --task: the words of a task that has one change, its id stays.
agents handoff d --task "Chapter four, on my own, and its notes" >/dev/null
check "handoff --task on a desk with a task keeps the id, the words change" \
  bash -c '[ "$(task_of d)" = "$1" ] && [ "$(field "$1" "t[\"title\"]")" = "Chapter four, on my own, and its notes" ]' _ "$d"
proc 1011 codex "$t/src/book-e"
agents handoff e --task "Chapter five, given later" >/dev/null
e=$(task_of e)
check "handoff --task at a desk with an agent at it: a new task, running, unnumbered (how: handoff --task)" \
  test "$(field "$e" 't["origin"]["kind"], t["status"]["value"], t["launch"]["seq"], t["launch"]["how"], t["launch"]["provider"]')" = "('user', 'running', None, 'handoff --task', 'codex')"
agents handoff f --task "Chapter six, for later" >/dev/null
f=$(task_of f)
check "at a desk with nobody: ready, not launched" test "$(field "$f" 't["status"]["value"], t["launch"]')" = "('ready', {})"

# --- The agent's words, read into the table ------------------------------------------------------
as 1010 handoff --status working --summary "started" >/dev/null
check "working on a running task moves nothing, and is noted in the task's log" \
  test "$(field "$d" 't["status"]["value"], t["log"][-1]["what"]')" = "('running', 'handoff status working: it is running already')"
as 1010 handoff --status waiting --next "which tense?" >/dev/null
check "waiting is needs decision, the handoff copied into the task" \
  test "$(field "$d" 't["status"]["value"], t["handoff"]["next"]["text"]')" = "('needs decision', 'which tense?')"
as 1010 handoff --status working >/dev/null
check "working again from needs decision is answered" test "$(field "$d" 't["status"]["value"]')" = "running"
check "with the event" bash -c 'grep -q "\"kind\": \"answered\"" <<<"$(events)"'
as 1010 handoff --status review >/dev/null
check "review is needs review" test "$(field "$d" 't["status"]["value"]')" = "needs review"
as 1010 handoff --status finished >/dev/null
check "finished is ready for release, never completed" test "$(field "$d" 't["status"]["value"], t["done"]')" = "('ready for release', None)"
as 1011 handoff --status parked >/dev/null
check "parked is blocked, on parked" test "$(field "$e" 't["status"]["value"], t["blocked"]["on"]')" = "('blocked', 'parked')"
as 1011 handoff --status review >/dev/null
check "a worker reporting from a blocked task ends the block" test "$(field "$e" 't["status"]["value"]')" = "needs review"
# The SessionEnd hook: the last launch ends, and a running task is blocked on its worker.
as 1011 handoff --status working >/dev/null
echo '{"reason":"logout"}' | VIKIX_AGENT_PID=1011 python3 "$here/bin/vikix-agents" left >/dev/null 2>&1
check "left blocks a running task on its worker, how it left kept" \
  test "$(field "$e" 't["status"]["value"], t["blocked"]["on"], t["launches"][-1]["left"]')" = "('blocked', 'worker', 'logout')"
check "the worker's state: exited, reliable, from the hook's note" \
  test "$(py 'w = T.worker_state(None, T.load(sys.argv[1])); print(w["state"], w["sure"])' "$e")" = "exited reliable"
rm -r "$t/proc/1011"
# The exit line's arm by itself, without a terminal, on a task running again.
py 'T.move(sys.argv[1], "running", "user", "started again by hand")' "$e"
out=$(cd "$t/src/book-e" && agents exited --code 7)
check "exited --code without --task finds the desk's task by the folder, quietly: '$out'" \
  bash -c '[ -z "$1" ] && [ "$(field "$2" "t[\"status\"][\"reason\"]")" = "the worker stopped: exit 7" ]' _ "$out" "$e"
# The tester's result (the task running again first: the user's sent back).
py 'T.move(sys.argv[1], "running", "user", "back to work"); print(T.tests_moved(sys.argv[1], False, ["spell"], False)["status"]["value"], T.load(sys.argv[1])["blocked"]["on"])' "$d" > "$t/out"
check "a failed check with the worker gone blocks the task on the tests: $(cat "$t/out")" test "$(cat "$t/out")" = "blocked tests"
py 'T.move(sys.argv[1], "running", "user", "retry"); T.handoff_move(sys.argv[1], "review", "claude 1"); print(T.tests_moved(sys.argv[1], False, ["spell"], True)["status"]["value"])' "$d" > "$t/out"
check "failed with the worker there, a task in review goes back to running: $(cat "$t/out")" test "$(cat "$t/out")" = running
check "passed moves nothing" test "$(py 'print(T.tests_moved(sys.argv[1], True, [], True)["status"]["value"])' "$d")" = running
check "tests started is a kind of the log, and tests done carries the task now" python3 -c '
import sys; sys.path.insert(0, sys.argv[1]); import tasks as T; assert "tests started" in T.KINDS and "tests done" in T.KINDS' "$here/lib"

# --- The release, and close --------------------------------------------------------------------
out=$(python3 "$here/lib/tasks.py" released "$t/src/book/.git" "$t/src/book-d" 0.9.1; echo "exit $?")
check "released completes the desk's open task, with the version: $out" \
  test "$(field "$d" 't["status"]["value"], t["status"]["by"], t["status"]["reason"]')" = "('completed', 'release', 'released as 0.9.1')"
check "the events: released with the version, then completed" \
  bash -c 'grep -q "\"kind\": \"released\".*\"version\": \"0.9.1\"" <<<"$(events)" && grep -q "\"kind\": \"completed\".*\"version\": \"0.9.1\"" <<<"$(events)"'
check "a desk with no open task says so by its exit" test "$(python3 "$here/lib/tasks.py" released "$t/src/book/.git" "$t/src/book-d"; echo $?)" = 1
check "a task completed is final: nothing moves it" grep -q 'is completed, which is final' <<<"$(py 'T.move(sys.argv[1], "running", "user")' "$d" 2>&1)"
rm -r "$t/proc/1010"
git -C "$t/src/book" merge -q --ff-only d 2>/dev/null || git -C "$t/src/book" merge -q d
agents close d >/dev/null
echo "f" > "$t/src/book-f/f.md"; git -C "$t/src/book-f" add f.md; git -C "$t/src/book-f" commit -q -m f   # work of its own, not in
echo "x" > "$t/src/book-f/x.md"
agents close f --force >/dev/null
check "close with --force cancels the desk's open task, the work thrown away" \
  test "$(field "$f" 't["status"]["value"], t["status"]["reason"]')" = "('cancelled', 'desk closed with --force, its work thrown away')"
git -C "$t/src/book" worktree add -q "$t/src/book-h" -b h >/dev/null 2>&1
agents handoff h --task "Chapter eight" >/dev/null; h=$(task_of h)
echo "h" > "$t/src/book-h/h.md"; git -C "$t/src/book-h" add h.md; git -C "$t/src/book-h" commit -q -m h
git -C "$t/src/book" merge -q h
agents close h >/dev/null
check "close with the branch merged completes the task" test "$(field "$h" 't["status"]["value"], t["status"]["reason"]')" = "('completed', 'desk closed, its branch merged')"

# --- The table: every transition, and a refused one ---------------------------------------------
py '
import json, os
ok = bad = 0
for frm, to in sorted(T.TRANSITIONS, key=str):
    if frm is None:
        continue
    t = T.new("a step", "book", "user")
    T.update(t["id"], lambda r: r["status"].update(value=frm))
    try:
        T.move(t["id"], to, "user", "the table")
        ok += 1
    except T.TaskError as e:
        print("refused", frm, to, e); bad += 1
    os.unlink(T.path(t["id"]))
print("moves", ok, "refused", bad)
t = T.new("a step", "book", "user")
for to in ("completed", "needs review", "blocked"):
    try:
        T.move(t["id"], to, "user")
        print("not refused:", to)
    except T.TaskError as e:
        print("refused:", str(e)[:40])
T.move(t["id"], "cancelled", "user", "never mind")
print(T.load(t["id"])["status"]["value"], T.load(t["id"])["done"] is not None)
os.unlink(T.path(t["id"]))' > "$t/out"
check "every transition of the table moves: $(cat "$t/out")" grep -q "^moves $(python3 -c "import sys; sys.path.insert(0, '$here/lib'); import tasks as T; print(sum(1 for f, _ in T.TRANSITIONS if f))") refused 0$" "$t/out"
check "and ready goes nowhere but queued, running or cancelled (completed only by the work being in)" test "$(grep -c '^refused:' "$t/out")" = 3
check "cancelled from any state but completed, final, with done" grep -q '^cancelled True$' "$t/out"
check "every kind the design names is a kind of the log" python3 -c '
import sys; sys.path.insert(0, sys.argv[1]); import tasks as T
for k in ("created", "approved", "priority", "ordered", "queued", "deferred", "launched", "paused", "resumed", "asked", "answered",
          "handoff", "tests started", "tests done", "review asked", "accepted", "sent back", "blocked", "unblocked", "exited",
          "handed off", "released", "completed", "cancelled", "proposed", "uncertain", "adopted"):
    assert k in T.KINDS, k
try:
    T.event("made up", "user"); raise SystemExit("not refused")
except T.TaskError:
    pass' "$here/lib"

# --- The sequence, at once -----------------------------------------------------------------------
rm -f "$HOME/.local/state/vikix/office/sequence"
for _ in $(seq 20); do py 'print(T.next_seq())' >> "$t/seqs" & done; wait
check "twenty launches at once take twenty numbers, none twice: $(sort -n "$t/seqs" | tr '\n' ' ')" \
  test "$(sort -n "$t/seqs" | uniq | wc -l)" = 20 -a "$(sort -n "$t/seqs" | tail -1)" = 20
check "the number never goes down" test "$(py 'print(T.sequence())')" = 20

# --- Refusals ---------------------------------------------------------------------------------
out=$(py 'T.new("the key is sk-ant-abcdefghijklmnopqrstu", "book", "user")' 2>&1)
check "a credential in a task's words is refused: $out" grep -q 'looks like it holds a credential' <<<"$out"
out=$(py 'T.move(sys.argv[1], "running", "user", "token ghp_abcdefghijklmnopqrstuvwxyz")' "$e" 2>&1)
check "and in a reason: $out" grep -q 'looks like it holds a credential' <<<"$out"
python3 -c 'import json, sys; p = sys.argv[1]; t = json.load(open(p)); t["colour"] = "red"; json.dump(t, open(p, "w"))' "$tasks/$f.json"
out=$(py 'T.update(sys.argv[1], lambda r: None)' "$f" 2>&1)
check "an unknown key in a record is refused at its next write: $out" grep -q 'unknown field: colour' <<<"$out"
python3 -c 'import json, sys; p = sys.argv[1]; t = json.load(open(p)); del t["colour"]; json.dump(t, open(p, "w"))' "$tasks/$f.json"
out=$(agents task ../x)
check "a task id that is a path is a desk's name, and refused as such: $out" grep -q 'no desk called' <<<"$out"

# A credential is refused everywhere: every text a task record takes, from
# the module (the words, the project, the topic, the source, who; a reason,
# what blocks; a launch's provider, how and mode; how a worker left; the
# worker's choices; a record's words changed under it), from the arms
# (handoff --task, worker, desk --task: refused before any record is made),
# and in a record from before, whose words are withheld at adoption.
cred="sk-ant-abcdefghijklmnopqrstu"
py '
import os
cred = sys.argv[1]
t = T.new("a step", "book", "user")
T.move(t["id"], "running", "user", "to work")
tries = {
    "new: the words": lambda: T.new(cred, "book", "user"),
    "new: the project": lambda: T.new("ok", cred, "user"),
    "new: who": lambda: T.new("ok", "book", cred),
    "new: the topic": lambda: T.new("ok", "book", "user", topic=cred),
    "new: the source": lambda: T.new("ok", "book", "user", kind="automation", source=cred),
    "new: the worker choices, use": lambda: T.new("ok", "book", "user", worker={"use": cred}),
    "new: the worker choices, mode": lambda: T.new("ok", "book", "user", worker={"mode": cred}),
    "move: the reason": lambda: T.move(t["id"], "needs review", "user", cred),
    "move: what blocks": lambda: T.move(t["id"], "blocked", "user", "x", blocked_on=cred),
    "launch: the provider": lambda: T.launch(t["id"], cred, "user", "worker"),
    "launch: how": lambda: T.launch(t["id"], "claude", "user", cred),
    "launch: the mode": lambda: T.launch(t["id"], "claude", "user", "worker", mode=cred),
    "launch: who": lambda: T.launch(t["id"], "claude", cred, "worker"),
    "exited: how it left": lambda: T.exited(t["id"], reason=cred),
    "update: the words changed under it": lambda: T.update(t["id"], lambda r: r.update(text=cred)),
    "update: the title": lambda: T.update(t["id"], lambda r: r.update(title=cred)),
}
bad = []
for name, go in tries.items():
    try:
        go(); bad.append(name)
    except T.TaskError as e:
        if "credential" not in str(e):
            bad.append(name + " (refused for another reason: " + str(e) + ")")
print("refused all" if not bad else "let through: " + "; ".join(bad))
print(T.load(t["id"])["status"]["value"], T.load(t["id"])["launches"])
os.unlink(T.path(t["id"]))' "$cred" > "$t/out"
check "every text of the module refuses a credential: $(head -1 "$t/out")" test "$(head -1 "$t/out")" = "refused all"
check "and nothing of the refused writes reached the record: $(tail -1 "$t/out")" test "$(tail -1 "$t/out")" = "running []"
before=$(ls "$tasks" | wc -l)
out=$(agents handoff c --task "the key is $cred")
check "handoff --task refuses it before any record is made: $out" bash -c 'grep -q "looks like it holds a credential" <<<"$1" && [ "$(ls "$2" | wc -l)" = "$3" ]' _ "$out" "$tasks" "$before"
out=$(agents worker c --here "the key is $cred")
check "worker the same, and no agent starts: $out" bash -c 'grep -q "looks like it holds a credential" <<<"$1" && ! grep -q "AGENT ARGS" <<<"$1" && [ "$(ls "$2" | wc -l)" = "$3" ]' _ "$out" "$tasks" "$before"
out=$(agents desk book z --task "the key is $cred" --here)
check "desk --task the same: $out" bash -c 'grep -q "looks like it holds a credential" <<<"$1" && ! grep -q "AGENT ARGS" <<<"$1" && [ "$(ls "$2" | wc -l)" = "$3" ]' _ "$out" "$tasks" "$before"
check "nothing of it in the events" bash -c '! grep -q "$1" <<<"$(events)"' _ "$cred"
check "nor in the task records" bash -c '! grep -rq "$1" "$2"' _ "$cred" "$tasks"

# --- Records from before, adopted ---------------------------------------------------------------
records="$HOME/.local/state/vikix/office/desks"
git -C "$t/src/book" worktree add -q "$t/src/book-old" -b old >/dev/null 2>&1
old_id=$(py 'print(H.desk_id(sys.argv[1], sys.argv[2]))' "$t/src/book/.git" "$t/src/book-old")
python3 - "$records/$old_id.json" "$old_id" "$t/src/book-old" <<'PY'
import json, sys
path, did, folder = sys.argv[1:]
rec = {"version": 1, "desk": {"id": did, "repo": "", "worktree": folder, "branch": "old", "project": "book", "made": 1791000000, "closed": 0},
       "task": {"text": "The old task", "by": "claude 9", "at": 1791100000},
       "handoff": {"status": {"value": "review", "by": "claude 9", "at": 1791100500}},
       "checks": [], "sessions": [], "observed": {}, "log": [{"at": 1791100000, "by": "claude 9", "what": "task set"}],
       "launch": {"provider": "claude", "mode": "", "by": "user", "at": 1791100100},
       "workers": [{"task": "An older task", "by": "user", "at": 1790900000, "ended": 1790950000, "status": "finished", "summary": "done", "provider": "codex"},
                   {"task": "A task with no status", "by": "user", "at": 1790960000, "ended": 1790990000, "status": "", "summary": ""}],
       "updated": 1791100500}
json.dump(rec, open(path, "w"), indent=1)
PY
out=$(agents tasks adopt)
check "adopt makes a record for the task and for each history entry: $out" grep -q '^3 task records made' <<<"$out"
live=$(task_of old)
check "the live one: by the agent, so its origin is unknown and says who; the status read into the table; the launch from the record, with no number" \
  test "$(field "$live" 't["origin"]["kind"], t["origin"]["by"], t["status"]["value"], t["launch"]["seq"], t["launch"]["provider"], t["launched"], t["created"], t["priority"]')" = "('unknown', 'claude 9', 'needs review', None, 'claude', 1791100100, 1791100000, 'normal')"
check "the page says what is unknown, never a made-up number" \
  bash -c 'grep -q "^Launch: launch order unknown claude" <<<"$1" && grep -q "^Origin: unknown (set by claude 9)" <<<"$1" && grep -q "queued: unknown" <<<"$1"' _ "$(agents task "$live")"
check "the event adopted lists what wasn't known" bash -c 'grep -q "\"kind\": \"adopted\".*\"unknown\": \[.*launch order" <<<"$(events)"'
check "the history: finished is ready for release (the agent's word), none cancelled; created from at, done from ended" python3 - "$records/$old_id.json" "$tasks" <<'PY'
import json, sys, glob
rec = json.load(open(sys.argv[1]))
ids = [w["task_id"] for w in rec["workers"]]
a, b = (json.load(open(f"{sys.argv[2]}/{i}.json")) for i in ids)
assert a["status"]["value"] == "ready for release" and a["created"] == 1790900000 and a["done"] is None and a["worker"]["use"] == "codex", a
assert b["status"]["value"] == "cancelled" and b["done"] == 1790990000, b
assert rec["task"]["id"] and rec["updated"] == 1791100500 and rec["desk"]["closed"] == 0, (rec["task"], rec["updated"])
PY
out=$(agents tasks adopt)
check "adopted once: a second run makes nothing: $out" grep -q '^0 task records made' <<<"$out"
# A desk the release closed, from before: its task is completed.
closed_id=$(py 'print(H.desk_id(sys.argv[1], sys.argv[2]))' "$t/src/book/.git" "$t/src/book-gone")
python3 - "$records/$closed_id.json" "$closed_id" "$t/src/book-gone" <<'PY'
import json, sys
path, did, folder = sys.argv[1:]
rec = {"version": 1, "desk": {"id": did, "repo": "", "worktree": folder, "branch": "gone", "project": "book", "made": 1791000000, "closed": 1791200000},
       "task": {"text": "A released task", "by": "user", "at": 1791100000}, "handoff": {},
       "checks": [], "sessions": [], "observed": {}, "log": [{"at": 1791200000, "by": "release", "what": "desk closed"}], "updated": 1791200000}
json.dump(rec, open(path, "w"), indent=1)
PY
agents tasks adopt >/dev/null
gone=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["task"]["id"])' "$records/$closed_id.json")
check "a desk the release closed: completed, done when it closed, yours" \
  test "$(field "$gone" 't["status"]["value"], t["done"], t["origin"]["kind"]')" = "('completed', 1791200000, 'user')"
check "adopting is one of the office's events, and a record with a bad desk id is left alone" python3 -c '
import sys; sys.path.insert(0, sys.argv[1]); import tasks as T
assert T.adopt([{"desk": {"id": "nope"}, "task": {"text": "x", "by": "user", "at": 1}}]) == []' "$here/lib"

# A record from before whose words hold a credential: adopted with its
# words withheld and said so, the credential in no task record.
cred_id=$(py 'print(H.desk_id(sys.argv[1], sys.argv[2]))' "$t/src/book/.git" "$t/src/book-cred")
python3 - "$records/$cred_id.json" "$cred_id" "$t/src/book-cred" "$cred" <<'PY'
import json, sys
path, did, folder, cred = sys.argv[1:]
rec = {"version": 1, "desk": {"id": did, "repo": "", "worktree": folder, "branch": "cred", "project": "book", "made": 1791000000, "closed": 0},
       "task": {"text": "The key is " + cred, "by": "user", "at": 1791100000}, "handoff": {},
       "checks": [], "sessions": [], "observed": {}, "log": [], "updated": 1791100000}
json.dump(rec, open(path, "w"), indent=1)
PY
out=$(agents tasks adopt)
check "adopted, one record: $out" grep -q '^1 task record made' <<<"$out"
withheld=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["task"]["id"])' "$records/$cred_id.json")
check "its words withheld, said in the page, the credential nowhere in the records or the log" \
  bash -c '[ "$(field "$1" "t[\"text\"]")" = "(a task whose words look like a credential, withheld)" ] && grep -q "unknown: .*its words" <<<"$(agents task "$1")" && ! grep -rq "$2" "$3" && ! grep -q "$2" <<<"$(events)"' _ "$withheld" "$cred" "$tasks"
rm -f "$records/$cred_id.json" "$tasks/$withheld.json"

# --- The worker's state, read ----------------------------------------------------------------------
py '
t = {"id": "t-20261013-000000", "launch": {"at": 1, "seq": 1}, "launches": [{"at": 1, "seq": 1, "ended": None}]}
def s(agent, task=t, **kw): w = T.worker_state(agent, task, **kw); return w["state"] + "/" + w["sure"]
print(s({"state": "asks", "agent": "claude", "said": "May I?"}), s({"state": "asks", "agent": "codex"}), s({"state": "question"}),
      s({"state": "done"}), s({"state": "idle", "agent": "claude"}), s({"state": "idle", "agent": "codex"}),
      s({"state": "working"}), s({"state": "running"}), s({"state": "working", "paused": {"by": "user"}}),
      s({"state": "idle", "waits": "a test slot"}), s({"state": "odd"}),
      s(None, now=30), s(None, now=1000), s(None, {"id": "t-20261013-000001", "launch": {}}))' > "$t/out"
check "each row of the table, with how sure: $(cat "$t/out")" \
  test "$(cat "$t/out")" = "waiting for permission/reliable waiting for permission/inferred waiting for input/reliable idle/reliable idle/reliable idle/inferred running/inferred running/inferred paused/reliable held/reliable unknown/unknown failed/inferred exited/inferred unknown/unknown"

# --- The log, read back -----------------------------------------------------------------------------
out=$(agents events "$c2")
check "a task's history, newest first, each event a line: $out" \
  bash -c 'grep -q "launched #5  by user  provider codex, how resume" <<<"$1" && grep -q "handed off  by user  claude -> codex" <<<"$1" && [ "$(tail -1 <<<"$1" | grep -c "created  by user")" = 1 ]' _ "$out"
out=$(agents events c)
check "a desk's: by its name, the handoff lines of lib/handoff.py among them, each naming the task" \
  bash -c 'grep -q "worker  by user  task Chapter two" <<<"$1"' _ "$out"
check "the handoff lines carry the task's id" bash -c 'grep -q "\"kind\": \"worker\", \"task\": \"t-" <<<"$(events)"'
check "--all is every event, --limit bounds it" test "$(agents events --all --limit 3 | wc -l)" = 3
check "--since a date takes what came after it" test "$(agents events --all --since 2026-01-01 --limit 1000 | wc -l)" -gt 20
check "--since in the future finds nothing" test "$(agents events --all --since "$(( $(date +%s) + 3600 ))" | head -1)" = "No event since then (the log: ~/.local/state/vikix/office/events-YYYY-MM.jsonl)."
out=$(agents events --since soon)
check "--since that names no time is refused: $out" grep -q -- '--since takes a span' <<<"$out"
out=$(agents tasks)
check "the list: the open ones in launch order with their numbers, the unnumbered after, then the done ones: $out" \
  bash -c 'grep -q "^  #2 " <<<"$1" && grep -q "^  #?     ready " <<<"$1" && grep -q "^Done in the last day" <<<"$1" && grep -q "completed .* Chapter four, on my own" <<<"$1"' _ "$out"
check "--json is the records" test "$(agents tasks --json | python3 -c 'import json, sys; print(type(json.load(sys.stdin)).__name__)')" = list
out=$(agents task c)
check "task by a desk's name is the desk's task, with its history: $out" \
  bash -c 'grep -q "^Task $2: Chapter two, the index" <<<"$1" && grep -q "^History (" <<<"$1" && grep -q "^Launches: 3" <<<"$1"' _ "$out" "$c2"
check "every form of the work is in help" test "$(agents help work | grep -c '^  vikix agents')" = 4
rm -f "$HOME/.config/vikix/office"
export VIKIX_TASK_ORIGIN="plan chapters"
agents handoff g --task "A plan's task" >/dev/null; g=$(task_of g)
check "a task an automation makes says so: by the plan" \
  test "$(field "$g" 't["origin"]["kind"], t["origin"]["source"]')" = "('automation', 'plan chapters')"
check "and the page words it" grep -q "^Origin: by plan chapters" <<<"$(agents task "$g")"
unset VIKIX_TASK_ORIGIN

# The log, by the end, holds every kind phase 1 writes (the design's
# kinds that a later phase brings are in KINDS, written by nothing yet).
py 'H.update(sys.argv[1], sys.argv[2], lambda r: H.add_check(r, "spell", False, "vikix", sys.argv[2], ""))' "$t/src/book/.git" "$t/src/book-c" >/dev/null
check "tests done, from a check of the desk record, carries the task" bash -c 'grep -q "\"kind\": \"tests done\", \"task\": \"t-" <<<"$(events)"'
missing=$(python3 - "$HOME/.local/state/vikix/office" <<'PY'
import glob, json, sys
seen = {json.loads(l)["kind"] for f in glob.glob(sys.argv[1] + "/events-*.jsonl") for l in open(f) if l.strip()}
phase1 = {"created", "approved", "queued", "deferred", "launched", "asked", "answered", "handoff", "tests done",
          "review asked", "accepted", "sent back", "blocked", "unblocked", "exited", "handed off", "released", "completed",
          "cancelled", "adopted", "worker", "closed", "left"}
print(" ".join(sorted(phase1 - seen)))
PY
)
check "every kind phase 1 writes is in the log (missing: '$missing')" test -z "$missing"

[ $fail = 0 ] && echo "tasks: ok (a task from each way in with its id, origin and launch number; the launcher's exit line and the hook block, never complete; the agent's words read into the table; the tester, the release and close move; every transition, the sequence at once, refusals; records from before adopted with their gaps unknown; the worker's state with how sure; the log read back)"
exit $fail
