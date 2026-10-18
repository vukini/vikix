# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## CI's lint: man doesn't show vikix-backup's prose on Ubuntu

Noted 2026-10-18, from Groki's handover (main run 39132865581, Vikix 0.72.97).

**What happens.** The `lint` job fails at `tests/ci.sh man`: `FAIL: man doesn't show vikix-backup's prose` (`tests/man.sh`, a grep for `Every backup is encrypted` in `MANWIDTH=80 man -M … vikix-backup | col -b`). It passes on the laptop. Lint's steps run one after another, so more may be hidden behind it.

**What's known.** Not looked into. Likely Ubuntu's man-db and groff justify or hyphenate that line differently from the laptop (extra spaces, a line break), so the fixed-string grep misses.

**Next step.** Reproduce on Ubuntu (`gh run view 39132865581 -R vukini/vikix --log-failed`), then squeeze the whitespace before grepping (`tr -s ' \n' ' '`) or grep a shorter phrase. Part of `plans/DESIGN-ci.md` item 1.

## Esploro's iPhone under Drives: not yet tried with a phone

Noted 2026-10-05, by the guides check; the packages added 2026-10-11 (Vikix 0.72.x).

**What happens.** Esploro shows an iPhone under Drives and opens it with a click. `optional/esploro.list` now brings what its `src/phone.lisp` runs (libimobiledevice for `idevice_id`, `ideviceinfo` and `idevicepair`; ifuse; usbmuxd, whose udev rule starts the daemon when a phone is plugged in), and the README says so; no phone has been plugged into a fresh install yet.

**Next step.** Plug an iPhone into a machine that has the feature, trust the computer on the phone, and see the folder open in Esploro; if it doesn't, `idevicepair pair` and `ifuse /tmp/phone` by hand say which step is missing.

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.

## agent-waiting: a question with choices may arrive late (to confirm)

Noted 2026-10-04, with the plugin's rewrite (Vikix 0.71.160).

**What happens.** Nothing seen yet. The plugin's hook for Claude Code's AskUserQuestion (`PreToolUse` with that matcher → `agent-waiting question`) was written without being seen to fire: a throwaway `claude -p` session can't show such a question.

**What's known.** `PermissionRequest` and `Stop` were checked on Claude Code 2.1.289 and fire at once with what the plugin reads. If the question hook doesn't fire, the note comes from Claude's own notification some seconds later, without the question's words.

**Next step.** The next time a session asks a question with choices while its window isn't in front, look at the bar and at `~/.local/state/vikix/agents/`: the note's third line should be the question.
