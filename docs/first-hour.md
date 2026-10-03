# Your first hour

You've installed Vikix and logged in. This page is the first hour: what you're looking at, the keys worth learning first, adding what you need, making it look yours, and keeping it current. [Installing Void for Vikix](install-void.md) is the page before.

## What you're looking at

At the top is **the bar**: the workspaces on the left, then the windows on this one; on the right the network, the sound, the battery and the time, and before them a word when something needs you (`updates 12`, `backup 9d`). It takes clicks: a workspace's number goes there, a window's title focuses it, `vol` opens the sound mixer, the network opens its settings.

The rest of the screen is windows. There are no title bars and no overlapping: each window fills its part of the screen, and you split the screen to put two side by side. That's StumpWM, and the keys below are how you drive it.

![The desktop at the first login: the bar at the top, and the welcome](shots/vikix-first-login.png)

The first time, a terminal opens with **the welcome**. Follow it: it adds software, shows the keys, picks a theme and your keyboard layout, and ticks each step off once it's done. `Super+m` → *Welcome* brings it back.

## The keys that matter

`Super` is the key with the Windows logo. Five to start with:

| Key | What it does |
|---|---|
| `Super+Return` | a terminal |
| `Super+d` (or `Super+Space`) | the launcher: type a program's name, Enter |
| `Super+m` | the Vikix menu: everything, in a list |
| `Super+/` | every key on one card; the next key closes it |
| `Super+q` | close the window |

Then, when you have two windows:

| Key | What it does |
|---|---|
| `Super+b`, `Super+v` | split the screen side by side, or one above the other |
| `Super+h` `j` `k` `l` (or the arrows) | move between them; add `Shift` to move the window |
| `Super+r` | remove a split |
| `Super+f` | fullscreen, and back |
| `Super+Tab` | the last window again |
| `Super+o` | every window on the workspace in a grid; pick one |
| `Super+u` | undo the last layout change |
| `Super+1` … `Super+9` | workspaces; `Super+Ctrl+1` … sends the window there |

And a few for everyday things: `Super+w` the browser, `Super+e` your files, `Print` a screenshot of an area (to the clipboard, to paste with `Ctrl+v`; `Shift+Print` keeps it as a file in `~/Pictures/Screenshots` instead), `Super+c` the clipboard's history, `Super+Escape` lock, `Super+Shift+Escape` suspend, log out or power off.

**When three windows aren't enough:** a workspace can be a strip instead (Super+m, *This workspace as a strip*, or `vikix viri`). Its windows stand side by side, each half the screen wide, in a row wider than the screen; two show at a time, and `Super+h` / `Super+l` move along the row, scrolling it. The bar shows the whole row, the two on the screen in brackets (`A [B C] D`), and the window you're in has the coloured border, as in tiles. A new window opens beside the one you're in, and nothing shrinks to make room. `Super+Shift+h` / `l` move a window along the row; the same menu entry (or `vikix viri off`) makes it tiles again, split as they were before, each window back in its place (one opened on the strip joins the current split). `Super+r` makes the window's column a third of the screen, two thirds, all of it, then half again (on tiles it still removes a split). `Super+[` and `Super+]` put the window into the column on its left or right, under what's there (an editor with a terminal below it); pressed on a window that shares a column, they take it out into a column of its own. `Super+j` / `Super+k` go up and down a column, and with `Shift` move the window. The bar shows a shared column as `D/C`.

`Super+F1` lists every key with what it does, to search and run from there. Mouse focus is on: a window takes your typing when the pointer is over it.

## Add what you need

What came is **the base**: a whole desktop, but no programming languages, editors or office suite. Those are **features**, added when you want them:

```sh
vikix features              # what there is, [x] for what you have
vikix add essentials        # Emacs, and C, Python and Lisp
vikix add python neovim     # any features, by name
vikix add office printing   # LibreOffice, and printers
```

`Super+m` → *Add software* is the same, as a list to tick. A single program that isn't a feature: `vikix pkg add NAME`. `vikix remove NAME` takes a feature away again. [How it fits together](how-it-works.md#the-base-and-the-features) explains the difference.

## Make it look yours

```sh
vikix theme                 # the themes there are
vikix theme nord            # switch: the bar, terminals, menus, lock screen, wallpaper, editors
```

Or `Super+m` → *Theme*. Six come with Vikix: void (the default), paper (light), gruvbox, nord, tokyo-night and contrast (for bright rooms and tired eyes). `vikix theme import` brings one of Omarchy's. The wallpaper follows the theme until you choose your own (`Super+m` → *Wallpaper*).

Your own keys, startup programs and settings go in `~/.stumpwm.d/user.lisp`, which loads last, so it wins: [Making it yours](customize.md) shows how. Before you change a file, `vikix snapshot`; if it goes wrong, `vikix undo`.

## Keep it current

When the bar says `updates`, there's something new:

```sh
vikix update                # Vikix, Void's packages, your languages and tools
vikix update core           # only Vikix: seconds
```

`Super+m` → *Update Vikix* does the first, in a terminal.

## When you're stuck

- **The agent:** `Super+a` starts the AI agent, which knows this desktop: ask it to change a key, find a setting, or explain an error. It takes a snapshot of your files first.
- **The checks:** `vikix doctor` looks at everything Vikix put in place and says what's missing.
- **The guides:** these pages, on your machine too (`Super+m` → *Vikix guide*). [When something breaks](fixing.md) is the one for problems.
