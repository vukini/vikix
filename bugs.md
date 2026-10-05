# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## The first menu after StumpWM starts is drawn too short

Noted 2026-10-05, on a hidden screen (Xvfb), while testing Super+m in sections; the same on the release before. Not checked on a real screen.

**What happens.** The first menu shown after StumpWM starts (Super+m: 13 rows) is drawn with its last rows missing (10 of 13; before the sections, 28 of 35) and a box about a sixth too wide. Any key that redraws it (Down), or opening it again, shows it whole, and every later menu is right.

**What's known.** The menu itself is right: its table and its view say 13 rows at that first drawing. The numbers fit a window sized with the old font's measures (9x15: 15 pixels a row where Iosevka has 19, 9 a letter where it has 7.6), so the message window's first size is probably worked out before the TTF font is what it measures with.

**Next step.** See whether a real login does it (the first Super+m after logging in). If so, look at what `echo-string-list` measures with on its first call after `vikix-set-font` (theme.lisp), and draw one message at start-up, or measure once, so the first menu is not the first.

## `tests/main.sh` fails in a busy parallel run, and passes alone

Noted 2026-10-04, twice the same day (`tests/run.sh` with other sessions' test runs beside it, load 15 to 25).

**What happens.** In `tests/run.sh` (side by side) `main` is reported FAILED; run alone straight after (`bash tests/main.sh`), on the same commit, it passes. `times` does the same for the known reason (its limits), and is in `run.sh`'s `alone` list; `main` isn't.

**What's known.** Nothing in the commits under test touched layouts or windows (a pin of Esploro; `vikix memory`). `main` drives a real StumpWM on a hidden screen, so it most likely waits a fixed time for a window or a layout that a loaded machine doesn't meet.

**Next step.** Run it under load (`stress-ng --cpu 16` beside it) to see which check fails, and give that wait a poll with a deadline; or add `main` to `alone` in `tests/run.sh` if it can't be made patient.

## tests/rules.sh fails when the machine is very busy

Noted 2026-10-03, while the load average was 20 to 25 on four cores (other sessions' work).

**What happens.** The part after a reload fails: "StumpWM's main thread did not answer within 10 s", or the window `Named` is gone (`window-group NIL`), then "StumpWM started again" counts too few windows. Alone it passes, in about a minute; on main it passed under the same load once and failed on this branch once, with no change to rules.

**What's known.** Its windows are `alacritty -e sleep 300`, and a slow run reaches the reload near that mark, so they close themselves; `vikix eval` gives up after 10 s while the reload is still loading.

**Next step.** Windows that live until the test ends (`sleep infinity`, killed by its cleanup), and a longer wait for the answer after `(loadrc)`.

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.

## The tray's network applet may show a stale list of networks (to confirm)

Noted 2026-10-05, on Vid's desktop at 0.71.179, tray on (`vikix tray on`, nm-applet in stumptray).

**What happens.** Vid: "the list is not updating in the wifi bar". Which part was stale (a network missing, old signal bars, networks gone) isn't known yet.

**What's known.** The system was fine at that moment: NetworkManager had scanned 20 seconds before (`LastScan` on the device), and `nmcli device wifi list` showed six networks; `nmcli device wifi rescan` works. So it is the applet's menu, not the scan. nm-applet had run for 30 hours; it was restarted (killed, started again from StumpWM, back in the tray, the connection untouched). Whether its list is right since then, Vid hasn't said.

**Next step.** Ask Vid what the menu shows against `nmcli device wifi list`. If it is still stale after the restart, build the picker (`TODO.md`, item 85) rather than chase the applet.

## agent-waiting: a question with choices may arrive late (to confirm)

Noted 2026-10-04, with the plugin's rewrite (Vikix 0.71.160).

**What happens.** Nothing seen yet. The plugin's hook for Claude Code's AskUserQuestion (`PreToolUse` with that matcher → `agent-waiting question`) was written without being seen to fire: a throwaway `claude -p` session can't show such a question.

**What's known.** `PermissionRequest` and `Stop` were checked on Claude Code 2.1.289 and fire at once with what the plugin reads. If the question hook doesn't fire, the note comes from Claude's own notification some seconds later, without the question's words.

**Next step.** The next time a session asks a question with choices while its window isn't in front, look at the bar and at `~/.local/state/vikix/agents/`: the note's third line should be the question.

