# Making it yours

Each section says which file to change and how to make the change take effect. Every file here is yours, so no update will overwrite it. [Where everything is](map.md) has the full list.

## Before you change anything

```sh
vikix snapshot "before: bigger bar font"   # record your files as they are
# ... make the change ...
vikix changes                              # see exactly what changed
vikix undo                                 # changed your mind: back to the snapshot
```

After an undo, `Super+m` → *Reload config* makes StumpWM use the old settings again.

Or ask the AI agent: `Super+a` starts Claude Code, which knows these rules (from `~/.claude/skills/vikix`) and takes a snapshot before it starts.

## The desktop: `~/.stumpwm.d/user.lisp`

Everything about StumpWM goes in this one file: keys, startup programs, the menu, the bar. It loads after all of Vikix's files, so what you set here wins. Apply a change with `Super+m` → *Reload config*. If there's a mistake, the error shows on screen, and everything else still loads.

To see how Vikix does something before changing it, read its layer in `~/vikix/config/stumpwm/vikix/`: `keys.lisp` for keys, `commands.lisp` for the menu, `modeline.lisp` for the bar.

### Keys

```lisp
(vikix-bind "s-w" "exec chromium")         ; change what a key does
(vikix-bind "s-o" "exec obsidian")         ; a new key
(undefine-key *top-map* (kbd "s-E"))       ; drop one of Vikix's keys
```

`s-` is Super, `C-` Ctrl, `M-` Alt, and a capital letter means Shift: `s-O` is Super+Shift+o. The command is a StumpWM command: `exec PROGRAM` starts a program, and `Super+m` → *All commands* lists the others.

To see a new key in the key help (`Super+F1`), add it to the list the help is built from too:

```lisp
(push '("s-o" "exec obsidian" "Obsidian") *vikix-bindings*)
(vikix-bind "s-o" "exec obsidian")
```

`Super+m` → *What does a key do?* tells you what any key is bound to now.

### Start a program with the desktop

```lisp
(run-shell-command "pgrep -x syncthing || syncthing --no-browser")
```

`user.lisp` runs again on every reload, so the `pgrep -x … ||` keeps a second copy from starting.

### The terminal, focus, and fonts

```lisp
(setf *vikix-terminal* "kitty")            ; what Super+Return opens
(setf *mouse-focus-policy* :click)         ; focus on click, not when the pointer moves over a window
(setf *vikix-font-size* 13)                ; the bar, menus and messages
(vikix-set-font)
```

### The Super+m menu

Each entry is a label and either a command or a Lisp form:

```lisp
(setf *vikix-menu*
      (append *vikix-menu*
              '(("Obsidian" (run-shell-command "obsidian"))
                ("Keys"     vikix-keys))))
```

### The bar

The bar is one format string. Vikix sets it in `modeline.lisp`:

```lisp
"%J  %W^>%R%K%X%Q%U%A%D%O%T%V%E%d"
```

`%J` the workspaces, `%W` the windows, `^>` right-aligns the rest: `%R` rec, `%K` awake, `%X` win (the Windows VM), `%Q` quiet, `%U` updates, `%A` backup, `%D` usb, `%O` network, `%T` Bluetooth, `%V` volume, `%E` battery, `%d` date and time. Set your own in `user.lisp` to drop or reorder fields:

```lisp
;; no Bluetooth, and the time without the date
(setf *time-modeline-string* "%H:%M"
      *screen-mode-line-format* "%J  %W^>%R%K%X%Q%U%A%D%O%V%E%d")
```

A field of your own can be a list entry `(:eval FORM)`, run each time the bar redraws (every 10 seconds). Keep the form quick, since the whole desktop waits while it runs:

```lisp
(setf *screen-mode-line-format*
      (list "%J  %W^>%R%K%X%Q%U%A%D%O%T%V%E"
            '(:eval (format nil "load ~a  " (first (uiop:split-string (uiop:read-file-string "/proc/loadavg")))))
            "%d"))
```

### Try it live first

`vikix eval` runs Lisp in the running StumpWM, so you can try a change before writing it down:

```sh
vikix eval '(vikix-bind "s-o" "exec obsidian")'
```

That lasts until the next reload or login. When it does what you want, put the same line in `user.lisp`.

## The look

| To change | Do |
|---|---|
| The whole theme | `vikix theme paper` (or `Super+m` → *Theme*). `vikix theme` lists them. |
| A theme of your own | `cp ~/vikix/themes/void.theme ~/.config/vikix/themes/mine.theme`, change the colours, `vikix theme mine`. A picture beside it, `mine.jpg`, becomes its wallpaper. |
| The wallpaper | `Super+m` → *Wallpaper*, or `vikix-wallpaper FILE`. Pictures in `~/Pictures/Wallpapers` show in the picker. *My own tool* in the picker stops Vikix touching it, for feh or nitrogen. |
| Terminal font, size, padding | `~/.config/alacritty/alacritty.toml`. Open windows change at once. |
| One program's colours, keeping the theme for the rest | Set them in that program's config, after the line that includes the theme. For dunst, a new file after the theme's: `~/.config/dunst/dunstrc.d/90-mine.conf`. |
| Text size on a high-resolution screen | `Xft.dpi` in `~/.Xresources` (the file suggests values), then log in again |
| Shadows, fading, transparency | `~/.config/picom/picom.conf`. picom rereads the file when it changes. To change `backend`, `pkill picom` first, then edit, then `picom -b`: changing it while picom runs can freeze the screen. |
| Notifications: where, how long, how big | `~/.config/dunst/dunstrc`, then `dunstctl reload` |
| The launcher and menus | `~/.config/rofi/config.rasi` |

## The machine

| To change | Do |
|---|---|
| Keyboard layout, Caps Lock | `~/.config/vikix/keyboard` (`VIKIX_KB_LAYOUT`, options such as `ctrl:nocaps`), then `Super+m` → *Apply keyboard settings*. The starter swaps Caps Lock and Left Ctrl. |
| When the screen locks, goes dark, suspends | Make `~/.config/vikix/idle` with any of `LOCK=10`, `SCREEN_OFF=11`, `SUSPEND=20` (minutes; `SUSPEND=0` never suspends; suspend is on battery only), then log in again |
| Night light hours and warmth | `~/.config/gammastep/config.ini`. `Super+Alt+l` switches it off and on. |
| Which program opens a kind of file | `~/.config/mimeapps.list`, or `xdg-mime default org.pwmt.zathura.desktop application/pdf` |
| Screens at a desk | Arrange them with `Super+m` → *Screens: arrange*, then *Screens: save this layout*. The layout comes back whenever the same screens are plugged in. |
| What backups leave out | `~/.config/vikix/backup-exclude` |

## The shell

`~/.bashrc` is yours. Vikix's one block is at the top and loads its aliases and prompt (`~/.config/vikix/vikix.bash`), so what you write below it wins:

```sh
alias gs='git status'          # your aliases
PS1='\w \$ '                   # your own prompt
export EDITOR=nvim
```

Don't edit between the `# >>> vikix … >>>` and `# <<< vikix … <<<` lines; Vikix rewrites those. `alias` lists every alias, and the [README](../README.md#shell-aliases) explains them.

## Programs and services

- **Install a program:** `xi NAME` (search with `xs WORD`). It stays installed, and `vikix update` keeps it current along with everything else.
- **Remove one Vikix installed:** `xr NAME` removes it, but the next `vikix update` installs it again, because it's in Vikix's package lists. There's no way to opt out of one yet.
- **Optional features** come with their own setup command, which adds them to `~/.config/vikix/optional`; from then on `vikix update` keeps their packages. So far there is one: the Windows VM (`vikix windows setup`, see the [README](../README.md#windows-in-a-vm)).
- **Switch on a service:** `sv-on NAME` (the services are in `/etc/sv/`), `sv-off NAME`, `svls` to list. These are system services. A program for your desktop session goes in `user.lisp` instead ([above](#start-a-program-with-the-desktop)).

## The editors

`~/.emacs.d` and `~/.config/nvim` are git clones of the author's configs, and `vikix update` pulls them. To use your own, install Vikix with `VIKIX_EMACS_REPO=` or `VIKIX_NVIM_REPO=` set to your repository, or replace the folder with your own. A folder that isn't a git clone is left alone. Edits to the clones can stop the pull; the update says so and carries on.

## Changing Vikix itself

Some things can only be changed in Vikix's own files: a default for everyone, a bug, a new stage. Change them in a checkout you commit to, not in place:

1. Fork github.com/vukini/vikix and point your checkout at the fork: `git -C ~/vikix remote set-url origin https://github.com/YOU/vikix.git`
2. Make the change in `~/vikix`, run `tests/run.sh`, and commit it.
3. `vikix update` now pulls your fork. To take in new Vikix versions, merge them into the fork.

Or, if it would help everyone, open an issue or a pull request.
