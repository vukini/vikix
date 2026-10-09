# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## Esploro's iPhone under Drives needs programs no list brings

Noted 2026-10-05, by the guides check. Esploro at the pin (b84b605).

**What happens.** Esploro shows an iPhone under Drives and opens it with a click, but on a machine with only Vikix's packages the programs it runs aren't there, so nothing shows. The guides say nothing of the iPhone for that reason.

**What's known.** Esploro's `src/phone.lisp` runs `idevice_id`, `ideviceinfo`, `idevicepair` and `ifuse`; no file in `packages/` names them (`optional/esploro.list` has the thumbnails' programs, archivemount and sshfs).

**Next step.** Find Void's packages for them (libimobiledevice's tools, ifuse, and usbmuxd with its service), add them to `optional/esploro.list` or to a feature of their own, try an iPhone, then a line in the README's Esploro paragraph.

## vikix.dev's Windows card doesn't say a program can have a window of its own

Noted 2026-10-05, by the guides check.

**What happens.** `site/index.html`'s card "Windows 11 in a window, installed by itself" tells of the whole Windows desktop only. `vikix windows app` and `apps` (since 0.71.178: one Windows program in a window of its own, tiled like any other) aren't on the page.

**What's known.** `docs/windows.md` has the section ("One program, in a window of its own") to take the words from.

**Next step.** A sentence and a command line on the card (`vikix windows app excel`), and a screenshot for the gallery when there is one.

## `tests/main.sh` fails in a busy parallel run, and passes alone

Noted 2026-10-04, twice the same day (`tests/run.sh` with other sessions' test runs beside it, load 15 to 25).

**What happens.** In `tests/run.sh` (side by side) `main` is reported FAILED; run alone straight after (`bash tests/main.sh`), on the same commit, it passes. `times` does the same for the known reason (its limits), and is in `run.sh`'s `alone` list; `main` isn't.

**What's known.** Nothing in the commits under test touched layouts or windows (a pin of Esploro; `vikix memory`). `main` drives a real StumpWM on a hidden screen, so it most likely waits a fixed time for a window or a layout that a loaded machine doesn't meet.

**Since.** Every run on the machine now draws from one set of test slots (`tests/run.sh`, the slots), so several sessions' runs no longer add up to a load of 15 to 25; it may not come back. If it does:

**Next step.** Run it under load (`stress-ng --cpu 16` beside it) to see which check fails, and give that wait a poll with a deadline; or add `main` to `alone` in `tests/run.sh` if it can't be made patient.

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
