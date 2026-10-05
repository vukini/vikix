# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0. The editors (Neovim into Vikix, AI in Neovim and Emacs) have their own list: `TODO-editors.md`.

## What's next, in order (drawn up with Vid 2026-10-03)

From a review of 0.71.71 against one aim: the best desktop for a power user. Vikix has no users but Vid yet, so what only matters once others arrive (a promise about what won't change, opening the plugin repo, signed updates, items 19 and 20) waits for the first of them. Until then, in this order:

1. ~~**The rules language.**~~ Done: the rules, `vikix rules`, remembering a window, the move over, the guide. What follows it is the next section.
2. **Saved layouts**: by hand (`vikix layout save NAME`, `vikix layout NAME`) and by a rule (`(layout "writing")`) are in (`layouts.lisp`, plain Lisp files as IDEAS' "Layouts as plain Lisp" had it). `vikix project open` saving (on leaving its workspace) and putting back a project's layout is in too (50a). Starting the windows a layout names that aren't open, and placing them as they come, is in too. Left: nothing planned; what living with it shows. The whole session back after a restart is in too (`resume.lisp`, `vikix resume`): every workspace saved by itself, and brought back at login. Left from it: Claude sessions resumed as the conversations they were (they come back as terminals in their folders), and floating windows.
3. **A desktop to trust for weeks.** Signed updates (To look into, 4) are what's left, and wait for the first outside user (Vid, 2026-10-04: not while he is the only one). The times are measured and tested (`vikix times`, `tests/times.sh`: login, a reload, a key to its command, an Emacs frame, StumpWM answering, and a tiled xterm), and the soak test is in (`vikix times soak`, an hour on a hidden screen, weekly after asking; `tests/soak.sh` a minute of it); not on GitHub, whose runners have no screen. Reloads and logins load the layer from compiled copies made in the background (a reload went from 2.2 s to under half a second on a hidden screen), and the bar's programs run in a thread of their own, which had held the main thread a quarter of a second every ten, four seconds once. A way out when it is stuck is in too: a watcher that notices the main thread going round and round and frees it, Super+Ctrl+Alt+Escape read apart from StumpWM's keys, `vikix rescue`, and the lock screen kept in front of the windows (`rescue.lisp`, `docs/fixing.md`). Not found, from 2026-10-05: why `gmerge` from a strip left windows floating, and what kept the main thread busy after the focus stopped moving; the watcher's report will say next time.
4. **Agents that act through code you can check first** (IDEAS, Leaning into Lisp), then the time machine for functions. The rules language's verbs (`*vikix-rule-verbs*`, `rules.lisp`) are the first entries of its allow-list.
5. **In between, as polish:** `bugs.md`. Done: a newly plugged screen lighting up by itself (Super+Ctrl+p for the rest), GTK and Qt programs following `vikix theme`, and a tray that can be switched on (`vikix tray on`).
   Also in, from a second look on 2026-10-05: one box for everything (the palette, Super+Space: windows, commands, projects, web apps, layouts and programs). Left from it: files and the docs as you type (the launcher's script mode lists once, so those want a different box), and the rules.
   And what gets used is counted (`vikix used`, `used.lisp`: keys, menu entries, palette picks, typed commands, rules, agents' commands; names and counts only, on this machine). And the agents' skill is a short first page and a page a subject (80 KB down to 15 for every session). Left from it: a count of which pages agents open would say whether the split is the right one. Left from the counts: after some weeks, look at `vikix used never` and decide which keys to give up or move (the key card is full); a count per day, if the totals turn out to hide what changed.
6. **Then the items picked from IDEAS** (the section below, 73 to 82), in their order.

## Offered next, and not started (Vid and Claude, 2026-10-05)

Left here before a restart; none is begun. In the order suggested:

- **Rules for more events** (the last line of the next section): a rule that fires when a screen is plugged in or taken away, a Wi-Fi network is joined, a drive is plugged in, or the laptop goes idle. "When I join VID, start Dropbox"; "when the TV is plugged in, this layout". Self-contained in `rules.lisp`.
- **The rules test, fast and steady** (`bugs.md`, "tests/rules.sh fails when the machine is very busy"): it took over five minutes a run on 2026-10-04 and every session's release waits on it. The next step is written there.
- **A focus timer in the bar** (item 77).
- **A Wi-Fi picker that scans first** (item 85 below), if the tray applet's list is still stale after its restart (`bugs.md`).
- The bigger one stays item 4 above, agents that act through code you can check first: `propose_rule` and `run_command` are its first slices; the next wants a short design before any code.

## After the rules language

The rules language is in: `when-window` and the timed rules (`rules.lisp`), `vikix rules`, remembering a window (Super+Shift+t), every hand-written window hook moved over, the guide (`docs/rules.md`) and the starter `rules.lisp`. What it leads to, each an item of its own when its turn comes:

- The apprentice's suggestions written as rules (IDEAS).
- The verbs table (`*vikix-rule-verbs*`) as the first entries of the allow-list for agents that act through code (What's next, 4). `propose_rule` (0.71.x) is its first use: `vikix-rule-proposal-check` in `rules.lisp` is the walker that lets through only rule forms, verbs and plain values.
- Rules for a screen plugged in or taken away, a Wi-Fi network joined, a drive plugged in, idle.

## Picked from IDEAS (with Vid 2026-10-04)

Moved here from `IDEAS.md` and the designs, in this order; 79 to 82 want a short design first (a `DESIGN-*.md`, or a section here), the rest are ready to start.

73. **The docs catalogue** (`DESIGN-docs.md`). Phase 0 is in (`vikix docs`, `bin/vikix-docs`): the catalogue over Vikix's guides, `~/src`, `~/dev`, the Org notes, man pages and Info manuals, FTS5 with Vikix's first, Super+F2, man pages as styled pages, `docs_search`/`docs_read` for the agents, `vikix docs get` for the old download. Also in: Markdown as styled pages, `pkgdoc` and `pkg` (packages and what they are), `vk` with prefixes and Tab. Also the page in Nyxt (`vikix docs page`, Super+m → *Every document as a page in Nyxt*): hits grouped by source with counts, Open and the other way. Still to do: P1 (Zeal, web links, PDFs, `vikix docs ask`, a watch on `~/src`).
76. **Nyxt commands, a batch of small ones** (IDEAS, "Nyxt: commands still to build"): **Tables → CSV**: Each `<table>` on the page into a CSV file, for a spreadsheet: `clss:select "table"`, rows and cells from the parsed copy. **Save the page's code blocks**: Every `<pre><code>` to files, or a prompt to pick one and copy it (the "send a block to a terminal" idea, done properly). **Add the page to `note`'s index**: , so `note ask` finds it beside your notes. **Reader view**: : the page's Markdown rendered back as a clean `nyxt:` page in the guide's style. **Jump to a heading**: : the page's headings as a Ctrl+Space source; pick one to scroll there. **Clip into a project's log**: : clip-selection's quote through `vikix project log NAME`, with a prompt for the project.
77. **A focus timer in the bar.** 25 or 50 minutes with do not disturb on by itself, then a break. Rules and the bar make it small.
79. **Publishing, `vikix add publish`** (design: `DESIGN-publish.md`). Phase 0 is in: the feature (Void's pandoc, Typst, Calibre, Sigil, IBM Plex, Amiri; epubcheck fetched as a pinned release on the `java` feature), `lib/publish/` (`build`, the `doc-to-epub` skill's `fix-tables.py` and `epub.css`, `publish.mk`), `vikix publish [NAME] [epub|pdf|check]`; Living in SQL builds an EPUB epubcheck passes and a PDF. Then of Phase 1, the spelling in `check` (hunspell, LibreOffice's `en_GB`, `eo` and `ar` pinned, passages by their `lang`, `words.txt`, `spell --keep`) and `--send` (a Kindle or Kobo as a drive, a BOOX over MTP or adb, `--to`). Also `vikix publish new`, and `vikix publish skill`, the cloud `doc-to-epub` skill made from the same files (Vid uploads it). Next: the `log.md` line, and a link check.
80. **Any file, as it was** (design: `DESIGN-restore.md`, 2026-10-04; touches Esploro's repo). `vikix backup` runs restic; Esploro gets a right-click "Versions…" listing a file's snapshots by date, restoring one as a plan with undo. Time Machine's best feature inside the file explorer, with Esploro's review in front of it.
81. **The outbound ledger** (design first; its place in `DESIGN-security.md`, item 8). One page: everything that left the laptop today, by program. Claude calls (`vikix mcp status` and `llm logs` already know), package fetches, Dropbox, the agents. The site says "nothing left the laptop" in several places; a ledger lets anyone check.
82. **Windows programs in their own windows, through RemoteApp** (design: `DESIGN-remoteapp.md`, 2026-10-04). Built, with stand-ins: `vikix windows apps setup` (FreeRDP, RemoteApp switched on through the guest agent, the password kept, `~/Documents` as `Y:`), `vikix windows apps` (the Start menu), `apps add`, `vikix windows app NAME [FILE]`; `tests/winapps.sh`. First real target: FACTS, the company ERP: it opens as a window of its own and reaches its server (2026-10-05). What's left is in `TODO-Windows.md`.

## Features

Built in this order: newcomers first, then the rest (the AI items have shipped; more are in the wish list). Package facts were checked against void-packages on 2026-09-28. In Void: uv, espeak-ng, podman, tesseract-ocr, xcolor. Not in Void: ollama, llama.cpp, whisper.cpp, aichat, llm, piper-tts ("piper" in Void is a gaming-mouse tool). Those come from their official releases, uv, or a source build in the style of 65-languages: pinned, checksummed where the project publishes checksums, and in ~/.local.

### And then

72. **Viri, a workspace that scrolls sideways** (`DESIGN-viri.md`; Phase 0 in, `vikix viri`). The drawn overview (0.71.130), sliding and centring (0.71.135) and the mouse (0.71.144) are in: the design's P0 and P1 are done. Past the design: the ends and a pinned column (0.71.156); tabbed columns (0.71.159); uneven heights (0.71.163); fill the rest (0.71.168); a whole column to another workspace (0.71.174); a sliver of the neighbours (0.71.177); a touchpad swipe (0.71.179), two fingers too (0.71.180); idea still open: a minimap in the bar. Left, P2: a touchscreen pan, a strip across two monitors, the lesson. Firefox off the screen's edge: watch whether it throttles.
64. **Esploro becomes Vikix's file explorer** (decided with Vid 2026-10-02). The plan is in Esploro's DESIGN.md ("Becoming Vikix's file explorer"). The window is Emacs (measured there: dired 1-2 ms a key at 20,000 files, McCLIM 44 ms with none and 7 s at 20,000; McCLIM kept on Esploro's `mcclim` branch), with menus, the mouse and drag and drop, and step 1 is in (0.71.x). Step 2 is in too: Super+e, folders by default (set over PCManFM only), drives through `xdg-open`, and "Show in folder" (org.freedesktop.FileManager1). Not done, on purpose: moving it into the base install, since it needs Emacs, which is a feature of its own; PCManFM stays the base's, and Super+Alt+e. `vikix doctor` says whether it's built at the pin and answering (`vikix esploro doctor`).
6. **Whole-system undo.** When / is btrfs: snapper snapshots before each `vikix update`, and `vikix rollback` notes. Skip cleanly on ext4.
9. **Tutorials: `vikix learn c`, Phase 2.** Paused until Vid has worked through some lessons (see TUTORIALS.md, "Where it stands"). Tracks 1 to 4 (fourteen lessons) shipped in 0.71.22. Next: tracks 5 to 8 (where everything lives, the heap, strings, structs) and the tutor skill. The plan and the decisions are in `TUTORIALS.md`; `learn/outputs.py --fill` writes a lesson's quoted outputs from real runs.

## Wish list

Added 2026-09-30, from a conversation with Vid about 0.52-0.65. Not yet ordered against the list above, and no package names checked against void-packages yet: check each before building, as for the features above. Numbered on from 10.

### AI, more

12. **A cloud model for `vikix ai use`.** Beside `local` and `claude`, `cloud`: any OpenAI-compatible address, a key from `vikix ai key`, and a model name, with OpenRouter as the ready-made default (one key, hundreds of models, pay per use). `s-i`, `llm`, gptel, Neovim's AI and the agents' `--local`-style switch all follow it. The docs say plainly that the text goes to that service and its model host.
15. **Your own model in the cloud: a guide.** Serverless GPUs (RunPod, Modal: pay per second, a minute or two to wake), a GPU rented by the hour (RunPod, Vast.ai, Lambda), and OpenRouter, compared on cost and privacy; which model sizes fit which cards at Hermes's 64k context; then pointing `vikix ai use cloud` at your own endpoint. Probably a docs page, not code.

### Your machines and your phone

16. **Tailscale as a feature** (design: `DESIGN-machines.md`, 2026-10-04). A private network between your own devices: the safe way for a phone or a server to reach the laptop, never SSH open to the internet.
17. **Syncthing as a feature** (design: `DESIGN-machines.md`, 2026-10-04). Folders (an Obsidian vault, say) kept in step between machines directly, no cloud; a bar note while it syncs.
18. **KDE Connect** (design: `DESIGN-machines.md`, 2026-10-04). Phone notifications on the desktop, files both ways, the phone as a remote.
19. **`vikix export` / `vikix import`** (design: `DESIGN-machines.md`, 2026-10-04). One file with your features, theme, keyboard, web apps and settings (no secrets), so a new machine becomes yours in one step.
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

30. **A drop-down terminal** on Super+`, over whatever is open.
31. **Find any file.** A rofi search over the home folder (plocate or fd), as fast as typing.
32. **Battery care on ThinkPads.** tlp's charge thresholds: stop at 80% while docked; a Super+m entry to charge to 100% before a trip.
83. **Another terminal, all the way** (good to have, not urgent; Vid 2026-10-04: it can wait for the first user who asks). Today `(setf *vikix-terminal* "kitty")` moves Super+Return and the menu's entries, and `vikix theme` writes kitty's colours (the `include` line added by hand); the rest stays on Alacritty.
85. **A Wi-Fi picker that scans first** (Vid asked on 2026-10-05 how to make the system scan again; the tray applet's list looked stale). Today the bar's Wi-Fi field opens `nmtui`, and with the tray on it is nm-applet's menu: neither has a "scan again", and the field itself only reads what NetworkManager already knows (`nmcli ... --rescan no`). A rofi list in Vikix's style: `nmcli device wifi rescan` first, then each network with its signal and whether it's known, the one in use marked, "Scan again" as an entry, Enter joins (a saved one at once, a new one asks its password), and `nmtui` still there for the rest. On a click on the bar's field, a Super+m entry, and `vikix wifi`.
    - **One setting.** `vikix terminal NAME` writes `~/.config/vikix/terminal`, read by StumpWM and by the shell commands alike. Now there are two that don't know of each other: `*vikix-terminal*`, and `$VIKIX_TERMINAL`, which nothing sets, so `vikix-ask`, `vikix-voice`, `vikix-local-ai` and `vikix project open` open Alacritty whatever the first says.
    - **One launcher.** `vikix-term [--class C] [--dir D] [-e CMD...]`, turning those into each terminal's own flags; every place that builds a terminal's command line calls it (`commands.lisp`, `modeline.lisp`, the four commands above). `--class` is what differs: `vikix learn`'s panes and the voice agent's window pass it as Alacritty takes it, and the rules match on it. Check each terminal's form before building (Ghostty's and WezTerm's weren't tested).
    - **Three kept working:** Alacritty (the default), Kitty and Ghostty, each a feature (`vikix add kitty`) with a theme file from `vikix theme`, a starter config that includes it (Iosevka, the same size), and open windows repainted. Any other terminal goes through the launcher's plain `-e`, without theme or class. Foot is Wayland only: not offered.
    - **The lists of terminals:** Ghostty into `*vikix-layout-terminals*` (`layouts.lisp`) and `own_window` (`bin/vikix-agent`), or both from one list.
    - **`vikix doctor`** checks the chosen terminal, not `alacritty` by name; Alacritty stays in `desktop.list` as the one that's always there.
    - Vid's `user.lisp` names Alacritty for the drop-down terminal and passes `--class` for nmtui: both move to the launcher, with Vid.

84. **The Living Series site** (design: `DESIGN-site.md`, 2026-10-04; mostly the Living Series repo's work, Vikix's part is `vikix publish` and the doors). Substack's successor on thelivingseries.com, with theliving.codes and theliving.studio beside it: static pages from `vikix publish` on Cloudflare, a small Lisp gate on a Debian server at Hetzner for purchases, logins and stamped downloads, Listmonk for the list, a fan-out from the feed to the list and the social feeds, a merchant of record for the till. Vikix gains `vikix publish hub|post|book|--draft`, `vikix doctor --on web`, and the droplet as a tailnet machine (TODO 16).

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
2. ~~**A newly plugged screen stays dark until a layout is saved.**~~ Done (`vikix-screens`, autorandr's predetect hook, StumpWM following RANDR's screen changes, Super+Ctrl+p). To try for real: a screen not seen before (the M80C has no saved layout yet), and unplugging.
3. **Local models on Intel graphics.** `vikix ai setup` keeps Ollama's Vulkan library (lib/ollama/vulkan). Try it on this X1's Intel graphics (OLLAMA_VULKAN=1, if that's still how it's switched on), and measure: faster than the CPU for 3-4B models? If so, a setting for it. llama.cpp built with Vulkan is the other route.
4. **Updates an agent can't forge** (plan: `DESIGN-security.md`, items 1 and 2). The pen-tester's first finding on the agents (2026-09-28): an agent with the SSH agent could push to github.com/vukini/vikix, and `vikix update` pulls `main` unchecked, then runs stages with sudo, on every machine. 0.51.1 keeps the SSH agent from agents; still to do: `vikix update` pulls only signed tags (git verify-tag against a key shipped in the checkout), and the push key loaded with `ssh-add -c` (confirm each use) or kept out of the session's agent. Also from that review: installers pinned where the projects allow (OpenCode's comes from a moving branch, npm and uv take `@latest`), and checksums from somewhere other than the download's own host.
5. **An agent's notifications** (plan: `DESIGN-security.md`, item 6). From the MCP pen-test (2026-09-29): a rate limit on the MCP notify tool. (Notifications over the lock screen: done in 0.70.0, vikix-lock pauses dunst while locked.) Also: `vikix doctor` could say when the MCP server is registered with --allow-eval.
6. **Why the docked Lazarus IDE fails to build.** Found by the everyday-user review of 2026-09-29: every update ended "the docked Lazarus IDE didn't build". Since 0.70.0 a failed build is remembered and tried again only when Void's Lazarus or the recipe changes, so updates no longer spend minutes on it. Still to find: the cause, in `~/.local/state/vikix/logs/lazarus-build.log` on the laptop.
7. **Audacity back into the feature video.** Left out in 0.66.0: Void's audacity-3.7.8_1 won't start against wxWidgets-gtk3-3.2.11_1 (`undefined symbol: _ZN12wxWindowBase14RegisterHotKeyEiii`, an ABI mismatch, so stubbing the symbol only moves the crash). When Void rebuilds either (a new `_N`), check `/usr/bin/audacity` starts, then put it back in `packages/optional/video.list`, its Super+m → Apps entry in `*vikix-apps-menu*`, and the README row and the feature's line.
