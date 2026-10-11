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

How a worker at a desk finishes (the same text is the last paragraph of a
worker's first prompt; `vikix agents handoff` and the hand-in's fields are
in `~/.claude/skills/vikix/ai.md`):

Understand the task and its acceptance criteria; read the handoff and the
project's instructions. Look at the files the task touches before changing
them. Make the change at your desk, on its branch. Run the tests the change
reaches through the project's runner (`tests/run.sh --changed`), fix what
fails, run them again. Update the guides the change makes wrong, in the same
commit. Commit only the files you changed, by name. Write the hand-in: status,
what changed and why, what is decided, what is left, the tests run, the
defects you know of. Hand back through the office (`vikix agents handoff
--status review`); don't merge, release or push unless the task or the house
says so. Ask when something essential is missing or an action would lose data,
open a hole or change the design; decide the routine yourself. If your sandbox
keeps the desk's `.git` or the office's state read-only (Codex's does), run
git, the tests and `vikix` outside it: ask to escalate, and the house's rules
let a desk's day through without a prompt.
