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

> 2026-10-07: the first three pieces are in (the task as the agent's first prompt, by `desk --task`, which another session built the same day in 0.71.249 with an estimate the handoff counts down; `resume` starts the agent with no first prompt: a resumed conversation has its context, a fresh one the handoff printed above it; the inbox, `vikix agents tell`, delivered by Claude Code's hook and read out by `handoff` and `resume` for the others; the report: a notification when an agent's status comes to review, waiting or finished, and the Stop hook `vikix agents stopping` asking a worker once for its handoff). The bar's agent-waiting note doesn't show a status yet: the note is by X window, which a status set from a terminal doesn't know; left for the Office's step.
> 2026-10-08: pause and go, the hard form and turns are in (`pause`, `go`, `turns`, `pause_hold`, `take_turn` in `bin/vikix-agents`; the second hook entry `touch --pause-only` before every tool, which delivers waiting notes too, so a note now reaches a worker at its next tool call, a read included). Not the Office's buttons: step 4.
> 2026-10-08: the tester is in (`vikix agents test [DESK | --all] [--log DESK]`; `test_desk`, `test_batch`, `test_all`, `tester_start` in `bin/vikix-agents`; `tests/tester.sh`). A desk joins the batch when it changed no file the batch has, in the order the desks went to review, which is greedier than "disjoint from every other" and runs fewer times. The note's 500 characters hold the failing tests' names and the first failure's line; the whole run is in `office/tests/ID.log`, `--log`. A project with no runner gets no check and no note, so a hand-in there makes no noise.
> 2026-10-08: dismiss and the SessionEnd note are in (`dismiss`, `left`; a note to the agent first; `Left:` on the handoff's page and in the Office's details), with the menu forms (`--menu` on tell, pause, test and dismiss; `pick_desk`), the desk keys `t`, `p`, `i`, `x`, and the Office's Pause/Go, Test and Tell buttons (`desk_action` in `lib/office.py`: `--pause`, `--unpause`, `--test`, `--tell`). The design is complete; what stays out is said under "What doesn't change".

> 2026-10-09, Vid: desks and workers apart. The workflow made a desk for every worker, so "worker" and "desk" were one word for two things. Now `vikix agents desk PROJECT TOPIC` makes the place alone (the worktree, the branch, a record, nobody at it), `vikix agents worker DESK "task"` starts an agent on a task there, and a desk takes its workers one after another on the same branch, the record folding each task before into its history (`workers`) with how it ended; `desk --task` stays as the shortcut doing both; `worker DESK` with no task is a session there. Two at once are refused (one worktree, one `git status`: the house rules couldn't say whose edit is whose; the locks of TODO 99 would be the way, if a day asks for it). Stage 2, the Office's rows a desk with its workers and the menu's two entries, comes next.

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

(The first three pieces are built: `desk_prompt` and `first_prompt_args`, `inbox_*`, `tell`, `notes_for_hook`, `status_told`, `handoff_apply` and `stopping` in `bin/vikix-agents`; a Bash command that writes at a desk is journaled as kind `shell`, so the Stop hook sees a `sed -i` too, while the clash and protection counts still read edits and crossings alone.)

(Pause and go and turns are built as the design said, with two differences: a turn is held only while the file is still uncommitted in the other agent's worktree, `clash_live`, since a journal entry alone would hold the turn for as long as that agent lives; and the hard form signals the agent's process by descriptor, `signal_agent`, checking it is an agent still.)

(The tester is built as the design said, in `bin/vikix-agents` rather than `lib/office.py`; the Office reads `testing` from the same note the listing reads.)

(Dismiss, the SessionEnd note, the keys and the Office's buttons are built as the design said; `left` keeps a dismissal noted a moment before over the hook's own reason, and the Office's Dismiss is its Close agent button, which was there.)

**Tests.** `tests/house.sh`: the inbox delivered and emptied, a pause that holds and then denies at the limit (`VIKIX_PAUSE_LIMIT=2`), `--pause-only` at a Read, turns waiting and the deadlock answered `ask`, the Stop hook's four cases. `tests/handoff.sh`: `review` starts the tester (`VIKIX_TESTER` names a stand-in), the check and the inbox line, `left` noted. `tests/office.sh`: `test` on a made-up project with a stub `tests/run.sh` that records what it ran, `--all` with two disjoint desks and one that overlaps, the batch's throwaway worktree gone afterwards. `tests/office-ui*`: the new buttons. `tests/mcp.sh`: `handoff_update` to review notifies.

## What doesn't change

- No agent types into another's window, answers another's question or resolves another's changes; the inbox is one way, and read by the agent's own hook.
- A desk's branch is only ever changed by its agent and by you; the tester's batch is a throwaway worktree, removed when the run ends.
- The handoff's three kinds of field stay apart and signed; a note in the inbox is `by` whoever wrote it, and the tester's lines are Vikix's.
- Agents without a hook (Aider; Gemini until its hook shape is tried) get the hard pause and the record, nothing else: said in `vikix agents hooks`, as the protection lines say today.

## Order

1. ~~The task reaches the worker, the inbox, the report.~~ In, 2026-10-07.
2. ~~Pause and go, the hard form, turns.~~ In, 2026-10-08.
3. ~~The tester, and review running it.~~ In, 2026-10-08.
4. ~~Dismiss and `left`, the keys, the Office's buttons, the guide, the skill.~~ In, 2026-10-08.
