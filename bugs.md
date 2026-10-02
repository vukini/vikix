# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)

## tests/swank.sh fails now and then: "the test's Swank didn't start"

Noted 2026-10-02. Test only; the desktop isn't affected as far as known.

**What happens.** About one run in three, `tests/swank.sh` stops with `FAIL: the test's Swank didn't start:` and a backtrace through `(load ".../swank.lisp")`, the test's copy of `config/stumpwm/vikix/swank.lisp`. The next run usually passes. Seen on `main` (2 failures in 6 runs) as on a branch that didn't touch Swank.

**What's known.** The test starts an "old" Swank on a random port, then loads swank-guard.lisp and swank.lisp, whose `vikix-start-swank` stops that server and at once makes a new one on the same port. The backtrace is in that load; the condition itself isn't printed, because `--non-interactive` prints only the frames.

**Next step.** Print the condition (a `handler-bind` around the load in the test's server.lisp, writing it to server.log). If it's the port still being held by the stopped server, wait for `stop-server` to finish (or retry `create-server` a few times) in `vikix-start-swank`; that would also make a real StumpWM's one-time restart of an unguarded Swank safer.

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.
