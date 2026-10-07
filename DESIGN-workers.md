# Vikix Workers — design

A desk with a task is a worker: you give it the task, it does the work, hands it in checked, and reports; you can pause it, let two take turns on one file, dismiss it, and take it up again another day.

Drafted 2026-10-07 for TODO item 105, from a talk with Vid. Decided that day, one by one: a pause takes hold at the worker's next tool call (a hard freeze only as a flag); the tester is a script, never an agent; a hand-in (status `review`) runs the tests by itself; a worker is made to write its handoff once before it goes quiet, and a chat session never is. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

The office has desks (`vikix agents desk`), a record a desk (`vikix agents handoff`), the house rules (the hook `vikix agents touch`), the Office frame, close and resume. Vid thinks of them as workers, and the gaps are the ones that word shows up:

- A desk started with `--task` writes the task into its record and says nothing to the agent. The agent starts at an empty prompt and reads the record only if it remembers the skill's rule.
- A worker that finishes says so only by setting its handoff, which it may forget; and when it does, nothing tells you. The Office shows "Needs you" when you open it.
- Nothing pauses an agent. Two agents on one file are stopped at Claude Code's prompt, for you to decide, every time; they never wait for each other.
- Nothing tests a desk's work but the release, at the very end, and nothing tells the worker what failed.
- There is no way to speak to a running worker but typing into its window, which the house rules forbid an agent and which a script can't do decently either.

## What it is

Seven pieces, each a subcommand of `vikix agents`, a key in the desks' map (`Super+Alt+d`) and a button in the Office, with the names of today kept: a *desk* and an *agent* in the code and the commands, a *worker* in the Office's words, since a worker is exactly a desk that carries a task.

- **The task reaches the worker.** `vikix agents desk PROJECT TOPIC --task "..."` starts the agent with the task as its first question, prefixed with "read your handoff first" (`vikix agent --ask`, the path `vikix diagnose` uses). `sit --task`, and `resume` at a desk with a record, hand the agent the same first line, so an agent joining a desk opens on what the desk is for.
- **The inbox: notes to a worker.** `vikix agents tell DESK "..."` leaves a line for the desk's agent, and the hook delivers the lines at the agent's next tool call, as it tells a crossing today. Everything below speaks through it: a test result, "paused", "your turn", "wrap up and write your handoff". Nothing ever types into an agent's window.
- **The worker reports.** A status set to `review`, `waiting` or `finished` notifies you, naming the desk, and the bar's agent-waiting note shows it. For a desk with a task, Claude Code's Stop hook refuses the first stop of a turn that changed files but left the handoff untouched, with the reason "write your handoff: status, what you did, what is left"; the second stop is let go, so nothing loops. A session with no task is never held to it.
- **Pause and go.** `vikix agents pause DESK` and `vikix agents go DESK`. Paused, the hook holds the agent's next tool call instead of answering: the agent sits with its context whole and costs nothing while it waits. After ten minutes it is denied with the reason, so the turn ends cleanly and the Office says "paused, turn ended: continue at its window". `--hard` freezes the process itself (SIGSTOP, SIGCONT on `go`), for an agent with no hook (Aider) or when it must stop this instant; said as such, since a request in flight may time out.
- **Turns on one file.** `vikix agents turns DESK on|off`. On, a clash (another agent has the file changed and uncommitted, or edited it since) holds the edit as a pause does, until the other agent has committed that file, instead of asking you. Two agents each waiting for the other is a deadlock the hook sees, and the later one asks you as today. Off by default: silence is wrong for a session you are talking with.
- **The tester.** `vikix agents test [DESK | --all]`. A script. For one desk it runs the tests its changes reach (`tests/run.sh --changed`, through the runner, so it queues in the machine's slots with everyone else) in the desk's worktree, writes the result into the record as a check with the failing output in the note, and tells the worker through its inbox. `--all` takes every desk in review, sorts them into those whose changed files are disjoint and those that overlap: the disjoint ones are tested together once, stacked on main in a throwaway worktree, since passing alone and failing together is the case a batch is for; the overlapping ones each on their own, each told which it overlaps with. Setting `review` runs the tester for that desk by itself, in the background, once per hand-in. No project with no `tests/run.sh` is tested: the check says so.
- **Dismiss.** `vikix agents dismiss DESK` is the Office's "Close agent" from the terminal: the agent is asked to exit, the desk, branch and files stay, and `resume` takes it up again. A `SessionEnd` hook notes in the record when and how the agent left, so a resumed desk says "dismissed Tuesday 15:40, 3 files uncommitted".

## How it is built

```
  you ── desk --task ──► record (task) ──► vikix agent --ask "read your handoff; TASK"
  you ── tell / pause / go / turns ──► office/inbox/ID.jsonl, office/pause/ID ──┐
                                                                              ▼
  Claude Code ── PreToolUse ──► vikix agents touch ──► waits while paused, waits its turn,
                                                       delivers the inbox as additionalContext
  Claude Code ── Stop ──► vikix agents stopping ──► "write your handoff" once
  agent ── handoff set --status review ──► notify-send; vikix agents test DESK (background)
                                            └─► check in the record; a line in the inbox
```

**The task reaches the worker** (`desk`, `sit`, `resume` in `bin/vikix-agents`): `agent_start(use, extra=...)` already carries the agent's own words after `--`; the task goes there as `--ask "Read your handoff first (vikix agents handoff). The task: ..."`. `vikix agent` passes `--ask` to each provider in its own way (`ASK` in `bin/vikix-agent`: a positional for claude and codex, `--prompt` for opencode, `-i` for gemini and agy; Aider is told to ask). A resume with a saved conversation gets the line too, since the conversation may be days old.

**The inbox** (`~/.local/state/vikix/office/inbox/ID.jsonl`, `ID` the desk's `desk_id` from `lib/handoff.py`, never a pid): one JSON line a note, `{at, by, text}`, `clean` from the lib applied (control characters out, length capped, nothing `SECRET` matches). `touch` reads and empties it under the record's lock, and puts the lines in `additionalContext` of its answer, after a crossing's words. Only Claude Code's hook can carry context: agy's decides only, OpenCode's plugin can only throw, Codex's adapter the same; for them the inbox is shown by `vikix agents handoff` and read out by `resume`, and `tell` says so when the desk's agent is one of those. The listing's row shows "1 note unread" (`where` in `bin/vikix-agents`), and the Office the same.

**The worker reports.** `desk_record` (`handoff set`, the MCP tool `handoff_update`) notifies on a change of status to `review`, `waiting` or `finished` (`notify-send -a Vikix`, as `say` does from the menu; never from a terminal that is a tty, since the user is there). The Stop hook: `config/claude/office.json` gains `"Stop": [{"hooks": [{"command": "vikix agents stopping"}]}]`; `stopping` reads Claude Code's JSON on stdin, lets a stop go when `stop_hook_active` is true (the stop that follows a refused one), when the desk has no `task`, or when the journal has no edit by this agent (`my_agent`) later than the handoff's last change (`handoff.*.at` in the record, the journal's `at`); else answers `{"decision": "block", "reason": "..."}`. The record notes the nudge, so `vikix agents handoff` can say "reminded twice".

**Pause and go** (`office/pause/ID`: a file with `{at, by, hard}`). `touch` looks for it first, before the journal and the rules: while it stands, sleep a second and look again, up to `VIKIX_PAUSE_LIMIT` seconds (600; the tests set 2), then `permissionDecision: deny` with "paused by Vid at 15:40; the turn ends here, and Enter at the window goes on when you say go". The hook's timeout in `office.json` rises to 660 for that entry. A second entry with the empty matcher (every tool, Read and Grep too) runs `vikix agents touch --pause-only`, so a pause takes hold at the next read as well, and costs one `stat` when there is no pause. `--hard` finds the agent as `close_agent` in `lib/office.py` does (pidfd, start identity rechecked) and sends SIGSTOP to the agent's process alone, never its terminal or the group; `go` removes the file and sends SIGCONT when the file said hard. A paused desk is `paused` in the listing's state (`vikix-agent-state` is not touched: the agent's own title still says what it was doing) and "Paused" in the Office, under Parked, with the time and the go button.

**Turns** (a `turns` field in the record, set through `update` under the lock). In `touch`, a clash with `turns` on writes a journal entry of kind `waiting` naming the file and the other agent, then waits as a pause does until `clashes_for` finds the file clean (the other's worktree has it committed, or its journal entry is gone with its pid), up to the same limit; then the clash is answered `ask` as today. Deadlock: before waiting, the journal is read for a `waiting` entry by the other agent that names this agent; if there is one, the later of the two (by `at`) answers `ask` at once and says why. The journal is rewritten at each touch with only the agents still alive, so a dead waiter holds nobody.

**The tester** (`vikix agents test`, `bin/vikix-agents`, the running parts in `lib/office.py` so the Office shares them). One desk: `BASE` is the merge base of the desk's branch and the project's own branch (as `.claude/release` stacks on main); `tests/run.sh --changed BASE` in the worktree, the output to `~/.local/state/vikix/office/tests/ID.log`; then `handoff check tests --ok|--failed --note` with the last forty lines of the first failing test (the lib's `LOG_MAX`), then a line in the inbox: "tests: 2 failed (rules, keys); vikix agents test --log shows them". `--all`: `git diff --name-only BASE` a desk in review; the sets that share no file are merged, in the order they went to review, onto a detached throwaway worktree of the project stacked on its own branch (`git worktree add --detach`, `git merge --no-ff` each; a merge that conflicts drops that desk from the batch, to be tested alone), `tests/run.sh --changed` runs once there, and every desk of the batch gets the check with "with DESKS" in its note; the overlapping ones run each alone, in their own worktree as it stands (a desk's branch is its agent's: never rebased or changed here), with "overlaps DESK on FILES" in the note. `review` triggers the one-desk run through `subprocess.Popen` with `start_new_session=True` from `desk_record`, once per hand-in (a note of the run under `office/tests/ID.running`, pid inside, so a second review while one runs waits for it). While it runs, the listing's `waits` shows "testing" for the desk, from that note, as it shows a release. `vikix agents test --log DESK` prints the log.

**Dismiss**: `dismiss DESK` is `close_agent` from the lib with the desk resolved by `desk_for`, and a last line in the inbox first, "dismissed; write your handoff if you can", which an agent mid-turn reads at its next tool call and an idle one never will. `office.json` gains `"SessionEnd"` → `vikix agents left`, which notes `{at, reason}` in the record under the agent's signature (`reason` from Claude Code's JSON: `exit`, `logout`, `prompt_input_exit`, `other`) and runs `observe`, so the record's git state is the one the agent left.

**Keys and the Office.** In the desks' map: `t` test, `p` pause or go (asks which desk; a paused one offers go), `i` tell, `x` dismiss; `registry.lisp` only, then `lib/skill-keys.sh --write`. The Office: a Paused mark in the row, Pause/Go, Test, Tell and Dismiss buttons, the check's note and the inbox's unread count in the details.

**Tests.** `tests/house.sh`: the inbox delivered and emptied, a pause that holds and then denies at the limit (`VIKIX_PAUSE_LIMIT=2`), `--pause-only` at a Read, turns waiting and the deadlock answered `ask`, the Stop hook's four cases. `tests/handoff.sh`: `review` starts the tester (`VIKIX_TESTER` names a stand-in), the check and the inbox line, `left` noted. `tests/office.sh`: `test` on a made-up project with a stub `tests/run.sh` that records what it ran, `--all` with two disjoint desks and one that overlaps, the batch's throwaway worktree gone afterwards. `tests/office-ui*`: the new buttons. `tests/mcp.sh`: `handoff_update` to review notifies.

## What doesn't change

- No agent types into another's window, answers another's question or resolves another's changes; the inbox is one way, and read by the agent's own hook.
- A desk's branch is only ever changed by its agent and by you; the tester's batch is a throwaway worktree, removed when the run ends.
- The handoff's three kinds of field stay apart and signed; a note in the inbox is `by` whoever wrote it, and the tester's lines are Vikix's.
- Agents without a hook (Aider; Gemini until its hook shape is tried) get the hard pause and the record, nothing else: said in `vikix agents hooks`, as the protection lines say today.

## Order

1. The task reaches the worker, the inbox, the report (the notification and the Stop hook). One release; from then on a worker started with a task comes back with a record.
2. Pause and go, the hard form, turns.
3. The tester, and review running it.
4. Dismiss and `left`, the keys, the Office's buttons, the guide's "Workers" section in `docs/agents.md`, the skill's line on the inbox.
