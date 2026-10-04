# Vikix Windows apps — design

A Windows program's own window on the Linux desktop: Excel tiled beside Emacs, a `.xlsx` opened from Esploro, Outlook in the launcher, with the Windows VM out of sight.

Drafted 2026-10-04 for TODO item 82. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

`vikix add windows` gives a Windows 11 Pro VM, shown whole in a SPICE window (`vikix windows`). That is right for setting Windows up, and wrong for using one program in it: Excel lives inside a second desktop, with its own taskbar, its own Alt+Tab and its own idea of where windows go, and a file in `~/Documents` has to be found again from Windows' side. StumpWM can't tile, focus or put on a workspace a window that is drawn inside another window.

RDP has a mode for exactly this. RemoteApp sends one program's windows instead of the desktop, and FreeRDP draws each as an ordinary X window. That is what the WinApps project does on other Linux desktops, and every piece it needs is already in Vikix.

## What it is

- **`vikix windows app NAME [FILE]`**: Excel, Word, PowerPoint, Outlook (or any program the VM has) as a window of its own; a file is opened in it, its Linux path turned into the `Z:` path Windows sees it by. The VM is started first if it's off, and the window waits for Windows to be ready.
- **Launcher entries and file types**: `.desktop` files for the Office programs found in the VM, so they are in Super+d and Super+m, and `mimeapps.list` entries offered so a `.xlsx` opens in Excel from Esploro, with LibreOffice still under "Open with".
- **`vikix windows apps`**: what the VM has, from its Start menu, read through the guest agent; new Windows programs appear on the Linux side when it runs again.
- **Set up once** (`vikix windows apps setup`): Remote Desktop and RemoteApp switched on in the VM through the guest agent (registry and firewall), the account's password stored once, FreeRDP installed. A fresh `vikix windows create` does the same in its first-login script.

## How it is built

```
 Super+d "Excel" ─┐
 Esploro .xlsx ───┼─► vikix windows app excel [~/Documents/x.xlsx]
 vikix windows ───┘         │
                            ├─ VM off? virsh start, wait for the guest agent and RDP's port
                            ├─ the VM's address: guest agent, guest-network-get-interfaces
                            ├─ ~/Documents/x.xlsx → Z:\... only under ~/Windows; else copied? (see questions)
                            └─ xfreerdp3 /v:ADDR /u:USER /from-stdin /app:program:EXCEL.EXE
                                 /app:cmd:"Z:\..." /cert:tofu /clipboard /sound
                                 /dynamic-resolution /wm-class:vikix-win-excel
                                 password on stdin, from ~/.config/vikix/secrets/windows-password
```

**Switching RemoteApp on in an installed VM.** The guest agent (installed by the first-login script) runs, as SYSTEM: `fDenyTSConnections=0`, `fAllowUnlistedRemotePrograms=1` (HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList), Network Level Authentication on, and the Remote Desktop firewall group enabled for the private network only. The VM is on `virbr0`, so port 3389 is reachable from this machine alone; nothing is opened to the LAN. `lib/windows-firstlogon.cmd` gets the same lines for new installs.

**The password.** RDP needs the account's password, which Vikix asks for at `create` and keeps nowhere. `apps setup` asks for it once and keeps it in `~/.config/vikix/secrets/windows-password` (600, in the folder snapshots never record). Its name has no `_KEY` or `_TOKEN`, so `lib/secrets.sh` never exports it into the environment. FreeRDP reads it from standard input (`/from-stdin`): it is never on a command line, where `ps` would show it.

**One session.** Windows 11 Pro gives one session to one user. An app over RDP takes the account's session from the SPICE console, which then shows the lock screen; `vikix windows` (SPICE) takes it back. Both can be open, one at a time in use. This is how WinApps behaves too.

**Each app's window.** `/wm-class:vikix-win-NAME` gives each program a class of its own, so a rule can place it (`(when-window (:class "vikix-win-excel") (workspace 4))`) and `vikix rules remember` works on it. Several windows of one program come as several X windows from one FreeRDP; a second `app` call for a program already open starts a second connection, which RDP joins to the same session.

## Goals

1. **Excel in a window of its own** from Super+d, tiled like any other, in under 5 seconds when the VM is running and once Windows is ready when it isn't.
2. **A `.xlsx` opened from Esploro opens in Excel** when the user chose so, with LibreOffice one click away.
3. **Nothing new reachable from outside**: RDP on the private bridge only, the password never in the environment or on a command line.
4. **An installed VM gets it without reinstalling.**

## Non-goals (this version)

- **Not drag-and-drop** between Linux and Windows windows (RDP doesn't carry it); the clipboard and the shared `~/Windows` folder do.
- **Not Office itself.** Vikix doesn't install or license Office; it finds what the VM has.
- **Not a second user or more sessions**: Windows 11 Pro allows one.
- **Not the whole desktop over RDP.** SPICE stays for that.

## Requirements

### Must have (P0)

1. `vikix windows apps setup`: FreeRDP (`freerdp` in `optional/windows.list`), RemoteApp switched on through the guest agent, the password stored; idempotent, and says what it changed.
2. `vikix windows app NAME [FILE]`: start and wait, the address, the path mapping, FreeRDP with the password on stdin; a clear message when Windows isn't ready, the password is wrong, or the program isn't there.
3. `vikix windows apps`: the programs in the VM's Start menu (guest agent), and `.desktop` files written for the ones chosen (Office's four by default when found).
4. Tests with stand-ins for virsh, the guest agent and xfreerdp3: the argument list (never the password), the path mapping, the registry commands sent, the desktop files.

### Should have (P1)

5. `mimeapps.list` entries, offered (yours: written only on a yes).
6. A setting to keep the VM running after the last app closes (`~/.config/vikix/windows`: `keep=on`), for the Z13; off by default (6 GB of memory).
7. The first-login script switches RemoteApp on for new installs.

### Later (P2)

8. A scan on each run of what's new in the Start menu, with a notification.
9. Icons from the programs' own `.exe` (through the share), for the launcher.

## Open questions

Blocking:
- **Is Office installed in the VM, and which programs?** (Vid) If not, the first target is whatever Windows-only program the VM is there for.
- **A file outside `~/Windows`**: Windows sees only `Z:` (`~/Windows`). Options: refuse and say so; copy the file into `~/Windows/Open/` and back when Excel closes (a sync that can lose an edit); or share all of `~` as a second drive (simplest, but Windows then sees every file of yours). Proposed: share `~/Documents` (and the folder of the file) read-write as a second drive, `D:`, decided once at setup.
- **The password stored, or asked each time?** Proposed: stored once (as above); `vikix windows apps forget` deletes it.

Non-blocking:
- The licence: what Windows 11 Pro's licence says about RDP to the same machine's VM is Vid's to read.
- `sdl3-freerdp3` or `xfreerdp3`: X11's is the one StumpWM handles natively; SDL's draws its own windows under X too. Start with xfreerdp3.

## Phasing

**Phase 0, a day:** `apps setup` on this laptop's VM, and `vikix windows app` for one program with no file, by hand, measured: does Excel (or the program Vid uses) come up as a tiled window, does the clipboard cross, how long from a running VM.

**Phase 1:** P0 items 1–4, with the file question settled.

**Phase 2:** P1, then the Start-menu scan.

## Risks

- **RemoteApp on client Windows is unofficial.** `fAllowUnlistedRemotePrograms` works on 10 and 11 Pro and is what WinApps relies on, but an update could close it. The full desktop over SPICE remains.
- **Windows' first boot is slow** (a minute or more): `app` must say it's waiting, not look broken.
- **Session handover**: an app over RDP locks the SPICE console's session; switching back and forth asks for the password on the console. Said plainly in the guide.
