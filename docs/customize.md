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
(vikix-bind "s-M-o" "exec obsidian")       ; a new key: Super+Alt+o
(undefine-key *top-map* (kbd "s-M-s"))     ; drop one of Vikix's keys
```

`s-` is Super, `C-` Ctrl, `M-` Alt, `S-` Shift, and a capital letter means Shift too: `s-O` is Super+Shift+o, `s-M-o` Super+Alt+o. The command is a StumpWM command: `exec PROGRAM` starts a program, and `Super+m` → *All commands* lists the others.

A key bound like that works, and nothing else knows of it. To have it on the key card (`Super+/`), in the key help (`Super+F1`) and in `Super+m` too, write it as a command, the way Vikix writes its own:

```lisp
(define-vikix-command obsidian "Obsidian: my notes"
  :run "exec obsidian" :key "s-M-o"
  :menu "Apps" :needs "obsidian")
```

The name (`obsidian`) is yours to choose; the words after it are what the key card and the menu say. `:run` is the command and `:key` its key. `:menu` puts it in `Super+m`, in that section of it (Start, Help, Vikix, AI, Work, Notifications, Desktop, Windows, System, Apps); leave it out for a key alone. `:label` gives the menu other words than the key card's, and `:needs` names a program or a file (`"~/..."`) without which the menu leaves the entry out. Leave `:key` out for a menu entry with no key; then `:do` can take a Lisp form in place of `:run`. `:agent t` lets your AI agent run it by name, without asking you each time ([Working with AI](ai.md#the-desktop-as-tools-mcp)): only for something put back as easily as it is done. A mistake in the form is said when `user.lisp` loads, with what is wrong.

Vikix's own commands are written the same way, all in one file, `registry.lisp` in Vikix's layer: its keys, its menu, and what agents may run all come from it. The older way still works, and is what a plugin or a web app does: add to the list the card and the help are built from, and bind the key.

```lisp
(push '("s-M-o" "exec obsidian" "Obsidian") *vikix-bindings*)
(vikix-bind "s-M-o" "exec obsidian")
```

The card puts each key in a group by what it runs: a program started with `exec` goes under *Apps* (or *AI & voice*, *Screenshots & recording* and so on, when Vikix knows the program), and anything else under *Other*. To choose the group yourself, give it as a fourth item: `'("s-t" "exec obsidian" "Obsidian" "Notes")`. A group of your own comes after Vikix's.

After `Ctrl+t`, StumpWM's prefix, the keys that can follow appear if you wait (StumpWM's which-key-mode, which Vikix turns on). To have it off, put `(vikix-which-key nil)` in user.lisp. Don't call `(which-key-mode)` there: it switches on and off, so every reload would flip it.

`Super+m` → *What does a key do?* tells you what any key is bound to now.

### The rule for keys

Each modifier beside Super means one thing. Vikix's keys keep to it, so do the plugins' and the web apps', and a key of yours is easiest to remember when it does too:

| Keys | What they are for | Vikix's, for example |
|---|---|---|
| Super | Everyday: the six main apps (terminal, launcher, browser, files, editor, agent), the small tools, focus, and what is done to the window you're in | `Super+Return`, `Super+w`, `Super+h`, `Super+q`, `Super+f` |
| Super+Shift | The same key, moving the window: move it, send it to a workspace, bring one here. Or the key's other way: redo, previous | `Super+Shift+h`, `Super+Shift+3`, `Super+Shift+g`, `Super+Shift+u` |
| Super+Alt | Open something else: every other app, every web app and plugin | `Super+Alt+p` projects, `Super+Alt+v` passwords, `Super+Alt+m` mail |
| Super+Ctrl | Switch something on the desktop | `Super+Ctrl+a` keep awake, `Super+Ctrl+l` night light, `Super+Ctrl+d` do not disturb, `Super+Ctrl+g` gaps |

So a new app goes on Super+Alt and a letter, a switch of your own on Super+Ctrl. Keys without Super keep their own ways: Print (Shift keeps a file, Ctrl is the window, Super the screen) and the laptop's own keys.

Sending a window to a workspace is Super+Shift and the digit on any keyboard: Vikix asks the keyboard what Shift+digit types (`!` on a US one) and binds that, again after `Super+m` → *Apply keyboard settings*. On a keyboard where the digits themselves need Shift (French), it is Super+Ctrl and the digit.

`vikix doctor` names a key that breaks the rule: a plugin's or a web app's not on Super+Alt, a program of yours on plain Super, a switch somewhere else. The key still works; the doctor only says so. What Vikix counts as everyday, a switch or a move is three short lists at the top of `~/vikix/config/stumpwm/vikix/keys.lisp`; add a command of your own to one in `user.lisp`, `(push "my-toggle" *vikix-key-switches*)`, and the doctor knows it.

### Which keys do you use?

Before you move a key or give one up, look at what you press. The desktop counts each key that runs a command, each entry you pick in a menu or in the palette, and each command you type:

```
$ vikix used
Counting since 5 Oct 2026 (12 days).

Keys
     412  Super+Return                 Terminal
     388  Super+Space                  Everything in one box: windows, commands, projects ...
      97  Super+f                      Fullscreen on/off

Menu entries
      14  Reload config

61 of 107 keys never pressed: vikix used never
```

`vikix used never` lists the keys you have never pressed since counting began: the ones free to take for something of your own. `vikix used all` shows every count and when each was last used; `vikix used forget` starts again. Super+m has it as *What you use*.

Only names and numbers are kept: the key, the command it is bound to, a menu entry's words. Never a window's title, and nothing you type into a program. The counts are in `~/.local/state/vikix/used`, a text file you can read or delete, and nothing sends it anywhere.

### Start a program with the desktop

```lisp
(at-login (run "syncthing --no-browser"))
```

`at-login` runs once each time you log in. `user.lisp` runs again on every reload, and the rule doesn't: there's no need for a `pgrep -x … ||` in front to keep a second copy from starting. A rule you add while logged in runs at the reload that brings it, once. It goes in `rules.lisp` or in `user.lisp` ([Rules for the desktop](rules.md)).

### Rules: what the desktop does by itself

A rule is one line that says where a window goes as it opens, or what happens at a time of day, on a low battery, or when you log in:

```lisp
(when-window (:class "Firefox") (workspace 2))                 ; Firefox opens on workspace 2
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(at "09:00" :weekdays (open-project "vikix"))                  ; each working day at nine
(when-battery-below 20 (notify "Battery at 20%" "Where's the charger?"))
```

They live in a file of their own beside `user.lisp`, `~/.stumpwm.d/rules.lisp`, which comes with every example switched off. `Super+Shift+t` writes one for you, for the window in front, and `vikix rules` lists them, says why a window went where it did, and tries them on the windows open now.

[Rules for the desktop](rules.md) is their page: everything a rule can match and do, how to see what your rules did, and what happens when one goes wrong.

### Saved layouts

A workspace's layout, the splits and which window sits in each (or a strip's columns, their widths and what's stacked), saved by name and put back later:

```sh
vikix layout save writing     # this workspace, as it is now
vikix layout writing          # back as it was
vikix layout list             # the ones saved
vikix layout rm writing
```

Or Super+m, *Layout: save this workspace's* and *Layout: put this workspace back*. A rule can put one back too: `(when-window (:class "Emacs" :title (:has "novel")) (layout "writing"))`.

Each is a file of plain Lisp in `~/.config/vikix/layouts/`, to read and change by hand: windows are described by their class and title, not remembered as the windows they were, and a split's place and size are parts of the screen, so a layout still fits after the windows have been closed and opened again, or on another screen. Putting one back matches the windows on the workspace to the saved ones (the same program first, then the closest title); a window it doesn't mention stays, and a saved one that isn't open is started again and placed as it comes (`vikix layout NAME --no-start` only names it). Each saved window says how: its `:command` and `:directory`, read from the program when the layout was saved; a terminal comes back in its shell's folder (with what ran in it, when that wasn't the shell), an Emacs window as `emacsclient -c` on the file it showed, Esploro on its folder. Since a layout can start programs, read one you were given before you put it back. A strip's layout makes the workspace a strip, a tiled one tiles. Floating windows aren't saved.

### Your windows back after a restart

The desktop saves every workspace by itself, every five minutes and when it ends: which windows, where they stand, and how each was started. After a restart, the login asks whether to bring them back; Enter does it. Each workspace in turn is put back as it was, its programs started again in their folders, and you end on the workspace you were on.

```sh
vikix resume           # what is saved, and what a login does
vikix resume now       # bring them back now (Super+m, Bring my windows back)
vikix resume always    # at login, bring them back without asking
vikix resume never     # at login, leave it
vikix resume ask       # at login, ask first: how it starts out
```

What comes back is what can be started again: a terminal in the folder it was in, with the program that ran in it; a program by its command line; a web app; an Emacs frame on its file. What a program had open inside it is the program's own to bring back: Firefox reopens its tabs, an editor its files. An AI agent started with Super+a comes back as a new session in its folder (in Claude Code, `claude --continue` takes up the last conversation there). Floating windows and dialogs aren't saved.

The saved workspaces are layouts like those above, kept apart in `~/.local/state/vikix/resume/`; the choice is one word in `~/.config/vikix/resume`.

### The drawer

A few programs you want often and for a moment: a calculator, your files, a page of notes. `Super+Ctrl+b` slides them in from the right edge of the screen, one above the other, over your windows, on whatever workspace you're on; the key again slides them away. They keep running while they're away, so the calculator keeps its sums and the files their folder. The windows underneath are not moved or made smaller.

As it comes, the drawer holds a terminal and PCManFM. Yours are a list in `user.lisp`, top to bottom, each a name and the command that starts it:

```lisp
(setf *vikix-drawer-apps*
      '(("Calculator" "speedcrunch")
        ("Files" "esploro --new ~" :class "Emacs" :title "Esploro")
        ("Notes" "emacsclient -c -n -a '' -F '((name . \"Notes\"))' ~/notes.org"
         :class "Emacs" :title "Notes")))
(setf *vikix-drawer-side* :left)     ; the edge: :right as it comes
(setf *vikix-drawer-width* "35%")    ; of the screen, or pixels: 500
```

A program is started the first time the drawer comes out, and again when you closed it. Its window goes into the drawer whatever your rules say of that program: a rule that sends SpeedCrunch to workspace 1 still holds for a SpeedCrunch you start yourself, not for the drawer's. The drawer knows a window by the program that made it. Where another program makes the window, say how to know it, the way a rule does (`:class`, `:instance`, `:title`, `:role`): an Emacs frame is made by Emacs's server, whatever started it, and a second PCManFM window by the first PCManFM. `xprop WM_CLASS WM_NAME` and a click on a window give its class (the second word) and its title.

On another workspace the key brings the drawer there. A window of the drawer tiled with `Super+t` is an ordinary window from then on, and its program is started again for the drawer the next time. On a strip the drawer stands over the columns. It slides when a compositor runs, as a strip does (`*viri-animate*`).

### The terminal, focus, and fonts

```lisp
(setf *vikix-terminal* "kitty")            ; what Super+Return opens
(setf *mouse-focus-policy* :click)         ; focus on click, not when the pointer moves over a window
(setf *vikix-font-size* 13)                ; the bar, menus and messages
(vikix-set-font)
```

Gaps between windows (Super+Ctrl+g) are 10px, 9px at the screen edge. The inner gap is on every side of each window, so two windows are twice it apart. To change them, or have them on from login:

```lisp
(setf swm-gaps:*inner-gaps-size* 3         ; 6px between windows
      swm-gaps:*outer-gaps-size* 3)        ; plus this at the screen edge
(swm-gaps:toggle-gaps-on)                  ; gaps from login on
```

### The Super+m menu

The menu opens on its sections: Start, Help, Vikix, AI, Work, Notifications, Desktop, Windows, System, Apps, and Power last. Each row says what the section holds. Enter (or Right) opens one, and Escape (or Left) comes back; a second Escape closes the menu. Typing at the top looks through every entry of every section at once, so `printers`, `theme` or `F10` is one step away (plain words, in any order and any case; a key's name counts, so `ctrl+d` finds what Super+Ctrl+d does). An entry that has a key shows it at the right, a web app's and a plugin's too.

A command written with `define-vikix-command` and `:menu` is in its section already (Keys, above). The menu itself is a list you can change as a whole. Each entry is a label and either a command or a Lisp form; then, if you like, what it needs: a program on PATH, or a file (`"~/..."`); and then its section. An entry whose need isn't there is left out of the menu, which is how Vikix hides JupyterLab or Printers until you add their features (and, in `*vikix-apps-menu*`, which the section Apps shows, each video, graphics or study program until it is installed):

```lisp
(setf *vikix-menu*
      (append *vikix-menu*
              '(("Obsidian" (run-shell-command "obsidian") "obsidian" "Apps")   ; in Apps, and only with obsidian installed
                ("Keys"     vikix-keys nil "Help")                              ; needs nothing; in Help
                ("Tides"    (run-shell-command "tides")))))                     ; no section: in one called Yours
```

A section can have a name of your own (`"Sailing"`): it comes after Vikix's, before Power. A section with one entry is not a row to open: the entry itself is at the top. Inside a section the entries keep the list's order, except that lines about the same thing (`Layout: save ...`, `Layout: put back ...`) stay together.

### The bar

`Super+Ctrl+h` hides the bar on the screen you're on, and the windows take its room; the key again brings it back (`Super+m` → *The bar on/off (hide it for the whole screen)* is the same). It isn't remembered: the bar is there again after *Reload config* and at the next login.

The mouse works on it too: a workspace's number goes there, a window's title focuses it, volume opens the mixer (the wheel turns it up and down, the middle button mutes), the network opens `nmtui`, and Bluetooth its settings. A click on any other field (the battery, the clock, `updates`) says what it is: the card `Super+Alt+?` shows for whatever the pointer is on (`vikix what`). A field Vikix writes is made an area with a name by `vikix-ml-what` in `modeline.lisp`, which is how the key knows what the pointer is on. The clickable parts are `^(:on-click ...)` areas made by `vikix-ml-clickable` in `modeline.lisp`; when they overlap, as a long window title under the fields on the right, the narrowest wins.

The bar is one format string. Vikix sets it in `modeline.lisp`:

```lisp
"%J  %W^>%R%K%X%Y%G%Q%U%A%D%Z%O%T%V%E%d"
```

`%J` the workspaces, `%W` the windows, `^>` right-aligns the rest: `%R` rec (or mic, while dictation listens), `%K` awake, `%X` win (the Windows VM), `%Y` ai (a local model loaded), `%G` mem (memory low, and programs left over), `%Q` quiet, `%U` updates, `%A` backup, `%D` usb, `%Z` Dropbox, `%O` network, `%T` Bluetooth, `%V` volume, `%E` battery, `%d` date and time. Set your own in `user.lisp` to drop or reorder fields:

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
| The wallpaper | It cycles: a new picture every 30 minutes from Vid's collection (the feature `wallpapers`, which a fresh install has), `~/Pictures/Wallpapers` and `~/wallpapers`. `vikix-wallpaper cycle 60` for every hour, `vikix-wallpaper next` for another now. To keep one: `Super+m` → *Wallpaper*, or `vikix-wallpaper FILE`; *Theme* there follows the theme, *Cycle* cycles again. `vikix update` brings the collection's new pictures. *My own tool* in the picker stops Vikix touching it, for feh or nitrogen. |
| Terminal font, size, padding | `~/.config/alacritty/alacritty.toml`. Open windows change at once. |
| GTK and Qt programs (Firefox, PCManFM, LibreOffice) | They follow the theme by themselves: dark with a dark one, light with a light one, at once. GTK 4 programs take its colours too. To keep one look whatever the theme: your rules in `~/.config/gtk-4.0/gtk.css`, below the line that imports the theme; for Qt, `qt6ct` |
| One program's colours, keeping the theme for the rest | Set them in that program's config, after the line that includes the theme. For dunst, a new file after the theme's: `~/.config/dunst/dunstrc.d/90-mine.conf`. |
| Text size on a high-resolution screen | `Xft.dpi` in `~/.Xresources` (the file suggests values), then log in again |
| A program whose boxes should float in front, like dialogs | `(push "Class" *vikix-dialog-classes*)` in `user.lisp`, the class being the second word `xprop WM_CLASS` prints when you click the window. Dialogs, password boxes (zenity, polkit, ssh-askpass, pinentry) already do |
| Shadows, fading, transparency | `~/.config/picom/picom.conf`. picom rereads the file when it changes. To change `backend`, `pkill picom` first, then edit, then `picom -b`: changing it while picom runs can freeze the screen. |
| Notifications: where, how long, how big | `~/.config/dunst/dunstrc`, then `dunstctl reload` |
| The launcher and menus | `~/.config/rofi/config.rasi` |

## The machine

| To change | Do |
|---|---|
| Keyboard layout, Caps Lock | `Super+m` → *Welcome* → *Set your keyboard layout* picks one from a list and applies it. Or edit `~/.config/vikix/keyboard` (`VIKIX_KB_LAYOUT`, options such as `ctrl:nocaps`), then `Super+m` → *Apply keyboard settings*. The starter swaps Caps Lock and Left Ctrl. |
| When the screen locks, goes dark, suspends | Make `~/.config/vikix/idle` with any of `LOCK=10`, `SCREEN_OFF=11`, `SUSPEND=20` (minutes; `SUSPEND=0` never suspends; suspend is on battery only), then log in again |
| Night light hours and warmth | `~/.config/gammastep/config.ini`. `Super+Ctrl+l` switches it off and on. |
| Which program opens a kind of file | `~/.config/mimeapps.list`, or `xdg-mime default org.pwmt.zathura.desktop application/pdf` |
| Screens at a desk | A screen you plug in lights up by itself, to the right of the laptop's, and comes back the same way next time. `Super+Ctrl+p` (or the laptop's display key) for mirror, the other screen only, the laptop's only, or arranging them by hand; what you choose is remembered for those screens. |
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
vikix webapp add crm https://crm.example.com --key s-M-k   # Super+Alt+k: web apps' keys are on Super+Alt
vikix webapp key crm none              # change its key, or drop it
```

Your list is `~/.config/vikix/webapps`, one `NAME URL [KEY]` per line; editing it by hand works too (your comments stay), then `Super+m` → *Reload config*; `vikix webapp list` points out a line it can't use. To start one at login, add `(run-shell-command "vikix-webapp launch NAME")` to `user.lisp`. See the [README](../README.md#web-apps).

## The editors

Emacs and Neovim are features: `vikix add emacs`, `vikix add neovim`. Neovim's config is split like the desktop's: Vikix's part is `~/.local/share/vikix/nvim`, and `~/.config/nvim` is yours (your plugins go in its `lua/plugins/`, and win). Emacs's is a git clone of the author's at `~/.emacs.d`, which `vikix update` pulls, and Vikix's AI setup for it is `~/.local/share/vikix/emacs`. [Neovim and Emacs](editors.md) has the rest: keys, language servers, AI in each, and bringing a config of your own.

## Projects

`vikix project` lists the folders under `~/src` that have a `log.md`, and adds to their logs ([the README](../README.md#projects-vikix-project) has the commands and the log's layout). Where it looks is `~/.config/vikix/projects`, yours; it starts as comments only, so the defaults stand until you uncomment a line:

```sh
root=~/src            # a folder your projects are in; one line each, as many as you like
root=~/work
depth=2               # how far down: 2 makes ~/src/series/book a project of the collection "series"
logs=~/src/project-logs   # a public repo ~/src/NAME with no log.md of its own uses logs/NAME/log.md
```

The change takes effect at once: each `vikix project` reads it again. A project whose build isn't `build.sh`, `make`, `src/build.sh` or `npm run build` says so in its log's Status, with a `- Build: COMMAND` line, and the same for its checks with `- Check: COMMAND`. `vikix project new NAME` adds a project (a folder in the first `root=` with its log); `vikix today` is the day across all of them. `Super+Alt+p` (or `Super+m` → *Projects*) picks one with rofi and opens a terminal in its folder and its log in Emacs (in `$EDITOR`, Neovim by default, without Emacs); the terminal is `$VIKIX_TERMINAL`, `alacritty` unless you set it.


`vikix project open NAME` (or Super+Alt+p) puts a project on a workspace of its own, the first empty one, with a terminal in its folder and its log in the editor. Arrange them as you like: when you leave that workspace its layout is saved (as a layout called `project-NAME`, see *Saved layouts*), and the next time you open the project it comes back that way. While the project's workspace is still open, opening it again just goes there. `vikix project save` saves it at once. A window the saved layout names that isn't open, a browser say, is started again and put in its place.

`vikix day` keeps a diary from the same projects: how long each had the screen, its entries and commits, a file a day in `~/journal` ([the README](../README.md#projects-vikix-project) says what it reads). Its folder is `folder=~/Notes/journal` in `~/.config/vikix/day`, a file you make; and `(setf *vikix-day-on* nil)` in `user.lisp` stops the desktop noting what is on the screen.

**Where was I?** When you come back to the laptop after ten minutes or more away, a notification with that title says where you were: how long you were gone, the project you were on and its next step, the files Emacs hasn't saved, your last command, and your last note if you have the [inbox plugin](plugins.md#inbox-notes-from-anywhere). `Super+m` → *Where was I? (the project, its next step, what isn't saved)* shows it again, and `vikix back` in a terminal says more: the project's last commit and your last few commands. It only reads what is kept anyway, the diary's record of the screen among it, so there is no card while `*vikix-day-on*` is `nil`. To wait longer, or never show it, in `user.lisp`:

```lisp
(setf *vikix-back-after* 1800)   ; seconds away before the card: half an hour (600 as it comes)
(setf *vikix-back-after* nil)    ; never; vikix back still answers when you ask
```

## AI

Each of these is one of your files, so it has an undo too. [Working with AI](ai.md) says what each does.

| To change | Do |
|---|---|
| The model Super+i uses (and the editors' chats, Super+F10 and `note`) | `vikix ai use local`, `vikix ai use claude` or `vikix ai use codex` (Super+i and Super+F10 only); `vikix ai use` alone says which. The model and the languages to translate into are in `~/.config/vikix/ai` ([Local or Claude](ai.md#local-or-claude)) |
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
