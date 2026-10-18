# Vikix Accelerators — design

A shorter loop from an idea to a shipped release, run hands-off, so Vid steps in only for decisions.

Drafted 2026-10-18 from Groki's handover (its "Productivity accelerators"), after the 0.72.97 release night; not yet checked on the machine. For Vid alone: no outside users yet. Build 1 to 3 first, together: they take away the release night's failure (releases stalled, agents silent, nobody trying again). They build on `DESIGN-ci.md` items 3 and 4 and on `DESIGN-dependable.md` item 11. The notes marked *2026-10-18* are what Vikix already has, from the code. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

1. **A desk on one key.** A StumpWM key asks for a topic, makes the desk `~/src/vikix-TOPIC`, opens the editor and a shell there, and starts Claude with `CLAUDE.md` and the `AGENTS.md` files loaded. A second key runs `.claude/release` for the desk in front. *2026-10-18:* `vikix agents desk` (Super+m, AI) does the first half without a key, since the key card is full; the desks' map, `Super+Alt+d`, may be where both keys go.
2. **A release queue that runs itself.** Finished desks join a queue that releases when the load is low. It tries a flaky test once more (logged to `flakes.jsonl`, `DESIGN-ci.md` item 3), runs under `env -u ANTHROPIC_API_KEY`, and pushes the branch and the tag by name (the tags are lightweight, so `--follow-tags` misses them). It reports the result and never stalls silently overnight. (Beside the task scheduler, TODO 115, which already starts work on Vid's word.)
3. **The morning brief** (TODO 100, `vikix brief`, with more in it): what shipped overnight, the failures with excerpts of their logs, CI's state for each job, desks waiting for review, open `vikix agents ask` questions, and the machine's load through the night.
4. **The Office's inbox as a popup.** Every agent's question and every review in one StumpWM menu, answered with one key (approve, reject, reply). Only Vid answers `vikix agents ask`, and the popup keeps it so. *2026-10-18:* `vikix agents attention --menu` (the desks' map's `?`) is the start of it.
5. **A bug caught from anywhere.** One key takes the window in front and its title, the recent logs, the `vikix` version and the git state, then files a TODO or opens a desk with a draft fix. (Elsewhere Vikix writes a window's title nowhere, `vikix what` and `vikix used` included; this one stays on the machine.)
6. **A fast reload loop for Lisp.** The changed `.lisp` files loaded into the running StumpWM (through the door, which holds a load asked by `vikix eval`) and only the tests they reach run (`tests/run.sh --changed`): no restart and no full run for most edits.
7. **Agents side by side without collisions.** A desk and a load-weighted test slot each, and a board in view of the lock holders, the slots, the load and the queue. Goes with the weighted slots and `queue.sh`'s own slots (`DESIGN-ci.md` item 3) and `DESIGN-dependable.md` item 11.
8. **Learning from use.** The commands and keys actually used, counted on the machine (no secrets, nothing of the notes or the diary). Once a week, suggestions: new keys, aliases or routines for sequences repeated, and dead keys to retire, which frees rows on the full key card. *2026-10-18:* `vikix used` counts already (names only, `used.lisp`), and TODO "What's next" 5 waits on its counts; what is new is sequences and the weekly suggestion.
9. **Daily drivers.** Clipboard history, a scratchpad, window layouts restored for each desk, and one switcher across desks, windows and TODOs. *2026-10-18:* clipmenu runs in the session, the drawer is the scratchpad, layouts come back with a project, and the palette (Super+Space) is one switcher; what is new is layouts by desk, and the desks and TODOs in the palette.

## The rules still hold

Change the user's files (`user.lisp`, `rules.lisp`), never Vikix's linked files or `~/vikix`; update the guides in the same commit when a key or a path changes; `vikix snapshot` before touching a file of the user's; everything goes through the release.
