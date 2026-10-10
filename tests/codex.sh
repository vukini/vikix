#!/usr/bin/env bash
# tests/codex.sh — Codex as a worker (TODO 116, Phase 1: plans/DESIGN-codex-integration.md),
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
#   codex execpolicy check, when Codex is here.

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
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nagent = "codex"\nmode = "supervised"\n' > "$t/plan.toml"
printf 'project = "book"\n[[task]]\nname = "a"\ntask = "A"\nmode = "fast"\n' > "$t/bad.toml"
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
assert ran[-1][-4:] == ["--use", "codex", "--mode", "supervised"], ran
print("plan ok")
EOF
)
check "a plan file's mode is read, checked and given to the worker: $out" grep -q "^plan ok" <<<"$out"

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
