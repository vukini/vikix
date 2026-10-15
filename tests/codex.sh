#!/usr/bin/env bash
# tests/codex.sh — Codex as a worker (TODO 116: plans/DESIGN-codex-integration.md),
# with a stand-in codex that records its arguments, a made-up home and a
# project with a desk; no network, and Codex itself only for its rules
# checker, when it is installed. tests/codex.sh --live, by hand and never
# from run.sh, runs the real Codex once (your login, a session's tokens):
# its sandbox with a desk as the only root, and one exec session at a
# scratch desk under the launcher's autonomous row with Vikix's hooks file
# and rules, asked to make a file, commit it and hand off, which shows the
# hooks firing (the journal's turn, edit and stop by codex), the commit and
# the handoff out of the sandbox without a prompt, and how it left.
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
#   ~/.config/vikix/secrets/ (from a session in the home folder too), allows
#   a routine command (the rules file's vikix and git lines, the tests, the
#   release; under timeout, env, nice, bash -lc or a full path, every
#   command of the line one of them; a substitution, a redirection to a
#   file, a PATH= in front, a pipe or sudo are not), says nothing for the
#   rest at the desk and writes the agent-waiting note unless the reviewer
#   answers (autonomous); the hook's lists are the rules file's lines; a
#   folder of no repository (Super+a's here) gets the house mode and the
#   trust flag; hooks codex reads ~/.codex/config.toml for a setting under
#   a header Codex doesn't read ([section]) and a file it can't read; --turn
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
#   sessions kept; --now hands over mid-turn. Phase 4, the review: vikix
#   agents review DESK runs a stand-in codex (exec, read-only, no approvals,
#   ephemeral, the schema as a file, the answer to one) or claude (-p, plan,
#   the schema on the line, the answer under structured_output) in a
#   throwaway worktree of the desk's last commit, the uncommitted left out,
#   no key and no SSH agent, the prompt naming the base, the task, the
#   criteria, the decisions and the shape; its findings go into the
#   handoff's Review signed by the reviewer with where and severity, a line
#   into the inbox and the log, the worktree is gone after; --review-done
#   marks one addressed; --log shows its words; unsaid, the provider that
#   isn't the desk's; --prompt adds words; while it runs the desk's agent is
#   under review, the reviewer's process is reviewing, and a second is
#   refused; aider, a reviewer not installed, --prompt with no words refused;
#   a reviewer that fails or answers prose is kept, not lost; review=codex
#   in the office file starts one at the hand-in, nothing without it.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY XDG_STATE_HOME XDG_CONFIG_HOME VIKIX_CODEX_HOOK_TRUST VIKIX_AGENT_SSH VIKIX_AGENT_MODE CODEX_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
orig_home=$HOME
real_codex=$(command -v codex || true)
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

# --- The real Codex, by hand: tests/codex.sh --live ------------------------------------------
# A scratch home under your cache, never /tmp (writable inside the sandbox,
# so a refusal there would prove nothing); the office's state is read from
# HOME, so the journal and the record land in it; a CODEX_HOME of its own
# holding a copy of your login, this checkout's hooks file and rules; your
# shell is snapshotted by Codex for its commands, so the scratch home's
# profile puts this checkout's bin first; the real /proc, since the hook
# finds its agent there.
live() {
  [ -n "$real_codex" ] || { echo "FAIL: --live needs codex installed"; exit 1; }
  [ -r "$orig_home/.codex/auth.json" ] || { echo "FAIL: --live needs a Codex login ($orig_home/.codex/auth.json)"; exit 1; }
  local L; L=$(mktemp -d -p "${XDG_CACHE_HOME:-$orig_home/.cache}" vikix-codex-live.XXXX)
  trap 'rm -rf "$t" "$L"' EXIT
  export HOME="$L/home" CODEX_HOME="$L/codex" VIKIX_RECORDS_DB="$L/records.db"
  unset VIKIX_PROC
  mkdir -p "$HOME/.config/vikix" "$CODEX_HOME/rules" "$L/src"
  printf 'root=%s\n' "$L/src" > "$HOME/.config/vikix/projects"
  install -m 600 "$orig_home/.codex/auth.json" "$CODEX_HOME/auth.json"
  ln -s "$here/config/codex/hooks.json" "$CODEX_HOME/hooks.json"
  ln -s "$here/config/codex/vikix.rules" "$CODEX_HOME/rules/vikix.rules"
  printf 'export PATH=%q:$PATH\n' "$here/bin" | tee "$HOME/.bash_profile" > "$HOME/.bashrc"
  export PATH="$here/bin:$PATH"
  git -C "$L/src" init -q -b main book; (cd "$L/src/book" && git config user.name T && git config user.email t@example.com \
    && echo '# Log' > log.md && git add log.md && git commit -q -m first && git worktree add -q "$L/src/book-a" -b a)
  local desk="$L/src/book-a"
  (cd "$desk" && git config user.name T && git config user.email t@example.com)

  # The sandbox with the desk as its only root, as the launcher's two sandboxed modes set it.
  local out
  out=$(cd "$desk" && timeout --kill-after=5s 60s "$real_codex" sandbox -c 'sandbox_mode="workspace-write"' \
    -c 'sandbox_workspace_write.writable_roots=[]' -- sh -c "echo x > inside.txt && echo inside-ok
      echo y > '$L/outside.txt' && echo outside-ok
      echo y > '$L/src/book/own.txt' && echo own-ok
      echo z >> .git && echo git-ok
      echo w > '$L/src/book/.git/worktrees/book-a/probe' && echo gitdir-ok
      true" 2>&1 </dev/null) || true
  echo "$out" | sed 's/^/   sandbox: /'
  check "the desk is writable inside the sandbox" grep -q inside-ok <<<"$out"
  check "a folder outside the desk is not" not grep -q outside-ok <<<"$out"
  check "the project's own folder is not" not grep -q own-ok <<<"$out"
  check "the desk's .git file is not" not grep -q git-ok <<<"$out"
  check "the repository's worktree folder is not" not grep -q gitdir-ok <<<"$out"
  rm -f "$desk/inside.txt"

  # A record for the desk, so SessionEnd has one to note how it left in.
  (cd "$desk" && python3 "$here/bin/vikix-agents" handoff --status working --summary "the live probe" >/dev/null)
  # One exec session under the launcher's autonomous row (codex_mode_args in bin/vikix-agent) with
  # the hook's trust, as vikix agent starts a worker; approvals go to Codex's reviewer, never to a
  # prompt a script can't answer.
  local args=(-c 'project_doc_fallback_filenames=["CLAUDE.md"]' -c 'project_doc_max_bytes=262144'
    -c 'sandbox_mode="workspace-write"' -c 'sandbox_workspace_write.writable_roots=[]' -c 'approval_policy="on-request"'
    -c 'sandbox_workspace_write.network_access=true' --approve-for-me --dangerously-bypass-hook-trust)
  # The prompt is a worker's first prompt (desk_prompt: the task, where the record is, the definition of
  # done), so what the run shows is what a worker is told.
  local prompt; prompt=$(python3 - "$here" <<'PY'
import importlib.util, sys
from importlib.machinery import SourceFileLoader
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_loader("office_agents", SourceFileLoader("office_agents", sys.argv[1] + "/bin/vikix-agents"))
A = importlib.util.module_from_spec(spec); spec.loader.exec_module(A)
print(A.desk_prompt("Three steps, nothing else, asking no questions: 1. with apply_patch, create probe.txt containing exactly one line: hello. 2. run: git add probe.txt && git commit -m probe. 3. run: vikix agents handoff --status review --summary 'probe committed'."))
PY
)
  echo "   running: codex exec --cd $desk ${args[*]} --skip-git-repo-check --ephemeral \"...\""
  out=$(cd "$desk" && timeout --kill-after=5s 300s "$real_codex" exec --cd "$desk" "${args[@]}" --skip-git-repo-check --ephemeral "$prompt" 2>&1 </dev/null) || true
  echo "$out" | sed 's/^/   codex: /'
  local journal="$HOME/.local/state/vikix/office/journal.jsonl"
  check "the PreToolUse hook fired: the journal has codex's edit of probe.txt" \
    grep -q '"kind": "edit", "agent": "codex".*probe.txt' "$journal"
  check "UserPromptSubmit fired: a turn by codex" grep -q '"kind": "turn", "agent": "codex"' "$journal"
  check "the Stop hook let a stop through: codex at its prompt" grep -q '"kind": "stop", "agent": "codex"' "$journal"
  check "probe.txt is there with its line" test "$(cat "$desk/probe.txt" 2>/dev/null)" = hello
  check "the commit got out of the sandbox (a desk's .git is read-only inside it: Codex must ask to run it outside, where the rules allow it): $(git -C "$desk" log --oneline | head -1)" \
    test "$(git -C "$desk" log --format=%s -1)" = probe
  local rec; rec=$(cd "$desk" && python3 "$here/bin/vikix-agents" handoff "$desk" --json 2>/dev/null || true)
  check "the handoff was written from inside the session: status review, its summary" \
    bash -c 'grep -q "\"value\": \"review\"" <<<"$1" && grep -q "probe committed" <<<"$1"' _ "$rec"
  if grep -q '"left"' <<<"$rec"; then echo "   SessionEnd fired: how it left is in the record"
  else echo "   (SessionEnd not seen: codex exec ended with no 'hook: SessionEnd' line; how a Codex left is still to see in a session of its own)"; fi

  # The hook's allow: a snapshot under a timeout matches no rule (Codex matches a rule from the
  # command's first word), so it gets out of the sandbox through the hook or the reviewer; the hook
  # notes the command in the journal when it is the one that let it out, which the reviewer never
  # does. (codex exec forces approval never without --approve-for-me, 2026-10-11: "Escalated retry is
  # prohibited by this environment", so the supervised row can't be probed here.) A file of
  # yours.list in the scratch home, so the snapshot has something to commit.
  local yours="$HOME/.local/state/vikix/yours.git"
  mkdir -p "$HOME/.stumpwm.d"; echo ';; probe' > "$HOME/.stumpwm.d/user.lisp"
  echo "   running: codex exec (the autonomous row) \"timeout 20s vikix snapshot 'before: probe two'\""
  out=$(cd "$desk" && VIKIX_AGENT_MODE=autonomous timeout --kill-after=5s 300s "$real_codex" exec --cd "$desk" "${args[@]}" --skip-git-repo-check --ephemeral \
    "One step, nothing else, asking no questions: run exactly this command, and when it fails inside the sandbox run it again escalated out of the sandbox: timeout 20s vikix snapshot 'before: probe two'. Then say what it printed." 2>&1 </dev/null) || true
  echo "$out" | sed 's/^/   codex: /'
  check "a snapshot under a timeout got out of the sandbox (the snapshot history: $(git --git-dir="$yours" log --format=%s -1 2>/dev/null))" \
    bash -c 'git --git-dir="$1" log --format=%s 2>/dev/null | grep -q "before: probe two"' _ "$yours"
  check "and the hook, not the reviewer, let it out: its allow is in the journal with the command" \
    grep -q '"kind": "shell", "agent": "codex".*"command": "timeout 20s vikix snapshot' "$journal"

  # The review's Codex road, real: the desk's commit read in a throwaway worktree, the findings against
  # the schema into the record (Claude's road, claude -p, is refused from inside a Claude Code session,
  # so it stays for a day at the keyboard).
  out=$(cd "$desk" && timeout --kill-after=5s 300s python3 "$here/bin/vikix-agents" review "$desk" --use codex 2>&1 </dev/null) || true
  echo "$out" | sed 's/^/   review: /'
  rec=$(cd "$desk" && python3 "$here/bin/vikix-agents" handoff "$desk" --json 2>/dev/null || true)
  check "the review by the real Codex answered the schema: a finding signed codex in the handoff's Review, no failure in the log" \
    bash -c 'grep -qE "\"by\": \"codex [0-9]+\"" <<<"$1" && ! grep -q "review by codex failed" <<<"$1"' _ "$rec"
  [ "$fail" = 0 ] && echo "codex --live: ok"
  exit "$fail"
}
[ "${1:-}" = --live ] && live

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
rm -f "$STARTED"; out=$(agent "$t" --use codex)
check "a folder of no repository (Super+a's agent here, in your home): the house default, its sandbox the folder, the trust flag, and said: $(started) / $out" \
  bash -c 'test "$(head -1 "$1")" = "$2 $3 [-c] [sandbox_workspace_write.network_access=true] [--approve-for-me] [--dangerously-bypass-hook-trust] " && grep -q "Codex autonomous: its sandbox is this folder, .*(and /tmp); the house rules. hook (vikix agents hooks codex) lets vikix snapshot" <<<"$4"' _ "$STARTED" "$fallback" "$desk_rows" "$out"
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
  bash -c 'grep -q "Vikix.s rules in ~/.codex/rules/vikix.rules" <<<"$1" && grep -q "not installed (vikix agents hooks codex --install links ~/.codex/rules/vikix.rules)" <<<"$1" && grep -q "trust: vikix agent passes --dangerously-bypass-hook-trust in your projects and in a folder of no repository (your home, Super+a.s here) when the hook file is Vikix.s" <<<"$1"' _ "$out"
# Codex's config.toml, the user's: read for a setting under a header Codex doesn't read, never written.
printf 'model = "x"\n\n[section]\n\nsandbox_mode = "workspace-write"\napproval_policy = "never"\n\n[sandbox_workspace_write]\nwritable_roots = ["/home"]\n' > "$HOME/.codex/config.toml"
out=$(agents hooks codex)
check "a setting under a header Codex doesn't read in ~/.codex/config.toml is said, with what to do: $out" \
  grep -q "/.codex/config.toml: sandbox_mode, approval_policy stand under \[section\], a table Codex doesn.t read, so they do nothing; move the lines above the first \[...\] header (your file: Vikix doesn.t write it)" <<<"$out"
printf 'model = "x"\nsandbox_mode = "workspace-write"\n\n[sandbox_workspace_write]\nwritable_roots = ["/home"]\n\n[profiles.fast]\napproval_policy = "never"\n' > "$HOME/.codex/config.toml"
out=$(agents hooks codex)
check "one in its place, or under a profile, is not: $out" not grep -q "config.toml" <<<"$out"
printf 'model = "x\n' > "$HOME/.codex/config.toml"
out=$(agents hooks codex)
check "a file Codex can't read is said: $out" grep -q "/.codex/config.toml: Codex can.t read it" <<<"$out"
rm -f "$HOME/.codex/config.toml"
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
A.projects = lambda: type("P", (), {"rows": staticmethod(lambda *a: []), "discover": staticmethod(lambda: []),
                                   "read_config": staticmethod(lambda: (["/x/src"], "/x/src/project-logs", 2))})()
A.agents_offered = lambda: []
office.github_account = lambda: None   # never the real gh from a test
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
import scheduler, tasks
from unittest.mock import patch
class Api:
    tasks_module = staticmethod(lambda: tasks)
    @staticmethod
    def inbox_add(*a): pass
with patch.object(scheduler, "start_plan", return_value=True) as start:
    assert plan.start_worker(Api, {"exists": True, "folder": t + "/src/book-a", "topic": "a"}, p["tasks"][0], p, None, {}, lambda *a: None)
sent = start.call_args.args[2]
assert sent["agent"] == "codex" and sent["mode"] == "supervised", sent
assert sent["acceptance"] == ["in order", "log says"], sent
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
allow='^{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}$'
out=$(esc 1101 "$t/src/book-a" "git commit -m x")
check "a routine command at the desk, a commit, is allowed, so no prompt: $out" grep -q "$allow" <<<"$out"
check "and noted in the journal as a command of codex's, the hook's trace" grep -q '"kind": "shell", "agent": "codex", "pid": 1101, .*"command": "git commit -m x"' "$journal"
check "and no plugin note: nobody waits for a yes" test ! -e "$NOTED"
out=$(esc 1101 "$t/src/book-a" "cp log.md log2.md")
check "a write at the desk that isn't routine says nothing (the prompt is yours, or the reviewer's): '$out'" test -z "$out"
check "and the plugin's note says Codex waits for your yes: $(head -c 60 "$NOTED" 2>/dev/null)" bash -c 'grep -q "^permission {" "$1"' _ "$NOTED"
rm -f "$NOTED"
# The routine commands as Codex types them: wrapped in timeout (which its own rules miss: the first
# word), env, nice, bash -lc, a full path; every command of the line one of them, or nothing is said.
while IFS='|' read -r want cmd; do
  out=$(esc 1101 "$t/src/book-a" "$cmd")
  case $want in
    allow) check "escalation: $cmd -> allowed: $out" grep -q "$allow" <<<"$out" ;;
    none)  check "escalation: $cmd -> left to you or the reviewer: '$out'" test -z "$out" ;;
  esac
done <<EOF
allow|timeout 20s vikix snapshot 'before: add three wallpapers'
allow|timeout --kill-after=5s 15s vikix agents handoff --status working --estimate '40 min'
allow|$HOME/.local/bin/vikix snapshot x
allow|env VIKIX_TESTER=0 tests/run.sh --changed
allow|nice -n 5 vikix doctor
allow|bash -lc 'vikix snapshot x && git status'
allow|vikix agents --json 2>&1
allow|tests/run.sh lint >/dev/null 2>&1
allow|.claude/release topic 'a line'
allow|git -C $t/src/book-a commit -m x
none|git push
none|git push --force
none|git branch -D x
none|git worktree add x
none|vikix update
none|vikix snapshot x && rm -rf x
none|vikix eval \$(cat f)
none|PATH=/tmp/evil vikix snapshot x
none|tests/run.sh lint > out.txt
none|vikix agents --json | head -3
none|sudo xbps-install -S
EOF
rm -f "$NOTED"
# A session in the home folder (Super+a's agent here): the same judgement, its folder holding everything.
out=$(esc 1104 "$HOME" "timeout 20s vikix snapshot 'before: wallpapers'")
check "from the home folder, a snapshot under a timeout is allowed: $out" grep -q "$allow" <<<"$out"
out=$(esc 1104 "$HOME" "cp k $HOME/.config/vikix/secrets/anthropic")
check "but the key store is denied there too, inside its folder as it is: $out" grep -q "$deny~/.config/vikix/secrets/ holds the user.s API keys" <<<"$out"
out=$(esc 1104 "$HOME" "tee $HOME/vikix/x.md")
check "and the installed checkout: $out" grep -q "$deny~/vikix is the installed Vikix" <<<"$out"
out=$(esc 1104 "$HOME" "tee $t/src/book-a/x.md")
check "and a project's repository, the agent being at no desk, with the way to one: $out" grep -q '"deny".*vikix agents sit book TOPIC' <<<"$out"
rm -f "$NOTED"
out=$(VIKIX_AGENT_MODE=autonomous esc 1101 "$t/src/book-a" "cp log.md log2.md")
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
check "hooks codex names every hook and keeps its honesty: $out" bash -c 'grep -q "PreToolUse (apply_patch read for its files" <<<"$1" && grep -q "PermissionRequest (a step out of its sandbox" <<<"$1" && grep -q "Stop and SessionEnd" <<<"$1" && grep -q "Seen firing here on 2026-10-10 (tests/codex.sh --live" <<<"$1" && ! grep -q unverified <<<"$1"' _ "$out"
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
# The next provider's task is never the task as it stands (the designer's "no code,
# hand in" became Codex's orders, 2026-10-11): --task, or the record's next step, read
# after the wait; neither, and the handover is refused with the agent left in place.
start=$(date +%s); out=$(agents handover h --to codex --here); took=$(( $(date +%s) - start ))
check "with no --task and no next step in the record, refused after the wait, nothing done ($took s): $out" \
  bash -c 'grep -q "^asked claude '"$spid"' for its handoff; waiting up to 2 s for the record to move" <<<"$1" && grep -q "^vikix agents: .*book-h: what is codex to do? --task \"...\" says, or the record.s next step (vikix agents handoff --next \"...\"); the task as it stands was the last agent.s and isn.t passed on. Nothing done: its agent stays" <<<"$1" && ! grep -q "AGENT ARGS" <<<"$1" && [ "$2" -ge 2 ]' _ "$out" "$took"
check "and its agent is still there" kill -0 "$spid"
as "$spid" handoff --next "Implement the sort as decided" >/dev/null
# The next step written: the task, and the agent's handoff goes into the history whole.
sleep 1
start=$(date +%s); out=$(agents handover h --to codex --here); took=$(( $(date +%s) - start ))
check "the agent is asked for its handoff and waited for ($took s): $out" \
  bash -c 'grep -q "^asked claude '"$spid"' for its handoff; waiting up to 2 s for the record to move" <<<"$1" && grep -q "^no handoff came: what the record has is what the next agent gets" <<<"$1" && [ "$2" -ge 2 ] && [ "$2" -lt 15 ]' _ "$out" "$took"
check "dismissed, with the notes first, each for it alone" bash -c 'grep -q "book-h: dismissed claude '"$spid"'\. The desk, its branch and 2 uncommitted files stay" <<<"$1" && grep -q "user (just now, for claude '"$spid"'): handing over to codex: write your handoff now (vikix agents handoff --status" <<<"$1" && grep -q "user (just now, for claude '"$spid"'): dismissed by user: write your handoff if you can, then stop" <<<"$1"' _ "$out"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
check "and the process is gone" not kill -0 "$spid" 2>/dev/null
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
check "then Codex is started fresh on the next step as its task, the desk's fields and the last agent's account its first prompt: $out" \
  bash -c 'grep -q "book-h: handed over, claude -> codex; its task: Implement the sort as decided$" <<<"$1" && grep -q "^  the task before it (Sort the chapters) is in the desk.s history with its handoff$" <<<"$1" && grep -q "^fresh conversation with codex at .*book-h, autonomous: a fresh conversation was asked for" <<<"$1" && grep -q "^the task and the handoff are its first prompt$" <<<"$1" && grep -q "^AGENT ARGS: --use codex --mode autonomous Implement the sort as decided" <<<"$1" && grep -q "^What the desk.s record holds, left by the agent before you" <<<"$1" && ! grep -q "^Status: review" <<<"$1" && grep -q "^The worker before you (claude, review, just now) was on: Sort the chapters$" <<<"$1" && grep -q "^It left to do: Implement the sort as decided$" <<<"$1" && grep -q "^Acceptance criteria, 1 of 2 done .*: 1. \[x\] a; 2. \[ \] b$" <<<"$1" && grep -q "^Decided already (don.t reopen without the user): kept the old order under --no-sort; one; two; xxx" <<<"$1" && grep -q "^Defects open: defect 6 (codex 1201); defect 7 (codex 1201); " <<<"$1" && grep -q "^Review findings open: plain finding (codex 1201)$" <<<"$1" && grep -q "^Changed against '"$base"': 3 files: ch1.md (+1 -0), log.md (+2 -0, uncommitted), notes.md (+0 -0, uncommitted)$" <<<"$1" && grep -q "^Commits past '"$base"': 2: [0-9a-f]* log: two; [0-9a-f]* ch1 begun$" <<<"$1" && grep -q "^This is your desk.s task, as its record keeps it" <<<"$1"' _ "$out"
check "the record logs the handover, keeps both sessions, has the new task and the old one's handoff in the history" python3 -c '
import json, sys
r = json.load(sys.stdin)
assert "handed over: claude -> codex" in [e["what"] for e in r["log"]], r["log"][-5:]
assert [(s["provider"], s["id"]) for s in r["sessions"]] == [("claude", "sess-claude-1")], r["sessions"]
assert "left" not in r and r["task"]["text"] == "Implement the sort as decided" and r["task"]["by"] == "user" and r["launch"]["provider"] == "codex", r
w = r["workers"][-1]
assert w["task"] == "Sort the chapters" and w["status"] == "review" and w["handoff"]["next"]["text"] == "Implement the sort as decided", w
h = r["handoff"]
assert "status" not in h and len(h["decisions"]) == 4 and len(h["defects"]) == 50 and h["acceptance"]["items"][0]["done"], sorted(h)' <<<"$(agents handoff h --json)"
# --now: mid-turn all the same, and the other way round, Codex's desk to Claude's hands.
agents handoff session codex sess-codex-1 --desk h >/dev/null
standin codex "$t/src/book-h"
printf '{"at": %s, "kind": "shell", "agent": "codex", "pid": %s, "folder": "%s", "file": ""}\n' "$(date +%s)" "$spid" "$t/src/book-h" >> "$journal"
out=$(agents handover h --to claude --now --here --task "Check Codex's sort against the design")
check "--now hands over mid-turn, no wait, and Claude gets --task as its first prompt: $(head -c 300 <<<"$out")" \
  bash -c 'grep -q "^handing over now: what the record has is what the next agent gets" <<<"$1" && ! grep -q "waiting up to" <<<"$1" && grep -q "book-h: handed over, codex -> claude; its task: Check Codex.s sort against the design$" <<<"$1" && grep -q "^AGENT ARGS: --use claude Check Codex.s sort against the design" <<<"$1"' _ "$out"
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

# --- The review by another provider (Phase 4) -------------------------------------------------
# A stand-in reviewer for both roads (codex exec, claude -p): it records its
# arguments, where it ran, what it saw there and whether a key reached it,
# waits while a hold file stands, and answers in the schema's shape (or as
# told: a file, prose, a failure).
rev="$t/reviewers"; mkdir -p "$rev"
export REVIEWED="$t/reviewed" REVIEW_HOLD="$t/review-hold" REVIEW_ANSWER="$t/review-answer" REVIEW_FAIL="$t/review-fail"
cat > "$rev/codex" <<'EOF'
#!/usr/bin/env bash
{ for a; do printf '[%s] ' "$a"; done; echo; echo "PWD=$PWD"; echo "KEYS=$(env | grep -c '_API_KEY=' || true)"; echo "SSH=${SSH_AUTH_SOCK:-none}"; echo "FILES=$(ls | tr '\n' ' ')"; } > "$REVIEWED"
printf '%s\n' "${@: -1}" > "$REVIEWED.prompt"
out=''; schema=''; prev=''
for a; do case $prev in -o) out=$a ;; --output-schema) schema=$a ;; esac; prev=$a; done
[ -n "$schema" ] && python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$schema" && echo "SCHEMA=ok" >> "$REVIEWED"
n=0; while [ -e "$REVIEW_HOLD" ] && [ $n -lt 120 ]; do sleep 0.25; n=$((n+1)); done
[ -e "$REVIEW_FAIL" ] && { echo "codex: something broke" >&2; exit 1; }
answer='{"summary": "Sound, two things to fix.", "findings": [{"where": "log.md:2", "severity": "high", "text": "the second line repeats the first"}, {"where": "", "severity": "low", "text": "ch1.md has no heading"}]}'
[ -f "$REVIEW_ANSWER" ] && answer=$(cat "$REVIEW_ANSWER")
if [ "$1" = -p ]; then printf '{"type":"result","is_error":false,"result":"see structured_output","structured_output":%s}\n' "$answer"
else printf '%s\n' "$answer" > "$out"; echo "codex: reviewed (stderr words)" >&2; fi
EOF
chmod +x "$rev/codex"; cp "$rev/codex" "$rev/claude"
review() { PATH="$rev:$PATH" FOO_API_KEY=secret SSH_AUTH_SOCK=/tmp/none python3 "$here/bin/vikix-agents" review "$@" --here 2>&1 </dev/null || true; }
rm -f "$REVIEWED" "$REVIEWED.prompt" "$REVIEW_HOLD" "$REVIEW_ANSWER" "$REVIEW_FAIL"
proc 1301 claude "$t/src/book-h"     # the worker at the desk now (Claude took it in the last handover)
head_h=$(git -C "$t/src/book-h" rev-parse --short HEAD)
# Without --here the review runs apart from the shell (a review read from a pipe under a
# timeout orphaned the reviewer and lost its findings, 2026-10-11): said, then the findings come.
out=$(PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" review h --use codex 2>&1 </dev/null || true)
check "a review runs apart from the shell, and says so: $out" \
  grep -q "book-h: codex reviews its last commit, apart from this shell; the findings go into its handoff and its agent.s inbox, and the reviewer.s words to .*reviews/[0-9a-f]*.log (vikix agents review --log book-h); --here would have waited for it" <<<"$out"
for _ in $(seq 1 80); do grep -q "review by codex" <<<"$(agents handoff h | tail -4)" && break; sleep 0.25; done
check "its findings came to the record by themselves: $(tail -2 <<<"$(agents handoff h)")" grep -qE "vikix \(just now\): review by codex [0-9]+ \([0-9]+ s\): 2 findings, 1 high" <<<"$(agents handoff h)"
check "the worker at the desk, its state unknown, is said to need waking" grep -q "claude 1301 may be at its prompt (its state isn.t known): it must be woken" <<<"$(cat "$HOME/.local/state/vikix/office/reviews/"*.log.reviewer)"
rm -f "$REVIEWED" "$REVIEWED.prompt"
out=$(review h --use codex)
check "a review by codex of the desk's last commit, the uncommitted left out, two findings into the handoff: $out" \
  bash -c 'grep -q "book-h: 2 uncommitted files left out: the review is of its last commit, '"$head_h"'$" <<<"$1" && grep -qE "book-h: review by codex [0-9]+ \([0-9]+ s\): 2 findings, 1 high, in your handoff.s Review \(vikix agents handoff\): address each and mark it with vikix agents handoff --review-done N\. Sound, two things to fix\.$" <<<"$1"' _ "$out"
check "codex exec, read-only, no approvals, ephemeral, the schema as a file and the answer to one, in the throwaway worktree, no key and no SSH agent, the files of HEAD and not the uncommitted: $(cat "$REVIEWED")" \
  bash -c 'grep -q "^\[exec\] \[--cd\] \[[^]]*/vikix-review-[^]/]*/review\] \[-s\] \[read-only\] \[-c\] \[approval_policy=\"never\"\] \[--ephemeral\] \[--color\] \[never\] \[--output-schema\] \[[^]]*findings.schema.json\] \[-o\] \[[^]]*findings.json\] \[Review the work" "$1" && grep -q "^PWD=.*/vikix-review-[^/]*/review$" "$1" && grep -q "^KEYS=0$" "$1" && grep -q "^SSH=none$" "$1" && grep -q "^FILES=ch1.md log.md $" "$1" && grep -q "^SCHEMA=ok$" "$1"' _ "$REVIEWED"
check "the prompt names the base, the task, the criteria with their ticks, the decisions and the shape: $(head -c 600 "$REVIEWED.prompt")" \
  bash -c 'grep -q "past '"$base"'" "$1" && grep -q "^The task it was done for: Check Codex.s sort against the design$" "$1" && grep -q "^The acceptance criteria, as the worker ticked them: \[x\] a; \[ \] b$" "$1" && grep -q "^Decided already, not to be reopened: kept the old order under --no-sort; one; two; xxx" "$1" && grep -q "^Answer with JSON alone, of exactly this shape: {\"type\":\"object\"" "$1"' _ "$REVIEWED.prompt"
check "the reviewer's worktree is gone" test -z "$(git -C "$t/src/book" worktree list | grep vikix-review || true)"
out=$(agents handoff h)
check "the record: each finding signed by the reviewer, the place kept, the severity said when it isn't the middle one; the inbox line for the worker: $out" \
  bash -c 'grep -qE "^  open      log.md:2 \[high\] the second line repeats the first  \(codex [0-9]+, just now\)$" <<<"$1" && grep -qE "^  open      \[low\] ch1.md has no heading  \(codex [0-9]+, just now\)$" <<<"$1" && grep -qE "^  vikix \(just now\): review by codex [0-9]+ \([0-9]+ s\): 2 findings, 1 high, in your handoff" <<<"$1"' _ "$out"
check "and the log's line" python3 -c '
import json, sys
r = json.load(sys.stdin)
what = [e for e in r["log"] if e["what"].startswith("review: ")]
assert what and what[-1]["what"] == "review: 2 findings, 1 high; Sound, two things to fix." and what[-1]["by"].startswith("codex "), what
rv = r["handoff"]["review"]
assert rv[-2]["where"] == "log.md:2" and rv[-2]["text"] == "[high] the second line repeats the first" and rv[-2]["open"] and rv[-1]["text"] == "[low] ch1.md has no heading", rv[-2:]' <<<"$(agents handoff h --json)"
n_rev=$(python3 -c 'import json, sys; print(len(json.load(sys.stdin)["handoff"]["review"]))' <<<"$(agents handoff h --json)")
out=$(as 1301 handoff --review-done "$n_rev")
check "the worker marks one addressed: $out" grep -q "book-h: handoff updated by claude 1301$" <<<"$out"
check "and the page says which, by whom" grep -qE "^  addressed \[low\] ch1.md has no heading  \(codex [0-9]+, just now; addressed by claude 1301\)$" <<<"$(agents handoff h)"
check "the reviewer's words are kept: --log" bash -c 'grep -q "^# review of .*book-h at [0-9a-f]* by codex" <<<"$1" && grep -q "^codex: reviewed (stderr words)$" <<<"$1"' _ "$(agents review --log h)"
# Claude Code's road: -p, plan, the schema on the line, the answer under structured_output.
rm -f "$REVIEWED"; out=$(review h --use claude)
check "claude -p --permission-mode plan with the schema, its JSON read from structured_output: $out / $(head -1 "$REVIEWED")" \
  bash -c 'grep -qE "book-h: review by claude [0-9]+ \([0-9]+ s\): 2 findings, 1 high" <<<"$1" && grep -q "^\[-p\] \[--permission-mode\] \[plan\] \[--output-format\] \[json\] \[--json-schema\] \[{\"type\":\"object\"" "$2" && grep -q "^KEYS=0$" "$2"' _ "$out" "$REVIEWED"
# No --use: the provider that isn't the desk's (claude is at it).
rm -f "$REVIEWED"; out=$(review h)
check "unsaid, the other provider reviews: $out" grep -qE "book-h: review by codex [0-9]+" <<<"$out"
rm -f "$REVIEWED"; out=$(review h --use codex --prompt "look hard at the log")
check "--prompt: the words go to the reviewer, before the shape: $(tail -3 "$REVIEWED.prompt" | head -1)" \
  bash -c 'grep -q "^look hard at the log$" "$1" && [ "$(grep -n "^look hard at the log$\|^Answer with JSON" "$1" | head -1 | cut -d: -f2)" = "look hard at the log" ]' _ "$REVIEWED.prompt"
# Reviewing, while it runs: the desk's agent says so under its row, the reviewer's own
# process (here a made-up one in the worktree) is named for what it is, and a second is refused.
touch "$REVIEW_HOLD"
PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" review h --use codex --here > "$t/review-bg.out" 2>&1 </dev/null & bg=$!
note=''
for _ in $(seq 1 80); do note=$(ls "$HOME/.local/state/vikix/office/reviews/"*.reviewing 2>/dev/null | head -1 || true); [ -n "$note" ] && break; sleep 0.25; done
check "a note of the review under way, with the reviewer's pid, the provider and its worktree: $(cat "$note" 2>/dev/null)" \
  bash -c '[ -n "$1" ] && [ "$(cut -f3 "$1")" = codex ] && [ -d "$(cut -f4 "$1")" ]' _ "$note"
wt=$(cut -f4 "$note"); proc 1302 codex "$wt"
out=$(agents)
check "vikix agents: the desk's agent is under review, the reviewer's process is reviewing: $out" \
  bash -c 'grep -qE "^           under review by codex \(pid [0-9]+, since [^)]+\): its findings come to its handoff and its inbox$" <<<"$1" && grep -qE "^  codex +.*vikix-review-.*  no window .* reviewing$" <<<"$1" && grep -q "reviewing a desk.s last commit, read-only, in a worktree of its own (vikix agents review)" <<<"$1"' _ "$out"
check "--json has the review under the desk's agent" python3 -c '
import json, sys
rows = {a["pid"]: a for a in json.load(sys.stdin)}
assert rows[1301]["review"]["provider"] == "codex" and rows[1302]["doing"] == "reviewing", (rows[1301].get("review"), rows[1302]["doing"])' <<<"$(agents --json)"
out=$(review h --use claude)
check "a second review while one runs is refused: $out" grep -qE "^vikix agents: .*book-h: codex is reviewing there already \(pid [0-9]+, since [^)]+\)" <<<"$out"
rm -rf "$t/proc/1302" "$REVIEW_HOLD"
wait "$bg" || true
check "the held review ended well and its worktree is gone: $(cat "$t/review-bg.out")" \
  bash -c 'grep -q "book-h: review by codex" "$1" && [ ! -d "$2" ]' _ "$t/review-bg.out" "$wt"
# Refused: a provider that can't review, one not installed, --prompt with no words, a desk that is gone.
out=$(review h --use aider)
check "aider can't review: $out" grep -q "^vikix agents: aider can't review: the reviewers are codex, claude" <<<"$out"
out=$(PATH="$rev-none:/usr/bin:/bin" FOO=1 python3 "$here/bin/vikix-agents" review h --use claude 2>&1 || true)
check "a reviewer not installed is said so: $out" grep -q "^vikix agents: claude isn't installed here: vikix agent --install claude" <<<"$out"
out=$(review h --use codex --prompt "")
check "--prompt with no words: $out" grep -q "^vikix agents: --prompt needs words for the reviewer" <<<"$out"
out=$(review nowhere-at-all --use codex)
check "a desk that isn't one: $out" grep -q "^vikix agents:" <<<"$out"
# A reviewer that fails, and one that answers prose: neither is lost.
touch "$REVIEW_FAIL"; out=$(review h --use codex)
check "a reviewer that fails is said so, in the record and the inbox: $out" \
  bash -c 'grep -q "book-h: review by codex failed: exit 1 (vikix agents review --log book-h shows its words)$" <<<"$1" && grep -q "\"what\": \"review: exit 1\"" <<<"$(python3 "$2" handoff h --json)" && grep -q "vikix (just now): review by codex failed: exit 1" <<<"$(python3 "$2" handoff h)" && grep -q "^codex: something broke$" <<<"$(python3 "$2" review --log h)"' _ "$out" "$here/bin/vikix-agents"
rm -f "$REVIEW_FAIL"
echo 'Looks fine to me, nothing to report beyond a stale heading.' > "$REVIEW_ANSWER"
out=$(review h --use codex)
check "prose instead of the shape is one finding holding it: $out" grep -qE "book-h: review by codex [0-9]+ \([0-9]+ s\): 1 finding, in your handoff" <<<"$out"
check "the finding's words" grep -q "^  open      Looks fine to me, nothing to report beyond a stale heading.  (codex " <<<"$(agents handoff h)"
rm -f "$REVIEW_ANSWER"
check "the worktrees are all gone" test -z "$(git -C "$t/src/book" worktree list | grep vikix-review || true)"
# A worker that handed in sits at its prompt and makes no tool call, so the findings would
# wait unread (2026-10-11): one at its prompt (a stop let through) with a conversation its
# provider can resume is asked to exit and resumed with the review's line as its prompt.
rm -r "$t/proc/1301"
standin claude "$t/src/book-h"
printf '{"at": %s, "kind": "stop", "agent": "claude", "pid": %s, "folder": "%s", "file": ""}\n' "$(date +%s)" "$spid" "$t/src/book-h" >> "$journal"
agents handoff session claude sess-wake-1 --desk h >/dev/null
mkdir -p "$HOME/.claude/projects/-src-book-h"; echo '{}' > "$HOME/.claude/projects/-src-book-h/sess-wake-1.jsonl"
printf '#!/bin/sh\nshift\n"$@" > %s 2>&1\n' "$t/term-out" > "$t/bin/term"; chmod +x "$t/bin/term"
rm -f "$t/term-out"
out=$(DISPLAY=:7 VIKIX_TERMINAL="$t/bin/term" review h --use codex)
for _ in $(seq 40); do [ -f "$t/term-out" ] && break; sleep 0.1; done
check "a worker at its prompt is woken with the findings: $out" \
  grep -q "book-h: claude $spid was at its prompt: its conversation is resumed with the note as its prompt" <<<"$out"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
check "the process was asked to exit" not kill -0 "$spid" 2>/dev/null
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
check "and its conversation resumed in a terminal at the desk, the review's line its prompt: $(cat "$t/term-out" 2>/dev/null)" \
  grep -qE "^AGENT ARGS: --use claude --resume sess-wake-1 review by codex [0-9]+ \([0-9]+ s\): 2 findings, 1 high, in your handoff.s Review" "$t/term-out"
check "the record logs the waking" grep -q "woken: claude [0-9]*: at its prompt, resumed with the note\|woken: claude [0-9]* at its prompt, resumed with the note" <<<"$(agents handoff h --json)"
# tell --now: the same waking with the note; a worker at work is left to its next tool call.
standin claude "$t/src/book-h"
printf '{"at": %s, "kind": "edit", "agent": "claude", "pid": %s, "folder": "%s", "file": "%s/log.md"}\n' "$(date +%s)" "$spid" "$t/src/book-h" "$t/src/book-h" >> "$journal"
out=$(agents tell h "look at the log first" --now)
check "tell --now on a worker at work leaves the note for its next tool call: $out" \
  bash -c 'grep -q "book-h: claude '"$spid"' is working: the note reaches it at its next tool call; the note waits in its inbox" <<<"$1" && kill -0 '"$spid"'' _ "$out"
check "the note waits" grep -q 'user (just now): look at the log first' <<<"$(agents handoff h)"
printf '{"at": %s, "kind": "stop", "agent": "claude", "pid": %s, "folder": "%s", "file": ""}\n' "$(($(date +%s) + 1))" "$spid" "$t/src/book-h" >> "$journal"
rm -f "$t/term-out"
out=$(DISPLAY=:7 VIKIX_TERMINAL="$t/bin/term" agents tell h "and the index" --now)
for _ in $(seq 40); do [ -f "$t/term-out" ] && break; sleep 0.1; done
check "at its prompt, tell --now wakes it with the note: $out" grep -q "book-h: claude $spid was at its prompt: its conversation is resumed with the note as its prompt" <<<"$out"
check "as its prompt: $(cat "$t/term-out" 2>/dev/null)" grep -q "^AGENT ARGS: --use claude --resume sess-wake-1 and the index$" "$t/term-out"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
out=$(agents tell h "nobody there" --now)
check "with no agent at the desk, tell --now leaves the note: $out" grep -q "book-h: no agent is at the desk: vikix agents resume reads the note out when one takes it up; the note waits in its inbox" <<<"$out"
# A pause past its limit ends the worker's turn (the hook's refusal), and the worker then sits
# at its prompt, making no call for the lifted pause to go through (2026-10-11: let go, it sat
# until the user spoke to it): go wakes it as tell --now does, with the words to carry on.
standin claude "$t/src/book-h"
agents pause h >/dev/null
out=$(VIKIX_PAUSE_LIMIT=1 VIKIX_AGENT_PID=$spid python3 "$here/bin/vikix-agents" touch --pause-only 2>&1 </dev/null)
check "the hook's refusal at the limit says go starts the agent again: $(head -c 100 <<<"$out")" \
  grep -q '"deny".*End this turn now, saying you are paused; nothing is lost. The user.s .vikix agents go. starts you again where you were' <<<"$out"
check "and notes in the pause that it ended the turn" grep -q '"ended": [0-9]' "$HOME/.local/state/vikix/office/pause/"*
printf '{"at": %s, "kind": "stop", "agent": "claude", "pid": %s, "folder": "%s", "file": ""}\n' "$(date +%s)" "$spid" "$t/src/book-h" >> "$journal"
rm -f "$t/term-out"
out=$(DISPLAY=:7 VIKIX_TERMINAL="$t/bin/term" agents go h)
for _ in $(seq 40); do [ -f "$t/term-out" ] && break; sleep 0.1; done
check "go wakes the worker whose turn the pause ended: $out" \
  grep -q "book-h: let go, paused [0-9]* s; the pause had ended its turn: claude $spid was at its prompt: its conversation is resumed with the words to carry on as its prompt" <<<"$out"
check "its conversation resumed with the words to carry on, where it was, as its prompt: $(cat "$t/term-out" 2>/dev/null)" \
  grep -q "^AGENT ARGS: --use claude --resume sess-wake-1 Vikix office: your desk was paused by user at [0-9:]* and let go just now, after [0-9]* s (vikix agents go, or the Office.s Go). The wait had reached 1 s and ended your turn; this is the pause lifted, not a new task: carry on from where you were, on the same task and plan; the pause changed nothing of yours. A note from the user, when there is one, reaches you at your next tool call.$" "$t/term-out"
check "the record logs the waking" grep -q "woken: claude [0-9]* at its prompt, resumed with the words to carry on" <<<"$(agents handoff h --json)"
check "the pause is gone" test -z "$(ls "$HOME/.local/state/vikix/office/pause/")"
for _ in 1 2 3 4 5; do kill -0 "$spid" 2>/dev/null || break; sleep 0.2; done
wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
# When it can't be woken (no desktop here to open its terminal on), why is said and the words
# wait in its inbox, for its next tool call; the agent stays.
standin claude "$t/src/book-h"
agents pause h >/dev/null
VIKIX_PAUSE_LIMIT=1 VIKIX_AGENT_PID=$spid python3 "$here/bin/vikix-agents" touch --pause-only >/dev/null 2>&1 </dev/null || true
printf '{"at": %s, "kind": "stop", "agent": "claude", "pid": %s, "folder": "%s", "file": ""}\n' "$(($(date +%s) + 1))" "$spid" "$t/src/book-h" >> "$journal"
out=$(agents go h)
check "with no desktop, go says why the worker wasn't woken and leaves the words: $out" \
  grep -q "book-h: let go, paused [0-9]* s; the pause had ended its turn, and claude $spid is at its prompt, and there is no desktop here to open its terminal on: speak to it; the words to carry on wait in its inbox" <<<"$out"
check "the words wait in the inbox" grep -q "user (just now): Vikix office: your desk was paused by user at [0-9:]* and let go just now" <<<"$(agents handoff h)"
check "and the agent stays" kill -0 "$spid"
agents pause h >/dev/null
out=$(agents go h)
check "a desk paused with its agent at its prompt, no turn ended, is left to its next call: $out" \
  grep -q "book-h: let go, paused [0-9]* s; claude $spid goes on at its next call, told it was paused and to carry on where it was" <<<"$out"
kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null || true; rm -rf "$t/proc/$spid"
python3 - "$journal" <<'PYJ'
import sys
lines = [l for l in open(sys.argv[1]) if '"kind": "stop"' not in l]
open(sys.argv[1], "w").writelines(lines)
PYJ
proc 1301 claude "$t/src/book-h"
# review=codex in the office file: a hand-in starts one by itself; without it, nothing does.
rm -f "$REVIEWED"
VIKIX_AGENT_PID=1301 PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" handoff --status working >/dev/null 2>&1 </dev/null || true
VIKIX_AGENT_PID=1301 PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" handoff --status review >/dev/null 2>&1 </dev/null || true
sleep 1
check "no review= in the office file: a hand-in starts no review" test ! -e "$REVIEWED"
echo 'review=codex' >> "$HOME/.config/vikix/office"
VIKIX_AGENT_PID=1301 PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" handoff --status working >/dev/null 2>&1 </dev/null || true
VIKIX_AGENT_PID=1301 PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" handoff --status review >/dev/null 2>&1 </dev/null || true
for _ in $(seq 1 80); do [ -e "$REVIEWED" ] && grep -q "review by codex" <<<"$(agents handoff h | tail -4)" && break; sleep 0.25; done
check "review=codex: the hand-in started a review by itself, apart from the caller, and its findings came: $(tail -3 <<<"$(agents handoff h)")" \
  bash -c '[ -e "$1" ] && grep -q "review by codex" <<<"$(python3 "$2" handoff h | tail -4)"' _ "$REVIEWED" "$here/bin/vikix-agents"
rm -f "$REVIEWED"
VIKIX_AGENT_PID=1301 PATH="$rev:$PATH" python3 "$here/bin/vikix-agents" handoff --summary "more" >/dev/null 2>&1 </dev/null || true
sleep 1
check "a status that stayed review starts none" test ! -e "$REVIEWED"
sed -i '/^review=codex$/d' "$HOME/.config/vikix/office"
check "help lists review among the workers' commands" grep -q "^  vikix agents review DESK \.\.\. *a review by another provider" <<<"$(agents help)"
unset -f review

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
# The definition of done: one table (DONE in lib/handoff.py), given by desk_prompt, on the skill's
# projects page and in the guide, held to the one in the code.
check "the definition of done is in the worker's first prompt, the skill's projects.md and docs/agents.md, word for word" \
  python3 - "$here" <<'PY'
import importlib.util, re, sys
from importlib.machinery import SourceFileLoader
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1] + "/lib")
import handoff
spec = importlib.util.spec_from_loader("office_agents", SourceFileLoader("office_agents", sys.argv[1] + "/bin/vikix-agents"))
A = importlib.util.module_from_spec(spec); spec.loader.exec_module(A)
norm = lambda t: " ".join(re.sub(r"^> ", "", t, flags=re.M).split())
done = norm(handoff.DONE)
bad = [name for name, text in (("desk_prompt", A.desk_prompt("x")),
                               ("projects.md", open(sys.argv[1] + "/config/claude/skills/vikix/projects.md").read()),
                               ("docs/agents.md", open(sys.argv[1] + "/docs/agents.md").read()))
       if done not in norm(text)]
if bad:
    print("not word for word in: " + ", ".join(bad))
sys.exit(1 if bad else 0)
PY
check "the rules file has no rule that lets sudo or a force-push through" \
  bash -c '! grep -E "\"(sudo|doas)\".*allow|--force.*allow" "$1/config/codex/vikix.rules"' _ "$here"
# The hook allows what the rules file allows, from the same words: its vikix and git lines are the
# hook's lists, and the git verbs that prompt (a deleting branch, tag, worktree) its exceptions.
check "the rules file's vikix and git allow lines are the hook's ROUTINE_VIKIX and ROUTINE_GIT, its prompting git verbs GIT_ASKS" \
  python3 - "$here" <<'PY'
import importlib.util, re, sys
from importlib.machinery import SourceFileLoader
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_loader("office_agents", SourceFileLoader("office_agents", sys.argv[1] + "/bin/vikix-agents"))
A = importlib.util.module_from_spec(spec); spec.loader.exec_module(A)
rules = open(sys.argv[1] + "/config/codex/vikix.rules").read()
def allowed(prog):
    m = re.search(r'prefix_rule\(pattern=\["%s", \[([^\]]*)\]\], decision="allow"' % prog, rules)
    return tuple(w.strip('"') for w in m.group(1).split(", ")) if m else ()
asks = {m.group(1): set(w.strip('"') for w in m.group(2).split(", "))
        for m in re.finditer(r'prefix_rule\(pattern=\["git", "(\w+)", \[([^\]]*)\]\], decision="prompt"', rules)}
bad = [f"{what}: rules {a!r}, hook {b!r}" for what, a, b in (("vikix", allowed("vikix"), A.ROUTINE_VIKIX),
                                                           ("git", allowed("git"), A.ROUTINE_GIT), ("asks", asks, A.GIT_ASKS)) if a != b]
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY

[ "$fail" = 0 ] && echo "codex: ok"
exit "$fail"
