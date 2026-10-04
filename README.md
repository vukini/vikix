# Vikix

**Vikix** — [vikix.dev](https://vikix.dev) — is an opinionated desktop layer for **Void Linux**, built around **StumpWM**.

Think of it as Void, supercharged: inspired by Omarchy, but its own thing. It is not a new distribution: it is a script run on top of an ordinary Void install. What you get:

- a keyboard-driven StumpWM desktop
- a small set of programs that work together
- one command, `vikix update`, that keeps it all current

Installed it already? [docs/](docs/README.md) is the map: where everything is, how it fits together, how to make it yours, working with AI, Windows in a window, and what to do when something breaks.

## Install

On a glibc Void install, logged in as your normal user:

```sh
xbps-fetch -o vikix-install https://vikix.dev/install
bash vikix-install
sudo reboot
```

A fresh Void has no `curl` (nor `git`), so this fetches the install with `xbps-fetch`, which is part of xbps. Where curl is there, `curl -fsSL https://vikix.dev/install | bash` does the same. New to Void? [Installing Void for Vikix](docs/install-void.md) goes through its installer screen by screen, with pictures, and [Your first hour](docs/first-hour.md) is the page after.

That's [`site/install`](site/install), short enough to read first: it checks this is glibc Void and that you're not root, installs git if it's missing, clones Vikix into `~/vikix` and runs `~/vikix/install.sh`. What you put after `bash -s --` goes to the install: `curl -fsSL https://vikix.dev/install | bash -s -- --with essentials`. Or do the same by hand:

```sh
git clone https://github.com/vukini/vikix.git ~/vikix
cd ~/vikix
./install.sh --dry-run      # read what it would do
./install.sh                # do it
sudo reboot
```

Log in on tty1 and the desktop starts, with a **welcome** in a terminal: add software, the keys that matter, a theme, your keyboard layout, the guide. Each step is ticked off once done, and Super+m, *Welcome* brings it back. That's **the base**: StumpWM, the bar, a terminal, Firefox and a file manager, sound, Wi-Fi and Bluetooth, the laptop's hardware, screenshots, themes, backups, and the AI agent on Super+a. Everything else is a **feature** you add when you want it, from a terminal on the new desktop:

```sh
vikix features              # what there is
vikix add essentials        # Emacs, and C, Python and Lisp
vikix add rust windows      # any features, by name
vikix add everything        # every editor and language, LibreOffice, printing (a few GB)
```

To have them in the same run, for a machine you just want to leave to it: `./install.sh --with essentials,windows`. See [What gets installed](#what-gets-installed) for the features and bundles.

The install asks for your password **once**, at the start, and then runs by itself, so you can walk away. Everything it prints is also kept in `~/.local/state/vikix/logs/`, and so is each `vikix update`. (Before 0.47 the install came in two parts: `install-1.sh` is now the same as `install.sh`, and `install-2.sh` runs `vikix add everything`.)

**Mirrors.** The install downloads a gigabyte or two, and Void's default mirror is slow in much of the world. So it first times the mirrors in `mirrors.list` and uses the fastest. To pick one yourself instead, name it:

```sh
VIKIX_MIRROR=https://mirror.accum.se/mirror/voidlinux ./install.sh
```

**If a stage fails.** The stages up to the login stop at the first one that fails, because each needs the one before. Sound, laptop hardware, a VM's guest tools and the features carry on, and the end lists what failed. Either way, the error names the stage. Fix the problem, then run just that stage:

```sh
./install.sh --only 30-lisp
```

Every stage checks before it changes anything, so re-running the install is safe. `./install.sh --list` shows the stages. The editors', languages' and `~/dev` stages (45, 65, 67) run when a feature needs them, from `vikix add`.

| Stage | What it does |
|---|---|
| `00-preflight` | Checks this is glibc Void, and that you are not root. Notes any existing StumpWM config. |
| `05-mirror` | Downloads from each mirror in `mirrors.list` for six seconds and points xbps at the fastest (about a minute). Skipped if you set `VIKIX_MIRROR`, or already chose a mirror in `/etc/xbps.d/`. |
| `10-packages` | Updates xbps itself, then installs the base lists and those of the features you chose (see [What gets installed](#what-gets-installed)), skipping anything already installed. |
| `20-services` | Enables the runit services in `services.list`, and adds you to the `video` group, and to `lpadmin` once CUPS is installed (with a polkit rule, so the Printers app needs no password). Before switching on a new service it has D-Bus reread its config, since Void's D-Bus only reads a new package's policy at boot, and a service started before that can't use it. `vikix update` runs it again, so a service that comes with a new package is switched on. |
| `25-network` | Starts NetworkManager, waits until it's running, then switches off dhcpcd and wpa_supplicant. Adds you to the `network` group. Switches the firewall on (`vikix firewall on`): once, here, so `vikix firewall off` stays off; machines installed before 0.71.7 got it from a migration. |
| `30-lisp` | Installs Quicklisp (and adds it to `~/.sbclrc`), clones clx-truetype (TrueType fonts for the bar, not in Quicklisp), builds `~/.local/bin/stumpwm` with Swank and clx-truetype inside, and clones `stumpwm-contrib`. |
| `40-config` | Links Vikix's config files into place and copies starter files you then own (including the keyboard file and the night light times). Makes the guides in `docs/` an Info manual, `~/.local/share/info/vikix.info`, and web pages with the diagrams, `~/.local/share/vikix/guide/`. Writes a man page for every `vikix` command into `~/.local/share/man/man1/` (`man vikix`, `man vikix-backup`), and for the commands of the plugins you've added (`man inbox`), made by `lib/man.py` from the header each script starts with, the one `-h` prints. |
| `45-editors` | With the features `emacs` and `neovim` only. Emacs: clones its config (`vukini/emacs-void`) to `~/.emacs.d`, and links Vikix's AI setup for it (`config/emacs`) to `~/.local/share/vikix/emacs`. Neovim: links Vikix's part (`config/nvim`) to `~/.local/share/vikix/nvim`, copies the starter to `~/.config/nvim` once, installs the plugins at the versions Vikix tested (Lazy's output goes to `~/.local/state/vikix/logs/nvim-plugins.log`), and takes a snapshot after; a clone of the old `vukini/nvim-void-linux` with no changes of yours is kept aside as `~/.config/nvim.vikix-bak.<time>`. Also installs the npm language servers into `~/.local`. Other repos: set `VIKIX_EMACS_REPO` / `VIKIX_NVIM_REPO`. |
| `55-hardware` | Touchpad settings (tap to click, natural scrolling), the Intel microcode rebuilt into the initramfs, and the standard `~/Documents` … folders. |
| `50-audio` | Sets up PipeWire, WirePlumber and the ALSA links, as the Void handbook describes. |
| `60-login` | Adds `~/.local/bin` to PATH, loads the aliases in every shell, and makes X start after login on tty1. |
| `65-languages` | For the language features you chose. Builds the languages Void doesn't package (PicoLisp), builds Lazarus's docked IDE into `~/.lazarus` (a build that fails isn't tried again until Void's Lazarus or the recipe changes; `VIKIX_REBUILD_LANGS=1` tries now), and fetches the current Julia with juliaup. The packaged ones are lines in `packages/lang-*.list`. |
| `67-dev` | Makes `~/dev`: a folder per installed language, the docs page, and the Python environment JupyterLab runs on. It downloads the offline docs and Zeal docsets only when run by `vikix docs`; otherwise it lists what is missing. Where `uv` is (the features `python` and `notes`), also `~/dev/ai`, the AI examples. `vikix update` runs it again. |
| `70-vm` | Inside a VM only (VirtualBox, or KVM/QEMU such as virt-manager): installs the guest tools (shared clipboard, screen resizing). Does nothing on real hardware. |
| `90-finish` | Marks existing migrations as applied, and prints what to do next. |

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
./install.sh               # the base; add --with essentials (or everything) for more
sudo reboot
```

Then log in on **tty1 in the VirtualBox window itself**. The desktop starts there; the SSH session has no screen. Open a terminal (Super+Return) to add features: `vikix add essentials`.

**Snapshot after the install.** Power off and take a snapshot then, so a later round can start from a working desktop.

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
./install.sh               # the base; add --with essentials (or everything) for more
sudo reboot
```

Log in on tty1, then add features from a terminal (Super+Return): `vikix add essentials`.

**Later versions** arrive with `vikix update`, which pulls from GitHub and then reloads StumpWM, so new keys, bar and menu work at once. The only password it asks for is your own, for sudo: it reads GitHub over HTTPS, which needs no login, even when a checkout's remote is SSH (`git@github.com:`, as in a clone you push from), so no key passphrase is asked either. The remote itself is left as it is. Changes made in the checkout itself (an edit, by hand or by another program) would stop the pull, so they're set aside first, not deleted: in a patch file to read (`~/.local/state/vikix/checkout-changes/`) and a named `git stash`. The update says so at the start and again at the end. Editors' leftovers are ignored; a commit made in the checkout stops the update, with the commands to keep it and go on.

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
  - `~/.stumpwm.d/rules.lisp`, your rules for the desktop: it comes with every example switched off, loads just before `user.lisp`, and is the one file Super+Shift+t adds to
  - the configs under `~/.config` for alacritty, picom, dunst and rofi
  - `~/.config/vikix/keyboard`: layout and XKB options, applied at every login. The starter swaps Caps Lock and Left Ctrl (`ctrl:swapcaps`); edit it, then `s-m` → "Apply keyboard settings". For Esperanto, it explains the options that put ĉ ĝ ĥ ĵ ŝ ŭ on Right Alt + c g h j s u, leaving every other key alone
  - `~/.config/vikix/backup-exclude`: what `vikix backup` leaves out
  - `~/.config/vikix/projects`: where `vikix project` looks for your projects (`root=`, `depth=`, `logs=`); all comments at first, so the defaults stand
  - `~/.Xresources`: text size. Raise `Xft.dpi` on a high-resolution screen (144 for a 14" 2.8K panel), then log in again

`config/yours.list` names your files, and Vikix keeps a history of them (see [Undo](#undo-for-your-files)).

If you already had a StumpWM config, it becomes your `user.lisp`. Anything else Vikix has to replace is moved aside to `<name>.vikix-bak.<time>`, never deleted.

## Keys

`s` means Super, `S` Shift, `M` Alt and `C` Ctrl; a capital letter is Shift and that letter (`s-H` is Super+Shift+h).

**The rule for keys.** Each modifier beside Super means one thing, for Vikix's keys, a plugin's and a web app's alike:

| Keys | What they are for |
|---|---|
| Super | Everyday: the six main apps (terminal, launcher, browser, files, editor, agent), the small tools, focus, and what is done to the window you're in |
| Super+Shift | The same key, moving the window: move it, send it to a workspace, bring one here; or the key's other way (redo, previous) |
| Super+Alt | Open something else: every other app, web app and plugin |
| Super+Ctrl | Switch something on the desktop: keep awake, night light, do not disturb, gaps, title bars, recording |

Keys without Super keep their own ways: Print (Shift keeps a file, Ctrl is the window, Super the screen) and the laptop's own keys. `vikix doctor` names a key that breaks the rule, and Vikix's tests fail on one of its own.

StumpWM's own `Ctrl+t` prefix keys still work too: press `Ctrl+t` and wait, and StumpWM lists the keys that can follow (its which-key-mode). Focus follows the mouse: pointing at a window focuses it, without a click. To click instead, put `(setf *mouse-focus-policy* :click)` in `user.lisp`.

| Key | What it does |
|---|---|
| `s-Return` | Terminal |
| `s-d` | Launcher |
| `s-SPC` | Launcher too: the key other desktops use for it |
| `s-w` | Browser (Firefox) |
| `s-e` | Files in Esploro, the file explorer in Emacs: the one on this workspace, or a new one here; F3 in it, two panes (PCManFM where Esploro isn't installed: `vikix add esploro`) |
| `s-M-s` | Files in SpaceFM (tabs, split panes) |
| `s-C-e` | Eject a USB drive: pick it, and a notification says when it's safe to pull out |
| `s-M-e` | Files in PCManFM |
| `s-M-E` | Files in a new Esploro window, even where one is open (`esploro --new`) |
| `s-M-r` | Reveal the file behind this window in Esploro: what an Emacs frame shows, a viewer's document, a terminal's folder |
| `s-M-p` | Projects: pick one with rofi; a terminal opens in its folder and its `log.md` in Emacs (see [Projects](#projects-vikix-project)) |
| `s-M-v` | Passwords (Bitwarden): pick a login, Enter types it into the window you were in (`vikix add bitwarden`; see [Passwords](#passwords)) |
| `s-a` | AI agent in a terminal: Claude Code, or the one you chose |
| `s-i` | AI on the selected text: ask, proofread, rewrite, translate, explain |
| `s-F9` | Dictation: speak, then `s-F9` again types it (`s-S-F9` cancels) |
| `s-F10` | Voice: speak, then `s-F10` again: the AI answers, shown and aloud; follow-ups carry on the conversation |
| `s-F11` | Voice: speak, then `s-F11` again: it goes to the agent (Claude Code), whose replies are read aloud |
| `s-S-F10` | Voice: stop the AI talking |
| `s-M-m` | Mail: your mail web app to the front, or opened (the first mail one `vikix webapp add` makes; see [Web apps](#web-apps)) |
| `s-x` | Emacs: a new window (the Emacs server is already running) |
| `s-c` | Clipboard history: pick something copied earlier, then paste it |
| `s-.` | Emoji: search by name (heart, cat, thumbs up); Enter types it into your window and copies it, `Ctrl+c` only copies |
| `s-=` | Calculator that answers as you type: `340 * 12%`, `5 ft to cm`, `100 USD to EUR`, `today + 30 days`. Enter copies the answer |
| `s-n` / `s-N` | Notifications: the last one again / pick an earlier one (rofi) |
| `s-C-n` / `s-C-d` | Notifications: close all / do not disturb on and off (the bar says `quiet`, and how many are waiting) |
| `s-q` | Close window |
| `s-f` | Fullscreen |
| `s-h` `s-j` `s-k` `s-l` | Move focus left, down, up, right |
| `s-H` `s-J` `s-K` `s-L` | Move the window |
| `s-←` `s-↓` `s-↑` `s-→` | Focus, on the arrows (in a VM on Windows, Super+L locks the host instead of reaching the guest) |
| `s-S-←` `s-S-↓` `s-S-↑` `s-S-→` | Move the window, on the arrows (Super+Shift, as with the letters) |
| `s-b` | Split side by side |
| `s-v` | Split one above the other |
| `s-r` | Remove the split |
| `s-u` / `s-U` | Undo / redo the last layout change on this workspace (splits, moves, closes) |
| `s-z` | Focus: only this window on the workspace, the others out of sight (the bar stays); `s-z` again puts the layout back exactly as it was, whatever you changed meanwhile. Each workspace has its own. `s-f` fills the whole screen instead |
| `s-C-g` | Gaps around windows, on or off (off at login; 10px between windows, 9px at the edge) |
| `s-g` | Go to any window on any workspace: pick one |
| `s-G` | Bring any window here from any workspace: pick one |
| `s-p` | Move the mouse pointer to the focused window |
| `s-t` | Float the focused window, or put it back in the tiles; a floating window moves with Super + left-drag and resizes with Super + right-drag. Dialogs (password boxes, file choosers, zenity's) float by themselves, centred, and stay in front when you click elsewhere; `s-t` tiles one that should be an ordinary window |
| `s-T` | Remember this window here: the rule that puts a window like it where this one is (its workspace, and when it floats its size and place) is shown, and on your yes written into `~/.stumpwm.d/rules.lisp` after a snapshot. `vikix rules forget N` takes it out again |
| `s-C-y` | Title bars on or off: a strip at the top of each tiled window with its number and name, the focused one in the theme's accent (on unless you turned them off; remembered in `~/.config/vikix/titlebars-off`) |
| `s-"` | Rename the focused window: its title bar and the bar show the new name |
| `s-1`…`s-9` | Go to a workspace |
| `s-S-1`…`s-S-9` | Send the window to a workspace (Super+Shift and the digit, whatever Shift+digit types on your keyboard) |
| `s-m` | Vikix menu: the welcome and Add software, key help, all commands, the Vikix guide (in Info, or in the browser with its diagrams), "what does a key do?", themes, network, printers, backup now, screens, update, and Power (the same as `s-S-Escape`). An entry for a feature you don't have (JupyterLab, Zeal, Printers, Windows, local AI, Dropbox) is left out until you add it. *Apps* opens the programs of the features video, graphics, blender, study, passwords, phone and cli-extras, each once it's installed |
| `s-/` | Every key at a glance: one card, grouped (apps, AI, windows, workspaces, notifications, screenshots, sound and screen, system, and yours). The next key closes it, and a key that does something does it too |
| `s-F1` | Every key, searchable. Pick one to run it. |
| `s-Escape` | Lock the screen |
| `s-S-Escape` | Power: lock, suspend, log out, reboot, power off (Lock first, so a stray Enter is harmless) |
| `s-C-a` | Keep awake on/off: no lock, dark screen or suspend while you watch or present (the bar says `awake`) |
| `s-C-l` | Night light on/off: a warmer screen in the evening |
| `Print` | Screenshot an area (drag one out, or click a window) to the clipboard |
| `C-Print` | Screenshot the focused window to the clipboard |
| `s-Print` | Screenshot the whole screen (the monitor the pointer is on) to the clipboard |
| `Shift` with any of those | The same, to a file in `~/Pictures/Screenshots` instead; middle-clicking its notification shows the folder (in Esploro when it's installed) |
| `s-C-v` | Record a video of an area or a window, without sound; press again to stop. The bar says `rec`, and the video goes to `~/Videos/Recordings` |
| `s-C-Print` | Screenshot or record: a menu of all of them, including recording the whole screen. Also **Text from an area** (drag over any text, even in a picture or a dialog, and it's on the clipboard, read by tesseract; other languages with `VIKIX_OCR_LANG=deu+eng` and their `tesseract-ocr-*` package) and **Pick a colour** (click anywhere: its `#rrggbb` on the clipboard, with a swatch in the notification) |
| volume and brightness keys | Change the level and show a bar for it |

## The bar

It answers the mouse too: click a workspace's number to go there, or a window's title to focus it; click **vol** for the mixer (pavucontrol; the wheel turns it up and down, the middle button mutes), the network for `nmtui`, and **bt** for Bluetooth's settings (blueman).

Along the top, in Iosevka like the terminal: on the left the workspaces in use (the current one in brackets) and this workspace's windows, numbered, the focused one in the accent colour; on the right, from left to right:

- **rec**, in the theme's alert colour, while the screen is being recorded (`s-C-v` stops it).
- **mic**, in the alert colour, while dictation or voice listens (`s-F9`, `s-F10` or `s-F11` again writes it down; `s-S-F9` cancels).
- **awake**, in the theme's quieter text colour, while keep awake is on (`s-C-a`).
- **ai**, in the quieter colour, while a local AI model is loaded in memory (`vikix ai stop` unloads it).
- **win**, in the quieter colour, while the Windows VM runs (`vikix windows stop` ends it): it holds 6 GB of memory and costs battery.
- **mem 91%**, in the accent colour when memory is low (under 15% free for programs), in the alert colour when it's nearly full, and **left 5** once programs nobody uses have piled up (`vikix memory`; click it for the whole picture). See [Memory](#memory).
- **quiet**, in the quieter text colour, while do not disturb is on (`s-C-d`), with the number of notifications waiting: they show when you switch it off.
- **updates**, in the theme's accent colour, when `vikix update` has something to bring: `updates 12` (Void packages), `updates 12 + Vikix`, or `Vikix update`; and `+ firmware` (or `firmware` alone) when a firmware update is waiting (see [Firmware updates](#firmware-updates)). Checked a minute after you log in and then every 6 hours, in the background (`vikix-updates`); `vikix update` clears it. Nothing shows when there's nothing, or when it couldn't check (offline).
- **usb**, in the accent colour, while a USB drive is mounted: eject it (`s-C-e`) before pulling it out.
- **backup 9d**, in the accent colour, once backups are set up and the last one is older than a week (`backup` alone: set up, but none yet). See [Backups](#backups).
- **dbx**, once Dropbox is set up here (the feature `dropbox`): `dbx ↓1,204 ↑3`, the files left to download and upload, in the quieter colour while it syncs; `dbx paused`; and in the accent colour `dbx off` when it isn't running (Vikix doesn't start it: `dropbox start`, or `s-m` → Dropbox → Start) or `dbx !` when it can't sync (`dropbox status` says why). Nothing while it's up to date (`vikix-dropbox`). `s-m` → Dropbox shows its status, opens `~/Dropbox`, starts and stops it.
- the network: `wifi` and the network's name (and its signal when it is weak, under 60%), `wired`, or `offline`
- Bluetooth, when it's on: `bt`, or the connected device and its battery, `bt WH-1000XM4 80%` (`+1` for another); nothing when it's off or there is none (`vikix-bt`). `s-m` → Bluetooth pairs and connects
- the volume: `vol 40%`
- the battery, on a laptop: `bat 84%`, with a `+` while charging; nothing when it is full on the charger
- the date and time
- the **tray**, if you switch it on: `vikix tray on` (or `s-m` → *Tray on/off*). The network's and Bluetooth's applets show their icons there (nm-applet, blueman-applet: click for networks, devices, VPNs), and any program that puts an icon in a tray does too. It's StumpWM's stumptray module, loaded only when it's on, with Quicklisp's xembed; the bar leaves its icons room. Your choice is kept in `~/.config/vikix/tray` for the next login, with the applets it starts (`applets = nm-applet blueman-applet`; name your own, or none). While it's on, the bar's own network and Bluetooth text steps aside for those two applets' icons, which say the same (the text comes back when the tray goes, or when you take an applet off the list). `vikix tray off` takes it away and stops them.

Each colour means one thing: alert (red in void) is something watching you, or about to stop you (memory nearly full), accent is something to act on, and the quieter colour is a mode you switched on yourself.

## Themes

One theme colours the whole desktop: StumpWM and its bar, the terminal (alacritty, and kitty if you want it), rofi, notifications, the lock screen, the wallpaper, and the editors, Neovim and Emacs. Six come with Vikix, each with its own wallpaper: **void** (dark, the default; Catppuccin Mocha), **paper** (light; Catppuccin Latte), **gruvbox** (warm and retro), **nord** (cool arctic blues), **tokyo-night** (deep blue, neon colours) and **contrast** (white on black with a yellow focus, every colour at 7:1 or better, for bright rooms and low vision). Where a palette's own colours were too faint to read (Nord's red, the comment grays), they're lifted to 4.5:1 on the background; `tests/theme.sh` checks that for every built-in theme.

```sh
vikix theme           # the current theme, and the list
vikix theme paper     # switch, everywhere, now; kept for the next start
```

Or `s-m`, then Theme. Open alacritty windows change at once; rofi and the lock screen use the new colours from their next start.

- **Omarchy's themes** come over with one command. [Omarchy](https://omarchy.org) has many, made by its community (see [themes.omarchy.org](https://themes.omarchy.org)): each is a git repository with its colours in `colors.toml` and its wallpapers in `backgrounds/`.

  ```sh
  vikix theme import bjarneo/omarchy-ash-theme      # OWNER/REPO on GitHub, or an https:// git URL
  vikix theme import URL mine --no-switch           # another name; import only
  ```

  It becomes your own theme, `~/.config/vikix/themes/ash.theme` (the name is the repository's without `omarchy-` and `-theme`), with the first picture in `backgrounds/` beside it as its wallpaper, and Vikix switches to it. The file says where it came from, and which Omarchy colour each of its colours is. The rest of the repository (Hyprland, Neovim, btop and the like) is left out. Nothing in it is run: only `#rrggbb` colours are read, and only a real JPEG, PNG or WebP is copied. It won't replace a theme of yours without `--force` (the old files are kept as `.vikix-bak`), nor take `void` or `paper`'s name. A theme with no `colors.toml` (some older ones have only `alacritty.toml`) can't be imported.
- **A theme is a file of colours:** `themes/void.theme` shows every name. `sel`, the colour behind selected text and rows, may be left out; `color0` stands in. Copy it to `~/.config/vikix/themes/mine.theme`, change the colours, and `vikix theme mine`.
- **How the programs get them:** `vikix theme` writes each program's colours into `~/.config/vikix/theme/`, and your configs include those files. Your `alacritty.toml` imports `alacritty.toml` from there, and rofi's `config.rasi` names `rofi.rasi`; dunst reads `~/.config/dunst/dunstrc.d/10-vikix-theme.conf` by itself. For kitty, add `include ~/.config/vikix/theme/kitty.conf` to your `kitty.conf`.
- **The editors** take the theme made for each built-in one: in Neovim Catppuccin (void, paper), gruvbox.nvim, nord.nvim and tokyonight.nvim; in Emacs Catppuccin and Doom's themes, installed from MELPA the first time, and Modus Vivendi for contrast. A theme of yours, or contrast in Neovim, is drawn in its own colours, from `~/.config/vikix/theme/palette` (mini.base16 in Neovim, `vikix-palette` in Emacs). `vikix theme NAME` changes a running Emacs and every open Neovim at once. To keep your own: in Neovim, a spec for `AstroNvim/astroui` with `colorscheme` in your `lua/plugins/`; in Emacs, don't load `vikix-theme.el` (emacs-void loads it, and falls back to gruber-darker without Vikix).
- **GTK and Qt programs** (Firefox, PCManFM, LibreOffice, zenity's boxes, Qt's) go dark with a dark theme and light with a light one, decided by the theme's background; open ones change at once. GTK 3 (Firefox, PCManFM, LibreOffice) switches between Adwaita and Adwaita-dark, told by xsettingsd (started with the desktop); GTK 4 and libadwaita take the theme's own colours too (its background, text and accent), from `~/.config/vikix/theme/gtk4.css`, which your `~/.config/gtk-4.0/gtk.css` imports on its first line (your own rules below it win); Qt 6 programs take the theme's palette through qt6ct (`QT_QPA_PLATFORMTHEME=qt6ct`; run `qt6ct` to choose otherwise), when they next start. A web page that offers a dark look follows too, in Firefox. Firefox's own colours follow when its theme is *System theme — auto* (the default).
- **The wallpaper** cycles until you choose otherwise: a new picture every 30 minutes, at random, from Vid's collection and your own `~/Pictures/Wallpapers` and `~/wallpapers` (`vikix-wallpaper cycle MINUTES` changes how often, `vikix-wallpaper next` changes it now). `s-m` → Wallpaper shows a picker with pictures, from Vikix's themes, `~/Pictures/Wallpapers` and `~/wallpapers`, and Vid's collection, which a fresh install adds as the feature `wallpapers` ([github.com/vukini/wallpapers](https://github.com/vukini/wallpapers), about 40 MB), cloned into `~/.local/share/vikix/wallpapers` and pulled by each `vikix update` (if your `~/wallpapers` is already a clone of it, the folder is only a link to yours, never pulled into; `vikix remove wallpapers` deletes the clone, or only the link). Its first entry, **Theme**, follows the theme, its second, **Cycle**, cycles again (or shows the next picture), and its last, **My own tool**, stops Vikix touching the wallpaper at all, for feh, nitrogen or a script that rotates pictures; machines that had one of those before 0.25.0 are set that way by the update. From a shell: `vikix-wallpaper FILE`, `vikix-wallpaper cycle`, `vikix-wallpaper theme`, `vikix-wallpaper off`. A picture you chose before 0.71.17 stays chosen. `vikix update` never changes the wallpaper. A theme's own wallpaper is the picture beside its theme file with the same name (`mine.jpg` next to `mine.theme`); a theme without one gets a plain background in its colour. Vikix's two were drawn by `lib/make-wallpaper.py`.
- **Keeping colours of your own** in one program: set them in its config (for dunst, in a drop-in that sorts after `10-vikix-theme.conf`, like `90-mine.conf`). Your own colours win there, and the rest still follows the theme.

## Changing the window manager while it runs

The StumpWM executable has Swank built in, and it listens on `127.0.0.1:4004`. From Emacs:

```
M-x slime-connect RET 127.0.0.1 RET 4004
```

That puts you at a REPL inside the running window manager. Anything you redefine there takes effect at once.

Swank runs whatever it's sent, as you, so it has a password: `~/.slime-secret`, made by the install (or `vikix update`), readable only by you. Emacs sends it by itself, and so does `vikix eval`; anything else that reaches 127.0.0.1:4004 (another local program, or the Windows VM, below) gets nothing. A wrong password closes that one connection and Swank goes on, and so does a client that sends nothing: it has 5 seconds to send the password.

When something in it fails, it asks rather than falling over. A mistake in `user.lisp` costs only that part of it: a small menu offers to skip it and load the rest, open the file at that line in Emacs, or load your last snapshot of it instead. An error StumpWM itself doesn't catch (in a timer, say), which used to restart the whole desktop, gets a menu too: carry on, or restart as before. Each error is kept, with its backtrace, in `~/.local/state/vikix/errors/` ([When the desktop asks what to do](docs/fixing.md#when-the-desktop-asks-what-to-do)).

If Emacs says the SLIME and Swank versions differ, answer `y`. It still works. The two come from different places: Emacs's package manager for SLIME, and Quicklisp for Swank.

Nyxt, the browser of the feature `lisp-apps`, has a Swank of its own on `127.0.0.1:4006`, with the same password and the same guard (`~/.local/share/vikix/nyxt/vikix.lisp` starts it as Nyxt starts; without `~/.slime-secret` it doesn't start at all). `M-x slime-connect RET 127.0.0.1 RET 4006` puts you at a REPL in the browser, in the package `nyxt-user`: define a command and it's in Ctrl+Space at once, inspect a buffer, or `M-.` into Nyxt's own source in `/usr/share/nyxt/source/`. `(setf *vikix-swank-port* nil)` in `~/.config/nyxt/config.lisp`, after the line that loads Vikix's part, keeps it closed.

## Rules

What happens to a window as it opens, at a time of day, when the battery runs low or when you log in, said in a line of Lisp, in `~/.stumpwm.d/rules.lisp` (which comes with examples to switch on) or `user.lisp`. [Rules for the desktop](docs/rules.md) is the guide:

```lisp
(when-window (:class "Firefox") (workspace 2))
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(when-window (:class "mpv" :title (:has "picture in picture"))
  (float :width "30%" :height "30%" :corner :bottom-right) (sticky))
```

- **Matching:** `:class`, `:instance`, `:title`, `:role`, `:type`, `:workspace`, `:not (...)`, `:where FUNCTION`. A string matches exactly; `(:has "text")` anywhere in it and in any case; `(:like "^regex$")` a pattern; a list any of them.
- **Verbs:** `workspace` (the window opens there, without showing here first; `:follow t` goes along), `float` (pixels or shares of the monitor, the middle or a corner), `tile`, `fullscreen`, `sticky`, `dialog`, `title`, `focus`, `run`, `command`, `notify`, `say`, `open-project`, `theme`; `layout` (puts a saved layout back: `vikix layout save NAME`), on a strip (Viri) `width` (the column's share of the screen: `1/3`, `2/3`, `"40%"`) and `join :left|:right` (under the column beside), which do nothing elsewhere; and any Lisp of your own, with `(window)` the window. `(define-rule-verb NAME (ARGS) "what it does" ...)` adds one.
- **Options:** `:once t`, `:on :focus`, `:on :close`, `:name "..."`.
- **Safe:** a misspelt verb or matcher is found when the file loads, with its line. A rule that fails at a window never stops the desktop: the error is written down, and the third failure switches the rule off until the next reload. A reload moves no window.
- **Without a window,** with the verbs that need none: `(at "09:00" :weekdays (open-project "vikix"))` (once a day; `:weekends`, `:on (:mon :thu)`; up to an hour late after a sleep, `:late t` however late, `:late nil` never), `(each 30 :minutes ...)` (or `:hours`), `(when-battery-below 20 ...)` (once as the charge goes under it), `(when-charging ...)`, `(when-on-battery ...)`, `(at-login ...)` (once a login, not at a reload: where startup programs go) and `(when-workspace 3 ...)`. One ticker checks them every 30 seconds; what ran is kept in `~/.local/state/vikix/rules/`, so a reload or a restart doesn't run a time twice.
- `vikix rules` lists them (Super+m, *Rules*, is the same in a menu): each one's number, on or off, how often it ran and when last, where it's written. `vikix rules why` says why the window in front is where it is, `test` what the rules would do with the windows open now, `apply` does it, `off N` and `on N` switch one until the next reload, `verbs` lists what a rule can match and do. `vikix doctor` names a rule switched off after failing, and the agents read the list through the MCP server's `rules` tool. [Making it yours](docs/customize.md) has the tables. Vikix's own window rules (Lazarus's dialogs, `vikix learn`'s panes) and the plugins' are in the same list, and nothing in the layer or a plugin hangs a function of its own on StumpWM's window hooks where a rule does the work. Super+Shift+t writes the rule for the window you're in ("remember this window here"), and `vikix rules forget N` takes a rule out of your `rules.lisp` again.

## The AI agent

Vikix is set up for an AI agent to work on the desktop with you, the way Omarchy is. The agent is [Claude Code](https://claude.com/claude-code).

- **`s-a`**, or **`a`** in a shell, starts Claude Code (or another agent: below). The first time, it offers to install it with Anthropic's installer (`curl -fsSL https://claude.ai/install.sh | bash`, into `~/.local/bin`).
- **The Vikix skill** (`config/claude/skills/vikix/SKILL.md`, linked to `~/.claude/skills/vikix`) tells the agent how Vikix is put together: Void's xbps and runit, which files are Vikix's and which are yours, the keys, and the commands below. Its main rule: change your files (`user.lisp` and the rest), never Vikix's own.
- **`vikix eval`** lets the agent (or you) run Lisp inside the running StumpWM and read the answer. That is how it can look at your windows and workspaces, or try a key or a theme live, before writing it into `user.lisp`:

  ```sh
  vikix eval '(mapcar (function group-name) (screen-groups (current-screen)))'
  vikix eval '(vikix-apply-theme :paper)'
  vikix eval '(loadrc)'          # reload the config after editing user.lisp
  ```

  It talks to Swank on port 4004. Errors come back as `error: ...`; they never leave it hanging. A menu or prompt that is open makes it give up after 10 seconds.
- **Undo.** Before each agent session, Vikix takes a snapshot of your files. See below.

### Any agent, not just Claude Code

```sh
vikix agent --list                 # the agents, which are here, and which s-a starts
vikix agent --use opencode         # another one, this time (installs it first, if you say so)
vikix agent --default codex        # the one s-a and `a` start from now on
vikix agent --use aider --local    # on a model on this laptop (Ollama), offline
vikix add gemini                   # install one as a feature; vikix remove gemini takes it away
vikix agent --acp claude          # as an ACP agent, for an editor: see below
```

**From an editor.** An editor that runs an agent itself should run `vikix agent --exec [NAME] [ARGS]` rather than the agent: it's the same start (the guide, no keys, no SSH agent, a snapshot first), with nothing of Vikix's on stdout, which is the agent's, no questions, and an error if the agent isn't installed. Without a name it starts yours. `vikix agent --acp [NAME]` is the same, as an [ACP](https://agentclientprotocol.com) agent (the Agent Client Protocol, which Neovim's CodeCompanion, Emacs's agent-shell and Zed speak): Gemini CLI and OpenCode speak it themselves; Claude Code and Codex through an adapter (`claude-agent-acp`, `codex-acp`, pinned) that `vikix agent --install` puts in `~/.local` with them, on Node 22 or newer, pointed at the agent you have rather than a copy of its own. Aider doesn't speak ACP. What an editor may read: `vikix agent --which` (the agent `s-a` starts) and `vikix ai use` (the model `s-i` uses), one word each.

| Agent | Installed by | Signs in with | Local (`--local`) |
|---|---|---|---|
| `claude`, Claude Code | Anthropic's installer, into `~/.local/bin` | your Claude login | no |
| `opencode`, [OpenCode](https://opencode.ai) | its installer, told not to edit `.bashrc` (linked into `~/.local/bin`) | any model company (`opencode auth login`) | yes |
| `codex`, [Codex](https://github.com/openai/codex) | OpenAI's installer, into `~/.local/bin` | your ChatGPT login | yes (`--oss`) |
| `gemini`, [Gemini CLI](https://github.com/google-gemini/gemini-cli) | npm, into `~/.local`; needs Node 20+ (`vikix add javascript`, which `vikix add gemini` brings) | your Google login | no |
| `aider`, [Aider](https://aider.chat) | uv, on Python 3.12 (Aider doesn't run on Void's 3.14) | an API key (`vikix ai key set anthropic`) | yes |

- **One guide for all of them.** Claude Code and OpenCode read the Vikix skill (OpenCode reads `~/.claude/skills` too). For the others, Vikix writes the same text as `~/.local/share/vikix/AGENTS.md`, at every update and every start: linked as `~/.codex/AGENTS.md`, imported by a one-line `~/.gemini/GEMINI.md` (a link would let Gemini's memory write into the guide), given to Aider with `--read`. A file of your own there is kept, and Vikix says how to add the guide to it.
- **The same snapshot first**, whichever agent: `vikix changes`, `vikix undo`.
- **What an agent doesn't get**, so a prompt injection (a web page, a file it reads) can't use it: the API keys `vikix ai key` keeps and other secrets in the environment (`*_KEY`, `*_TOKEN`, `*_SECRET`, `*_PASSWORD` …), since each signs in its own way; `VIKIX_AGENT` is set, so a shell it opens doesn't read the keys back. Aider has no login, so it keeps the model companies' keys (Anthropic, OpenAI, Gemini, OpenRouter, DeepSeek, Mistral, Groq, xAI). Nor your SSH agent (`SSH_AUTH_SOCK`), which after your first push would let it push as you. `VIKIX_AGENT_API_KEY=1` and `VIKIX_AGENT_SSH=1` keep them. It prevents accidents; it isn't a sandbox. OpenCode is told to ask before commands, edits and fetches, unless your opencode.json sets `permission`.
- **Installers** are downloaded whole first, then run, without your keys; a dry run (`DRY_RUN=1`) runs none.
- **Start them through Vikix** (`vikix agent --use NAME`, `s-a`), not as plain `codex`: that skips the snapshot and the above.
- **Local** (`--local`, `--model NAME`, which needs `--local`): the best coder among your models (qwen2.5-coder first). On a laptop's CPU, minutes per answer, and a 3B model can answer, not work through a task; `vikix ai models` has bigger ones if the memory allows. A small model isn't sent the guide (it would be most of what it reads).
- **Taking one away:** `vikix remove NAME` or `vikix agent --uninstall NAME` (the same: both forget the feature) removes the program and keeps its settings, logins and history; a link of your own in `~/.local/bin` stays.

## API keys

An API key (Anthropic's, OpenAI's) has to be somewhere programs can find it, and the obvious place, an `export` line in `~/.bashrc`, is the wrong one: `~/.bashrc` is one of your files, and its history keeps every version for ever (see [Undo](#undo-for-your-files)). So Vikix has a place for them:

```sh
vikix ai key set anthropic       # paste it; it isn't shown. Becomes ANTHROPIC_API_KEY
vikix ai key set openai          # OPENAI_API_KEY. Also gemini, perplexity, openrouter, groq,
                                 # mistral, deepseek, xai, huggingface (HF_TOKEN), github (GITHUB_TOKEN)
vikix ai key set MY_SERVICE_API_KEY   # any other: a name ending in _API_KEY, _KEY, _TOKEN or _SECRET
pass show api/openai | vikix ai key set openai    # or piped in, from a password manager
vikix ai key list                # names and a fingerprint (sk-a…cdef), never the keys
vikix ai key remove openai
```

- **Where:** `~/.config/vikix/secrets/`, one file per key, only yours to read (the folder 700, each key 600). The history of your files never records it, whatever `config/yours.list` says. Encrypted backups (`vikix backup`) do keep it, so a restored machine has its keys back.
- **Who sees them:** every new terminal, and every program the desktop starts from the next login, as environment variables. A terminal open before `set` gets it after `exec bash`. Only names like a key's are ever exported, so nothing dropped in that folder can set `PATH` or send your key to another address (`ANTHROPIC_BASE_URL`). `vikix update` and the installer run without them: they run other people's code (npm, uv, Quicklisp).
- **Don't type a key on the command line** (`vikix ai key set sk-ant-...`): it lands in your shell history. `set` refuses it and says how to take it out.
- **Claude Code.** `vikix agent` (`Super+a`) starts it without `ANTHROPIC_API_KEY`, so it uses your Claude login and plan, and an agent can't print the key from its environment. `VIKIX_AGENT_API_KEY=1 vikix agent` gives it the key, billed as API use. Plain `claude` in a terminal sees the key and asks once; answer No to keep your plan.
- **`vikix doctor`** looks for keys left where they shouldn't be: in your files and their history, and in the files a shell reads at start (`~/.profile`, `~/.zshrc` …). It names the file and line, never the key, gives the exact `vikix ai key set` command, and says how to start the history afresh (the old one set aside, not deleted, though undo's older snapshots go with it). A dotfile that's a link into a git repository gets a warning of its own: that repository's history has the key too. Once a key has been in a file, it may also be in a backup or on a remote: to be sure, replace the key itself.

## Local AI models

Models that run on this machine, with [Ollama](https://ollama.com): offline, and nothing leaves the laptop.

```sh
vikix ai setup         # once: Ollama, as you, in ~/.local/opt/ollama (no password); it starts with the desktop
vikix ai models        # choose one to download (or s-m → Local AI: choose a model)
vikix ai chat          # talk to it (or s-m → Local AI: talk to a model); /bye or Ctrl+D leaves
vikix ai list          # what you have; vikix ai remove MODEL deletes one
vikix ai status        # running? which model is loaded, holding how much memory, until when
vikix ai uninstall     # take Ollama away (--models deletes the models too)
```

- **Honest about a laptop without a graphics card.** The picker reads this machine's memory and says how each model runs here: 1–2 billion parameters fast, 3–4 billion well, 7–8 billion slowly, and bigger ones aren't offered. What that means, measured on an X1 Carbon's i7-7500U with `llama3.2:3b`: about 4 s to load, then about 11 s for two sentences. 1–2B models are about twice as quick; 7–8B about three times as slow. A good start is `llama3.2:3b` (2 GB) for questions and writing, `qwen2.5-coder:3b` (1.9 GB) for code. The list is `lib/ai-models.tsv`.
- **The bar says `ai`** while a model is loaded in memory: `llama3.2:3b` holds 2.6 GB of it. It unloads after 5 minutes unused, or at once with `vikix ai stop` (`s-m` → Local AI: unload the model). What you type to `ollama run` is kept in `~/.ollama/history`.
- **Where they are:** `~/.ollama/models`. They're big, so backups leave them out; they download again.
- **Only this machine** can use it: it listens on 127.0.0.1, which the Windows VM can't reach.
- **Just the parts it needs:** Ollama's release is 1.4 GB, mostly NVIDIA's libraries; setup checks the download against its published checksum, keeps the CPU's and Vulkan's (for Intel graphics, later), about 100 MB, and deletes the rest. Its log is `~/.local/state/vikix/ollama.log` (one old one kept, not a growing one); `vikix doctor` checks it's running.

### `llm` on the command line

[llm](https://llm.datasette.io), Simon Willison's command-line tool for language models, with its Ollama and Anthropic plugins: the same command for a local model and for Claude, fed from a pipe.

```sh
vikix ai llm                                   # once: installs it (uv, as you), pinned
cat notes.md | llm "summarise"
git diff | llm "write the commit message"
llm -m llama3.2:3b "..."                       # a local model, by name
llm -m claude-sonnet-5 "..."                   # Claude, with your key (vikix ai key set anthropic)
```

- **Its default model** is a local one when you have one (free, offline, nothing leaves the laptop), else Claude when `ANTHROPIC_API_KEY` is set. Run `vikix ai llm` again after downloading a model and it moves from Claude to the local one. A default you chose (`vikix ai llm --default MODEL`, or `llm models default …`) is never changed. With neither a local model nor an Anthropic key, llm's own default is an OpenAI model (paid, with an OpenAI key), and `vikix ai llm` says so.
- **Keys**: it reads the ones `vikix ai key` keeps, so there's no second copy; when llm says `No key found … llm keys set`, use `vikix ai key set anthropic` instead, then a new terminal. `llm models -q ollama` lists just your local models (`llm models` lists every model the plugins know).
- **Each call starts in about 3 s** (Python and the plugins loading), before the model's own time.
- **Everything asked is logged**, in a SQLite database: `llm logs -n 5` shows the last five, `llm logs -q WORD` searches them, `llm logs off` stops the logging. Its times are UTC. For your own queries, `sqlite3 "$(llm logs path)" "select datetime(datetime_utc, 'localtime'), model, duration_ms from turns order by datetime_utc desc limit 5"`. The log is in `~/.config/io.datasette.llm/`, and backups keep it.

### AI on the selected text (`s-i`)

Select some text anywhere (a web page, an email, a terminal, Emacs) and press **`s-i`**: a menu asks what to do with it.

- **Ask about it**: type a question; the selection comes with it (select nothing to ask on its own).
- **Proofread**, **Rewrite: clearer**, **Translate** (into a language you pick: English, Esperanto, French, Spanish, Arabic, Hindi, or type another): the result goes to the clipboard, and a notification shows it (Proofread also lists what it changed, so a change for the worse shows). Paste it where you want it.
- **Explain**: what the text means; for code, a command or an error, what it does and how to fix it.

A short answer is a notification; a long one opens in a terminal (`q` closes it). The text is what you last highlighted, else the clipboard; X keeps a highlight after it's gone from the screen, so the notification while it works shows the start of the text it took. It all goes through `llm`, so `vikix ai llm` first, and `llm logs` keeps every answer.

**Which model** is yours to say: `vikix ai use local` or `vikix ai use claude` (also at the end of the `s-i` menu), or edit `~/.config/vikix/ai` (written on first use, and in the snapshot history): `use=local` (the default: free, offline, the text stays on the laptop; llama3.2:3b, or your first local model, or `model=` names one) or `use=claude` (better, paid, the text goes to Anthropic; needs `vikix ai key set anthropic`). It never switches from local to Claude by itself; the menu names the model and where the text goes. On a laptop CPU, llama3.2:3b takes about 10 s to proofread, rewrite or explain a sentence; it translates into Esperanto poorly (Claude does it well). `languages=` in the same file sets the list Translate offers. For a key straight to one action, in `user.lisp`: `(define-key *top-map* (kbd "s-I") "exec vikix-ask proofread")`.

### The desktop as an MCP server (`vikix mcp`)

`bin/vikix-mcp` is an [MCP](https://modelcontextprotocol.io) server on stdin/stdout (JSON-RPC 2.0, a message a line; protocol 2025-11-25 back to 2024-11-05), Python's standard library only. `vikix mcp register [--allow-eval] [--allow-undo]` adds it to Claude Code for you (`claude mcp add --scope user vikix -- vikix-mcp serve`) and prints the settings lines for Codex, Gemini CLI and OpenCode; `vikix mcp status`, `unregister`, `tools`. Typed at a terminal on its own, it shows its help.

Why, when the agent can run commands: each command needs your yes, and these tools are a small checked set you can allow once (`mcp__vikix__*` in Claude Code), while other commands still ask.

- **Read only** (`readOnlyHint`): `desktop` (workspaces, windows with their titles and classes, screens, theme), `keys`, `rules` (the desktop's rules, and why a window is where it is), `doctor`, `history`, `changes`, `themes`, `version`.
- **Small acts**: `notify`, `snapshot`, `set_theme`, `switch_workspace`, `focus_window`.
- **Off unless switched on** (`destructiveHint`): `eval` (`--allow-eval`) and `undo` (`--allow-undo`).
- **What an agent sends is checked** against the desktop before anything runs: a workspace that exists, a theme there is, a window number that's there, a snapshot id's shape. Only such values reach Lisp (as Lisp strings, escaped) or a command (as a single argument, never a shell). The read-only tools use fixed Lisp forms that answer in JSON.
- **Local only**: the agent starts it; nothing listens on a port. Agents that start it with a trimmed environment (Codex) get the session's display and D-Bus from `~/.local/state/vikix/session.env`, which `vikix-session` writes (600) at login.
- **It stays current.** An agent keeps the server for its whole session; after `vikix update` changes it, it runs itself again in the same process before the next request (new code that doesn't compile is left alone), so the agent sees the new tools without a reconnect. A server from before 0.58.0 needs one reconnect (`/mcp` in Claude Code).
- **Every call is logged**, refused ones too, in `~/.local/state/vikix/mcp.log` (600, rotated at 1 MB): the time, `ok`/`error`/`refused`, the tool, its arguments (secrets scrubbed, long ones cut with their length and a hash).
- **What it hands back** is scrubbed of secrets (`lib/debug-report.py`, as `vikix debug` does), and the tools that return text from files and programs say it's data, not instructions; window titles are cut to 200 characters. A command that fails is an error, not a success; so is a Lisp error from `eval`.
- **Robust**: bad JSON, a batch, params of the wrong type, invalid UTF-8, deep nesting or a line over 1 MB get an error answer, and the server carries on.
- **The flags are a convenience, not a wall**: an agent that may run commands can run `vikix eval` or register again itself.
- **Theme names** are letters, digits, `-` and `_` (`vikix theme` refuses others, and doesn't list a file named otherwise): the name goes to StumpWM as a Lisp keyword. `vikix eval` sends Swank's password only to a port that's yours (`/proc/net/tcp`), and a form that timed out doesn't run later.

### Dictation (`s-F9`)

`vikix add dictation` builds [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (v1.9.4, its commit checked) for this CPU in `~/.local/opt/whisper.cpp`, and downloads its English model and the Silero voice detector into `~/.local/share/vikix/whisper/`, each checked against its published SHA-256: about two minutes, no password when the build tools (cmake, gcc, make) are there. Then **`s-F9`** starts listening (the bar says `mic`), **`s-F9`** again types what you said with `xdotool` into the window you pressed it in (and puts it on the clipboard; if you've moved to another window meanwhile, only on the clipboard); **`s-S-F9`** cancels. Presses within 0.7 s are one (a held key repeats). The recording is 16 kHz mono in `$XDG_RUNTIME_DIR`, yours alone, moved aside when you stop (so a new one can start while it's written down) and deleted once written down. It stops itself after five minutes and says so; the next `s-F9` types it.

- **Fast enough:** on this X1's i7-7500U, a sentence takes two or three seconds, loading included, and a minute of speech about ten.
- **Only speech is typed:** the voice detector keeps whisper from hearing silence as "you" or "(crickets chirping)" (this laptop's microphone hiss is as loud as speech), and bracketed descriptions of sounds are dropped.
- **Languages:** `base.en` (English, 150 MB) to start; `vikix dictate models small` for many (490 MB, slower, the language found by itself).
- `vikix dictate file WAV` prints what a recording says (any format ffmpeg reads; it fails when there's no speech); `vikix dictate status`; `vikix remove dictation` (the models stay unless `vikix dictate uninstall --models`).

### Voice (`s-F10`, `s-F11`)

`vikix add voice` (it brings dictation and llm) installs [Piper](https://github.com/OHF-Voice/piper1-gpl) (`piper-tts` 1.8.0, pinned, with uv, as you) and a voice from one commit of `rhasspy/piper-voices`, checked against its SHA-256, into `~/.local/share/vikix/piper/`. Dictation does the listening: **`s-F10`** listens, **`s-F10`** again sends what you said to Super+i's model (`vikix-ask which`: local or Claude, as `vikix ai use` set it) through `llm`, with a system prompt for a spoken answer. The answer is read aloud (Piper streams into `pw-play`, so the first sentence is heard while the rest is made) and shown, in a notification or, when long, a terminal. Follow-ups carry on the same llm conversation (`--cid`, kept in `~/.local/state/vikix/voice-chat`) until `idle=` minutes of quiet (5), or Super+m → *Voice: a new conversation*. **`s-F11`** sends it to the agent instead: the first time, `vikix agent --ask` in a terminal of class `vikix-voice-agent`, with a Stop hook given by `--settings` for that session only (never in your Claude settings) that reads Claude Code's reply aloud; after that, the same terminal is found and what you said is typed into it. **`s-S-F10`** stops the talking, and listening again stops it too, so the microphone doesn't hear it.

- **Where the words go:** what you say stays on the laptop (whisper); `s-F10`'s question goes where Super+i's text does; `s-F11`'s goes to the agent's company. Piper runs here.
- **Choices** in `~/.config/vikix/voice`: `voice=` lessac or amy (American), alan (British), switched with `vikix voice voices NAME`; `speak=no` shows answers only; `idle=`.
- `vikix voice say TEXT` reads anything aloud (`-` from stdin); `vikix voice status`; `vikix remove voice` (the voices stay unless `vikix voice uninstall --voices`). Only Claude Code's replies are spoken: another agent (`vikix agent --default`) gets the question, and answers on screen.

### Ask your notes (`note`)

`vikix add notes` (it brings local AI) makes `note`, which answers questions from a folder of Markdown, an Obsidian vault say, in any terminal:

```sh
note index ~/General --skip Admin,Readwise   # the first time: about five minutes a thousand notes
note index                                   # later, from anywhere: only the notes that changed
note ask "what did I write about runit?"     # an answer from your notes, naming them
note ask --claude "..."                      # Claude answers this one (--local: the laptop)
note find "runit"                            # the nearest notes, no answer: quick
note status                                  # the folder, the index, who answers
```

- **How:** `note index` cuts each note into passages at its headings, turns each into an embedding on the laptop (all-minilm, through Ollama) and keeps them in `~/.local/share/vikix/notes/index.db`. `note ask` finds the six passages nearest the question, and a model answers from those alone. Hidden files and folders (`.obsidian`, Emacs's `.#note.md` locks) are never read.
- **Where the words go:** who answers follows Super+i (`vikix ai use local|claude`, `model=` in `~/.config/vikix/ai`), `--local` and `--claude` for one question. Locally nothing leaves the laptop; with Claude, those six passages (never the whole folder) go to Anthropic. Leave out folders you'd never send with `--skip`: they're never read at all.
- **Choices** in `~/.config/vikix/notes` (written by the first `note index FOLDER`): `folder=`, `skip=`, and `embed=` (`nomic-embed-text` finds better, after `ollama pull nomic-embed-text`; a change reads every note again).
- `vikix remove notes` keeps the index (`vikix notes uninstall --index` deletes it). `~/dev/ai/examples/ask-notes` is the same idea made small, to read and change.

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

## Passwords

Two ways, as features:

- **`vikix add bitwarden`**: your Bitwarden account, the same vault as on your phone and other computers. `Super+Alt+v` opens a picker of your logins: type a few letters, and Enter types the username, Tab, then the password into the window you were in (a sign-in form). Alt+3 types the password alone (a password box), Alt+4 the two-factor code; Alt+c copies the password, Alt+u the username, Alt+t the code, each gone from the clipboard after 45 seconds; Alt+m shows every field. The first time in a while, a box asks your master password; the vault then stays unlocked for an hour. `vikix bitwarden setup` asks your account's email and signs in (`--eu` for an account on bitwarden.eu, `--server URL` for your own Vaultwarden); if Bitwarden refuses a new device, it says how to register it once with your API key (`rbw register`). `vikix bitwarden sync` fetches changes made elsewhere (the picker does every hour), `lock` locks it now, `status` says how it stands. The picker's settings are yours: `~/.config/rofi-rbw.rc`. Web pages are easier with Bitwarden's browser extension.
- **`vikix add passwords`**: KeePassXC, offline: one encrypted file of your own, to back up or sync yourself.

**Coming from LastPass:** in LastPass, *Advanced Options → Export* (a CSV file); in Bitwarden's web vault, *Tools → Import data → LastPass (csv)*. Or import straight from your LastPass account there. Then delete the CSV: it holds every password in plain text.

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

What Vikix installs comes in two parts: **the base**, which every Vikix has, and **features**, which you choose. Each is one or more package lists in `packages/`. `features.list` says which lists each feature brings; a list no feature names is part of the base.

```sh
vikix features             # what there is, and what you have: [x]
vikix add python rust      # add features: their packages now, and every update keeps them
vikix add essentials       # or a bundle: essentials, developer, everything
vikix remove julia         # stop keeping it, and uninstall what only it needed
```

- **Features:** each language (`c`, `python`, `lisp`, `rust` …, with `devtools`, the tools every language uses, coming along), `emacs`, `neovim`, `office` (LibreOffice), `printing`, `webapps`, `dropbox`, `video`, `graphics`, `blender`, `study`, `passwords`, `bitwarden`, `phone`, `cli-extras`, `wallpapers`, `lisp-apps`, `esploro`, `hype`, `windows`, `local-ai`, `llm`, `dictation`, `voice`, `notes`, and the other agents `opencode`, `codex`, `gemini` and `aider`. `wallpapers` and, from `lisp-apps` on, the rest each run their own setup (`vikix wallpapers setup`, `vikix lisp-apps setup`, `vikix esploro setup`, `vikix hype setup`, `vikix windows setup`, `vikix ai setup`, `vikix ai llm`, `vikix dictate setup`, `vikix voice setup`, `vikix notes setup`, `vikix agent --install NAME`), and `vikix remove` its uninstall; `voice` brings `dictation` and `llm`, and `notes` brings `local-ai`.
- **Bundles** (`bundles.list`): `essentials` is Emacs, C, Python and Lisp; `developer` both editors and every language; `everything` is developer, LibreOffice and printing, which is what a full install had before 0.46. `creative` is video, graphics and Blender.
- **Your choices** are the lines of `~/.config/vikix/features`, yours to edit. A machine installed before 0.46 had every list, so its file says `everything`, plus what it set up since (Windows, local AI). With no file at all, everything is kept. A feature you installed by hand (`xi dropbox`) shows as had in `vikix features` and the Super+m picker, and the next `vikix update` adds it to the file, so its packages are kept; one with a setup command (local AI, the agents) can't be told by its packages, so `vikix add` it.
- **One program**, not a feature: `vikix pkg add NAME` (alone, a search of every package in Void), `vikix pkg drop NAME`. A package Vikix's lists name that you drop goes on `~/.config/vikix/packages-skip`, which `10-packages` leaves out; `vikix pkg list` shows it, and adding the package again takes it off.
- **`vikix remove`** shows what it would uninstall and asks first (`--yes` skips the question). A package the base or another feature of yours names stays, and so does one that another installed package needs. A feature only there for the one removed goes too: `devtools`, once no language is left. Your own files are never touched: `~/dev`, `~/.emacs.d`, `~/.config/nvim`, `~/Windows`.

| List | Contents |
|---|---|
| `base` | dbus, elogind, polkit and its password box, openssh, chrony (clock), git, curl, rsync, zip, 7zip, man pages, xdg-utils, texinfo (`info`, and makeinfo for the Vikix manual), python3 (for `vikix eval`) |
| `desktop` | X11, picom, dunst, rofi (with its emoji picker and calculator), alacritty, fonts (Noto, colour emoji, Nerd Font symbols), i3lock, gammastep (night light), screenshots and screen recording (maim, slop, ffmpeg), the text in a screenshot (tesseract-ocr, with English) and a colour picker (xcolor), clipmenu (clipboard history), and what puts GTK and Qt programs in the theme (xsettingsd, gnome-themes-extra's Adwaita-dark, qt6ct) |
| `fonts` | Iosevka, the terminal font. Every variant comes in one 862 MB package, the biggest single download of the install. Also fonttools, which `vikix-font` uses to take the one Iosevka the bar needs out of that package. |
| `network` | NetworkManager (`nmtui` for Wi-Fi), with its connection editor, ufw, the firewall (`vikix firewall`), and nethogs, network use per program (`s-m` → *Network use*) |
| `audio` | PipeWire, WirePlumber (with Bluetooth audio), pamixer, pavucontrol |
| `laptop` | tlp, fwupd (firmware updates), fprintd (fingerprint readers), brightnessctl, xprintidle (suspend when idle on battery), Bluetooth (bluez, blueman), autorandr, and the firmware a recent ThinkPad needs: sof-firmware (sound), intel-ucode (from the nonfree repo, enabled by `repos.list`), intel-video-accel |
| `printing` | Feature `printing`. CUPS with its filters, system-config-printer (and cups-pk-helper, so it needs no root), avahi and nss-mdns (finding network printers), ipp-usb (driverless USB printers), and drivers for older printers: gutenprint, foomatic, brlaser |
| `emacs` | Feature `emacs`. Emacs, and the pdf-tools build deps |
| `neovim` | Feature `neovim`. Neovim, efm-langserver, and the `tree-sitter` CLI (Neovim builds its parsers with it) |
| `editor-tools` | With either editor: nodejs, for the npm language servers (`45-editors`). Each language's own server is in its `lang-*` list |
| `apps` | Firefox, PCManFM, USB drives that mount when plugged in (udisks2, udiskie; gvfs-mtp for Android phones), SpaceFM, mpv, nsxiv, zathura, Foliate (EPUB) |
| `office` | Feature `office`. LibreOffice: Writer, Calc, Impress, Draw, Math |
| `dev` | base-devel (gcc, make), gdb, valgrind, libsanitizer-devel (gcc's `-fsanitize=address,undefined`), strace, rlwrap |
| `cli` | htop, ripgrep, fd, fzf, bat, eza, tmux, tree, jq, zoxide, yazi, lazygit, gh (GitHub CLI), restic (for `vikix backup`), atuin (with bash-preexec) |
| `lisp` | SBCL |
| `lang-*` | One file per language, each the feature of that name (`lang-lisp` is `lisp`): C extras (tcc, clang, ccls, rr, cmake, meson, ninja, shellcheck, shfmt, the C and POSIX man pages), Python (pip, ipython, pipx, uv), Lisp and Scheme (ccl, racket and its docs, chez-scheme, guile), Haskell (ghc and its docs, cabal, HLS, hlint), Forth (gforth), WebAssembly (wabt, wasmtime), Ruby (with `ri` docs), SQLite (sqlite, litecli, sqlitebrowser), Lua (lua54, LuaJIT, lua-language-server), Go (with gopls), JavaScript (nodejs), Zig (zig, zls), Rust (with rust-analyzer and the docs), Java (openjdk21, gradle), OCaml (dune, ocamlfind, opam), Julia (juliaup), Pascal (fpc, Lazarus), and `lang-tools`, the feature `devtools` (ctags, entr, hyperfine, tokei, just, Zeal for offline docs) |
| `optional/windows` | Feature `windows` (`vikix windows setup`, or `vikix add windows`): libvirt (with dnsmasq, for the VM's network), QEMU, UEFI firmware (edk2-ovmf), swtpm, virtiofsd, virt-viewer, xorriso. See [Windows](#windows-in-a-vm) |
| `optional/dropbox` | Feature `dropbox` (`vikix add dropbox`): Dropbox's command-line client, from the nonfree repo. `dropbox start -i` fetches the daemon into `~/.dropbox-dist` and signs you in the first time |
| `optional/webapps` | Feature `webapps`, chosen by the first `vikix webapp add`: Chromium, which runs the web apps. See [Web apps](#web-apps) |
| `optional/video` | Feature `video`: Shotcut (editing), OBS (recording with sound), HandBrake (re-encoding), yt-dlp (downloading) |
| `optional/graphics` | Feature `graphics`: GIMP, Inkscape, Krita, darktable (RAW photos), Flameshot (screenshots to mark up) |
| `optional/blender` | Feature `blender`: Blender, on its own because it's 230 MB |
| `optional/study` | Feature `study`: Anki (flashcards), Xournal++ (writing on PDFs) |
| `optional/passwords` | Feature `passwords`: KeePassXC |
| `optional/bitwarden` | Feature `bitwarden`: rbw, rofi-rbw and pinentry-gtk. See [Passwords](#passwords) |
| `optional/phone` | Feature `phone`: scrcpy and adb (android-tools), an Android phone's screen in a window. Switch on USB debugging on the phone first |
| `optional/cli-extras` | Feature `cli-extras`: pandoc, ncdu |
| `optional/lisp-apps` | Feature `lisp-apps`: Nyxt, and SDL2 with its fonts and images (and libvterm, for the terminal inside Lem), which Lem's window is built on. See [Lisp programs](#lisp-programs-vikix-add-lisp-apps) |
| `optional/esploro` | Feature `esploro`: ImageMagick, poppler and ffmpegthumbnailer, which make the thumbnails of Esploro's preview (Esploro itself is built by `vikix esploro setup`) |
| `optional/hype` | Feature `hype`: Qt 6 with its QML, multimedia, image and SVG parts, libwebp and zlib to build Hype; ffmpeg6 and source-highlight, which it runs; xdg-desktop-portal with its gtk backend, for its file dialogs |
| `optional/dictation` | Feature `dictation` (`vikix dictate setup`): cmake, gcc and make, to build whisper.cpp. See [Dictation](#dictation-s-f9) |
| `optional/notes` | Feature `notes` (`vikix notes setup`): uv, which runs `note`'s Python with its pinned libraries. See [Ask your notes](#ask-your-notes-note) |

## Laptop

- **A screen plugged in lights up by itself:** to the right of the laptop's, at the largest size it shows at 50 Hz or more (a 4K screen on an HDMI 1.4 port gets 2560x1440 at 60 Hz, not 4K at 30), and a notification says so. That layout is saved for those screens, so next time it comes straight back; unplugged, the laptop's screen is alone again, and StumpWM follows each change by itself. **`s-C-p`** (or the laptop's display key) is the menu for the rest: extend, mirror, the other screen only, the laptop's only, arrange by hand (arandr), save as it is now; what you pick is remembered for those screens too. In a terminal: `vikix screens` (what's connected, and the layout saved for them), `vikix screens extend|mirror|external|laptop`. The layouts are autorandr's, in `~/.config/autorandr`: Vikix's are named `auto-…`, and one you save with a name of your own (`s-m` → *Screens: save this layout*) is the one used. It works through a hook autorandr runs before it looks for a saved layout, `~/.config/autorandr/predetect.d/vikix`.
- **Away from the keyboard.** After 10 minutes the screen locks, after 11 it goes dark, and after 20, on battery only, the computer suspends. Change the minutes in `~/.config/vikix/idle` (`LOCK=10`, `SCREEN_OFF=11`, `SUSPEND=20`, and `SUSPEND=0` never suspends), then log in again. **Keep awake** (`s-C-a`, or `s-m` → Keep awake) stops all three for a film or a talk; the bar says `awake`, and every login starts with it off. While the screen is locked, notifications wait, and show once you unlock (Do not disturb, if it was on, stays on).
- **Night light.** From 19:00 the screen warms over an hour, and from 6:00 it cools again (gammastep). The times and colours are in `~/.config/gammastep/config.ini`: by the clock, not the sun, so no location is needed. `s-C-l` (or `s-m` → Night light) switches it off, and it stays off at the next login until you switch it on.
- **Suspend** from the power menu (`s-S-Escape`, or `s-m` → Power) or by closing the lid; the screen locks first. elogind alone handles the lid and the power button (`HandleLidSwitch` in `/etc/elogind/logind.conf`); before 0.71.31 acpid suspended on the lid as well, and the two collided. **Log out**, **Reboot** and **Power off** are there too, through elogind, no sudo.
- **Touchpad**: tap to click, natural scrolling, off while typing (`/etc/X11/xorg.conf.d/40-libinput.conf`, installed by `55-hardware`).
- **Battery.** `vikix-battery` warns at 15% and again, urgently, at 5% (change them with `VIKIX_BATTERY_LOW` / `VIKIX_BATTERY_CRITICAL`). It only starts on a machine with a battery; `vikix-battery --once` shows the charge.
- **High-resolution screen.** Set `Xft.dpi` in `~/.Xresources` (see the file for values), then log in again.
- **Which program opens what** is `~/.config/mimeapps.list`, yours after the first copy: Firefox for links, zathura for PDFs, nsxiv for images (through `vikix-image`, so the rest of the folder is a key press away: `n` / `p`, or Enter for thumbnails), mpv for video and audio. Each `vikix update` (and `vikix add`) also gives it the starter's defaults it lacks, once their program is installed (LibreOffice for office files, Foliate for e-books): never over a type you set, and each only once, so one you delete stays deleted (`lib/mimeapps.sh`; what was offered is in `~/.local/state/vikix/mimeapps-offered`).

## Memory

When memory fills, Linux moves programs out to the disk and back, and the desktop can stall for minutes. `vikix-memory watch`, started with the desktop, looks every 15 seconds (two small files) and warns before that:

- **Low** (under 15% free for programs, or swap all but full): one notification, with the three biggest programs, and the bar says `mem 86%`.
- **Nearly full** (under 7%, or the machine already stalling for memory): one more, urgent, and the bar's field turns to the alert colour. Close something then.
- Each is said once, and again only after memory came back. `VIKIX_MEMORY_LOW` and `VIKIX_MEMORY_CRITICAL` change the two levels.

```sh
vikix memory          # memory and swap, the biggest programs (each with all its processes), files kept in memory (/tmp), what's left over
vikix memory left     # only the programs left over, each with why
vikix memory clean    # end them: the ones surely left over after a yes, the "maybe" ones one by one; --yes: the sure ones, no questions
```

**Left over** means nobody can be using it. For sure: a program on a hidden screen (Xvfb) whose starter has gone, or on a screen that no longer exists, or a test's program whose home is a temporary folder. Maybe: a program an AI agent's command started and left behind, one whose folder was deleted, an editor with no window. And always: its starter is gone, it has no terminal and no window on your screen, and it's older than 10 minutes, so a test that's running is left alone. Nothing is ever ended by itself: the watcher only counts them, says so once when they pile up (5 of them, or 300 MB), and the bar says `left 5`. `s-m` → *Memory* has both commands.

`/tmp` is kept in memory on Void, so big files there count: `vikix memory` says how much.

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

## Fingerprint

Where the laptop has a reader that [libfprint supports](https://fprint.freedesktop.org/supported-devices.html), a finger can stand in for your password at sudo and on the lock screen.

```sh
vikix fingerprint          # is there a reader? enrols your right index finger the first time
vikix fingerprint on       # let sudo and the lock screen take it
vikix fingerprint off      # the password only, as before
vikix fingerprint enrol left-index-finger   # another finger
```

- **How to use it:** at sudo's password prompt, or on the lock screen, press Enter with nothing typed, then touch the reader. Typing your password works exactly as before; over SSH the reader is never asked.
- **What `on` changes:** a marked block in `/etc/pam.d/sudo` and `/etc/pam.d/i3lock`, just before their `auth` line, after a backup of each (`*.vikix-bak.<time>`). `off` takes it out again and leaves the files as they were.
- **No usable reader, no change.** `vikix fingerprint` says so, and names the reader lsusb shows. The X1 Carbon 6th gen's Validity 138a:0097 is one libfprint doesn't support; [python-validity](https://github.com/uunicorn/python-validity) drives some Validity readers, but Void doesn't package it.

## Firewall

The firewall (ufw) is on from the install: nothing on the network can connect to this computer unless a rule lets it, and SSH is always let in. Everything it asks for itself (web pages, mail, updates) gets its answers back as usual.

```sh
vikix firewall             # on or off, and the rules (asks for your sudo password to read them)
vikix firewall allow 8000/tcp web   # let a port in; both tcp and udp when neither is named
vikix firewall close 8000/tcp       # take it out again
vikix firewall off         # switch it off; vikix firewall on brings the same rules back
```

- **Programs others connect to** need a rule. `vikix firewall on` gives one to those Vikix knows about, when they're installed: LocalSend (53317, tcp and udp). Anything else, a server you're writing, a game, gets `vikix firewall allow PORT`.
- **Already let in, without a rule:** printers and other devices that announce themselves on the network (mDNS, which avahi uses, and UPnP), by ufw's own rules; the VMs on libvirt's network (Windows, `void-vm`), by libvirt's.
- **Where it lives:** `/etc/ufw` (ufw's own files; `sudo ufw ...` works too), and the runit service `ufw`, which puts the rules back at boot. `s-m` → *Firewall* shows the same as `vikix firewall`, and `vikix doctor` says whether it's on.

## USB drives

A USB drive mounts by itself when it's plugged in, under `/run/media/$USER/NAME`, and a notification says so, with a button to open it in your folder program (`xdg-open`: Esploro with the feature, else PCManFM). `vikix-drives start` runs udiskie at every login; nothing needs a password.

- **Eject** with `s-C-e` (or `s-m` → *Eject a drive*): pick the drive, and it's unmounted and powered off; a notification says when it's safe to pull out, or which drive is still in use.
- **Encrypted (LUKS) drives** ask for their passphrase in a rofi prompt, then mount like any other; ejecting locks them again.
- **The bar** says `usb` while a drive is mounted.
- **Android phones** show in PCManFM (gvfs-mtp); on the phone, choose "File transfer" when it asks.
- **Your own udiskie settings:** write `~/.config/udiskie/config.yml` and Vikix's (`config/udiskie/config.yml`, which only chooses the notifications) is no longer used.

## Printing

Printing is a feature: `vikix add printing` installs CUPS and switches it on, with avahi to find printers on the network (`everything` includes it).

- **Add a printer:** `s-m` → *Printers*. A printer on your network shows up by itself, and so does a USB printer that works with AirPrint (through ipp-usb). When it offers a driver, pick the driverless one ("IPP Everywhere"). From your next login you are in the `lpadmin` group, so neither it nor `lpadmin` asks for a password (a polkit rule, `/etc/polkit-1/rules.d/50-vikix-printers.rules`, lets that group manage printers at the machine itself).
- **Print** from any program's Print dialog, or from a terminal: `lp file.pdf`. `lpstat -p` lists the printers, `cancel` stops a job.
- **An older printer** may need a driver. gutenprint, foomatic and brlaser (Brother lasers) are installed. For HP, `xi hplip`, then `hp-setup -i`; for Epson inkjets, `xi epson-inkjet-printer-escpr`.
- **CUPS's own page**, http://localhost:631, shows every printer and its queue.

## Windows, in a VM

For work software that only runs on Windows. Windows 11 runs in a VM with its desktop in a window that StumpWM tiles like any other: the clipboard is shared, the screen resizes with the window, and `~/Windows` is drive `Z:` in Windows. It's optional, since most people won't want its 250 MB of packages:

```sh
vikix windows setup                # once: the packages, the drivers disc, ~/Windows
vikix windows create ~/Downloads/Win11_English_x64.iso   # Windows installs itself
vikix windows                      # start it, and open its desktop (or s-m → Windows)
vikix windows stop                 # shut it down (also: status, remove)
```

- **The ISO** comes from [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11). `create` asks for the password of your Windows account, which is named after your Linux one; add `--key` with a product key, or Windows 11 Pro installs unactivated (it works, with a reminder to activate).
- **By itself.** An answer file does the whole install: the drivers, the disk, a local account (no Microsoft account), and at the first login the guest tools, the shared folder and no sleep. A notification says when Windows is ready, about 25 minutes later. The answer disc holds your password, so it's deleted then, and so are the copies Windows keeps.
- **An older CPU is fine.** Setup's CPU check is skipped; the VM has the TPM 2.0 and Secure Boot Windows 11 wants.
- **It runs as you** (libvirt's `qemu:///session`): the disk in `~/.local/share/libvirt/images/` (or `setup --disk DIR`, which needs 40 GB free), and no network port for the display.
- **Your files** go in `~/Windows` (drive `Z:`), which `vikix backup` covers. The VM's disk it leaves out: it's big, and changes all the time.
- **Reboot and Power off** in the power menu shut Windows down properly first. Logging out leaves it running.
- **Its network is kept apart from this machine.** A program in Windows (a bad download, say) can't reach what this machine keeps to itself: the window manager's Lisp door (which could run commands as you), the printers, a local AI model. Windows still reaches the internet and your network; it sees this machine as just another computer, at 192.168.122.1. There's nothing to do for it: `vikix windows setup`, or `vikix update` for a VM made before 0.41.0, sets it up and asks for your password (sudo) once. A VM moved while it was running keeps its old network until Windows restarts; `vikix windows status` says so, and so does a notification. How it works: libvirt's NAT network (`virbr0`, run by the system libvirt service, with dnsmasq, from each boot) and one line in `/etc/qemu/bridge.conf`. The move gives Windows a new network card, so settings made on the old one (a fixed address) don't carry over. To reach a program on this machine from Windows on purpose, run it on 192.168.122.1 (or all addresses), not 127.0.0.1.
- **To change the VM** (memory, CPUs, a USB device), `virt-manager -c qemu:///session`.

## Plugins

Small additions that aren't part of Vikix's core, from their own repo ([vikix-plugins](https://github.com/vukini/vikix-plugins)): a few words in the bar, Super+m entries, keys, a program started with the desktop. You add the ones you want. Each has a guide, with its keys, settings and what to do when it doesn't work: [Plugins, one by one](docs/plugins.md).

```sh
vikix plugin list                 # the plugins there are; yours marked
vikix plugin add agent-waiting    # shows what it runs, needs and changes, asks, then adds it
vikix plugin remove agent-waiting # runs its remove; your settings for it stay
vikix plugin off NAME             # stop loading one (vikix plugin on NAME brings it back)
vikix plugin safe                 # the next login loads none
```

- **The first one, `agent-waiting`.** When a Claude Code session in another window asks for your answer (a permission, a question), the bar says `agent asks`; when sessions have finished, `agents done 2`. **Super+Alt+w** (or a click on it) goes to the window, asking ones first; looking at a window clears its note. It works through three hooks it adds to `~/.claude/settings.json` (a copy is kept first; `remove` takes them out again); a session already running takes them when you type `/hooks` in it (Claude Code asks you to review them), or when restarted.
- **`ai-usage`.** How much of your Claude plan you've used, the 5-hour window and the week: `plan 24% 41%` in the bar, the accent colour from 75%. **Super+Alt+u** says when each resets. Claude Code gives these numbers to its status line, so the plugin becomes the status line (a status line of your own keeps working through it, and comes back with `remove`); they appear once a session has answered once.
- **`next-meeting`.** Your next meeting in the bar (`Standup 14:30 in 12m`, `now: Standup`), and a notification 5 minutes before. **Super+Alt+j** joins it (a Teams link in the Teams web app, Meet in the meet one), **Super+Alt+c** lists the week. It reads your calendars' private links: `next-meeting add work` asks for one without showing it (Outlook on the web: Settings, Calendar, Shared calendars, Publish a calendar, the ICS link; Google: the calendar's settings, Integrate calendar, the secret iCal address; Todoist: its calendar feed); add as many as you have, each under its own label.
- **`flights`.** **Super+Alt+f** asks a line (`DXB LHR 12 Nov, back 20th`, `LHR JFK 3 Dec business`, `DXB BEY 5 Jan direct 2 adults`) and lists the flights, cheapest first, the quickest marked; Enter opens the search on Google Flights, to book there or on the airline's site: the plugin itself never books. The last entry watches the route: checked every 6 hours, a notification and `flight cheaper` in the bar when its price drops. `flights "DXB LHR 12 Nov"` does the same in a terminal; `flights watching`, `flights unwatch N`. Set your currency and home airport (then `LHR 12 Nov` is enough) in `~/.config/vikix/plugins/flights/settings`. Prices come from Google Flights through fast-flights, an unofficial library (no account, no key): a change at Google can break searches until it catches up.
- **`repos`.** Which git projects in `~/src` (and `~/.emacs.d`, `~/.dotfiles`) need pushing, pulling or committing, or have tags not pushed or stashes left: `git 2` in the bar, in the accent colour when something waits to be pushed or pulled. **Super+Alt+g** opens a terminal with each project's state, the commands that do it, and a shell ready: Up brings the commands back one by one. It asks GitHub every 30 minutes over HTTPS, through gh's login, so your SSH key's passphrase is never needed; it never pushes or pulls by itself. The commands it suggests are yours to choose in `~/.config/vikix/plugins/repos/settings` (`push = gpush {path}`, say), with the folders it looks at.
- **`inbox`.** Notes from anywhere. **Super+Alt+i** opens a small box over whatever you're doing (an Emacs frame): write, or press **Super+F9** and speak; the first line is the note's title. **C-c C-c** keeps it, **C-c C-k** drops it. **Super+Alt+Shift+i** does the same with what you'd selected quoted in it. Each note lands at once as a heading in your Org inbox, `~/Dropbox/notes/inbox.org` (the phones see it through Dropbox; another file in `~/.config/vikix/plugins/inbox/settings`), with when and the window it came from. A note taken over Firefox or Nyxt gets the page's address too (Firefox's from its session file, which it writes every 15 seconds: a page opened just before may not have one yet; the web apps, Chromium, only their title). Without Emacs's server, the box is a rofi line. From a terminal or a script: `inbox add "call the bank"`.
  **Super+Alt+Shift+s** sorts the inbox, in a terminal: the model Super+i uses (`vikix ai use`: on this laptop, or Claude, and then the notes' text goes to Anthropic, as it says first) suggests which `.org` file beside the inbox, and which top heading in it, each note belongs in, and which are to-dos. You change what you like (a note's number, then the place's; `t` and a number for a to-do; `d` and a number deletes it, `d` again keeps it), Enter moves them; `inbox sort --undo` puts the files back as they were, deleted notes too. The first sort makes starter files: `work.org`, `personal.org`, `projects.org` (a heading for each project in `~/src`) and `someday.org`; rename, add or remove them freely. To-dos get `TODO`, and go to Todoist when you say so, once it has your token: `vikix ai key set todoist` (Todoist: Settings, Integrations, Developer); the note keeps the task's link.
- **Pinned, so checked.** Vikix keeps the repo at a commit it pins (`~/.local/share/vikix/plugins`), moved only by a Vikix release, so an update can't swap a plugin's code in silently. `vikix update` fetches a moved pin when you have plugins.
- **What's yours:** the list of your plugins (`~/.config/vikix/plugins.list`) and each one's settings (`~/.config/vikix/plugins/NAME`, copied once). A plugin's programs are linked into `~/.local/bin` while it's added.
- **Safe to try.** A plugin's Lisp runs inside StumpWM with all its power, so a plugin is code you trust, like your `user.lisp`. It loads a piece at a time, as Vikix's own files do: a mistake costs only that piece, and the menu asks what to do. One that stops the desktop from starting: `vikix plugin safe` (from a text console: Ctrl+Alt+F2) and log in again, then `vikix plugin off NAME`.
- **Writing one:** a folder with a `manifest` and its code; the plugins repo's README says how.

## The record store (`vikix records`)

What plugins find is kept, to search and use later, rather than gone when a menu closes: every flight search with all its results, a watched route's price at each check, the meetings you joined, your Claude plan's use over time. It's one local file, `~/.local/share/vikix/records.db` (readable only by you, and in `vikix backup`):

```sh
vikix records search singapore          # full text, newest first: words, "a phrase", OR
vikix records list flights --kind price --since 30d
vikix records get 42                    # one record; --json for all its data
vikix records list flights --json | jq ...   # for scripts
vikix records export --org > records.org     # to read in Emacs (or --jsonl, --csv)
vikix records forget flights --older 1y      # tidy up (asks first)
vikix records stats
```

It's SQLite: anything can read it with SQL (`sqlite3 ~/.local/share/vikix/records.db`; the table is `records`: plugin, kind, key, at, title, body, data as JSON, link). An agent can read it through `vikix mcp` (`records_search`, `records_get`), never write to it. Nothing is tidied away by itself.

## Web apps

Some programs are really websites: mail and meetings most of all. A web app opens one in a window of its own, with no tabs and no address bar, that StumpWM tiles and finds like any program:

```sh
vikix webapp add superhuman       # a preset: superhuman, fastmail, gmail, outlook (work), outlook-live
vikix webapp add fastmail --key s-M-f # with a key of its own (Super+Alt+f)
vikix webapp add teams --key s-M-t   # a meeting preset: teams, meet (Google Meet), zoom
vikix webapp add crm https://crm.example.com   # any site (--media: with the camera and microphone)
vikix webapp media crm on         # let one use the camera and microphone, or off
vikix webapp key fastmail none    # another key, or none (vikix webapp key NAME s-X)
vikix webapp list                 # and remove NAME: its logins are kept; --forget deletes them
```

- **Mail on a key.** The first mail web app gets `s-M-m` (Super+Alt+m): it brings the mail window to the front from any workspace, or opens it. Every web app is also in the launcher (`s-d`) and in `s-m`, and its key in the key help.
- **Superhuman, Gmail and work Outlook** can all be one window: Superhuman handles Gmail and Microsoft 365 accounts. Fastmail's own web app is the one for Fastmail. Outlook on the web is what a work account's sign-in rules least often block; the desktop Outlook needs the Windows VM.
- **Logins kept apart.** Each web app has its own Chromium profile (`~/.local/share/vikix/webapps/NAME`), so a work login never mixes with a personal one or with Firefox. Backups keep the logins and leave out the caches.
- **Meetings** (Teams, Google Meet, Zoom) work in their web apps: the camera, the microphone, and sharing your screen (share the *entire screen*: StumpWM swaps windows in a frame, which a shared window doesn't follow). A web app's window has no address bar, so Chromium's question "allow camera and microphone?" is easily missed, and the meeting's settings then show every device greyed out: the meeting presets have both allowed for their own site from the start, and `vikix webapp media NAME on` (or `--media` when adding) does it for any other, from its next start.
- **Notifications** come through dunst, like everything else: allow them in the web app when it asks. They come only while its window is open (on any workspace), and web apps don't start by themselves at login: to have mail open from the start, put `(run-shell-command "vikix-webapp launch superhuman")` in `~/.stumpwm.d/user.lisp`.
- **Your list** is `~/.config/vikix/webapps`, one `NAME URL [KEY]` per line; editing it by hand is fine, your own `#` comments stay, and `vikix webapp list` points out a line it can't use.
- **Chromium** is installed the first time you add a web app (the feature `webapps`, so `vikix update` then keeps it; `vikix remove webapps` takes it away).

## Finding a document (`vikix docs`, Super+F2)

Every document on the machine in one catalogue: Vikix's guides, the README, DESIGN, TODO, CLAUDE and log files and the `docs/` of your projects in `~/src`, the language guides in `~/dev`, your Org notes (`~/Dropbox/notes`, the converted vault too), every man page and every Info manual, the READMEs and notes packages keep in `/usr/share/doc`, and every package there is, installed or not. **Super+F2** (or `s-m` → *Search every document*) asks for words, then lists what matches, best first, each with whose words they are (`vikix`, `repo`, `dev`, `note`, `man`, `info`, `doc`, `pkg`): Vikix's guides rank first, then yours, then the system's. Enter opens it: a guide as its page in the docs browser; a man page or any Markdown (a project's README, a design) as a page styled like the guide (made by mandoc and pandoc, kept in `~/.cache/vikix/docs/`); a package as a short page saying what it is, whether it's installed, how to add it and its website; an Info manual or a note in Emacs. Ctrl+Enter opens it the other way: Emacs for a file, a terminal for a man page or a package.

```sh
vikix docs find runit            # the start of a word is enough; "exact words", a OR b
vikix docs find xbps --source man
vikix docs read 'man:sv(8)'      # as plain text
vikix docs status                # how many from where, and when last read
vikix docs page runit            # the hits as a page in Nyxt
```

With Nyxt, the catalogue is also a page there: `vikix docs page WORDS`, or Super+m → *Every document as a page in Nyxt*, or `vikix-docs` in Nyxt's own command list. Without words it shows what's there: how many from each source, then Vikix's guides and your projects' documents in full. The hits are grouped by whose they are, with a count per group, and each has *Open* and *The other way*, the same as Enter and Ctrl+Enter in Super+F2; *Find…* searches again. Nyxt is started when it isn't running. A document deleted since the last index says so rather than opening nothing.

It's one SQLite file, `~/.local/share/vikix/docs/index.db`, made in about a second and a half; it reads again what changed when a search finds it more than a day old, and `vikix update` reads the man pages and manuals again. Nothing in it leaves the machine. The agents search it too (`vikix mcp`'s read-only `docs_search` and `docs_read`), so they answer from the man page rather than from memory. What used to be `vikix docs`, downloading the offline programming docs into `~/dev`, is now `vikix docs get`.

## Editors

Emacs's config is a separate repository, cloned by `45-editors` and pulled by `vikix update`. Neovim's is Vikix's own, in `config/nvim`, split like StumpWM's: Vikix's part, kept current, and yours, copied once.

- **Emacs** — `~/.emacs.d` is [vukini/emacs-void](https://github.com/vukini/emacs-void). `vikix-session` starts `emacs --fg-daemon` at login, so `e` (`emacsclient -c -a ""`) opens a frame at once. The first start on a new machine installs the packages from MELPA in the background; give it a few minutes before the first `e`. SLIME connects to StumpWM on port 4004. AI, with [gptel](https://github.com/karthink/gptel): `C-c g` a chat on the model `s-i` uses (`vikix ai use`: a local one, or Claude with your key), `C-c G` its menu, where Claude and your local models are next to the config's own (OpenAI, Perplexity); it says what's missing instead of asking for a key. Your agent, with [agent-shell](https://github.com/xenodium/agent-shell): `C-c a` a chat with it (`vikix agent --acp`: Claude Code, Codex, Gemini CLI or OpenCode), `C-c A` it in a terminal (`vikix agent`, so Aider too). That part is Vikix's `~/.local/share/vikix/emacs/vikix-ai.el`, which the config loads when it's there. Your notes (the Org files in `~/Dropbox/notes` the inbox plugin writes to and `inbox sort` files into) are under `C-c n`: `a` the agenda (this week, then every TODO in the notes and their journal), `t` the TODOs, `c` a note into the inbox, `o` a notes file, `j` today's journal page (`journal/2026-10-03.org`), and with [org-roam](https://www.orgroam.com/) (emacs-void installs it with its other packages) `f` find a note or start one, `i` a link to another, `l` what links here, `g` the graph of your notes, in the browser ([org-roam-ui](https://github.com/org-roam/org-roam-ui), on 127.0.0.1 only). org-roam's index lives in `~/.cache/vikix/org-roam.db`, never in Dropbox. A list of agenda files of your own (`org-agenda-files`) is left alone. That part is `vikix-notes.el`, beside the AI one. An Obsidian vault comes over with `vikix obsidian convert FOLDER`, a folder at a time, into `~/Dropbox/notes/vault/`: links become org-roam links, attachments are copied, the vault itself is only read, and a report says what didn't convert cleanly ([Your notes](docs/notes.md#bringing-an-obsidian-vault)).
- **Neovim** — [AstroNvim](https://astronvim.com) v6, with a few choices of Vikix's: the Typst pack (with a live preview), function signatures while typing, `jk` to leave insert mode, JSX snippets, `$…$` pairs in TeX. Vikix's part is `~/.local/share/vikix/nvim`, a link to `config/nvim` that `vikix update` keeps current. `~/.config/nvim` is yours: its `init.lua` loads Vikix's part, then your own plugin specs in `lua/plugins/`, which win (`example.lua` there shows how). The plugins are installed at the versions Vikix tested (`lazy-lock.json`), and when Vikix tests newer ones, `vikix update` moves them on. Plugins you add keep their own versions; after a `:Lazy update` of yours, Vikix's plugins keep yours too, and the update says once how to take Vikix's again. Plain settings and keys can go at the end of `init.lua`. `v` opens it. AI, with [CodeCompanion](https://codecompanion.olimorris.dev), under `Space A`: `c` a chat on the model `s-i` uses (`vikix ai use`: a local one, or Claude with your key), `q` ask about the selection or the file, `g` a chat with your agent (`vikix agent --acp`), `t` your agent in a terminal (`vikix agent`); each says what's missing (a key, Ollama, the agent) instead of failing. A config of your own: `VIKIX_NVIM_REPO=` at install, or any git clone at `~/.config/nvim`, which updates pull.
- **The guide:** [Neovim and Emacs](docs/editors.md) (`info vikix`, *Neovim and Emacs*): who owns which file, keys, language servers, AI in each.
- **Language servers** on PATH for both: `ccls`, `lua-language-server`, `gopls`, `efm-langserver` from Void; `typescript-language-server`, `pyright`, `bash-language-server` from npm in `~/.local/bin`.

### Lisp programs (`vikix add lisp-apps`)

StumpWM is a program written in Common Lisp that you can change, while it runs, in Common Lisp. These three are the same kind of program, so the desktop and its apps can speak one language.

- **Nyxt** (`nyxt`): a web browser, from Void. Its keys, commands and modes are Lisp, in `~/.config/nyxt/config.lisp`. Once it's installed, Vikix's guides and the offline docs open in it (`vikix-docs-open`: Super+m → *Vikix guide in the browser*, *Programming docs*, and `docs`), in the Nyxt window already open if there is one, brought forward from its workspace; the rest of the web stays with your default browser. `~/.config/vikix/docs-browser`, one word such as `firefox`, names another browser for them. Nyxt takes the desktop's colours: your `~/.config/nyxt/config.lisp` (copied once) loads Vikix's part, `~/.local/share/vikix/nyxt/vikix.lisp`, which builds a Nyxt theme from `vikix theme`'s palette, and `vikix theme NAME` repaints a running Nyxt over its socket. Take the load line out to keep Nyxt's own colours. The same part starts Swank in Nyxt, for Emacs: see [Changing the window manager while it runs](#changing-the-window-manager-while-it-runs).
- **Lem** (`lem`): an editor with Emacs's keys, in its own window. Void has no package, so `vikix lisp-apps setup` builds it into `~/.local/opt/lem`: a pinned commit, and the libraries it needs at the versions its `qlfile.lock` names (installed by qlot, apart from your Quicklisp). Its config is `~/.lem/init.lisp`.
- **McCLIM's Listener** (`clim-listener`): a Lisp prompt in a window, where what it prints is still the object behind it; click one to use it again. McCLIM, the Listener and Clouseau (the inspector: `(clouseau:inspect x)` at its prompt) come from Quicklisp and are saved as one program in `~/.local/opt/mcclim`, so it opens at once.
- All three are in the launcher (`s-d`). Building takes a few minutes, once; the logs are in `~/.local/state/vikix/logs/` (`lem-build.log`, `clim-listener-build.log`).
- `vikix lisp-apps status` says what's built; `vikix lisp-apps setup --rebuild` builds Lem and the Listener again; `vikix remove lisp-apps` removes them and Nyxt (McCLIM stays in your Quicklisp).

### Esploro, a file explorer (`vikix add esploro`)

[Esploro](https://github.com/vukini/esploro) is Vid's file explorer: a frame of Emacs, built on dired, with what a file manager is expected to have, for the mouse as much as the keys: a menu bar and a tool bar, right-click menus, click to select and double-click to open, Ctrl+click and Shift+click, dragging files out to other programs and dropping them in, places down the side (home, your folders, plugged-in drives, GTK's bookmarks, the Trash), back and forward, sorting, a filter, finding below, the Trash to look in and restore from, and copy and paste that other file managers understand. Its core is Common Lisp: every change (copy, move, paste, rename, a new folder, the Trash, a drop) is checked whole first, done in the background and kept in a journal, so undo puts it back; and beside each file, the windows that have it open.

- `s-e` (Super+e) goes to the Esploro window on this workspace, or opens one here: each workspace can have its own, at its own folder (`s-M-E`, Super+Alt+Shift+e, a new one even where one is open; `esploro --new FOLDER` from a shell; File → New Window too). In a window, F3 (View → Two Panes) shows two folders side by side, with Copy and Move to Other Pane on the menus; a file dropped on a pane goes into its folder. It's also `esploro [FOLDER]`, in the launcher (`s-d`) and in `s-m` → Apps. Its frame has a file manager's menus (File, Edit, View, Go, Help; Emacs's own are hidden there). It's your file manager everywhere: folders other programs open, drives you plug in, and the browsers' "Show in folder" (Firefox, Chromium: `org.freedesktop.FileManager1`, which setup has the session bus start, `~/.local/share/dbus-1/services/`) open in it, the file selected; setup makes it the default for folders only over PCManFM, Vikix's earlier one, never over a program of your own, and uninstall puts PCManFM back. A new one opens in the workspace's project (the folder, up to its `.git` or `log.md`, most of the workspace's windows are about). `s-M-r` (Super+Alt+r) reveals the file behind the window you're in, and `s-M-x` (Super+Alt+x) offers Esploro's file commands for it in rofi (open, copy its path, compress, extract, shrink a picture, your own from `~/.config/esploro/commands.lisp`; one that changes files is shown as a plan first, and a notification says what it made, the archive or the smaller picture). In Esploro, `z` does your last change (a move into a folder, a copy, the Trash) again on what's selected, and Edit → Save Last Change As… keeps it by name under Recipes; View → Search… (`M-s s`) finds files below the folder from a few words (`kind:pdf newer:30 -invoice`), kept by name down the side under Searches; File → Close Project… lists what's open in the project, unsaved first, to save and close. `esploro selection` prints the files selected in Esploro, for a shell or an agent. Edit → Changes… (`C-c u`) lists every change Esploro made, in words, with Undo for any one of them; Go → Connect to Server… (`C-c k`) opens a server's folders over SSH like local ones (`user@host:folder`, with `sshfs`, which the feature brings; a dialog asks your key's passphrase); in Dropbox's folder each file says synced, syncing or can't sync. `vikix esploro try` builds Esploro from your clone (`~/src/esploro`) and puts it on the desktop at once, the running Emacs reloaded, before it's pushed or pinned; updates keep it while it's newer than Vikix's pin, and the release that pins it takes over. An agent never changes your files through Esploro: its MCP tool `propose_file_changes` shows you a plan, checked first, and only your Apply runs it (undo takes it back). Your rules for where files go, in your own words in `~/.config/esploro/sorting.md` ("a work zip goes in Work"), go to every agent with that tool, so a correction made once holds for all of them. F11 shows a preview beside the folder: a picture, a PDF's first page, a frame of a video (thumbnails from ImageMagick, poppler and ffmpegthumbnailer, which the feature brings), a text's first lines. Its manual: `?` or F1 in it, Help → Esploro Manual, or `info esploro` (setup puts it in `~/.local/share/info`, beside Vikix's).
- `vikix esploro setup` (which `vikix add esploro` runs, with Emacs if you haven't it) builds its command into `~/.local/opt/esploro` from a pinned commit, with SBCL alone, in seconds; the window's code is `emacs/esploro.el` beside it, which the command loads into the running Emacs the first time, so your Emacs config needs nothing.
- `vikix update` builds it again only when a release moves the pin; `vikix esploro status` says what's built, and `vikix esploro doctor` (part of `vikix doctor`) whether it's built at the pin, the command, the folder program, Show in folder, and loaded in Emacs; `vikix remove esploro` removes it (an `esploro` of your own in `~/.local/bin` is left alone). Its first window, in McCLIM, is kept on Esploro's `mcclim` branch.
- Dragging a file out of Emacs (Esploro, dired) to another program works under StumpWM because `windows.lisp` takes `_NET_CLIENT_LIST_STACKING` out of what StumpWM says it supports: Emacs otherwise trusts that list, counts windows StumpWM has hidden as visible, and drops back onto itself. An Emacs started before 0.71.38 sees the change after a restart.

### Slides (`vikix add hype`)

[Hype](https://github.com/omacom/hype) is DHH's app for presentations: a Markdown file, with its pictures and videos beside it, and a visual slide editor. It was made for Omarchy; Vikix gives it what it looks for there.

```sh
hype new talk/talk.md --title "My talk" --theme nord   # start one
hype open talk/talk.md          # the editor (or s-d, Hype)
hype export talk/talk.md talk.pdf   # or talk.pptx
hype help                       # everything else, and hype help format for the Markdown
```

A sample to start from, a short tour of Vikix with speaker notes, two screenshots, code and a table: `~/vikix/examples/hype/vikix-tour/presentation.md`. Copy the folder somewhere of your own before changing it (`cp -r ~/vikix/examples/hype/vikix-tour ~/talks/`), since `vikix update` keeps `~/vikix` as it is on GitHub.

- **Built from source:** Void has no package, so `vikix hype setup` builds a pinned release into `~/.local/opt/hype` with Void's Qt 6 (a minute or two, once; the log is `~/.local/state/vikix/logs/hype-build.log`). `vikix hype status` says what's built; `vikix hype setup --rebuild` builds it again.
- **Your theme's colours:** Hype's window follows `vikix theme` as it changes, and every Vikix theme, yours too, is one to choose for the slides (the palette icon, or `--theme`). `vikix theme` writes them in Omarchy's form: the current one to `~/.local/state/omarchy/current/theme/colors.toml`, all of them to `~/.local/share/vikix/omarchy/themes/`, where the `hype` command points `OMARCHY_PATH` unless you set it yourself.
- **Open and Save** go through the desktop portal (xdg-desktop-portal, drawing gtk's dialog). Setup writes `~/.config/xdg-desktop-portal/portals.conf` to say so, unless you have one, and restarts a portal that was already running, which reads its settings only when it starts. If Hype ever says the file chooser is missing, `vikix hype setup` again (or logging in again) puts that right.
- **Your agent can write the slides:** setup runs `hype skill install`, a skill in `~/.agents/skills/hype`, linked into `~/.claude/skills`. Ask Super+a for a talk, and it writes the Markdown with `hype help format` and checks it with `hype check`.
- `vikix remove hype` removes Hype, its command, launcher entry, skill and theme files; your presentations and the portal's settings stay.

## Languages

Vikix is for playing with languages, so it installs them. Each is a small file in `packages/`; delete the file to drop the language, add a line to add a tool.

| Language | Packages | Try |
|---|---|---|
| C | gcc and friends (`base-devel`), clang, clangd, gdb, valgrind, tcc, rr, cmake, meson, ninja | `tcc -run hello.c` |
| Python | python3, pip, ipython, pipx, uv; JupyterLab in `~/dev/python/.venv` | `ipython`, `jlab` |
| Common Lisp | sbcl (with Quicklisp), ccl; SLIME in Emacs, Swank into StumpWM on 4004 (and Nyxt on 4006, with lisp-apps) | `sbcl` (rlwrap'd) |
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

Each language's server for the editors is in its `lang-*.list` (ccls with C, gopls with Go, lua-language-server with Lua); the npm ones (pyright, typescript-language-server, bash-language-server) come from `45-editors`.

### `~/dev`: your projects, the docs offline, and examples

`67-dev` makes a folder for each installed language. `vikix docs get` then downloads each one's documentation into it, so it works with no network. The installer and `vikix update` leave the downloads out, because they are a few GB from sites that are sometimes very slow; run `vikix docs` when you have the time, and again later to add a new language's docs.

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
  ai/      examples/claude local embeddings ask-notes   (with uv: the python feature)
```

Every language also has a **Zeal** docset (Bash too): open Zeal (`s-m` → "Zeal"), type, and it searches them all. Emacs finds the same docsets through `~/.docsets`, the default folder of `dash-docs`.

**Disk space.** With every language installed it comes to about 5 GB: the Zeal docsets roughly 3.4 GB (Racket's alone is 0.6 GB; Rust's, Java's and Julia's add about 1 GB), the `ghc-doc`, `racket-doc` and `rust-doc` packages 1.6 GB, the Python environment 0.5 GB, the HTML docs under 0.1 GB. A download that crawls (under 10 KB/s for a minute) is skipped with a warning, and the next `vikix docs` tries it again.

**Examples to build and change.** Each language gets small programs in `~/dev/<language>/examples/`, one per folder, each with a README and a `Makefile` that works the same everywhere: `make` builds, `make run` runs, `make clean` tidies. Inside, the Makefile calls the language's own tool (cargo, go, lazbuild, …), whose files are there too, so you learn the real thing. Every language has the same three:

- `hello` — the smallest program that builds
- `wordfreq` — the ten most common words in the Gettysburg Address; every language prints exactly the same thing (`make check`), so two can be compared side by side
- one showing what the language is known for: C a linked list with `make check` under valgrind, Rust errors as `Result`, Go goroutines, Free Pascal a Lazarus window, Python the Game of Life with generators, Zig `comptime` with its tests, Haskell infinite lazy lists, OCaml a calculator built on variants and pattern matching, Java records and sealed interfaces, Julia multiple dispatch, Common Lisp macros (with their expansions printed), Scheme `call/cc` and tail calls, Racket a picture drawn by a recursive function, PicoLisp its built-in database, Forth a defining word that makes words (`2 km 350 m +`), JavaScript a web server asked three things at once, Ruby blocks and methods written at run time, Lua metatables, SQL a small library database queried with joins, WebAssembly a sandbox that decides which files a program may open

They are copied once, so they are yours to change; an update adds new ones and never touches one you have. Every language has them, all twenty. Each builds with the language's own tool: make, cargo, go, fpc and lazbuild, zig build, cabal, dune, Gradle, SBCL's compile-file, Chez's compile-program, raco make, wat2wasm and zig cc for WebAssembly, and SQLite builds the library's database; Python, Julia, JavaScript, Ruby, Lua, PicoLisp and Forth run as they are. `wordfreq` is written twenty ways, and in SQL it's a single query.

**AI to learn from**, in `~/dev/ai` (made where uv is, which the feature `python` brings): four small programs, each with `make run`, that call a model the way any program of yours would.

- `claude`: one question to Claude, from Python with Anthropic's library (streamed) and from the shell with curl and jq (one POST). It needs a key (`vikix ai key set anthropic`) and prints the tokens each question used.
- `local`: the same to a model on the laptop through Ollama's API (`vikix add local-ai`), with Python's own `urllib`: nothing to install, nothing sent anywhere.
- `embeddings`: ten sentences turned into numbers by a local embedding model (all-minilm, `make setup` fetches its 46 MB), kept in SQLite with sqlite-vec, and the nearest to a question found by meaning.
- `ask-notes`: the last two together. `make index NOTES=~/General SKIP=Admin` reads a folder of Markdown (an Obsidian vault) into `notes.db`, then only what changed; `make ask QUESTION="..."` finds the six nearest passages and a local model answers from them alone, naming the notes. `CLAUDE=1` has Claude answer instead, and then only those six passages go to Anthropic. About five minutes a thousand notes, on an X1 Carbon.

Each Python example names its libraries at its top (`# /// script`, pinned), and `uv run` fetches them the first time: nothing is installed for the whole machine.

**A README for each language**, `~/dev/<language>/README.md`: a table of its tools on this machine (compiler, build tool, debugger, language server, formatter, linter), each with where it is and which version, or "not installed"; where to start; and the official site, source code, package registry, and free books and tutorials, every link checked. Every update writes it again, so it stays true; keep notes of your own in another file. A `README.md` there that you wrote yourself is left alone.

Only installed languages get a folder. `~/dev` is yours: Vikix only adds to it, and never deletes or overwrites anything there except `index.html`.

### Learning C (`vikix learn c`)

A course in the terminal, where every lesson is a real program you edit, save, and watch get checked. It starts past the basics: the toolchain, the machine, what C really does.

`vikix learn c`, or `s-m` → *Learn C*, opens the course on the first empty workspace, in two halves: the lesson on the left, from the top, and on the right a shell in that lesson's folder, to edit and run things in. Save `exercise.c` and the lesson pane checks it, below the lesson. In the lesson pane:

| Key | |
|---|---|
| arrows, PgUp/PgDn, Space | scroll the lesson |
| `n` or Right, `p` or Left | the next lesson, the one before (the shell follows at its next prompt) |
| `h` | a hint, one at a time |
| `c` | check now |
| `r` | the lesson's files as they came (after a snapshot: `vikix undo` brings yours back) |
| `q` | close both, and back to the workspace you were on |

It remembers the lesson and where you were in it, and opens there next time. From a shell, the same: `vikix learn c next`, `prev`, `list`, `hint`, `go 03`, `reset 03`; `vikix learn c --here` puts the lesson pane in the terminal you're in.

- **Each lesson** is a folder in `~/learn/c/`: `lesson.md` to read (Vikix keeps it current, so a corrected lesson reaches you), `example.c`, complete and commented, and `exercise.c`, which is yours to change and never overwritten. When the checks pass, delete the `// NOT DONE` line, and `n` goes on.
- **The checks** compile with `-std=c17 -Wall -Wextra -pedantic`, warnings as errors, and run everything under AddressSanitizer and UBSan: an answer that prints the right thing and reads past an array, or overflows an int, isn't done. They show only the first thing that failed. They stay Vikix's (`~/vikix/learn/c/`), so a fix reaches you with `vikix update`; your files in `~/learn` are yours, in your snapshot history.
- **Every output a lesson quotes** came from running it, and `tests/learn.sh` runs it again: a gcc that behaves differently fails the test, not the reader.
- **So far:** tracks 1 to 4 of the plan's twelve, fourteen lessons, each track ending in a small project. [TUTORIALS.md](TUTORIALS.md) is the plan. `vikix learn` itself knows nothing about C, so other languages can follow.

| Track | Lessons |
|---|---|
| 1 · The toolchain | 01 the four stages of `cc` · 02 what the warnings catch (and that some need `-O2`) · 03 the linker: `nm`, `-lm`, archive order · 04 *project:* a Makefile that rebuilds only what changed |
| 2 · Values and bits | 05 integers and overflow · 06 signed and unsigned · 07 *project:* bits and `printbits` |
| 3 · Control and functions | 08 the design recipe · 09 loops, and finding a bug with `gdb` · 10 *project:* numbers with commas, `LLONG_MIN` included |
| 4 · Pointers and arrays | 11 pointers and `my_strlen` · 12 out-parameters · 13 arrays in functions · 14 *project:* `my_memcpy`, `my_memset`, `my_strcmp` |

### Python and JupyterLab

`jlab` (or `s-d` → JupyterLab, or `s-m` → "JupyterLab") starts JupyterLab in `~/dev`, and it opens in the browser. If it is already running, its page opens again. The Python behind it is `~/dev/python/.venv`, made with `uv` and ready with jupyterlab, numpy, pandas, matplotlib, scipy and sympy. To add a library:

```sh
uv pip install --python ~/dev/python/.venv polars
```

It is a separate environment because Void's own Python won't take `pip install`. When Void moves to a new Python version, `vikix update` makes the environment again.

**Not automated.** Two things you install by hand, the way they are on the X1 now:

- **Cuis Smalltalk** — download a release bundle from the Cuis-Smalltalk-Dev GitHub page into `~/apps/`, and keep your `cuis` launcher script from `vukini/dotfiles` (it pins `-ud` so user files stay out of `$PWD`).
- **Odin** — prebuilt binaries into `~/bin/odin-bin`, on PATH from `.bashrc`. `ols` is its language server; the Emacs config already maps it.

## Projects (`vikix project`)

A project is a folder with a `log.md`: a book, a site, a program. `vikix project` finds them in `~/src` (two levels down, so a collection repo's folders are projects too: `living-series/living-in-lambda`), and tells you where each one stands. The log is plain Markdown, newest first, so you, Emacs, scripts and Claude sessions all read and write the same file:

```markdown
# Log: Living in Lambda

**Status** (Living in Lambda), as of 2026-09-12: 60% complete.

- Standing: Tracks 0 to III of 6 published
- Next: Track IV, types
- Build: ./build.sh --all

## 2026-09-12 · Track III published (Vid)

What was done.

Next: Track IV.
```

```sh
vikix project                 # one line each, most recently logged first: % done, the last entry and how long ago, the next step
vikix project list --all      # with the projects that have no entries yet
vikix project show lambda     # the title, folder, log, Status and the last three entries
vikix project path lambda     # the folder: cd "$(vikix project path lambda)"
vikix project log lambda "Track IV's step list agreed." --next "write step 1" --status "track IV started"
vikix project open lambda     # on a workspace of its own: a terminal in its folder, its log in Emacs, placed as you left them (Super+Alt+p picks one with rofi; Super+m → Projects)
vikix project save            # its workspace's layout, now (leaving the workspace saves it too; vikix layout project-lambda)
vikix project build lambda    # its build, in its folder: the log's Build line, build.sh, a Makefile, src/build.sh or package.json (-n only says which)
vikix project check lambda    # its checks, in its folder: the log's Check line, check.sh, check, tests/run.sh, test.sh, make check or test, npm test
vikix project new my-book     # a new project: ~/src/my-book with a log.md (--in series: inside a collection; --private: the log in ~/src/project-logs)
vikix today                   # what was done today, project by project: the log entries and the commits, then what's next (also: yesterday, a date)
```

To add a project, `vikix project new NAME` (or `vikix project new .` in a folder you already have): it writes a `log.md` with a Status and a first entry, so `vikix project` lists it at once. For a public repo, `--private` keeps the log in `~/src/project-logs/NAME/log.md` instead. It never runs `git init` or commits.

The `- Build:` and `- Check:` lines are optional: they are for a project whose build or checks aren't the usual ones. The next step is the newer of the Status' `- Next:` and the newest entry's `Next:` line. A name can be part of one (`lambda`), as long as only one project has it; otherwise it lists the ones it could be. `log` puts the new entry just above the newest one, marked `(Vid)` as the logs mark entries written by hand; from an agent (`--agent`, or anything run inside Claude Code) it leaves the mark off. It never commits: it says the `git` line that would.

- **Skipped:** hidden folders, `node_modules`, and git worktrees (a folder whose `.git` is a file), which would show a project twice.
- **Public repos** keep their log out of the repo: a repo in `~/src` with no `log.md` uses `~/src/project-logs/NAME/log.md` when there is one. That folder is not a project itself.
- **Where it looks** is yours, in `~/.config/vikix/projects`: `root=` (as many as you like), `depth=`, `logs=`.

## Shell aliases

**`vk` is `vikix`, shorter**, and both take less typing: a command by the start of its name when only one begins so (`vk upd`, `vk th paper`, `vk scr`), and the word after it the same way when it starts only one of that command's own (`vk docs f runit` is `vikix docs find runit`). A start that fits several says which (`vk d` → debug, diagnose, dictate, docs, doctor) and does nothing. **Tab** completes in bash: the commands, then each one's words, the themes after `theme`, the features after `add`, the plugins after `plugin add`. The guides and the agents keep saying `vikix`.

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
| `eq`, `ekill`, `emacs-restart` | Emacs with no config (for debugging it), stop the daemon, restart it (refuses with unsaved buffers, asks before ending open chats) |
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
vikix update       # pull Vikix, update Void, new packages and services, config links, editor configs, migrations, llm, your pipx/uv/cargo programs
vikix update core  # Vikix only, in seconds; vikix update system (Void's packages), vikix update tools (editors, languages, your programs)
vikix update core --from ~/src/vikix   # the same from your own clone's main, not GitHub: to try commits before you push them
vikix memory       # what uses the memory, biggest first, and the programs left over; vikix memory clean ends those
vikix debug        # one file that says what's going on (keys taken out), to attach to an issue
vikix diagnose     # that report, handed to your AI agent: what's wrong, and how to fix it
vikix migrate      # only the migrations not yet applied
vikix rebuild-wm   # rebuild the StumpWM executable
vikix docs get     # download the offline programming docs into ~/dev (slow; update skips them)
vikix docs find runit   # search every document on the machine (Super+F2)
vikix doctor       # check everything is in place (programs, services, XDG_RUNTIME_DIR, the agent's pieces)
vikix features     # what you can add, and what you have; vikix add NAME, vikix remove NAME
vikix pkg add gimp # one program; vikix pkg add alone searches them all; vikix pkg drop NAME uninstalls one and keeps it out
vikix welcome      # the first steps; vikix welcome add is the software picker (Super+m, Add software)
vikix eval FORM    # run Lisp in the running StumpWM
vikix agent        # Claude Code (Super+a)
vikix snapshot / changes / history / undo   # the history of your files
vikix backup       # back up your home folder (vikix backup help for the rest)
vikix firmware     # firmware updates waiting (BIOS, Thunderbolt, ...); vikix firmware update installs them
vikix windows      # Windows in a VM: setup, create ISO, then open, stop, status
vikix ai key set anthropic   # an API key, kept out of your dotfiles and their history
vikix webapp add superhuman  # a website as a program: presets superhuman, fastmail, gmail, outlook
vikix ai setup               # local AI models (Ollama); then vikix ai models to choose one
vikix ai llm                 # the llm command: cat notes.md | llm "summarise"
vikix add lisp-apps          # Nyxt, Lem and McCLIM's Listener: programs in Common Lisp
vikix add esploro            # Esploro, a file explorer in Emacs (Super+e)
vikix add wallpapers         # Vid's wallpapers, cycled and in the Super+m picker (a fresh install has them)
vikix add hype               # Hype: Markdown slides with a visual editor, in your theme's colours
vikix learn c                # a C course in the terminal: edit, save, it's checked
vikix fingerprint  # a finger for sudo and the lock screen, where the reader is supported
vikix firewall     # the firewall: on or off, its rules; vikix firewall allow PORT lets one in
vikix dictate setup          # speak, and it types (s-F9); vikix add dictation does the same
vikix voice setup            # talk to the AI (s-F10) or the agent (s-F11), and it answers aloud
vikix project                # your projects (folders with a log.md in ~/src): newest first, % done, what's next
vikix project log NAME "..." # today's entry at the top of its log.md (--next "...", --status "few words")
cd "$(vikix project path lambda)"   # a project's folder; also show, open, build, check NAME; new NAME
vikix today                  # today's log entries and commits across your projects, and what's next
note ask "..."               # ask your notes (vikix add notes, then note index FOLDER once)
vikix mcp register           # the desktop as tools for your agent; vikix mcp status
```

## Tests

The tests are scripts in `tests/`. GitHub runs them on every push, and every Monday, since the editor configs can break when a package they pull in changes upstream (`.github/workflows/test.yml`). To run them yourself:

```sh
tests/run.sh            # all but the editors: a few minutes
tests/run.sh --quick    # without the slow corners (Void's mirror, every language's examples): two or three minutes
tests/run.sh --changed  # only the tests for what changed since origin/main: seconds, for a small change
tests/run.sh lint lisp  # just those
tests/run.sh --all      # plus the editors: several minutes, needs the network
```

They run side by side, as many at once as the machine has cores (`VIKIX_TEST_JOBS=1` runs them one after another), and each one's output is printed whole when it ends. `tests/changed.sh` says how changed files map to tests: a file maps to the tests that name it, and one it can't place means the whole quick set.

| Test | Checks |
|---|---|
| `lint` | Every script parses (shell and Python), the ones you run are executable, and shellcheck has no warnings; and every test keeps off the running desktop's Swank (`VIKIX_SWANK_PORT=9`) |
| `lisp` | Every Lisp file reads cleanly, so a missing paren shows up here, not at login (needs `sbcl`); no float is given to a timer as its delay; none of Vikix's keys breaks the rule for keys (each modifier means one thing), and the rule finds the ones that would |
| `rules` | `rules.lisp`. Without a screen: matching (exact strings, `:has`, `:like`, lists, variables, `:type`, `:workspace`, `:not`, `:where`); mistakes found as the file loads, each with its line; one of each rule after a second load; a failing rule written down and switched off at the third failure; `:once`, `:on :focus`, `:on :close`; a plugin's rules going with it. With a clock and a battery of the test's own: `at` (its days, once, not again after a reload or a restart, late after a sleep, a rule written after its time), `each`, `when-battery-below`, `when-charging` and `when-on-battery`, `at-login` once, `when-workspace`, and their mistakes found at load. In a real StumpWM on a hidden screen (as `viri`; skipped without it): a window on its workspace before it shows, `float` by shares of the monitor, `tile`, `title`, `fullscreen`, `sticky`, `dialog`, a failing rule, a reload that moves nothing, a restart that leaves the windows where they are, one ticker, and `at-login` once across a reload and a restart; `vikix rules`: a rule found by its number, its name or words only it has, off and on, why a window is where it is (what ran, what waits and why, a failure with its words), what `vikix doctor` is told, and on the hidden screen the command itself (the list, `why`, `test` doing nothing, `apply`, a name with Lisp in it staying a name) and the menu with a key; remembering a window: how it is known (its class, its instance when that tells more, an Emacs frame with a name by its title), the rule written into `rules.lisp` under a dated comment after a snapshot and loaded, replaced where it stands when remembered again, `vikix rules forget` (never a rule of `user.lisp`), a file that can't be read only added to, and on the hidden screen a floating window remembered with the real key, closed, and opened again at the same size and place; Vikix's own rules, which were hooks (a Lazarus window that isn't the main one floats at its own size, `vikix learn`'s two panes each land in their half), and the plugins' at the pin (inbox's note box floats where it should, a look clears agent-waiting's note, and a rule that runs at every look leaves one note, not one a look); the starter `rules.lisp` has no rule switched on as it comes, each of its examples is a rule once switched on, and the guide (`docs/rules.md`) names every verb there is |
| `keys` | In a real StumpWM on a hidden screen (as `viri`; skipped without it): Super+Shift+digit sends the window to that workspace with the key asked of the keyboard, on a US layout, a British one (Shift+2 is `"`) and a French one (Super+Ctrl+digit there, the digits needing Shift); Super+Shift with an arrow or a letter moves the window; the keys from before the rule for keys are let go at a reload, but not one you gave something else; none of Vikix's keys breaks the rule; Super+g's list gives each window's workspace and, for a terminal, its folder and what runs in it; the answer of *What does a key do?* stays on the screen when the menu closed over the pointer |
| `viri` | In a real StumpWM on a hidden screen (needs Xvfb, xdotool, alacritty and Vikix's StumpWM; skipped without): a workspace becomes a strip and back with its windows in order, Super+h/l walk and scroll it, Super+Shift+l moves a column, new and closed windows, a dialog, another workspace, `vikix viri` from a shell; the window keys that only knew tiles (Super+Tab, Super+p, Super+g, Super+Shift+g, Super+u, Super+b) each do their thing on a strip or say why not, and a column sent to a tiled workspace is tiled there; each column's window has a title bar, Super+Ctrl+y switches them, a fullscreen window has none; Super+o draws the strip on a card: a box for each window, the frame moved with h and the arrows, Enter, a digit, `/` for the list, Escape, a key bound to something else, a window opening; a scroll slides in steps to the same places as a jump, and `*viri-centre*` keeps the focused column in the middle; the mouse: Super and the wheel, a width dragged by a side edge or with Super and the right button, a title bar dragged to carry a column, clicks on the overview |
| `main` | In a real StumpWM on a hidden screen (as `viri`; skipped without it): `Super+Ctrl+m` puts a workspace into main and stack, a new window opens at the top of the stack (or as the main one), `Super+Shift+h`/`j` swap windows, `Super+r` goes through the main window's widths, a closed window, a split put back, focus mode, a full stack, a dialog, another workspace; the layout picker (`Super+Ctrl+Space`, `vikix-layout-pick NAME`) between tiles, main and stack, a grid and a strip; a layout saved in the mode comes back in it |
| `battery` | The low-battery warner warns once at 15%, once at 5%, and again only after charging |
| `backup` | With restic: `vikix backup setup` makes an encrypted store and a password only you can read, a backup leaves out what `backup-exclude` names, a restore comes back beside the original, an unplugged drive or a wrong password stops with a message, and the bar's reminder says the right thing (needs `restic`) |
| `services` | `20-services` switches on only services whose package is there, has D-Bus reread its config once before the first new one, adds you to `lpadmin` and installs the Printers app's polkit rule once CUPS is installed, and changes nothing when run again |
| `image` | `vikix-image` opens nsxiv on the image's whole folder, in name order, at the image you picked |
| `nyxt` | Vikix's Nyxt file reads only `key=#rrggbb` lines of the palette and builds a theme from them (none without bg and fg), `vikix theme` asks a running Nyxt, and only a running one, to read it again; its Swank starts only with `~/.slime-secret`, on 127.0.0.1:4006, once, not when switched off, and a taken port doesn't stop Nyxt; a client that sends no password is refused after the time limit and the accept loop goes on; the starter config loads the file from where it's linked |
| `docs-open` | `vikix-docs-open` sends guides and docs to Nyxt as `file://` URLs (spaces and `#` escaped), asks StumpWM to bring a running Nyxt forward, falls back to `xdg-open` without Nyxt, and takes another browser from `~/.config/vikix/docs-browser`; the menu and `docs` use it |
| `nightlight` | `vikix-nightlight` starts gammastep at login unless it was switched off, toggles it, remembers off, and stops it so the colours come back |
| `capture` | `vikix-screenshot` takes an area, the focused window or the monitor under the pointer, to the clipboard (saying how Shift keeps it as a file) or a file (whose notification shows the folder on a middle click); `vikix-record` records the right part of the screen, stops, saves, and clears the bar; `text` puts an area's text on the clipboard (tesseract, on the picture made 3× bigger) and `colour` a picked `#rrggbb`, and neither touches the clipboard when cancelled; with picom running, an area waits for the picker's fade before it's taken, so a blurring picom can't blur it |
| `idle` | `vikix-idle` suspends only on battery, only after the idle time in its settings, and never while keep awake is on |
| `lock` | the locker runs i3lock in the foreground in the theme's colour and pauses notifications while locked, bringing them back after (also after a failed lock); Do not disturb stays on; with xss-lock running, the key asks it to lock rather than starting a second i3lock; without, it locks by itself; a bad colour falls back to void's |
| `lazarus` | `65-languages` builds the docked Lazarus IDE with the widget set it finds and the docking packages; a failed build warns once and is remembered, so the next run says so without building or warning; `VIKIX_REBUILD_LANGS=1` or a new Lazarus from Void tries again; a build that works forgets the failure; a built IDE newer than Void's is left alone |
| `notifications` | `vikix-notifications` lists dunst's history newest first, and shows again the one you pick |
| `updates` | `vikix-updates` counts waiting Void packages and Vikix commits, says `?` for a check that failed, not 0, and fetches a checkout with an SSH remote over HTTPS |
| `theme` | `vikix theme` writes every program's colours from one theme file and refuses a broken one; the migration hooks old starter configs up to it without touching your own settings |
| `theme-import` | `vikix theme import` makes a Vikix theme of a made-up Omarchy theme repo: Omarchy's colour names in Vikix's (the ANSI-only kind too), `#rgb` widened and alpha dropped, missing bright colours made 20% lighter, its first real picture beside it, the name from the repo's; nothing in the repo runs, and shell code, non-hex values, a `[table]`, a fake or linked picture, an `ext::` or `http://` address are all left out or refused; no overwrite without `--force` (the old files kept aside), never a built-in theme's name, and a dry run writes nothing |
| `wallpaper` | `vikix-wallpaper` cycles your pictures until you choose otherwise (never repeating the one showing, never the themes' own, the minutes kept, a missing picture skipped, the theme's when there's nothing to cycle, one watcher at a time), shows the theme's when asked, keeps your choice across theme changes, gives a theme without a picture a plain background in its colour, sets what the picker picked, and leaves the wallpaper alone when off or during `vikix update`; the migration turns it off where you had your own; `vikix add wallpapers` clones the collection (or links to `~/wallpapers` when that is a clone of it, listed once), records the feature, pulls new pictures, and `remove` deletes the clone but never your own and drops a choice that went with it |
| `mimeapps` | The starter's defaults reach an older `mimeapps.list`: only types it doesn't set, only once their program is installed, each offered once (a deleted one stays deleted), written in `[Default Applications]` in place (a link stays a link), a dry run changes nothing |
| `rofi` | `vikix-rofi` opens the emoji picker and calculator with Vikix's keys, the calculator's Enter copies exactly the answer, and a missing plugin is named in a notification |
| `firewall` | `vikix firewall on` refuses what comes in and lets everything out, always lets SSH in before switching on, opens LocalSend's port only where it's installed and links the runit service; `allow` and `close` take only ports, a dry run changes nothing, status while off asks no password, and the migration does nothing without ufw |
| `fingerprint` | `vikix fingerprint on` puts its PAM block just before the first auth line and `off` leaves the files exactly as they were, never twice and always after a backup; nothing changes without a usable reader and an enrolled finger |
| `firmware` | `vikix firmware update` refuses on battery and goes ahead on the charger or on a desktop, fetches the LVFS list first, and counts the waiting updates for the bar |
| `drives` | `vikix-drives` finds the mounted drives (a space in a name too), ejects the one picked and says when it's safe or that it's in use, starts a backup on plug-in only for the backup drive and only when one is due, and gives udiskie your own settings when you have them |
| `examples` | every example in `dev/*/examples/` builds and runs with its Makefile, where its compiler is installed, and every `wordfreq` prints the same `expected.txt` (the AI ones only build here) |
| `dev-ai` | the AI examples run end to end against a made-up Claude API and Ollama on 127.0.0.1: the key sent (never on curl's command line), the model, `fallbacks` with its beta header, streaming, the model that writes text picked over the embedding one, the nearest sentence and notes found, hidden files and folders (an Emacs lock too) and skipped ones left out, only changed notes read again, another folder starting afresh, and every missing key, model or server saying what to do |
| `bar` | `vikix-net` labels the link and shows the Wi-Fi signal only when it is weak; `vikix-bt` shows Bluetooth only when it is on, with the device and its battery, and never waits on a hung bluetoothd; `vikix-dropbox` counts the files left to sync, says off, paused or a problem, and nothing when up to date or never set up; `vikix-font` gives StumpWM Iosevka Regular, or a stand-in until Iosevka is installed |
| `windows` | `vikix windows setup` refuses without KVM or space before changing anything, opts in once, and deletes a download with the wrong checksum; `10-packages` installs an optional list only once chosen; `create`'s answer file is valid XML in the ISO's language, and the password stays off the command line and out of reach of other users; `virt-install` gets the TPM, Secure Boot, the private bridge (never passt), virtiofs and TRIM; `vikix windows network` sets up the system libvirt, its network and bridge.conf, moves a passt VM onto `virbr0`, says plainly when libvirt won't start, asks for no password when all is ready, and tells a Windows still running on the old network to restart; the migration runs it only where Windows was chosen, and never fails the update; `vikix doctor` checks the VM's network; the discs come out and the answer disc goes only once Windows is ready; power off shuts a running Windows down and leaves libvirt alone otherwise |
| `llm` | `vikix ai llm` installs llm and its Ollama and Anthropic plugins with uv, pinned; its default becomes a local model (llama3.2:3b first) when there is one, else Claude with a key, else it says what to do and warns that a plain `llm` would go to OpenAI; the default it picked is picked again (a local model later wins over Claude), a default you chose stays; `--default` sets one; `--refresh` (from `vikix update`) reinstalls only an llm that isn't the pinned version; without uv, a plain message |
| `agents` | the guide is the skill without its header and calls itself a guide; each agent installs as its project says (OpenCode without editing `.bashrc`, Codex without questions, Aider on Python 3.12 with uv, Gemini with npm into `~/.local` and only on Node 20+) and is recorded as a feature; the guide is linked for Codex and Gemini, never over your own file (which it says how to extend), and given to Aider with `--read`; the default starts, with its arguments, after a snapshot, and without API keys (Aider keeps the model companies', `VIKIX_AGENT_API_KEY=1` all); `--default`, `--list`; `--local` picks the best coder model for aider, codex (`--oss`) and opencode (an Ollama provider), and refuses claude and a model you don't have; `--uninstall` keeps settings and your GEMINI.md, drops the link, and the default goes back to claude; installers run downloaded whole, without keys, and not in a dry run; no SSH agent or other secrets reach an agent, which gets VIKIX_AGENT (secrets.sh then exports nothing); OpenCode asks unless your config sets permissions; `--model` needs `--local`; a small local model isn't sent the guide; Gemini's GEMINI.md imports the guide (0.49.0's link is replaced); uninstall forgets the feature and leaves a link that isn't Vikix's; a failed snapshot doesn't stop the agent; `--exec` leaves stdout to the agent alone, drops the keys and the SSH agent, starts yours without a name, and never asks, even at a terminal; `--which` says which is yours; `--acp` starts gemini with `--acp`, codex through its adapter (installed with it, pinned, without a copy of its own, and only on Node 22+) with `CODEX_PATH` at yours, and refuses aider, `--local`, and a missing adapter; uninstalling codex takes its adapter; the test drops keys it inherits, so a failure never prints yours |
| `memory` | against a made-up `/proc`: `vikix memory watch` warns once when memory is low and again, urgently, when nearly full (or the machine stalls), not twice, and again after memory came back; the bar's field and its words; a hidden screen whose starter is gone, what's on it, a vanished screen and a test's home are left over, an agent's strays only maybes, and a running test, a terminal's program and a window's are not; piled up is said once; `clean --yes` ends a real stray of the test's own and leaves the one on your screen |
| `debug` | `vikix debug` writes a 600 report through a temp file (refusing a link; an old 644 file ends 600): the problems at a glance (a Lisp error, a failed stage), the sections, only Vikix's own log lines (a browser's, with the pages and a web page's text, left out and counted), the session's start and end, repeats collapsed; it keeps out stored secrets whatever their shape, Swank's, git's and the backup password, key shapes (Slack, Stripe, JWTs, AWS, Google...), JSON and lowercase names, `--password` flags, private key blocks, Bearer, `curl -u`, URL passwords and paths, random-looking strings, home, user and machine names; a bad byte or control code doesn't stop it; `--help`; `vikix diagnose` needs a terminal, starts in Vikix's state folder, Claude in plan mode, Aider with `--read` and `--no-git`, and says the logs are data |
| `dictate` | setup clones whisper.cpp at the pinned tag and refuses another commit, builds for this CPU, downloads the model and the voice detector and refuses a wrong checksum (keeping nothing), writes the choice, records the feature, asks for no sudo when the build tools are there, and a second setup does nothing; toggle listens (16 kHz mono, 600, the bar's file), then writes it down with voice detection and types it, on the clipboard too, without whisper's descriptions of sounds; nothing heard, nothing typed; cancel types nothing; not set up, it says so; `models small` lets whisper find the language; uninstall keeps the models unless asked; presses within 0.7 s are one; a recording the 5-minute limit stopped is typed by the next press; a new dictation while one is written down keeps its own file; moved to another window, only the clipboard; a space after each; `models` and `status` clean before setup; `file` fails on no speech |
| `notes` | `note` against a made-up Claude and Ollama in a made-up home: ask and index say what to do first; the first index remembers the folder and skips in a file that explains itself, keeps the index in a folder of your own (700), and leaves out hidden files and folders, Emacs's lock links and skipped folders; again from anywhere, only changes, and what's gone goes; `--skip` alone, another folder starting afresh, one index at a time; find, and ask giving the model the rule and the nearest passages; who answers following `~/.config/vikix/ai`, `--local`/`--claude`, no key; status; setup (records the feature, pulls the model only when missing); uninstall keeping the index unless `--index` |
| `project` | `vikix project` in a made-up home with made-up projects: a repo with `log.md`, a collection with its own `LOG.md` and two projects, a public repo whose log is in `~/src/project-logs` (that folder no project), and a git worktree, hidden folders, `node_modules` and too-deep folders skipped; `~/.config/vikix/projects`'s `root=`, `depth=`, `logs=`; `list` newest first with the %, how long ago and the newer Next, cut to the terminal's width, `--all`; `show`, `path`, names by prefix, part or `collection/name`, an ambiguous one listing the candidates; `log` puts today's entry after the Status and before the newest (with `--next`, `--status`, `(Vid)` unless `--agent` or Claude Code), into a log kept apart too, and says how to commit; `build` finds the log's `Build:` line, `build.sh` (bash or sh), `Makefile`, `src/build.sh`, `package.json`, runs in the folder and passes on the exit status; `check` finds the log's `Check:` line, `check.sh` (run itself when executable), `tests/run.sh`, `make check` or `make test` (only a target the Makefile has), `npm test`, and passes on the exit status; `new` makes a folder and log (Status, first entry, listed at once), inside a collection (`--in`), the log kept apart (`--private`, saying when the repo isn't one yet), for `.`, and refuses a folder with a log or a git worktree; `today` shows the day's entries, commits on any branch (not the day before's), the next step, `yesterday` or a date, `--no-git`, and `vikix today` reaches it; `open` starts a terminal there and Emacs on the log, and refuses without a desktop |
| `voice` | setup installs the pinned Piper with uv and downloads the voice, refusing a wrong checksum (keeping nothing), writes the choices, records the feature, and a second setup does nothing; `say` streams Piper into the player at the voice's rate, `quiet` stops the whole group, `speak=no` stays silent; `ask` uses Super+i's model with a spoken-style prompt, speaks the answer without Markdown or links and shows it, carries the conversation on, starts afresh after the idle minutes or `new`, and says why when it fails (speaking nothing); `agent` starts Claude Code in a terminal it can find again, with a Stop hook for that session only; `agent-said` speaks the reply from the hook's field or the transcript, without code, and exits 0 on junk; `dictate toggle ask`/`agent` quiet the voice, then send what was said there, typing nothing; `voices` switches; uninstall keeps the voices unless asked |
| `lisp-apps` | setup fetches Lem at the pinned commit and refuses another, installs its libraries with qlot in its folder, then builds the SDL2 window with 4 GiB; builds the Listener with Clouseau as one program, leaving no half-written one; links `lem` and `clim-listener`, puts both in the launcher, records the feature, asks for no sudo when the packages are there; a second setup builds nothing, `--rebuild` builds again; a failed build shows its end and names its log; `status` says what's built and from which commit; uninstall removes only what setup made and forgets the feature; a dry run changes nothing |
| `esploro` | setup fetches Esploro at the pinned commit and refuses another, builds its command with `build.lisp` in its folder (SBCL alone, no Quicklisp), links `esploro` and puts it in the launcher for folders, records the feature, builds nothing a second time and again with `--rebuild`; a failed build names its log; uninstall removes only what setup made; the feature brings Emacs; Super+e finds its frame by title, the Apps menu names it, and `vikix update` builds a moved pin |
| `learn` | every C lesson's example compiles without a warning and runs, every output its lesson.md quotes is what the command prints now, the exercise as shipped fails its check and the worked answer passes; where the sanitizers are, an INT_MIN overflow and a read past a string are caught and reported briefly; the runner copies lessons once without the checks or answers, never over your work, and lists, hints (one at a time), checks (the NOT DONE gate, moving on, the last lesson staying), resets and watches |
| `hype` | setup fetches Hype at the pinned commit and refuses another, builds it with Void's qmake6, records the feature, needs no sudo when the packages are there, writes the command (OMARCHY_PATH at Vikix's themes, yours winning), the launcher entry and the portal's settings (never over yours), moves another `hype` aside and installs the agent's skill; `vikix theme` writes the current theme and every theme for it, and nothing without it; a second setup builds nothing, a failed build names its log, uninstall leaves only yours, a dry run changes nothing |
| `mcp` | the server answers initialize (the client's protocol version, or its newest), ping, tools/list and tools/call, -32601 and -32700; notifications get no answer; read-only tools say so and read through fixed forms (a title with quotes and a backslash comes through whole); eval and undo exist only when switched on, and a refused eval runs nothing; a workspace, window number, theme or snapshot id that isn't there is refused before Lisp or a shell; the notification is the agent's, its markup escaped; calls are logged; register adds it to Claude Code with the flags; malformed input (params as a list, a list as a name, a lone surrogate, deep nesting, bytes that aren't UTF-8, a batch) gets an error and the server lives on; a title with `=> ` doesn't cut the answer; a failed command or a Lisp error is an error; notifications start Agent:; the session's DISPLAY is used when missing; a theme named like Lisp is neither offered nor taken; at a terminal it shows its help, and a misspelt flag is refused; refused calls are logged, the log 600; after its files change it answers with the new code in the same process, losing no request and saying the tools changed, and leaves new code that doesn't compile alone |
| `ai-keys` | `vikix-ask` (`s-i`) writes `~/.config/vikix/ai` on first use and takes the model from it: llama3.2:3b first, else your first local model, the one named there (a name with anything odd in it refused), or Claude only with `use=claude` and a key, never by itself; the menu's choice leads to its action; Proofread/Rewrite/Translate copy the answer without the model's "Here is…"; Ask sends the question with the selection; a short answer is a notification, a long one a terminal; nothing selected, the clipboard, then a plain message; llm's key error points to `vikix ai key`; Proofread lists its changes; the answer's terminal doesn't keep the lock; `vikix ai use` (and the menu) switch, Claude only with a key; any typed language; `use=Local`; a misspelt action is said |
| `ai-local` | `vikix ai setup` refuses a download with the wrong checksum, installs only the CPU's and Vulkan's parts (no NVIDIA libraries), puts `ollama` on PATH, deletes the download, keeps models out of backups, and a second run downloads nothing; the picker offers 7–8B models only where they fit (16 GB, not 8 GB), marks what you have, and a choice (by number, with a ✓, or in rofi) downloads the right model; `status` says the loaded model's memory and when it unloads; `stop` unloads through the API and says so (a notification from `s-m`); `chat` runs the model; `remove` says plainly what's missing; the bar's note comes and goes with the model; a big log is moved aside; `uninstall` stops only its own processes (a decoy `ollama` survives) and keeps the models unless `--models` (needs Python 3.14's zstd) |
| `bitwarden` | `vikix bitwarden pick` says how to set it up when there's no account, asks the master password first when the vault is locked, and opens nothing when that's cancelled; setup saves the email, the password box, an hour's lock and (`--eu`) the EU server, signs in and syncs, writes the picker's settings once, and says how to register a refused device; uninstall forgets the local copy and keeps your settings |
| `webapp` | `vikix webapp add` gives a preset its address and the first mail one `s-M-m`, keeps an app's key when it's added again, makes a launcher entry with its window class, opts in to Chromium, suggests `https://` for a bare address, and refuses a bad name, an address that isn't https (but localhost), Vikix's own keys (the workspace keys too) and another web app's (saying how to free it); `key` moves or drops a key; `open` starts a Chromium app window with its own class and profile (700); `list` says keys as spoken, points out lines it can't use and logins left behind; `remove` keeps your comments and the logins unless `--forget`; `webapps.lisp` binds the keys, names each as its launcher entry does, adds key help and `s-m` entries (before Power), skips a bad line and loads the rest, and a reload drops what went; the migration adds the web apps' caches to an existing backup-exclude once |
| `features` | `features.list` and `bundles.list` name only lists, features and bundles that exist, and no language list is in the base by mistake; a feature installed by hand counts as had, unless it has a setup command; everything and the base together are every list; with no choices file every list is wanted, plus the old optional ones; `vikix add` installs only the new feature's lists, runs the editors' and languages' stages only when one comes, refuses an unknown name, and records a feature with its own setup (Windows) only once that succeeds; `vikix remove` takes the features only the removed one needed (devtools), keeps one you chose by name or another needs, keeps packages the base, another feature (nodejs for Emacs) or another installed package needs, asks without `--yes`, keeps your comments and a linked choices file; the migration writes an older machine's choices once |
| `welcome` | The software picker lists bundles and features, marks the ones you have (installed by hand too) and adds only what's new; its preview names a feature's packages and setup; the keyboard step offers X's layouts and sets yours in `~/.config/vikix/keyboard` without touching the rest (a linked file stays one) and applies it; each step is ticked; opening it marks it shown; StumpWM opens it at the first login only, and Super+m has Welcome and Add software; the migration marks it shown on a desktop in use |
| `menu` | An `s-m` entry that names what it needs (a program on PATH, or a file under `~/`) is shown only when that is there, so JupyterLab, Zeal, Printers, Windows, local AI and Dropbox appear with their features; the rest always; every need named is a real package or file |
| `pkg` | `vikix pkg add NAME` installs a package by its name at once, and other words open a search that leaves out what's installed; `drop` asks unless `--yes`, and a package a wanted list names goes on the skip list (the feature's `vikix remove` named when it has one); `10-packages` leaves the skip list out and says so; adding again takes a package off, keeping your comments and a linked file |
| `oneline` | `site/install`, piped into bash as `curl … \| bash -s -- ARGS` would: it clones Vikix and runs `install.sh` with the arguments, refuses another system, musl and root before changing anything, installs git first when it's missing, updates a clone already there and leaves alone a folder that isn't one, and a download cut off halfway runs nothing |
| `man` | Every `bin/vikix*` gets a man page from its header (`lib/man.py`): the forms under SYNOPSIS, the prose under DESCRIPTION, the `~/` paths it names under FILES, the commands it names under SEE ALSO, with nothing for mandoc's lint to warn about; a header out of shape fails with its reason and costs only its own page; a page for a command that's gone is removed, one of yours is not; `40-config` installs them once, and `man` finds them through `MANPATH` beside the system's; the commands of the plugins in your list get pages too, and lose them when the plugin goes; a page that isn't Vikix's is never written over; `docs/commands.md` is the same headers as a guide page (`lib/man.py --guide`), and the test fails when it is out of date |
| `info` | The guides in `docs/` make an Info manual with no makeinfo warnings and a node for every heading; a broken link or a page missing from the table stops the build; `40-config` installs it once and lists it in the info `dir`; Emacs opens it and follows a link (needs makeinfo) |
| `home` | `40-config` and `60-login` change nothing when run again, and `vikix undo` puts your files back (and undoing again brings the change back); API keys never reach the history, even when `yours.list` names their folder, and on a history older than that rule; you get a `rules.lisp` of your own, a copy, which a second run leaves as you changed it |
| `ai` | `vikix ai key set` keeps a key 600 in a 700 folder and never prints it (a fingerprint instead), refuses names that aren't keys' (`PATH`, `LD_PRELOAD`, `ANTHROPIC_BASE_URL`), typos and a key typed on the command line; only keys' names from real files of yours are exported, in shells and the session (whose log's trace is off while they load); `check` finds a key in your files, `~/.profile` and the like, and their history, by file and line, names a dotfile linked into a git repo and anything odd in the folder, and is quiet once all's fixed; `vikix agent` and `vikix update` run without the keys |
| `swank` | With a real Swank: without `~/.slime-secret`'s password, or with a wrong one, nothing runs, and Swank goes on; a client that connects and stays silent keeps `vikix eval` out for no more than a few seconds; a Swank started before the guard is restarted, guarded, by the next reload; `vikix eval` sends it and works; `40-config` makes it once, 600 (needs sbcl and Quicklisp) |
| `errors` | `errors.lisp` loads a file a form at a time: a form that fails is skipped and the rest load, a `(` never closed skips the rest, the line given is the form's own; each error is written down (the newest kept), with the name of what it defined still pointing at its file; it makes a float timer's time whole and stops asking after three errors in 20 seconds (needs Quicklisp's StumpWM) |
| `update` | `vikix update` runs the new version's steps after it pulls, logs the whole run, carries on past a failed stage, naming it at the end, and pulls a checkout with an SSH remote over HTTPS; changes made in the checkout are set aside in a patch file and a named stash (a dry run only says so), editors' leftovers are ignored, and the update goes on; a clash left in the checkout, or a commit made there, stops it with the commands to fix it; `update core` runs only 10-packages, 20-services, 40-config, the migrations and the reload (no Void upgrade, no editors or tools), and `--from DIR` pulls DIR's main instead of GitHub, a fast-forward only, refused when the checkout went another way, and only with core; `update system` only Void's packages (no pull, no stages), `update tools` only 45-editors, 65-languages, 67-dev, llm and your pipx, uv (never Vikix's pinned llm and Piper) and cargo programs; an unknown part is refused |
| `packages` | Every name in `packages/*.list` is a real Void package |
| `dry-run` | Both install parts run through with `--dry-run`, and leave the offline docs to `vikix docs get` |
| `nvim` | `45-editors` for Neovim, without the network: a new machine gets the starter, the link to Vikix's part and the tested lock, with the plugins restored (Lazy's output in a log of its own) and a snapshot after; an update with nothing new restores nothing; a newer lock from Vikix moves Vikix's plugins on and keeps the ones you added, and leaves versions you moved (said once per lock); 0.55.0's state carries over; an unchanged clone of `nvim-void-linux` is set aside for the starter, said last, and one with your changes or commits stays; `VIKIX_NVIM_REPO`, a clone and a folder of your own are left to you, and a clone stays out of the snapshots; a dry run changes nothing; the Lua compiles |
| `editors` | The Emacs config and Vikix's Neovim config install from scratch into an empty home and start without errors, Neovim with Vikix's part and CodeCompanion loaded (its agents started by `vikix agent --acp`), its AI keys saying what's missing rather than failing, and treesitter highlighting Markdown, Lua, Python and Typst |

## Folder layout

| Path | Contents |
|---|---|
| `install.sh` | Runs the stages in order: the base, then `--with` features. `install-1.sh` and `install-2.sh` are from before 0.47 |
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
| `docs/` | The user's guides: where everything is, how it fits together, customizing, fixing. Installed as an Info manual too (`info vikix`, or `C-h i` in Emacs) and as web pages (Super+m → *Vikix guide in the browser*). `docs/diagrams/` holds the diagrams: Mermaid sources, the SVGs `render.sh` draws from them, and a text version of each for Info |
| `site/` | The website, [vikix.dev](https://vikix.dev): static pages (the front page and the gallery) and the one-line install, published to GitHub Pages by `.github/workflows/pages.yml` |

## Not done yet

- **Installer ISO.** None yet. For now it's a script on top of a plain Void install.

## Contact

Questions and ideas: [Discussions](https://github.com/vukini/vikix/discussions). Bugs: [Issues](https://github.com/vukini/vikix/issues). Anything else, or a security problem you'd rather not post in public: **vikid@vikix.dev**.

Vikix is made by The Vikid Truth and owned by The Living Studios FZE LLC, Ajman, UAE. MIT licence: see [LICENSE](LICENSE).
