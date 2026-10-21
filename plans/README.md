# Plans

The longer plans of Vikix, one file each. The queue is `../TODO.md`, the pool `../IDEAS.md`, the big ideas `../NOVEL.md`, what shipped out of the first two `../ARCHIVE.md`; a design here moves into `TODO.md` when work on it starts, and what ships is deleted from it, what changes dated.

## Active release priority

**[Desktop 1.0 critical path](DESKTOP-1.0.md)** (2026-10-21) — overrides the order of optional TODOs: reliability/security and rollback; autonomous checked agents; personal-machine continuity; installation and 30-day validation. Excludes Vikix Cloud. Acceptance evidence is required before calling a phase complete.

## Designs

| File | Drafted | What it works out |
|---|---|---|
| `DESIGN-accelerators.md` | 2026-10-18 | Groki's handover: the loop from idea to release run hands-off for Vid, a desk on one key, a release queue that runs itself, the morning brief (TODO 100), the Office's inbox as a popup, a bug caught from anywhere, a fast Lisp reload, learning from use, daily drivers; 1 to 3 first. |
| `DESIGN-ci.md` | 2026-10-18 | Groki's handover after 0.72.97's five tries: CI that shows every failure (and the red `man` step), pinned shellcheck, tests that hold under load (weighted slots, a load gate, wait-until helpers, once more alone), releases that don't stall, hermetic tests, more of the suite in CI, the budgets, housekeeping. |
| `DESIGN-cloud.md` | 2026-10-09 | Vid's idea, as he wrote it: rented always-on machines as nodes of the one Vikix (`vikix nodes`, `--on NAME` over SSH first, projects sent by git, jobs that outlive the laptop), and the product that could sell such nodes (TODO 117, its v0.1; its first four parts shipped 2026-10-12 as `bin/vikix-node`). |
| `DESIGN-codex-integration.md` | 2026-10-10 | Codex as a first-class worker: `CLAUDE.md` as its instructions, three modes set by the launcher with the desk as the sandbox's only root, its hooks in Codex's shape with an escalation denied off the desk, the hand-in's fields, a review by another provider and a handover between them (TODO 116, shipped in five releases on 2026-10-10; left: Vid's day with the two providers, the commands in `docs/agents.md`). |
| `DESIGN-cuis.md` | 2026-10-03 | Cuis Smalltalk as a Vikix feature, with a door for the agent. Phase 0 built 2026-10-09: `vikix cuis`, `vikix eval --cuis` (TODO 88). |
| `DESIGN-dependable.md` | 2026-10-18 | Groki's handover: the laptop to depend on, a known-good update channel, system rollback (TODO 6), the Lisp toolchain pinned, signed updates (To look into 4), an update doctor, a hardware check, test tiers, keys only where needed, desks enforced by the system, the ledger (TODO 81), one view of releases and agents, caps on what grows (TODO 96). |
| `DESIGN-docs.md` | 2026-10-03 | The docs catalogue and the `vk` alias. |
| `DESIGN-machines.md` | 2026-10-04 | Your laptops, desktop and phones as one Vikix: Tailscale, Syncthing, KDE Connect, `vikix export`/`import`, `--on NAME` for the doors (TODO 16 to 19). |
| `DESIGN-music.md` | 2026-10-17 | Remaining Music design after the 0.72.85 browser sketchpad; executable continuation in `music-next.toml`. |
| `music-next.toml` | 2026-10-17 | Executable Office plan: banks through performance, dependencies and acceptance checks; one worker at a time, released by the plan, no user gate (2026-10-17). |
| `DESIGN-office-tasks.md` | 2026-10-10 | The Office as a task board: a task record of its own with provenance, priority and a launch number, the worker's state apart from the task's, Needs attention with decisions a worker registers (phases 1 and 2 implemented 2026-10-14), phase 3 queue and scheduler implemented 2026-10-15, released in 0.72.78; the full board and proposals remain (TODO 115). |
| `DESIGN-openclaw.md` | 2026-10-08 | OpenClaw with the office: a sixth agent in a terminal, the house rules as its plugin, its Gateway as the phone's way in; TODO 13's slot, OpenClaw or Hermes for Vid to choose. |
| `DESIGN-phone.md` | 2026-10-08 | The phone's way into the desktop, replacing OpenClaw's gateway direction for TODO 13. |
| `DESIGN-publish.md` | 2026-10-04 | Books, sites and EPUBs built and checked by one command (TODO 79). |
| `DESIGN-random-guide.md` | 2026-10-11 | `vikix docs random` and a Help entry: one of the guides under `docs/` at random, opened as `vikix docs` opens it, every page once before any twice (a deck in a state file); no key. |
| `DESIGN-remoteapp.md` | 2026-10-04 | A Windows program's own window on the desktop, through RDP's RemoteApp (TODO 82). |
| `DESIGN-restore.md` | 2026-10-04 | Any file as it was: its versions from the backups and the snapshots, brought back as an Esploro plan (TODO 80). |
| `DESIGN-security.md` | 2026-10-04 | The pen-tester's open findings as a dated plan: signed updates, pinned installers, the door module and allow-list, the ledger (TODO 4 and 5). |
| `DESIGN-site.md` | 2026-10-04 | The Living Series site in place of Substack: static pages from `vikix publish`, a small Lisp gate for purchases and logins, Listmonk (TODO 84). |
| `DESIGN-viri.md` | 2026-10-03 | The scrolling workspace; Phase 0 built as `viri.lisp`, P0 and P1 shipped. |
| `DESIGN-what.md` | 2026-10-05 | What is this: any part of the running computer explained on a card (idea 2 of `NOVEL.md`); Phase 0 built as `vikix what`. |
| `DESIGN-workers.md` | 2026-10-07 | A desk with a task as a worker: the task said to it, an inbox, a report by construction, pause and go, a tester, dismiss (the former TODO 105, shipped). |

## Other plans

| File | Written | What it holds |
|---|---|---|
| [VIKIX_CLOUD_HANDOFF.md](VIKIX_CLOUD_HANDOFF.md) | 2026-10-15 (imported) | Vid’s Cloud development handoff, supplementing `DESIGN-cloud.md` and TODO 117: phased acceptance criteria, transfer safeguards, dogfooding and later product context; annotated for the node commands already shipped. |
| `ai-desktop.md` | 2026-09-30 | The AI desktop at work (one Radeon AI PRO R9700), beside the ROG Flow Z13 (TODO 58 to 63). |
| `TODO-editors.md` | 2026-09-29 | What is left for the editors: Neovim's config into Vikix, AI in Neovim and Emacs. |
| `TODO-Windows.md` | 2026-10-05 | What is left for Windows programs in their own windows (`vikix windows app`). |
| `TUTORIALS.md` | 2026-09-28 | The courses of `vikix learn`, C first: the plan and the rules for a lesson. |
| `APP-IDEAS.md` | 2026-10-03 | Programs worth trying on Vikix, and whether Void packages them. |

| [website-refresh.md](website-refresh.md) | 2026-10-21 | Value-led homepage, wallpaper gallery and the original site’s recovery branch. |
