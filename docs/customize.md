# Making it yours

Each section says which file to change and how to make the change take effect. Every file here is yours, so no update will overwrite it. [Where everything is](map.md) has the full list.

## Before you change anything

```sh
vikix snapshot "before: bigger bar font"   # record your files as they are
# ... make the change ...
vikix changes                              # see exactly what changed
vikix undo                                 # changed your mind: back to the snapshot
```

In a terminal, `vikix undo` first lists the files it will put back and asks. Say no if that isn't the snapshot you meant (an AI agent takes one when it starts, so the one before may be the agent's), and pick another from `vikix history` with `vikix undo ID`. After an undo, `Super+m` → *Reload config* makes StumpWM use the old settings again. `vikix undo --help` shows the four commands together.

Or ask the AI agent: `Super+a` starts Claude Code (or the agent you chose), which knows these rules (from `~/.claude/skills/vikix`) and takes a snapshot before it starts. [Working with AI](ai.md) says how.

## The desktop: `~/.stumpwm.d/user.lisp`

Everything about StumpWM goes in this one file: keys, startup programs, the menu, the bar. It loads after all of Vikix's files, so what you set here wins. Apply a change with `Super+m` → *Reload config*. If there's a mistake, the error shows on screen, and everything else still loads.

To see how Vikix does something before changing it, read its layer in `~/vikix/config/stumpwm/vikix/`: `keys.lisp` for keys, `commands.lisp` for the menu, `modeline.lisp` for the bar.

### Keys

```lisp
(vikix-bind "s-w" "exec chromium")         ; change what a key does
(vikix-bind "s-t" "exec obsidian")         ; a new key
(undefine-key *top-map* (kbd "s-E"))       ; drop one of Vikix's keys
```

`s-` is Super, `C-` Ctrl, `M-` Alt, and a capital letter means Shift: `s-O` is Super+Shift+o. The command is a StumpWM command: `exec PROGRAM` starts a program, and `Super+m` → *All commands* lists the others.

To see a new key on the key card (`Super+/`) and in the key help (`Super+F1`), add it to the list both are built from too:

```lisp
(push '("s-t" "exec obsidian" "Obsidian") *vikix-bindings*)
(vikix-bind "s-t" "exec obsidian")
```

The card puts each key in a group by what it runs: a program started with `exec` goes under *Apps* (or *AI & voice*, *Screenshots & recording* and so on, when Vikix knows the program), and anything else under *Other*. To choose the group yourself, give it as a fourth item: `'("s-t" "exec obsidian" "Obsidian" "Notes")`. A group of your own comes after Vikix's.

After `Ctrl+t`, StumpWM's prefix, the keys that can follow appear if you wait (StumpWM's which-key-mode, which Vikix turns on). To have it off, put `(vikix-which-key nil)` in user.lisp. Don't call `(which-key-mode)` there: it switches on and off, so every reload would flip it.

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

Gaps between windows (Super+g) are 10px, 9px at the screen edge. The inner gap is on every side of each window, so two windows are twice it apart. To change them, or have them on from login:

```lisp
(setf swm-gaps:*inner-gaps-size* 3         ; 6px between windows
      swm-gaps:*outer-gaps-size* 3)        ; plus this at the screen edge
(swm-gaps:toggle-gaps-on)                  ; gaps from login on
```

### The Super+m menu

Each entry is a label and either a command or a Lisp form, and, if you like, what it needs: a program on PATH, or a file (`"~/..."`). An entry whose need isn't there is left out of the menu, which is how Vikix hides JupyterLab or Printers until you add their features (and, in `*vikix-apps-menu*`, Super+m → Apps, each video, graphics or study program until it is installed):

```lisp
(setf *vikix-menu*
      (append *vikix-menu*
              '(("Obsidian" (run-shell-command "obsidian") "obsidian")   ; shown only with obsidian installed
                ("Keys"     vikix-keys))))
```

### The bar

The mouse works on it too: a workspace's number goes there, a window's title focuses it, volume opens the mixer (the wheel turns it up and down, the middle button mutes), the network opens `nmtui`, and Bluetooth its settings. The clickable parts are `^(:on-click ...)` areas made by `vikix-ml-clickable` in `modeline.lisp`; when they overlap, as a long window title under the fields on the right, the narrowest wins.

The bar is one format string. Vikix sets it in `modeline.lisp`:

```lisp
"%J  %W^>%R%K%X%Y%Q%U%A%D%Z%O%T%V%E%d"
```

`%J` the workspaces, `%W` the windows, `^>` right-aligns the rest: `%R` rec (or mic, while dictation listens), `%K` awake, `%X` win (the Windows VM), `%Y` ai (a local model loaded), `%Q` quiet, `%U` updates, `%A` backup, `%D` usb, `%Z` Dropbox, `%O` network, `%T` Bluetooth, `%V` volume, `%E` battery, `%d` date and time. Set your own in `user.lisp` to drop or reorder fields:

```lisp
;; no Bluetooth, and the time without the date
(setf *time-modeline-string* "%H:%M"
      *screen-mode-line-format* "%J  %W^>%R%K%X%Y%Q%U%A%D%Z%O%V%E%d")
```

A field of your own can be a list entry `(:eval FORM)`, run each time the bar redraws (every 10 seconds). Keep the form quick, since the whole desktop waits while it runs:

```lisp
(setf *screen-mode-line-format*
      (list "%J  %W^>%R%K%X%Y%Q%U%A%D%Z%O%T%V%E"
            '(:eval (format nil "load ~a  " (first (uiop:split-string (uiop:read-file-string "/proc/loadavg")))))
            "%d"))
```

### Try it live first

`vikix eval` runs Lisp in the running StumpWM, so you can try a change before writing it down:

```sh
vikix eval '(vikix-bind "s-t" "exec obsidian")'
```

That lasts until the next reload or login. When it does what you want, put the same line in `user.lisp`.

## The look

| To change | Do |
|---|---|
| The whole theme | `vikix theme paper` (or `Super+m` → *Theme*). `vikix theme` lists them. |
| A theme of your own | `cp ~/vikix/themes/void.theme ~/.config/vikix/themes/mine.theme`, change the colours, `vikix theme mine`. A picture beside it, `mine.jpg`, becomes its wallpaper. The name is letters, digits, `-` and `_` only (`my-theme`, not `my theme`): a file named otherwise isn't listed or used. |
| A theme from Omarchy | `vikix theme import bjarneo/omarchy-ash-theme` (OWNER/REPO on GitHub, or an `https://` git URL). [Omarchy](https://omarchy.org)'s themes, and its community's at [themes.omarchy.org](https://themes.omarchy.org), are git repositories with a `colors.toml`. The colours become `~/.config/vikix/themes/ash.theme` (the repository's name without `omarchy-` and `-theme`; give another as the next word), the first picture in `backgrounds/` its wallpaper, and Vikix switches to it (`--no-switch` doesn't). Nothing in the repository is run, and the rest of it is left out. `--force` replaces a theme of yours with the same name; the old files are kept as `.vikix-bak`. |
| The wallpaper | `Super+m` → *Wallpaper*, or `vikix-wallpaper FILE`. Pictures in `~/Pictures/Wallpapers` and `~/wallpapers` show in the picker; `vikix add wallpapers` adds Vid's collection there too, and `vikix update` brings its new ones. *My own tool* in the picker stops Vikix touching it, for feh or nitrogen. |
| Terminal font, size, padding | `~/.config/alacritty/alacritty.toml`. Open windows change at once. |
| One program's colours, keeping the theme for the rest | Set them in that program's config, after the line that includes the theme. For dunst, a new file after the theme's: `~/.config/dunst/dunstrc.d/90-mine.conf`. |
| Text size on a high-resolution screen | `Xft.dpi` in `~/.Xresources` (the file suggests values), then log in again |
| Shadows, fading, transparency | `~/.config/picom/picom.conf`. picom rereads the file when it changes. To change `backend`, `pkill picom` first, then edit, then `picom -b`: changing it while picom runs can freeze the screen. |
| Notifications: where, how long, how big | `~/.config/dunst/dunstrc`, then `dunstctl reload` |
| The launcher and menus | `~/.config/rofi/config.rasi` |

## The machine

| To change | Do |
|---|---|
| Keyboard layout, Caps Lock | `Super+m` → *Welcome* → *Set your keyboard layout* picks one from a list and applies it. Or edit `~/.config/vikix/keyboard` (`VIKIX_KB_LAYOUT`, options such as `ctrl:nocaps`), then `Super+m` → *Apply keyboard settings*. The starter swaps Caps Lock and Left Ctrl. |
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

Don't edit between the `# >>> vikix … >>>` and `# <<< vikix … <<<` lines; Vikix rewrites those.

**API keys don't go here.** An `export ANTHROPIC_API_KEY=...` line in `~/.bashrc` is kept for ever in your files' history. Use `vikix ai key set anthropic` instead: every shell still gets the variable (see the [README](../README.md#api-keys)). `alias` lists every alias, and the [README](../README.md#shell-aliases) explains them.

## Programs and services

- **Install a program:** `vikix pkg add NAME`, or `vikix pkg add` alone to search every package in Void with a description beside each (Super+m → *Install a program*). `xi NAME` works too. It stays installed, and `vikix update` keeps it current along with everything else.
- **Add or remove a feature:** a language, an editor, LibreOffice, printing, video and graphics apps, Windows, local AI, dictation and voice, another AI agent. `vikix features` lists them and marks the ones you have; `vikix add rust` installs one, and every update keeps it; `vikix remove rust` uninstalls what only it needed, after showing you the list. Bundles add several at once: `vikix add essentials` (Emacs, C, Python, Lisp), `developer`, `creative` (video, graphics, Blender), `everything`. Your choices are `~/.config/vikix/features`. The programs of the app features (video, graphics, blender, study, passwords, phone, cli-extras) are in `Super+m` → *Apps*, each once it's installed. Windows (`vikix windows setup`, see [Windows in a window](windows.md)) and web apps (the first `vikix webapp add`) choose their feature by themselves.
- **Remove a program:** `vikix pkg drop NAME`, or `vikix pkg drop` alone to pick from what's installed (Super+m → *Remove a program*). One that Vikix's lists name goes on your skip list, `~/.config/vikix/packages-skip`, so `vikix update` doesn't bring it back; `vikix pkg list` shows it, and `vikix pkg add NAME` takes one off. For a whole language or editor, `vikix remove` is the better way: it says so. (`xr NAME` removes a package too, but an update would install it again.)
- **A launcher entry of your own:** the launcher (Super+d) lists the `.desktop` files in `~/.local/share/applications`. Put yours there, with a `Name=` and an `Exec=`; a `Keywords=` line (`Keywords=jlab;notebook;`) makes it come up for other words you might type, as `jlab` finds JupyterLab.
- **Switch on a service:** `sv-on NAME` (the services are in `/etc/sv/`), `sv-off NAME`, `svls` to list. These are system services. A program for your desktop session goes in `user.lisp` instead ([above](#start-a-program-with-the-desktop)).

## Web apps

A website you use like a program (mail, a CRM, a calendar) can have a window, a launcher entry and a key of its own:

```sh
vikix webapp add superhuman            # presets: superhuman, fastmail, gmail, outlook, outlook-live
vikix webapp add crm https://crm.example.com --key s-C-c
vikix webapp key crm none              # change its key, or drop it
```

Your list is `~/.config/vikix/webapps`, one `NAME URL [KEY]` per line; editing it by hand works too (your comments stay), then `Super+m` → *Reload config*; `vikix webapp list` points out a line it can't use. To start one at login, add `(run-shell-command "vikix-webapp launch NAME")` to `user.lisp`. See the [README](../README.md#web-apps).

## The editors

Emacs and Neovim are features: `vikix add emacs`, `vikix add neovim`. Neovim's config is split like the desktop's: Vikix's part is `~/.local/share/vikix/nvim`, and `~/.config/nvim` is yours (your plugins go in its `lua/plugins/`, and win). Emacs's is a git clone of the author's at `~/.emacs.d`, which `vikix update` pulls, and Vikix's AI setup for it is `~/.local/share/vikix/emacs`. [Neovim and Emacs](editors.md) has the rest: keys, language servers, AI in each, and bringing a config of your own.

## AI

Each of these is one of your files, so it has an undo too. [Working with AI](ai.md) says what each does.

| To change | Do |
|---|---|
| The model Super+i uses (and the editors' chats, Super+F10 and `note`) | `vikix ai use local` or `vikix ai use claude`; `vikix ai use` alone says which. The model and the languages to translate into are in `~/.config/vikix/ai` ([Local or Claude](ai.md#local-or-claude)) |
| The agent Super+a starts (and the editors, and Super+F11) | `vikix agent --default opencode`; `vikix agent --which` says which ([Another agent](ai.md#another-agent)) |
| Dictation's language | `vikix dictate models small` for many languages, `base.en` for English ([Dictation](ai.md#dictation)) |
| The voice that answers, or no voice at all | `vikix voice voices alan`; `speak=no` or `idle=` in `~/.config/vikix/voice` ([Talking with the AI](ai.md#talking-with-the-ai)) |
| The notes `note` reads | `note index FOLDER --skip A,B` once; `folder=`, `skip=`, `embed=` in `~/.config/vikix/notes` ([Asking your notes](ai.md#asking-your-notes-note)) |
| What the agent may do on the desktop without asking | `vikix mcp register` gives it the desktop as tools; `--allow-eval` and `--allow-undo` add the two risky ones, and registering again without them takes them away ([The desktop as tools](ai.md#the-desktop-as-tools-mcp)) |

## Changing Vikix itself

Some things can only be changed in Vikix's own files: a default for everyone, a bug, a new stage. Change them in a checkout you commit to, not in place:

1. Fork github.com/vukini/vikix and point your checkout at the fork: `git -C ~/vikix remote set-url origin https://github.com/YOU/vikix.git`
2. Make the change in `~/vikix`, run `tests/run.sh`, and commit it.
3. `vikix update` now pulls your fork. To take in new Vikix versions, merge them into the fork.

Or, if it would help everyone, open an issue or a pull request.
