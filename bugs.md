# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## `tests/main.sh` fails in a busy parallel run, and passes alone

Noted 2026-10-04, twice the same day (`tests/run.sh` with other sessions' test runs beside it, load 15 to 25).

**What happens.** In `tests/run.sh` (side by side) `main` is reported FAILED; run alone straight after (`bash tests/main.sh`), on the same commit, it passes. `times` does the same for the known reason (its limits), and is in `run.sh`'s `alone` list; `main` isn't.

**What's known.** Nothing in the commits under test touched layouts or windows (a pin of Esploro; `vikix memory`). `main` drives a real StumpWM on a hidden screen, so it most likely waits a fixed time for a window or a layout that a loaded machine doesn't meet.

**Next step.** Run it under load (`stress-ng --cpu 16` beside it) to see which check fails, and give that wait a poll with a deadline; or add `main` to `alone` in `tests/run.sh` if it can't be made patient.

## A window with a broken WM_HINTS can't be raised: "an error StumpWM didn't catch"

Noted 2026-10-04, on Vid's desktop at 0.71.148 (`~/.local/state/vikix/errors/20261004-161317-00.txt`).

**What happens.** A window titled "Calculator" opened, and StumpWM met an error it doesn't catch, in the handling of the window's map request: `The value 1668047203 is not of type (UNSIGNED-BYTE 29) when binding XLIB::ID`. Vikix's errors menu took it, so the desktop went on, but every raise of that window would do the same.

**What's known.** The backtrace is `raise-window` → `window-urgent-p` → `xlib::decode-wm-hints` → `xlib::lookup-pixmap`. The window's `WM_HINTS` was `#(7 1 1 1668047203 0 0 0 0 0)`: its flags say it has an icon pixmap, and the pixmap's id is 1668047203, which is no X id (they are 29 bits) but the four letters "calc" read as a number (0x636c6163). So the program wrote text where an id belongs, and CLX, which StumpWM reads the hints with, is strict about it. Which program it was isn't known: the calculators tried that day aren't installed any more (SpeedCrunch, which is, doesn't do it).

**Next step.** Reproduce it with any window: `xprop -id ID -f WM_HINTS 32c -set WM_HINTS "7, 1, 1, 1668047203, 0, 0, 0, 0, 0"`, then raise it. The likely fix is to read the hints forgivingly, `xlib:wm-hints` answering nothing for a window whose hints can't be read (an `sb-int:encapsulate` in `windows.lisp`, as `get-window-placement` is wrapped in `rules.lisp`), with a check for it in `tests/focus.sh`.

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
