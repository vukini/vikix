# Ideas

Ideas for Vikix that nobody has decided to build yet. When one is picked up, it moves to `TODO.md` (worked out properly there: what, why, what it touches) and is deleted from here. Nothing here is a promise, and no package name here has been checked against void-packages.

Gathered on 2026-09-30, in a conversation with Vid.

## Software Void doesn't have

- **Flatpak as a feature.** The easy route to apps Void doesn't package (Obsidian, Zoom, Spotify, Signal), each somewhat walled off from the rest of the system. `vikix update` would update them too.
- **Distrobox.** An Ubuntu or Arch system inside Vikix, sharing the home folder, for anything that only ships as a .deb or for Arch. The safety net.

## Working on projects

- **Per-project settings with direnv.** Entering a project's folder sets its tools and settings; leaving undoes them.

## AI

- **Ask about the screen.** Drag over any area (a chart, an error dialog, a PDF page) and ask about it: `s-i` for pictures, with a vision model.
- **Voice commands.** Hold a key and say "put Firefox on workspace 3" or "open the Vikix project": the dictation already there, then the agent acting through the MCP server.
- **Meeting notes.** Record a call, transcribe it locally, then a summary and action items. Only with everyone's consent, and the screen says a recording is running.
- **Jev (TypeSafe AI), for typed decisions.** A cloud API that answers with one of a fixed set of choices and how sure it is (not text), claimed in 70-500 ms and nearly free: https://typesafe.ai/blog/introducing-system-one-models-and-jev. Compare it with a local model held to a JSON schema (Ollama's structured outputs) when the desk's mail groups (TODO item 21), `vikix notes sort` (item 38) or voice commands are built. Against it, as seen 2026-10-02: cloud only and closed, early access, its own benchmarks, and business mail is local by default; "can't hallucinate" only means the answer is always an allowed choice, not the right one.

## Everyday business

- **Text snippets.** `;addr` becomes your address, `;thanks` a standard reply (espanso or similar), for the email you write over and over.
- **A scanner.** SANE and simple-scan, scanning straight into the desk's documents inbox (wish list: the desk), with the text read by OCR on the way in.

## Focus

- **A focus timer in the bar.** 25 or 50 minutes with do not disturb on by itself, then a break.
- **Where did my time go.** Time per app and per project, recorded automatically and kept only on this machine; the children's screen-time plugin could use the same record.

## Presenting

- **Draw on the screen** during a talk (gromit-mpx), to go with Hype (in `TODO.md`).
- **OBS as a feature,** for recording or streaming lessons.

## Languages

- **Vikix in Esperanto.** Menus, messages, the welcome and the key help in Esperanto, then other languages: translations kept in files beside the code.
- **Arabic done properly.** Good Arabic fonts, and right-to-left text shown correctly in the terminal and the editors.

## For the children

- **An education bundle** for the children's account (wish list: a children's account): GCompris, Tux Paint, a typing tutor, Scratch.

## Inventions: things other desktops don't do

Vikix can try these because the whole desktop is a live Lisp program, it already keeps the shell history (atuin) and the history of your files (snapshots), and it has local AI.

- **The apprentice: a desktop that learns your habits.** It watches how you work, notices what you repeat, and offers to automate it.
    - **From the shell history:** sequences you repeat (`cd` to a repo, `git pull`, `vikix update` → one command, with a name); long commands retyped often (→ an alias); commands that fail and are rerun fixed (with `sudo`, a typo corrected: it learns the fix); daily habits with a faster way (a flag or a tool you didn't know).
    - **From the desktop, which only Vikix can see:** StumpWM records which keys, commands and menu entries are used. "You open Firefox and move it to workspace 2 every morning" → a window rule. "You clicked the launcher 20 times this week" → Super+d. "These five keys are never used" → offered for things you do.
    - **How it offers:** a short weekly digest, not pop-ups. Each suggestion shows exactly what it would add (an alias, a function, a key in `user.lisp`) with a one-key yes; every yes is a snapshot first, so `vikix undo` takes it back.
    - **How it's built:** the patterns are plain counting, no AI; a model only names and explains a suggestion. History is private and holds secrets typed by accident: a local model only, and the secrets scrubbed first, as `vikix debug` does.
- **"Where was I?"** Back at the laptop after a break, a lock or a meeting: a small card with the project you were in, the last commands, open files with unsaved changes, and the last note captured. For someone who juggles many projects.
- **Learn Lisp by changing your own desktop.** A `vikix learn` course where each lesson changes the running desktop: a key that tells the time, the bar's colours, your first StumpWM command. The desktop is the teaching tool. A companion to the Common Lisp books.
- **A readable history of your settings.** Each snapshot gets a one-line plain-English description ("added a key for the calculator"), written by a model from the diff, so `vikix history` reads like a diary of how the machine was shaped, and undoing the right thing is easy.
- **"Find that thing I saw."** Optionally, a screenshot every few minutes, kept only on this machine and encrypted, its text made searchable ("the error this morning", "that price yesterday"): a private, local Recall. Off by default, paused with one key, never taking password windows or the lock screen, old ones deleted by themselves.
- **"Explain what just went wrong."** One key, right after a command fails: the error and the recent commands are read, explained, and the fix offered, run only if you say so.

## Leaning into Lisp

Ideas that work only because the desktop is a running Lisp program you can inspect, change and question while it runs. Vid's favourites to start with were three, which make Vikix safer and easier to shape, each a real reason for Lisp rather than a novelty: the first, errors that ask instead of crash, is built (`errors.lisp`); the other two are the first two below.

- **A little language for desktop rules.** Macros for rules that read like sentences, kept in `user.lisp` or a rules file: `(when-window (:class "Firefox") (move-to-workspace 2))`, `(at "09:00" :weekdays (open-project "vikix"))`, `(when-battery-below 20 (dim-screen) (notify "Charger?"))`. The apprentice (Inventions, above) writes its suggestions in it, so what it proposes can be read.
- **Agents that act through code you can check first.** Code is data: an agent sends a Lisp form for the desktop (through `vikix eval` or the MCP server), and before it runs Vikix walks the form and checks every function it calls against an allow-list. Moving a window passes; running a shell command or reading the secrets folder is refused or needs your OK. A check that's hard to make in other languages.
- **A time machine for functions.** Each live redefinition (from Emacs, `vikix eval` or an agent) keeps the previous version and its source. `vikix lisp undo move-window` puts the old one back; a history says what changed and when. Snapshots do this for files; this does it for the running code.
- **Look inside any window.** Super-click a window: the Lisp inspector opens in Emacs (SLIME) on StumpWM's object for it, with its class, size, workspace and properties, changeable live. A way to learn the desktop from the inside.
- **Layouts as plain Lisp.** Saved layouts (the "save and restore layouts" item in `TODO.md`) stored as readable s-expressions: open them, edit by hand, copy between machines, put one in a note.
- **Your configuration as a book.** `user.lisp` written as an Org document, explanations and code together, the code tangled out by org-babel. The config reads like a chapter.
- **Live-code music from the same Lisp.** A feature with SuperCollider and a Common Lisp client for it: from the Emacs that talks to StumpWM, play loops, change the tempo live, bind patterns to keys; the bar shows the beat.
- **Your own desktop, compiled.** `save-lisp-and-die` builds one StumpWM executable with your plugins and settings compiled in, so the desktop starts at once; a Super+m entry rebuilds it after changes, and the plain build stays as the fallback.

## Lisp apps for the Lisp desktop

Small programs (an image viewer, a file explorer, a launcher, a video player) written in Common Lisp and driven by Vikix: the Lisp-machine idea on a modern desktop, where the desktop, the apps, the rules and the agents talk to each other in one language. A natural companion, or sequel, to the *Living Software* book (one program grown across a book), one app grown in public per book or site.

- **First, what already exists** (shipped in 0.69.0: `vikix add lisp-apps`): **Lem** (an editor written in Common Lisp, Emacs-like, graphical and terminal), **Nyxt** (a web browser written in Common Lisp, programmable as StumpWM is), **McCLIM** (a toolkit for windowed apps in Common Lisp, drawing through the same X11 library as StumpWM) with its inspector (Clouseau) and listener. The first apps StumpWM can drive in its own language, with no new code.
- **Where Lisp adds something: presentations.** In McCLIM, what is on screen is still the Lisp object behind it: a file shown in an explorer *is* the file object, its right-click offers the commands that apply to it, and the same object can be handed to StumpWM, a rule or an agent. That is what would make these apps new rather than copies.
- **Where it doesn't:** decoding video, rendering the web, reading every image format are years of others' work. Lisp for the interface and the behaviour, proven engines underneath: the video player is a Lisp app controlling mpv over its socket, not a decoder.
- **How they fit:** each app its own Lisp process (a crash takes down the app, never the desktop), registered with Vikix and taking commands as StumpWM does through `vikix eval`; one shared command language, so a rule (`(when-window (:class "vikix-view") …)`) or an agent can drive any of them, checked by the allow-list (Leaning into Lisp); one look, following `vikix theme`.
- **An order, smallest and most useful first:** 1. install Lem, Nyxt, McCLIM (done, 0.69.0); 2. an **image viewer** (thumbnails, zoom, tags, renaming, all scriptable; could replace nsxiv); 3. a **file explorer** built on presentations, the showcase (became Esploro, its own project, now an Emacs window over a Lisp core: TODO 64); 4. a **launcher and menu** in Lisp, replacing rofi and joining the key help and the plugins; 5. a **video player**, a Lisp front-end on mpv; 6. the text editor stays Lem or Emacs, extended rather than rewritten.

## Nyxt: commands still to build

From the Nyxt work of 2026-10-02 (the guide is `docs/nyxt.md`; the page tools there are built and tested). Build each as those were: on a hidden display, then into `~/.config/nyxt/page-tools.lisp` and the guide.

- **Tables → CSV.** Each `<table>` on the page into a CSV file, for a spreadsheet: `clss:select "table"`, rows and cells from the parsed copy.
- **Save the page's code blocks.** Every `<pre><code>` to files, or a prompt to pick one and copy it (the "send a block to a terminal" idea, done properly).
- **Download every link of a kind**, e.g. every PDF on a course page (`a[href$=".pdf"]`), into one folder, as save-page-images does.
- **All open tabs as a Markdown list** of titles and links, to keep a research session.
- **Ask a question about the page**: summarize-page's route, with a prompt for the question.
- **Add the page to `note`'s index**, so `note ask` finds it beside your notes.
- **Reader view**: the page's Markdown rendered back as a clean `nyxt:` page in the guide's style.
- **Jump to a heading**: the page's headings as a Ctrl+Space source; pick one to scroll there.
- **Play the page's video in mpv** (with `yt-dlp`).
- **Clip into a project's log**: clip-selection's quote through `vikix project log NAME`, with a prompt for the project.
- **A QR code of a link or of the selection**, not only the page: `cl-qrencode` as `show-url-qrcode` uses it.
- **Bigger:** commands joining Nyxt to the desktop (a page into a project's log, a site as a web app, show a file in Esploro, the window to a workspace); address rewrites and blocked domains (Nyxt's request hook); Ctrl+Space sources for `~/dev`'s docs, `vikix project` folders and links from notes; Lisp-made `nyxt:` pages (a start page with the projects, `vikix today`, the key card from StumpWM); a `vikix learn c` lesson page with a **Check** button that runs the checker beside the lesson.

## Gathered on 2026-10-03, in a conversation with Vid

Two of the day's ideas are already worked out as designs, so they go to `TODO.md` instead when picked up: `DESIGN-music.md` (the musical sketchpad: patterns as Lisp, a codeless grid over them, the inbox, "send to Ardour") and `DESIGN-docs.md` (one catalogue over every document on the machine, `Super+h`, the agent's `docs_search`, and the `vk` alias, prefix matching and tab completion). The rest are here, none decided.

### The desktop, from the inside

- **"Why did that happen?"** `Super+?` after anything (a window jumped workspaces, a key did something odd, a notification came) shows the command, rule or line of `user.lisp` that caused it, with Edit and Undo beside it. StumpWM runs every action through `run-commands` already; a ring of the last fifty, each with its source, is small. Only a desktop that is a program can answer this.
- **One command registry for Vikix itself.** Today the same commands are described three times by hand: `*vikix-bindings*` in `keys.lisp` (key, command, blurb), `*vikix-menu*` and friends in `commands.lisp` (label, action, what it needs) and the fixed tool list in `vikix-mcp`; the agents' `SKILL.md` is a fourth copy. A `define-vikix-command` with name, doc, key, menu group, needs and an `agent-safe` flag would generate the key map, Super+m, Super+F1, the MCP tool list and the command section of the skill from one place, so the agent is never offered a command the key map doesn't know. Esploro's `define-file-command` is the model.
- **`vikix pick`, and rofi retired from the scripts.** Super+m and Super+F1 are already StumpWM's own `select-from-menu`; rofi is left doing the launcher, clipmenu, emoji, calc and seven `rofi -dmenu` pickers in `vikix-ask`, `-drives`, `-esploro`, `-local-ai`, `-notifications`, `-project` and `-wallpaper`. A `vikix pick` (lines in, choice out, through `vikix eval`) lets those seven drop rofi today and follow the theme for free; the launcher then needs only `.desktop` parsing and fuzzy matching in Lisp. Emoji and calc are the one thing rofi does that this wouldn't. This is item 4 of "Lisp apps for the Lisp desktop", found to be smaller than it sounds.

### Trust you can check

- **The outbound ledger.** One page: everything that left the laptop today, by program. Claude calls (`vikix mcp status` and `llm logs` already know), package fetches, Dropbox, the agents. The site says "nothing left the laptop" in several places; a ledger lets anyone check.
- **Try before you trust.** `vikix try PROGRAM`: run anything in a bubblewrap sandbox (in Void) with a throwaway home, see what it wants to touch (the ledger reports it), then install for real or let it vanish.
- **Guest.** `vikix guest`: a fresh login that sees none of your files, keys or sessions, wiped when it logs out. For lending the laptop to a visitor, or a child for ten minutes. On Void: a user, a tmpfs home, one StumpWM group.

### Documentation that acts

- **"Do it" buttons in the guides.** Every command on a guide page in Nyxt gets a button that sends the form to StumpWM through the checked route the agent uses, snapshot first. With the docs catalogue (`DESIGN-docs.md`), any Markdown on the machine gets the same: a README's install steps become buttons. Nyxt is Lisp, so this is a page hook, not a program.
- **Show me how.** Ask the agent "how do I split the screen" and the desktop demonstrates instead of answering: `vikix-osd` shows the key, StumpWM performs it slowly, the bar names what changed. Teaching by doing, from the OSD and the eval route already there. The children's account would get a lot from this.

### Files and care

- **Any file, as it was.** `vikix backup` runs restic; Esploro gets a right-click "Versions…" listing a file's snapshots by date, restoring one as a plan with undo. Time Machine's best feature inside the file explorer, with Esploro's review in front of it.
- **See better.** A Super+m entry that enlarges everything in one step (fonts, bar, rofi, Emacs, Firefox, through one scale in `vikix theme`), switches to a high-contrast theme and offers a dyslexia-friendly font, and back. One theme file for the whole desktop is what makes this possible to do properly.

### Windows programs as native windows

- **Office in its own windows, through RemoteApp.** RDP's RemoteApp mode exports one Windows program's window instead of the whole desktop, and FreeRDP shows it as an ordinary X window, so StumpWM tiles Excel beside Emacs like anything else (what the WinApps project does elsewhere). The pieces are in place: `vikix windows create` installs Windows 11 **Pro**, which has the RDP server (Home doesn't); the VM is on the private `virbr0`, so port 3389 is reachable only from this machine; `freerdp` 3.32.1 is in Void (checked 2026-10-03); `~/Windows` is `Z:`, so a file opened from Esploro has a path Windows can see. To add: Remote Desktop and the `fAllowUnlistedRemotePrograms` key in the install's answer file; `vikix windows app excel [FILE]`, which starts the VM if it's off and runs `xfreerdp /app:program:EXCEL.EXE /app:cmd:"Z:\…" /clipboard /sound /dynamic-resolution`, the password from the key store, never on the command line; `.desktop` files for Word, Excel, PowerPoint and Outlook so they're in the launcher and Super+m, and `mimeapps.list` entries so a `.xlsx` opens in Excel from Esploro with LibreOffice under "open with"; a scan of the VM's Start Menu over the share so new Windows programs appear on the Linux side by themselves. Limits: SPICE stays for the full desktop, RDP for apps (both can run); clipboard and files cross, drag-and-drop doesn't; the first launch waits for Windows to boot, so keeping the VM running is a setting worth having on the Z13 (memory) and off on the X1; what the Windows licence says about RDP use is Vid's to read.

### Cuis Smalltalk

Worked out as `DESIGN-cuis.md`: `vikix add cuis` from pinned packages, a `vikix eval --cuis` door with Swank's password and guard, the desktop drawn as objects in Morphic, the music sketchpad's second face, lessons that change the running image, and a docs adapter for class comments. One idea stays here: **the other living image, as a book.** The Common Lisp book is *Living in the Image*; Cuis is the other image one can live in, and one language against two images is a chapter nobody has written. For the Living Series file when the time comes.

### Music, beyond the design

- **Reaper as a second DAW feature.** `vikix add reaper`, from reaper.fm, pinned and checksummed as Ollama is; the same OSC transport commands behind it, so the Lisp side doesn't care which DAW is listening. Ardour stays the default of `vikix add music` because it's free and in Void.
- **Carla is not in Void** (checked 2026-10-03): TODO item 22 names it; Ardour hosts LV2 itself, so drop Carla or build it from source.

### Website notes (vikix.dev, reviewed 2026-10-03)

Fixes agreed and briefed to an agent: the agent transcript and nav overflow on phones, the hero screenshot unreadable at phone width, the name repeated three times before the pitch; the AI feature list cut to three headline items with the rest folded; the Void material moved to its own page; the `llm` commit-message demo replaced or dropped; a FAQ entry on Swank that says what's true (localhost only, `~/.slime-secret`, the auth deadline in `swank-guard.lisp`), since the earlier draft of that entry wrongly said there was no authentication.
