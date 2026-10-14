#!/usr/bin/env bash
# tests/reconnect.sh — an agent the network stopped is taken up again when it
# is back (vikix agents reconnect, and the watcher its hook starts), with a
# stand-in agent that is a real process, a made-up home and /proc, a planted
# Claude Code transcript, and a local port standing in for the API's host.
# No network: the port is closed for "down" and listened on for "back".
#
#   The hook (touch, and touch --pause-only) starts one watcher for the agent
#   from Claude Code's transcript_path, once; a turn ending normally is left
#   alone; one ending with a connection error (isApiErrorMessage, the
#   network's words) is noted as a stop in the journal with why, and said so
#   by reconnect while the host doesn't answer; when it answers the agent is
#   woken: asked to exit, its conversation resumed with the words to carry
#   on, the record logging it, the watcher gone; a user who went on (a
#   message after the error) is left alone; a login error is no network
#   stop; the watcher ends with its agent; reconnect by hand says what it
#   finds.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
listener=""
cleanup() {
  [ -n "$listener" ] && kill "$listener" 2>/dev/null || true
  for p in "${pids[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  for w in "$t"/home/.local/state/vikix/office/reconnect/*.json; do
    [ -f "$w" ] && kill "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("watcher", ""))' "$w" 2>/dev/null)" 2>/dev/null || true
  done
  rm -rf "$t"
}
trap cleanup EXIT
pids=()
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc"
unset XDG_STATE_HOME XDG_CONFIG_HOME ANTHROPIC_BASE_URL
mkdir -p "$HOME/.config/vikix" "$t/src" "$t/bin" "$t/proc"
echo "5000.00 1.00" > "$t/proc/uptime"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"   # the desks are worktrees beside a project's repository
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
printf 'one\ntwo\n' > ch1.md; echo '# Log' > log.md; git add ch1.md log.md; git commit -q -m first   # a project is a folder with a log
git worktree add -q "$t/src/book-a" -b a
cd "$here"
proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
standin() {   # standin NAME FOLDER: a real process the waking's SIGTERM lands on, gone from the made-up /proc as it dies
  bash -c 'trap "rm -rf \"$0/proc/$$\"; exit 0" TERM; sleep 300 & wait' "$t" &
  spid=$!; pids+=("$spid"); proc "$spid" "$1" "$2"
}
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
journal="$HOME/.local/state/vikix/office/journal.jsonl"
watchers="$HOME/.local/state/vikix/office/reconnect"
# The stand-ins: the terminal (its command's output kept), the agent launcher, a desktop with no terminals.
printf '#!/bin/sh\nshift\n"$@" > %s 2>&1\n' "$t/term-out" > "$t/bin/term"; chmod +x "$t/bin/term"
printf '#!/bin/sh\necho "AGENT ARGS: $*"\n' > "$t/bin/agent"; chmod +x "$t/bin/agent"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/eval"; chmod +x "$t/bin/eval"
export VIKIX_AGENT_CMD="$t/bin/agent" VIKIX_EVAL="$t/bin/eval" VIKIX_TERMINAL="$t/bin/term" DISPLAY=:7
export VIKIX_RECONNECT_POLL=1 VIKIX_RECONNECT_SETTLE=0
# The API's host: a port of this machine, closed until the test listens on it.
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
export VIKIX_API_HOST="127.0.0.1:$port"
listen() { python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(8); time.sleep(120)' "$port" & listener=$!; sleep 0.3; }
# The transcript: Claude Code's store for the desk's folder, a line a message.
store="$HOME/.claude/projects/$(python3 -c 'import re,sys,os; print(re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(sys.argv[1])))' "$t/src/book-a")"
mkdir -p "$store"
sid=sess-net-1
transcript="$store/$sid.jsonl"
ts() { date -u +%Y-%m-%dT%H:%M:%S.000Z; }
say_assistant() { printf '{"type":"assistant","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$(ts)" "$1" >> "$transcript"; }
say_user() { printf '{"type":"user","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$(ts)" "$1" >> "$transcript"; }
api_error() { printf '{"type":"assistant","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]},"error":"%s","isApiErrorMessage":true}\n' "$(ts)" "$2" "$1" >> "$transcript"; }
after_turn() { printf '{"type":"system","subtype":"turn_duration","timestamp":"%s"}\n{"type":"file-history-snapshot"}\n' "$(ts)" >> "$transcript"; }
hook_input() { printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' "$sid" "${1:-$transcript}" "$t/src/book-a"; }
touch_as() { hook_input | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" touch "${@:2}" 2>&1; }
touch_with() { hook_input "$2" | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" touch 2>&1; }   # touch_with PID TRANSCRIPT
watcher_of() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$watchers/$1.json" "$2" 2>/dev/null || true; }
wait_for() { local _n; for _n in $(seq "$1"); do eval "$2" && return 0; sleep 0.2; done; return 1; }
export -f wait_for

# --- A watcher from the hook, once --------------------------------------------------------------
say_user "write chapter two"; say_assistant "Done."; after_turn
standin claude "$t/src/book-a"
out=$(touch_as "$spid")
check "the hook says nothing of it: '$out'" test -z "$out"
check "and started a watcher for the agent" wait_for 25 "[ -f '$watchers/$spid.json' ]"
w1=$(watcher_of "$spid" watcher)
check "the watcher is a process of its own, watching" bash -c 'kill -0 "$1" && grep -q reconnect "/proc/$1/cmdline"' _ "$w1"
touch_as "$spid" >/dev/null; touch_as "$spid" --pause-only >/dev/null
check "a second call starts no second watcher" test "$(watcher_of "$spid" watcher)" = "$w1"
# Both hook entries run for an edit, at once: still one watcher.
kill "$w1"; wait "$w1" 2>/dev/null || true; rm -f "$watchers/$spid.json"
touch_as "$spid" >/dev/null & j1=$!; touch_as "$spid" --pause-only >/dev/null & j2=$!; wait "$j1" "$j2"
sleep 1
check "two hooks at once start one watcher" test "$(pgrep -fc "reconnect --watch $t/src/book-a --pid $spid " || true)" = 1
w1=$(watcher_of "$spid" watcher)
check "the file names it" kill -0 "$w1"
out=$(agents reconnect a)
check "a turn that ended well is left alone: $out" grep -q "book-a: claude $spid: its last turn wasn.t ended by the network" <<<"$out"
check "nothing is noted in the journal for it" bash -c '! grep -q "\"kind\": \"stop\"" "$1" 2>/dev/null' _ "$journal"

# --- The network ends a turn: noted, said, waited for; back: the agent woken ----------------------
say_user "and chapter three"
api_error server_error "API Error: Can.t reach the API server — check your internet or DNS (EAI_AGAIN)"; after_turn
check "the watcher sees the turn end that way" wait_for 40 "[ -n \"\$(watcher_of $spid gone_at)\" ]"
check "and notes the stop in the journal, with why" grep -q "\"kind\": \"stop\", \"agent\": \"claude\", \"pid\": $spid, .*\"why\": \"network\"" "$journal"
out=$(python3 - "$here/bin/vikix-agents" "$spid" "$t/src/book-a" <<'PY'
import runpy, sys
g = runpy.run_path(sys.argv[1], run_name="not_main")
print(g["journal_states"]([{"agent": "claude", "pid": int(sys.argv[2]), "folder": sys.argv[3], "state": "running", "doing": ""}])[0]["doing"])
PY
)
check "the listing's words: $out" test "$out" = "stopped by the network: taken up again when it is back"
out=$(agents reconnect a)
check "by hand while the host doesn't answer: said, nothing done: $out" \
  bash -c 'grep -q "book-a: claude '"$spid"' was stopped by the network at [0-9:]*: API Error: Can.t reach the API server" <<<"$1" && grep -q "127.0.0.1 doesn.t answer yet: its watcher wakes it when it does, or --wait waits here" <<<"$1"' _ "$out"
check "the agent is untouched" kill -0 "$spid"
check "the journal's stop is noted once" test "$(grep -c '"why": "network"' "$journal")" = 1
rm -f "$t/term-out"
listen
check "the host answers: the agent is asked to exit" wait_for 50 "! kill -0 $spid 2>/dev/null"
wait "$spid" 2>/dev/null || true
check "and its conversation resumed in a terminal at the desk, the words to carry on its prompt: $(cat "$t/term-out" 2>/dev/null)" \
  bash -c 'wait_for 25 "[ -f \"$1\" ]" && grep -q "^AGENT ARGS: --use claude --resume sess-net-1 Vikix office: your last turn ended at [0-9:]* because the network was down (API Error: Can.t reach the API server — check your internet or DNS (EAI_AGAIN)). The network is back (127.0.0.1 answers again, after [0-9a-z ]*), and this is your conversation taken up again by Vikix, not a new task: carry on from where you were" "$1"' _ "$t/term-out"
check "the record logs the outage and the waking" \
  bash -c 'grep -q "the network was back: claude '"$spid"' stopped by it at [0-9:]*" <<<"$1" && grep -q "woken: claude '"$spid"' at its prompt, resumed with the words to carry on" <<<"$1"' _ "$(agents handoff a --json)"
check "the watcher is gone with its agent" wait_for 25 "[ ! -f '$watchers/$spid.json' ] && ! kill -0 $w1 2>/dev/null"
check "and its log with it, after a quiet end" test ! -f "$watchers/$spid.json.log"
kill "$listener" 2>/dev/null || true; wait "$listener" 2>/dev/null || true; listener=""

# --- The user went on by themselves: left alone; a login error is no network stop ---------------
standin claude "$t/src/book-a"
: > "$transcript"; say_user "write chapter two"; say_assistant "Done."; after_turn
touch_as "$spid" >/dev/null
check "a watcher for the next agent" wait_for 25 "[ -f '$watchers/$spid.json' ]"
w2=$(watcher_of "$spid" watcher)
# A new conversation under the same process (/clear): the hook's transcript path changes,
# and the watcher on the old file is replaced by one on the new.
touch_with "$spid" "$store/sess-net-2.jsonl" >/dev/null
check "a changed transcript replaces the watcher" wait_for 25 "[ \"\$(watcher_of $spid transcript)\" = '$store/sess-net-2.jsonl' ] && ! kill -0 $w2 2>/dev/null"
touch_with "$spid" "$transcript" >/dev/null
check "and back" wait_for 25 "[ \"\$(watcher_of $spid transcript)\" = '$transcript' ]"
w2=$(watcher_of "$spid" watcher)
say_user "and four"; api_error server_error "API Error: Connection lost mid-response. The response above may be incomplete."; after_turn
check "a connection lost mid-response is the network's too" wait_for 40 "[ -n \"\$(watcher_of $spid gone_at)\" ]"
say_user "continue"; say_assistant "Going on."; after_turn
check "the user went on: the watcher stands down" wait_for 40 "[ -z \"\$(watcher_of $spid gone_at)\" ]"
rm -f "$t/term-out"
listen
sleep 3
check "the host answering wakes nobody" bash -c 'kill -0 "$1" && [ ! -f "$2" ]' _ "$spid" "$t/term-out"
kill "$listener" 2>/dev/null || true; wait "$listener" 2>/dev/null || true; listener=""
api_error authentication_failed "Login expired · Please run /login"; after_turn
out=$(agents reconnect a)
check "a login that expired is no network stop: $out" grep -q "book-a: claude $spid: its last turn wasn.t ended by the network" <<<"$out"
sleep 2
check "nor for the watcher" test -z "$(watcher_of "$spid" gone_at)"
: > "$transcript"; say_user "x"; api_error rate_limit "You're out of usage credits. Run /usage-credits to keep using Fable 5.1 or /model to switch models."; after_turn
out=$(agents reconnect a)
check "nor the credits: $out" grep -q "its last turn wasn.t ended by the network" <<<"$out"
out=$(agents reconnect --all)
check "--all looks at every desk with an agent: $out" grep -q "book-a: claude $spid: its last turn wasn.t ended by the network" <<<"$out"
out=$(agents reconnect a --wrong)
check "an option that isn't one: $out" grep -q "^vikix agents: vikix agents reconnect \[DESK | --all\] \[--wait\]" <<<"$out"
kill "$spid"; wait "$spid" 2>/dev/null || true
check "the watcher ends with its agent" wait_for 25 "[ ! -f '$watchers/$spid.json' ] && ! kill -0 $w2 2>/dev/null"

# --- By hand, with --wait: the host waited for here ---------------------------------------------
standin claude "$t/src/book-a"
: > "$transcript"; say_user "write"; api_error server_error "API Error: Connection error (ECONNRESET)"; after_turn
# No watcher (VIKIX_RECONNECT=0 keeps the hook from starting one); the stop isn't in the journal yet.
VIKIX_RECONNECT=0 touch_as "$spid" >/dev/null
check "VIKIX_RECONNECT=0: no watcher" bash -c 'sleep 1; [ ! -f "$1" ]' _ "$watchers/$spid.json"
rm -f "$t/term-out"
agents reconnect a --wait > "$t/wait-out" 2>&1 &
waiter=$!
sleep 2.5
check "it waits: $(cat "$t/wait-out")" bash -c 'grep -q "waiting for 127.0.0.1 ..." "$1" && kill -0 "$2"' _ "$t/wait-out" "$spid"
listen
wait "$waiter" || true
check "then wakes the agent, its stop noted first: $(cat "$t/wait-out")" \
  bash -c 'grep -q "was at its prompt: its conversation is resumed with the words to carry on as its prompt" "$1" && grep -q "\"why\": \"network\"" "$2"' _ "$t/wait-out" "$journal"
check "as its prompt: $(cat "$t/term-out" 2>/dev/null)" \
  bash -c 'wait_for 25 "[ -f \"$1\" ]" && grep -q "^AGENT ARGS: --use claude --resume sess-net-1 Vikix office: your last turn ended at [0-9:]* because the network was down (API Error: Connection error (ECONNRESET))" "$1"' _ "$t/term-out"
wait "$spid" 2>/dev/null || true
kill "$listener" 2>/dev/null || true; wait "$listener" 2>/dev/null || true; listener=""

[ $fail = 0 ] && echo "reconnect: ok (the hook starts one watcher per Claude Code at a desk; a turn the network ended is noted, said, and taken up again when the API's host answers; the user going on, a login or the credits wake nobody; the watcher ends with its agent; reconnect by hand, with --wait)"
exit $fail
