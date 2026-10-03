# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)

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
