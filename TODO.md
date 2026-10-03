# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0. The editors (Neovim into Vikix, AI in Neovim and Emacs) have their own list: `TODO-editors.md`.

## What's next, in order (drawn up with Vid 2026-10-03)

From a review of 0.71.71 against one aim: the best desktop for a power user. Vikix has no users but Vid yet, so what only matters once others arrive (a promise about what won't change, opening the plugin repo, items 19 and 20) waits for the first of them. Until then, in this order:

1. **The rules language** (the next section, items 66 to 71). Vid picked it first.
2. **Saved layouts** (items 29 and 50a, with IDEAS' "Layouts as plain Lisp"): one feature, used by hand, by a rule (`(layout "writing")`) and by `vikix project open`.
3. **A desktop to trust for weeks.** Signed updates (To look into, 4). A soak test: a hidden StumpWM on Xvfb with windows opening and closing for an hour, the time its main thread takes to answer measured over Swank, failing above a limit, weekly on GitHub. And times written down and tested: login to a usable desktop, a reload, a key to its action, an Emacs frame. Neither test is worked out yet.
4. **Agents that act through code you can check first** (IDEAS, Leaning into Lisp), then the time machine for functions. The rules language's verbs (item 66) are the first entries of its allow-list.
5. **In between, as polish:** `bugs.md`; a newly plugged screen (To look into, 2); GTK and Qt programs following `vikix theme`, and a tray that can be switched on (README, "Not done yet").

## The rules language (picked by Vid 2026-10-03)

Rules for the desktop that read like sentences, in Lisp: what happens when a window opens, at a time of day, when the battery runs low.

```lisp
(when-window (:class "Firefox") (workspace 2))
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(when-window (:class "mpv" :title (:has "picture in picture"))
  (float :corner :bottom-right :width "30%") (sticky))
(at "09:00" :weekdays (open-project "vikix"))
(each 30 :minutes (run "vikix-wallpaper next"))
(when-battery-below 20 (notify "Battery at 20%: charger?"))
(at-login (run "syncthing --no-browser"))
```

**Why.** Today each rule is a function and a hook written by hand. Vikix has three (dialogs and Lazarus in `windows.lisp`, `vikix learn`'s panes in `commands.lisp`), Vid's `user.lisp` three more (nmtui, the drop-down terminal, Lazarus again), and two plugins one each (inbox's box, agent-waiting's change of focus): a dozen lines each, repeating the same guards, and each a place for the traps already met. Floating a window twice is an error. A tiled window kept on every workspace ends the desktop at the next workspace switch. A timer given `0.3` instead of `3/10` stops the event loop. A title matched as a pattern without `^...$` catches every window with the word in it. The language keeps those guards in one place. And since a rule is data (its own text is kept), the desktop can list its rules, say why a window went where it did, write one for you, and later let the apprentice (IDEAS) and the agents propose them in a form you can read before it runs.

**Decisions.** Suggested by the review; Vid to confirm or change each before item 66 is built.

- **Where rules live.** In `user.lisp`, or in a file of their own, `~/.stumpwm.d/rules.lisp`: the user's (`yours.list` already covers `.stumpwm.d`, so snapshots and `vikix undo` do too), loaded by `init.lisp` just before `user.lisp`, a form at a time as every file is, so `user.lisp` still wins. The desktop only ever writes to `rules.lisp` (item 69), never to `user.lisp`.
- **A plain string matches exactly.** `(:has "text")` is "contains", in any case; `(:like "^regex$")` is a pattern; a list of them is any of them. StumpWM's own placement rules take every string as an unanchored pattern, which is the trap above.
- **Verbs are looked up in a table, not called as functions.** They can't be functions of those names: in StumpWM's package `float` is Common Lisp's, `fullscreen` and `title` are StumpWM's commands (checked 2026-10-03), and `every` is Common Lisp's too, which is why the word for a repeat is `each`. So `when-window` reads the forms of its body: one whose first word is in the verbs table becomes a call to that verb, and any other is ordinary Lisp, left as it is. Only the body's own forms are read this way, not what's inside them. A misspelt verb or matcher is then an error when the file loads, with its file and line in the errors menu, not when the window opens three days later. The table is also the list `vikix rules verbs` prints, and the start of the allow-list for agents (What's next, 4).
- **A rule that fails never asks.** Rules run inside StumpWM's handling of an X event or a timer, where an error that gets out means `errors.lisp`'s menu at best and a restart of StumpWM at worst, once for every window that opens. Each run is wrapped: the error is written to `~/.local/state/vikix/errors/` as any other, a message names the rule, and the third failure switches the rule off until the next reload (`vikix doctor` lists those).
- **A reload gives exactly what the files say.** The table is emptied when the layer loads, and a rule is known by its `:name`, or without one by its own text, so loading a file again, or `C-x C-e` on a rule in Emacs, replaces it and never adds a second. A reload doesn't move windows already open; `vikix rules apply` does, when asked.
- **Order.** Rules run in the order they were defined: Vikix's, the plugins', `rules.lisp`, `user.lisp`. The last verb to act wins.
- **Not in the language:** keys (`vikix-bind` stays as it is), and conditions of its own (the body is Lisp: `when`, `unless`).

66. **The core: `when-window` and its verbs.** A new layer file, `config/stumpwm/vikix/rules.lisp`, in `init.lisp`'s `*vikix-files*` after `windows` (it uses its floating and centring) and before `plugins` (so plugins can use it).
    - **The table,** `*vikix-rules*`: for each rule its name, what sets it off, its matcher, its text as written, the file and line it came from and whose that is (Vikix, a plugin by `*vikix-plugin*`, `rules.lisp`, `user.lisp`), the compiled body, on or off, how often it ran, when last, and its last error. One named function a StumpWM hook (`*new-window-hook*`, `*focus-window-hook*`, `*destroy-window-hook*`), each going through the table: never a hook a rule. Taking a rule away is then taking its entry out, and unloading a plugin takes its rules with it, which hooks added by hand can't do ("Hooks a plugin added stay until StumpWM starts again", `plugins.lisp`).
    - **Matchers:** `:class`, `:instance`, `:title`, `:role`, `:type` (`:dialog`, `:normal`), `:workspace` (where it opened), `:not (...)`, and `:where FUNCTION` for anything else. Before the body, options: `:name "..."`, `:on :open` (the default), `:on :focus`, `:on :close`, and `:once t` (the first window that matches only: Firefox to workspace 2 at login, later windows where you are).
    - **The first verbs,** each safe to run twice and checking before it acts: `workspace` (a number or a name; `:follow t` goes along), `float` (`:width`, `:height`, `:x`, `:y`, `:corner`; centred when no place is given; a whole number is pixels, `"65%"` a share of the window's monitor), `tile`, `fullscreen`, `sticky` (on every workspace: it floats the window first, because of the trap above), `dialog` (float, centred, kept in front, as `*vikix-dialog-classes*` does), `title`, `focus`; and for any rule `run` (a shell command), `command` (a StumpWM command), `notify`, `say` (StumpWM's message), `open-project`, `theme`. `(window)` is the window, for Lisp of your own. `(define-rule-verb NAME (ARGS) "what it does" ...)` adds a verb, for plugins and `user.lisp`.
    - **`workspace` without a flash.** StumpWM chooses a new window's workspace before showing it (`get-window-placement`, from its own `*window-placement-rules*`) and runs `*new-window-hook*` afterwards, so a window moved from the hook shows where you are for a moment first. Build it with the hook, look on Xvfb and on the laptop; if the flash shows, wrap `get-window-placement` (`sb-int:encapsulate`, as `windows.lisp` wraps `update-window-properties`) so rules with a `workspace` verb are asked there.
    - **Tests,** `tests/rules.sh`, in two parts. Without a screen, as `tests/errors.sh` runs: StumpWM's window objects can be made without X (`(make-instance 'tile-window :class "Firefox" :res "Navigator" :title "...")`, checked 2026-10-03), so matching, the errors at load, one rule after a second load, and the switching off after three failures are all tested there. The verbs need real windows: a hidden StumpWM on Xvfb, as was done by hand for the errors menu on 2026-10-02, windows opened with a class of their choosing, then `vikix eval` asked where each ended up. That is the first Xvfb test in `tests/`, and the soak test (What's next, 3) grows from it. Not with xterm until `bugs.md`'s resize loop is fixed. And `tests/lisp.sh` fails on a float written as a delay to `run-with-timer` anywhere in the layer (`errors.lisp` already mends such a timer when it meets one; this keeps them from being written).
67. **Time, power and login.** The forms `at`, `each`, `when-battery-below`, `when-charging`, `when-on-battery`, `at-login` and `when-workspace`, on the same table.
    - **One ticker** for all of them (every 30 seconds, whole numbers only), never a timer a rule.
    - **`at "09:00"`** with `:weekdays`, `:weekends` or `:on (:mon :thu)`. A time missed while the laptop slept runs on waking when it is less than an hour late (`:late nil` never, `:late t` however late). What has run today is kept in `~/.local/state/vikix/rules/`, so a reload or a restart of StumpWM at 09:05 doesn't run it again.
    - **`each N :minutes`** (or `:hours`), counted from when it last ran.
    - **`when-battery-below N`** runs once as the charge goes under N, and is ready again once it is above or on the charger. It reads the same sysfs files as the bar (`vikix-battery-file`, `modeline.lisp`).
    - **`at-login`** runs once a login, not at each reload. It replaces the `pgrep -x ... ||` in front of every startup program (docs/customize.md, "Start a program with the desktop"). To settle while building: what marks a login (a file in `$XDG_RUNTIME_DIR` named by `vikix-session`'s process, so a restart of StumpWM alone doesn't count as one).
    - **`when-workspace 3`** runs on going to that workspace.
    - **Later, not now:** a screen plugged in or taken away (with the screens work; StumpWM has `*new-head-hook*` but nothing for one removed), a Wi-Fi network joined, a drive plugged in, idle.
    - **Tests:** the clock and the battery are read through functions the tests replace, so a test steps through a day, a sleep and a discharge in a second, without a screen.
68. **Seeing and steering them: `vikix rules`.** `bin/vikix-rules`, thin over `vikix eval`.
    - `vikix rules` lists them: a number, on or off, the rule as written, where it's from, how often it ran and when last, its last error.
    - `off N|NAME` and `on`; off lasts until the next reload, and the list says so.
    - `why` for the focused window (or `why CLASS`): which rules matched it and what each did. Each window keeps a short note of the rules that ran on it.
    - `test`: the open windows against the rules, saying what would happen, doing nothing. `apply`: do it, for windows already open.
    - `verbs`: the verbs and matchers, each with its line of description.
    - Super+m, Rules: the same list in a menu. `vikix doctor`: rules switched off after failures, and rules naming a workspace that isn't there. `vikix debug`: the list, scrubbed as the rest. The MCP server: a read-only `rules` tool (the list, and why).
69. **"Remember this window here"** (Super+Ctrl+t, beside Super+t; free in `keys.lisp` and in Vid's `user.lisp` on 2026-10-03, Super+Shift+t being Vid's theme picker).
    - It reads the focused window: what to know it by, its workspace, tiled or floating, and when floating its size and place as shares of the monitor.
    - **What to know it by:** its class; its instance instead when other windows share the class (Alacritty started with `--class`, the web apps' `vikix-NAME`); its title, matched whole, for an Emacs frame with a name of its own, since every Emacs frame has the same class.
    - It shows the rule it would write, in StumpWM's menu: write it, the workspace only, cancel. Then a snapshot ("before: a rule for Firefox"), the rule added to `~/.stumpwm.d/rules.lisp` under a dated comment, with `:name "remembered: Firefox"`, and loaded. Remembering the same window again replaces that rule. `vikix undo` takes it back, and `vikix rules forget` removes one by name.
70. **Vikix and Vid move over.** The proof that the language is enough: if one of the eight rules written by hand today can't be said in it, it is short of something.
    - In the layer: Lazarus's floating windows and `vikix learn`'s panes become rules. Dialogs keep `vikix-float-dialog` (it also raises them at every change of focus), with `*vikix-dialog-classes*` working as before and the verb `dialog` beside it.
    - In Vid's `user.lisp`, by Vid or with Vid, since it's the user's file: nmtui, the drop-down terminal's window, and Lazarus (which the layer already does).
    - In `vikix-plugins`: inbox's floating box (`*new-window-hook*`) and agent-waiting's clearing on focus (`*focus-window-hook*`, a rule with `:on :focus`) become rules, and the pin moves. Its test then fails on an `add-hook` in a plugin's Lisp, so a removed plugin leaves nothing behind.
71. **The guide, and what follows.**
    - A starter `config/stumpwm/rules.lisp`, copied once (`copy_user`) to `~/.stumpwm.d/rules.lisp`: all comments, with the examples above.
    - `docs/rules.md` (the forms, the matchers, the verbs, how to see why a window moved), in `docs/README.md`'s table; `docs/customize.md`'s "Start a program with the desktop" becomes `at-login`; `docs/map.md` gets the new files; the skill (`SKILL.md`) tells agents to write a rule into `rules.lisp` after a snapshot, not a hook into `user.lisp`; the README's keys and the site's card.
    - Then, each an item of its own when its turn comes: the verb `layout` (What's next, 2); the apprentice's suggestions written as rules (IDEAS); a `propose_rule` tool for agents, shown before it is applied as `propose_file_changes` is; and the verbs table as the allow-list's first entries (What's next, 4).

## Features

Built in this order: newcomers first, then the rest (the AI items have shipped; more are in the wish list). Package facts were checked against void-packages on 2026-09-28. In Void: uv, espeak-ng, podman, tesseract-ocr, xcolor. Not in Void: ollama, llama.cpp, whisper.cpp, aichat, llm, piper-tts ("piper" in Void is a gaming-mouse tool). Those come from their official releases, uv, or a source build in the style of 65-languages: pinned, checksummed where the project publishes checksums, and in ~/.local.

### And then

72. **Viri, a workspace that scrolls sideways** (`DESIGN-viri.md`; Phase 0 in, `vikix viri`). Next, from living in it: a border on the focused column (the first thing missing), Super+Tab's overview as a menu of the strip's columns, widths (Super+r on a strip), stacking two in a column, then `vikix project` saving a strip and the agent's `desktop` tool seeing columns. Firefox off the screen's edge: watch whether it throttles.
64. **Esploro becomes Vikix's file explorer** (decided with Vid 2026-10-02). The plan is in Esploro's DESIGN.md ("Becoming Vikix's file explorer"). The window is Emacs (measured there: dired 1-2 ms a key at 20,000 files, McCLIM 44 ms with none and 7 s at 20,000; McCLIM kept on Esploro's `mcclim` branch), with menus, the mouse and drag and drop, and step 1 is in (0.71.x). Step 2 is in too: Super+e, folders by default (set over PCManFM only), drives through `xdg-open`, and "Show in folder" (org.freedesktop.FileManager1). Not done, on purpose: moving it into the base install, since it needs Emacs, which is a feature of its own; PCManFM stays the base's, and Super+Alt+e. `vikix doctor` says whether it's built at the pin and answering (`vikix esploro doctor`).
6. **Whole-system undo.** When / is btrfs: snapper snapshots before each `vikix update`, and `vikix rollback` notes. Skip cleanly on ext4.
9. **Tutorials: `vikix learn c`, Phase 2.** Paused until Vid has worked through some lessons (see TUTORIALS.md, "Where it stands"). Tracks 1 to 4 (fourteen lessons) shipped in 0.71.22. Next: tracks 5 to 8 (where everything lives, the heap, strings, structs) and the tutor skill. The plan and the decisions are in `TUTORIALS.md`; `learn/outputs.py --fill` writes a lesson's quoted outputs from real runs.

## Wish list

Added 2026-09-30, from a conversation with Vid about 0.52-0.65. Not yet ordered against the list above, and no package names checked against void-packages yet: check each before building, as for the features above. Numbered on from 10.

### AI, more

12. **A cloud model for `vikix ai use`.** Beside `local` and `claude`, `cloud`: any OpenAI-compatible address, a key from `vikix ai key`, and a model name, with OpenRouter as the ready-made default (one key, hundreds of models, pay per use). `s-i`, `llm`, gptel, Neovim's AI and the agents' `--local`-style switch all follow it. The docs say plainly that the text goes to that service and its model host.
15. **Your own model in the cloud: a guide.** Serverless GPUs (RunPod, Modal: pay per second, a minute or two to wake), a GPU rented by the hour (RunPod, Vast.ai, Lambda), and OpenRouter, compared on cost and privacy; which model sizes fit which cards at Hermes's 64k context; then pointing `vikix ai use cloud` at your own endpoint. Probably a docs page, not code.

### Your machines and your phone

16. **Tailscale as a feature.** A private network between your own devices: the safe way for a phone or a server to reach the laptop, never SSH open to the internet.
17. **Syncthing as a feature.** Folders (an Obsidian vault, say) kept in step between machines directly, no cloud; a bar note while it syncs.
18. **KDE Connect.** Phone notifications on the desktop, files both ways, the phone as a remote.
19. **`vikix export` / `vikix import`.** One file with your features, theme, keyboard, web apps and settings (no secrets), so a new machine becomes yours in one step.
20. **A Vikix installer image.** A USB stick that installs Void and Vikix in one go (void-mklive).

### The desk: mail, documents, investing

21. **The desk.** Business mail and paperwork, sorted by AI, for someone who gets hundreds of emails a day across more than one company. Parts, in order:
    - **Mail on the machine:** isync into a Maildir, indexed by notmuch; searchable offline, readable in Emacs. Microsoft 365 may block this (IMAP needs OAuth, and IT may refuse); then the brief works from the web app or Superhuman instead.
    - **`vikix mail brief`:** the day's mail in groups (needs your reply, waiting on others, invoices and payments, investor and bank updates, newsletters, skip), a line each. Draft replies for the first group, into a drafts folder: nothing ever sends itself.
    - **Documents:** an inbox folder for scans, downloads and attachments (pulled from mail); OCR, dated, tagged by company, type and counterparty, filed (Paperless-ngx, locally). Questions across them ("the notice period in the lease"), and reminders for dates found in them.
    - **Investing:** holdings as plain-text accounts (hledger or Beancount) or Ghostfolio, fed from broker statements the AI turns into entries you check; prices and news for what you hold. Numbers, not advice.
    - **The morning brief:** mail, today's calendar, dates coming up in documents, the portfolio, on one page.
    - **Rules:** the step that reads mail can do nothing else (no sending, no web, no commands), because any email may carry a prompt injection; business folders go to a local model by default, Claude only where chosen; `llm`'s log off for this (it keeps every prompt); one key for this job only; companies kept apart (tags, folders, accounts); everything in `vikix backup`. Check the laptop's disk is encrypted.
    - To ask Vid first: which mail systems, where documents live now, which brokers, and whether Claude may read business mail.

### Music

22. **Music production as a feature.** Low-latency audio: PipeWire's JACK side, realtime priority (rtkit or limits), Ardour, Carla and a plugin set; a setting that trades battery for lower latency while recording.

### Languages and reading

23. **Keyboard layouts on a key.** English, Arabic and others, switched with a key, the current one in the bar; Esperanto keeps its Right Alt option.
24. **Spell checking in Esperanto and Arabic,** in Emacs, LibreOffice and Firefox (hunspell dictionaries).
25. **Read aloud.** An `s-i` action that speaks the selection with a local voice (piper, from its release: not in Void).
26. **E-books to an e-reader.** Calibre as a feature: send an EPUB or PDF to a BOOX or Kindle, converting first when needed.

### Work

27. **Remote desktop.** Remmina or FreeRDP, for work servers, lighter than the Windows VM.

### The desktop

29. **Save and restore layouts.** `vikix layout save writing`: which windows sit where on a workspace; restoring brings the workspace back for a project.
30. **A drop-down terminal** on Super+`, over whatever is open.
31. **Find any file.** A rofi search over the home folder (plocate or fd), as fast as typing.
32. **Battery care on ThinkPads.** tlp's charge thresholds: stop at 80% while docked; a Super+m entry to charge to 100% before a trip.

### Family

33. **A children's account.** A second login with a simpler desktop and apps chosen by the parent, where nothing of the parent's can be broken; a home for a child's programming course.

### Plugins, themes and wallpapers (decided with Vid 2026-09-30)

Three new repos beside Vikix, each independent: `vukini/vikix-plugins`, `vukini/vikix-themes`, and the wallpapers, done as `vukini/wallpapers` (`vikix add wallpapers`; still to do there: a `CREDITS` file, and Git LFS or release archives if the clone gets slow). The core keeps what a fresh install needs offline: void and paper and their two wallpapers. Every plugin offered is Vid's own for now; opening the repo to others' plugins comes later.

34. **A plugin system.** Built in 0.71.x: `vikix plugin` (list, add, remove, off, on, safe, status, sync), the repo `vukini/vikix-plugins` at a pinned commit, the kinds bar (`%P`), menu, key and service, `plugins.lisp` loading each through the errors menu, the debug report. Still to do: `vikix doctor` naming them, and a safe-mode login chosen at the login itself (now `vikix plugin safe` before logging in).
35. **`vikix-themes`.** A folder per theme: the `.theme` file, its wallpaper, a preview in void and paper sizes. `vikix theme get NAME`, or `vikix add themes` for all; the picker lists them. Item 5's "more themes" (Gruvbox, Nord, Tokyo Night, a high-contrast one) are made here, not in the core.

The first plugins, in order:

37. ~~**Agent waiting**~~ The first plugin, `agent-waiting` (Claude Code through its hooks). Still to do: the other agents, by watching their terminals.
38. ~~**Notes from anywhere.**~~ The plugin `inbox`: the box (Super+Alt+i, Super+Alt+Shift+i quoting the selection), the page's address (Firefox, Nyxt), `inbox sort` (Super+Alt+Shift+s: the model suggests, you choose, `--undo`) and to-dos to Todoist. Still to do, later: a daily digest of what was captured; the web apps' (Chromium's) page addresses.
39. ~~**Flights**~~ The plugin `flights` (search from a line, watched routes): prices from Google Flights through fast-flights (no card, unofficial), never booking; LetsFG wasn't used (it asks for a card to search, and can book).
40. ~~**AI usage.**~~ The plugin `ai-usage`.
41. ~~**Next meeting.**~~ The plugin `next-meeting` (calendars by their private ICS links). Still to do: Microsoft 365 by its sign-in, for when IT forbids publishing a calendar.
42. **Unread mail.** A count in the bar: the first small piece of the desk (item 21).
43. **Build status.** The last GitHub test run for chosen repos, Vikix's first; red in the bar when one fails.
44. **A number of your choice.** Any figure refreshed on a timer (a portfolio's value, a sales total), from a command you give. Off unless set up.
45. **Screen time for children.** Daily limits on the children's account (item 33), with a warning before time runs out.
46. **Weather.** A small note for your city in the bar.

## Vikix as the workshop for the Living Series (decided with Vid 2026-09-30)

Vid's books, sites and apps (the Living Series: about 28 projects, 315 MB, today in the Obsidian vault's `Living-in-Life` folder, with Progress docs in a claude.ai project and the Work Log, Status Board and Living Shelf as claude.ai pages) move into one repo, and Vikix becomes the system they're made in. The general parts are Vikix features anyone could use; the Living Series is Vid's configuration of them. Once `vukini/living-series` exists, its own steps move into that repo's `TODO.md`.

Decided: **one repo** for all the projects; **private**; the claude.ai pages kept as **online views generated from the repo**; editing in **Emacs**, Obsidian only as an optional viewer (mainly to read on the phone); work away from the laptop goes through **Claude sessions on the GitHub repo** (as on 2026-09-29/30), so the Windows PC needn't be on.

47. **The repo, `vukini/living-series`.**
    - A folder per project (kebab-case names, fixing `Living-in-Commor-Lisp`); `shared/` for what projects share (house styles, the Living Maths shell, build and check helpers); a `project.org` in each folder: its name, kind, % done, next step, artifact URL and build, check and publish commands as Org properties, and its work log as dated headings under `* Log`, which Emacs and agents read as a tree (item 57). The books themselves stay in Markdown: their pipelines, the sites and GitHub all work with it.
    - A root `CLAUDE.md` (the series' house rules, the log rule, Working in parallel as in Vikix's), and one per project from its House-Rules/Plan; the skills in use (algorithms-in-python, living-in-javascript, interactive-learning-site, work-log) as the repo's own `.claude/skills/`.
    - Built files (EPUBs, generated HTML, `out/`, `dist/`) not committed: `make` rebuilds them. The Esperanto art (241 MB) in Git LFS or its own repo: check LFS storage limits first.
48. ~~**Moving in, safely.**~~ Done 2026-10-02: every project moved, checked and building in `~/src/living-series`; the vault's `Living-in-Life` archived (`~/backups/archive/`) and removed.
50. **The `living` plugin (Vid's own).** The series-specific layer on `vikix project` (item 49, shipped): `living` (the dashboard), `living open lambda`, `living log`, `living shelf` (the Living Shelf page built from the projects' `log.md` files: the log is Markdown now, `log.md` per project with a Status block and dated entries, not the `project.org` first planned), and a bar note for the project in hand. It uses the plugin system (item 34).
50a. **`vikix project open` with a saved window layout.** The last part of item 49 (`new`, `check` and `vikix today` shipped after 0.71.32):
    - `open` with a saved window layout: the project's terminal, editor, a preview of its built page and the agent, placed the way they were left last time (StumpWM's dump-group / restore-group, saved per project), instead of a fresh terminal and editor.
51. ~~**The online views.**~~ Dropped (Vid, 2026-10-02): the series is made on the laptop and claude.ai is no longer used, so there are no pages there to regenerate. `vikix project list` and the logs are the views.
52. **Reading on the phone.** The GitHub app shows the private repo as it is (Markdown and Org both render; nothing to set up, read-only); the online views (item 51) for status at a glance. Notes and quick capture on the phones go through the Org notes in Dropbox (item 54), not the repo. Obsidian is no longer part of this (item 53).

## Org instead of Obsidian (decided with Vid 2026-09-30)

Obsidian is retired. Vid used it to view, organise and quickly capture notes, synced to Android, iPhone, Linux, Windows and Mac. Org takes its place: plain text that is also a tree of data a Lisp can read, so the desktop (StumpWM), the editor (Emacs), the notes and the agents are one Lisp system. Editing is in Emacs; the phones use Org apps; Dropbox syncs, because it is the one method both phone apps share.

53. **Obsidian, retired in stages.** It keeps working in parallel until the phones have proven themselves for a few weeks; then the vault is archived (read-only, in `vikix backup`), not deleted. The Living Series leaves it through items 47–52; everything else through item 55.
54. ~~**The notes: Org files in `~/Dropbox/notes`.**~~ Done without a feature of its own (`notes` is `note ask`'s): the inbox plugin makes the folder and `inbox sort` the starter files; `config/emacs/vikix-notes.el` gives `C-c n` (the agenda over the notes and their journal, the TODOs, capture into the inbox, the journal, org-roam's find, links, backlinks and graph through org-roam-ui), loaded by emacs-void, where `~/Dropbox/notes` opens editable. Still to do: `vikix doctor` saying whether org-roam is installed.
    - **History without breaking sync:** no `.git` inside Dropbox (the two fight over the same files and can corrupt the repo). A timer copies `~/Dropbox/notes` into a private repo outside Dropbox, `~/notes-history`, and commits hourly, so every version can be restored; `vikix backup` covers both.
    - **Conflicts:** an edit on a phone and the laptop before they sync leaves a Dropbox "conflicted copy"; `vikix doctor` and a bar note point them out, and a command shows the two side by side.
55. ~~**Converting the vault.**~~ `vikix obsidian` (bin/vikix-obsidian): a folder at a time into `~/Dropbox/notes/vault/`, links as org-roam id: links (IDs from each note's place, so links work ahead of their folder), front matter, attachments copied, a report per folder; the vault only read. Still to do: Vid converts the folders and checks them; then item 53, the vault archived.
56. ~~**The phones.**~~ `docs/notes.md`, the notes guide: the laptop's side (the box, the sort, `C-c n`) and Orgzly Revived and beorg over Dropbox, what each can do, what travels and what to do with a conflicted copy. Notes files open in Emacs follow the phones' changes (auto-revert). Not yet tried on the phones themselves: Vid to try both and correct the steps.
57. **Notes an agent can query.** Emacs reads Org as a tree (org-element; org-ql for queries), so an agent working through Emacs asks exact questions ("projects under 50%", "notes tagged vikix this week", "open TODOs for Link") instead of searching text. Exposed to the agents through the checked-Lisp route (IDEAS: Leaning into Lisp) and the MCP server; read-only by default, edits shown before they're made.

## The ROG Flow Z13 (bought 2026-09-30)

Vid's new laptop, bought for AI on the machine itself: an ASUS ROG Flow Z13 (2025), model GZ302EA-XS99. AMD Ryzen AI Max+ 395, 128 GB of memory shared by the processor and the graphics, a 13.4" 2560×1600 touch screen, a detachable keyboard. Most of this can only be finished with it in hand.

58. **Void and Vikix on it.** Install from the glibc image and write down what works on Void's kernel: Wi-Fi 7 (MediaTek), the speakers (CS35L41 amplifiers, which need their firmware), the camera, the fingerprint reader, suspend, the battery. What needs a fix becomes item 59; the findings go in a hardware page in `docs/`.
59. **A Z13 profile in `55-hardware`**, chosen by the model name (DMI: GZ302). The detachable keyboard wakes it from suspend when folded shut: switch off that USB device's wake-up, through an elogind sleep hook. `Xft.dpi` for its screen (about 225 pixels an inch). ASUS's fan and power modes and the keyboard light with asusctl, if Void packages it. Touch works in X; turning the screen round by hand from Super+m, and turning it by itself (iio-sensor-proxy) later.
60. **Most of the memory for AI.** On this chip Linux lets the graphics use only part of the memory at first (about 96 of 128 GB). Kernel settings (the TTM page limit) raise it to about 120 GB, which Qwen3-235B needs. `vikix ai setup` offers it on any Ryzen AI Max machine, asking first, since it changes how the machine boots.
61. **Ollama on its graphics.** Vulkan (the library `vikix ai setup` already keeps) against ROCm, measured with gpt-oss-120b. The picker in `vikix ai models` learns the 128 GB tier: gpt-oss-120b (about 63 GB, 34-56 tokens a second: the default), Nemotron 3 Super 120B for coding agents, Qwen3-235B after item 60. Its memory rule counts memory the graphics share.
62. **Local by default for private work.** Notes (`note ask`), Super+i and the desk (item 21) on gpt-oss-120b, with nothing leaving the laptop; Claude for coding Vikix and the Living Series' core work (the explanations, code, measured findings). Try gpt-oss-120b on Esperanto and Toki Pona passages Vid knows well before using it on those books.
63. **Quiet or full power.** A Super+m choice between quiet (battery, fans down) and full power for long AI jobs (asusctl's profiles, or the kernel's platform_profile), with the bar saying which.
13. **Hermes Agent (Nous Research): the phone gateway and local agents** (items 13 and 14 merged and moved here, Vid 2026-10-02: as a sixth terminal agent it adds little beside the five, so it waits for the Z13). Worth it for: talking to the agent from Telegram, WhatsApp or Signal (its gateway), its scheduled jobs, and memory and skills it keeps itself on any model, local ones included, which the Z13 makes real. Needs a design first.
    - **The agent:** `vikix agent --use hermes`, installed from the official https://hermes-agent.nousresearch.com (hermes-agent.org is a third party): `install.sh` clones into `~/.hermes/hermes-agent`, bootstraps uv, puts `hermes` in `~/.local/bin`. Checked 2026-10-02: by default it also installs a browser (Chromium) and a computer-use driver (`--skip-browser`, `--skip-computer-use`; skip computer-use at least), it tells you to reload `.bashrc` (keep it off yours), and it follows a moving branch (no version pin found). No login of its own but Nous Portal, so like Aider it keeps one key, the one it needs, from `vikix ai key`, never copied into `~/.hermes/.env`. It reads `AGENTS.md` from the project folder, not Vikix's guide in `~/.local/share/vikix`: find how to give it that. ACP: `hermes acp`, after installing its `acp` extra. Local models: a custom OpenAI-compatible `base_url` (Ollama). Try the installer in the VM first.
    - **The gateway:** a door into the machine, so: an allow-list of senders, Hermes's Docker backend for commands, a bar note while it runs (`hermes`), and a snapshot on a timer instead of per session. On a laptop it stops when the lid closes; the always-on version is Hermes on a small cloud server reaching the laptop over Tailscale (item 16).

## C tutorials: `vikix learn c`

Plan: Learning To Code project → "Vikix — C Tutorials Plan"
Standard: C23 (ISO/IEC 9899:2024). Free draft N3220:
https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3220.pdf

### Decide first
- [ ] Lesson style: working example first, then a small exercise? (or examples only)
- [ ] Audience: me first, or Vikix newcomers too? (sets where track 1 starts)
- [ ] Editors: terminal only, or an Emacs/Neovim key that runs the check?
- [ ] Put ~/learn/c/ in yours.list so `vikix undo` covers exercise work?
- [ ] Switch the plan from -std=c17 to -std=c23 (check the gcc/clang versions on Void)

### Phase 0: prove the feel
- [ ] bin/vikix-learn runner (language-neutral: each course folder carries its own compile/check)
- [ ] Commands: learn c | list | go NN | hint | reset NN | check
- [ ] Watch mode with entr; build with -Wall -Wextra -pedantic -g -fsanitize=address,undefined
- [ ] Design-recipe checks run one step at a time; show only the first failure
- [ ] Three sample lessons: one from track 1 (toolchain), 3 (functions), 4 (pointers)
- [ ] `make check` in learn/c/ regenerates every quoted output and diffs it (evidence rule)
- [ ] Lessons cite C23 sections (e.g. §6.5.7) against N3220
- [ ] Test in the container, then in the VM

### Later
- [ ] Phase 1: tracks 1–4
- [ ] Phase 2: tracks 5–8 + vikix-tutor skill (Super+a in a lesson folder)
- [ ] Phase 3: tracks 9–12 + capstones (Forth in C, tiny Lisp in C, vikix-battery in C)
- [ ] Reuse the runner for other languages: learn lisp / forth / haskell / sql

### Reference
- N3220 (C23), N1570 (C11), N1256 (C99): open-std.org/jtc1/sc22/wg14/www/docs/
- cppreference.com, C section: topic by topic, marks what changed in each version
- Bottom-Up C findings (14 measured surprises) → lesson material

## To look into

1. **The lock screen once showed the desktop in the VM.** On 2026-09-27 xss-lock's `i3lock` had been running for two hours in `void-vm` (picom on xrender with the 0.23.0 starter), yet screenshots showed the desktop, with the bar's clock stale, and rofi couldn't grab the keyboard. A fresh lock covered the screen in every test afterwards: with and without picom, after a notification, a new window, StumpWM rearranging, a dark screen and rofi. A second clue the same day: a picom that had run for a while in the VM stopped showing newly opened windows (rofi's area showed the wallpaper) until it was restarted, and a fresh picom was fine. So the likelier story is picom showing a stale frame, not windows above the lock; the X screen under it may well have been locked. Still to find: what makes picom stop repainting in the VM (long idle with vsync? the screen going dark for real?), and whether it ever happens on real hardware. A pen-tester review in the VM, left locked through a long idle, would settle it. Later that day, testing Lazarus (Qt5) in the VM: its newly opened windows were often left unpainted by picom (xrender), though StumpWM had them and they showed at once without picom or after restarting it; rofi was always fine. Turning off open/close fading helped once and not the second time, so that isn't it. Since then the picom starter never fades i3lock, so a lock screen can't be caught half faded in. Next to try: `use-damage = false` in the picom starter, the usual fix for picom's xrender backend in VMs, where partial repaints get missed; then see if the stale frames stop.
2. **A newly plugged screen stays dark until a layout is saved.** autorandr's udev rule runs `autorandr --batch --change --default default` on every plug. With no saved profiles, and no `default`, it does nothing: on 2026-09-28 a TV on HDMI was detected (`xrandr` said connected) but never turned on. Nothing tells the user to save a layout with Super+m. Options: fall back to a virtual profile (`--default horizontal`, which puts new screens to the right at their preferred mode) in both the udev path and vikix-session, if autorandr accepts virtual profiles there. Or `vikix doctor` and the docs could point to the save-layout entry. Careful with the preferred mode: a 4K TV on this X1's HDMI 1.4 port gets 4K@30, and 1080p60 is nicer. Also, udev's rule is autorandr's own (/usr/lib/udev/rules.d/40-monitor-hotplug.rules), so a different default means Vikix shipping its own rule in /etc/udev/rules.d.
3. **Local models on Intel graphics.** `vikix ai setup` keeps Ollama's Vulkan library (lib/ollama/vulkan). Try it on this X1's Intel graphics (OLLAMA_VULKAN=1, if that's still how it's switched on), and measure: faster than the CPU for 3-4B models? If so, a setting for it. llama.cpp built with Vulkan is the other route.
4. **Updates an agent can't forge.** The pen-tester's first finding on the agents (2026-09-28): an agent with the SSH agent could push to github.com/vukini/vikix, and `vikix update` pulls `main` unchecked, then runs stages with sudo, on every machine. 0.51.1 keeps the SSH agent from agents; still to do: `vikix update` pulls only signed tags (git verify-tag against a key shipped in the checkout), and the push key loaded with `ssh-add -c` (confirm each use) or kept out of the session's agent. Also from that review: installers pinned where the projects allow (OpenCode's comes from a moving branch, npm and uv take `@latest`), and checksums from somewhere other than the download's own host.
5. **An agent's notifications.** From the MCP pen-test (2026-09-29): a rate limit on the MCP notify tool. (Notifications over the lock screen: done in 0.70.0, vikix-lock pauses dunst while locked.) Also: `vikix doctor` could say when the MCP server is registered with --allow-eval.
6. **Why the docked Lazarus IDE fails to build.** Found by the everyday-user review of 2026-09-29: every update ended "the docked Lazarus IDE didn't build". Since 0.70.0 a failed build is remembered and tried again only when Void's Lazarus or the recipe changes, so updates no longer spend minutes on it. Still to find: the cause, in `~/.local/state/vikix/logs/lazarus-build.log` on the laptop.
7. **Audacity back into the feature video.** Left out in 0.66.0: Void's audacity-3.7.8_1 won't start against wxWidgets-gtk3-3.2.11_1 (`undefined symbol: _ZN12wxWindowBase14RegisterHotKeyEiii`, an ABI mismatch, so stubbing the symbol only moves the crash). When Void rebuilds either (a new `_N`), check `/usr/bin/audacity` starts, then put it back in `packages/optional/video.list`, its Super+m → Apps entry in `*vikix-apps-menu*`, and the README row and the feature's line.
