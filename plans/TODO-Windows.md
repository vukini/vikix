# TODO: Windows programs

What is left for Windows programs in their own windows (`vikix windows app`, TODO item 82, `DESIGN-remoteapp.md`). Written 2026-10-05, after FACTS, the company ERP, first ran this way. Remove an item in the commit that ships it.

## Working on it

**Where things are.** `lib/windows-apps.py` does the work behind `vikix windows app` and `apps` (`bin/vikix-windows` hands those two words to it). Inside Windows everything goes through the QEMU guest agent, PowerShell run as SYSTEM: load the module and call `powershell(SCRIPT)` (returns exit code and output; `up(for_rdp=False)` first starts the VM and waits for the agent). The design is `DESIGN-remoteapp.md`; the stand-in test is `tests/winapps.sh`.

**The live tools,** `tests/windows-live/` (against the real VM, not in `tests/run.sh`): `catch-layer.sh` waits up to four minutes for a big override-redirect FreeRDP window and keeps its depth, properties, own pixels (`xwd`) and a screenshot; start it, then make the program show the thing. `layertest.py` opens a small test form over RemoteApp once per FreeRDP setting and reads its pixels; its docstring has the lessons that cost a run each.

**FACTS** (the company ERP, the first real program, 2026-10-05): id `factserp`, `C:\Program Files (x86)\FACTS COMPUTER SOFTWARE HOUSE\FactsERP\Facts.exe` (its Start-menu shortcut is an installer's advertised one: the program comes from Windows Installer's `ShortcutTarget` and `ComponentPath`, not the shortcut's target, which is its icon). It reaches its server from the VM's private network ("Online" in its status bar). Vid's rule puts it on workspace 4 (`~/.stumpwm.d/rules.lisp`, "FACTS on 4").

**Things to know before touching it:**
- The VM takes 6 GB: ask Vid before starting it, and never switch his workspaces to look at one; ask him to go there. `import -window` with an empty window id waits for a click and holds the pointer.
- Windows 11 Pro has one session: an app over RDP takes it from the SPICE console (`vikix windows`), which then shows the lock screen. A session that had the whole desktop open keeps Explorer running, and FreeRDP then mirrors its windows ("Program Manager", 1920x1080, override-redirect) too.
- FreeRDP 3.30: `/from-stdin` reads only from a terminal; Vikix passes every argument on stdin (`/args-from:stdin`). Its log is `~/.local/state/vikix/logs/windows-app.log`; its Kerberos "default realm" lines and `xf_rail ... TODO: implement` lines are noise.
- picom blurs behind see-through windows, and FreeRDP's override-redirect layers are see-through: the starter `picom.conf` leaves `vikix-win-*` out of the blur (0.71.183), and Vid's has the line too.
- The shares: `VirtioFsSvc` mounts `~/Windows` as `Z:` (tag `vikix-shared`) and `VikixDocuments` mounts `~/Documents` as `Y:` (tag `vikix-documents`), the same `virtiofs.exe` (`C:\Program Files\Virtio-Win\VioFS\`) with `-t TAG -m DRIVE`. Set their command lines in the registry (`ImagePath`), never with `sc.exe` from PowerShell: its quoting cut the path at its first space and both drives stopped (fixed 0.71.187). Both are visible in the user's session.

## 0. FACTS's message boxes don't show

FACTS draws some boxes ("are you sure?" on closing, a startup message) on a layer whose pixels each have their own transparency (Windows' per-pixel layered windows, `UpdateLayeredWindow`). Over RemoteApp, FreeRDP 3.30 makes the layer's window (32-bit, override-redirect, the main window's size) but every pixel arrives black and fully transparent, so the box is invisible and FACTS waits for an answer. Found 2026-10-05 with `xwd` on the layer. A window that fades as a whole (constant opacity) comes through in every setting tried (`-gfx`, `+aero`, `/bpp:24`, the progressive codec), so no FreeRDP option is the fix. To try: FACTS's own Themes menu (a plain theme may draw boxes without the layer); `sdl3-freerdp3`, which draws differently; and, if neither, FACTS as Windows' whole desktop over RDP in one tiled window (`vikix windows app facts --desktop`), where Windows draws everything itself.

## 1. See that the title bar sits below the bar (0.71.184)

The desktop says where the bar is (`_NET_WORKAREA`) and FreeRDP passes it to Windows (`/workarea`), so a maximized program's own title bar, its close button too, should come out below Vikix's bar. Tested in a hidden StumpWM, not yet on the real VM: open FACTS, and Edge from FACTS, and see that both title bars are below the bar. If not, the next things to try: `/monitors` with the bar's height left out, or StumpWM answering FreeRDP's move requests for these windows.

## 2. Windows shut down by itself, or kept running

Today the VM runs until `vikix windows stop`, holding 6 GB. A setting in `~/.config/vikix/windows`: `after-last-app = stop` (shut Windows down a few minutes after the last program's window closes, saying so first) or `keep` (the default today; on the Z13, with memory to spare, starting is then instant). The FreeRDP processes are Vikix's children, so the last one ending is easy to notice.

## 3. A file opened from Esploro in a Windows program

`mimeapps.list` entries offered (the user's file: written on a yes), so a `.xlsx` or a FACTS export opens in the Windows program, with LibreOffice still under "Open with". `vikix windows app NAME FILE` already maps `~/Windows` (Z:) and `~/Documents` (Y:); the `.desktop` files `apps add` writes already take `%f`.

## 4. New installs switch RemoteApp on by themselves

`lib/windows-firstlogon.cmd` gets what `apps setup` does through the guest agent: `fDenyTSConnections=0`, `UserAuthentication=1`, the `TSAppAllowList` keys, the Remote Desktop firewall group, and the second virtio-fs service for `~/Documents`. Then `apps setup` on a new VM only installs FreeRDP and keeps the password.

## 5. Smaller

- A notification when Windows has a program the launcher doesn't (a scan of the Start menu at each `app`, against `windows-apps.json`).
- The program's own icon in the launcher: extracted from its `.exe` through the guest agent (PowerShell's `System.Drawing.Icon::ExtractAssociatedIcon`), written to `~/.local/share/icons/`.
