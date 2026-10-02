# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.

## A meeting web app can't choose its camera or microphone

Noted 2026-10-02. Minor.

**What happens.** In a web app made with `vikix webapp add` (Teams, here), the meeting settings show the camera, microphone and speaker lists greyed out. The web app's window has no address bar, so Chromium's question "allow camera and microphone?" is easily missed, and the site never gets them.

**The fix used by hand.** With the web app closed, `~/.local/share/vikix/webapps/NAME/Default/Preferences` got `profile.content_settings.exceptions.media_stream_camera` and `media_stream_mic` set to `{"https://SITE:443,*": {"setting": 1}}` (allow, for that site only); then it worked: devices, a test call, sharing the screen.

**Next step.** `vikix webapp add` could ask "a meeting app? allow its camera and microphone" (or a `--media` flag, and a Teams preset with it on), writing that before the first start; Chromium rewrites Preferences while it runs, so only when the web app is closed.
