# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## `vikix windows remove` leaves the Windows programs' things behind

Noted 2026-10-05, by the guides check.

**What happens.** After `vikix windows remove`, the password kept for Windows programs (`~/.config/vikix/secrets/windows-password`), the launcher entries (`~/.local/share/applications/vikix-win-*.desktop`) and the list of programs (`~/.local/state/vikix/windows-apps.json`) are still there, the entries for programs that are gone.

**What's known.** `cmd_remove` in `bin/vikix-windows` deletes the VM, its disk and the answers disc, and predates `vikix windows apps`. `docs/windows.md` ("Removing it") says how to clear the first two by hand.

**Next step.** Have `cmd_remove` do what `vikix windows apps forget` does, and delete the `vikix-win-*.desktop` entries and `windows-apps.json`; then take the by-hand line out of the guide. A check for it in `tests/winapps.sh`.

## A code block inside a list item comes out wrong in the Info manual and the web guide

Noted 2026-10-05, by the guides check.

**What happens.** A fenced code block indented under a numbered or bulleted item is not a block there: "Installing Windows" in `docs/windows.md` (three of them) and one in `docs/plugins.md` (line 49) show as ` ``sh vikix windows setup `` ` in a line of text, and in the web guide every step is numbered 1. On GitHub they are right.

**What's known.** `lib/md2texi.py` knows fenced code only at the start of a line (`python3 lib/md2texi.py docs | grep -n 'windows setup'` shows the `@code{sh ...}` it makes), and `tests/info.sh` passes, since makeinfo has nothing to warn about.

**Next step.** Teach `md2texi.py` an indented fence inside an item (an `@example` within the `@item`, the list going on after it), and have `tests/info.sh` fail on a ` ``` ` left in the Texinfo. Or write those two lists without the construct, as the newer section of `windows.md` does.

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

## The first menu after StumpWM starts is drawn too short

Noted 2026-10-05, on a hidden screen (Xvfb), while testing Super+m in sections; the same on the release before. Not checked on a real screen.

**What happens.** The first menu shown after StumpWM starts (Super+m: 13 rows) is drawn with its last rows missing (10 of 13; before the sections, 28 of 35) and a box about a sixth too wide. Any key that redraws it (Down), or opening it again, shows it whole, and every later menu is right.

**What's known.** The menu itself is right: its table and its view say 13 rows at that first drawing. The numbers fit a window sized with the old font's measures (9x15: 15 pixels a row where Iosevka has 19, 9 a letter where it has 7.6), so the message window's first size is probably worked out before the TTF font is what it measures with.

**Next step.** See whether a real login does it (the first Super+m after logging in). If so, look at what `echo-string-list` measures with on its first call after `vikix-set-font` (theme.lisp), and draw one message at start-up, or measure once, so the first menu is not the first.

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


## tests/registry.sh: "its key runs it" failed once in a full run

Noted 2026-10-05, releasing Super+i's Codex choice.

**What happens.** In a release's full run, with other sessions testing, `registry` failed at `FAIL: its key runs it: NIL`: the hidden StumpWM had shown no message when the test read it, right after the key press. Alone, the test passed three times out of three on the same commit, and the release passed at the second try.

**What's known.** The check reads the screen's last message straight after `key super+alt+F12`, without waiting for the command to have run. The change being released touched nothing of StumpWM's.

**Next step.** Have the check wait for the message (a short loop, as other hidden-screen tests do) instead of reading it once.

## tests/docs.sh: "Super+F2's menus: Return should open the hit" failed once in a release's run

Noted 2026-10-05, releasing Esploro's Names Only.

**What happens.** In a release's run, with other sessions testing (load 7 on 4 cores), `docs` failed at `FAIL: Super+F2's menus: Return should open the hit its way:` with nothing opened. Alone, a minute later on the same commit, it passed. The change being released touched the README, `bin/vikix-esploro` and `tests/esploro.sh` only.

**What's known.** The check types into rofi on a hidden screen by the clock: 1.5 s after starting `vikix-docs pick` it types the words and Return, 1.5 s later the key that opens the hit. On a busy machine rofi isn't up, or the hits aren't listed, when the keys are sent.

**Next step.** Wait for rofi's window (`xdotool search --sync`) before typing, and for the second menu before the opening key, instead of the two sleeps.
