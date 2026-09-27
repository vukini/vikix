# Vikix

**Vikix** — [vikix.dev](https://vikix.dev) — is an opinionated desktop layer for **Void Linux**, built around **StumpWM**.

Think of it as Void, supercharged: inspired by Omarchy, but its own thing. It is not a new distribution: it is a script run on top of an ordinary Void install. What you get:

- a keyboard-driven StumpWM desktop
- a small set of programs that work together
- one command, `vikix update`, that keeps it all current

## Install

On a glibc Void install, logged in as your normal user. The install comes in two parts, so the long part never stands between you and a working desktop.

**Part one: the desktop.** The base system, the network, StumpWM and its config, and the login.

```sh
git clone https://github.com/vukini/vikix.git ~/vikix
cd ~/vikix
./install-1.sh --dry-run    # read what it would do
./install-1.sh              # do it
sudo reboot
```

Log in on tty1 and the desktop starts.

**Part two: everything else.** Editors, languages, apps, sound, laptop hardware. This is the long part. Run it from a terminal on the new desktop (Super+Return):

```sh
~/vikix/install-2.sh
```

Each part asks for your password **once**, at the start, and then runs by itself, so you can walk away. Part two says when it has finished with a notification. Everything each part prints is also kept in `~/.local/state/vikix/logs/`, and so is each `vikix update`.

`./install.sh` runs both parts one after the other, for a machine you just want to leave to it.

**Mirrors.** The install downloads 1–2 GB, and Void's default mirror is slow in much of the world. Part one first times the mirrors in `mirrors.list` and uses the fastest. To pick one yourself instead, name it:

```sh
VIKIX_MIRROR=https://mirror.accum.se/mirror/voidlinux ./install-1.sh
```

**If a stage fails.** Part one stops at the first stage that fails, because each of its stages needs the one before. Part two carries on with the rest and lists at the end what failed. Either way, the error names the stage. Fix the problem, then run just that stage:

```sh
./install.sh --only 30-lisp
```

Every stage checks before it changes anything, so re-running either part is safe. `./install.sh --list` shows which stage is in which part.

| Stage | Part | What it does |
|---|---|---|
| `00-preflight` | 1 | Checks this is glibc Void, and that you are not root. Notes any existing StumpWM config. |
| `05-mirror` | 1 | Downloads from each mirror in `mirrors.list` for six seconds and points xbps at the fastest (about a minute). Skipped if you set `VIKIX_MIRROR`, or already chose a mirror in `/etc/xbps.d/`. |
| `10-packages` | 1, 2 | Updates xbps itself, then installs what `packages/*.list` names, skipping anything already installed. Part one installs the core lists (base, desktop, network, lisp, cli); part two the rest. |
| `20-services` | 1, 2 | Enables the runit services in `services.list`, and adds you to the `video` group, and to `lpadmin` once CUPS is installed (with a polkit rule, so the Printers app needs no password). Before switching on a new service it has D-Bus reread its config, since Void's D-Bus only reads a new package's policy at boot, and a service started before that can't use it. `vikix update` runs it again, so a service that comes with a new package is switched on. |
| `25-network` | 1 | Starts NetworkManager, waits until it's running, then switches off dhcpcd and wpa_supplicant. Adds you to the `network` group. |
| `30-lisp` | 1 | Installs Quicklisp (and adds it to `~/.sbclrc`), clones clx-truetype (TrueType fonts for the bar, not in Quicklisp), builds `~/.local/bin/stumpwm` with Swank and clx-truetype inside, and clones `stumpwm-contrib`. |
| `40-config` | 1 | Links Vikix's config files into place and copies starter files you then own (including the keyboard file and the night light times). |
| `45-editors` | 2 | Clones the Emacs config (`vukini/emacs-void`) to `~/.emacs.d` and the Neovim config (`vukini/nvim-void-linux`) to `~/.config/nvim`, installs the npm language servers into `~/.local`, and installs Neovim's plugins. Other repos: set `VIKIX_EMACS_REPO` / `VIKIX_NVIM_REPO`. |
| `55-hardware` | 2 | Touchpad settings (tap to click, natural scrolling), the Intel microcode rebuilt into the initramfs, and the standard `~/Documents` … folders. |
| `50-audio` | 2 | Sets up PipeWire, WirePlumber and the ALSA links, as the Void handbook describes. |
| `60-login` | 1 | Adds `~/.local/bin` to PATH, loads the aliases in every shell, and makes X start after login on tty1. |
| `65-languages` | 2 | Builds the languages Void doesn't package (PicoLisp), builds Lazarus's docked IDE into `~/.lazarus`, and fetches the current Julia with juliaup. The packaged ones are lines in `packages/lang-*.list`. |
| `67-dev` | 2 | Makes `~/dev`: a folder per installed language, the docs page, and the Python environment JupyterLab runs on. It downloads the offline docs and Zeal docsets only when run by `vikix docs`; otherwise it lists what is missing. `vikix update` runs it again. |
| `70-vm` | 1 | Inside a VM only (VirtualBox, or KVM/QEMU such as virt-manager): installs the guest tools (shared clipboard, screen resizing). Does nothing on real hardware. |
| `90-finish` | 1, 2 | Marks existing migrations as applied, and prints what to do next. |

## Trying it in VirtualBox (from Windows)

A VM is the safe place to try each new version. These steps assume VirtualBox on Windows, and a plain glibc Void already installed in the VM.

### Once: set up the VM

**Let Windows reach the VM over SSH.** Power the VM off, then open **Settings → Network → Adapter 1** (NAT) → **Advanced → Port Forwarding**, and add one rule:

| Name | Protocol | Host Port | Guest Port |
|---|---|---|---|
| ssh | TCP | 2222 | 22 |

Leave both IP fields blank.

**Set two VirtualBox options.** Vikix can't set these from inside the VM:

- **Display → Graphics Controller: VMSVGA.** The screen then resizes with the window.
- **General → Advanced → Shared Clipboard: Bidirectional.**

**In the VM, switch SSH on and add the tools the copy needs:**

```sh
sudo ln -s /etc/sv/sshd /var/service/     # skip if `ls /var/service` already shows sshd
sudo xbps-install -Su xbps
sudo xbps-install -Su
sudo xbps-install -S git unzip
```

**Take a snapshot of this clean state.** Power off, then choose **Snapshots → Take** and call it `void-clean`. Every later round starts from here.

### Each round: copy in a version and install

From **PowerShell on Windows**, in the folder holding the zip. Replace `you` with your Void username:

```powershell
cd $HOME\Downloads
scp -P 2222 vikix-0.9.0.zip you@127.0.0.1:~/
ssh -p 2222 you@127.0.0.1
```

The `ssh` session is a terminal into the VM in which paste works. In it:

```sh
unzip ~/vikix-0.9.0.zip -d ~
cd ~/vikix
./install-1.sh
sudo reboot
```

Then log in on **tty1 in the VirtualBox window itself**. The desktop starts there; the SSH session has no screen. Open a terminal (Super+Return) and run part two:

```sh
~/vikix/install-2.sh
```

**Snapshot after part one.** Power off and take a snapshot then, so a later round can start from a working desktop.

### Upgrading a VM that already has Vikix

Copy the new zip in the same way, then **keep the same folder**, `~/vikix`. Your config links point into it.

```sh
rm -rf ~/vikix
unzip ~/vikix-0.9.0.zip -d ~
cd ~/vikix
./install.sh            # safe to re-run: finished steps are skipped, new migrations run at the end
```

Then log out and back in on tty1. To start from scratch instead, restore the `void-clean` snapshot.

### If something doesn't work

| Symptom | Likely cause |
|---|---|
| `scp` says "Connection refused" | The port-forwarding rule is missing, or `sshd` isn't running in the VM (`ls /var/service`). |
| `scp` says "REMOTE HOST IDENTIFICATION HAS CHANGED" after reinstalling Void in the VM | Run `ssh-keygen -R "[127.0.0.1]:2222"` in PowerShell, then try again. |
| The screen doesn't follow the window size | Graphics Controller isn't VMSVGA, or the VM hasn't been rebooted since `70-vm`. |
| Copy and paste doesn't cross between Windows and the VM | Shared Clipboard is off: **Devices → Shared Clipboard → Bidirectional**. |

## Trying it in virt-manager (KVM, from Linux)

The repo is public, so the VM clones it directly; nothing is copied in by hand. Install a plain glibc Void in the VM first.

**In virt-manager, before the install.** Open the VM's details (the light-bulb icon) and check:

- **Display: Spice**, and **Video: Virtio** (or QXL). The screen then resizes with the window; also tick **View → Scale Display → Auto resize VM with window**.
- **Channel `com.redhat.spice.0`** (shared clipboard and resizing) and **Channel `org.qemu.guest_agent.0`** (clean shutdown from the host). New VMs usually have both; if not, **Add Hardware → Channel**.

**In the VM, as your normal user:**

```sh
sudo xbps-install -Syu xbps
sudo xbps-install -S git
git clone https://github.com/vukini/vikix.git ~/vikix
cd ~/vikix
./install-1.sh
sudo reboot
```

Log in on tty1, then run part two from a terminal (Super+Return): `~/vikix/install-2.sh`.

**Later versions** arrive with `vikix update`, which pulls from GitHub and then reloads StumpWM, so new keys, bar and menu work at once. The only password it asks for is your own, for sudo: it reads GitHub over HTTPS, which needs no login, even when a checkout's remote is SSH (`git@github.com:`, as in a clone you push from), so no key passphrase is asked either. The remote itself is left as it is.

| Symptom | Likely cause |
|---|---|
| `70-vm` says a channel is missing | Add it as above, then run `~/vikix/install.sh --only 70-vm` and log in again. |
| The screen doesn't follow the window size | Display isn't Spice, Video isn't Virtio/QXL, or "Auto resize VM with window" is off. |
| Copy and paste doesn't cross between host and VM | No `com.redhat.spice.0` channel, or you haven't logged in again since `70-vm`. |

## Who owns which file

Every config file belongs either to Vikix or to you:

- **Vikix's files** are symlinks into this checkout, and `vikix update` refreshes them:
  - `~/.stumpwm.d/init.lisp`
  - `~/.stumpwm.d/vikix/`
  - `~/.xinitrc`
  - `~/.local/bin/vikix` and its helpers (`vikix-lock`, `vikix-osd`, `vikix-screenshot`, `vikix-record`, …)
  - `~/.config/vikix/vikix.bash`, the aliases and prompt
  - `~/.claude/skills/vikix`, which tells Claude Code how Vikix works
  - `~/.config/fontconfig/conf.d/50-vikix-iosevka.conf`, the monospace font
- **Your files** are copied once, then never touched again:
  - `~/.stumpwm.d/user.lisp`, which loads last, so anything in it wins
  - the configs under `~/.config` for alacritty, picom, dunst and rofi
  - `~/.config/vikix/keyboard`: layout and XKB options, applied at every login. The starter swaps Caps Lock and Left Ctrl (`ctrl:swapcaps`); edit it, then `s-m` → "Apply keyboard settings". For Esperanto, it explains the options that put ĉ ĝ ĥ ĵ ŝ ŭ on Right Alt + c g h j s u, leaving every other key alone
  - `~/.config/vikix/backup-exclude`: what `vikix backup` leaves out
  - `~/.Xresources`: text size. Raise `Xft.dpi` on a high-resolution screen (144 for a 14" 2.8K panel), then log in again

`config/yours.list` names your files, and Vikix keeps a history of them (see [Undo](#undo-for-your-files)).

If you already had a StumpWM config, it becomes your `user.lisp`. Anything else Vikix has to replace is moved aside to `<name>.vikix-bak.<time>`, never deleted.

## Keys

`s` means Super. StumpWM's own `Ctrl+t` prefix keys still work too. Focus follows the mouse: pointing at a window focuses it, without a click. To click instead, put `(setf *mouse-focus-policy* :click)` in `user.lisp`.

| Key | What it does |
|---|---|
| `s-Return` | Terminal |
| `s-d` | Launcher |
| `s-w` | Browser (Firefox) |
| `s-e` | Files (PCManFM) |
| `s-E` | Files in SpaceFM (tabs, split panes) |
| `s-C-e` | Eject a USB drive: pick it, and a notification says when it's safe to pull out |
| `s-a` | AI agent: Claude Code in a terminal |
| `s-x` | Emacs: a new window (the Emacs server is already running) |
| `s-c` | Clipboard history: pick something copied earlier, then paste it |
| `s-.` | Emoji: search by name (heart, cat, thumbs up); Enter types it into your window and copies it, `Ctrl+c` only copies |
| `s-=` | Calculator that answers as you type: `340 * 12%`, `5 ft to cm`, `100 USD to EUR`, `today + 30 days`. Enter copies the answer |
| `s-n` / `s-N` | Notifications: the last one again / pick an earlier one (rofi) |
| `s-C-n` / `s-M-n` | Notifications: close all / do not disturb on and off (the bar says `quiet`, and how many are waiting) |
| `s-q` | Close window |
| `s-f` | Fullscreen |
| `s-h` `s-j` `s-k` `s-l` | Move focus left, down, up, right |
| `s-H` `s-J` `s-K` `s-L` | Move the window |
| `s-←` `s-↓` `s-↑` `s-→` | Focus, on the arrows (in a VM on Windows, Super+L locks the host instead of reaching the guest) |
| `s-C-←` `s-C-↓` `s-C-↑` `s-C-→` | Move the window, on the arrows |
| `s-b` | Split side by side |
| `s-v` | Split one above the other |
| `s-r` | Remove the split |
| `s-u` / `s-U` | Undo / redo the last layout change on this workspace (splits, moves, closes) |
| `s-g` | Gaps around windows, on or off (off at login) |
| `s-A` | Any window on any workspace: pick one and go there |
| `s-C-a` | Any window on any workspace: pick one and bring it here |
| `s-p` | Move the mouse pointer to the focused window |
| `s-1`…`s-9` | Go to a workspace |
| `s-C-1`…`s-C-9` | Send the window to a workspace |
| `s-m` | Vikix menu: key help, all commands, "what does a key do?", themes, network, printers, backup now, screens, update, and Power (the same as `s-S-Escape`) |
| `s-F1` | Every key, searchable. Pick one to run it. |
| `s-Escape` | Lock the screen |
| `s-S-Escape` | Power: lock, suspend, log out, reboot, power off (Lock first, so a stray Enter is harmless) |
| `s-M-a` | Keep awake on/off: no lock, dark screen or suspend while you watch or present (the bar says `awake`) |
| `s-M-l` | Night light on/off: a warmer screen in the evening |
| `Print` | Screenshot an area (drag one out, or click a window) to the clipboard |
| `C-Print` | Screenshot the focused window to the clipboard |
| `s-Print` | Screenshot the whole screen (the monitor the pointer is on) to the clipboard |
| `Shift` with any of those | The same, to a file in `~/Pictures/Screenshots` instead |
| `s-R` | Record an area or a window, without sound; press again to stop. The bar says `rec`, and the video goes to `~/Videos/Recordings` |
| `s-C-Print` | Screenshot or record: a menu of all of them, including recording the whole screen |
| volume and brightness keys | Change the level and show a bar for it |

## The bar

Along the top, in Iosevka like the terminal: on the left the workspaces in use (the current one in brackets) and this workspace's windows, numbered, the focused one in the accent colour; on the right, from left to right:

- **rec**, in the theme's alert colour, while the screen is being recorded (`s-R` stops it).
- **awake**, in the theme's quieter text colour, while keep awake is on (`s-M-a`).
- **quiet**, in the quieter text colour, while do not disturb is on (`s-M-n`), with the number of notifications waiting: they show when you switch it off.
- **updates**, in the theme's accent colour, when `vikix update` has something to bring: `updates 12` (Void packages), `updates 12 + Vikix`, or `Vikix update`; and `+ firmware` (or `firmware` alone) when a firmware update is waiting (see [Firmware updates](#firmware-updates)). Checked a minute after you log in and then every 6 hours, in the background (`vikix-updates`); `vikix update` clears it. Nothing shows when there's nothing, or when it couldn't check (offline).
- **usb**, in the accent colour, while a USB drive is mounted: eject it (`s-C-e`) before pulling it out.
- **backup 9d**, in the accent colour, once backups are set up and the last one is older than a week (`backup` alone: set up, but none yet). See [Backups](#backups).
- the network: `wifi` and the network's name (and its signal when it is weak, under 60%), `wired`, or `offline`
- Bluetooth, when it's on: `bt`, or the connected device and its battery, `bt WH-1000XM4 80%` (`+1` for another); nothing when it's off or there is none (`vikix-bt`). `s-m` → Bluetooth pairs and connects
- the volume: `vol 40%`
- the battery, on a laptop: `bat 84%`, with a `+` while charging; nothing when it is full on the charger
- the date and time

Each colour means one thing: alert (red in void) is something watching you, accent is something to act on, and the quieter colour is a mode you switched on yourself.

## Themes

One theme colours the whole desktop: StumpWM and its bar, the terminal (alacritty, and kitty if you want it), rofi, notifications, the lock screen and the wallpaper. Two come with Vikix: **void** (dark, the default) and **paper** (light).

```sh
vikix theme           # the current theme, and the list
vikix theme paper     # switch, everywhere, now; kept for the next start
```

Or `s-m`, then Theme. Open alacritty windows change at once; rofi and the lock screen use the new colours from their next start.

- **A theme is a file of colours:** `themes/void.theme` shows every name. `sel`, the colour behind selected text and rows, may be left out; `color0` stands in. Copy it to `~/.config/vikix/themes/mine.theme`, change the colours, and `vikix theme mine`.
- **How the programs get them:** `vikix theme` writes each program's colours into `~/.config/vikix/theme/`, and your configs include those files. Your `alacritty.toml` imports `alacritty.toml` from there, and rofi's `config.rasi` names `rofi.rasi`; dunst reads `~/.config/dunst/dunstrc.d/10-vikix-theme.conf` by itself. For kitty, add `include ~/.config/vikix/theme/kitty.conf` to your `kitty.conf`.
- **The wallpaper** follows the theme until you choose one: `s-m` → Wallpaper shows a picker with pictures, from Vikix's themes, `~/Pictures/Wallpapers` and `~/wallpapers`. Its first entry, **Theme**, goes back to following the theme, and its last, **My own tool**, stops Vikix touching the wallpaper at all, for feh, nitrogen or a script that rotates pictures; machines that had one of those before 0.25.0 are set that way by the update. From a shell: `vikix-wallpaper FILE`, `vikix-wallpaper theme`, `vikix-wallpaper off`. `vikix update` never changes the wallpaper. A theme's own wallpaper is the picture beside its theme file with the same name (`mine.jpg` next to `mine.theme`); a theme without one gets a plain background in its colour. Vikix's two were drawn by `lib/make-wallpaper.py`.
- **Keeping colours of your own** in one program: set them in its config (for dunst, in a drop-in that sorts after `10-vikix-theme.conf`, like `90-mine.conf`). Your own colours win there, and the rest still follows the theme.

## Changing the window manager while it runs

The StumpWM executable has Swank built in, and it listens on `127.0.0.1:4004`. From Emacs:

```
M-x slime-connect RET 127.0.0.1 RET 4004
```

That puts you at a REPL inside the running window manager. Anything you redefine there takes effect at once.

If Emacs says the SLIME and Swank versions differ, answer `y`. It still works. The two come from different places: Emacs's package manager for SLIME, and Quicklisp for Swank.

## The AI agent

Vikix is set up for an AI agent to work on the desktop with you, the way Omarchy is. The agent is [Claude Code](https://claude.com/claude-code).

- **`s-a`**, or **`a`** in a shell, starts Claude Code. The first time, it offers to install it with Anthropic's installer (`curl -fsSL https://claude.ai/install.sh | bash`, into `~/.local/bin`).
- **The Vikix skill** (`config/claude/skills/vikix/SKILL.md`, linked to `~/.claude/skills/vikix`) tells the agent how Vikix is put together: Void's xbps and runit, which files are Vikix's and which are yours, the keys, and the commands below. Its main rule: change your files (`user.lisp` and the rest), never Vikix's own.
- **`vikix eval`** lets the agent (or you) run Lisp inside the running StumpWM and read the answer. That is how it can look at your windows and workspaces, or try a key or a theme live, before writing it into `user.lisp`:

  ```sh
  vikix eval '(mapcar (function group-name) (screen-groups (current-screen)))'
  vikix eval '(vikix-apply-theme :paper)'
  vikix eval '(loadrc)'          # reload the config after editing user.lisp
  ```

  It talks to Swank on port 4004. Errors come back as `error: ...`; they never leave it hanging. A menu or prompt that is open makes it give up after 10 seconds.
- **Undo.** Before each agent session, Vikix takes a snapshot of your files. See below.

## Undo for your files

Vikix keeps a history of your files (the ones in `config/yours.list`: `~/.stumpwm.d/`, the configs under `~/.config`, `~/.bashrc`, `~/.bash_profile`). It is a git repository in `~/.local/state/vikix/yours.git`, so no `.git` folder appears in your home.

```sh
vikix snapshot "trying a new theme"   # record your files as they are now
vikix changes                         # what changed since the last snapshot
vikix history                         # the snapshots, newest first
vikix undo                            # back to how they were one snapshot ago
vikix undo 3f2a1bc                    # back to a given snapshot
```

A snapshot is taken after every install or `vikix update`, and before every agent session. An undo is a snapshot too, so running `vikix undo` twice puts things back. After an undo, reload StumpWM (`s-m` → *Reload config*) to use the old settings.

This history is for your settings, on this machine. For everything else, and for a lost laptop, see [Backups](#backups).

## Backups

`vikix backup` backs up your whole home folder with [restic](https://restic.net): encrypted, and only what changed since the last time, so after the first one a backup takes minutes. It leaves out what can be downloaded or rebuilt again: caches, the bin, the languages' package caches, node_modules, what Vikix installs (Emacs and Neovim plugins, the offline docs, the StumpWM build) and virtual machine disks. The list is `~/.config/vikix/backup-exclude`, yours to edit.

**Once: set up a drive.** Plug in a USB drive (it mounts by itself, under `/run/media/$USER`), then:

```sh
vikix backup setup /run/media/$USER/DRIVE
```

It makes a `vikix-backup` folder on the drive and a password for the backups, and shows the password once. **Write it down, away from the laptop:** the backups can't be read without it, and the copy in `~/.config/vikix/backup-password` is lost with the laptop. Any place restic knows works too, like `sftp:you@server:/backups` or a cloud bucket.

**Then, now and then:**

```sh
vikix backup                     # back up now (or s-m → Backup now, which tells you when it's done)
vikix backup status              # where, and when the last one was
vikix backup list                # the backups
vikix backup restore ~/Documents/letter.odt   # bring it back from the latest backup
vikix backup restore ~/Pictures 3f2a1bc       # ... or from an earlier one
```

A restore goes into `~/Restored/<time>/`, beside your files, never over them; move back what you want. **Plug in to back up:** when the backup drive is plugged in and a backup is due (none yet, or the last is older than the reminder's days), it starts by itself and says when it's done. Otherwise nothing runs by itself: the bar says `backup 9d` once the last backup is more than a week old, as a reminder to plug the drive in. Change the days with `DAYS=` in `~/.config/vikix/backup`, or stop the reminder with `vikix backup off` (the backups stay on the drive). Old backups thin out as new ones come: one a day for a week, one a week for a month, one a month for a year. `vikix backup check` reads them back to make sure they are sound.

## What gets installed

| List | Contents |
|---|---|
| `base` | dbus, elogind, polkit and its password box, openssh, chrony (clock), git, curl, rsync, zip, 7zip, man pages, xdg-utils, python3 (for `vikix eval`) |
| `desktop` | X11, picom, dunst, rofi (with its emoji picker and calculator), alacritty, fonts (Noto, colour emoji, Nerd Font symbols), i3lock, gammastep (night light), screenshots and screen recording (maim, slop, ffmpeg), clipmenu (clipboard history) |
| `fonts` | Iosevka, the terminal font. Every variant comes in one 862 MB package, so it waits for part two; until then the terminal uses a plain monospace font, and the bar Noto Sans Mono. Also fonttools, which `vikix-font` uses to take the one Iosevka the bar needs out of that package. |
| `network` | NetworkManager (`nmtui` for Wi-Fi), with its connection editor |
| `audio` | PipeWire, WirePlumber (with Bluetooth audio), pamixer, pavucontrol |
| `laptop` | tlp, fwupd (firmware updates), acpid, brightnessctl, xprintidle (suspend when idle on battery), Bluetooth (bluez, blueman), autorandr, and the firmware a recent ThinkPad needs: sof-firmware (sound), intel-ucode (from the nonfree repo, enabled by `repos.list`), intel-video-accel |
| `printing` | CUPS with its filters, system-config-printer (and cups-pk-helper, so it needs no root), avahi and nss-mdns (finding network printers), ipp-usb (driverless USB printers), and drivers for older printers: gutenprint, foomatic, brlaser |
| `editors` | Emacs, Neovim, the pdf-tools build deps, the `tree-sitter` CLI (Neovim builds its parsers with it), and the language servers Void packages (ccls, lua-language-server, gopls, efm-langserver) plus nodejs for the npm ones |
| `apps` | Firefox, PCManFM, USB drives that mount when plugged in (udisks2, udiskie; gvfs-mtp for Android phones), SpaceFM, mpv, nsxiv, zathura, Foliate (EPUB), LibreOffice (Writer, Calc, Impress, Draw, Math), Zeal (offline docs) |
| `dev` | base-devel (gcc, make), gdb, valgrind, rlwrap |
| `cli` | htop, ripgrep, fd, fzf, bat, eza, tmux, tree, jq, zoxide, yazi, lazygit, gh (GitHub CLI), restic (for `vikix backup`), atuin (with bash-preexec) |
| `lisp` | SBCL |
| `lang-*` | One file per language, so a language is one file to keep or delete: C extras (tcc, rr, cmake, meson, ninja, shellcheck, shfmt, the C and POSIX man pages), Python (pip, ipython, pipx, uv), Lisp and Scheme (ccl, racket and its docs, chez-scheme, guile), Haskell (ghc and its docs, cabal, HLS, hlint), Forth (gforth), WebAssembly (wabt, wasmtime), Ruby (with `ri` docs), SQLite (sqlite, litecli, sqlitebrowser), Lua (lua54, LuaJIT), Go, Zig (zig, zls), Rust (with rust-analyzer and the docs), Java (openjdk21, gradle), OCaml (dune, ocamlfind, opam), Julia (juliaup), Pascal (fpc, Lazarus), and `lang-tools` (ctags, entr, hyperfine, tokei, just) |

## Laptop

- **Docking.** Arrange the monitors once with `s-m` → *Screens: arrange*, then `s-m` → *Screens: save this layout* and call it `default` (or `desk`, `home` …). autorandr re-applies the matching layout whenever those monitors are plugged in, and at login.
- **Away from the keyboard.** After 10 minutes the screen locks, after 11 it goes dark, and after 20, on battery only, the computer suspends. Change the minutes in `~/.config/vikix/idle` (`LOCK=10`, `SCREEN_OFF=11`, `SUSPEND=20`, and `SUSPEND=0` never suspends), then log in again. **Keep awake** (`s-M-a`, or `s-m` → Keep awake) stops all three for a film or a talk; the bar says `awake`, and every login starts with it off.
- **Night light.** From 19:00 the screen warms over an hour, and from 6:00 it cools again (gammastep). The times and colours are in `~/.config/gammastep/config.ini`: by the clock, not the sun, so no location is needed. `s-M-l` (or `s-m` → Night light) switches it off, and it stays off at the next login until you switch it on.
- **Suspend** from the power menu (`s-S-Escape`, or `s-m` → Power) or by closing the lid; the screen locks first. **Log out**, **Reboot** and **Power off** are there too, through elogind, no sudo.
- **Touchpad**: tap to click, natural scrolling, off while typing (`/etc/X11/xorg.conf.d/40-libinput.conf`, installed by `55-hardware`).
- **Battery.** `vikix-battery` warns at 15% and again, urgently, at 5% (change them with `VIKIX_BATTERY_LOW` / `VIKIX_BATTERY_CRITICAL`). It only starts on a machine with a battery; `vikix-battery --once` shows the charge.
- **High-resolution screen.** Set `Xft.dpi` in `~/.Xresources` (see the file for values), then log in again.
- **Which program opens what** is `~/.config/mimeapps.list`, yours after the first copy: Firefox for links, zathura for PDFs, nsxiv for images (through `vikix-image`, so the rest of the folder is a key press away: `n` / `p`, or Enter for thumbnails), mpv for video and audio.

## Firmware updates

Laptop makers publish firmware updates on [LVFS](https://fwupd.org): for a ThinkPad, the BIOS, Thunderbolt, docks and the fingerprint reader. fwupd installs them; `vikix firmware` is the short way in.

```sh
vikix firmware            # fetch the latest list and show what's waiting
vikix firmware update     # install it (or s-m → Firmware updates)
vikix firmware devices    # what fwupd knows about, with each one's version
```

- **Keep the charger in.** `vikix firmware update` won't start on battery: a firmware update that loses power halfway can leave a device that doesn't start. Don't turn the computer off while it runs.
- **Some updates finish during a reboot.** The BIOS is one: fwupd asks before restarting, and the screen can stay dark for a minute or two while it installs.
- **The bar** says `firmware` (or `updates 12 + firmware`) when something is waiting: `vikix-updates` asks LVFS every 6 hours.
- **Passwords:** none for the check. Signed firmware from LVFS, which is nearly all of it, installs without one; so does the laptop's own firmware (the BIOS), since you're in `wheel` at the machine itself (fwupd's polkit rules). Anything else asks for your password once.
- **"UEFI ESP partition not detected"**: fwupd didn't find the EFI partition, which BIOS updates are staged on. If it's mounted somewhere unusual, set `EspLocation=` in `/etc/fwupd/fwupd.conf` to that folder.

## USB drives

A USB drive mounts by itself when it's plugged in, under `/run/media/$USER/NAME`, and a notification says so, with a button to open it in PCManFM. `vikix-drives start` runs udiskie at every login; nothing needs a password.

- **Eject** with `s-C-e` (or `s-m` → *Eject a drive*): pick the drive, and it's unmounted and powered off; a notification says when it's safe to pull out, or which drive is still in use.
- **Encrypted (LUKS) drives** ask for their passphrase in a rofi prompt, then mount like any other; ejecting locks them again.
- **The bar** says `usb` while a drive is mounted.
- **Android phones** show in PCManFM (gvfs-mtp); on the phone, choose "File transfer" when it asks.
- **Your own udiskie settings:** write `~/.config/udiskie/config.yml` and Vikix's (`config/udiskie/config.yml`, which only chooses the notifications) is no longer used.

## Printing

Part two installs CUPS and switches it on, with avahi to find printers on the network.

- **Add a printer:** `s-m` → *Printers*. A printer on your network shows up by itself, and so does a USB printer that works with AirPrint (through ipp-usb). When it offers a driver, pick the driverless one ("IPP Everywhere"). From your next login you are in the `lpadmin` group, so neither it nor `lpadmin` asks for a password (a polkit rule, `/etc/polkit-1/rules.d/50-vikix-printers.rules`, lets that group manage printers at the machine itself).
- **Print** from any program's Print dialog, or from a terminal: `lp file.pdf`. `lpstat -p` lists the printers, `cancel` stops a job.
- **An older printer** may need a driver. gutenprint, foomatic and brlaser (Brother lasers) are installed. For HP, `xi hplip`, then `hp-setup -i`; for Epson inkjets, `xi epson-inkjet-printer-escpr`.
- **CUPS's own page**, http://localhost:631, shows every printer and its queue.

## Editors

Both configs are separate repositories, cloned by `45-editors` and pulled by `vikix update`; Vikix never edits them.

- **Emacs** — `~/.emacs.d` is [vukini/emacs-void](https://github.com/vukini/emacs-void). `vikix-session` starts `emacs --fg-daemon` at login, so `e` (`emacsclient -c -a ""`) opens a frame at once. The first start on a new machine installs the packages from MELPA in the background; give it a few minutes before the first `e`. SLIME connects to StumpWM on port 4004.
- **Neovim** — `~/.config/nvim` is [vukini/nvim-void-linux](https://github.com/vukini/nvim-void-linux), an [AstroNvim](https://astronvim.com) v5 setup. Plugins are installed by the stage to the versions in `lazy-lock.json`; on the first start, Mason adds the tools the config names (stylua, debugpy, tree-sitter-cli) in the background. `v` opens it.
- **Language servers** on PATH for both: `ccls`, `lua-language-server`, `gopls`, `efm-langserver` from Void; `typescript-language-server`, `pyright`, `bash-language-server` from npm in `~/.local/bin`.

## Languages

Vikix is for playing with languages, so it installs them. Each is a small file in `packages/`; delete the file to drop the language, add a line to add a tool.

| Language | Packages | Try |
|---|---|---|
| C | gcc and friends (`base-devel`), clang, clangd, gdb, valgrind, tcc, rr, cmake, meson, ninja | `tcc -run hello.c` |
| Python | python3, pip, ipython, pipx, uv; JupyterLab in `~/dev/python/.venv` | `ipython`, `jlab` |
| Common Lisp | sbcl (with Quicklisp), ccl; SLIME in Emacs, Swank into StumpWM on 4004 | `sbcl` (rlwrap'd) |
| Scheme, Racket | racket, chez-scheme, guile | `racket`, `scheme`, `guile` |
| PicoLisp | built from source by `65-languages` into `~/.local/opt/picolisp` | `pil +` |
| Haskell | ghc, cabal, haskell-language-server, hlint | `ghci` |
| Forth | gforth | `gforth` |
| WebAssembly | wabt, wasmtime | `wat2wasm x.wat && wasmtime x.wasm` |
| JavaScript | nodejs | `node` |
| Ruby | ruby | `irb` |
| SQL | sqlite, litecli, sqlitebrowser | `litecli db.sqlite` |
| Lua | lua54, LuaJIT | `lua5.4` |
| Go | go, gopls | `go run .` |
| Zig | zig, zls | `zig run x.zig` |
| Rust | rust, cargo, rust-analyzer, rust-src; the Rust book and the standard library docs offline (rust-doc) | `cargo new hi && cd hi && cargo run` |
| Java | openjdk21 (java, javac, jshell), gradle | `jshell` |
| OCaml | ocaml, dune, ocamlfind, opam (`opam install utop ocaml-lsp-server` for a better REPL and the language server) | `ocaml` |
| Julia | juliaup, and the current Julia it fetches | `julia` |
| Free Pascal | fpc and its sources; Lazarus, built with the docked IDE: one window that StumpWM tiles, with its dialogs floating | `fpc hello.pas`, `vikix-lazarus` |

Language servers for the editors are in `editors.list` and `45-editors`.

### `~/dev`: your projects, the docs offline, and examples

`67-dev` makes a folder for each installed language. `vikix docs` then downloads each one's documentation into it, so it works with no network. The installer and `vikix update` leave the downloads out, because they are a few GB from sites that are sometimes very slow; run `vikix docs` when you have the time, and again later to add a new language's docs.

```
~/dev/
  index.html         every doc below on one page (`docs` opens it)
  docsets -> Zeal's docsets
  python/  docs/python-3.x-docs-html/     .venv/  (JupyterLab)
  lisp/    docs/HyperSpec/
  racket/  docs/racket -> the racket-doc package
  haskell/ docs/ghc    -> the ghc-doc package
  lua/     docs/manual.html
  zig/     docs/langref-<version>.html    (`zig std` for the library)
  sql/     docs/sqlite-doc-<version>/
  rust/    docs/rust   -> the rust-doc package (the book, std)
  c/ go/ forth/ ruby/  docs/README.md     (man 3, go doc, info gforth, ri)
  java/ ocaml/ julia/ pascal/  docs/README.md   (jshell, man ocaml, ? in julia, Lazarus F1)
```

Every language also has a **Zeal** docset (Bash too): open Zeal (`s-m` → "Zeal"), type, and it searches them all. Emacs finds the same docsets through `~/.docsets`, the default folder of `dash-docs`.

**Disk space.** With every language installed it comes to about 5 GB: the Zeal docsets roughly 3.4 GB (Racket's alone is 0.6 GB; Rust's, Java's and Julia's add about 1 GB), the `ghc-doc`, `racket-doc` and `rust-doc` packages 1.6 GB, the Python environment 0.5 GB, the HTML docs under 0.1 GB. A download that crawls (under 10 KB/s for a minute) is skipped with a warning, and the next `vikix docs` tries it again.

**Examples to build and change.** Each language gets small programs in `~/dev/<language>/examples/`, one per folder, each with a README and a `Makefile` that works the same everywhere: `make` builds, `make run` runs, `make clean` tidies. Inside, the Makefile calls the language's own tool (cargo, go, lazbuild, …), whose files are there too, so you learn the real thing. Every language has the same three:

- `hello` — the smallest program that builds
- `wordfreq` — the ten most common words in the Gettysburg Address; every language prints exactly the same thing (`make check`), so two can be compared side by side
- one showing what the language is known for: C a linked list with `make check` under valgrind, Rust errors as `Result`, Go goroutines, Free Pascal a Lazarus window, Python the Game of Life with generators, Zig `comptime` with its tests, Haskell infinite lazy lists, OCaml a calculator built on variants and pattern matching, Java records and sealed interfaces, Julia multiple dispatch, Common Lisp macros (with their expansions printed), Scheme `call/cc` and tail calls, Racket a picture drawn by a recursive function, PicoLisp its built-in database, Forth a defining word that makes words (`2 km 350 m +`), JavaScript a web server asked three things at once, Ruby blocks and methods written at run time, Lua metatables, SQL a small library database queried with joins, WebAssembly a sandbox that decides which files a program may open

They are copied once, so they are yours to change; an update adds new ones and never touches one you have. Every language has them, all twenty. Each builds with the language's own tool: make, cargo, go, fpc and lazbuild, zig build, cabal, dune, Gradle, SBCL's compile-file, Chez's compile-program, raco make, wat2wasm and zig cc for WebAssembly, and SQLite builds the library's database; Python, Julia, JavaScript, Ruby, Lua, PicoLisp and Forth run as they are. `wordfreq` is written twenty ways, and in SQL it's a single query.

**A README for each language**, `~/dev/<language>/README.md`: a table of its tools on this machine (compiler, build tool, debugger, language server, formatter, linter), each with where it is and which version, or "not installed"; where to start; and the official site, source code, package registry, and free books and tutorials, every link checked. Every update writes it again, so it stays true; keep notes of your own in another file. A `README.md` there that you wrote yourself is left alone.

Only installed languages get a folder. `~/dev` is yours: Vikix only adds to it, and never deletes or overwrites anything there except `index.html`.

### Python and JupyterLab

`jlab` (or `s-d` → JupyterLab, or `s-m` → "JupyterLab") starts JupyterLab in `~/dev`, and it opens in the browser. If it is already running, its page opens again. The Python behind it is `~/dev/python/.venv`, made with `uv` and ready with jupyterlab, numpy, pandas, matplotlib, scipy and sympy. To add a library:

```sh
uv pip install --python ~/dev/python/.venv polars
```

It is a separate environment because Void's own Python won't take `pip install`. When Void moves to a new Python version, `vikix update` makes the environment again.

**Not automated.** Two things you install by hand, the way they are on the X1 now:

- **Cuis Smalltalk** — download a release bundle from the Cuis-Smalltalk-Dev GitHub page into `~/apps/`, and keep your `cuis` launcher script from `vukini/dotfiles` (it pins `-ud` so user files stay out of `$PWD`).
- **Odin** — prebuilt binaries into `~/bin/odin-bin`, on PATH from `.bashrc`. `ols` is its language server; the Emacs config already maps it.

## Shell aliases

These come from `~/.config/vikix/vikix.bash`. Type `alias` to see them all.

| Alias | Does |
|---|---|
| `ll` `la` `lt` | Long list, list with hidden files, tree (eza) |
| `..` `...` `....` `cd-` `d` | Up one, two, three folders; back to the previous one; the folder stack |
| `z NAME` / `zi` | zoxide: go to a folder you've been to, by part of its name / pick from a list |
| `y` | yazi, the file manager; quit with `q` and the shell stays where you were looking |
| `v` / `e` | Neovim / Emacs (starting an Emacs server if none is running) |
| `eg` / `ec` | Emacs in a new window, leaving the terminal free / Emacs inside the terminal |
| `nvd A B` | Neovim diff of two files |
| `eq`, `ekill`, `emacs-restart` | Emacs with no config (for debugging it), stop the daemon, restart it (refuses with unsaved buffers) |
| `b` | bat: `cat` with colour. Plain `cat` is left alone. |
| `mkd` `cpr` `chx` `xo` | `mkdir -p`, `cp -r`, `chmod +x`, open with the usual program |
| `psg NAME` / `hg WORD` | find a running process / a line in your history |
| `r` / `bb` | reload `~/.bashrc` / edit it (`bb` is left alone if babashka is installed) |
| `xi` `xu` `xr` `xs` `xl` | xbps: install, update everything, remove, search, list a package's files |
| `svls`, `sv-on NAME`, `sv-off NAME` | runit: list services, switch one on, switch one off |
| `g` `gst` `gl` `gla` `gd` `gds` | git, status, log graph (this branch / all), diff (unstaged / staged) |
| `ga` `gaa` `gcm` `gca` `gamend` | add, add everything, commit with a message, commit every change, amend |
| `gundo` `gwip` | undo the last commit (changes stay staged), commit everything as "wip" |
| `gco` `gsw` `gb` `gps` `gpl` `gf` `gr` `gsh` `gshp` | checkout, switch, branches, push, pull, fetch, remotes, stash, stash pop |
| `gc URL` | clone (unless Graphviz's `gc` is installed) |
| `lg` | lazygit |
| `sbcl` | SBCL with history and arrow keys (through rlwrap) |
| `activate` | the Python virtual environment in `.venv` |
| `jlab` / `docs` / `dev` | JupyterLab in `~/dev` / the offline docs page / go to `~/dev` |
| `a` | Claude Code, after a snapshot of your files |
| `Ctrl+R` | atuin: search all your history, from every terminal |
| `Ctrl+T` / `Alt+C` | fzf: pick a file / a folder |
| `Alt+s` | the last command again without its command and options, cursor at the start: after `ls -la ~/Pictures/cat.png`, press `Alt+s` and type `xo` to open it |
| `Alt+.` | bash's own: the last argument of the previous command (press again for older ones) |

Git status is `gst`, not `gs`, which is Ghostscript's command.

Your own colours for `ls` and eza can go in `~/.dircolors`; it is read when it exists. The desktop session runs one `ssh-agent`, so every terminal and Emacs share it: with `AddKeysToAgent yes` in `~/.ssh/config`, a key's passphrase is asked once per login.

Put your own aliases in `~/.bashrc`. Vikix's line sits at the top of that file, so anything you write below it loads later and wins.

## Everyday commands

```sh
vikix update       # pull Vikix, update Void, new packages and services, config links, editor configs, migrations
vikix migrate      # only the migrations not yet applied
vikix rebuild-wm   # rebuild the StumpWM executable
vikix docs         # download the offline programming docs into ~/dev (slow; update skips them)
vikix doctor       # check everything is in place (programs, services, XDG_RUNTIME_DIR, the agent's pieces)
vikix eval FORM    # run Lisp in the running StumpWM
vikix agent        # Claude Code (Super+a)
vikix snapshot / changes / history / undo   # the history of your files
vikix backup       # back up your home folder (vikix backup help for the rest)
vikix firmware     # firmware updates waiting (BIOS, Thunderbolt, ...); vikix firmware update installs them
```

## Tests

The tests are scripts in `tests/`. GitHub runs them on every push, and every Monday, since the editor configs can break when a package they pull in changes upstream (`.github/workflows/test.yml`). To run them yourself:

```sh
tests/run.sh          # about a minute
tests/run.sh --all    # plus the editors: several minutes, needs the network
```

| Test | Checks |
|---|---|
| `lint` | Every script parses (shell and Python), the ones you run are executable, and shellcheck has no warnings |
| `lisp` | Every Lisp file reads cleanly, so a missing paren shows up here, not at login (needs `sbcl`) |
| `battery` | The low-battery warner warns once at 15%, once at 5%, and again only after charging |
| `backup` | With restic: `vikix backup setup` makes an encrypted store and a password only you can read, a backup leaves out what `backup-exclude` names, a restore comes back beside the original, an unplugged drive or a wrong password stops with a message, and the bar's reminder says the right thing (needs `restic`) |
| `services` | `20-services` switches on only services whose package is there, has D-Bus reread its config once before the first new one, adds you to `lpadmin` and installs the Printers app's polkit rule once CUPS is installed, and changes nothing when run again |
| `image` | `vikix-image` opens nsxiv on the image's whole folder, in name order, at the image you picked |
| `nightlight` | `vikix-nightlight` starts gammastep at login unless it was switched off, toggles it, remembers off, and stops it so the colours come back |
| `capture` | `vikix-screenshot` takes an area, the focused window or the monitor under the pointer, to the clipboard or a file; `vikix-record` records the right part of the screen, stops, saves, and clears the bar |
| `idle` | `vikix-idle` suspends only on battery, only after the idle time in its settings, and never while keep awake is on |
| `notifications` | `vikix-notifications` lists dunst's history newest first, and shows again the one you pick |
| `updates` | `vikix-updates` counts waiting Void packages and Vikix commits, says `?` for a check that failed, not 0, and fetches a checkout with an SSH remote over HTTPS |
| `theme` | `vikix theme` writes every program's colours from one theme file and refuses a broken one; the migration hooks old starter configs up to it without touching your own settings |
| `wallpaper` | `vikix-wallpaper` shows the theme's picture until you choose one, keeps your choice across theme changes, gives a theme without a picture a plain background in its colour, sets what the picker picked, and leaves the wallpaper alone when off or during `vikix update`; the migration turns it off where you had your own |
| `rofi` | `vikix-rofi` opens the emoji picker and calculator with Vikix's keys, the calculator's Enter copies exactly the answer, and a missing plugin is named in a notification |
| `firmware` | `vikix firmware update` refuses on battery and goes ahead on the charger or on a desktop, fetches the LVFS list first, and counts the waiting updates for the bar |
| `drives` | `vikix-drives` finds the mounted drives (a space in a name too), ejects the one picked and says when it's safe or that it's in use, starts a backup on plug-in only for the backup drive and only when one is due, and gives udiskie your own settings when you have them |
| `examples` | every example in `dev/*/examples/` builds and runs with its Makefile, where its compiler is installed, and every `wordfreq` prints the same `expected.txt` |
| `bar` | `vikix-net` labels the link and shows the Wi-Fi signal only when it is weak; `vikix-bt` shows Bluetooth only when it is on, with the device and its battery, and never waits on a hung bluetoothd; `vikix-font` gives StumpWM Iosevka Regular, or a stand-in until Iosevka is installed |
| `home` | `40-config` and `60-login` change nothing when run again, and `vikix undo` puts your files back (and undoing again brings the change back) |
| `update` | `vikix update` runs the new version's steps after it pulls, logs the whole run, carries on past a failed stage, naming it at the end, and pulls a checkout with an SSH remote over HTTPS |
| `packages` | Every name in `packages/*.list` is a real Void package |
| `dry-run` | Both install parts run through with `--dry-run`, and leave the offline docs to `vikix docs` |
| `editors` | The Emacs and Neovim configs install from scratch into an empty home and start without errors |

## Folder layout

| Path | Contents |
|---|---|
| `install.sh` | Runs the stages in order; `install-1.sh` and `install-2.sh` run one part each |
| `install/` | The stages |
| `lib/` | Shared shell helpers, and the StumpWM build script |
| `packages/` | Package lists, one per concern |
| `services.list` | The runit services to enable |
| `mirrors.list` | The Void mirrors `05-mirror` chooses from |
| `config/` | Everything that ends up in `~` |
| `bin/` | `vikix`; `vikix-session`, which `.xinitrc` starts; `vikix-eval`, behind `vikix eval` |
| `themes/` | The colour themes (see [Themes](#themes)) |
| `dev/` | What `67-dev` puts in `~/dev` for each language: its README (with `tools.list`, the tools whose paths and versions it fills in) and its examples |
| `migrations/` | One-off changes for machines already installed (see its README) |
| `tests/` | The tests (see [Tests](#tests)) |
| `site/` | The website, [vikix.dev](https://vikix.dev): one static page, published to GitHub Pages by `.github/workflows/pages.yml` |

## Not done yet

- **System tray.** StumpWM has no tray, so the network and Bluetooth applets aren't started. Use `nmtui` and `blueman-manager` instead; both are in the `s-m` menu.
- **Themes for GTK and Qt programs** (Firefox, PCManFM, LibreOffice). They keep their own look.
- **Installer ISO.** None yet. For now it's a script on top of a plain Void install.
