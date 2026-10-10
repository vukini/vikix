# Codex as a first-class worker — design

Codex (OpenAI's agent, `codex`) already starts from Vikix, sits at desks, takes a task, writes a handoff and is resumed. What it does not do is hold the house rules the way Claude Code does, run a long task without a stop at every escalation, or tell the Office what it is doing. This design makes Codex a worker Vikix can trust with a desk: the same guide, a launcher that sets its autonomy and its sandbox per desk, hooks that enforce the house rules at the tool, states the Office can read, and a hand-in other agents can take up, review and correct.

Drafted 2026-10-10 for TODO item 116, from Vid's brief ("First-Class Codex Integration and Multi-Agent Collaboration"). *2026-10-10, Phase 1 shipped* (the launcher: `CLAUDE.md` as Codex's fallback with the cap, `--mode` on `vikix agent`, `worker`, `desk`, `resume`, the plan file and the Office's form, the mode in the record, `config/codex/vikix.rules` and its install, the hook-trust flag; `tests/codex.sh`; the guide's *Modes*): what shipped is deleted below, and what it changed is dated. What was found building it: Codex ignores a config key it doesn't know on the command line, so `codex debug prompt-input` was used to verify the fallback (it shows the prompt's instructions, `CLAUDE.md` among them with the overrides and not without), `codex sandbox -c sandbox_mode="workspace-write" -c 'sandbox_workspace_write.writable_roots=[]'` to verify the narrowed roots (the folder and `/tmp` writable, `~/src` and `.git` refused), and `--approve-for-me` from `codex --help` stands in for the `approvals_reviewer` key, which could not be verified the same way. Kept like the other designs: what ships is deleted from it, what changes is dated. Where the brief left a choice open, the choice made is marked *decided here*, for Vid to overturn. Everything said of Codex below was checked on the dev machine against Codex CLI 0.160.1 (`codex --help`, `codex features list`, `codex sandbox`, its hooks and config documentation on 2026-10-10); where a thing is from its documentation alone it says *unverified here*.

---

## The problem

Vikix treats its six agents alike, and Codex is in every part of the office already. What is there, and what each part lacks for Codex, on this machine today:

| The brief asks for | What exists | What is missing |
|---|---|---|
| Shared project context | `~/.codex/AGENTS.md` is a link to `~/.local/share/vikix/AGENTS.md`, the skill's first page, made by `vikix agent --write-guide` (15 KB; it names the skill's other pages by path). Vid's own `~/.codex/AGENTS.override.md` tells Codex to read it. | Nothing of the repository's: Codex reads `AGENTS.md` from the repository's root to the folder it works in, never `CLAUDE.md` (77 KB), and stops at 32 KiB in all (`project_doc_max_bytes`). A Codex worker on Vikix has the desktop's guide and not the project's. |
| Autonomy | `vikix agent --use codex` starts it as the user's config has it (`sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`); `--sandbox read-only` for a `vikix diagnose` report; `--oss` for a local model. | No mode: every escalation out of the sandbox is a prompt, and at a desk there are many (below). Vid's `~/.codex/rules/default.rules` holds sixty "always allow" rules from past Codex desks, `git push` and `.claude/release` among them: the record of what the prompts cost. |
| The sandbox at a desk | Codex's Linux sandbox works on Void (bubblewrap and seccomp; verified: a write outside the workspace fails as *Read-only file system*, `/tmp` and the folder are writable). | The user's config widens it: `writable_roots = ["/home/vukini/src"]`, so from a desk Codex may write the project's own folder, `~/src/vikix`, and every other desk. And a desk's `.git` is a file pointing into the repository's `.git/worktrees/`, which Codex protects: inside the sandbox `git commit` fails at a desk, so every commit is an escalation and a prompt. |
| The house rules | `config/codex/hooks.json` is linked as `~/.codex/hooks.json` (`vikix agents hooks codex --install`); `vikix agents touch --for codex` exists. Codex 0.160 has hooks as a stable feature, on by default. | The hook has never fired here: the journal has no edit by Codex. Three reasons, each verified against Codex's hooks documentation: Codex's edit tool is `apply_patch`, whose input is the patch text in `tool_input.command`, and `touch` looks for `file_path`, finds none and returns, so no edit of Codex's is judged; a clash is answered `ask`, which Codex's PreToolUse rejects (a failed hook, not a question); and a hook needs the user's trust once in `/hooks`, tied to the file's hash, so every release that changes the file needs it again. The desk rule holds for Codex through its guide alone. |
| Worker states | The agent-waiting plugin's `notify` setting (`agent-turn-complete`, `approval-requested`, `async-question`) and the `[ ! ] Action Required` title give *waits for your yes*, *asked you something* and *finished its turn* (`vikix-agent-state`, agents.lisp). | *Working* and *at its prompt* come from Claude Code's title mark; Codex writes none, so it is *running* all day. No Stop or SessionEnd hook: a worker that leaves without its handoff is not asked, and how it left is not noted. |
| Resume | `codex resume ID` from the record's session; the store searched in `~/.codex/sessions/Y/M/D/rollout-*-ID.jsonl` (`session_store`, `sessions_on_disk` in `lib/handoff.py`). The hook's `session_id` is never noted, since the hook never ran. | Codex is moving its store: `~/.codex/thread_history_1.sqlite`, `session_index.jsonl` and a `migrate-rollouts` command are there beside the rollout files. Once the files go, the record's session is called lost and a fresh conversation starts. |
| Collaboration | One record a desk (`lib/handoff.py`): task, handoff (status, summary, next, estimate), checks with their freshness, sessions, the inbox (`vikix agents tell`), `resume --use codex` on another provider's desk, the tester, `dismiss`. | A hand-in has no list of files changed, acceptance criteria or review findings as fields; a review by another provider is a conversation to arrange by hand, and the only way to hand a desk from one provider to another is dismiss, then worker. |
| Definition of done | `desk_prompt`: read the handoff, give an estimate, write the handoff when handing back. The skill's rules. The Stop hook asks Claude Code for its handoff after a turn that changed files. | Not written anywhere as one list; Codex has no Stop hook to be reminded by. |
| Tests | `tests/handoff.sh` (resume with `codex resume ID`, the hooks adapter's install), `tests/house.sh` (a Codex process in the clash and crossing cases), `tests/plan.sh` (`agent = "codex"`), `tests/ai-keys.sh` (keys withheld), `tests/titles.sh`. | Nothing runs Codex's hook input through `touch`, nothing checks what the launcher gives Codex, nothing touches its sandbox. |

Two things this design does *not* build: a second agent-management system (everything lands in `bin/vikix-agent`, `bin/vikix-agents`, `lib/handoff.py`, `config/codex/` and the Office), and Codex's own multi-agent features as a way to run the office (its subagents share one folder and one sandbox; a desk is Vikix's unit of work).

## What it is

Six pieces, in the order they are built:

1. **One guide, two files.** Codex gets the repository's instructions as Claude Code does: the launcher names `CLAUDE.md` as the file Codex falls back to when a folder has no `AGENTS.md`, for that session only, with the cap raised to fit it. The desktop's guide stays `~/.codex/AGENTS.md`. Nothing is written into a file of the user's.
2. **Three modes, set by the launcher.** `vikix agent --mode supervised|autonomous|unrestricted`, with Codex's sandbox narrowed to the desk, its approvals routed as the mode says, and a rules file of Vikix's for the commands a desk needs outside the sandbox (git in a worktree, the tests, `vikix`). A worker at a desk is *autonomous* unless its task says otherwise; *unrestricted* is typed each time, warned about, recorded, and refused in a project's own folder.
3. **The hooks, in Codex's shape.** `config/codex/hooks.json` gains Codex's tool names, `apply_patch` read for its paths, a clash answered as OpenCode's is, the Stop and SessionEnd hooks Claude Code has, and a PermissionRequest hook that denies an escalation into the project's own folder, `~/vikix` or another desk whatever the mode: enforcement at the tool, not in the instructions.
4. **States the Office can read.** *Working* from the hooks' journal (an edit or a command noted in the last minute), *waits for your yes* from PermissionRequest as well as the title, *at its prompt* from the Stop hook, how it left from SessionEnd; the mode in every row.
5. **The hand-in, as fields.** The record's handoff gains what the brief lists and `git` can say: files changed against the base, tests run with their result (the checks, already there), acceptance criteria copied from the task, defects and limits, review findings signed by their reviewer, the recommended next action (`next`, already there). `vikix agents review DESK --use PROVIDER` runs a reviewer in a throwaway worktree of the desk's commit, never at the desk, and writes its findings into the record and the inbox. `vikix agents handover DESK --to PROVIDER` passes a desk from one provider to the next in order: the handoff asked for, the worker dismissed, the next one started with the record as its first prompt.
6. **The definition of done**, one paragraph every worker is given (`desk_prompt`), one page of the skill, one section of the guide, and the Stop hook holding every provider that has one to it.

## 1. Shared project context

**What Codex reads.** From `CODEX_HOME` (`~/.codex`): `AGENTS.override.md` if present, else `AGENTS.md`, one file. Then from the project's root (the Git root) down to the folder it works in: in each folder `AGENTS.override.md`, then `AGENTS.md`, then the names in `project_doc_fallback_filenames`, one file a folder, concatenated root first, cut at `project_doc_max_bytes` (32 KiB by default). The chain is built once a session. (Codex's AGENTS.md documentation, 2026-10-10; the symlink case is not documented, and `~/.codex/AGENTS.md` being a link has worked here since 0.49.)

**What Vikix does** shipped in Phase 1 (`codex_args` in `bin/vikix-agent`: the two overrides, for the terminal and `--exec`, never the ACP adapter).

*Decided here:* `CLAUDE.md` is the one source for the repository, as the brief asks, and no `AGENTS.md` is added to Vikix's repository: a second file is a second place to go stale, and `.claude/docs-check` watches one. A line at the head of `CLAUDE.md` says that Codex and Claude Code both read it, and that "Claude" in it means the agent at the desk, whichever it is. If the token cost of the whole file shows in Codex's answers, the fallback becomes a short `AGENTS.md` that names the sections of `CLAUDE.md` to read for each kind of change, and `.claude/docs-check` gains it; not before.

**Where the rest is found.** The guide's table names the skill's pages by path (`~/.claude/skills/vikix/NAME.md`), `vikix docs` finds the guides, `man vikix-agents` the commands: Codex opens them when it needs them, which is the brief's "without loading unnecessary documentation into every prompt". Nothing new here.

**The same for the others.** OpenCode reads the skill; Gemini CLI and Antigravity CLI import the guide; Aider is given it. The repository's `CLAUDE.md` reaches them as their own fallback mechanisms allow (Gemini's `GEMINI.md`, Antigravity's rules): noted, not built here. The strategy's sentence is in `docs/ai.md` (Phase 1).

## 2. Autonomous Codex execution

**Codex's levers, as 0.160.1 has them.** `approval_policy`: `on-request` (the model asks when an action needs to leave the sandbox) or `never` (a failed action goes back to the model; `untrusted` is retired, `on-failure` deprecated). `approvals_reviewer`: `user` (the default) or `auto_review`, where a second Codex agent decides each escalation under a policy that denies credential probing, data leaving and destructive acts, and trips a breaker after three denials (`--approve-for-me` on the command line). `sandbox_mode`: `read-only`, `workspace-write` (the folder, `/tmp`, and `[sandbox_workspace_write].writable_roots`; network off unless `network_access = true`), `danger-full-access`. Rules (`~/.codex/rules/*.rules`, experimental): a `prefix_rule` with `allow` runs a command prefix outside the sandbox without a prompt, `prompt` asks, `forbidden` refuses; the most restrictive match wins; `codex execpolicy check` tests a file. `--dangerously-bypass-approvals-and-sandbox` (alias `--yolo`) is the whole lot off. All of it takes `-c key=value` on the command line, which is how the launcher sets it per session. The newer permission profiles (`default_permissions`, `[permissions.NAME]`) cannot be mixed with `sandbox_mode`; the user's config uses `sandbox_mode`, so this design does too, and a later Codex that retires it moves the table below, not the design.

**The modes** shipped in Phase 1 (`codex_mode_args` in `bin/vikix-agent`, the one place the rows are written; the table stays here as the reference):

| Mode | Sandbox | Approvals | Network | Rules | For |
|---|---|---|---|---|---|
| `supervised` | `workspace-write`, roots: the desk alone (`writable_roots=[]`, which overrides the user's `~/src`) | `on-request`, reviewer `user` | off | Vikix's rules file (below) | an unfamiliar project, a machine with things on it |
| `autonomous` | the same | `on-request`, the reviewer through `--approve-for-me` (2026-10-10: the flag, since the `approvals_reviewer` key can't be verified here) | `network_access=true` | the same | a desk's worker: the default (Vid, 2026-10-10) |
| `unrestricted` | `danger-full-access` | `never` (the flag `--dangerously-bypass-approvals-and-sandbox`) | on | ignored by Codex | the VM, a container; typed each time |

What the two sandboxed modes share: the desk is the only writable root, so the project's own folder, `~/vikix` and the other desks are read-only to Codex's shell inside the sandbox, and `.git` (the desk's file and the repository's `.git/worktrees/NAME` it points to) is protected by Codex; `/tmp` is writable, as the tests need; the sandbox covers what Codex spawns (git, the test runner, pip). What *autonomous* adds is the reviewer in the user's chair for the escalations and the network for dependencies (`pip`, `cargo`, `git fetch` over HTTPS; the SSH agent is withheld as today, so `git push` has no key unless the worker was started `--push`), which TODO item 81's ledger will show.

**Why a desk prompts so much, and the rules file** (shipped in Phase 1 as `config/codex/vikix.rules`, with `tag`, `describe`, `ls-files`, `blame`, `history` and `version` allowed too, `doas` forbidden beside `sudo`, and the deleting verbs of `branch`, `tag` and `worktree` at `prompt`; held to its intent by `tests/codex.sh` through `codex execpolicy check`, skipped where Codex isn't installed).** A desk's `.git` is read-only inside the sandbox, so `git add` and `git commit` at a desk are escalations, each a prompt in *supervised* and each a reviewer's decision in *autonomous*; the same for `vikix snapshot` (writes `~/.local/state`), `tests/run.sh` (its slots and logs there too), `vikix agents handoff` (the record). Vid's `default.rules` is the list of what he was asked. So Vikix ships `config/codex/vikix.rules`, linked as `~/.codex/rules/vikix.rules` by `vikix agents hooks codex --install` beside the hooks file (Codex reads every `.rules` file under `~/.codex/rules/`; a file of the user's there is left alone), with `allow` for what a desk's day needs and nothing that leaves the house:

```
prefix_rule(pattern=["git", ["add", "commit", "status", "diff", "log", "show", "stash", "rebase", "checkout", "switch", "restore", "rev-parse", "branch", "fetch", "merge"]], decision="allow", justification="a desk's own branch")
prefix_rule(pattern=["git", "push"], decision="prompt", justification="pushing is the user's (gup); a worker started with --push has the key")
prefix_rule(pattern=["git", "worktree"], decision="prompt", justification="desks are made and closed by vikix agents")
prefix_rule(pattern=["tests/run.sh"], decision="allow")
prefix_rule(pattern=["vikix", ["snapshot", "changes", "agents", "try", "docs", "what", "why", "rules", "eval", "project", "records", "doctor", "theme"]], decision="allow")
prefix_rule(pattern=[".claude/release"], decision="allow", justification="the house's release path, which refuses the dangerous cases itself")
prefix_rule(pattern=["vikix", "update"], decision="prompt")
prefix_rule(pattern=["sudo"], decision="forbidden", justification="nothing of the system from a desk; ask the user")
prefix_rule(pattern=["git", "push", "--force"], decision="forbidden")
```

`codex execpolicy check --rules config/codex/vikix.rules -- git commit -m x` in `tests/codex.sh` holds the file to its intent (each line's `match`/`not_match` examples do the same at Codex's load). A rule allows a *prefix*: `git branch -D` is under `git branch`, so the branch verbs that delete are `prompt` in their own lines, which win by being stricter. *Vid, 2026-10-10:* `.claude/release` is allowed because it is the step the house asks a worker to finish with, and it refuses by itself a main behind origin, a dirty tree and a failed test; whether a given worker releases is the task's to say (a plan file's `gate = "me"`, the task's words), not the provider's. `git push` prompts rather than being forbidden because a worker started `--push` is meant to.

**The switch** shipped in Phase 1, with these changes: the mode is kept as the record's `launch` (`provider`, `mode`, `by`, `at`; `set_launch` in `lib/handoff.py`, written by `worker`, `desk --task` and `resume`) rather than a `worker` dict, shown as the page's *Mode:* line, in the listing's handoff line and the Office row's `mode`; `resume` without `--mode` takes the last launch's mode for the same provider; a Codex started by hand gets the house default only in a desk (a linked worktree), elsewhere the user's own settings unless `--mode` is typed; the project's own folder is judged by `vikix agents place FOLDER` (two words: known/unknown/none, desk/own/none), which the launcher asks; the mode also rides in `VIKIX_AGENT_MODE` for what the agent runs.

**For the other providers.** The same word maps where it can: Claude Code `--permission-mode default|acceptEdits|bypassPermissions`, OpenCode's `permission` block (`ask`/`allow`), Gemini CLI `--approval-mode default|auto_edit|yolo`, Antigravity CLI `--mode`. `--mode` is accepted for every provider from the first phase and refused with the words for one whose mapping is not yet written (Aider has none): Codex's row is built now, the others' are added as each is tried, and `docs/ai.md` says which are.

**What stays Codex's own.** Its model, effort, `/permissions` changes mid-session, its `default.rules` of the user's own, `AGENTS.override.md`, `notify` (the plugin's), the MCP servers in `config.toml`. The launcher adds to the command line and links files of Vikix's; it edits no line of the user's.

## 3. The house rules and the Office

**The hooks file**, `config/codex/hooks.json`, in Codex's shape (from its hooks documentation, 2026-10-10: the same JSON as Claude Code's for `PreToolUse`, `Stop` and `SessionEnd`, with differences named below):

```
PreToolUse       matcher "Bash|apply_patch"        vikix agents touch --for codex          (the house rules, the pause, the notes)
PreToolUse       (no matcher)                      vikix agents touch --for codex --pause-only
PermissionRequest matcher "Bash|apply_patch"       vikix agents touch --for codex --escalation   (an escalation judged: deny off the desk)
Stop                                               vikix agents stopping --for codex
SessionEnd                                         vikix agents left --for codex
UserPromptSubmit                                   vikix agents touch --for codex --turn   (a turn began: the working mark)
```

What changes in `bin/vikix-agents`:

- `touch` reads Codex's input. `tool_name` is `Bash` or `apply_patch`; both carry `tool_input.command`. For `apply_patch` the command is the patch text, and `patch_paths` reads its `*** Add File:`, `*** Update File:`, `*** Delete File:` and `*** Move to:` lines, each made absolute from `cwd`, and every one goes through the judgement an Edit does (the desk rule, the pause, clashes, crossings, the journal: kind `edit`, one entry a file). A `Bash` goes through `touch_bash` as today. The hook's `session_id` is noted on the desk (`note_session`), so `resume` has Codex's conversation without the user typing it.
- `hook_output` for `codex` never says `ask`: Codex's PreToolUse takes `deny` (with `permissionDecisionReason`), `allow` and `additionalContext`, and fails the hook on `ask`. A clash is answered as OpenCode's is (the journal's `asked` kind): refused once with the reason and `vikix agents clash FILE`, and the same edit within ten minutes goes through, the agent having told the user. A crossing is `additionalContext`, as for Claude Code. The desk rule stays `deny`. The notes from the inbox ride on `additionalContext` too, so `vikix agents tell` reaches a Codex worker at its next tool call, as it reaches Claude Code.
- `--escalation`: the PermissionRequest hook. Its answer is `hookSpecificOutput.decision.behavior`, `allow` or `deny` with `message`, or nothing, which leaves the prompt to the user or the reviewer. Vikix answers `deny` for an escalation whose command would write (the `writes` judgement of `touch_bash`) into the project's own folder, `~/vikix`, another agent's desk or `~/.config/vikix/secrets/`, and says nothing otherwise. This is the enforcement the brief asks for beyond instructions: in *autonomous* mode the reviewer never sees these, and in *unrestricted* there is no PermissionRequest to hook, which is one more reason that mode is typed each time.
- `stopping` and `left` take `--for codex`. Codex's Stop carries `stop_hook_active` and `last_assistant_message` and takes `decision: block` with a `reason` that becomes the next prompt, so the handoff reminder works unchanged. Codex's SessionEnd fires when the conversation is archived, Codex closes, or after thirty minutes idle with no client; `reason` is always `other`, so `left` says *left* without a cause for Codex. The Stop hook also writes the agent-waiting plugin's note when the plugin is there (`agent-waiting done`, the same command Claude Code's Stop hook runs), so *finished its turn* and *at its prompt* no longer wait for `notify`'s minute.
- `--turn` (UserPromptSubmit) writes a `turn` entry to the journal, so a worker that is thinking before its first tool call is *working*, not *running*.

**Trust** shipped in Phase 1 (`codex_hooks_ours` in `bin/vikix-agent`: the link, or a link to a copy of the file, since the installed checkout's copy is the same file; `codex_trust_line` in `vikix agents hooks codex`). *Vid, 2026-10-10:* the flag only when the hooks file is Vikix's and the folder is one of the user's known projects; `VIKIX_CODEX_HOOK_TRUST=ask` keeps the prompt everywhere.

**States.** `vikix-agent-state` (agents.lisp) reads the title and the plugin's note; for Codex it gains nothing new in Lisp. `vikix agents` and the Office (Python) gain *working* for any provider without a title mark: an `edit`, `shell` or `turn` entry of the agent's pid in the journal within the last sixty seconds, said as *working (a command 12 s ago)*. *Waits for your yes* comes from the plugin's note (its `notify` already catches `approval-requested`) and from the PermissionRequest hook, which writes the note's `ask` line when the plugin is there, so it no longer depends on the title. The Office's row shows the provider, its mode and its state as today's columns do; *outstanding approvals* is the `ask` note's line, *completed work* the hand-in's `changed` (below). The agent's terminal is named `TOPIC · Codex` as now.

**The store.** `session_store("codex", ID)` and `sessions_on_disk("codex", FOLDER)` learn the SQLite store beside the rollout files: `~/.codex/session_index.jsonl` (id, thread name, updated) and `thread_history_1.sqlite`, read-only, with the rollout glob kept for older installs; `codex resume ID` is unchanged. `tests/handoff.sh` plants both shapes.

**The plan runner, the tester, `vikix try`, the release.** Nothing provider-specific is needed: a Codex worker at a desk runs `tests/run.sh --changed` as any worker, the tester runs it for them, `vikix try` fetches the desk's commit, `.claude/release` is a script. The plan runner's `agent = "codex"` works today (`tests/plan.sh`); it gains `mode`.

**Codex's own worktrees and subagents.** Codex 0.160 has `--worktree` (a managed Git worktree of its own) and subagents (`multi_agent`, on by default: `default`, `worker`, `explorer` in one folder and one sandbox). The launcher never passes `--worktree`; the guide says a desk is Vikix's and is made with `vikix agents desk`. A Codex subagent is not an agent of the office (no terminal of its own): its edits run through the same PreToolUse hooks under the parent's pid, so the house rules see them as the parent's, which is right; whether Codex's `SubagentStart`/`SubagentStop` hooks are needed for anything is left until a worker uses them.

## 4. Workspace and security enforcement

What holds each rule, after this design, said as `protection_lines` will say it:

| Rule | Instructions | Hook | Sandbox |
|---|---|---|---|
| A desk and worktree of its own | the guide | `touch`: `off_desk` denies an edit from a folder that is no desk | — |
| Never the project's own folder, never `~/vikix` | the guide | `touch` denies; PermissionRequest denies the escalation | both outside the desk's writable root |
| Never another agent's worktree | the guide | a crossing is told and recorded; a clash is refused once | outside the writable root |
| Never force-push, never rewrite main | the guide | `git push --force` forbidden by the rules file; `.claude/release` is the only road to main and refuses what it should | the repository's `.git` is read-only inside; the SSH agent is withheld |
| The release process | the guide | `.claude/release` allowed, `vikix update` and `git push` prompt | — |
| Keys and secrets | the guide | `drop_keys`-style `env -u` at the start (today); PermissionRequest denies a write under `secrets/` | Codex's own `shell_environment_policy` drops `*KEY*`, `*SECRET*`, `*TOKEN*` by default |
| No destructive system operation | the guide | `sudo` forbidden by the rules file | `/etc`, `/usr` outside the root |

The brief's caution, that autonomy must not bypass the protections: *autonomous* changes only who answers an escalation (the reviewer for the user); the hooks and the rules file run before either sees it, and the sandbox under both. *Unrestricted* removes the sandbox and the approvals; the PreToolUse hooks still run (they are Codex's, not the sandbox's), so the desk rule and the clash check hold even there, and the PermissionRequest hook has nothing to do, which the mode's warning says.

**What remains advisory.** A command that writes through a program `writes` doesn't know passes `touch_bash` (a Python script of the agent's own); inside the sandbox it is still held to the desk's root. The PermissionRequest hook answers Codex's escalations, not the reviewer's reasoning. No filesystem lock between agents (TODO 99). `protection_lines` keeps its last line about no filesystem enforcement for the hooks' part, and gains *sandboxed to its desk (codex)* for the Codex rows, read from the launch's mode in the record.

## 5. Cross-agent collaboration and handoffs

**The hand-in's fields.** `lib/handoff.py`'s `handoff` keeps `status`, `summary`, `next`, `estimate`, and gains, each signed as the others are:

| Field | Written by | What |
|---|---|---|
| `acceptance` | the user (`--acceptance` on `worker`, `desk --task`, `handoff`; a plan file's `acceptance = [...]`) | the criteria, a list of lines; a worker ticks them (`--done N`), and the record shows `2 of 3` |
| `changed` | Vikix, at every write of the handoff and at the tester's run (`observe`) | `git diff --stat BASE..HEAD` plus the uncommitted, as a list of paths with `+`/`-` counts; BASE is `base_of` (the project's own branch's merge-base) |
| `commits` | Vikix, the same way | the branch's commits past BASE, hash and subject |
| `tests` | the tester and the worker (`--tests "tests/run.sh --changed: 12 passed"`) | already the `checks`, named here as what the hand-in shows |
| `defects` | the worker (`--defect "..."`, repeatable; `--defect-done N`) | known defects and limits, open or closed |
| `review` | a reviewer (`review`, below), or the user (`--review "..."`) | findings, each `by`, `at`, the text, `file:line` when given, `open` or `addressed` |
| `decisions` | the worker (`--decided "..."`) | architectural choices made, a line each, so the next worker doesn't reopen them |

The MCP tool `handoff_update` takes the same fields; `handoff` and `resume` read them out; the Office shows them on the desk's page. Nothing of a conversation is copied: `git`, the record and the project's documents are the common ground, as the brief asks. `clean` caps each field and refuses credentials as it does today.

**A review by another provider.** `vikix agents review DESK [--use PROVIDER] [--prompt "..."]`: a throwaway worktree of the desk's HEAD (as `test_batch` makes one), a reviewer run non-interactively and read-only in it, its findings written into `review` (by `codex 1234` or `claude 5678`) and a line into the desk's inbox, the worktree removed. For Codex: `codex exec --cd WORKTREE -s read-only -a never --output-schema findings.json "review the changes against BASE: ..."`, or `codex review --base BRANCH` when its output proves steady (its text goes into one finding); for Claude Code: `claude -p --permission-mode plan` with the same schema asked for in the prompt. The reviewer never sits at the desk, never edits, has no window: it is a script's child, as the tester is, and `vikix agents` lists it as *reviewing* through a note as the tester's. A review is also what `vikix agents handoff --status review` can start by itself when `review=PROVIDER` is in `~/.config/vikix/office` (off by default; *decided here*: a review that costs a model's time is asked for, not assumed). The implementing worker gets the findings at its next tool call through the inbox, and `--review-done N` closes one.

**Handing a desk over.** `vikix agents handover DESK --to PROVIDER [--mode MODE]`: refused while the desk's agent is mid-turn (*working* in the last minute) unless `--now`; a note to the agent asking for its handoff, up to two minutes for the Stop hook to see it written (the record's `handoff.at` moves); `dismiss`; then `resume DESK --use PROVIDER --fresh`, whose first prompt is the task, the handoff and the hand-in's fields (`desk_prompt` grows a second paragraph from the record), with `handed over: claude → codex` in the record's log. Both sessions stay in `sessions`, so `resume` with either provider finds its conversation. Nothing runs two agents in one worktree: `worker_at` keeps refusing a second, and `handover` is the one road that does the sequence. TODO 115's task record, when it comes, adds the `handed off` event and keeps the task's id across it; this design's handover works on the desk record alone and needs nothing of 115.

**The example workflow, in the commands:** Claude designs at a desk (`worker DESK "design ..." --use claude`, its handoff `review`); `handover DESK --to codex` (Codex implements, runs the tests, corrects, hands in); `review DESK --use claude` (findings into the record); Codex, still at the desk, gets them in its inbox and addresses them; `.claude/release` as the house does. Every step is a command that already exists or is named here, and the Office's desk page shows the whole as one record.

## 6. Standardized task completion

One text, in three places made from one: `lib/handoff.py`'s `DONE`, a paragraph; `desk_prompt` appends it after the task (every provider that takes a first prompt); `config/claude/skills/vikix/projects.md` has it as the section *A worker's day* (SKILL.md is at 15.7 KB of its 16; it gets one line, *a worker finishes as `projects.md`, "A worker's day" says*), and `docs/agents.md` quotes it. The paragraph:

> Understand the task and its acceptance criteria; read the handoff and the project's instructions. Look at the files the task touches before changing them. Make the change at your desk, on its branch. Run the tests the change reaches through the project's runner (`tests/run.sh --changed`), fix what fails, run them again. Update the guides the change makes wrong, in the same commit. Commit only the files you changed, by name. Write the hand-in: status, what changed and why, what is decided, what is left, the tests run, the defects you know of. Hand back through the office (`vikix agents handoff --status review`); don't merge, release or push unless the task or the house says so. Ask when something essential is missing or an action would lose data, open a hole or change the design; decide the routine yourself.

The Stop hook holds Claude Code and Codex to the hand-in (`stopping`, when a turn changed files). A hook-less provider is held by the paragraph alone, and `protection_lines` says so.

## 7. Office task assignment and review

What the Office gains in this design, all on the desk record, with TODO 115's task board noted where it will take a piece over:

- **Provider and mode per worker**: the New worker and New desk forms (`config/emacs/vikix-office.el`) and `vikix agents worker --use --mode`; the row shows both. (115: the task record's `worker` choices.)
- **Progress and blockers**: the hand-in's `acceptance` count, `changed`, `defects` and the state column on the row and page. (115: *Needs attention* as items.)
- **History across providers**: `sessions`, the log's `handed over` line, `workers` as today. (115: `launches`, the event log.)
- **Transfer**: `handover`, a button *Hand over to…* with the provider list. (115: `handed off` event.)
- **Independent review**: `review`, a button *Review by…*; the findings on the page with *addressed* ticks. (115: a *review* item in Needs attention.)
- **Review findings back to the implementer**: the inbox, as above.
- **Acceptance criteria**: the list on the page, ticks by the worker, the user's *Accept* sets the status finished. (115: *needs review* → *ready for release*.)

Nothing here is a scheduler, a queue or a second record: those are 115's, and this design's fields are what 115's task record will carry over.

## 8. Tests and documentation

**`tests/codex.sh`** (no network, no Codex needed for most of it: a stand-in `codex` that records its argv and environment, as `tests/handoff.sh`'s `VIKIX_AGENT_CMD` does):

- the launcher: `vikix agent --use codex` passes the fallback filenames and the cap; each mode passes its table row and nothing else; `unrestricted` is refused in a project's own folder, warned about, and recorded in the launch; `--mode` for a provider without a mapping is refused with the words; keys and the SSH agent withheld as before (`tests/ai-keys.sh` stays the owner of that);
- `touch --for codex`: a PreToolUse input with `apply_patch` and three files judged as three edits (off a desk denied, a crossing told, a clash refused once and passed within ten minutes, never `ask` in the output); a `Bash` input through `touch_bash`; `session_id` noted; the notes on `additionalContext`;
- `--escalation`: a PermissionRequest input for a write into the project's own folder, `~/vikix`, another desk and `secrets/` answered `deny` with a message, a write at the desk answered with nothing;
- `stopping --for codex` and `left --for codex` with Codex's fields;
- the journal's `turn` and the *working* column from it;
- the rules file: `codex execpolicy check --rules config/codex/vikix.rules` for each intent (skipped when Codex isn't installed, said so);
- the store: `session_store` and `sessions_on_disk` against a planted `session_index.jsonl` and SQLite file, and against the rollout glob;
- the hand-in's fields: written, signed, capped, a credential refused, read back by `handoff`; `changed` and `commits` from a made-up repository;
- `review` with a stand-in reviewer writing findings; `handover` on a stand-in agent (asked, dismissed, the next started with the record in its prompt); both refused where they should be;
- `CLAUDE.md` under the cap the launcher sets.

**When Codex is installed** (`tests/codex.sh --live`, by hand, never in `run.sh`): `codex sandbox` with the desk's root shows a write outside refused and `.git` protected; a PreToolUse hook fired once in a real session (the journal's edit by `codex`), which is also the moment `ADAPTERS`' *unverified* for Codex is removed and `UNVERIFIED` loses nothing (it never held Codex). The release pipeline needs no Codex test: `tests/release.sh` and `tests/try.sh` are provider-blind. Recovery from an interrupted worker: `tests/handoff.sh`'s resume cases, with Codex's new store shape added.

**Documentation**, when the phases ship: `docs/agents.md` (*What holds the rules, for each agent* rewritten for Codex; a section *Modes*; *The hand-in*; *A review by another agent*; *Handing a desk over*; *Not there yet* shortened), `docs/ai.md` (the providers' table gains a *Modes* column and the context-sharing sentence), the skill (`projects.md`'s *A worker's day*, `ai.md`'s Codex lines, one line in `SKILL.md`), the guide through `--write-guide`, the headers of `bin/vikix-agent` and `bin/vikix-agents` and so the man pages and `docs/commands.md`, the Office's help line, `plans/DESIGN-office-tasks.md`'s providers table (its Codex row shrinks to what is left).

## 9. Implementation phases

Each phase a release of its own, independently testable, in `tests/codex.sh` unless named:

**Phase 1 — Context and launcher**: shipped 2026-10-10 (above). Of its acceptance, what the tests and the probes showed: the rows passed, `unrestricted` refused in a project's own folder, `CLAUDE.md` in Codex's prompt (`codex debug prompt-input`), a write outside the desk refused inside the sandbox (`codex sandbox`). Still to see on a real desk: a Codex worker committing, testing, snapshotting and handing off with no prompt (the first live run is Phase 5's).

**Phase 2 — The hooks and the states.** `touch --for codex` reading `apply_patch`, never answering `ask`; `--escalation`; Stop and SessionEnd; `--turn` and *working*; the store's new shape; `protection_lines` honest about all of it. *Accepted when:* the journal shows Codex's edits with their paths; an edit from a non-desk folder is denied in Codex's own words; a clash is refused once and passes once told; an escalation into `~/src/vikix` is denied under *autonomous* with the reviewer never asked; a Codex worker that changed files is asked for its handoff before it stops; `vikix agents` says *working* and *at its prompt* for Codex; `resume` finds a Codex conversation from the SQLite store.

**Phase 3 — The hand-in and the handover.** The fields in `lib/handoff.py`, `handoff_update`, `handoff`, the Office's page; `changed` and `commits` from git; `vikix agents handover`. *Accepted when:* a desk handed from Claude Code to Codex shows both sessions, the hand-in's fields intact, and Codex's first prompt holds them; `tests/handoff.sh` runs twenty-five writers over the new fields as it does over the old.

**Phase 4 — The review.** `vikix agents review` with Codex's `exec` and Claude's `-p`, findings into the record and the inbox, `--review-done`, the Office's button. *Accepted when:* a review by the other provider of a desk's commit lands in the record signed, the implementer gets it at its next tool call, and the reviewer's worktree is gone afterwards; `vikix agents` shows *reviewing* while it runs.

**Phase 5 — Validation and the guides.** The live checks (`--live`), the guides and the skill, `DESIGN-office-tasks.md`'s table, the `unverified` words removed where they no longer hold, `.claude/docs-check --reviewed`. *Accepted when:* `tests/run.sh` is green with `codex` in its list, `tests/agents.sh` and `tests/info.sh` pass with the new pages, and a full day's workflow (design, implement, review, correct, release) has been run once on Vikix itself with the two providers, its record kept as the example in `docs/agents.md`.

**Next:** Phase 2, which makes what Phase 1 promises enforceable at the tool.

## What doesn't change

- The desk, the worktree, the record, the inbox, the tester, the plan runner, `vikix try`, `.claude/release`: one model for every provider, as today.
- No file of the user's is written: `~/.codex/config.toml`, `AGENTS.override.md`, `default.rules` are theirs; Vikix links its own files beside them and adds to Codex's command line.
- Claude Code's hooks, `office.json`, the door, the snapshot, the keys withheld: unchanged.
- The agent-waiting plugin keeps its `notify` road for Codex; the hooks only add to it.
- TODO 115's task board keeps its design; this one hands it fields and a `handed over` log line, nothing that competes.

## Unresolved, and the risks

- **Hook trust.** *Vid, 2026-10-10:* the launcher passes `--dangerously-bypass-hook-trust` only when the hooks file is Vikix's link *and* the folder is one of his known projects (`known_repos`, the list the hook judges the desk rule by); elsewhere Codex's own `/hooks` prompt stays, so a cloned repository's `.codex/hooks.json` and a plugin's hooks never run untrusted. `VIKIX_CODEX_HOOK_TRUST=ask` keeps the prompt everywhere.
- **The default mode.** *Vid, 2026-10-10:* a visible setting, `mode=autonomous` with a comment in `~/.config/vikix/office`, shown picked in the forms, `--mode` overriding it for one worker. A setting he wrote is not a guess; the forms' rule stands for choices that make something.
- **The reviewer's judgement.** `auto_review` is a model's decision on each escalation, not a rule: Codex's documentation calls it no deterministic guarantee, and it can approve a write the hooks don't catch (a path the command doesn't name). The PermissionRequest hook and the sandbox stand before and under it; the ledger (TODO 81) will show what left. In *autonomous* mode the network is on for the desk's shell, which is the brief's "controlled network access" only through the sandbox's `network_proxy` domain policy if Vid wants a list; off by default here.
- **`CLAUDE.md` whole in every Codex session**: some 20,000 tokens at the start, the same Claude Code reads. If it shows in Codex's cost or attention, the short `AGENTS.md` that names sections (section 1) is the fallback, and `.claude/docs-check` watches it.
- **`.claude/release` allowed by rule.** *Vid, 2026-10-10:* allowed, one rule for both providers; the yes comes per task, not per provider: a plan file's `gate = "me"` holds a desk's release for his word, and a worker started by hand is told in its task whether it releases. A `prompt` would be answered by Codex's reviewer in the default mode anyway, so it protects less than it seems. The script's own refusals (main behind origin, a dirty tree, failing tests, the queue's lock) stay the guard.
- **Codex's store and flags move**: `sandbox_mode` is the older setting beside permission profiles, rules are experimental, the thread store is mid-migration. Each is behind one table or function (`CODEX_MODES`, `vikix.rules`, `session_store`), and `tests/codex.sh --live` is where a new Codex is tried first, as `vikix ai` does for Super+i's switches.
- **Subagents.** Codex's own may edit under the parent's pid, which the house rules see as the parent's. Whether a subagent spawned in another folder could slip the desk rule is not documented; the sandbox's root is the parent's, so a write elsewhere fails there. To watch in `--live`.
- **The task text's road into the record.** This design's brief reached its worker as its first line only (the body was read from the clipboard); whether the Office's form, rofi or the shell dropped it is not known. Not Codex's, but the first thing to find when the Office's forms are next touched.
