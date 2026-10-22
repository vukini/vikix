# Grok Bot with Vikix — design

Grok Bot (xAI's agent desktop app: Bots on a persistent cloud computer, with your approval for anything on this one) as a correspondent of the Office, and what of it is worth trying on Vid's projects.

Drafted 2026-10-22 with Vid, the day `vikix grok install` shipped (Grok Bot 0.75.0 on the dev machine). Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## What is there already

- **The program.** `vikix grok install` (the feature `grok-bot`): xAI publishes Grok Bot for Linux as a `.deb`, an `.rpm` and an AppImage through Cursor's update server (`api2.cursor.sh/updates/api/download/stable/linux-x64/sand`, no checksum; no Flatpak exists), and Void has the tools for none of them, so the `.deb` is read with Python alone into `~/.local/share/vikix/grok-bot`, with `~/.local/bin/grok-bot` linked and a launcher entry. Install again is the update: unpacked, it can't update itself. `packages/optional/grok-bot.list` carries the libraries. `docs/ai.md`, "Grok Bot handoffs", has the by-hand recipe for a plain Void.
- **The handoff.** `vikix grok`: a private queue (`~/.local/share/vikix/grok/tasks.db`) of briefs you choose; the task's prompt is pasted into Grok Bot; Grok runs `vikix grok claim ID` and `vikix grok result ID --file -` on this computer through its own approval card; the result (summary, sources, artifacts, questions; nothing is fetched or run) waits in `review` until you `accept`. Super+m → AI has *Grok Bot: open* and *Grok Bot: list tasks*.

## What Grok Bot is, and what that fixes

It has no CLI, no task API and no hooks, and a Bot starts from a prompt you paste or a routine you made in the app. So:

- **It is never a worker** the Office launches at a desk. It is a correspondent: things go to it, things come back, and the step in between is yours. The paste is also where you decide what leaves the machine.
- **The house rules don't reach it.** They hold through hooks, and a command Grok runs here passes only through its approval card. The guide's line stands: *Execution on Local Computer* at **Ask every time**, **Never allow** until there is a reason. Nothing below fences it; nothing below pretends to.
- **It keeps files.** Its cloud computer is persistent and shared by all your Bots (`/workspace`, browser sessions, logins). Vid's books are private: a question travels, never a manuscript.

## The integration, in five steps

Each step stands alone and is small; the first two make one desk, the next two another.

**1. See it on the board.** `lib/office.py` reads `tasks.db` read-only (`vikix grok list --json` is the shape) and shows each Grok task as a row of the board with a kind of its own; a task in `review` is an item of *Needs attention*, and `y` accepts it there as it accepts a worker's review (`vikix grok accept`). The Grok Bot window joins `vikix agents` by its window class, its state unknown (it writes no mark in its title). Tests: `office`, `office-ui`, `tasks`, `grok`.

**2. The results become records.** An accepted result goes into the record store (`vikix records add`: plugin `grok`, kind `result`, key the task id, the summary as body, the links in data). Then any agent finds it through `records_search`, and `vikix day` can say what Grok answered. The queue stays a queue. Tests: `grok`, `records`.

**3. Workers ask, you carry.** Two MCP tools in `bin/vikix-mcp`: `grok_brief` (creates a queued task, sends nothing, as `new` does; the brief and a project label) and `grok_result` (an accepted result by id, read-only). A worker at a desk that needs research writes the brief and goes on; its handoff names the task id. On your side one menu entry, *Grok: hand over the next brief* (`registry.lisp`, AI; no key: the card is full), copies the oldest queued task's prompt to the clipboard and focuses Grok Bot's window; a notification says what is waiting. Tests: `mcp`, `grok`, `registry`, `agents`.

**4. A skill instead of a long prompt.** Grok Bot has skills (a reusable set of instructions, a library shared by all your Bots, `/` in the composer). `vikix grok instructions` is already the protocol text; `vikix grok skill` prints it in the shape a skill takes, and the guide says where to paste it once. Every prompt then shrinks to the task id and title. Tests: `grok`.

**5. The desktop, as for any program.** A `what` page for its window (`config/what/`), and a `grok-bot` example in the starter `rules.lisp` (`when-window (:class ...) (workspace N)`), since it opens a new window. Small; the class is read from the running window first.

Left out on purpose: fencing its local execution (above); a `vikix doctor` warning on an *Always allow* setting, worth it only if its settings file turns out readable, unchecked; Grok Bot as a provider of `vikix agent` (no CLI).

## Trials: what it has that Vikix hasn't

Each is a brief or a routine, with nothing of Vid's on the cloud computer. What is learned goes back here as a dated note, or into `TODO.md`.

1. **A routine for `desktop-upstream`.** Its first review is due 2026-11-22: the Void baseline and actionable system developments. A Bot on a monthly schedule reads Void's package changes, StumpWM, the kernel and the agents' releases, and returns a brief with links. The laptop may be closed. Tells whether a routine's brief is worth more than a cron job's.
2. **The Sources check** of `living-series-infra`: the open questions in its log (binary search 1962 or 1960, Shannon 1937 or 1940, the IBM 704 year, the SQL transcripts' SQLite version) as one brief each, a source-linked answer back through `vikix grok result`. The first real use of the handoff; the questions travel, the books don't.
3. **The X digest.** The X plugin reads your bookmarks, timeline and DMs. A weekly routine: what people said about Void, StumpWM, Omarchy and agent desktops, and which questions Vikix could answer. The distribution work for vikix.dev that nothing here does.
4. **The morning brief as a routine** (TODO 100, `DESIGN-accelerators.md`): a Bot reads Vikix's GitHub issues and the week's commits and writes the brief; a GitHub notification can start a routine. A cheap way to learn what a brief should hold before Vikix builds one.
5. **A group chat** of two Bots, a researcher and a reviewer, on one Sources question. The Office has desks, but agents never message each other; this shows what asynchronous handoffs with a visible owner look like.
6. **Teach a task.** A browser workflow recorded into a skill (up to ten minutes). Try it on something repeated, such as checking an EPUB's rendering on a reader site.
7. **The phone.** A brief dictated into the mobile app, picked up on the desktop; `vikix grok` is the receiving end.

Not for it: `budanth` (private credentials and costs), Vikix's own code (the desks do it better, and its cloud computer isn't Void), anything that needs this machine.

## Open questions

- Grok Bot's settings file: readable, and does it hold the local-execution policy? Decides the doctor line.
- The window class of its window, for step 1 and step 5.
- Whether a routine can run `vikix grok result` on this computer when the desktop app is closed (expected: no; the result then stays in the chat until the app is open).
