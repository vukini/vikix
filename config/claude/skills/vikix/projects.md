# Vikix: projects

A page of the Vikix skill (~/.claude/skills/vikix/SKILL.md: read that first, its rules hold here). The user's projects and their logs, and what was done on a day.

The user's projects are the folders under `~/src` (two levels down) with a
`log.md`: newest entry first, `## YYYY-MM-DD · status words`, the body, an
optional `Next: ...` line; above the entries an optional `**Status**`
paragraph (`..., as of DATE: N% complete.`, then `- Standing:`, `- Next:`,
`- Build:`, `- Check:` lines). A collection's folders are projects too
(`living-series/living-in-lambda`); a public repo with no log.md of its own
has it in `~/src/project-logs/NAME/log.md`. Git worktrees are skipped.

- `vikix project` lists them (most recently logged first, % done, next
  step); `show NAME` gives the Status and the last three entries: read it
  before working on a project. `path NAME` is the folder; names may be
  any unique part (`lambda`).
- **At the end of a session that changed a project**, add one entry:
  `vikix project log NAME "what was done, in a sentence or three" --next "the next step" [--status "few words"]`.
  Run from Claude Code (or with `--agent`) it is the agent's entry,
  unmarked; the user's own are marked `(Vid)`. It goes just above the
  newest entry, into the right file (the one kept apart too), and is not
  committed: commit it with the project's other changes when you commit
  those, never on your own. Don't edit older entries or the Status unless asked.
- `vikix project build NAME` runs the project's build in its folder (the
  log's `- Build:` line, else build.sh, Makefile, src/build.sh,
  package.json; `-n` only says which) and passes on its exit status.
- `vikix project check NAME` runs its checks the same way (the log's
  `- Check:` line, else check.sh, check, tests/run.sh, test.sh, make
  check/test, npm test).
- `vikix project new NAME` makes a project (`~/src/NAME` and its log.md;
  `--in COLLECTION`, `--log-apart` for a public repo's log, `.` for the
  current folder): use it, don't write a new log by hand. Alone it never
  commits; `--git` makes it a repository (README, log, one commit) and
  `--github public|private` makes it on GitHub with gh and pushes once
  through gh's login: only when the user asked for a repository.
- `vikix today [yesterday|DATE]`: what was done that day across all
  projects (log entries and commits) and what's next; a good first read
  when the user asks where they were.
- `vikix day [yesterday|DATE]`: the day as the desktop saw it, kept as
  `~/journal/DATE.org` (the user's diary, private: read it when asked what
  they did, never send it anywhere): how long each project had the screen
  (noted every 30 seconds in `~/.local/state/vikix/day/`, by workspace,
  project, program and folder, never a title), its entries and commits,
  Esploro's changes, agents' sessions, the rules that ran. `--no-file`
  only prints; `--week` the last seven days; `--for NAME` one project.
  "What did I do on Tuesday": `vikix day DATE --no-file`. `vikix day log`
  offers the user the log entries a day still lacks, each written on
  their yes: it's theirs to run, in a terminal.
- Where was I: `vikix back` (bin/vikix-back) prints how long the user was away, the project they were on (or the one before a terminal in ~) with its next step and last commit, Emacs's unsaved files, their last commands there and the last inbox note; `--card` is the notification the desktop shows by itself after ten minutes away (`*vikix-back-after*`, day.lisp). Read-only.
- `vikix project open NAME` puts the project on a workspace of its own (the one it has still, else the first empty one of the nine, else a new one named for the project: groups.lisp's `vikix-workspace-claim`; Super+0 goes to a workspace by name), opens a terminal there and the log in Emacs, and once they've come puts its saved layout back (`project-NAME`, a collection's `/` as `--`; saved when you leave that workspace, or by `vikix project save [NAME]`). Saved windows that aren't open are started again and placed.
- Super+Alt+p a project (vikix-project pick: rofi, then a terminal in its folder and its log.md in Emacs).

## A worker's day

How a worker at a desk finishes, a step a row (the same table ends a
worker's first prompt; `vikix agents handoff` and the hand-in's fields are
in `~/.claude/skills/vikix/ai.md`):

| Step       | What |
|------------|------|
| Understand | the task and its acceptance criteria; read the handoff and the project's instructions. |
| Estimate   | once you know the shape of the work, say how long it will take, assuming no major issue turns up: `vikix agents handoff --status working --estimate "40 min"`, or the MCP tool `handoff_update`. |
| Look       | at the files the task touches before changing them. |
| Change     | at your desk, on its branch. |
| Test       | the tests the change reaches, through the project's runner (`tests/run.sh --changed`); fix what fails, run them again. When the map picks the whole set, say so and what the alternative costs before running; a run at a desk is recorded, so neither the tester nor the release runs it again. |
| Guides     | update the ones the change makes wrong, in the same commit. |
| Commit     | only the files you changed, by name. |
| Hand-in    | status, what changed and why, what is decided, what is left, the tests run, the defects you know of. |
| Hand back  | through the office (`vikix agents handoff --status review`); don't merge, release or push unless the task or the house says so. |
| Ask        | when something essential is missing, or an action would lose data, open a hole or change the design; decide the routine yourself. A repair (something put back on the desktop) is done and reported first; a change that would make Vikix do it by itself is offered as a question, with its test cost. |
| Sandbox    | if yours keeps the desk's `.git` or the office's state read-only (Codex's does), run git, the tests and `vikix` outside it: ask to escalate; the house's rules let a desk's day through without a prompt. |

Your task has a record of its own, apart from the desk and from you
(`~/.local/state/vikix/office/tasks/ID.json`; the user's guide: *The work:
tasks and their history* in `docs/agents.md`): an id for life
(`t-20261014-0d2c16`), who made it, its priority, the number of each launch
(the order the office started the workers in; none for an agent the office
never started), and a state that moves only by a named step, your handoff's
words among them (working is *running*, waiting *needs decision*, review
*needs review*, finished *ready for release*; the user completes it by
releasing). What you may run, all of it read-only:

- `vikix agents tasks` (or the MCP tool `tasks`): every task, the open ones
  in launch order, `#?` for one adopted from before the records.
- `vikix agents task ID` (or your desk's name): one task's page, with its
  history; *unknown* is a fact the record never had, never a guess.
- `vikix agents events [ID | DESK | --all] [--since 2h]`: the office's log,
  newest first, every step of every task; your desk's when nothing is named.

Nothing of yours moves another agent's task: a task moves by its own
worker's handoff, by the user, by the tester, by the release or by its
worker's exit. `vikix agents tasks adopt` is the user's, run once by an update.

## Questions and attention

`vikix agents attention` lists what needs the user, in priority order;
`--json` gives the same items as the Office. Super+Alt+d then `?` opens
its menu. The Office puts these items above the desks, with waiting time
when its source supplied one (otherwise *time unknown*).

A worker registers a question on its own task:

```sh
vikix agents ask "Keep the old order?" --choice "keep: compatible" --choice "drop: simpler" --recommend keep --reason "Existing scripts use it" --blocks
vikix agents ask --wait d-20261014-abcdef
```

`--context` adds background, `--blocks` moves the task to *needs decision*;
omit it to keep working on independent parts. Waiting is bounded by
`VIKIX_ASK_LIMIT` (seconds, at most 600), and exits 3 if unanswered.
MCP `decide` registers, `decision` reads. Only the user answers, in the
Office or with `vikix agents answer ID TEXT`. Never answer for them.
Answers reach the task's inbox and remain in its decision record; handoff
and resume show them even after delivery. One answer leaves other blocking
questions open. Answering a stopped worker's question does not launch it.

## Task queue

`vikix agents queue` (or `queue --json`) reads priority, position, the next
eligible task and every blocker; the Office snapshot has the same `queue`.
Reading never launches. Only the user changes priorities or the queue,
cancels tasks, or starts its workers. Do not run those acts for another
worker. Automatic starts require the user's `auto=on` in the Office config;
`at_once=2` by default, shared with plan workers. Paused workers do not take
a slot. The user may explicitly `queue bump TASK --over DESK`; the scheduler
never preempts on its own. An ambiguous launch is blocked, never retried
by guessing. The guide's “Priorities and the task queue” has the commands.
