# Vikix

**Vikix** — [vikix.dev](https://vikix.dev) — is an opinionated desktop layer for **Void Linux**, built around **StumpWM**.

It is to Void what Omarchy is to Arch. It is not a new distribution: it is a script run on top of an ordinary Void install. What you get:

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

Each part asks for your password **once**, at the start, and then runs by itself, so you can walk away. Part two says when it has finished with a notification. Everything each part prints is also kept in `~/.local/state/vikix/logs/`.

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
| `20-services` | 1, 2 | Enables the runit services in `services.list`, and adds you to the `video` group. |
| `25-network` | 1 | Starts NetworkManager, waits until it's running, then switches off dhcpcd and wpa_supplicant. Adds you to the `network` group. |
| `30-lisp` | 1 | Installs Quicklisp (and adds it to `~/.sbclrc`), builds `~/.local/bin/stumpwm` with Swank inside, and clones `stumpwm-contrib`. |
| `40-config` | 1 | Links Vikix's config files into place and copies starter files you then own (including the keyboard file). |
| `45-editors` | 2 | Clones the Emacs config (`vukini/emacs-void`) to `~/.emacs.d` and the Neovim config (`vukini/nvim-void-linux`) to `~/.config/nvim`, installs the npm language servers into `~/.local`, and installs Neovim's plugins. Other repos: set `VIKIX_EMACS_REPO` / `VIKIX_NVIM_REPO`. |
| `55-hardware` | 2 | Touchpad settings (tap to click, natural scrolling), the Intel microcode rebuilt into the initramfs, and the standard `~/Documents` … folders. |
| `50-audio` | 2 | Sets up PipeWire, WirePlumber and the ALSA links, as the Void handbook describes. |
| `60-login` | 1 | Adds `~/.local/bin` to PATH, loads the aliases in every shell, and makes X start after login on tty1. |
| `65-languages` | 2 | Builds the languages Void doesn't package (PicoLisp). The packaged ones are lines in `packages/lang-*.list`. |
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

**Later versions** arrive with `vikix update`, which pulls from GitHub.

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
  - `~/.config/vikix/vikix.bash`, the aliases and prompt
  - `~/.claude/skills/vikix`, which tells Claude Code how Vikix works
- **Your files** are copied once, then never touched again:
  - `~/.stumpwm.d/user.lisp`, which loads last, so anything in it wins
  - the configs under `~/.config` for alacritty, picom, dunst and rofi
  - `~/.config/vikix/keyboard`: layout and XKB options, applied at every login. The starter swaps Caps Lock and Left Ctrl (`ctrl:swapcaps`); edit it, then `s-m` → "Apply keyboard settings". For Esperanto, it explains the options that put ĉ ĝ ĥ ĵ ŝ ŭ on Right Alt + c g h j s u, leaving every other key alone
  - `~/.Xresources`: text size. Raise `Xft.dpi` on a high-resolution screen (144 for a 14" 2.8K panel), then log in again

`config/yours.list` names your files, and Vikix keeps a history of them (see [Undo](#undo-for-your-files)).

If you already had a StumpWM config, it becomes your `user.lisp`. Anything else Vikix has to replace is moved aside to `<name>.vikix-bak.<time>`, never deleted.

## Keys

`s` means Super. StumpWM's own `Ctrl+t` prefix keys still work too.

| Key | What it does |
|---|---|
| `s-Return` | Terminal |
| `s-d` | Launcher |
| `s-w` | Browser (Firefox) |
| `s-e` | Files (PCManFM) |
| `s-a` | AI agent: Claude Code in a terminal |
| `s-x` | Emacs: a new window (the Emacs server is already running) |
| `s-c` | Clipboard history: pick something copied earlier, then paste it |
| `s-q` | Close window |
| `s-f` | Fullscreen |
| `s-h` `s-j` `s-k` `s-l` | Move focus left, down, up, right |
| `s-H` `s-J` `s-K` `s-L` | Move the window |
| `s-←` `s-↓` `s-↑` `s-→` | Focus, on the arrows (in a VM on Windows, Super+L locks the host instead of reaching the guest) |
| `s-C-←` `s-C-↓` `s-C-↑` `s-C-→` | Move the window, on the arrows |
| `s-b` | Split side by side |
| `s-v` | Split one above the other |
| `s-r` | Remove the split |
| `s-1`…`s-9` | Go to a workspace |
| `s-C-1`…`s-C-9` | Send the window to a workspace |
| `s-m` | Vikix menu: key help, all commands, "what does a key do?", themes, network, screens, update, suspend / reboot / power off |
| `s-F1` | Every key, searchable. Pick one to run it. |
| `s-Escape` | Lock the screen |
| `Print` | Screenshot an area to the clipboard |
| `Shift+Print` | Screenshot an area to `~/Pictures/Screenshots` |
| volume and brightness keys | Change the level and show a bar for it |

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

## What gets installed

| List | Contents |
|---|---|
| `base` | dbus, elogind, polkit and its password box, openssh, chrony (clock), git, curl, rsync, zip, 7zip, man pages, xdg-utils |
| `desktop` | X11, picom, dunst, rofi, alacritty, fonts (Noto, Nerd Font symbols), i3lock, screenshots, clipmenu (clipboard history) |
| `fonts` | Iosevka, the terminal font. Every variant comes in one 862 MB package, so it waits for part two; until then the terminal uses a plain monospace font. |
| `network` | NetworkManager (`nmtui` for Wi-Fi), with its connection editor |
| `audio` | PipeWire, WirePlumber (with Bluetooth audio), pamixer, pavucontrol |
| `laptop` | tlp, acpid, brightnessctl, Bluetooth (bluez, blueman), autorandr, and the firmware a recent ThinkPad needs: sof-firmware (sound), intel-ucode (from the nonfree repo, enabled by `repos.list`), intel-video-accel |
| `editors` | Emacs, Neovim, the pdf-tools build deps, and the language servers Void packages (ccls, lua-language-server, gopls, efm-langserver) plus nodejs for the npm ones |
| `apps` | Firefox, PCManFM with USB mounting, mpv, nsxiv, zathura |
| `dev` | base-devel (gcc, make), gdb, valgrind, python3, rlwrap |
| `cli` | htop, ripgrep, fd, fzf, bat, eza, tmux, tree, jq, zoxide, yazi, lazygit, atuin (with bash-preexec) |
| `lisp` | SBCL |
| `lang-*` | One file per language, so a language is one file to keep or delete: C extras (tcc, rr, cmake, meson, ninja, shellcheck, shfmt), Python (pip, ipython, pipx), Lisp and Scheme (ccl, racket, chez-scheme, guile), Haskell (ghc, cabal, HLS, hlint), Forth (gforth), WebAssembly (wabt, wasmtime), Ruby, SQLite (sqlite, litecli, sqlitebrowser), Lua (lua54, LuaJIT), Go, Zig (zig, zls), and `lang-tools` (tree-sitter, ctags, entr, hyperfine, tokei, just) |

## Laptop

- **Docking.** Arrange the monitors once with `s-m` → *Screens: arrange*, then `s-m` → *Screens: save this layout* and call it `default` (or `desk`, `home` …). autorandr re-applies the matching layout whenever those monitors are plugged in, and at login.
- **Suspend** from the `s-m` menu or by closing the lid; the screen locks first. **Reboot** and **Power off** are there too, through elogind, no sudo.
- **Touchpad**: tap to click, natural scrolling, off while typing (`/etc/X11/xorg.conf.d/40-libinput.conf`, installed by `55-hardware`).
- **Battery.** `vikix-battery` warns at 15% and again, urgently, at 5% (change them with `VIKIX_BATTERY_LOW` / `VIKIX_BATTERY_CRITICAL`). It only starts on a machine with a battery; `vikix-battery --once` shows the charge.
- **High-resolution screen.** Set `Xft.dpi` in `~/.Xresources` (see the file for values), then log in again.
- **Which program opens what** is `~/.config/mimeapps.list`, yours after the first copy: Firefox for links, zathura for PDFs, nsxiv for images, mpv for video and audio.

## Editors

Both configs are separate repositories, cloned by `45-editors` and pulled by `vikix update`; Vikix never edits them.

- **Emacs** — `~/.emacs.d` is [vukini/emacs-void](https://github.com/vukini/emacs-void). `vikix-session` starts `emacs --fg-daemon` at login, so `e` (`emacsclient -c -a ""`) opens a frame at once. The first start on a new machine installs the packages from MELPA in the background; give it a few minutes before the first `e`. SLIME connects to StumpWM on port 4004.
- **Neovim** — `~/.config/nvim` is [vukini/nvim-void-linux](https://github.com/vukini/nvim-void-linux), an [AstroNvim](https://astronvim.com) v5 setup. Plugins are installed by the stage to the versions in `lazy-lock.json`; on the first start, Mason adds the tools the config names (stylua, debugpy, tree-sitter-cli) in the background. `v` opens it.
- **Language servers** on PATH for both: `ccls`, `lua-language-server`, `gopls`, `efm-langserver` from Void; `typescript-language-server`, `pyright`, `bash-language-server` from npm in `~/.local/bin`.

## Languages

Vikix is for playing with languages, so it installs them. Each is a small file in `packages/`; delete the file to drop the language, add a line to add a tool.

| Language | Packages | Try |
|---|---|---|
| C | gcc and friends (`base-devel`), clang, gdb, valgrind, tcc, rr, cmake, meson, ninja | `tcc -run hello.c` |
| Python | python3, pip, ipython, pipx | `ipython` |
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

Language servers for the editors are in `editors.list` and `45-editors`.

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
| `nvd A B` | Neovim diff of two files |
| `eq`, `ekill`, `emacs-restart` | Emacs with no config (for debugging it), stop the daemon, restart it (refuses with unsaved buffers) |
| `b` | bat: `cat` with colour. Plain `cat` is left alone. |
| `mkd` `cpr` `chx` `xo` | `mkdir -p`, `cp -r`, `chmod +x`, open with the usual program |
| `psg NAME` / `hg WORD` | find a running process / a line in your history |
| `r` | reload `~/.bashrc` |
| `xi` `xu` `xr` `xs` `xl` | xbps: install, update everything, remove, search, list a package's files |
| `svls`, `sv-on NAME`, `sv-off NAME` | runit: list services, switch one on, switch one off |
| `g` `gst` `gl` `gla` `gd` `gds` | git, status, log graph (this branch / all), diff (unstaged / staged) |
| `ga` `gaa` `gcm` `gca` `gamend` | add, add everything, commit with a message, commit every change, amend |
| `gundo` `gwip` | undo the last commit (changes stay staged), commit everything as "wip" |
| `gco` `gsw` `gb` `gps` `gpl` `gf` `gr` `gsh` `gshp` | checkout, switch, branches, push, pull, fetch, remotes, stash, stash pop |
| `lg` | lazygit |
| `sbcl` | SBCL with history and arrow keys (through rlwrap) |
| `activate` | the Python virtual environment in `.venv` |
| `a` | Claude Code, after a snapshot of your files |
| `Ctrl+R` | atuin: search all your history, from every terminal |
| `Ctrl+T` / `Alt+C` | fzf: pick a file / a folder |

Git status is `gst`, not `gs`, which is Ghostscript's command.

Put your own aliases in `~/.bashrc`. Vikix's line sits at the top of that file, so anything you write below it loads later and wins.

## Everyday commands

```sh
vikix update       # pull Vikix, update Void, new packages, config links, editor configs, migrations
vikix migrate      # only the migrations not yet applied
vikix rebuild-wm   # rebuild the StumpWM executable
vikix doctor       # check everything is in place (programs, services, XDG_RUNTIME_DIR, the agent's pieces)
vikix eval FORM    # run Lisp in the running StumpWM
vikix agent        # Claude Code (Super+a)
vikix snapshot / changes / history / undo   # the history of your files
```

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
| `migrations/` | One-off changes for machines already installed (see its README) |

## Not done yet

- **System tray.** StumpWM has no tray, so the network and Bluetooth applets aren't started. Use `nmtui` and `blueman-manager` instead; both are in the `s-m` menu.
- **Theme switching.** It only covers StumpWM so far. The terminal, dunst and rofi copies keep the dark colours.
- **Installer ISO.** None yet. For now it's a script on top of a plain Void install.
