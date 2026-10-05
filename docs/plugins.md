# Plugins, one by one

Plugins are small additions you choose: a few words in the bar, a key, a Super+m entry, sometimes a program that runs in the background. They come from their own repository, [vikix-plugins](https://github.com/vukini/vikix-plugins), at a version Vikix has checked, and nothing is added until you ask for it. This page is a guide to each one: what it does, how to add it, how to use it, where it keeps things, and what to do when it doesn't work.

## Adding, removing, switching off

```sh
vikix plugin list                 # every plugin, yours marked
vikix plugin add NAME             # says what it runs, needs and changes, asks, then adds it
vikix plugin remove NAME          # runs its remove; your settings for it stay
vikix plugin off NAME             # stop loading it (vikix plugin on NAME brings it back)
vikix plugin safe                 # the next login loads none
```

A plugin's keys and bar take effect at once. If a plugin's key is one Vikix or a web app of yours already has, the plugin's wins, a message names both, and `vikix doctor` lists it until one moves; removing the plugin gives the key back. Vikix's tests check the plugins at its pinned version for such clashes before a release. Each one's settings are yours, in `~/.config/vikix/plugins/NAME/`, copied once and never overwritten. A plugin that keeps a record of what it found (a flight search, a meeting joined) puts it in the record store, `vikix records` ([README](../README.md#the-record-store-vikix-records)), where you can search it.

A plugin's commands (`inbox`, `repos`, `flights` ...) are on your PATH while it's added, each with a man page made from what its `-h` prints: `man inbox`. `man vikix` lists them after Vikix's own, and removing the plugin takes its pages away.

A plugin's code runs inside the desktop with all its power, like your `user.lisp`: add the ones you trust. If one ever stops the desktop from starting, log in on a text console (Ctrl+Alt+F2), run `vikix plugin safe`, log in again, and switch the culprit off.

The keys at a glance. A plugin's keys are all on Super+Alt, with Shift for a second one on the same letter: that is where everything beyond the six main apps opens ([the rule for keys](customize.md)).

| Key | Plugin | What it does |
|---|---|---|
| Super+Alt+w | agent-waiting | Go to the agent waiting for you, or pick among several |
| Super+Alt+u | ai-usage | How much of your Claude plan is used |
| Super+Alt+j | next-meeting | Join the meeting on now, or the next |
| Super+Alt+c | next-meeting | The coming week's meetings |
| Super+Alt+f | flights | Search flights |
| Super+Alt+g | repos | Which projects need pushing, pulling or committing |
| Super+Alt+i | inbox | A note into your inbox |
| Super+Alt+Shift+i | inbox | A note quoting what you selected |
| Super+Alt+Shift+s | inbox | Sort the inbox |

## agent-waiting: an agent waiting for you

You start Claude Code on a task in one window and get on with something else in another. When it needs you, or has finished, the bar says which session, where it is and whether it asks something of you; a notification says what; and one key takes you there.

**Add it:** `vikix plugin add agent-waiting`. It adds five hooks to Claude Code's settings, `~/.claude/settings.json` (a copy of the file is kept first). A Claude Code session already running takes them once you type `/hooks` in it (it asks you to look them over), or when it starts again. After an update that brings new hooks, add it again: it shows what it changes, asks, and adds only what isn't there.

**Use it:**

- `asks: Esploro tags (3)` in the bar, in the accent colour: the session called *Esploro tags*, on workspace 3, wants something of you. Either a dialog is open (a permission, a question with choices) and its work stands still, or it finished and its last words ask something: a question, or a step that is yours (a line that starts `You:`).
- `done: Fix the bar (1)`, quieter: that session finished and asks nothing.
- With several: `asks: Esploro tags (3) +1, done 2` is two that ask and two that finished. The one named is the one to go to first: an open dialog before a question, the oldest first.
- A session is called by its window's title, which Claude Code sets to what the session is about; a window with no title of its own, by the folder the session works in.
- **A notification** comes the moment a session asks: `Esploro tags asks (workspace 3)`, and under it what it asks (`Bash: Install the build`, or its question). Finished sessions stay in the bar only. To have a notification for those too, or none at all, put one of these in `~/.stumpwm.d/user.lisp`:

  ```lisp
  (setf *agent-waiting-notify* :all)   ; finished sessions too
  (setf *agent-waiting-notify* nil)    ; the bar only
  ```

- **Super+Alt+w**, or a click on the bar, goes to the window. When several wait it lists them first, each with its workspace, its name, how long it has waited and what it said; Enter goes to the one chosen. Looking at a window clears its note.
- A session that stops while work of its own still runs in the background (a test run it waits for) isn't done, and leaves no note unless it asks something.

**Where things are:** a small file per terminal window in `~/.local/state/vikix/agents/`: the state and the time, the folder, and the line of what was said.

**When it doesn't work:**

- *Nothing in the bar:* the session started before the plugin was added. Type `/hooks` in it, or start it again.
- *It tells you of a permission some seconds late:* the hook that says a dialog opened (`PermissionRequest`) isn't in your settings. `vikix plugin add agent-waiting` again adds it.
- *It says asks, but nothing asks:* it read a question in the session's last words that wasn't one for you. Look at the window: that clears it.
- *It says done for a session that asked you something:* its last three lines had no question mark and no line starting `You:`. That is all it goes by.
- It knows Claude Code only. Codex, Gemini CLI, OpenCode and Aider don't tell it.

**Remove it:** `vikix plugin remove agent-waiting` takes the hooks out of `~/.claude/settings.json` again, and leaves your other settings as they were.

## ai-usage: how much of your Claude plan is left

With a Claude Pro or Max plan, Claude Code knows how much of the plan you've used: the 5-hour window and the week. This puts it in the bar, so you see a limit coming.

**Add it:** `vikix plugin add ai-usage`. Claude Code hands those numbers only to its status line (the line under its prompt), so the plugin becomes the status line. If you already had a status line of your own, it keeps running, through the plugin, and comes back as it was when you remove it.

**Use it:**

- `plan 24% 41%` in the bar: the 5-hour window, then the week. The accent colour from 75%, the alert colour from 90%.
- **Super+Alt+u**, or a click: how much each window has used, and when it resets.
- Claude Code's own status line shows the same, `plan 24% 5h · 41% week`.

**Where things are:** the numbers in `~/.local/state/vikix/ai-usage`. Every 15 minutes at most, a record in the record store: `vikix records list ai-usage` is your use over days and weeks.

**When it doesn't work:**

- *"nothing known yet":* Claude Code only knows after its first answer in a session. Ask it anything.
- *Nothing at all:* the numbers come with a Pro or Max plan, not with an API key.

**Remove it:** `vikix plugin remove ai-usage` puts back the status line you had before (or none).

## next-meeting: your next meeting, and joining it

Your next meeting in the bar, with how long until it starts; a notification five minutes before; and one key to join it, a Teams meeting in the Teams web app.

**Add it:** `vikix plugin add next-meeting`. It installs two small Python libraries for reading calendars (it asks first). Then give it your calendars: each one's private link, an address that lets the plugin read that calendar.

```sh
next-meeting add work      # asks for the link; what you paste isn't shown
next-meeting add home
next-meeting calendars     # your calendars, by label (never the secret part)
next-meeting forget home
```

Where each calendar's private link is:

- **Microsoft 365 (Outlook on the web):** Settings, Calendar, Shared calendars, Publish a calendar; choose the calendar and how much it shows, Publish, then copy the **ICS** link.
- **Google Calendar:** the calendar's Settings, *Integrate calendar*, the **Secret address in iCal format**.
- **Todoist:** its calendar feed link, where your plan offers one.

**A private link is a key to that calendar:** anyone who has it can read it. The plugin keeps them in a file only you can read and never prints them. If one ever gets out, reset it where you got it.

**Use it:**

- `Standup 14:30 in 12m` in the bar, for the next meeting within four hours; `now: Standup` while it's on, in the accent colour.
- **Super+Alt+j**, or a click: join the meeting on now, or the next one. A Teams link opens in the Teams web app (`vikix webapp add teams`), a Meet link in the Meet one when you have it, anything else in your browser.
- **Super+Alt+c:** the coming week, in a list; Enter joins the one you pick.
- `next-meeting list` in a terminal: the same week.

**Where things are:** the links in `~/.config/vikix/plugins/next-meeting/calendars` (600); the calendars as last read in `~/.cache/vikix/next-meeting/`; what the bar shows in `~/.local/state/vikix/next-meeting`. Each meeting you join is a record: `vikix records list next-meeting`.

**When it doesn't work:**

- *Nothing in the bar:* no meeting in the next four hours, or no calendar yet (`next-meeting calendars`). `next-meeting fetch` reads them all now and says what went wrong with one.
- *Microsoft 365 has no "Publish a calendar":* your organisation has switched publishing off. Ask IT, or use the Outlook web app for that calendar for now.
- *A meeting changed and the bar didn't:* calendars are read every 5 minutes, and Google can take a while to update the link's copy.

**Remove it:** `vikix plugin remove next-meeting`. Your calendar links stay in the settings folder until you delete it.

## flights: searching flights from a line

Type a line like `DXB LHR 12 Nov, back 20th` and see the flights, cheapest first, with the quickest marked. Enter opens that search on Google Flights, where you book (there or on the airline's site): the plugin itself never books anything. It can also watch a route and tell you when it gets cheaper.

**Add it:** `vikix plugin add flights`. It makes a Python of its own with fast-flights, the library that reads Google Flights (a minute, once). Then set your currency and home airport in `~/.config/vikix/plugins/flights/settings`:

```
currency = AED
home = DXB
```

With a home airport, `LHR 12 Nov` is enough.

**Use it:**

- **Super+Alt+f** asks the line, then lists the flights. Enter on one opens the search on Google Flights; the last entry watches the route.
- The line: two airports by their three-letter codes, a date, and `back DATE` for a return. Also `business`, `premium`, `first`, `direct`, `2 adults`, `1 child`. Dates as you'd write them: `12 Nov`, `Nov 12`, `2026-11-12`; `back 20th` for the same month.
- A watched route is checked every 6 hours. When its price drops: a notification, and `flight cheaper` in the bar until you look (a click, or Super+m, *Flights: the watched ones that got cheaper*).
- In a terminal:

```sh
flights "LHR JFK 3 Dec business"    # the list, in the terminal
flights watch "DXB LHR 12 Nov"      # watch a route
flights watching                    # what's watched, and the cheapest seen
flights unwatch 2                   # stop watching the second
```

**Where things are:** the watched routes in `~/.config/vikix/plugins/flights/watched`; the prices seen in `~/.local/state/vikix/flights/`. Every search with its results, and each watched route's price at each check, are records: `vikix records search singapore`, `vikix records list flights --kind price`.

**When it doesn't work:**

- *No flights, or an error, for a route that has them:* fast-flights is unofficial, and a change on Google's side can break it until the library catches up. Search on Google Flights directly meanwhile.
- *A direct flight missing:* the plugin asks for the direct ones separately and adds them; if one is still missing, `direct` in the line asks for only those.
- *Prices in the wrong currency:* `currency =` in the settings.

**Remove it:** `vikix plugin remove flights` removes its Python too. Your watched routes stay in the settings folder.

## repos: what your projects need

Which of your git projects have changes not committed, commits not pushed, commits on GitHub not pulled, tags not pushed, or stashes left behind. The bar keeps count; one key opens a terminal with the details and the commands to run.

**Add it:** `vikix plugin add repos`. It looks at every project in `~/src`, and at `~/.emacs.d` and `~/.dotfiles`. To change which, see the settings below.

**Use it:**

- `git 2` in the bar: two projects need something. In the accent colour when something is waiting to be pushed or pulled.
- **Super+Alt+g**, or a click: a terminal with each project's state and the commands that do what it needs. The commands are in the terminal's history: press **Up** to bring each back, Enter to run it.
- Super+m, *Projects: pick one*: the projects in a list; Enter offers push, pull, a terminal there, or Magit in Emacs.
- `repos fetch` asks GitHub now what's new (it does every 30 minutes by itself).
- `repos push` pushes every project that needs it, commits and tags (`repos push esploro` just that one). A project another pins goes first: Esploro and the plugins before Vikix, whose files name the commit of each it builds. It won't push Vikix while it pins a commit GitHub hasn't got, since every install that updated would then fail to fetch it. When GitHub has moved on, it brings those commits in first and pushes again.
- `repos pull` brings in GitHub's new commits for every project, yours put on top of them. It asks over HTTPS, so no passphrase.
- `repos ship` is `repos push`, then `vikix update core`: the desktop runs what you pushed. The step after a release.
- `repos update` updates the whole system (`vikix update`: Void's packages, Vikix, your tools).
- `repos` also says when a project is past the commit Vikix pins (`2 past vikix's pin`): it has work Vikix doesn't use yet.

It never pushes, pulls or merges unless you ask, and asking GitHub never needs your SSH key's passphrase: it goes over HTTPS, through `gh`'s login when you have one.

**Settings** (`~/.config/vikix/plugins/repos/settings`):

```
roots = ~/src                       # folders whose projects it looks at
extra = ~/.emacs.d ~/.dotfiles      # single projects elsewhere
skip =                              # projects to leave out, by folder name
push = gpush {path}                 # the commands it suggests, if not git's own
pins = esploro:~/src/vikix/bin/vikix-esploro vikix-plugins:~/src/vikix/bin/vikix-plugin
                                    # PROJECT:FILE, the file holding NAME_COMMIT=<sha>
```

**When it doesn't work:**

- *A private project never shows commits to pull:* GitHub needs `gh auth login` to answer for a private project.
- *The wrong terminal opens:* it opens Vikix's (Super+Return's); `terminal = kitty` in the settings names another.

**Remove it:** `vikix plugin remove repos`.

## inbox: notes from anywhere

A key over whatever you're doing opens a small box; what you write, or say, lands in your Org inbox in Dropbox, which your phones see too. Later, one key sorts the inbox into your notes files. This has a guide of its own: [Your notes](notes.md).

**Add it:** `vikix plugin add inbox`. It needs Emacs (`vikix add emacs`) for the box; without Emacs, the box is a one-line rofi prompt.

**Use it:**

- **Super+Alt+i:** the box. The first line is the note's title. **Super+F9** speaks into it. **C-c C-c** keeps the note, **C-c C-k** drops it.
- **Super+Alt+Shift+i:** the same, with what you'd selected quoted in it.
- **Super+Alt+Shift+s:** sort the inbox. A model suggests where each note goes and which are to-dos; you change what you like (`3` to move note 3, `t 3` to-do or not, `d 3` delete), Enter does it. `inbox sort --undo` puts it all back.
- `inbox add "call the bank"` from a terminal.
- `notes-sync` (or Super+m, *Notes: sync with Dropbox*): your notes up to Dropbox now. It starts Dropbox if it isn't running, takes the notes folder back into this laptop's sync if selective sync left it out, and waits until Dropbox says it's up to date.

**Where things are:** the notes in `~/Dropbox/notes/`; the inbox is `inbox.org` (another file: `file = ~/notes/inbox.org` in `~/.config/vikix/plugins/inbox/settings`); the copies each sort keeps in `~/.local/state/vikix/inbox/sorts/`.

**When it doesn't work:**

- *Two boxes open, Emacs's and rofi's:* the note couldn't be added in Emacs (an older plugin with an Emacs that opens files read-only). `vikix update` brings the fix.
- *No page address on a note from the browser:* Firefox saves its open tabs every 15 seconds, so a page opened just before may not be known yet; web apps (Chromium) give only their title.
- *To-dos don't reach Todoist:* `vikix ai key set todoist` once, with the token from Todoist's Settings, Integrations, Developer.

**Remove it:** `vikix plugin remove inbox`. Your notes stay where they are.
