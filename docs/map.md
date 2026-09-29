# Where everything is

What Vikix put on your machine, where, and whose it is. Three kinds of file:

- **Vikix's**: a symlink into the checkout. `vikix update` replaces it. Don't edit it; your change would be lost, and `vikix update` would stop, because it pulls with `git pull --ff-only`.
- **Yours**: copied once from a starter in `~/vikix/config/`, then never touched again. Edit freely. These have a history: see [undo](customize.md#before-you-change-anything).
- **Written for you**: made by a Vikix command and written again whenever that command runs. Don't edit these either; change what they're made from.

`ls -l` tells the first two apart: Vikix's files show `-> /home/you/vikix/...`.

## Your home folder

```
~/
├── vikix/                     the checkout: Vikix itself (see below)
│
├── .stumpwm.d/
│   ├── init.lisp              Vikix's   loads Vikix's layer, then user.lisp
│   ├── vikix/                 Vikix's   the layer: theme, groups, commands, windows, keys, help, webapps, modeline, swank
│   ├── user.lisp              yours     your StumpWM settings; loaded last, so they win
│   └── modules/               stumpwm-contrib, cloned by 30-lisp (swm-gaps, ttf-fonts, ...)
│
├── .xinitrc                   Vikix's   runs vikix-session inside dbus-run-session
├── .bash_profile              yours     with Vikix's marked blocks: PATH, read .bashrc, startx on tty1
├── .bashrc                    yours     with one marked block at the top that reads vikix.bash
├── .Xresources                yours     text size (Xft.dpi) and cursor size
├── .sbclrc                    yours     loads Quicklisp (added by 30-lisp)
├── .slime-secret              yours     Swank's password (600): Emacs and vikix eval send it
│
├── .config/
│   ├── vikix/
│   │   ├── vikix.bash         Vikix's   aliases, prompt, fzf/zoxide/atuin setup
│   │   ├── keyboard           yours     layout and XKB options
│   │   ├── idle               yours     minutes before lock, dark screen, suspend (make it; see customize.md)
│   │   ├── backup             yours     where backups go, and the reminder's days
│   │   ├── backup-exclude     yours     what backups leave out
│   │   ├── backup-password    yours     the backup password (never in snapshots)
│   │   ├── secrets/           yours     API keys, one file each (vikix ai key); never in snapshots
│   │   ├── ai                 yours     which model Super+i uses: use=local or claude, model=, languages=
│   │   ├── agent              yours     which agent Super+a starts (vikix agent --default NAME)
│   │   ├── dictation          yours     dictation's model: base.en or small (vikix dictate models)
│   │   ├── features           yours     the features you chose (vikix add, vikix remove, vikix features)
│   │   ├── packages-skip      yours     packages you dropped (vikix pkg drop); updates leave them out
│   │   ├── windows            yours     where the Windows VM's disk is
│   │   ├── webapps            yours     your web apps: NAME URL [KEY] (vikix webapp)
│   │   ├── wallpaper          yours     a link to the picture you chose
│   │   ├── wallpaper-off      yours     exists if you set the wallpaper with your own tool
│   │   ├── themes/            yours     your own themes (NAME.theme, NAME.jpg)
│   │   └── theme/             written   each program's colours, and `current`, the theme you chose (`vikix theme`)
│   ├── alacritty/alacritty.toml   yours  imports ../vikix/theme/alacritty.toml
│   ├── picom/picom.conf           yours  the compositor: shadows, fading, backend
│   ├── dunst/dunstrc              yours  notifications
│   ├── dunst/dunstrc.d/10-vikix-theme.conf   written   the theme's colours for dunst
│   ├── rofi/config.rasi           yours  the launcher and menus
│   ├── gammastep/config.ini       yours  night light times and colours
│   ├── mimeapps.list              yours  which program opens which kind of file
│   ├── fontconfig/conf.d/50-vikix-iosevka.conf   Vikix's   monospace means Iosevka
│   ├── udiskie/config.yml         yours, if you make it: replaces Vikix's udiskie settings
│   └── nvim/                      yours     with the feature neovim: init.lua (your settings at its end), your plugins in lua/plugins/, lazy-lock.json
│
├── .emacs.d/                  with the feature emacs: a git clone of the Emacs config (vukini/emacs-void)
├── .claude/skills/vikix       Vikix's   tells Claude Code how Vikix works
│
├── .local/
│   ├── bin/
│   │   ├── vikix, vikix-*     Vikix's   the command and its helpers
│   │   ├── stumpwm            built     the window manager, built by 30-lisp (`vikix rebuild-wm`)
│   │   └── pil, claude, ...   installed by 65-languages, the npm language servers, Claude Code
│   ├── share/applications/*.desktop   Vikix's   JupyterLab, vikix-image, Lazarus in the launcher (Super+d); your web apps' too
│   ├── share/vikix/fonts/wm.ttf       built     the bar's font, made by vikix-font
│   ├── share/vikix/nvim               Vikix's   Vikix's part of Neovim: AstroNvim and Vikix's plugins (a link to config/nvim)
│   ├── share/info/vikix.info          written   these guides as an Info manual (`info vikix`)
│   ├── state/vikix/mcp.log            written   every call an agent made to vikix mcp (600)
│   ├── state/vikix/session.env        written   the session's display and D-Bus, for vikix mcp under Codex (600)
│   ├── share/vikix/whisper/           fetched   dictation's model and voice detector (vikix dictate)
│   ├── share/vikix/AGENTS.md          written   the skill as a guide for Codex, Gemini, Aider (linked as ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md)
│   ├── opt/picolisp/          built     PicoLisp, from source (with the feature lisp)
│   ├── opt/ollama/            built     Ollama, for local AI models (vikix ai setup)
│   ├── share/libvirt/images/  the Windows VM's disk and its driver disc (not backed up)
│   ├── share/vikix/webapps/   each web app's own Chromium profile: its logins (caches not backed up)
│   └── state/vikix/           Vikix's record of this machine (see below)
│
├── quicklisp/                 Common Lisp libraries; StumpWM is built from here
├── .lazarus/                  Lazarus with the docked IDE, built by 65-languages
│
├── dev/                       yours, with parts written for you (see below); a folder per language you added
├── .ollama/models/            local AI models (vikix ai models): big, not backed up
├── vikix-debug-*.txt           the reports vikix debug writes (yours to delete; vikix diagnose's are in ~/.local/state/vikix/diagnose/)
├── .config/io.datasette.llm/  llm's settings and its log of everything asked (vikix ai llm)
├── Pictures/Screenshots/      Shift+Print and friends
├── Videos/Recordings/         Super+Shift+r
├── Windows/                   yours     drive Z: in the Windows VM (vikix windows)
└── Restored/                  `vikix backup restore` puts files here, never over yours
```

### `~/.local/state/vikix`: the record of this machine

| Path | What |
|---|---|
| `logs/` | One log per install and per `vikix update`, named by date |
| `session.log`, `session.log.old` | Everything the desktop session printed, this login and the one before. The first place to look when the desktop won't start. |
| `yours.git` | The history of your files (`vikix snapshot`, `changes`, `history`, `undo`). A git repository whose work tree is `~`, limited to the files in `~/vikix/config/yours.list` |
| `migrations/` | Which one-off fixes this machine has had |
| `welcome` | The welcome's steps you've done (`vikix welcome`); that it exists means the welcome has been shown, so it doesn't open at login again |
| `checkout-changes/` | Changes someone made in `~/vikix`, set aside by `vikix update` as patch files (see [When something breaks](fixing.md#an-update-failed)) |
| `diagnose/` | The last five reports `vikix diagnose` gave your agent |
| `jupyter.log` | JupyterLab's messages (`jlab`) |
| `ollama.log` | Local AI's log (vikix ai); one old one is kept as `ollama.log.old` |
| `updates` | What the bar's `updates` field shows, written by `vikix-updates` every 6 hours |
| `initramfs-*` | Marks that the initramfs was rebuilt with this microcode |

### `~/dev`

A folder per language you added (`vikix add python` …), made by `67-dev`: `~/dev/<language>/README.md` (the tools on this machine, and where to learn; **written again by every update**, so keep your notes in another file), `examples/` (copied once, yours), and `docs/` (filled by `vikix docs`). `~/dev/index.html` links every offline doc. Anything else you put in `~/dev` is left alone.

## The checkout: `~/vikix`

Everything Vikix is. `readlink -f ~/.local/bin/vikix` finds it if you cloned it somewhere else.

| Path | What |
|---|---|
| `VERSION` | The version you have (`vikix version`) |
| `install.sh`, `install/` | The installer (the base, then `--with` features) and its stages, `NN-name.sh`. Each is safe to run again: `./install.sh --only 40-config` |
| `bin/` | `vikix` and its helpers, linked into `~/.local/bin`. Each starts with a comment saying what it does. |
| `config/` | Everything that ends up in your home: the files linked there, and the starters copied once |
| `config/stumpwm/vikix/` | The StumpWM layer. Read it to see how a key, the bar or the menu is made, then change it from `user.lisp` |
| `config/yours.list` | The files the snapshot history covers |
| `packages/*.list` | What gets installed, one list per concern, `lang-*.list` one per language. `packages/optional/` holds lists only a feature brings, like the Windows VM |
| `features.list`, `bundles.list` | What `vikix add` offers: each feature's lists, and the bundles (essentials, developer, everything). A list no feature names is the base |
| `services.list` | The runit services Vikix switches on |
| `themes/` | The themes that come with Vikix (`void`, `paper`) and their wallpapers |
| `dev/` | The READMEs and examples `~/dev` is made from |
| `migrations/` | One-off fixes for machines installed before a change |
| `lib/` | Shared shell helpers, and the script that builds StumpWM |
| `docs/` | These pages |
| `site/` | The website, vikix.dev, and `site/install`, the one-line install |
| `tests/` | The tests: `tests/run.sh` |

The checkout is a git repository. `git -C ~/vikix log` shows what each version changed.

## Outside your home

What Vikix changes on the system itself. Everything else under `/` is as Void left it, plus the packages.

| Path | What | By |
|---|---|---|
| `/etc/xbps.d/*-repository-*.conf` | The mirror, the fastest one found at install | `05-mirror` |
| `/var/service/*` | Links that switch on the services in `services.list`, and NetworkManager | `20-services`, `25-network` |
| `/etc/polkit-1/rules.d/50-vikix-printers.rules` | With the feature printing: the `lpadmin` group manages printers without a password | `20-services` |
| `/etc/alsa/conf.d/` | Links that send ALSA programs to PipeWire | `50-audio` |
| `/etc/X11/xorg.conf.d/40-libinput.conf` | Touchpad: tap to click, natural scrolling | `55-hardware` |
| `/boot/initramfs-*` | Rebuilt with the Intel microcode | `55-hardware` |
| `/etc/udev/rules.d/60-vboxguest.rules` | VirtualBox only: the shared clipboard | `70-vm` |
| Groups | You are added to `video`, `network`, `lpadmin` (and `vboxsf` in VirtualBox) | `20-services`, `25-network`, `70-vm` |

dhcpcd and wpa_supplicant are switched off by `25-network`, since NetworkManager does their job.

## Where Void keeps things

Not Vikix's, but you'll want them:

| What | Where |
|---|---|
| Services you can switch on | `/etc/sv/` (switch one on: `sv-on NAME`) |
| Services that are on | `/var/service/` (list them: `svls`) |
| Whether a service is running | `sudo sv status NAME` |
| Package files | `xl NAME` (`xbps-query -f`) |
| Which package has a file | `xbps-query -o /path/to/file` |
