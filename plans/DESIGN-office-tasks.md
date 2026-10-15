# The Office as a task board — design

The Office shows agents; it should show the work. A task of its own, apart from the agent doing it and the desk it is done at, with a state that is the work's and not the worker's; what needs you, in one list, with the question itself; a queue with priorities and an order, and a scheduler that starts the next task only when you let it; the order the workers were launched in, kept; and a history of every task that outlives it.

Drafted 2026-10-10 for TODO item 115, from Vid's brief ("Office task management, priorities and ergonomics"). *2026-10-14: phase 1 (task identity and metadata) shipped: `lib/tasks.py`, the arms `tasks`, `task`, `events` and `exited`, the snapshot's version 2, the Office's launch number and task record box, the MCP tool `tasks`, the release's `released`, the migration; the sections it built are cut to what changed. Phase 2 (attention and decisions) was implemented 2026-10-14; later phases remain.* Kept like the other designs: what ships is deleted from it, what changes is dated. Where the brief left a choice open, the choice made is marked *decided here*, for Vid to overturn.

---

## The problem

The Office (`lib/office.py`, `config/emacs/vikix-office.el`) is a view of desks: a row a desk, under it the user's task, the agent's live state, the handoff and the next step, grouped into *Needs you*, *Working*, *Parked*, *Finished* and *Closed* (`group` in `snapshot`). That grouping mixes two things that are not one:

- **The worker's state** is what `agents.lisp` reads from the terminal (`vikix-agent-state`: `:asks`, `:done`, `:idle`, `:working`, `:running`, from the agent-waiting plugin's note or the title's mark) and what `waits` reads from the test and release notes. It is observed, each snapshot, and gone when the process is.
- **The task's state** is what the record keeps: the user's `task` and the agent's `handoff.status`, one of `working`, `waiting`, `review`, `finished` (`STATES` in `lib/handoff.py`). It is the agent's claim, written when the agent remembers (the Stop hook asks once).

So an agent that implemented the thing and then asked an architectural question is *at its prompt* while its task is open; the row says *Needs you* only if the plugin caught the question, else *Working*. A worker that exits leaves its task's status at `working` forever; the row goes to *Parked*, among desks that never had a task. A task has no identity but its desk: `workers` in the record folds the task before into a history entry when the next worker starts (`fold_worker`), with no id, no priority and no order, and a task with no desk yet has nowhere to be. Nothing in the Office says which of two waiting agents was started first, what will run next, or why.

What is there and stays, because this design extends it:

| The brief asks for | What exists | What is missing |
|---|---|---|
| A task with identity and metadata | The desk record's `task` (text, by, at), its `workers` history (`lib/handoff.py`) | An id, a record of its own, priority, order, provenance, dependencies, timestamps apart (created, queued, launched, done) |
| Worker state apart from task state | `vikix-agent-state` (agents.lisp), `waits`, `pause_read`, `left` in the record | The two named apart, each with its source and how sure it is; a worker's exit noted for every provider |
| Needs attention | *Needs you* (a desk with an agent in `asks`, or a status `waiting`/`review`, or `attention` `asks`/`gup`/`close`) | Items, not desks: the question itself, since when, the failed test, the clash, the proposal, the worker that stopped; *uncertain* said as such |
| Decisions as objects | The agent-waiting note's third line (what it asked); `vikix agents tell` the other way | A decision registered by the worker, answered in the Office, delivered back |
| Priorities and order | None | Priority, a manual order, run next, defer, cancel |
| A queue and a scheduler | `at-once` is being designed for plan files (the plan runner, at work on a desk of its own since 2026-10-10) | A persistent queue of single tasks, a capacity, a tick that starts the next one only when allowed |
| Launch order and a timeline | The record's `log` (last 40 lines), the seats' order, the journal | A launch number, an event log that outlives the record |
| Agents proposing tasks | `propose_rule` is the pattern: an agent proposes, the user adds | A task proposed, with its parent and its worker named, under a limit |
| One model for every provider | `ADAPTERS`, `RESUME`, `FIRST_PROMPT`, the hooks | The same task record for all; what each provider can and can't report |

## What it is

Five pieces, in the Office's words and `vikix agents`' commands:

1. **A task is a record of its own.** `~/.local/state/vikix/office/tasks/ID.json`, made by every way a task comes into being (`desk --task`, `worker`, `sit --task`, the Office's forms, an agent's proposal, the plan runner), with an id for life, its provenance, its priority, its timestamps, its dependencies and its worker's choices. The desk record points at its task by id; the task points back at its desk, when it has one.
2. **Two states, never one.** The worker's state is observed at each snapshot, with where it came from and how sure it is. The task's state is recorded, and changes only by a named transition: the user's act, the agent's handoff, the tester, the release, the launcher's exit line.
3. **Needs attention**, a list of items at the top of the Office and in `vikix agents attention`: each item one thing you can do something about, with the project, the task, the worker, why, since when, the question when there is one, and the acts that answer it. A **decision** is an item a worker registers on purpose (`vikix agents ask`, the MCP tool `decide`), answered in the Office or with `vikix agents answer`, delivered through the inbox.
4. **The queue**: priority and order, kept apart; `run next`, up, down, defer, cancel; a scheduler (`vikix agents queue`) that says what runs next and why and starts it on your word, or by itself only once `auto=on` is written in your config, never past `at_once` workers, never a second time after a crash.
5. **The Office drawn around the work**: Needs attention, Running (with the launch number and how long), Queue (with position and priority), Blocked (with why), Completed (with the release), then the desks standing empty, Closed and the Archive as today; sorting; a task's full page with its history; every act on a key.

## The task record, the two states, the events

Shipped 2026-10-14 (phase 1): the record, the rules, the sequence, adoption, the transition table and the event log are as designed, in `lib/tasks.py` (its docstring and `TRANSITIONS`, `EVENT_OF`, `KINDS` are the tables now). What changed on the way:

- The table gained the agent's `finished` straight from *running* (no review asked first), a worker reporting from *blocked* (`waiting`, `review`, `finished` end the block: an agent that sat down itself, or was started by hand, at a blocked task), and *completed* from any open state when the work is in (`done=True`: the release, the desk closed with its branch merged), since the branch is on main whatever the record said. `parked`, the fifth handoff word (after the design), is *blocked on parked*.
- `vikix agents worker DESK "new task"` doesn't ask yet what to do with the task before: it is left *blocked on worker* at the desk's back (the design's third choice), to be resumed, handed on or cancelled; the question in the terminal and in the form is phase 4's.
- A task made by `sit --task` or by `handoff --task` at a desk with an agent at it runs with no launch number: the office never started that agent, and no number is made up.
- `adopt` is idempotent by the desk, the time and the words as well as by the ids written back, so a record whose ids can't be written is never adopted twice; the live task of a desk with a launch and no `left` is read as *running*, with none as *ready*; a history entry's `finished` is *ready for release*, as the table says, except on a desk the release closed, where it is *completed*.
- The plan runner's workers carry `origin.kind` `automation`, `source` `plan NAME`, through `VIKIX_TASK_ORIGIN` in its environment; the runner is otherwise unchanged (its `at-once` and chains stay its own until phase 3).

## Attention and decisions (phase 2)

Implemented 2026-10-14. The commands, storage and user workflow are in
`docs/agents.md`, “Needs attention and decisions”; the code is `lib/tasks.py`
(decisions), `lib/office.py` (attention and user actions), `lib/agents/work.py`
(the CLI) and `config/emacs/vikix-office.el` (the attention box and answers).
The snapshot remains version 2, with additive `attention` and task `questions`.

Decisions are durable inbox items themselves: their answer's `delivered`
field is acknowledged by the inbox reader under the decision lock. This
avoids a second file that could lose an answer between two writes. The
answer remains readable after delivery. The task lock serializes the
limit of ten open questions; an answer leaves other blocking decisions
open and never restarts a stopped worker. Ordinary handoff changes cannot
clear an unanswered blocking decision.

Notifications share stable ids across the writer and the Office. Snapshot
reads do not notify; the Office refresh opts in, as does `attention --notify`.
Provider notes supply their timestamp; a title alone has no reliable time,
so its item says unknown. Clashes must still be uncommitted, not merely an
old journal entry. The desks map's `?` opens the attention menu.

Later phases still own the queue, proposal approval and the full five-section
board. Release-stop items can display a release note that says stopped or
refused; retaining such notes after the release process exits belongs with
phase 6's release recovery. The older desk groups remain below Needs attention.

## Priority, order and the queue (phase 3)

Released in 0.72.78 (2026-10-15). Commands and settings are
in `docs/agents.md`, “Priorities and the task queue”. `lib/scheduler.py`
serializes queue edits and launches, computes eligibility, reserves launch
numbers/capacity, and blocks ambiguous starts rather than retrying them.
`worker_at` accepts the task id and reserved sequence so a queued task
keeps its identity. Reads and Office refreshes never tick the scheduler.

The Office adds Queue and Blocked boxes above its existing desk groups.
Queue keys are `!`, `+`/`-`, `M-p`/`M-n`, `d`, `k`, `S`, and `Q` to enqueue
a ready desk task; parked desks move from `k` to `K`. Phase 4 still owns
the full board, sorting and task creation form. A CLI `task new` creates
ready tasks without opening a desk; `task ready` approves/retries backlog
or blocked work after inspection.

Plan workers use the shared capacity lock and launch intents through
`start_plan`; a running plan is explicit authorization for its own steps,
even with `auto=off`. The plan runner keeps its dependency chains, retry
limits and release gates. Their full presentation as one board remains
phase 4's. The per-plan `at-once` may impose a smaller limit than the Office's.

A reservation persists until a worker is observed or its exit is recorded;
a later tick with reliable discovery blocks an ambiguous start after two
minutes. No automatic retry follows. `queue bump` is explicit cooperative
preemption at a different desk; `go` restores the paused task. The default
`at_once=2` and `auto=off` remain unchanged; no user's config is edited.

## Agents proposing tasks

```sh
vikix agents propose "split the picker's scan into a thread" --after t-20261010-7f3a9c   # from a worker
```

The MCP tool `propose_task` is the same. A proposal is a task with `origin` `{kind: agent, by: "claude 48213", parent: the worker's task, worker: the launch's seq}` in *backlog*, an item *proposed* in Needs attention, and nothing else: no desk, no launch, no slot. Approval (`task approve`, the Office's *Approve*) makes it *ready* and signs `approved`. Two policies, in the config: `delegate=ask` (the default: every proposal waits for you) or `delegate=allow` for proposals under a parent whose user-made task says `--delegate N` (the form's *may delegate N tasks* box, off by default): those go to *ready* with `approved.by` `parent t-…`, `N` of them at most, `delegate_max` over all parents in a day at most; past the limit a proposal is a plain proposal. A proposal that names a parent that is not the proposer's own task, or none, is refused. Automation's tasks (the tester's *fix the failing tests*, the plan runner's chains, the morning brief's) have `origin.kind` `automation` and say which. Parent and children are shown together in the Office (a child under its parent in every section); a parent isn't completed while a child is running, and cancelling a parent cancels its backlog children with a note and leaves running ones. Four kinds of origin, each worded in the row: *yours*, *proposed by claude #104*, *made by claude #104 under your t-…*, *by the tester*.

## The providers

One record for all; what differs is behind `ADAPTERS` in `bin/vikix-agents`, which gains three columns beside the hooks:

| Provider | Worker state from | Decisions | Exit |
|---|---|---|---|
| claude | hooks (the plugin's notes, reliable), the title's mark | `ask`/`decide`; the answer through the hook's notes, or `--wait` | SessionEnd and the launcher's line |
| codex | its hooks (`config/codex/hooks.json`, seen firing 2026-10-10: a turn begun, an edit, a stop let through, in the journal), its notify setting (the plugin's `codex` command: a turn ended, an approval or a question), the `Action Required` title | `ask --wait` from its shell; `decide` once `vikix mcp` is given to it | its SessionEnd hook (not seen in `codex exec`) and the launcher's line |
| opencode | its plugin (`config/opencode/vikix-office.js`: a clash only) | `ask --wait` | the launcher's line |
| gemini, antigravity | Antigravity's plugin (the house rules); no state | `ask --wait` | the launcher's line |
| aider | nothing | `ask --wait` | the launcher's line |

So Codex and Claude Code share the record, the queue, the attention list and the history today; *2026-10-10:* TODO item 116 (`plans/DESIGN-codex-integration.md`, five phases, all shipped that day) gave Codex the hooks (*working* from a turn begun, *at its prompt* from a stop let through, the handoff asked for, how it left), a mode per desk, the hand-in's fields, the handover and the review, so what Codex still lacks here is the answer carried into its context by a hook (its hook delivers the inbox's notes; a decision would ride the same road) and `vikix mcp` under Codex (`codex mcp add`), which would give it `decide`, `decision` and `handoff_update` as Claude Code has them: still to verify on a machine that has it, a line in `tests/handoff.sh` when done. A handoff between providers (`resume --use codex` on Claude Code's task) keeps the task id, the decisions, the launches and the history, and appends `handed off`.

## The Office

**The list**, top to bottom, each a box as today, a row a task (a desk with no task is a row in *Desks*):

1. **Needs attention** — the items, in their order: `[decision] #105 codex · vikix/office-redesign · 25 min · asks: keep the old order under --no-scan?` and under it the acts as buttons. The count in the frame's title (*The Office (3)*).
2. **Running** — `#104 claude · vikix/wifi-fix · 35 min · running · the Wi-Fi picker should scan first`, then Live, Handoff, Next as today; a worker *idle* on a running task says *idle, task open*.
3. **Queue** — `3. high  the guide review  · vikix, desk to make: guide-review · waits: at_once 2 reached`, then *Next: … because …* and a *Start next* button; *Scheduler paused by you* when it is.
4. **Blocked** — `#107 codex · installer tests · blocked on t-… (needs review)`, *worker stopped 2 h ago: exit 1, 3 uncommitted*.
5. **Completed** — the last day's: the task, *released 0.72.26*, *accepted, not yet released*, with its launch number and how long it took against the estimate (`estimate_state`); older ones in the Archive.
6. **Desks** standing empty (today's *Parked*), **Closed**, and the **Archive** as today.

Every state is a word; colour follows it (the attention faces stay) and never carries alone. The provider is named in every row, the launch number too, so two Claude workers are told apart. `s` cycles the sort within Running and Completed: launch order (oldest first, the default), newest first, created, last activity, priority, status, project, provider; the Queue is always in queue order.

**The task's page** (`RET`): the record's metadata in a box (id, origin, created, queued, launched #, provider, priority, dependencies, desk and branch, commit, activity, done), the task's text, the decisions open and answered, the handoff as today (signed), the Git state, the checks, the workers (every launch), the notes waiting, and *History* (`h`): the events, newest first. The acts as buttons, only those that apply, as today. *Go to agent* (`a`) and the desk's terminal stay one key away from every row.

**Keys**, kept: `g a c x C P t i N w A q RET TAB n p`. New: `!` run next, `+`/`-` priority, `M-n`/`M-p` order, `d` defer, `k` cancel, `S` start next, `D` answer the selected decision (a menu of its choices, *other…* for text), `y` accept a review, `b` send it back with a note, `h` history, `s` sort, `1`..`5` jump to a section, `T` new task (the form: text, project, priority, desk or topic, after, the worker's boxes; *queue it* ticked or not, as Vid's rule on forms says: nothing picked by guessing). The frame's own `C-x o` and the forms' `C-c C-c`/`C-c C-k` as they are. The terminal Office (`--tty`) has all of it: nothing here draws anything the text frame can't.

**In a terminal:** `vikix agents` stays the agents' list; `vikix agents tasks` is the board in text, in the same sections, `vikix agents attention` the first section, `vikix agents task TASK` the page, `--json` for all three; the MCP tools `tasks` (READ: the board) and `office` (the snapshot, grown) give them to agents.

**The snapshot** (`vikix agents office --json`, the MCP tool `office`): `version` 2, with `tasks`, `attention`, `queue` (`at_once`, `auto`, `paused`, `order`, `next` with its why, `skipped` with theirs), `sequence`, and `desks` as today, so a script reading `desks` still works. The Emacs view reads the new keys; a desktop whose `vikix-agents-tsv` is older is handled as today.

## How it is built

- **`lib/tasks.py`**: the record (`new`, `load`, `update` under lock, `all_tasks`), `clean` shared with `lib/handoff.py`, the sequence (`next_seq`), the events (`event`, `events_for`), `move` with the transition table, `worker_state`, the decisions (`ask`, `answer`, `open_decisions`), `adopt` for old records, `propose` with the policy.
- **`lib/scheduler.py`**: `world()` (tasks, agents, desks, releases, config), `eligible`, `pick`, `tick`, `launch` with the intent file.
- **`lib/office.py`**: `snapshot` grows `tasks`, `attention`, `queue`; `attention()`; `task_action` for the new acts (`--approve`, `--answer`, `--accept`, `--back`, `--priority`, `--order`, `--start`, `--cancel`, `--new-task`); the forms gain the task's fields.
- **`config/emacs/vikix-office.el`**: the sections, the task's page, the sorting, the keys, the decision menu, the task form.
- **`bin/vikix-agents`**: the arms `task`, `tasks`, `queue`, `ask`, `answer`, `propose`, `attention`, `events`, `exited`; `desk --task`, `worker`, `sit --task`, `resume`, `handoff --task`, `handoff_apply`, `tester_result`, `left`, `close`, `pause_folder`, `go_folder` make or move the task and append the event; the launcher's exit line in `agent_start`; the header's forms and `SECTIONS` (a section *the work*: tasks, the queue, decisions); `ADAPTERS`' three columns; `vikix agents help` by the header, `docs/commands.md` by `lib/man.py --guide`.
- **`bin/vikix-mcp`**: `tasks`, `decision` (READ), `decide`, `propose_task` (ACT), `answer` never (the user's); `handoff_update` unchanged; `office` the grown snapshot.
- **`.claude/release`**: appends `released` (the version) through `python3 lib/tasks.py released COMMON FOLDER VERSION` beside `handoff.py closed`, and runs a tick.
- **`config/stumpwm/vikix/registry.lisp`**: one entry, *Agents: what needs you* (`vikix-agents attention --menu`, the items in a menu, a pick goes to the agent or answers a decision in rofi), under the desks' map as `?`. Nothing else in Lisp: the desktop keeps reading terminals, and the task model lives in files.
- **The skill** (`config/claude/skills/vikix/SKILL.md`: the decision rule; `projects.md`: the commands), `~/.local/share/vikix/AGENTS.md` through `--write-guide`, `docs/agents.md` (a section *The work: tasks, the queue, what needs you*, and the Office's section rewritten), `docs/ai.md`'s providers' table, the man pages, the key list (`lib/skill-keys.sh --write`).
- **A migration** that runs `vikix agents tasks adopt` once and makes the config file with its defaults as comments.
- **The plan runner** (at work on a desk of its own since 2026-10-10) is a client of this: a plan's tasks are task records with `after` and `origin.kind` `automation`, its chains the same-desk rule of `eligible`, its `at-once` bounded by the config's `at_once`, its `gate: me` a task that waits at *ready for release*. Phase 3 shares capacity and launch intents; the plan keeps its own dependency/retry/release state until the full board unifies their presentation. Which of the two ships first decides who adopts whose files; the event log is wanted by both and comes first either way.

## What doesn't change

- The desk is still the place and the agent's address: `handoff`, `handoff_update`, `tell`, `pause`, `go`, `turns`, `test`, `dismiss`, `resume`, `close` keep their shapes; the desk record keeps its fields and gains `task.id`.
- The agent's four handoff words stay; the task's ten states are the Office's reading of them with the user's and Vikix's acts.
- Nothing starts a worker but you, until `auto=on` is in your config, and then only within `at_once`, only tasks you made or approved, only with the rights you gave that task.
- No agent answers another's decision, cancels another's task, or launches a worker; a proposal is a proposal.
- The house rules, the journal, the seats, the tester, the release queue and the agent-waiting plugin stay as they are; the Office reads them.
- A record from before is adopted with its gaps shown as unknown; no history is invented, and no record is deleted but by *Forget* and *Purge* as today.

## Tests

- **`tests/tasks.sh`** (no screen; a made-up home, a repository with worktrees, a stand-in `/proc` as `tests/handoff.sh` has): a task from each way in has an id and its origin; adopted records keep what they had and say *unknown* for the rest; the sequence never repeats across twenty launches at once; every transition in the table, and a refused one; priority against order (a high task behind a critical, a blocked high behind a ready normal); `queue next`, `up`, `down`, `defer`; `after` holds and releases, the same-desk rule; a proposal waits, `--delegate N` lets N through and not N+1, `delegate_max` caps the day; `at_once` holds the third; an intent left by a crash is cleared once and never launched twice (two ticks at once, a tick after a killed launch); a decision registered, answered, delivered through the hook's notes and through `--wait`; a worker's exit line and `left` block the task and keep it; a handoff between providers keeps the id and history; the events have every kind named above; a credential is refused everywhere.
- **`tests/office-ui.py` and `.el`**: the five sections and their rows; an idle worker on a running task shown as *idle, task open*; *uncertain* after `quiet`; the sort orders; the keys; the decision menu; the task form; the terminal Office with the same.
- **`tests/handoff.sh`**: `desk --task`, `worker`, `resume` and the Stop hook with task records present; the adoption of a record written by hand in the old shape.
- **`tests/house.sh`**: the answer delivered by the hook once; the exit line's code in the events.
- **`tests/mcp.sh`**: `tasks`, `decision`, `decide`, `propose_task`; `office` version 2.
- **`tests/release.sh`**: the `released` event and the tick at a release's end.
- **`tests/tester.sh`**: a failed check with the worker gone blocks the task; with the worker there it stays in review and the inbox has the line.
- `tests/changed.sh` maps `lib/tasks.py` and `lib/scheduler.py` to these.

## Order

1. **Task identity and metadata** (`lib/tasks.py`, the records, the sequence, the events, adoption, the exit line; `tasks`, `task`, `events`; the snapshot's `tasks`; the Office showing the launch number and the task's page with its history). The ground the rest stands on, and what the plan runner's desk asked for first. **Recommended first.**
2. **Attention and decisions** implemented 2026-10-14; see the guide and the implementation note above.
3. **Priorities and the scheduler** implemented 2026-10-15, released in 0.72.78; see the implementation note above.
4. **The Office redrawn** (the five sections in full, the sort, the task form, the terminal board, the MCP `tasks`).
5. **Proposals and handoffs between providers** (`propose`, `propose_task`, the policy, parent and child, `resume --use` on a task; the adapters' columns; the two Codex pieces verified where Codex is).
6. **Recovery and the full test run** (the crash tests, the restart tests, the interplay with the tester and the release queue; `bugs.md` for what living with it shows).

Each phase is a release of its own and leaves the Office working as before where its part isn't built.

## Open, for Vid

- Whether `finished` from an agent should ever mean *completed* for a project with no release step (a book's chapter, a note): *decided here* no, the user's *Done* does it; a per-project line could say otherwise.
- Whether a paused worker holds a slot (*decided here*: no).
- The default `at_once` (2 here: the laptop's cores and the tests' slots are the limit that shows first).
- Whether the desks' map gets `?` for the attention menu, or the bar's agent-waiting field opens it on a click.
