# TODO: Windows programs

What is left for Windows programs in their own windows (`vikix windows app`, TODO item 82, `DESIGN-remoteapp.md`). Written 2026-10-05, after FACTS, the company ERP, first ran this way. Remove an item in the commit that ships it.

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
