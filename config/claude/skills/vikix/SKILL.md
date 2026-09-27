---
name: vikix
description: How the Vikix desktop (Void Linux + StumpWM, vikix.dev) is put together, which files you may change, and how to change the running desktop safely. Use for any request about this machine's desktop, keys, themes, window manager, packages, services, or the vikix command.
---

# Vikix

This machine runs **Vikix**: an opinionated desktop layer on top of an
ordinary **Void Linux** install, built around the **StumpWM** window
manager (written in Common Lisp). Think of it as Void, supercharged:
inspired by Omarchy, but its own thing.

Void is not a systemd distribution. Remember:

- Packages: `xbps-install -S NAME` (with sudo), `xbps-query -Rs WORD` to search, `xbps-remove -R NAME`.
- Services are runit: switch one on with `sudo ln -s /etc/sv/NAME /var/service/`, off by removing that link, status with `sudo sv status NAME`. There is no `systemctl` and no user services; session programs start in `bin/vikix-session`.
- glibc Void. elogind runs through dbus, never as a runit service.
- The network is NetworkManager (`nmtui`, `nmcli`).

## The one rule: change the user's files, never Vikix's

Every config file belongs either to Vikix or to the user.

**Vikix's files** are symlinks into the Vikix checkout. `vikix update`
replaces them, so any edit there is lost, and it breaks the update
(`git pull --ff-only`). **Do not edit them**:

- `~/.stumpwm.d/init.lisp`, `~/.stumpwm.d/vikix/` (theme, groups, commands, windows, keys, help, modeline, swank)
- `~/.xinitrc`, `~/.local/bin/vikix*`, `~/.config/vikix/vikix.bash`
- this skill, and everything else in the checkout. Find the checkout with `readlink -f ~/.local/bin/vikix` (it is `<checkout>/bin/vikix`); normally `~/vikix`.

**The user's files** are copies they own. Make changes here:

| Want to change | Edit |
|---|---|
| Anything in StumpWM: keys, theme, terminal, new commands, startup programs | `~/.stumpwm.d/user.lisp` (loads last, so it wins) |
| Terminal look | `~/.config/alacritty/alacritty.toml` |
| Compositor, notifications, launcher | `~/.config/picom/picom.conf`, `~/.config/dunst/dunstrc`, `~/.config/rofi/config.rasi`. picom reloads its config when the file changes, and switching its `backend` that way (glx to xrender) has frozen a desktop: for a backend change, `pkill picom`, edit, then `picom -b`. |
| Minutes before lock, dark screen, suspend on battery | `~/.config/vikix/idle` (`LOCK=`, `SCREEN_OFF=`, `SUSPEND=`; 0 never suspends), then log in again |
| Keyboard layout and options (e.g. `ctrl:swapcaps`) | `~/.config/vikix/keyboard`, then run `vikix-keyboard` |
| Which program opens which file type | `~/.config/mimeapps.list` (images: `vikix-image.desktop`, nsxiv with the rest of the folder) |
| Text size on a high-resolution screen | `~/.Xresources` (`Xft.dpi`, `Xcursor.size`); takes effect at the next login |
| Shell aliases, PATH additions | `~/.bashrc`, **after** the `# <<< vikix ... <<<` blocks. Never edit inside a `# >>> vikix NAME >>>` block; Vikix rewrites those. |

If the user asks for a change that can only be made in Vikix's own files
(a bug in Vikix, a new default for everyone), say so, and offer to write
it as a change to the checkout that they can review and commit. Don't
make it silently.

## Before and after changing files

The user's files have a history of their own (a git repository in
`~/.local/state/vikix/yours.git`, work tree `~`; `config/yours.list` in
the checkout names the files). Use it:

1. **Before** the first change: `vikix snapshot "before: <what you're about to do>"`.
   (`vikix agent`, which is how Super+a starts you, already took one.)
2. Make the change.
3. **After**: show it with `vikix changes`, and tell the user they can
   take it back with `vikix undo`.

Other commands: `vikix history` lists snapshots; `vikix undo ID` goes
back to a given one; `vikix changes ID` shows what one snapshot changed.
An undo is itself a snapshot, so a second `vikix undo` reverses it.
Don't run `vikix undo` unless the user asks for it.

## The running desktop: `vikix eval`

StumpWM is a live Lisp image with a Swank server on `127.0.0.1:4004`.
`vikix eval` sends Lisp to it and prints what came back:

```sh
vikix eval '(+ 1 2)'                              # => 3
vikix eval '(mapcar (function group-name) (screen-groups (current-screen)))'
vikix eval '(mapcar (function window-class) (group-windows (current-group)))'
vikix eval '(lookup-key *top-map* (kbd "s-a"))'   # what a key runs
vikix eval '(message "Hello")'                    # show a message on screen
vikix eval < some-file.lisp                       # several forms from stdin
```

- Forms are read in the `STUMPWM` package, and run in StumpWM's main thread.
- Each value is printed after `=> `. Errors print `error: ...` and exit 1; they never hang. Exit 2 means StumpWM couldn't be reached (not running, or a menu or prompt was open: ask the user to close it).
- **Changes made with `vikix eval` are live only.** They're gone at the next reload or login. To keep one, also write it into `~/.stumpwm.d/user.lisp`.
- To apply an edited `user.lisp`: `vikix eval '(loadrc)'` reloads everything (Vikix's files, then user.lisp). If user.lisp has an error, StumpWM shows it on screen and keeps running; the rest still loads.
- Don't evaluate anything that waits for keyboard input (`read-one-line`, `select-from-menu`, commands with prompts): it blocks the main thread until the user answers.
- Don't call `(quit)`, `(restart-hard)`, or anything that ends the session, unless the user asks.

A good workflow for a StumpWM change: try it live with `vikix eval`,
let the user see it, then write the same form into `user.lisp`.

## What Vikix defines in StumpWM (use these in user.lisp)

- `(vikix-bind "s-KEY" "command")` binds a Super key (`s-` Super, `C-` Ctrl, `M-` Alt; `s-H` means Super+Shift+h). Commands are StumpWM command strings: `"exec firefox"`, `"vikix-terminal"`, `"move-focus left"`.
- `*vikix-bindings*` is the list of Vikix's keys: `(key command description)`. The key help (Super+F1) is built from it, so to make a user key show up there too: `(push '("s-y" "exec xterm" "XTerm") *vikix-bindings*)` then `(vikix-bind "s-y" "exec xterm")`.
- `(setf *vikix-terminal* "xterm")` changes the terminal Super+Return opens.
- Themes: `vikix theme NAME` (shell) switches everything (StumpWM, terminals, rofi, dunst, lock screen) and saves the choice; `vikix theme` lists them. A theme is a file of colours: `themes/NAME.theme` in the checkout, or the user's own in `~/.config/vikix/themes/NAME.theme` (copy `void.theme` and change it). Programs get the colours from files `vikix theme` writes into `~/.config/vikix/theme/`, which their configs include; don't edit those, they're overwritten. `(vikix-apply-theme :name)` in Lisp repaints StumpWM alone. The wallpaper: `vikix-wallpaper` (pick, FILE, theme, off, which); `~/.config/vikix/wallpaper-off` means the user sets it with their own tool (feh, nitrogen, a rotator in user.lisp) and Vikix never touches it; the user's choice is the link `~/.config/vikix/wallpaper`, otherwise the theme's picture beside its theme file (themes/void.jpg), otherwise a plain background in the theme's bg. `vikix theme NAME` applies it too; `vikix update` doesn't. StumpWM's bar, menus and messages are in Iosevka through the contrib module ttf-fonts: `bin/vikix-font` makes `~/.local/share/vikix/fonts/wm.ttf` (Iosevka Regular out of Void's .ttc, or a link to Noto Sans Mono), and theme.lisp loads only that folder. Never run the module's `cache-fonts` over `/usr/share/fonts` in the running StumpWM: it takes minutes and the desktop stops meanwhile. The size is `*vikix-font-size*` (11), settable in user.lisp before calling `(vikix-set-font)` again.
- Backups: `vikix backup` (restic) backs up all of `~` except what `~/.config/vikix/backup-exclude` names (the user's file; add big rebuildable folders there). `vikix backup setup PLACE` once (a mounted USB drive, or any restic repository), then `vikix backup`, `status`, `list`, `restore PATH [ID]` (into `~/Restored/<time>/`, never over the original), `check`, `off`. The password is `~/.config/vikix/backup-password`: never print, copy or commit it. Nothing runs by itself; the bar's `backup 9d` is the reminder.
- Printing: CUPS, with the runit services `cupsd`, `avahi-daemon` (finds network printers) and `ipp-usb` (driverless USB printers). The user adds printers with Super+m → Printers (system-config-printer) or http://localhost:631, and is in the `lpadmin` group, so no password (Vikix's polkit rule `/etc/polkit-1/rules.d/50-vikix-printers.rules` covers the app). From a shell: `lpinfo -v` lists the printers found, `lpadmin -p NAME -E -v URI -m everywhere` adds a driverless one, `lpstat -p` lists them, `lp FILE` prints. An older printer may need a driver package (gutenprint, foomatic and brlaser are installed; `hplip` for HP).
- `*vikix-menu*` is the Super+m menu: a list of `(label action)`, where the action is a command symbol or a Lisp form. Add to it with `push` or `append` in user.lisp.
- `(vikix-in-terminal "shell command")` runs a command in a terminal that waits for Enter.
- `(run-shell-command "program")` starts a program; put startup programs in user.lisp.
- Commands are defined with `(defcommand name (args) (prompts) "doc" body)`; `(documentation 'name 'function)` shows a command's description.

The keys as installed (Super+F1 shows the live list): Super+Return
terminal, Super+d launcher, Super+w browser, Super+e files, Super+a this
agent, Super+x an Emacs window, Super+c clipboard history (clipmenu),
Super+. emoji picker and Super+= calculator (vikix-rofi: rofi-emoji,
rofi-calc with qalculate; Enter copies the answer), Super+n / Super+Shift+n the last
notification again / pick an earlier one, Super+Ctrl+n close all,
Super+Alt+n do not disturb (dunstctl; the bar says quiet; the bar also shows `bt`, or `bt DEVICE 80%`, while Bluetooth is on, from bin/vikix-bt), Super+Alt+a keep
awake (vikix-idle; no lock, dark screen or suspend; the bar says awake),
Super+Alt+l night light on/off (vikix-nightlight, gammastep; times and
colours in the user's ~/.config/gammastep/config.ini; off lasts across logins),
Print a screenshot of an area (or a clicked window), Ctrl+Print of the
focused window, Super+Print of the monitor under the pointer, all to the
clipboard (vikix-screenshot; add Shift for a file in
~/Pictures/Screenshots), Super+Shift+r record an area or window and again
to stop (vikix-record, ffmpeg, no sound; the bar says rec; videos in
~/Videos/Recordings), Super+Ctrl+Print a menu of all of them, Super+q close, Super+f fullscreen, Super+h/j/k/l focus (Shift to
move the window; the arrow keys do the same), Super+b / Super+v split,
Super+r remove split, Super+u / Super+Shift+u undo / redo a layout
change, Super+g gaps on/off, Super+Shift+a / Super+Ctrl+a any window on
any workspace (go there / bring it here), Super+p pointer to the focused
window, Super+1..9 workspaces, Super+Ctrl+1..9 send the
window there, Super+m the Vikix menu, Super+Escape lock, Super+Shift+Escape the power menu (lock, suspend, log out, reboot, power off). StumpWM's own
keys follow the prefix Ctrl+t. Focus follows the mouse (sloppy focus).

## Checking and fixing

- `vikix doctor` checks programs, services, links, the snapshot history and that `vikix eval` works. Start here when something is broken.
- The bar shows `updates N` / `Vikix update` when `vikix update` has something to bring; `vikix-updates` checks (every 6 hours, from the session) and saves the counts in `~/.local/state/vikix/updates`.
- `vikix update` pulls Vikix, updates Void, adds new packages and switches on their services, re-links the config, and reloads the running StumpWM so new keys, bar and menu take effect; a failed step is named at the end, and the rest still run; `vikix migrate` runs one-off fixes; `vikix rebuild-wm` rebuilds the StumpWM binary after a Quicklisp update; `vikix docs` downloads the offline programming docs into `~/dev` (a few GB, slow, so `vikix update` and the installer skip it).
- Languages are `packages/lang-*.list` in the checkout, one per language (C, Python, Lisps, Haskell, Forth, WebAssembly, JavaScript, Ruby, SQL, Lua, Go, Zig, Rust, Java, OCaml, Julia, Free Pascal); `65-languages` builds PicoLisp, builds Lazarus's docked IDE into `~/.lazarus` (start it with `vikix-lazarus`, not `startlazarus`, which picks Void's undocked one), and fetches Julia with juliaup. In StumpWM (windows.lisp) the docked Lazarus window tiles and every other Lazarus window floats.
- Installer stages are `<checkout>/install/NN-name.sh`; re-run one with `<checkout>/install.sh --only NN-name`. Each checks before it changes anything, so re-running is safe.
- The session starts from tty1: `~/.bash_profile` runs `startx`, `~/.xinitrc` runs `vikix-session`, which starts pipewire, dunst, picom, the Emacs daemon, then StumpWM (`~/.local/bin/stumpwm`).
- `sudo` asks for a password. Tell the user before running anything with sudo, and prefer to give them the command when it changes the system (packages, services, `/etc`).
