# Everyday user: `vikix update` sets aside changes in the checkout (2026-09-28)

Checked: the dev checkout at **0.42.2** (commit be426c6). The installed desktop
(`~/vikix/VERSION`) is still **0.42.1**, so the new behaviour isn't live yet.
Everything was tried in throwaway copies under the session scratchpad: a fake
upstream built from `git ls-files`, a clone as the "installed checkout", the
upstream's newer `bin/vikix` cut off right after the pull (as `tests/update.sh`
does), and `HOME`, `VIKIX_STATE` pointed at temp dirs, with `VIKIX_SUDO_KEPT=1` and
`VIKIX_SWANK_PORT=9`. Nothing ran against the real `~/vikix` or with sudo. The
temp dirs are deleted.

The situation this handles is real, and it's already on this machine:
`~/.local/state/vikix/logs/update-20260928-104716.log` is the old "Your local
changes ... would be overwritten by merge" failure (TODO.md), and `git -C
~/vikix status` shows an untracked Emacs autosave right now,
`config/stumpwm/vikix/#theme.lisp#`. The next real update will stash it.

The main path works: the update gets past changes that used to stop it, takes
under half a second before the pull, and the named stash holds everything. The
problems start once a user tries to get the changes back, or has updated more
than once.

---

## 1. A `stash pop` that conflicts leaves conflict markers in a file the desktop loads, and the next update then fails and says the changes were set aside when they weren't

**What happened.** I made an edit to `config/stumpwm/init.lisp` in the clone (what
someone gets by editing `~/.stumpwm.d/init.lisp`, which is a symlink into the
checkout) and ran the update: it was stashed. Upstream then changed the end of the
same file, and a second update pulled that change. Then I did what the message
suggests, `git -C <checkout> stash pop`:

```
CONFLICT (content): Merge conflict in config/stumpwm/init.lisp
...
The stash entry is kept in case you need it again.
```

`init.lisp` now contains `<<<<<<< Updated upstream` / `=======` / `>>>>>>>
Stashed changes`. Because that file is the live `~/.stumpwm.d/init.lisp`, the
next reload or login reads those markers as Lisp. I checked with sbcl: loading
stops at the first marker (`The variable <<<<<<< is unbound`), so everything after
it in `init.lisp` is never loaded. Where the markers land decides how much of
the Vikix layer and `user.lisp` is lost.

Then I ran `vikix update` again, as someone would to "fix it":

```
!! the Vikix checkout (~/vikix) has changes of its own, which would stop the update:
     UU config/stumpwm/init.lisp
     ?? config/stumpwm/vikix/#theme.lisp#
   They're set aside, not deleted (Vikix's files are replaced by every update):
error: could not write index
config/stumpwm/init.lisp: needs merge
```

It exits with 1. It says "They're set aside" *before* the stash runs, the stash
fails, and nothing from Vikix follows: no "See them", no next step. The user now
has a broken `init.lisp` and an update that won't run.

**Expected.** Either a pop that can't damage the live config, or a Vikix-level
way out. Also, the "set aside" sentence should come only after the stash has
worked.

**How to see it.** In a throwaway clone: edit `config/stumpwm/init.lisp`, update,
commit an upstream change at the same place, update, `stash pop`, update again.

**Cost.** This is rare, but the damage is high: it breaks the desktop at the
next login, and a user who doesn't know git has no way to recover. It happens
most for exactly the files people edit by mistake (the symlinked
`~/.stumpwm.d/*.lisp`), because those are the files updates change.

**Suggestion.** The smallest fix: in `set_aside_local_changes`, stop with
a clear message if `git status --porcelain` shows a conflict (`UU`, `AA`, `DU`
…), for example `die "the checkout is half-way through getting changes back (a
conflict in FILE). To give up on them and keep Vikix's version: git -C DIR
checkout -- FILE (they stay in the stash)"`. Print "They're set aside" only after
`stash push` succeeds. Better still, replace `stash pop` in the message with a
command that can't conflict and doesn't touch live files:

```
git -C ~/vikix stash show -p --include-untracked 'stash@{N}' > ~/vikix-changes-<date>.patch
```

That gives the user their changes as a file to read or copy from, which is what
"to keep a note, or move it" means anyway. Keep `stash pop` in docs/fixing.md
for people who know git, with a line on what to do after a conflict.

Not in TODO.md.

## 2. Stashes pile up, and "See them" / "Get them back" always act on the newest, which is usually not the one that matters

**What happened.** I ran four updates, each with an Emacs autosave present
(`#theme.lisp#`, which Emacs re-creates while a file is open, and which is
already in the real checkout now). The result was four stashes:

```
stash@{0}: On master: vikix update 2026-09-28 11:14: changes made in the checkout
stash@{1}: On master: vikix update 2026-09-28 11:14: changes made in the checkout
stash@{2}: On master: vikix update 2026-09-28 11:14: changes made in the checkout
stash@{3}: On master: vikix update 2026-09-28 11:13: changes made in the checkout
```

The real edit (the `init.lisp` change) was in `stash@{3}`. The printed commands,
`stash show -p --include-untracked` and `stash pop`, both act on `stash@{0}`,
which was just the latest autosave. A user who reads the message from an update
a week after the edit gets the wrong thing and will think the edit is gone.
`stash pop` of the autosave also fails when Emacs has already re-created the file
(`#theme.lisp# already exists, no checkout / could not restore untracked files
from stash`). That's another raw git error, though nothing is lost.

The names are all the same apart from the time, so `stash list` doesn't show
which one holds what.

**Expected.** The message points at *this* update's stash, and the list says
what each stash contains.

**Cost.** This happens often for anyone who edits in the checkout with Emacs:
every update adds a stash. The confusion ("where did my change go?") costs
minutes to an hour, or the change is given up for lost.

**Suggestion.** (a) Put the file names in the stash message (`vikix update
2026-09-28 11:13: init.lisp, #theme.lisp#`), so `stash list` answers the
question by itself. (b) Print the exact entry: after the push it is `stash@{0}`,
but it moves with every later update, so use the stash's commit id (`git stash
list --format=%h -1`) in the "See them / Get them back" lines, or save the patch
to a file (see 1). (c) Leave editor junk (`#*#`, `*~`, `.#*`) out: add them to
`.gitignore`, which already keeps `*.zip` out, so they never stop a pull or make
a stash at all. (c) alone removes most stashes in practice.

Not in TODO.md.

## 3. The warning scrolls away: nothing at the end of the update mentions the stash

**What happened.** The "set aside" block comes at the very start of the run, lines
2–10. A real update log here is about 425 lines (`update-20260928-093043.log`
429, `update-20260928-105647.log` 423). The last line is `Vikix X is up to date`,
with no reminder. The update also reloads StumpWM, so an edit made through a
symlinked file (say a key added to `~/.stumpwm.d/keys.lisp`) stops working
straight away, with no explanation on screen.

**Expected.** The summary at the end says "your changes to FILE were set aside;
see …", in the same way the end already names the stages that failed.

**Cost.** This happens every time there are changes. Most people won't scroll
back 400 lines, so to them the change has "vanished", which undoes the "nothing
is lost" promise.

**Suggestion.** Save the stash name in an env var or file that the re-exec'd
`--pulled` run can read, and repeat one line just before "is up to date". The
log already holds the full block. Optionally, `vikix doctor` could mention
"N sets of changes set aside in the checkout (git -C ~/vikix stash list)".

Not in TODO.md.

## 4. The message is written for git users

For someone who doesn't know git:

- `  M config/stumpwm/init.lisp` / `?? config/stumpwm/vikix/#theme.lisp#`: the
  `M` and `??` codes mean nothing to them. Something like "changed:" and "new
  file:" would.
- The paths are relative to the checkout. Someone who edited
  `~/.stumpwm.d/init.lisp` won't recognise `config/stumpwm/init.lisp` as that
  file. The line "A change of yours belongs in your own files" is right, but it
  doesn't tell them *this* was their edit to `~/.stumpwm.d/init.lisp`.
- "set aside" is good plain language, and "not deleted" is exactly the
  reassurance needed. "stash" appears only inside the commands, which is also
  fine. But the commands are three words of git jargon (`stash show -p
  --include-untracked`) with no hint of what the output looks like (a diff).
- "see docs/customize.md" is relative to nothing. It should be
  `~/vikix/docs/customize.md`, or `info vikix`, or Super+m → Vikix guide, which
  the skill already mentions.
- In a dry run (`DRY_RUN=1`) it still says "They're set aside" next to "would
  run: git … stash push". That's minor.

**Suggestion.** Map the codes to words (`M`→changed, `??`→new, `D`→deleted).
For paths under `config/stumpwm/`, also show the `~/.stumpwm.d/…` name they're
linked as. Use an absolute path or `info vikix` for the guide.

Not in TODO.md.

## 5. The docs don't match the new behaviour in two places

- `config/claude/skills/vikix/SKILL.md` line 25 still says an edit to Vikix's
  files "breaks the update (`git pull --ff-only`)". Now the edit is set aside,
  and the update goes on and reloads StumpWM without it. The agent should tell
  users "the next update will set your edit aside", not "it'll break".
- docs/fixing.md, "An update failed", says of `stash show -p` and `stash pop`
  what they do, but not that they act on the *latest* entry only, nor what to
  do after a conflicting pop (see 1 and 2). README's "Later versions" paragraph
  is accurate as far as it goes.

Not in TODO.md.

## 6. Nearby, not new in 0.42.2: a commit in the checkout still stops the update with raw git

The skill offers to write Vikix changes "as a change to the checkout that they
can review and commit". If the user commits and upstream moves on, `vikix
update` stops at "pulling Vikix" with git's `Diverging branches can't be
fast-forwarded … fatal: Not possible to fast-forward, aborting.` (exit 128). The
set-aside step doesn't help, since there's nothing uncommitted. docs/fixing.md
says a stop at "pulling Vikix" is "usually the network", which is misleading
here.

**Suggestion.** When `pull --ff-only` fails and `git rev-list @{u}..HEAD` isn't
empty, say "the checkout has commits of its own (git -C ~/vikix log @{u}..)";
push them or move them to a branch", and add a line to fixing.md.

Not in TODO.md.

---

## What felt good

- The update no longer stops for an autosave file. That was a real failure on
  this machine today, and it's gone.
- "set aside, not deleted" and the named, dated stash are the right idea and the
  right tone. Nothing was ever lost in any of my runs: every edit and untracked
  file was recoverable from `git stash list`.
- Ignored files (the release zips) are left alone, as promised.
- The check is cheap: a clean checkout prints nothing extra (tested), and the
  whole pre-pull step takes a fraction of a second.
- The commands print the real checkout path, so they can be copied as they are.
- README, fixing.md and the skill all mention the behaviour in the same release.
