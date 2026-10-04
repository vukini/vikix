# Vikix Restore — design

Any file, as it was: a file's past versions from the backups and the snapshots, found from the file itself, brought back as a plan with undo.

Drafted 2026-10-04 for TODO item 80. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

Vikix keeps two histories of your files and neither is reachable from a file. `vikix backup` (restic, encrypted, to a USB drive or a remote) holds daily, weekly and monthly versions of all of `~`; `vikix snapshot` (a git repo over `yours.list`) holds every change to your settings. To get a file back today you need to know which history has it, type `vikix backup restore PATH [ID]` with a snapshot id from `vikix backup list`, and look in `~/Restored/<time>/`. That is better than most desktops, and still a man page away from an ordinary person, who thinks "the file I had on Tuesday", not "snapshot 4f2a".

Nothing shows a file's versions beside the file; nothing says, before restoring, what will change; and the two histories answer different questions with different commands.

## What it is

- **`vikix versions PATH`**: every version of a file or folder, from both histories, newest first, each with its date and size and where it came from (backup or snapshot). One command, one list.
- **Esploro's "Versions…"**: the same list on a right-click, with a preview, and "Bring back" as an Esploro plan: the review panel shows what will be restored where, Apply does it, undo takes it back.
- **A restore that never overwrites**: a version comes back beside the file as `NAME (Tuesday).ext`, or replaces it only through the plan, where the current one goes to the Trash first.
- **Setup that a non-technical user finishes**: `vikix backup setup` without a place picks the USB drive that's plugged in; the password is printed as a card; the bar's reminder opens the setup when clicked.

## How it is built

```
  Esploro ─── Versions… ──► vikix versions PATH --json ──► restic (backup) + git (yours.git)
      │                                                       │
      └── plan: (:restore-version PATH ID DEST) ──► vikix restore PATH ID [--beside|--replace]
                      review panel: Apply / Cancel                 │
                                                                   └── journal entry, undo
```

**`vikix versions`** (in `bin/vikix-backup`, with a new verb, or its own `bin/vikix-versions` calling both histories):

- Backups: `restic find --json PATH` lists the snapshots that hold the path with its size and modification time; versions with the same content hash are folded into one row with a date range ("Mon 29 Sep to Thu 2 Oct"), so a file unchanged for a month is one line, not thirty.
- Snapshots: for a path under `yours.list`, `git -C yours.git log --follow -- PATH` gives commits and dates; the same folding.
- Output: a table for people (`date · where · size · what changed`, the last from `restic diff` or `git diff --stat` against the next-older version), `--json` for Esploro.
- Time: `restic find` over a year of snapshots is seconds on a USB drive; the list is cached per path for a minute.

**`vikix restore PATH ID`**: by default `--beside`, writing `NAME (DATE).ext` next to the file (restic `dump` for a file, `restore --include` into a temporary folder then a move for a folder; `git show` for the snapshot history). `--replace` puts the current file in the Trash first (the freedesktop Trash, as Esploro does), then restores in place. Nothing is ever overwritten without a copy in the Trash. `~/Restored/` stays for `vikix backup restore`, which remains for scripts and the old habit.

**Esploro** (its own repo):

- A file command `versions` (`define-file-command`, `:changes nil`) that calls `vikix versions --json` and shows the list in a buffer: date, source, size, the change summary; `RET` previews (text as text, images with the thumbnail machinery, others by size and type); `b` brings back beside, `r` replaces.
- "Bring back" is a plan step, `(:restore-version PATH ID DEST)`, added to `*plan-operations*` with its inverse (a `:trash` of the restored file for `--beside`; a `:restore` from the Trash for `--replace`), so the review panel, the journal and `undo` work as for a move. The step runs `vikix restore`.
- A folder's "Versions…" lists the folder's versions, and "Bring back" restores it beside as `NAME (DATE)/`.

**Setup, for someone who hasn't read anything:**

- `vikix backup setup` with no place: lists the mounted drives (udiskie knows them) and asks which; the password is generated and shown once with "print this card" (a one-page PDF through the publish pipeline's `pdf` when present, else plain text to the printer).
- The bar's "backup 9d" note opens a menu on click: back up now, or set up if never set up.
- `vikix doctor`: last backup, where, whether the drive is plugged in, whether `check` ever ran, and a reminder about the password card until the user says it is kept.

## Goals

1. **A file's history is one list, from the file.** Right-click, Versions…, and every version from both histories, newest first, in words and dates.
2. **Bringing back is safe by construction.** Beside by default; replacing goes through the Trash and the plan; undo exists.
3. **No ids, no paths, no man page** for the everyday case. The commands keep them for the rest.
4. **Setup finishes.** A person with a USB drive and no vocabulary ends with a backup running and a password card in a drawer.

## Non-goals (this version)

- **Not continuous backup.** Backups run when asked or when the reminder is clicked; a timer is a later setting. The snapshot history covers settings continuously already.
- **Not a new backup format.** restic and git as now; this is a window onto them.
- **Not whole-system rollback.** TODO 6 (snapper on btrfs) is separate.
- **Not cloud destinations' setup.** restic's `sftp:`, `b2:` and the rest still work by typing them; the guided setup is for a drive.

## User stories

- As anyone, I want to right-click a file and see what it looked like last Tuesday so that I can get back the paragraph I deleted.
- As anyone, I want "Bring back" to put the old version beside the new one so that I can compare before I decide.
- As someone who did replace it, I want undo to work.
- As someone with a USB drive and no vocabulary, I want `vikix backup setup` to find the drive and give me a card so that backups exist at all.
- As Vid, I want `vikix versions ~/.stumpwm.d/user.lisp` to show the settings history and the backup history in one list.
- As the agent, I want `vikix versions --json` so that I can answer "when did this file change?" from the histories rather than guessing.

## Requirements

### Must have (P0)

1. **`vikix versions PATH`** over both histories, folded by content, with the change summary; `--json`.
   - [ ] For a file changed on three days across ten snapshots, the list has three rows
2. **`vikix restore PATH ID --beside|--replace`**, the Trash on replace, never an overwrite.
   - [ ] `--replace` leaves the previous file in the Trash with its original name
3. **Esploro's "Versions…"** with preview, "bring back beside" and "replace" as plan steps with inverses; undo works. (In Esploro's repo, pinned into Vikix as its other features are.)
4. **Guided setup**: the drive picker, the password card, the bar note's menu, the doctor lines.

### Should have (P1)

5. A diff view for text files between two versions, in Emacs (`ediff`), from the Versions list.
6. `vikix versions --since "last week"` and friends, plain-language dates.
7. A timer: `vikix backup every day|week` as a snooze job, off by default.

### Later (P2)

8. Searching inside past versions ("the file that mentioned the lease", across snapshots): `restic find` by content is slow; a side index when the docs catalogue learns backups as a source.
9. Deleted files: Esploro's folder "Versions…" listing files that existed in a version and don't now, with "bring back".

## Open questions

Blocking:
- **Where the Esploro side lives in Esploro's own order of work.** (Vid) Its DESIGN.md has its own "Later" list; this needs a line there, and the plan step type added to its `plan.lisp`.
- **Preview of large or binary files from restic**: `dump` to a temporary file every time, or a size cap above which the preview says "too big to show, bring it back beside". Proposed: 20 MB cap.

Non-blocking:
- Folding by content: restic exposes content hashes in `find --json`? If not, fold by size and mtime.
- The password card's wording and whether it also carries the restic repository's location.

## Phasing

**Phase 0, a day:** `vikix versions` and `vikix restore --beside` over the backup history alone; try it on a real file from the X1's backups.

**Phase 1:** the snapshot history in the same list, `--replace` through the Trash, Esploro's command and plan step, the guided setup.

**Phase 2:** P1.

## Risks

- **A USB drive that isn't plugged in.** Half the time the backup isn't there. `vikix versions` says so plainly and shows the snapshot history alone; Esploro's list gets a line "plug in the backup drive to see older versions".
- **restic's speed over many snapshots.** Measured in Phase 0 on a year of real backups; if `find` is slow, the per-path cache grows to a day and warms when the drive is plugged in.
- **Two codebases.** Vikix's command and Esploro's window must agree on the JSON; a test in Vikix runs `vikix versions --json` against a fixture repository and checks the shape Esploro reads.
