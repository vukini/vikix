# The Office as a task board — design

The Office shows agents; it should show the work. A task of its own, apart from the agent doing it and the desk it is done at, with a state that is the work's and not the worker's; what needs you, in one list, with the question itself; a queue with priorities and an order, and a scheduler that starts the next task only when you let it; the order the workers were launched in, kept; and a history of every task that outlives it.

Drafted 2026-10-10 for TODO item 115, from Vid's brief ("Office task management, priorities and ergonomics"). Nothing here is built. Kept like the other designs: what ships is deleted from it, what changes is dated. Where the brief left a choice open, the choice made is marked *decided here*, for Vid to overturn.

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

## The task record

```
office/tasks/t-20261010-7f3a9c.json         one a task; the id is the day it was made and six hex digits
{
 "version": 1,
 "id": "t-20261010-7f3a9c",
 "title": "the Wi-Fi picker should scan first",        first line of the text, 80 characters at most
 "text": "the Wi-Fi picker should scan first, then show the list",
 "project": "vikix",
 "desk": {"id": "3f9a1c2b7d4e", "worktree": "/home/vid/src/vikix-wifi-fix", "branch": "wifi-fix"},   or {} while none
 "topic": "wifi-fix",                                   the desk to make when none is set and the task is launched
 "origin": {"kind": "user", "by": "user", "parent": null, "worker": null, "approved": {"by": "user", "at": ...}},
 "priority": "normal",                                  critical | high | normal | low
 "status": {"value": "running", "by": "vikix", "at": ..., "reason": ""},
 "blocked": {},                                         {"on": "t-…" | "worker" | "tests" | "release" | "decision …", "why": "..."} while blocked
 "after": ["t-20261009-11ab2c"],                        the tasks this one builds on
 "worker": {"use": "claude", "local": false, "push": false, "no_tests": false},    the choices as the forms have them
 "launch": {"seq": 104, "at": ..., "by": "user", "provider": "claude", "pid": 48213, "start": "123456"},   the last launch; {} before one
 "launches": [...],                                     every launch, oldest first (seq, at, provider, ended, how)
 "created": ..., "queued": ..., "launched": ..., "activity": ..., "done": ...,     epoch seconds, null until it happened
 "handoff": {... as the desk record keeps it ...},      a copy at each write, so the history has the agent's words
 "decisions": ["d-…"],
 "children": ["t-…"],
 "log": [{"at": ..., "by": ..., "what": "..."}]         the last forty; the whole history is the event log
}
```

Rules, the same as the desk record's (`lib/handoff.py`): a write takes the file's lock, reads, changes, replaces; every text goes through `clean` (no control characters, capped, never a credential); `by` is `user`, `vikix`, or an agent as `claude 48213`; an unknown key is refused. A task's `handoff` is written by the same `handoff_apply` that writes the desk's, so the agent's commands and MCP tools don't change: the desk is the agent's address, the task is what it is working on there.

**Where the pieces live.** `lib/tasks.py` (the records, the sequence, the events, the transitions, the decisions), `lib/scheduler.py` (eligibility, capacity, the tick), with arms in `bin/vikix-agents` that parse and print, as `lib/office.py` is used today. New code goes in the libraries rather than the 3,400-line command (TODO item 112).

**The launch sequence** is one file, `office/sequence`, a number, taken under `flock` and written back plus one at each launch; it never goes down, and a record made before this design has `launch.seq` null, shown as *launch order unknown*, never a made-up number.

**Older records are adopted, not rewritten.** The first snapshot after the update (and `vikix agents tasks adopt`, run by a migration) makes a task record for each desk record's `task` (the id written back into the desk record as `task.id`) and for each entry of its `workers` history: `created` from the entry's `at`, `done` from `ended`, `origin.kind` `user` when `by` is `user`, else `unknown`; `launch` empty; `priority` normal; `status` from the entry's handoff status by the table below, `cancelled` for a history entry with no status. What isn't known is null and shown as *unknown*. Nothing is invented.

**Identity through handoffs.** A task is handed from one worker to the next on the same record: `resume`, `worker` at a desk whose task is open, and a change of provider (`--use codex` at `resume`) add a launch to `launches` and keep the id, the decisions and the history. `vikix agents worker DESK "new task"` makes a new task and *completes or cancels the old one explicitly* (it asks, in the terminal and in the form: done, cancelled, or kept open at the desk's back, `blocked on worker`), instead of folding it silently.

## Two states, kept apart

**The worker's state** is derived at each snapshot by `worker_state(agent, task)` in `lib/tasks.py`, as a triple: the state, where it was read, and how sure (*reliable*, *inferred*, *unknown*).

| Worker state | Read from | Sure? |
|---|---|---|
| starting | a launch intent with no process yet (`office/launching/TASK`, below), under 30 s old | reliable |
| running | `:working` (Claude Code's turning mark), `:running` (no mark) | inferred |
| waiting for permission | the plugin's `ask` note, Claude Code's PermissionRequest; Codex's `[ ! ] Action Required` title | reliable; the title inferred |
| waiting for input | the plugin's `reply` note (a question in its last words), its `question` note (AskUserQuestion) | reliable |
| idle | `:idle` (the star at its prompt), the plugin's `done` note | reliable for Claude Code, inferred from the mark alone |
| paused | `office/pause/ID` stands | reliable |
| held | `waits`: a test slot, a release's turn | reliable |
| exited | the launcher's exit line (below), or SessionEnd (`left`), or the process gone | reliable with the line, inferred from the process alone |
| failed | the launcher's exit line with a code other than 0, or a process gone within 60 s of its launch | reliable; inferred for the 60 s rule |

What makes *exited* and *failed* reliable for every provider, hooks or not: the terminal a worker is started in (`open_at`, `agent_start`) runs `vikix agent ...; vikix agents exited --code $?` rather than the agent alone, so the exit code reaches the task's events whatever the provider; Aider and Gemini, which have no SessionEnd hook, are covered the same way. For an agent started by hand in a terminal the process alone says it.

**The task's state** is recorded in the task's `status`, and changed only by a transition in the table; `lib/tasks.py`'s `move(task, to, by, reason)` refuses any other. Every transition is an event (below).

| From | To | By what |
|---|---|---|
| (new) | backlog | an agent's proposal (`propose`), a task written with `--later` |
| (new) | ready | the user makes a task (the forms, `desk --task`, `worker`, `task new`) |
| backlog | ready | the user approves it (the Office's *Approve*, `task approve`) |
| ready | queued | the user queues it (`queue add`, the form's *queue it*); `auto=on` queues a ready task that has a desk or a topic |
| queued, ready | running | a launch (`queue start`, `worker`, `resume`, `desk --task`, the tick under `auto`) |
| running | needs decision | the worker registers a blocking decision (`ask --blocks`); the agent's handoff status `waiting` |
| running | needs review | the agent's handoff status `review` |
| running | blocked | the launcher's exit line or `left` while the task was running (`blocked on worker`: *the worker stopped*); the tester's check failed and the worker is gone; a dependency came back open |
| needs decision | running | the decision is answered (`answer`); the handoff status back to `working` |
| needs review | running | the tester's check failed with the worker still there (it reads the inbox and goes on); the user sends it back (*Back to work*, with a note) |
| needs review | ready for release | the user accepts (*Accept*), or the agent's handoff status `finished` with the branch not yet in the project's own |
| ready for release, needs review | completed | the release that closes the desk (`.claude/release`'s `closed`), or the branch seen merged (`desk_state`) with the user's *Done* |
| blocked | ready | the cause is gone: the dependency done, the user's *Retry*; `resume` on a task blocked on its worker puts it to running |
| any but completed | cancelled | the user (`task cancel`, `k`); a cancelled parent cancels its backlog children with a note, never a running one |
| completed, cancelled | (none) | final; a new task is made instead |

The agent's own four words (`working`, `waiting`, `review`, `finished`, `STATES` in `lib/handoff.py`) stay the agent's vocabulary and map into the table, so no skill page, no hook and no MCP tool changes its shape. *Decided here:* `finished` from the agent means *ready for release*, never *completed*: the agent's work is done, yours is not, which is the distinction between an idle worker and an unfinished task that the brief asks for. A worker's exit never completes or cancels anything: the task goes to *blocked on worker* and stays in view until you resume it, hand it to another provider or cancel it.

## The events

`office/events-YYYY-MM.jsonl`, one line an event, appended under `flock`, one file a month (as `vikix day`'s screen log is kept), read newest first by `vikix agents events [TASK | DESK | --all] [--since WHEN]`, shown as a task's *History* page in the Office. Never rewritten; `vikix memory` (TODO item 96) may bound it later.

```
{"at": 1760090000, "seq": 104, "task": "t-20261010-7f3a9c", "desk": "3f9a1c2b7d4e", "kind": "launched", "by": "user",
 "data": {"provider": "claude", "pid": 48213, "how": "queue start"}}
```

Kinds: `created`, `approved`, `priority` (from, to), `ordered` (position), `queued`, `deferred`, `launched` (the sequence number is given here and nowhere else), `paused`, `resumed`, `asked` (a decision registered), `answered`, `handoff` (status, by), `tests started`, `tests done` (ok, names), `review asked`, `accepted`, `sent back`, `blocked` (on, why), `unblocked`, `exited` (code, reason), `handed off` (provider from, to), `released` (version), `completed`, `cancelled`, `proposed` (by which worker, parent), `uncertain` (first seen), `adopted` (an old record taken in, with what was unknown). Each writer of state already in the code (`handoff_apply`, `tester_result`, `left`, `pause_folder`, `go_folder`, `close`, `lib/handoff.py closed` from the release) gains one line that appends its event; the plan runner's desk (2026-10-10) asked for this log first, and reads the same file.

## Needs attention

`attention(snapshot)` in `lib/office.py` makes the list from the tasks, the agents and the notes, each item:

```
{"kind": "decision", "task": "t-…", "title": "the Wi-Fi picker…", "project": "vikix", "desk": "wifi-fix",
 "worker": "claude 48213", "provider": "claude", "since": 1760090000, "seq": 104,
 "why": "asks: keep the old order under --no-scan, or drop it?",
 "question": {...the decision...}, "actions": ["answer", "go", "tell"]}
```

| Kind | Raised by | The line says | Acts |
|---|---|---|---|
| decision | a registered decision without an answer | the question, the recommended choice | Answer…, Go to agent |
| question | the plugin's `reply` or `question` note with no decision registered (inferred) | the line it said | Go to agent, Register as decision… |
| permission | the plugin's `ask` note; Codex's title | *waits for your yes* | Go to agent |
| tests failed | the newest check failed and is fresh, and the worker is idle or gone | the failing tests' names, the first line | Go to agent, Test again, Tell… |
| review | task *needs review*, its tests passed or off | the handoff's next step | Accept, Back to work…, Diff (the Git state) |
| release | task *ready for release*; a terminal in `gup` or `close` attention | *release it*, *gup*, *close the terminal* | Release… (runs `.claude/release` in a terminal), Go to agent |
| release stopped | a release note whose state says refused or stopped (`.claude/release` writes it: a rebase that conflicts, main behind origin) | the note's line | Go to agent, Release again… |
| clash | the journal's `asked` or `waiting` entries (two workers on one file; the deadlock of turns) | the file, both workers | Go to agent, Turns on/off |
| proposed | a task in *backlog* with `origin.kind` `agent` | who proposed it, under which parent | Approve, Cancel, Edit… |
| worker stopped | task *blocked on worker* | how it left (`left.reason`, the exit code), files uncommitted then | Resume…, Hand to…, Cancel |
| blocked by task | task *blocked* on another | which, and that one's state | Go to that task |
| uncertain | a *running* task whose worker's state is inferred or unknown and nothing has come from it (no event, no journal edit, no title change) for `quiet` minutes (20, `~/.config/vikix/office`) | *no sign from codex for 25 min* | Go to agent, Tell… |
| discovery unavailable | `live_known` false | the error | Refresh |

An idle terminal is never an item by itself, and never counts as done. When the snapshot cannot tell (discovery unavailable, a provider with no hook and no mark), the item says *status uncertain* and the row's worker column says *unknown*, as `live_known` does today. Items are ordered: decisions and permissions first (the worker stands still), then stopped workers, failed tests, clashes, reviews, releases, proposals, uncertain. `since` is the event that raised it (the note's time, the decision's `at`, the check's, the status change), so *waiting 25 min* is true. A desktop notification is sent once per item when it is raised (the report `status_told` already sends for a status; it moves here and covers the other kinds), never again while it stands.

`vikix agents attention` prints the same list in a terminal; the bar's agent-waiting field keeps its one-line note (that plugin stays the detector; the Office reads its notes).

## Decisions

A worker that needs a choice registers it, and the Office shows it where you look:

```sh
vikix agents ask "Keep the old order under --no-scan?" \
  --choice "keep: --no-scan stays, one more test" --choice "drop: simpler, a user of it would notice" \
  --recommend keep --context "docs/wifi.md names --no-scan" --blocks
# prints: decision d-20261010-2b9c41 registered; vikix agents ask --wait d-20261010-2b9c41 waits for the answer
vikix agents ask --wait d-20261010-2b9c41          # blocks up to 10 min (VIKIX_ASK_LIMIT), prints the answer, exit 3 when none yet
vikix agents answer d-20261010-2b9c41 keep          # the user; or free text; or from the Office
```

`office/decisions/d-…json`: id, task, desk, by (the worker), question, context, choices (label, consequence), recommended (with the agent's reason), blocks, at, and once given `answer` {choice or text, by, at, delivered at}. A decision with `--blocks` moves its task to *needs decision*; one without leaves the task running and is an item all the same. The MCP tools: `decide` (ACT: the same fields; the answer comes back through the inbox or a later `decision` call), `decision` (READ: one decision's state, so a worker can poll it). Texts go through `clean`; ten open decisions a task at most.

**Delivery.** The answer is written into the decision and into the desk's inbox as a note `[decision d-… answered by user: keep]`; Claude Code's hook hands it over at the next tool call (`notes_for_hook`), and a worker waiting in `ask --wait` gets it the moment the file changes (it polls the file every two seconds; a hook-less provider has this road alone). `handoff` and `resume` read open decisions and answers out, as they read notes. Nothing types into the window.

**The fallback**, for a worker that asks in prose and for providers that can't run the command: the agent-waiting plugin's `reply` note is the item, kind *question*, with the line it said and a *Register as decision…* act that makes the record for it, so the answer can be delivered the same way. Where there is neither a note nor a mark (Aider; Gemini CLI until tried), the task shows *uncertain* after `quiet` minutes, and the words say to look at its window. The skill's first page gains one rule: *a question the user must answer goes through `vikix agents ask` (or the tool `decide`), not only your last message*; the Stop hook's reminder (`stopping`) adds the same sentence when the turn ended with a question mark in its last line, which is a nudge, not detection.

## Priority, order and the queue

Priority is the task's (`priority`, one of four); order is the queue's (`office/queue.json`: `{"version": 1, "order": ["t-…", ...]}`, under `flock`), the tasks in *queued* in the order they run, within each priority. The two are kept apart: a high task may stand behind a critical one and be blocked while a normal one is ready, and the scheduler says so.

```sh
vikix agents queue                       # the queue: position, priority, task, desk, what holds it; then: next, and why
vikix agents queue add TASK [--first]    # ready → queued, at the end (or the head) of its priority
vikix agents queue next TASK             # to the head of the queue, whatever its priority: "run next"
vikix agents queue up|down TASK          # one place within its priority
vikix agents queue defer TASK            # queued → ready (or backlog with --later), its order forgotten
vikix agents task priority TASK critical|high|normal|low
vikix agents task cancel TASK ["why"]
vikix agents queue start [TASK]          # launch the next eligible task now (or TASK, if eligible), one
vikix agents queue pause|go              # the scheduler held, by you; shown in the Office
```

In the Office, on the selected task: `!` run next, `+`/`-` priority up and down, `M-n`/`M-p` move down and up, `d` defer, `k` cancel, `S` start it. Drag and drop: Emacs's text buffers have no decent drag of a row, and the mouse picks a row already; *decided here*: not offered, and said so, rather than half done. A task is paused or resumed through its worker (`P`, as today): a pause is the worker's, not the queue's.

## The scheduler

`lib/scheduler.py`: `eligible(task, world)` and `tick(world, launch=False)`. A task is eligible when it is *queued*; every task in `after` is *completed* (or *ready for release* when the two share a desk: the next builds on the branch's commits); its desk, when it has one, stands, has nobody at it, is not paused, and has no release under way on its branch (the release notes `release_queue` reads); its provider is installed (`agents_offered`); it is approved (`origin.approved`; a user's task is approved as made); and `at_once` is not reached, counting the workers running now (agents at desks with a task in *running* or *needs review* and not paused; a paused worker holds its context, not a slot, *decided here*). The pick is the first eligible in priority order, then queue order, then `created`. `tick` prints the pick with why, and every skipped task with why (*blocked by t-…*, *its desk has claude 48213 at it*, *at_once 2 reached*, *waits for your approval*); the Office shows the same under the Queue box: *Next: … because …*.

**Starting.** `launch(task)` writes the intent `office/launching/TASK` (the sequence number taken now, the time, this pid) before anything else, makes the desk when the task has a topic and no desk (`desk PROJECT TOPIC`, as the form does), starts the worker through `worker_at` with the task's own worker choices and nothing more (an auto launch never adds `--push` or `--local` the user didn't set on that task), moves the task to *running* with the launch, appends `launched`, and removes the intent. A `tick` that finds an intent younger than two minutes skips that task; one older, with no agent at the desk and no launch recorded, is cleared with an event `launch failed` and the task goes to *blocked on worker*. Two ticks at once are serialised by `office/queue.lock`; a tick that can't get the lock in a second does nothing and says so. This is what keeps a crash or a restart from launching twice.

**When it runs.** By hand (`queue start`, the Office's *Start next*), and as a detached script (as `tester_start` runs the tester) after each event that frees a slot or unblocks a task: a worker's exit (`exited`, `left`), a status coming to review or finished (`handoff_apply`), a release's `closed`, a desk closed, an answer given, a task cancelled or completed. Without `auto=on` the detached tick only recomputes and notifies once when something new became eligible (*the queue has a task ready to start*); with it, the tick launches up to the free slots. Nothing runs from StumpWM's thread, and the Office's ten-second refresh runs no tick.

**Config**, `~/.config/vikix/office`, `key=value` lines (read by `read_list`'s Python twin; TODO item 102 would fold it into the manifest): `at_once=2`, `auto=off`, `quiet=20`, `delegate=ask`, `delegate_max=3`. Defaults when the file is missing. `auto` off is the rule: the brief and the house rules both say nothing starts a worker but you until you say otherwise.

**Preemption is an act, never the scheduler's.** `vikix agents queue bump TASK --over DESK` pauses the worker at DESK through the hook (its context whole), moves that desk's task to *blocked: paused for TASK*, and starts TASK at a fresh desk (never at the paused one: one worktree, one `git status`); `go` on the paused desk lifts the block. The scheduler itself never pauses, dismisses or signals anything because a higher task arrived.

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
| codex | its notify setting (the plugin's `codex` command: a turn ended, and by its docs an approval or a question), the `Action Required` title; its PreToolUse hook unverified (`config/codex/hooks.json`, Codex 0.160) | `ask --wait` from its shell; `decide` once `vikix mcp` is given to it | the launcher's line |
| opencode | its plugin (`config/opencode/vikix-office.js`: a clash only) | `ask --wait` | the launcher's line |
| gemini, antigravity | Antigravity's plugin (the house rules); no state | `ask --wait` | the launcher's line |
| aider | nothing | `ask --wait` | the launcher's line |

So Codex and Claude Code share the record, the queue, the attention list and the history today; what Codex lacks is reliable *idle* and *waiting for input* (its notify says a turn ended; the plugin writes `done` or `reply` from its last message) and the answer carried into its context by a hook. The two Codex pieces to verify on a machine that has it, each a line in `tests/handoff.sh` when done: the hooks file's shape, and `vikix mcp` under Codex (`codex mcp add`), which would give it `decide`, `decision` and `handoff_update` as Claude Code has them. There is no Codex-integration item in `TODO.md` at this writing (2026-10-10; the Codex items are 12, the cloud model, 37, agent-waiting, and 99, files reserved); when one is written, this table is its list for the office's side, and the adapter columns are where it lands. A handoff between providers (`resume --use codex` on Claude Code's task) keeps the task id, the decisions, the launches and the history, and appends `handed off`.

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
- **The plan runner** (at work on a desk of its own since 2026-10-10) is a client of this: a plan's tasks are task records with `after` and `origin.kind` `automation`, its chains the same-desk rule of `eligible`, its `at-once` the config's `at_once`, its `gate: me` a task that waits at *ready for release*, and its state the records and the events rather than a store of its own. Which of the two ships first decides who adopts whose files; the event log is wanted by both and comes first either way.

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
2. **Attention and decisions** (`attention()`, `ask`, `answer`, `decide`, `decision`, the delivery, the fallback, the *uncertain* rule, the Needs attention box, the notification per item, the skill's rule). The most visible change, and the one that answers the brief's first sentence.
3. **Priorities and the scheduler** (`priority`, the queue file, `queue`, `lib/scheduler.py`, the config, the intent, `auto`, `bump`; the Queue and Blocked boxes, the keys).
4. **The Office redrawn** (the five sections in full, the sort, the task form, the terminal board, the MCP `tasks`).
5. **Proposals and handoffs between providers** (`propose`, `propose_task`, the policy, parent and child, `resume --use` on a task; the adapters' columns; the two Codex pieces verified where Codex is).
6. **Recovery and the full test run** (the crash tests, the restart tests, the interplay with the tester and the release queue; `bugs.md` for what living with it shows).

Each phase is a release of its own and leaves the Office working as before where its part isn't built.

## Open, for Vid

- Whether `finished` from an agent should ever mean *completed* for a project with no release step (a book's chapter, a note): *decided here* no, the user's *Done* does it; a per-project line could say otherwise.
- Whether a paused worker holds a slot (*decided here*: no).
- The default `at_once` (2 here: the laptop's cores and the tests' slots are the limit that shows first).
- Whether the desks' map gets `?` for the attention menu, or the bar's agent-waiting field opens it on a click.
