#!/usr/bin/env bash
# tests/codex.sh — Codex as a worker (TODO 116, Phases 1 and 2: plans/DESIGN-codex-integration.md),
# with a stand-in codex that records its arguments, a made-up home and a
# project with a desk; no network, and Codex itself only for its rules
# checker, when it is installed.
#
#   The launcher (bin/vikix-agent): Codex is given the repository's
#   instructions, CLAUDE.md as the file to fall back on when a folder has no
#   AGENTS.md, with the cap raised to hold Vikix's whole (and CLAUDE.md
#   stays under that cap); at a desk it gets the house default mode (mode=
#   in ~/.config/vikix/office, written once as autonomous with its
#   meaning), elsewhere none unless --mode is typed; each mode is its table
#   row and nothing else (supervised and autonomous: the folder its only
#   writable root; autonomous: the network and Codex's own reviewer;
#   unrestricted: the one flag); unrestricted is refused in a project's own
#   folder, warned about at a desk; --mode for another provider, or a mode
#   that isn't one, is refused with the words; a report (vikix diagnose)
#   keeps its read-only sandbox; the hook's trust is passed only when
#   ~/.codex/hooks.json is Vikix's (the link, or a copy of the file) and
#   the folder is one of your projects, never with VIKIX_CODEX_HOOK_TRUST=ask;
#   the launcher's list of modes is the office's. The office (bin/vikix-agents):
#   place says what a folder is; worker, desk --task and resume take
#   --mode, give it to the agent, keep it in the record (shown on the page,
#   under the agent at the desk, in the listing) and take the house default
#   for Codex; resume takes the last launch's mode up again; --mode for
#   another provider and a desk alone with --mode are refused; hooks codex
#   --install links the rules file beside the hook, leaves a file of yours
#   alone, and says how the hook is trusted; the Office's form offers the
#   modes and passes --mode; a plan file's mode reaches the worker. The
#   rules file (config/codex/vikix.rules): each line's intent, through
#   codex execpolicy check, when Codex is here. Phase 2, the hooks and the
#   states: touch --for codex reads apply_patch for every file it names
#   (and a patch in a Bash heredoc), judges each as an edit (off a desk and
#   the project's own folder denied, a crossing told, a clash refused once
#   and the same edit passed within ten minutes, never ask), notes the
#   session id, carries the desk's notes on additionalContext;
#   --escalation (PermissionRequest) denies a step out of the sandbox that
#   would write into the project's own folder, ~/vikix, another desk or
#   ~/.config/vikix/secrets/, says nothing at the desk and writes the
#   agent-waiting note unless the reviewer answers (autonomous); --turn
#   (UserPromptSubmit) notes a turn, from which the listing says working;
#   stopping --for codex asks for the handoff and writes the plugin's done
#   note, a stop let through is "at its prompt"; left --for codex says left;
#   the handoff's page says what holds the rules for a Codex; the hooks
#   file is in Codex's shape; the store: a thread in session_index.jsonl
#   or the SQLite store is resumed, one in neither is gone, a thread that
#   ran a command in the folder is suggested. Phase 3, the hand-in and the
#   handover: the handoff's fields (acceptance from worker, desk --task, a
#   plan file and handoff, ticked with --done N and shown as 2 of 3;
#   defects and --defect-done; a finding with where, --review-done;
#   decisions) written, each signed, fifty kept, a line cut at a thousand,
#   a credential refused, a tick past the list refused, read back on the
#   page and in --json; changed and commits read from git against where the
#   branch left main, the uncommitted and the new marked; handover on a
#   stand-in agent (a real process): refused mid-turn by the journal, for a
#   provider that isn't one, without --to, by the agent itself, for a desk
#   with no task; then asked for its handoff in a note, waited for,
#   dismissed, the next started with the task, the handoff and the fields
#   as its first prompt, the log's "handed over: claude -> codex", both
#   sessions kept; --now hands over mid-turn.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME VIKIX_CODEX_HOOK_TRUST VIKIX_AGENT_SSH VIKIX_AGENT_MODE
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db" VIKIX_PROC="$t/proc" VIKIX_TESTER=0
mkdir -p "$HOME/.config/vikix" "$HOME/.local/bin" "$HOME/.codex" "$t/src" "$t/proc" "$t/bin"
printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
echo "5000.00 1.00" > "$t/proc/uptime"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# A project (a log makes it one for vikix project), a desk of it, and a repository that is nobody's project.
git -C "$t/src" init -q -b main book; cd "$t/src/book"; git config user.name T; git config user.email t@example.com
echo '# Log' > log.md; git add log.md; git commit -q -m first
git worktree add -q "$t/src/book-a" -b a
git -C "$t" init -q -b main stranger
cd "$here"

# The stand-in codex: its arguments, one in brackets each, and the environment Vikix gives it.
export STARTED="$t/started"
cat > "$HOME/.local/bin/codex" <<'EOF'
#!/bin/sh
for a; do printf '[%s] ' "$a"; done > "$STARTED"; echo >> "$STARTED"
env | grep '^VIKIX_AGENT' >> "$STARTED"
EOF
chmod +x "$HOME/.local/bin/codex"
agent() { (cd "$1" && shift && VIKIX_STATE="$t/state" bash "$here/bin/vikix-agent" "$@" 2>&1 </dev/null) || true; }
started() { cat "$STARTED" 2>/dev/null || true; }

# --- The launcher ----------------------------------------------------------------------------
fallback='[-c] [project_doc_fallback_filenames=["CLAUDE.md"]] [-c] [project_doc_max_bytes=262144]'
desk_rows='[-c] [sandbox_mode="workspace-write"] [-c] [sandbox_workspace_write.writable_roots=[]] [-c] [approval_policy="on-request"]'
rm -f "$STARTED"; out=$(agent "$t/src/book" --use codex)
check "in a project's own folder, no mode typed: the repository's instructions and nothing more: $(started)" \
  test "$(head -1 "$STARTED")" = "$fallback "
check "the office file is written once, with its meaning: $(cat "$HOME/.config/vikix/office" 2>/dev/null)" \
  bash -c 'grep -qx "mode=autonomous" "$1" && grep -q "^# " "$1"' _ "$HOME/.config/vikix/office"
check "CLAUDE.md is under the cap the launcher sets ($(wc -c < "$here/CLAUDE.md") bytes of 262144): raise both together" \
  test "$(wc -c < "$here/CLAUDE.md")" -lt 262144
rm -f "$STARTED"; out=$(agent "$t/src/book-a" --use codex)
check "at a desk, no mode typed: the house default, autonomous, its row and nothing else: $(started)" \
  test "$(head -1 "$STARTED")" = "$fallback $desk_rows [-c] [sandbox_workspace_write.network_access=true] [--approve-for-me] "
check "the mode is in the agent's environment too: $(started)" grep -qx "VIKIX_AGENT_MODE=autonomous" "$STARTED"
check "and said: $out" grep -q "Codex autonomous: its sandbox is this folder" <<<"$out"
rm -f "$STARTED"; out=$(agent "$t/src/book-a" --use codex --mode supervised)
check "supervised: the same sandbox, the network off, no reviewer: $(started)" \
  test "$(head -1 "$STARTED")" = "$fallback $desk_rows [-c] [sandbox_workspace_write.network_access=false] "
rm -f "$STARTED"; out=$(agent "$t/src/book-a" --use codex --mode unrestricted)
check "unrestricted at a desk: the one flag, a warning: $(started) / $out" \
  bash -c 'test "$(head -1 "$1")" = "$2 [--dangerously-bypass-approvals-and-sandbox] " && grep -q "no sandbox and no approvals" <<<"$3"' _ "$STARTED" "$fallback" "$out"
rm -f "$STARTED"; out=$(agent "$t/src/book" --use codex --mode unrestricted)
check "unrestricted in a project's own folder: refused, with the way to a desk, and codex not started: $out" \
  bash -c 'grep -q "never in a project.s own folder" <<<"$1" && grep -q "vikix agents sit book TOPIC" <<<"$1" && [ ! -e "$2" ]' _ "$out" "$STARTED"
out=$(agent "$t/src/book-a" --use claude --mode autonomous)
check "--mode for another provider is refused with the words: $out" grep -q "mode is Codex.s for now (supervised autonomous unrestricted); claude runs as its own settings say" <<<"$out"
out=$(agent "$t/src/book-a" --use codex --mode fast)
check "a mode that isn't one is refused: $out" grep -q "mode which? supervised autonomous unrestricted" <<<"$out"
printf 'mode=supervised\n' > "$HOME/.config/vikix/office"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "mode= in the office file is the default at a desk: $(started)" grep -q "network_access=false" "$STARTED"
printf 'mode=whatever\n' > "$HOME/.config/vikix/office"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "a misspelt mode= falls back to autonomous: $(started)" grep -q -- "--approve-for-me" "$STARTED"
rm -f "$HOME/.config/vikix/office"
echo report > "$t/report.txt"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex --report "$t/report.txt" >/dev/null
check "a report keeps Codex read-only, with no mode: $(started)" \
  bash -c 'grep -q "\[--sandbox\] \[read-only\]" "$1" && ! grep -q "sandbox_mode\|VIKIX_AGENT_MODE" "$1"' _ "$STARTED"
rm -f "$STARTED"; out=$(agent "$t/src/book-a" --use codex --mode supervised --report "$t/report.txt")
check "a report with --mode keeps read-only still, and says so: $(started) / $out" \
  bash -c 'grep -q "\[read-only\]" "$1" && ! grep -q "sandbox_mode" "$1" && grep -q "mode supervised set aside" <<<"$2"' _ "$STARTED" "$out"
# The hook's trust.
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "no hooks file of Vikix's: no trust flag" not grep -q "bypass-hook-trust" "$STARTED"
ln -s "$here/config/codex/hooks.json" "$HOME/.codex/hooks.json"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "Vikix's hook linked, in a project of yours: the trust flag: $(started)" grep -q -- "--dangerously-bypass-hook-trust" "$STARTED"
rm -f "$STARTED"; VIKIX_CODEX_HOOK_TRUST=ask agent "$t/src/book-a" --use codex >/dev/null
check "VIKIX_CODEX_HOOK_TRUST=ask keeps Codex's prompt" not grep -q "bypass-hook-trust" "$STARTED"
rm -f "$STARTED"; agent "$t/stranger" --use codex >/dev/null
check "a repository that is no project of yours: no trust flag, and no mode" \
  bash -c '! grep -q "bypass-hook-trust\|sandbox_mode" "$1"' _ "$STARTED"
rm -f "$HOME/.codex/hooks.json"; echo '{}' > "$HOME/.codex/hooks.json"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "a hooks file of the user's own: no trust flag" not grep -q "bypass-hook-trust" "$STARTED"
rm -f "$HOME/.codex/hooks.json"; cp "$here/config/codex/hooks.json" "$t/hooks.json"; ln -s "$t/hooks.json" "$HOME/.codex/hooks.json"
rm -f "$STARTED"; agent "$t/src/book-a" --use codex >/dev/null
check "a link to a copy of Vikix's file (the installed checkout's) is Vikix's too" grep -q "bypass-hook-trust" "$STARTED"
rm -f "$HOME/.codex/hooks.json"
# One list of modes, in the launcher and the office.
check "the launcher's MODES is the office's" \
  test "$(sed -n 's/^MODES=(\(.*\))$/\1/p' "$here/bin/vikix-agent")" = "$(python3 -c 'import re,sys; print(" ".join(re.search(r"^MODES = \((.*)\)", open(sys.argv[1]).read(), re.M).group(1).replace("\"", "").replace(",", "").split()))' "$here/lib/agents/common.py")"
# A dry run writes nothing.
rm -f "$HOME/.config/vikix/office"
out=$(cd "$t/src/book-a" && DRY_RUN=1 VIKIX_STATE="$t/state" bash "$here/bin/vikix-agent" --use codex 2>&1 </dev/null || true)
check "a dry run says it would write the office file, and doesn't: $out" \
  bash -c 'grep -q "would write.*office: mode=autonomous" <<<"$1" && [ ! -e "$2" ]' _ "$out" "$HOME/.config/vikix/office"

# --- The office ------------------------------------------------------------------------------
export VIKIX_AGENT_CMD="$t/bin/agent" VIKIX_EVAL="$t/bin/eval"
printf '#!/bin/sh\necho "AGENT ARGS: $*"\n' > "$t/bin/agent"; chmod +x "$t/bin/agent"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/eval"; chmod +x "$t/bin/eval"   # a desktop with no terminals: the listing finds agents in /proc
agents() { python3 "$here/bin/vikix-agents" "$@" 2>&1 </dev/null || true; }
proc() {   # proc PID NAME FOLDER: an agent process in the made-up /proc
  mkdir -p "$t/proc/$1"
  printf '%s\0%s\0' "$2" "--some-flag" > "$t/proc/$1/cmdline"
  printf '%s (%s) S 1 %s 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' "$1" "$2" "$1" > "$t/proc/$1/stat"
  ln -sfn "$3" "$t/proc/$1/cwd"
}
check "place: a desk of a project of yours" test "$(agents place "$t/src/book-a")" = "known desk"
check "place: the project's own folder" test "$(agents place "$t/src/book")" = "known own"
check "place: a repository that is no project" test "$(agents place "$t/stranger")" = "unknown own"
check "place: no repository" test "$(agents place "$t")" = "none none"
out=$(agents worker "$t/src/book-a" "sort them" --use codex --here)
check "a Codex worker with no --mode gets the house default and the record keeps it: $out" \
  bash -c 'grep -q "^AGENT ARGS: --use codex --mode autonomous sort them" <<<"$1" && grep -q "a worker at .*, codex, autonomous" <<<"$1"' _ "$out"
out=$(agents handoff "$t/src/book-a")
check "the page says the mode and what it means: $out" grep -q "^Mode: autonomous (codex; user, just now): its sandbox is the desk alone, a reviewer of its own" <<<"$out"
out=$(agents worker "$t/src/book-a" "x" --use claude --mode supervised --here)
check "--mode for another provider is refused before anything starts: $out" \
  bash -c 'grep -q "mode is Codex.s for now" <<<"$1" && ! grep -q "AGENT ARGS" <<<"$1"' _ "$out"
out=$(agents worker "$t/src/book-a" "y" --use codex --mode supervised --here)
check "--mode supervised is passed on: $out" grep -q "^AGENT ARGS: --use codex --mode supervised y" <<<"$out"
check "and shown" grep -q "^Mode: supervised (codex; user, just now): its sandbox is the desk alone, every step out of it asks you" <<<"$(agents handoff "$t/src/book-a")"
printf 'mode=supervised\n' > "$HOME/.config/vikix/office"
out=$(agents worker "$t/src/book-a" "z" --use codex --here)
check "mode= in the office file is the office's default too: $out" grep -q "^AGENT ARGS: --use codex --mode supervised z" <<<"$out"
rm -f "$HOME/.config/vikix/office"
check "the log line names the mode" grep -q "worker started, codex supervised: z" <<<"$(agents handoff "$t/src/book-a" --json)"
agents handoff session codex thread-9 --desk "$t/src/book-a" >/dev/null
out=$(agents resume "$t/src/book-a" --here --use codex)
check "resume takes the last launch's mode up again, and says it: $out" \
  bash -c 'grep -q "^AGENT ARGS: --use codex --mode supervised$" <<<"$1" && grep -q "^fresh conversation with codex at .*, supervised: " <<<"$1"' _ "$out"
out=$(agents resume "$t/src/book-a" --here --use codex --mode autonomous)
check "resume --mode overrides it: $out" grep -q "^AGENT ARGS: --use codex --mode autonomous$" <<<"$out"
out=$(agents resume "$t/src/book-a" --here --use claude --mode autonomous)
check "resume --mode for another provider is refused: $out" grep -q "mode is Codex.s for now" <<<"$out"
proc 1002 codex "$t/src/book-a"
out=$(agents handoff "$t/src/book-a")
check "under the Codex at the desk, its sandbox: $out" grep -q "codex 1002: .*; sandboxed to its desk (codex, autonomous)" <<<"$out"
out=$(agents)
check "the listing's handoff line has the mode: $out" grep -q "handoff: .*; autonomous" <<<"$out"
out=$(agents worker "$t/src/book-a" "w" --use codex --mode unrestricted --here)
check "a second worker is refused while one is at the desk (the mode's refusal doesn't come first): $out" grep -q "is at this desk already" <<<"$out"
rm -r "$t/proc/1002"
out=$(agents worker "$t/src/book-a" "w" --use codex --mode unrestricted --here)
check "unrestricted from the office: said, passed, kept: $out" \
  bash -c 'grep -q "^unrestricted: codex will run with no sandbox" <<<"$1" && grep -q "^AGENT ARGS: --use codex --mode unrestricted w" <<<"$1"' _ "$out"
proc 1003 codex "$t/src/book-a"
check "and the protection line says so" grep -q "codex 1003: .*; no sandbox: unrestricted, by the user" <<<"$(agents handoff "$t/src/book-a")"
rm -r "$t/proc/1003"
out=$(agents desk book b --task "t" --use codex --mode supervised --here)
check "desk --task --mode: the desk and the worker, with the mode: $out" grep -q "^AGENT ARGS: --use codex --mode supervised t" <<<"$out"
out=$(agents desk book c --mode supervised)
check "a desk alone with --mode is refused, as with --use: $out" grep -q "^vikix agents: --mode is for the worker, and a desk alone starts no agent" <<<"$out"
out=$(agents worker "$t/src/book-a" "v" --use codex --mode fast --here)
check "a mode that isn't one is refused: $out" grep -q "mode which? supervised, autonomous, unrestricted" <<<"$out"
# The hooks adapter: the rules file beside the hook, and the trust said.
out=$(agents hooks codex)
check "hooks codex names the rules file and how the hook is trusted: $out" \
  bash -c 'grep -q "Vikix.s rules in ~/.codex/rules/vikix.rules" <<<"$1" && grep -q "not installed (vikix agents hooks codex --install links ~/.codex/rules/vikix.rules)" <<<"$1" && grep -q "trust: vikix agent passes --dangerously-bypass-hook-trust in your projects when the hook file is Vikix.s" <<<"$1"' _ "$out"
out=$(VIKIX_CODEX_HOOK_TRUST=ask agents hooks codex)
check "with VIKIX_CODEX_HOOK_TRUST=ask it says Codex's prompt stays everywhere: $out" grep -q "trust: Codex.s own /hooks prompt everywhere" <<<"$out"
out=$(agents hooks codex --install)
check "--install links the hook and the rules file: $out" \
  bash -c 'test "$(readlink "$HOME/.codex/hooks.json")" = "$1/config/codex/hooks.json" && test "$(readlink "$HOME/.codex/rules/vikix.rules")" = "$1/config/codex/vikix.rules"' _ "$here"
check "and says both installed" test "$(grep -c "installed" <<<"$out")" -ge 2
rm "$HOME/.codex/rules/vikix.rules"; echo '# mine' > "$HOME/.codex/rules/vikix.rules"
out=$(agents hooks codex --install)
check "a rules file of the user's own is left alone: $out" \
  bash -c 'grep -q "rules/vikix.rules is there and isn.t Vikix.s: left alone" <<<"$1" && [ "$(cat "$HOME/.codex/rules/vikix.rules")" = "# mine" ]' _ "$out"
# The Office's form and backend, and a plan file's mode.
out=$(python3 - "$here" <<'EOF'
import importlib.util, sys
sys.dont_write_bytecode = True   # no __pycache__ left in bin/ or lib/
from importlib.machinery import SourceFileLoader
root = sys.argv[1]
sys.path.insert(0, root + "/lib")
import office, plan
spec = importlib.util.spec_from_loader("office_agents", SourceFileLoader("office_agents", root + "/bin/vikix-agents"))
A = importlib.util.module_from_spec(spec); sys.modules[spec.name] = A; spec.loader.exec_module(A)
assert office.worker_words(["--use", "codex", "--mode", "supervised"], "worker") == ["--use", "codex", "--mode", "supervised"]
for bad in (["--mode"], ["--mode", "--push"]):
    try:
        office.worker_words(bad, "worker"); raise SystemExit("--mode without a word passed")
    except ValueError as e:
        assert "mode which" in str(e), e
A.projects = lambda: type("P", (), {"rows": staticmethod(lambda *a: []), "discover": staticmethod(lambda: [])})()
A.agents_offered = lambda: []
offer = office.form(A)
assert offer["modes"] == ["supervised", "autonomous", "unrestricted"] and offer["mode"] == "autonomous", offer
p = plan.read_plan(sys.argv[2]) if len(sys.argv) > 2 else None
print("office ok")
EOF
)
check "the Office's backend offers the modes with the default, and carries --mode: $out" grep -q "^office ok" <<<"$out"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nagent = "codex"\nmode = "supervised"\nacceptance = ["in order", "log says"]\n' > "$t/plan.toml"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nmode = "fast"\n' > "$t/bad.toml"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nacceptance = "one line"\n' > "$t/bad-acceptance.toml"
out=$(python3 - "$here" "$t" <<'EOF'
import sys
sys.dont_write_bytecode = True
root, t = sys.argv[1], sys.argv[2]
sys.path.insert(0, root + "/lib")
import plan
p = plan.read_plan(t + "/plan.toml")
assert p["tasks"][0]["mode"] == "supervised", p["tasks"][0]
try:
    plan.read_plan(t + "/bad.toml"); raise SystemExit("a bad mode passed")
except plan.PlanError as e:
    assert "mode is supervised, autonomous or unrestricted, not 'fast'" in str(e), e
ran = []
plan.run = lambda words, log: (ran.append(words) or (True, ""))
class Api:
    @staticmethod
    def inbox_add(*a): pass
plan.start_worker(Api, {"exists": True, "folder": t + "/src/book-a", "topic": "a"}, p["tasks"][0], p, None, {}, lambda *a: None)
assert ran[-1][-8:] == ["--use", "codex", "--mode", "supervised", "--acceptance", "in order", "--acceptance", "log says"], ran
try:
    plan.read_plan(t + "/bad-acceptance.toml"); raise SystemExit("a bad acceptance passed")
except plan.PlanError as e:
    assert "acceptance is a list of lines" in str(e), e
print("plan ok")
EOF
)
check "a plan file's mode and acceptance are read, checked and given to the worker: $out" grep -q "^plan ok" <<<"$out"

# --- The store: Codex's thread store beside the rollout files (Phase 2) ------------------------
# No rollout file: the id in session_index.jsonl, or in the SQLite thread
# store, is a conversation that can be resumed; one in neither is gone, and
# the words say where was looked. A thread that ran a command in the folder
# is suggested for it, never taken.
python3 - "$HOME/.codex" "$t/src/book-b" <<'EOF'
import json, os, sqlite3, sys
root, folder = sys.argv[1], sys.argv[2]
with open(os.path.join(root, "session_index.jsonl"), "w") as f:
    f.write(json.dumps({"id": "01a1-indexed", "thread_name": "Sort them", "updated_at": "2026-10-09T10:00:00.123456789Z"}) + "\n")
    f.write("not json\n")
c = sqlite3.connect(os.path.join(root, "thread_history_1.sqlite"))
c.execute("CREATE TABLE thread_turns (thread_id TEXT NOT NULL, turn_id TEXT NOT NULL, rollout_ordinal INTEGER, status TEXT, PRIMARY KEY (thread_id, turn_id))")
c.execute("CREATE TABLE thread_items (thread_id TEXT NOT NULL, turn_id TEXT NOT NULL, item_id TEXT NOT NULL, rollout_ordinal INTEGER, created_at_ms INTEGER NOT NULL, item_json TEXT NOT NULL, item_type TEXT NOT NULL DEFAULT '', PRIMARY KEY (thread_id, turn_id, item_id))")
c.execute("INSERT INTO thread_turns VALUES ('01a1-insqlite', 't1', 1, 'completed')")
c.execute("INSERT INTO thread_items VALUES ('01a1-insqlite', 't1', 'i1', 2, 1791219615192, ?, 'commandExecution')",
          (json.dumps({"type": "commandExecution", "command": "ls", "cwd": folder}),))
c.execute("INSERT INTO thread_items VALUES ('01a1-insqlite', 't1', 'i2', 3, 1791219615200, ?, 'userMessage')",
          (json.dumps({"type": "userMessage", "content": [{"type": "text", "text": folder}]}),))
c.commit(); c.close()
EOF
agents handoff session codex 01a1-indexed --desk "$t/src/book-a" >/dev/null
out=$(agents resume "$t/src/book-a" --here --use codex)
check "a thread in session_index.jsonl, with no rollout file, is resumed: $out" \
  bash -c 'grep -q "^AGENT ARGS: --use codex --mode [a-z]* resume 01a1-indexed$" <<<"$1" && grep -q "its store has it (~/.codex/session_index.jsonl)" <<<"$1"' _ "$out"
agents handoff session codex 01a1-insqlite --desk "$t/src/book-a" >/dev/null
out=$(agents resume "$t/src/book-a" --here --use codex)
check "one in the SQLite store alone, the same: $out" \
  bash -c 'grep -q "resume 01a1-insqlite$" <<<"$1" && grep -q "its store has it (~/.codex/thread_history_1.sqlite)" <<<"$1"' _ "$out"
agents handoff session codex 01a1-nowhere --desk "$t/src/book-a" >/dev/null
out=$(agents resume "$t/src/book-a" --here --use codex)
check "one in neither is gone, and the words say where was looked: $out" \
  grep -q "session 01a1-nowhere is gone from ~/.codex (sessions/, session_index.jsonl, thread_history_1.sqlite)" <<<"$out"
out=$(agents resume "$t/src/book-b" --here --use codex)
check "a thread that ran a command in the folder is suggested for it, never taken: $out" \
  bash -c 'grep -q "^fresh conversation with codex" <<<"$1" && grep -q "codex.s own store has a conversation in this folder: 01a1-insqlite" <<<"$1"' _ "$out"
check "the store is read, never written" test "$(stat -c %Y "$HOME/.codex/thread_history_1.sqlite")" -le "$(( $(date +%s) ))" -a ! -e "$HOME/.codex/thread_history_1.sqlite-journal"

# --- The hooks, in Codex's shape, and the states (Phase 2) ------------------------------------
# Codex's hook input: tool_name Bash or apply_patch, both with
# tool_input.command; a patch is read for every file it names. Its hook
# takes deny and allow only, never ask. The agent-waiting plugin is a
# stand-in that records what it is told.
unset WINDOWID ALACRITTY_WINDOW_ID
export PATH="$t/bin:$PATH" NOTED="$t/noted"
printf '#!/bin/sh\nprintf "%%s " "$1" >> "$NOTED"; cat >> "$NOTED"; echo >> "$NOTED"\n' > "$t/bin/agent-waiting"; chmod +x "$t/bin/agent-waiting"
hook() { local pid=$1 json=$2; shift 2; printf '%s' "$json" | VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" touch --for codex "$@" 2>&1; }
stop_as() { printf '%s' "$2" | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" stopping --for codex 2>&1; }
left_as() { printf '%s' "$2" | VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" left --for codex 2>&1; }
journal="$HOME/.local/state/vikix/office/journal.jsonl"
mkdir -p "$HOME/vikix" "$HOME/.config/vikix/secrets"
agents worker "$t/src/book-a" "p2" --use codex --mode autonomous --here >/dev/null
proc 1101 codex "$t/src/book-a"
proc 1102 claude "$t/src/book-b"
proc 1103 codex "$t/src/book"
proc 1104 codex "$HOME"
patch() { printf '{"session_id":"01a1-thread","tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"*** Begin Patch\\n%s\\n*** End Patch"}}' "$1" "$2"; }
out=$(hook 1101 "$(patch "$t/src/book-a" '*** Update File: log.md\n@@\n-x\n+y\n*** Add File: notes/new.md\n+hello\n*** Move to: notes/moved.md')")
check "a patch at the desk, nobody else on its files: nothing said: '$out'" test -z "$out"
check "every file it names is an edit in the journal, made absolute from cwd: $(grep -c '"pid": 1101' "$journal")" \
  bash -c 'grep -q "\"kind\": \"edit\".*\"pid\": 1101.*book-a/log.md" "$1" && grep -q "\"pid\": 1101.*book-a/notes/new.md" "$1" && grep -q "\"pid\": 1101.*book-a/notes/moved.md" "$1"' _ "$journal"
check "its session id is noted on the desk" grep -q '"id": "01a1-thread"' "$HOME/.local/state/vikix/office/desks/"*.json
out=$(hook 1103 "$(patch "$t/src/book" '*** Update File: log.md\n@@\n-x\n+y')")
check "in the project's own folder (so off a desk): denied, in Codex's words (deny, never ask): $out" \
  bash -c 'grep -q "\"permissionDecision\": \"deny\"" <<<"$1" && grep -q "you are not at a desk.*The project.s own folder, .*, is for merging only" <<<"$1" && ! grep -q "\"ask\"" <<<"$1"' _ "$out"
out=$(hook 1104 "$(patch "$HOME" "*** Add File: $t/src/book-a/x.md\n+x")")
check "off a desk: denied, with the way to one: $out" bash -c 'grep -q "\"deny\"" <<<"$1" && grep -q "vikix agents sit book TOPIC" <<<"$1"' _ "$out"
out=$(hook 1101 "$(patch "$t/src/book-a" "*** Add File: $t/src/book-b/plan.md\n+x")")
check "a file in another agent's desk is a crossing, told on additionalContext: $(head -c 120 <<<"$out")" \
  bash -c 'grep -q "\"additionalContext\": \"Vikix office: .*book-b/plan.md is in .*book-b, the folder claude 1102 works in, not yours" <<<"$1" && ! grep -q permissionDecision <<<"$1"' _ "$out"
printf 'changed by claude\n' > "$t/src/book-b/log.md"
out=$(hook 1101 "$(patch "$t/src/book-a" '*** Update File: log.md\n@@\n-x\n+z')")
check "a clash (claude has log.md changed in its worktree): refused once, with the reason, never ask: $out" \
  bash -c 'grep -q "\"permissionDecision\": \"deny\"" <<<"$1" && grep -q "another agent is on this file. claude 1102 (.*book-b) has changed it in .*book-b, uncommitted" <<<"$1" && grep -q "the same edit within ten minutes goes through" <<<"$1" && ! grep -q "\"ask\"" <<<"$1"' _ "$out"
out=$(hook 1101 "$(patch "$t/src/book-a" '*** Update File: log.md\n@@\n-x\n+z')")
check "the same edit again within ten minutes passes: '$out'" test -z "$out"
check "the clash is recorded" grep -q 'codex 1101 and claude 1102 on' <<<"$(VIKIX_RECORDS_DB=$t/records.db python3 "$here/bin/vikix-records" list office --kind clash)"
git -C "$t/src/book-b" checkout -q -- log.md
out=$(hook 1103 '{"tool_name":"Bash","cwd":"'"$t/src/book"'","tool_input":{"command":"sed -i s/a/b/ log.md"}}')
check "a Bash command that would write in the project's own folder is denied: $(head -c 80 <<<"$out")" grep -q '"deny".*This command would write there' <<<"$out"
out=$(hook 1101 '{"tool_name":"Bash","cwd":"'"$t/src/book-a"'","tool_input":{"command":"sed -i s/a/b/ log.md"}}')
check "one at the desk passes: '$out'" test -z "$out"
out=$(hook 1103 '{"tool_name":"Bash","cwd":"'"$t/src/book"'","tool_input":{"command":"apply_patch <<'"'"'EOF'"'"'\n*** Begin Patch\n*** Update File: log.md\n@@\n-x\n+y\n*** End Patch\nEOF"}}')
check "a patch applied through a Bash heredoc is read for its files too: $(head -c 80 <<<"$out")" grep -q '"deny".*merging only' <<<"$out"
agents tell a "look at the log first" >/dev/null
out=$(hook 1101 '{"tool_name":"Bash","cwd":"'"$t/src/book-a"'","tool_input":{"command":"ls"}}')
check "a note left with vikix agents tell rides on additionalContext at its next tool call: $out" \
  grep -q '^{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "Vikix office, notes for you at this desk (vikix agents tell): \[user, [0-9:]*\] look at the log first"}}$' <<<"$out"
# --escalation: the PermissionRequest hook. A step out of the sandbox that would write off the desk is denied.
esc() { hook "$1" '{"session_id":"01a1-thread","tool_name":"Bash","cwd":"'"$2"'","tool_input":{"command":"'"$3"'"}}' --escalation; }
deny='^{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "deny", "message": "Vikix office: '
out=$(esc 1101 "$t/src/book-a" "git -C $t/src/book commit -m x")
check "an escalation into the project's own folder is denied, in PermissionRequest's shape: $out" grep -q "$deny.*the project.s own folder, which is for merging only.*This step out of the sandbox would write there" <<<"$out"
out=$(esc 1101 "$t/src/book-a" "cp log.md $HOME/vikix/log.md")
check "into ~/vikix, the installed checkout: $out" grep -q "$deny~/vikix is the installed Vikix, which only pulls" <<<"$out"
out=$(esc 1101 "$t/src/book-a" "tee $t/src/book-b/x.md")
check "into another desk: $out" grep -q "$deny.*book-b/x.md is in .*book-b, another desk: an agent writes at its own desk only, .*book-a" <<<"$out"
out=$(esc 1101 "$t/src/book-a" "echo k > $HOME/.config/vikix/secrets/anthropic")
check "into the key store: $out" grep -q "$deny~/.config/vikix/secrets/ holds the user.s API keys" <<<"$out"
out=$(hook 1101 "$(patch "$t/src/book-a" "*** Update File: $t/src/book/log.md\n@@\n-x\n+y")" --escalation)
check "a patch's files are judged the same: $(head -c 100 <<<"$out")" grep -q "$deny.*merging only" <<<"$out"
check "each refusal is recorded" test "$(VIKIX_RECORDS_DB=$t/records.db python3 "$here/bin/vikix-records" list office --kind refused | grep -c "a step out of Codex.s sandbox")" -ge 4
rm -f "$NOTED"
out=$(esc 1101 "$t/src/book-a" "git commit -m x")
check "a write at the desk says nothing (the prompt is yours, or the reviewer's): '$out'" test -z "$out"
check "and the plugin's note says Codex waits for your yes: $(head -c 60 "$NOTED" 2>/dev/null)" bash -c 'grep -q "^permission {" "$1"' _ "$NOTED"
rm -f "$NOTED"
out=$(VIKIX_AGENT_MODE=autonomous esc 1101 "$t/src/book-a" "git commit -m x")
check "in autonomous mode the reviewer answers, so no note: '$out' / $(cat "$NOTED" 2>/dev/null)" bash -c '[ -z "$1" ] && [ ! -e "$2" ]' _ "$out" "$NOTED"
out=$(esc 1101 "$t/src/book-a" "cat $t/src/book/log.md")
check "a command that reads is left alone: '$out'" test -z "$out"
# --turn, the stop and the leaving: the states the listing reads from the journal.
rm -f "$NOTED"
out=$(hook 1101 '{"session_id":"01a1-thread","prompt":"go on"}' --turn)
check "a turn begun prints nothing (stdout would reach the model): '$out'" test -z "$out"
check "is in the journal, and clears the plugin's note" bash -c 'grep -q "\"kind\": \"turn\".*\"pid\": 1101" "$1" && grep -q "^clear " "$2"' _ "$journal" "$NOTED"
out=$(agents --json)
check "the listing says working for it, from the journal, with what and how long ago: $(grep -o '"doing": "[^"]*"' <<<"$out" | head -3 | tr '\n' ' ')" \
  python3 -c 'import json, sys; a = [a for a in json.load(sys.stdin) if a["pid"] == 1101][0]; assert a["state"] == "working" and a["doing"].startswith("working (a turn begun ") and a["doing"].endswith(" s ago)"), a' <<<"$out"
check "and codex 1103, which did nothing in a minute, is running still" \
  python3 -c 'import json, sys; a = [a for a in json.load(sys.stdin) if a["pid"] == 1103][0]; assert a["state"] == "running", a' <<<"$out"
rm -f "$NOTED"
out=$(stop_as 1101 '{"stop_hook_active":false,"last_assistant_message":"Done with the log. Shall I go on?","cwd":"'"$t/src/book-a"'"}')
check "the Stop hook asks a worker that changed files for its handoff, in Codex's shape: $(head -c 100 <<<"$out")" grep -q '^{"decision": "block", "reason": "Vikix office: this turn changed [0-9]* files* at your desk' <<<"$out"
check "and writes the plugin's done note with its last words: $(head -c 80 "$NOTED" 2>/dev/null)" grep -q '^done {.*Shall I go on' "$NOTED"
out=$(stop_as 1101 '{"stop_hook_active":true}')
check "the stop after it is let go: '$out'" test -z "$out"
check "and noted" grep -q '"kind": "stop".*"pid": 1101' "$journal"
out=$(agents --json)
check "so the listing says at its prompt: $(grep -o '"doing": "[^"]*"' <<<"$out" | head -3 | tr '\n' ' ')" \
  python3 -c 'import json, sys; a = [a for a in json.load(sys.stdin) if a["pid"] == 1101][0]; assert a["state"] == "idle" and a["doing"] == "at its prompt", a' <<<"$out"
out=$(agents)
check "in words too: $out" grep -q "^  codex .*book-a.* at its prompt$" <<<"$out"
out=$(left_as 1101 '{"reason":"other"}')
check "SessionEnd with Codex's reason, always other, says left: '$out' / $(grep -o '"reason": "[a-z]*"' "$HOME/.local/state/vikix/office/desks/"*.json | tr '\n' ' ')" \
  bash -c '[ -z "$1" ] && grep -q "^Left: left (codex 1101, " <<<"$2"' _ "$out" "$(agents handoff "$t/src/book-a")"
# What holds the rules, said honestly on the handoff's page.
out=$(agents handoff "$t/src/book-a")
check "under a Codex whose edits came through its hook: the three hooks named, and its sandbox: $out" \
  bash -c 'grep -q "^  codex 1101: its PreToolUse hook (vikix agents touch --for codex): [0-9]* edits proposed through it; its PermissionRequest hook denies a step out of its sandbox into the project.s own folder, ~/vikix, another desk or secrets/; its Stop hook asks for the handoff; sandboxed to its desk (codex, autonomous)" <<<"$1" && grep -q "^  no filesystem enforcement by Vikix: a worktree keeps copies apart, it is no sandbox; Codex.s own sandbox, narrowed to the desk by its mode, is the one there is" <<<"$1"' _ "$out"
proc 1105 codex "$t/src/book-b"; rm -r "$t/proc/1102"
out=$(agents handoff "$t/src/book-b")
check "under one with no edit seen, the hook file being Vikix's: installed, none seen yet: $out" grep -q "^  codex 1105: its hooks installed (~/.codex/hooks.json is Vikix.s: edits, commands, steps out of its sandbox, turns and stops), none of its edits seen yet" <<<"$out"
rm "$HOME/.codex/hooks.json"
check "the hook file gone: instructions only" grep -q "^  codex 1105: instructions only, unless its hook is installed (vikix agents hooks codex --install)" <<<"$(agents handoff "$t/src/book-b")"
out=$(agents hooks codex)
check "hooks codex names every hook and keeps its honesty: $out" bash -c 'grep -q "PreToolUse (apply_patch read for its files" <<<"$1" && grep -q "PermissionRequest (a step out of its sandbox" <<<"$1" && grep -q "Stop and SessionEnd" <<<"$1" && grep -q "unverified on this machine until one has fired" <<<"$1"' _ "$out"
rm -r "$t/proc/1101" "$t/proc/1103" "$t/proc/1104" "$t/proc/1105"
# The hooks file, in Codex's shape (its documentation, 0.160): a description, the events, their commands.
check "config/codex/hooks.json is in Codex's shape" python3 -c '
import json, sys
h = json.load(open(sys.argv[1]))
assert isinstance(h.get("description"), str) and "_comment" not in h
hooks = h["hooks"]
cmds = {e: [(g.get("matcher"), x["command"], x["timeout"]) for g in hooks[e] for x in g["hooks"]] for e in hooks}
assert cmds["PreToolUse"] == [("Bash|apply_patch", "vikix agents touch --for codex", 660), (None, "vikix agents touch --for codex --pause-only", 660)], cmds
assert cmds["PermissionRequest"] == [("Bash|apply_patch", "vikix agents touch --for codex --escalation", 15)], cmds
assert cmds["UserPromptSubmit"] == [(None, "vikix agents touch --for codex --turn", 15)], cmds
assert cmds["Stop"] == [(None, "vikix agents stopping --for codex", 15)], cmds
assert cmds["SessionEnd"] == [(None, "vikix agents left --for codex", 3)], cmds   # 3 s is the most Codex allows a SessionEnd hook
assert set(cmds) == {"PreToolUse", "PermissionRequest", "UserPromptSubmit", "Stop", "SessionEnd"}, cmds
for g in (g for e in hooks.values() for g in e):
    for x in g["hooks"]:
        assert x["type"] == "command"' "$here/config/codex/hooks.json"

# --- The hand-in's fields and the handover (Phase 3) ------------------------------------------
# A fresh desk, book-h: a worker given criteria with its task, the fields written by the
# worker (a made-up Codex in /proc), read back, refused where they should be.
export VIKIX_HANDOVER_WAIT=2
as() { VIKIX_AGENT_PID=$1 python3 "$here/bin/vikix-agents" "${@:2}" 2>&1 </dev/null || true; }
out=$(agents desk book h --task "Sort the chapters" --acceptance "chapters in order" --acceptance "the log says so" --acceptance "tests pass" --use codex --here)
check "desk --task --acceptance: the criteria go into the record and the worker's first prompt: $out" \
  bash -c 'grep -q "^AGENT ARGS: --use codex --mode autonomous Sort the chapters" <<<"$1" && grep -q "Acceptance criteria, 0 of 3 done (tick one with vikix agents handoff --done N): 1. \[ \] chapters in order; 2. \[ \] the log says so; 3. \[ \] tests pass" <<<"$1"' _ "$out"
out=$(agents handoff h)
check "the page shows them unticked: $out" bash -c 'grep -q "^Acceptance (user, just now): 0 of 3 done$" <<<"$1" && grep -q "^  \[ \] the log says so$" <<<"$1"' _ "$out"
out=$(agents worker "$t/src/book-h" --acceptance "x" --here)
check "--acceptance without a task is refused: $out" grep -q "^vikix agents: --acceptance goes with a task" <<<"$out"
proc 1201 codex "$t/src/book-h"
out=$(as 1201 handoff --done 2 --decided "kept the old order under --no-sort" --defect "slow past 500 chapters" --defect "no colour yet" --review "log.md:1 the heading is stale")
check "the worker ticks one, decides, adds two defects and a finding, in one write: $out" grep -q "book-h: handoff updated by codex 1201, acceptance 1 of 3 done$" <<<"$out"
out=$(agents handoff h)
check "the page: the tick signed, the decision, the defects open, the finding with where: $out" \
  bash -c 'grep -q "^Acceptance (user, just now): 1 of 3 done$" <<<"$1" && grep -q "^  \[x\] the log says so  (codex 1201, just now)$" <<<"$1" && grep -q "^Decided (1):$" <<<"$1" && grep -q "^  kept the old order under --no-sort  (codex 1201, just now)$" <<<"$1" && grep -q "^Defects: 2 open$" <<<"$1" && grep -q "^  open      no colour yet  (codex 1201, just now)$" <<<"$1" && grep -q "^Review: 1 open$" <<<"$1" && grep -q "^  open      log.md:1 the heading is stale  (codex 1201, just now)$" <<<"$1"' _ "$out"
out=$(as 1201 handoff --defect-done 1 --review-done 1)
check "a defect closed and a finding addressed: $out" \
  bash -c 'grep -q "^Defects: 1 open, 1 closed$" <<<"$1" && grep -q "^  closed    slow past 500 chapters  (codex 1201, just now; closed by codex 1201)$" <<<"$1" && grep -q "^Review: 0 open, 1 addressed$" <<<"$1" && grep -q "^  addressed log.md:1 the heading is stale  (codex 1201, just now; addressed by codex 1201)$" <<<"$1"' _ "$(agents handoff h)"
check "--json has each signed, the finding's where apart from its words, and the log's lines" python3 -c '
import json, sys
r = json.load(sys.stdin); h = r["handoff"]
assert h["acceptance"]["by"] == "user" and h["acceptance"]["items"][1]["done_by"] == "codex 1201" and not h["acceptance"]["items"][0]["done"], h["acceptance"]
assert h["decisions"][0]["by"] == "codex 1201" and h["defects"][0]["closed_by"] == "codex 1201" and not h["defects"][0]["open"] and h["defects"][1]["open"], h
assert h["review"][0]["where"] == "log.md:1" and h["review"][0]["text"] == "the heading is stale" and not h["review"][0]["open"], h["review"]
what = [e["what"] for e in r["log"]]
assert "acceptance (3)" in what and "done 2 of 3: the log says so, defect (2), review (1), decided (1)" in what, what
assert "defect-done 1: slow past 500 chapters, review-done 1: the heading is stale" in what, what' <<<"$(agents handoff h --json)"
out=$(as 1201 handoff --done 9)
check "a tick past the list is refused: $out" grep -q "there is no item 9 (1 to 3)" <<<"$out"
out=$(as 1201 handoff --done two)
check "and one that isn't a number: $out" grep -q "\-\-done N: the number of the item, counted from 1, not 'two'" <<<"$out"
out=$(as 1201 handoff --decided "API_KEY=abcdefghijk is the key")
check "a credential in a decision is refused: $out" grep -q "a decision looks like it holds a credential: a record keeps none" <<<"$out"
out=$(as 1201 handoff --acceptance "")
check "a criterion with no words: $out" grep -q "acceptance criteria are lines of text, one each" <<<"$out"
printf '{"status":"working","acceptance":["a","b"],"done":1,"decided":["one","two"],"review":"plain finding"}' > "$t/h.json"
out=$(as 1201 handoff --from "$t/h.json")
check "--from takes the fields as JSON, a list where a list is: $out" grep -q "status working, acceptance 1 of 2 done$" <<<"$out"
check "and an acceptance written again replaces the list whole, ticks and all" python3 -c '
import json, sys
h = json.load(sys.stdin)["handoff"]
assert [i["text"] for i in h["acceptance"]["items"]] == ["a", "b"] and h["acceptance"]["items"][0]["done"] and not h["acceptance"]["items"][1]["done"], h["acceptance"]
assert [d["text"] for d in h["decisions"]] == ["kept the old order under --no-sort", "one", "two"], h["decisions"]
assert h["review"][1]["text"] == "plain finding" and "where" not in h["review"][1] and h["review"][1]["open"], h["review"]' <<<"$(agents handoff h --json)"
for i in $(seq 1 55); do as 1201 handoff --defect "defect $i" >/dev/null; done
long=$(printf 'x%.0s' $(seq 1 1200))
as 1201 handoff --decided "$long" >/dev/null
check "fifty of each are kept, the oldest gone first, and a line is cut at a thousand" python3 -c '
import json, sys
h = json.load(sys.stdin)["handoff"]
assert len(h["defects"]) == 50 and h["defects"][-1]["text"] == "defect 55" and h["defects"][0]["text"] == "defect 6", (len(h["defects"]), h["defects"][0])
assert len(h["decisions"][-1]["text"]) == 1000, len(h["decisions"][-1]["text"])' <<<"$(agents handoff h --json)"
# What changed and the commits, read from git against where the branch left main: at every
# write of the handoff, the uncommitted and the new marked.
echo 'two' >> "$t/src/book-h/log.md"; git -C "$t/src/book-h" commit -q -am "log: two"
echo 'ch' > "$t/src/book-h/ch1.md"; git -C "$t/src/book-h" add ch1.md; git -C "$t/src/book-h" commit -q -m "ch1 begun"
echo 'three' >> "$t/src/book-h/log.md"; echo 'notes' > "$t/src/book-h/notes.md"
base=$(git -C "$t/src/book-h" merge-base HEAD main | cut -c1-7)
as 1201 handoff --status review >/dev/null
out=$(agents handoff h)
check "changed against the base, the uncommitted and the new marked, and the commits past it: $out" \
  bash -c 'grep -q "^Changed (vikix, just now): 3 files against '"$base"'$" <<<"$1" && grep -q "^  +2 -0  log.md (uncommitted)$" <<<"$1" && grep -q "^  +1 -0  ch1.md$" <<<"$1" && grep -q "^  +0 -0  notes.md (new, uncommitted)$" <<<"$1" && grep -q "^Commits (vikix, just now): 2 past '"$base"'$" <<<"$1" && grep -q "^  [0-9a-f]*  log: two$" <<<"$1" && grep -q "^  [0-9a-f]*  ch1 begun$" <<<"$1"' _ "$out"
check "--json: the paths in order, the subjects oldest first, signed vikix" python3 -c '
import json, sys
h = json.load(sys.stdin)["handoff"]
assert h["changed"]["by"] == "vikix" and [f["path"] for f in h["changed"]["files"]] == ["ch1.md", "log.md", "notes.md"], h["changed"]
assert h["commits"]["by"] == "vikix" and [c["subject"] for c in h["commits"]["list"]] == ["log: two", "ch1 begun"], h["commits"]' <<<"$(agents handoff h --json)"
rm -r "$t/proc/1201"
# The handover: a stand-in agent that is a real process (so the dismissal lands), the
# record between the two providers.
agents handoff session claude sess-claude-1 --desk h >/dev/null
standin() {   # standin NAME FOLDER: a real process the dismissal lands on, gone from the made-up /proc as it dies, as from the real one
  bash -c 'trap "rm -rf \"$0/proc/$$\"; exit 0" TERM; sleep 300 & wait' "$t" &
  spid=$!; proc "$spid" "$1" "$2"
}
standin claude "$t/src/book-h"
printf '{"at": %s, "kind": "edit", "agent": "claude", "pid": %s, "folder": "%s", "file": "%s/log.md"}\n' "$(date +%s)" "$spid" "$t/src/book-h" "$t/src/book-h" >> "$journal"
out=$(agents handover h --to codex --here)
check "refused while its agent is mid-turn, by the journal: $out" \
  bash -c 'grep -q "^vikix agents: claude '"$spid"' is working (an edit [0-9]* s ago): wait for its prompt, or --now hands over mid-turn" <<<"$1" && ! grep -q "AGENT ARGS" <<<"$1"' _ "$out"
check "and nothing was dismissed" kill -0 "$spid"
out=$(agents handover h --to nobody)
check "a provider that isn't one is refused: $out" grep -q "^vikix agents: --to nobody? the providers: claude, codex, opencode, gemini, antigravity, aider" <<<"$out"
out=$(agents handover h)
check "and no --to: $out" grep -q "^vikix agents: vikix agents handover DESK --to NAME" <<<"$out"
out=$(VIKIX_AGENT_PID=$spid agents handover h --to codex)
check "an agent doesn't hand its own desk over: $out" grep -q "that is your own desk: an agent doesn't hand itself over" <<<"$out"
agents desk book n >/dev/null
out=$(agents handover n --to codex)
check "a desk with no task has nothing to hand over: $out" grep -q "^vikix agents: .*book-n has no task in its record: nothing to hand over (vikix agents worker n" <<<"$out"
# The edit made two minutes ago: not mid-turn, not at its prompt either, so the note is
# waited for (VIKIX_HANDOVER_WAIT seconds), then the agent is dismissed and Codex started.
python3 - "$journal" "$spid" <<'PY'
import json, sys
lines = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
for e in lines:
    if e.get("pid") == int(sys.argv[2]):
        e["at"] -= 120
open(sys.argv[1], "w").write("".join(json.dumps(e) + "\n" for e in lines))
PY
start=$(date +%s); out=$(agents handover h --to codex --here); took=$(( $(date +%s) - start ))
check "the agent is asked for its handoff and waited for ($took s): $out" \
  bash -c 'grep -q "^asked claude '"$spid"' for its handoff; waiting up to 2 s for the record to move" <<<"$1" && grep -q "^no handoff came: what the record has is what the next agent gets" <<<"$1" && [ "$2" -ge 2 ] && [ "$2" -lt 15 ]' _ "$out" "$took"
check "dismissed, with the note first" bash -c 'grep -q "book-h: dismissed claude '"$spid"'\. The desk, its branch and 2 uncommitted files stay" <<<"$1" && grep -q "user (just now): handing over to codex: write your handoff now (vikix agents handoff --status" <<<"$1" && grep -q "user (just now): dismissed by user: write your handoff if you can, then stop" <<<"$1"' _ "$out"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
check "and the process is gone" not kill -0 "$spid" 2>/dev/null
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
check "then Codex is started fresh, the task, the handoff and the fields its first prompt: $out" \
  bash -c 'grep -q "book-h: handed over, claude -> codex$" <<<"$1" && grep -q "^fresh conversation with codex at .*book-h, autonomous: a fresh conversation was asked for" <<<"$1" && grep -q "^the task and the handoff are its first prompt$" <<<"$1" && grep -q "^AGENT ARGS: --use codex --mode autonomous Sort the chapters" <<<"$1" && grep -q "^What the desk.s record holds, left by the agent before you" <<<"$1" && grep -q "^Status: review (codex 1201, just now)\.$" <<<"$1" && grep -q "^Acceptance criteria, 1 of 2 done .*: 1. \[x\] a; 2. \[ \] b$" <<<"$1" && grep -q "^Decided already (don.t reopen without the user): kept the old order under --no-sort; one; two; xxx" <<<"$1" && grep -q "^Defects open: defect 6 (codex 1201); defect 7 (codex 1201); " <<<"$1" && grep -q "^Review findings open: plain finding (codex 1201)$" <<<"$1" && grep -q "^Changed against '"$base"': 3 files: ch1.md (+1 -0), log.md (+2 -0, uncommitted), notes.md (+0 -0, uncommitted)$" <<<"$1" && grep -q "^Commits past '"$base"': 2: [0-9a-f]* log: two; [0-9a-f]* ch1 begun$" <<<"$1" && grep -q "^This is your desk.s task, as its record keeps it" <<<"$1"' _ "$out"
check "the record logs the handover and keeps both sessions" python3 -c '
import json, sys
r = json.load(sys.stdin)
assert "handed over: claude -> codex" in [e["what"] for e in r["log"]], r["log"][-5:]
assert [(s["provider"], s["id"]) for s in r["sessions"]] == [("claude", "sess-claude-1")], r["sessions"]
assert r["left"]["reason"] == "dismissed" and r["task"]["text"] == "Sort the chapters" and r["launch"]["provider"] == "codex", r' <<<"$(agents handoff h --json)"
# --now: mid-turn all the same, and the other way round, Codex's desk to Claude's hands.
agents handoff session codex sess-codex-1 --desk h >/dev/null
standin codex "$t/src/book-h"
printf '{"at": %s, "kind": "shell", "agent": "codex", "pid": %s, "folder": "%s", "file": ""}\n' "$(date +%s)" "$spid" "$t/src/book-h" >> "$journal"
out=$(agents handover h --to claude --now --here)
check "--now hands over mid-turn, no wait, and Claude gets the first prompt: $(head -c 300 <<<"$out")" \
  bash -c 'grep -q "^handing over now: what the record has is what the next agent gets" <<<"$1" && ! grep -q "waiting up to" <<<"$1" && grep -q "book-h: handed over, codex -> claude$" <<<"$1" && grep -q "^AGENT ARGS: --use claude Sort the chapters" <<<"$1"' _ "$out"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
check "both sessions stay, for resume with either" python3 -c '
import json, sys
r = json.load(sys.stdin)
assert [(s["provider"], s["id"]) for s in r["sessions"]] == [("claude", "sess-claude-1"), ("codex", "sess-codex-1")], r["sessions"]
assert [e["what"] for e in r["log"] if e["what"].startswith("handed over")] == ["handed over: claude -> codex", "handed over: codex -> claude"]' <<<"$(agents handoff h --json)"
out=$(agents resume h --use codex --here)
check "resume without --fresh gives no first prompt (the conversation has the record): $out" grep -q "^AGENT ARGS: --use codex --mode autonomous$" <<<"$out"
unset VIKIX_HANDOVER_WAIT

# --- The rules file, through Codex's own checker (when Codex is here) ---------------------------
if command -v codex >/dev/null 2>&1 && timeout 20 codex execpolicy check --help >/dev/null 2>&1; then
  decision() { timeout --kill-after=5s 60s codex execpolicy check --rules "$here/config/codex/vikix.rules" -- "$@" 2>/dev/null |
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("decision", "none"))' 2>/dev/null || echo error; }
  while IFS='|' read -r want cmd; do
    # shellcheck disable=SC2086  # the command's words
    got=$(decision $cmd)
    check "rules: $cmd -> $want (got $got)" test "$got" = "$want"
  done <<'EOF'
allow|git commit -m x
allow|git add -A
allow|git status
allow|git log --oneline
allow|git branch x
allow|git worktree list
allow|git tag v1
allow|git fetch origin
prompt|git push
prompt|git push origin main
forbidden|git push --force
forbidden|git push -f origin main
forbidden|git push --force-with-lease
prompt|git branch -D x
prompt|git branch -d x
prompt|git tag -d v1
prompt|git worktree add x
prompt|git worktree remove x
allow|tests/run.sh --changed
allow|vikix snapshot before
allow|vikix agents handoff --status review
allow|vikix eval (+ 1 2)
allow|.claude/release topic line
prompt|vikix update
forbidden|sudo xbps-install -S
forbidden|doas ls
none|ls -la
EOF
else
  echo "(codex isn't installed here: the rules file's lines aren't checked with codex execpolicy)"
fi
check "the rules file has no rule that lets sudo or a force-push through" \
  bash -c '! grep -E "\"(sudo|doas)\".*allow|--force.*allow" "$1/config/codex/vikix.rules"' _ "$here"

[ "$fail" = 0 ] && echo "codex: ok"
exit "$fail"
