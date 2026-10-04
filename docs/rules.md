# Rules for the desktop

A rule is one line that says what the desktop does by itself: Firefox opens on workspace 2, the sound mixer floats, a program starts when you log in, a notification comes at one o'clock. You write it once, and it holds from then on.

```lisp
(when-window (:class "Firefox") (workspace 2))
(when-window (:class (:has "pavucontrol")) (float :width "50%" :height "60%"))
(at-login (run "syncthing --no-browser"))
(at "13:00" :weekdays (notify "One o'clock" "Lunch."))
```

Rules are safe to try. A mistake in one is found when the file loads and costs only that rule; a rule that fails later never stops the desktop; and `vikix undo` puts your file back as it was.

## Where your rules live

In `~/.stumpwm.d/rules.lisp`. It's yours: Vikix makes it once, with every example switched off (a `;` in front), and never overwrites it. Take the `;` away from an example, change it to suit, and reload with `Super+m` → *Reload config*.

A rule works in `~/.stumpwm.d/user.lisp` too, and that is the place for one that calls a function you wrote there. `rules.lisp` loads just before `user.lisp`.

## The quickest rule: remember this window

You don't have to write a rule to get one. Put a window where you want it: on its workspace, and if it floats, at the size and place you like. Then press `Super+Shift+t`.

The rule that would put a window like it there is shown first. Choose *Write it* and it is added to `rules.lisp` under a dated comment, named `"remembered: ..."`, after a snapshot of your files. The menu also offers the workspace alone (for a floating window, without its size and place), and another way to know the window: its instance or its title instead of its class.

Remembering the same window again replaces its rule. `vikix rules forget 3` takes a rule out of `rules.lisp` again, by its number or its name, and `vikix undo` puts the file back. Only `rules.lisp` is ever written this way, never `user.lisp`.

## From an idea to a rule

Four ideas, each taken from the wish to a rule that works. They all go the same way: say what you want in a sentence, find out what the desktop calls the window, write the line, and check it before you trust it.

### Mail on a workspace of its own

**The idea.** "My mail opens on workspace 7, and I go there with it."

**What is the window called?** A rule knows a window by its class, the name its program gives it. Open your mail, then ask in a terminal about the window, by a word of its title:

```
$ vikix rules why fastmail
vikix-fastmail "Fastmail" (workspace 1, window 0)
  No rule has run for it.
  No rule matches it either: it is where StumpWM, or you, put it.
```

The first word is the class, `vikix-fastmail`; then come its title and where it is now. No rule is about it yet, which is what we expected. (`Super+m` → *Rules* with the mail window in front shows the class too, in its first entry.)

**The rule.** The sentence turns into one line, in two parts: what the window must be, then what to do with it.

```lisp
(when-window (:class "vikix-fastmail") (workspace 7 :follow t))
```

`(:class "vikix-fastmail")` is the window: exactly that class, nothing longer. `(workspace 7 :follow t)` sends it to workspace 7, and `:follow t` takes you along; without it you'd stay where you are. Put the line in `~/.stumpwm.d/rules.lisp` and reload (`Super+m` → *Reload config*).

**Check it.** `vikix rules` lists it. Vikix's own two rules come first, so yours is number 3:

```
 3  on     0×  never         (when-window (:class "vikix-fastmail") (workspace 7 :follow t))   rules.lisp:3
```

It is on, hasn't run yet, and is written on line 3 of your file. The mail window is still on workspace 1: a reload never moves the windows you have. Ask what the rule would do with them:

```
$ vikix rules test 3
vikix-fastmail "Fastmail" (workspace 1, window 0)
    3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))
2 windows open; 1 of them matches that rule. Nothing was done: vikix rules apply 3 does it.
```

It found the right window and no other. Now do it:

```
$ vikix rules apply 3
vikix-fastmail "Fastmail" (workspace 1, window 0)
    ran     3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))
1 run.
```

You're on workspace 7 with your mail. From now on it opens there by itself, and `vikix rules why fastmail` says what happened:

```
vikix-fastmail "Fastmail" (workspace 7, window 0)
  Rules that ran for it:
    15:36  on apply  3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))   rules.lisp:3
```

### A calculator in the corner

**The idea.** "The calculator floats in the top right corner, a quarter of the screen wide, instead of taking half my screen as a tile."

**The rule, by hand.**

```lisp
(when-window (:class "Gnome-calculator")
  (float :width "25%" :height "40%" :corner :top-right))
```

`float` takes the window out of the tiles. `"25%"` and `"40%"` are shares of the monitor below the bar, so the rule fits any screen; a plain number, `400`, is pixels. `:corner :top-right` puts it there, a few pixels in from the edges. Leave the corner out and it floats in the middle.

**Or let the desktop write it.** Float the calculator with `Super+t`, drag it where you want it (Super and the left button move it, Super and the right button resize it), and press `Super+Shift+t`. The rule it offers is the window as it stands:

```lisp
(when-window (:class "Gnome-calculator") :name "remembered: Gnome-calculator" (workspace 1) (float :width "25%" :height "40%" :x "74%" :y "1%"))
```

It wrote the place as `:x` and `:y`, shares of the screen from its left and top, since it can't know you meant "the corner". It also wrote the workspace the window is on. If the calculator should open wherever you are, take `(workspace 1)` out of the line afterwards; the file is yours to edit.

**Check it.** `vikix rules apply 4` runs it on the calculator that is open, as in the first example. Close the calculator and open it again to see the rule work on a new window.

### A reminder on working days

**The idea.** "At eleven and at three, Monday to Friday, tell me to stand up."

**The rule.** There is no window here, so no matcher: the rule starts with when.

```lisp
(at ("11:00" "15:00") :weekdays (notify "Stand up" "Two minutes away from the screen."))
```

`at` takes a time on the 24-hour clock, or a list of them. `:weekdays` keeps it to Monday to Friday. `notify` shows a notification: its title, then its text.

**Check it.** `vikix rules` lists it as on, `0×`, `never`: its time has to come. To see it work without waiting until eleven, put a time two minutes from now in its place (and take `:weekdays` out if today is a weekend), reload, and wait: the notification comes within half a minute of the time, and `vikix rules` then shows `1×` and when. Put the real times back afterwards.

Two things to know about times. A rule written after its time has passed waits for the next day; it doesn't run at once. And if the laptop was asleep at eleven, the reminder comes when it wakes, as long as that is within the hour.

### A rule that doesn't work, and finding out why

**The idea.** "Firefox on workspace 4." But the line has a slip in it:

```lisp
(when-window (:class "Firefox") (workspace 42))
```

**What happens.** Nothing breaks. Firefox opens where you are, a message says a rule failed, and the desktop carries on. `vikix rules` shows the failure under the rule:

```
 6  on     0×  never         (when-window (:class "Firefox") (workspace 42))   rules.lisp:7
        failed 1 time, last: There is no workspace 42.
```

And the window itself remembers:

```
$ vikix rules why Firefox
Firefox "Mozilla Firefox" (workspace 1, window 0)
  Rules that ran for it:
    15:36  on open  6  (when-window (:class "Firefox") (workspace 42))   rules.lisp:7
        FAILED: There is no workspace 42.
```

Change 42 to 4, reload, and `vikix rules apply 6` sends the open Firefox there. Had you left it, the third failure would have switched the rule off until the next reload.

**A slip in a word, not a number,** is caught sooner, when the file loads. `(flaot)` for `(float)`:

```
Vikix: error in rules.lisp, line 8 (skipped):
flaot isn't a verb, nor a function defined before this rule. The verbs: command, dialog, float, focus, fullscreen, join, layout, notify, open-project, run, say, sticky, theme, tile, title, width, workspace.
```

Only that rule is skipped. The others in the file load as if it weren't there.

## Rules for windows

```lisp
(when-window (:class "Firefox") (workspace 2))                 ; Firefox opens on workspace 2
(when-window (:class "Slack") (workspace 4 :follow t))         ; and you go along
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(when-window (:class "mpv" :title (:has "picture in picture"))
  (float :width "30%" :height "30%" :corner :bottom-right) (sticky))
(when-window (:class "Gcolor3") (dialog))                      ; float, centred, kept in front
```

First comes what the window must be, then what to do with it.

### What a rule matches

| To match | Write |
|---|---|
| The window's class, or its instance (`xprop WM_CLASS` and a click on the window shows both: the instance first, the class second) | `:class "Firefox"`, `:instance "Navigator"` |
| Its title, or its role | `:title "Calculator"`, `:role "pop-up"` |
| Its type | `:type :dialog` |
| The workspace it opens on | `:workspace 3` |
| None of something | `:not (:title "Esploro")` |
| Anything else | `:where #'my-test`, a function of the window |

A plain string matches exactly that and nothing longer. `(:has "fox")` matches a text that contains it, in capitals or not; `(:like "^Mozilla .*")` is a pattern; a list, `("Chromium" "Brave")`, is any of them. An empty matcher, `()`, is every window.

### What a rule does

| Verb | What it does |
|---|---|
| `(workspace 2)` | Sends the window to a workspace, by number or name: it opens there, without showing here first. `:follow t` takes you along |
| `(float ...)` | Floats it. `:width` and `:height` are pixels (`400`) or a share of the monitor below the bar (`"65%"`), 60% when left out. It goes in the middle, or to a `:corner` (`:top-left`, `:top-right`, `:bottom-left`, `:bottom-right`, `:top`, `:bottom`, `:left`, `:right`), or to `:x` and `:y`. `(float :own t)` only floats it, at the size and place the window asks for itself. It has the focus as it opens, as a tiled window does; opened for a workspace that isn't in view, it is shown there, with the focus, when you go to it |
| `(tile)` | Puts a floating window back in the tiles |
| `(fullscreen)` | Fills the screen with it |
| `(sticky)` | Keeps it on every workspace (it floats) |
| `(dialog)` | Floats it in the middle and keeps it in front of the tiles, as password boxes are |
| `(title "name")` | Names it, in its title bar and the bar |
| `(focus)` | Goes to it |
| `(run "command")`, `(command "vikix-grid")` | Runs a shell command, or a StumpWM command |
| `(notify "text")`, `(say "text")` | A notification, or a message in the middle of the screen |
| `(open-project "name")`, `(theme "paper")` | Opens one of your projects; switches the theme |
| `(layout "writing")` | Puts the workspace back as a layout you saved ([Making it yours](customize.md#saved-layouts)) |
| `(width 2/3)`, `(join :left)` | On a strip (`vikix viri`): the window's column is two thirds of the screen wide (`1/3`, `1/2`, `1`, `"40%"`); the window goes under the column on its left (or `:right`). Off a strip they do nothing |

Anything else in a rule is Lisp of your own, where `(window)` is the window. `vikix rules verbs` prints this list from the running desktop, so it is never behind.

### Options

Between the matcher and the verbs a rule can have options:

| Option | What it changes |
|---|---|
| `:once t` | Only the first window that matches: Firefox to workspace 2 when you log in, later windows where you are |
| `:on :focus`, `:on :close` | When the window gets the focus, or goes, instead of when it opens |
| `:name "..."` | What the rule is known by, in the list and to `vikix rules off` |

## Rules for the time, the battery and workspaces

The same file, the same verbs (those that need no window: `run`, `command`, `notify`, `say`, `open-project`, `theme`), and any Lisp of your own:

```lisp
(at "09:00" :weekdays (open-project "vikix"))            ; each working day at nine
(at ("12:30" "18:00") (notify "Stand up"))               ; more than one time
(each 30 :minutes (run "vikix-wallpaper next"))
(when-battery-below 20 (notify "Battery at 20%" "Where's the charger?"))
(when-charging (say "On the charger"))
(when-on-battery (run "brightnessctl set 40%"))
(at-login (run "syncthing --no-browser"))
(when-workspace 3 (command "vikix-grid"))                ; on arriving at workspace 3
```

| Rule | When it runs |
|---|---|
| `(at "09:00" ...)` | At that time, on the 24-hour clock, once a day. `:weekdays`, `:weekends` or `:on (:mon :thu)` keep it to those days. If the laptop was asleep at the time, it runs on waking when that's less than an hour later; `:late t` runs it however late that day, `:late nil` only on time. A reload or logging in again doesn't run it a second time, and a rule you write after its time waits for the next day |
| `(each 30 :minutes ...)` | Every so many `:minutes` or `:hours`, counted from when it last ran, so not at once when you write it. After a long sleep it runs once, not once for each time missed |
| `(when-battery-below 20 ...)` | Once, as the charge goes under 20% off the charger. It's ready again when the charge is back above that, or the charger has been in |
| `(when-charging ...)`, `(when-on-battery ...)` | When the charger goes in, or comes out |
| `(at-login ...)` | Once each login, not at a reload. A rule you add while logged in runs at the reload that brings it, once |
| `(when-workspace 3 ...)` | Each time you go to that workspace: a number, a name, or a list of them |

They're checked every 30 seconds, so a time is met within half a minute. `at-login` is how a program starts with the desktop: `user.lisp` runs again on every reload and the rule doesn't, so there's no need for a `pgrep -x … ||` in front to keep a second copy from starting.

## Seeing what your rules do

`vikix rules`, in a terminal, lists every rule: its number, whether it's on, how often it ran since the last reload and when last, the rule, and where it's written. `Super+m` → *Rules* is the same list in a menu.

| Command | What it does |
|---|---|
| `vikix rules why` | Why the window in front is where it is: the rules that ran for it, and those that match it but haven't run, each with the reason. `vikix rules why Firefox` for the windows of a class |
| `vikix rules test` | What the rules would do with the windows open now, doing nothing. `vikix rules test 3` for one rule |
| `vikix rules apply` | Do it. A reload never moves the windows you already have; this does. `vikix rules apply 3` for one rule |
| `vikix rules off 3` | Switch a rule off until the next reload, by its number, its `:name`, or words only it has. `vikix rules on 3` brings it back |
| `vikix rules forget 3` | Take a rule out of `rules.lisp` for good, after a snapshot |
| `vikix rules verbs` | Everything a rule can be, match and do, each with its line |

A good habit after writing a rule: reload, then `vikix rules test` to see which open windows it would take, before you trust it with new ones. [The commands](commands.md#vikix-rules) has the whole of `vikix rules`.

## When a rule goes wrong

- **A misspelt verb or matcher** is found when the file loads, with its line, like any mistake in `user.lisp`. Only that rule is lost; the rest load.
- **A rule that fails as it runs** (a workspace that isn't there, a verb that can't do its work) never stops the desktop. A message says so, the error is kept in `~/.local/state/vikix/errors/`, and `vikix rules` shows it under the rule.
- **After three failures** the rule is switched off until the next reload, so a broken rule doesn't fail for every window that opens. `vikix rules on 3` gives it three more tries, and `vikix doctor` names a rule that is off this way.
- **A window didn't go where you expected:** `vikix rules why` on it says which rules ran and which only match. A rule written after the window opened hasn't run for it; `vikix rules apply` runs it now.

[When something breaks](fixing.md) has the rest of what to do when the desktop misbehaves.

## Whose rules run, and in what order

Rules run in the order they're written: Vikix's own, then the plugins', then `rules.lisp`, then `user.lisp`. When two send a window to different workspaces, the last one wins.

Vikix says what it wants of windows in the same way, so `vikix rules` lists its rules first: Lazarus's dialogs float at their own size while its main window tiles, and `vikix learn`'s lesson and shell each go into their half. A plugin's come next (inbox's note box floats; agent-waiting's note is cleared when you look at its window), and go when the plugin is removed. Any of them can be switched off like your own, with `vikix rules off`.

A reload gives exactly what the files say: a rule you deleted is gone, one you changed is replaced, and none is there twice.

## A verb of your own

When several rules need the same few lines of Lisp, give them a name:

```lisp
(define-rule-verb quarter ()
  "Float the window in the top right quarter of the screen."
  (vikix-verb-float :width "50%" :height "50%" :corner :top-right))

(when-window (:class "Gnome-calculator") (quarter))
```

The string is its line in `vikix rules verbs`. Inside, `(rule-window)` is the window. Put it in `user.lisp`, with the rules that use it after it.

## For the curious: how rules work

The whole of it is one file, `~/vikix/config/stumpwm/vikix/rules.lisp`.

- **A rule is data.** `when-window`, `at` and the others are macros that add an entry to one table, `*vikix-rules*` (`vikix-add-rule`), with the rule's own text kept beside its compiled test and body. That is how the desktop can list its rules and say where each was written.
- **Three hooks, not one a rule.** `vikix-rules-new-window`, `vikix-rules-focus-window` and `vikix-rules-destroy-window` sit on StumpWM's window hooks and go through the table. Nothing else in Vikix, and no plugin, adds a window hook of its own where a rule does the work.
- **A window is on its workspace before it shows.** StumpWM picks a new window's workspace before it draws it (`get-window-placement`); Vikix wraps that function (`vikix-rules-get-window-placement`) and asks the rules with a `workspace` verb first, so the window never flashes where you are.
- **Verbs are looked up in a table**, `*vikix-rule-verbs*`, not called as functions of those names: `float` is Common Lisp's own function, and `fullscreen` and `title` are StumpWM's commands. That is also why a misspelt verb is caught when the file loads.
- **Every run is wrapped** (`vikix-run-rule`): an error is written down and counted, and never reaches StumpWM's handling of the window, where it would mean a menu or a restart.
- **One ticker** (`vikix-rules-tick`, every 30 seconds) runs the rules for the clock, the battery and login. What an `at` or `each` rule last did is kept in `~/.local/state/vikix/rules/ran`, so a reload doesn't repeat it. What ran at this login is noted on the X server's root window, which lives exactly as long as a login does.
- **Each window keeps a few notes** of the rules that ran for it. `vikix rules why` reads them.

An AI agent sees the same list: the desktop's MCP server has a read-only `rules` tool, with why for a window ([Working with AI](ai.md)).
