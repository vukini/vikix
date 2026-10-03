# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.

## An xterm keeps StumpWM busy (title bars and resize steps)

Noted 2026-10-02, on the hidden test desktop (Xvfb); not seen on the laptop.

**What happens.** With an xterm tiled, StumpWM's main thread never rests: `vikix eval` answers "StumpWM's main thread did not answer within 10 s", though keys still work. A backtrace of the main thread shows it in `vikix-titled-maximize-window` from xterm's `WM_NORMAL_HINTS` changing, then `:configure-notify` on the frame around it, over and over (X sequence numbers climbing fast). It goes on after the xterm closes, until StumpWM restarts.

**What's known.** xterm asks for sizes in steps of a character (resize increment 6 by 13). The title bar takes room at the window's top, the height no longer fits a step, xterm sets its hints again, and the layout runs again. Alacritty asks for no steps and doesn't do it. Emacs frames ask for steps too, but don't do it: `vikix times measure` opens one on a hidden screen and StumpWM answers in under 0.1 s after it (2026-10-03).

**Next step.** In `vikix-titlebar-place`, round the height down to the window's increment (`geometry-hints`), or don't run the layout again when the hints changed but the size they give hasn't.
