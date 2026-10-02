# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0. The editors (Neovim into Vikix, AI in Neovim and Emacs) have their own list: `TODO-editors.md`.

## Features

Built in this order: newcomers first, then the rest (the AI items have shipped; more are in the wish list). Package facts were checked against void-packages on 2026-09-28. In Void: uv, espeak-ng, podman, tesseract-ocr, xcolor. Not in Void: ollama, llama.cpp, whisper.cpp, aichat, llm, piper-tts ("piper" in Void is a gaming-mouse tool). Those come from their official releases, uv, or a source build in the style of 65-languages: pinned, checksummed where the project publishes checksums, and in ~/.local.

### And then

64. **Esploro becomes Vikix's file explorer** (decided with Vid 2026-10-02). The plan is in Esploro's DESIGN.md ("Becoming Vikix's file explorer"); first the window's toolkit, McCLIM or Emacs, measured there (dired: 1-2 ms a key at 20,000 files; McCLIM: 44 ms a key with none, 7 s at 20,000). Then, on Vikix's side, once Esploro does the everyday things: Super+e, `inode/directory` in `config/xdg/mimeapps.list`, `--file-manager` in `bin/vikix-drives`, org.freedesktop.FileManager1 for "Show in folder"; from the feature `esploro` into the base install with a migration, PCManFM kept as the fallback for a release or two; the key card, the guides, `vikix doctor`.
6. **Whole-system undo.** When / is btrfs: snapper snapshots before each `vikix update`, and `vikix rollback` notes. Skip cleanly on ext4.
9. **Tutorials: `vikix learn c`, Phase 2.** Paused until Vid has worked through some lessons (see TUTORIALS.md, "Where it stands"). Tracks 1 to 4 (fourteen lessons) shipped in 0.71.22. Next: tracks 5 to 8 (where everything lives, the heap, strings, structs) and the tutor skill. The plan and the decisions are in `TUTORIALS.md`; `learn/outputs.py --fill` writes a lesson's quoted outputs from real runs.

## Wish list

Added 2026-09-30, from a conversation with Vid about 0.52-0.65. Not yet ordered against the list above, and no package names checked against void-packages yet: check each before building, as for the features above. Numbered on from 10.

### AI, more

12. **A cloud model for `vikix ai use`.** Beside `local` and `claude`, `cloud`: any OpenAI-compatible address, a key from `vikix ai key`, and a model name, with OpenRouter as the ready-made default (one key, hundreds of models, pay per use). `s-i`, `llm`, gptel, Neovim's AI and the agents' `--local`-style switch all follow it. The docs say plainly that the text goes to that service and its model host.
13. **Hermes Agent (Nous Research), as an agent.** `vikix agent --use hermes`, a feature, installed from the official https://hermes-agent.nousresearch.com (hermes-agent.org is a third party), into `~/.hermes` with uv. It reads `AGENTS.md`, so the guide works as it is. The same rules as the other agents: the snapshot first, no SSH agent, installers downloaded whole. To solve: Hermes keeps its keys in `~/.hermes/.env`; give it only the one it needs. Its terminal agent adds little beside the five; the value is item 14.
14. **Hermes's gateway, later.** Talking to the agent from Telegram, WhatsApp or Signal, and its scheduled jobs. A door into the machine, so: an allow-list of senders, Hermes's Docker backend for commands, a bar note while it runs (`hermes`), and a snapshot on a timer instead of per session. On a laptop it stops when the lid closes; the always-on version is Hermes on a small cloud server reaching the laptop over Tailscale (item 16). Needs a design first.
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
28. **Teams and Zoom as web app presets,** beside the mail ones.

### The desktop

29. **Save and restore layouts.** `vikix layout save writing`: which windows sit where on a workspace; restoring brings the workspace back for a project.
30. **A drop-down terminal** on Super+`, over whatever is open.
31. **Find any file.** A rofi search over the home folder (plocate or fd), as fast as typing.
32. **Battery care on ThinkPads.** tlp's charge thresholds: stop at 80% while docked; a Super+m entry to charge to 100% before a trip.

### Family

33. **A children's account.** A second login with a simpler desktop and apps chosen by the parent, where nothing of the parent's can be broken; a home for a child's programming course.

### Plugins, themes and wallpapers (decided with Vid 2026-09-30)

Three new repos beside Vikix, each independent: `vukini/vikix-plugins`, `vukini/vikix-themes`, and the wallpapers, done as `vukini/wallpapers` (`vikix add wallpapers`; still to do there: a `CREDITS` file, and Git LFS or release archives if the clone gets slow). The core keeps what a fresh install needs offline: void and paper and their two wallpapers. Every plugin offered is Vid's own for now; opening the repo to others' plugins comes later.

34. **A plugin system.** A plugin is a folder: a manifest (name, one-line description, kinds, packages it needs, the Vikix version it works with) and its code, Lisp with StumpWM's full power, and shell where that's simpler. Kinds to start: **bar** (a few words in the bar on a timer, with a click or key action), **menu** (entries in Super+m), **key** (bindings, through `vikix-bind`, in the key help), **service** (started at login). Commands: `vikix plugin list` (available, and yours), `vikix plugin add NAME` (shows what it runs and needs, asks, installs its packages), `remove`, and `vikix update` updates them. The code is Vikix's (`~/.local/share/vikix/plugins/NAME`, updated), the settings are yours (`~/.config/vikix/plugins/NAME`, copied once). Each plugin is pinned to a reviewed commit, so an update can't swap code in silently. Because Lisp plugins run inside StumpWM: load each wrapped, as the layer files are, so a broken one is reported and skipped; a hung one needs a way out, so `vikix plugin off NAME` works from a TTY and a safe-mode login loads none. `vikix doctor` lists them; `vikix debug` names them. A test in the plugins repo's CI: every manifest valid, every Lisp file reads, every shell script passes lint.
35. **`vikix-themes`.** A folder per theme: the `.theme` file, its wallpaper, a preview in void and paper sizes. `vikix theme get NAME`, or `vikix add themes` for all; the picker lists them. Item 5's "more themes" (Gruvbox, Nord, Tokyo Night, a high-contrast one) are made here, not in the core.

The first plugins, in order:

37. **Agent waiting** (after Omarchy's `herdr`). When an agent in a background window stops for your answer, the bar says `agent waiting`, and a key jumps to that window. Claude Code's hooks can report it; the others by watching their terminals.
38. **Notes from anywhere.** A key opens a small capture box over whatever you're doing: type, dictate (the Super+F9 dictation), or take the selection, with the window's title or the page's address added as the source. It lands at once as a dated heading in the Org inbox, `~/Dropbox/notes/inbox.org` (item 54), through org-capture, so the phones see it too. Then, only when asked: `vikix notes sort` has a model read the inbox and refile each note under a project or category (the notes' Org files and headings, or a list in the settings), showing its choices first; local model by default. Later: a note's to-dos into Todoist, and a daily digest of what was captured.
39. **Flights** (after Omarchy's most-starred plugin, LetsFG Flights). Search from a prompt ("DXB to LHR, 12 Nov, back 20th"), cheapest and quickest in a rofi list, the chosen one opened in the browser; watched routes, with a notification when the price drops. LetsFG (MIT, CLI and MCP) does the search, but asks for a payment method even to search, and can book: the plugin searches only, and booking stays in the browser, never done by an agent. Check its terms, and look for a search source that needs no card.
40. **AI usage.** How much of the Claude plan this session has used, and when it resets, in the bar.
41. **Next meeting.** The next meeting and how long until it starts, in the bar; a key opens its call link; a rofi list for the week.
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
48. **Moving in, safely.** Nothing is deleted from the vault until each project is checked in its new home.
    - An inventory first: per project, what is source, what is built, what is an asset, what is leftover (`_to_delete`, empty folders, `plenejo`), shown to Vid before anything moves.
    - One commit per project. `living-in-the-image` keeps its history (git subtree). The Progress, Plan and Findings docs come from the claude.ai project into each folder; the Work Log and Status Board databases are exported into each `project.org`.
    - Then every project's build and check run on Vikix; a list of what fails, fixed project by project.
    - Switch-over: the laptop clones to `~/living` (outside the vault); the vault's `Living-in-Life` becomes read-only, then archived once all is verified.
49. **In Vikix: projects, generally.** `vikix project` for any folder with a `project.org`: `list` (last log line, next step, % done), `open NAME` (its saved layout, the editor on its Progress doc, a terminal there, a preview, the agent: IDEAS' project switcher, made real), `log NAME "…"`, `check`, `build`, and `vikix today` (IDEAS) from the logs and commits. Plain files, so Claude sessions, Emacs and scripts all read and write the same log.
50. **The `living` plugin (Vid's own).** The series-specific layer on item 49: `living` (the dashboard), `living open lambda`, `living log`, `living shelf` (the Living Shelf page built from the `project.org` files), and a bar note for the project in hand. It uses the plugin system (item 34).
51. **The online views.** The Work Log, Status Board and Living Shelf pages on claude.ai regenerated from the repo, not typed into by hand: at the end of a Claude session that changed the log, and by a daily scheduled cloud task reading the repo. The repo is the truth; the pages are for reading anywhere.
52. **Reading on the phone.** The GitHub app shows the private repo as it is (Markdown and Org both render; nothing to set up, read-only); the online views (item 51) for status at a glance. Notes and quick capture on the phones go through the Org notes in Dropbox (item 54), not the repo. Obsidian is no longer part of this (item 53).

## Org instead of Obsidian (decided with Vid 2026-09-30)

Obsidian is retired. Vid used it to view, organise and quickly capture notes, synced to Android, iPhone, Linux, Windows and Mac. Org takes its place: plain text that is also a tree of data a Lisp can read, so the desktop (StumpWM), the editor (Emacs), the notes and the agents are one Lisp system. Editing is in Emacs; the phones use Org apps; Dropbox syncs, because it is the one method both phone apps share.

53. **Obsidian, retired in stages.** It keeps working in parallel until the phones have proven themselves for a few weeks; then the vault is archived (read-only, in `vikix backup`), not deleted. The Living Series leaves it through items 47–52; everything else through item 55.
54. **The notes: Org files in `~/Dropbox/notes`.** A feature, `vikix add notes` (with `dropbox`): the folder, a starter layout (`inbox.org`, a file per area, `journal/`), and in Emacs org-capture templates (on a key from anywhere, through the notes plugin, item 38), the agenda over all of it, and org-roam for links, backlinks and a graph as Obsidian had. Windows and Mac: Emacs and Dropbox, the same files.
    - **History without breaking sync:** no `.git` inside Dropbox (the two fight over the same files and can corrupt the repo). A timer copies `~/Dropbox/notes` into a private repo outside Dropbox, `~/notes-history`, and commits hourly, so every version can be restored; `vikix backup` covers both.
    - **Conflicts:** an edit on a phone and the laptop before they sync leaves a Dropbox "conflicted copy"; `vikix doctor` and a bar note point them out, and a command shows the two side by side.
55. **Converting the vault.** Pandoc turns Markdown into Org, links included; a script does the vault a folder at a time, keeps attachments beside the notes, and reports what didn't convert cleanly (Obsidian-only syntax such as embeds and callouts). The general Common Lisp notes and the rest move this way; nothing is removed from the vault until its Org copy has been checked.
56. **The phones.** Android: Orgzly Revived, syncing `~/Dropbox/notes` over Dropbox. iPhone: beorg, the same over Dropbox. A short guide page in `docs/` for setting each up, with which files to sync (not the history repo), and what each app can and can't do (reading, capture, ticking tasks, the agenda: yes; org-roam's graph: laptop only).
57. **Notes an agent can query.** Emacs reads Org as a tree (org-element; org-ql for queries), so an agent working through Emacs asks exact questions ("projects under 50%", "notes tagged vikix this week", "open TODOs for Link") instead of searching text. Exposed to the agents through the checked-Lisp route (IDEAS: Leaning into Lisp) and the MCP server; read-only by default, edits shown before they're made.

## The ROG Flow Z13 (bought 2026-09-30)

Vid's new laptop, bought for AI on the machine itself: an ASUS ROG Flow Z13 (2025), model GZ302EA-XS99. AMD Ryzen AI Max+ 395, 128 GB of memory shared by the processor and the graphics, a 13.4" 2560×1600 touch screen, a detachable keyboard. Most of this can only be finished with it in hand.

58. **Void and Vikix on it.** Install from the glibc image and write down what works on Void's kernel: Wi-Fi 7 (MediaTek), the speakers (CS35L41 amplifiers, which need their firmware), the camera, the fingerprint reader, suspend, the battery. What needs a fix becomes item 59; the findings go in a hardware page in `docs/`.
59. **A Z13 profile in `55-hardware`**, chosen by the model name (DMI: GZ302). The detachable keyboard wakes it from suspend when folded shut: switch off that USB device's wake-up, through an elogind sleep hook. `Xft.dpi` for its screen (about 225 pixels an inch). ASUS's fan and power modes and the keyboard light with asusctl, if Void packages it. Touch works in X; turning the screen round by hand from Super+m, and turning it by itself (iio-sensor-proxy) later.
60. **Most of the memory for AI.** On this chip Linux lets the graphics use only part of the memory at first (about 96 of 128 GB). Kernel settings (the TTM page limit) raise it to about 120 GB, which Qwen3-235B needs. `vikix ai setup` offers it on any Ryzen AI Max machine, asking first, since it changes how the machine boots.
61. **Ollama on its graphics.** Vulkan (the library `vikix ai setup` already keeps) against ROCm, measured with gpt-oss-120b. The picker in `vikix ai models` learns the 128 GB tier: gpt-oss-120b (about 63 GB, 34-56 tokens a second: the default), Nemotron 3 Super 120B for coding agents, Qwen3-235B after item 60. Its memory rule counts memory the graphics share.
62. **Local by default for private work.** Notes (`note ask`), Super+i and the desk (item 21) on gpt-oss-120b, with nothing leaving the laptop; Claude for coding Vikix and the Living Series' core work (the explanations, code, measured findings). Try gpt-oss-120b on Esperanto and Toki Pona passages Vid knows well before using it on those books.
63. **Quiet or full power.** A Super+m choice between quiet (battery, fans down) and full power for long AI jobs (asusctl's profiles, or the kernel's platform_profile), with the bar saying which.

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
