# Ideas

## Architecture review with Codex (2026-10-05)

Suggestions from a read of the projects in `~/src`, saved at Vid's request.
These are recommendations, not agreed priorities or a replacement for the
order in [TODO.md](TODO.md). No implementation was started in this review.

Vikix already has a broad set of features. The strongest next step is to
connect the command registry, rules, snapshots, projects and live Lisp
desktop so that everyday work takes less managing.

1. **Restore the work, including the conversation.** Session restoration
   brings agent terminals back in their folders, and `vikix agents resume`
   takes a desk's conversation up again by hand; the remaining step is to do
   that at the login. After a reboot, recover the project, layout and
   resumable session, and say clearly what could not be restored. This
   follows the session work in TODO's saved layouts item.
2. **Bring file versions into Esploro.** The planned "Versions…" interface
   should list available versions, preview or compare one, and restore
   through a reversible plan. This makes backups useful during ordinary
   work. Continue [plans/DESIGN-restore.md](plans/DESIGN-restore.md), TODO item 80.
3. **Show what changed after an update.** Keep a small "Since your last
   update" page, filtered by installed features and linked to examples.
   Features arriving quickly need a way to become habits. This develops
   [NOVEL.md, idea 11](NOVEL.md#11-whats-new-for-you), rather than adding a
   separate release-notes mechanism.

Of the review's five, the office and "why?" with a next action are built,
and its project handoff card became the desk's handoff (`ARCHIVE.md`).
Suggested order from this review: reliable session restoration first.

## Gemini's audit (2026-10-23)

Vid worked a roadmap out with Gemini (six phases, P0 to P2, with the programs it would bring in) and brought it as [plans/gemini-audit-2026-10-23.md](plans/gemini-audit-2026-10-23.md), kept as he brought it. This section is what came of sorting it against the lists: what is already built under another name, what became a dated note under an existing item, what stays an idea here, and what runs against a decision already taken. The order of the lists is unchanged: `plans/DESKTOP-1.0.md` comes first, and the brief's own order (the roaming rig in days 1 to 3, the site in days 4 to 7) is for Vid to confirm or not. None of the programs the brief names has been checked against void-packages.

### Already in Vikix, by another name

- **The IPC off the main thread** (P3.3): `socket.lisp` serves agents from a thread of its own, a thread a request, reads answered while a menu is open, a deadline and `:busy` after it (`ARCHIVE.md`, the socket). Left of the brief's point: a rate limit, now in To look into 5 of `TODO.md`.
- **Compiled copies validated before use** (P3.5): `init.lisp` compiles to a `.making` file and renames it, and a copy that fails to load is marked and the text loaded instead; `vikix update` asks the new StumpWM image whether it starts before keeping it (`plans/DESIGN-dependable.md` 1 and 3). TODO 92's dumped core gets the same check.
- **ACP** (P4.4): `vikix agent --acp`, the adapters, agent-shell in Emacs (`plans/TODO-editors.md`, decision 4).
- **The agents' states, an inbox, one-key accept and send back** (P4.3): the Office (`vikix agents office`, Needs attention, `y` and `b`), the agent-waiting plugin's bar note. What is left is TODO 97 and `DESIGN-dependable.md` 11.
- **A local semantic index** (P5.3): `note ask` and `vikix docs ask` embed with sqlite-vec through Ollama (`lib/notes.py`) over the guides, the repositories, `~/dev` and the user's `own=` folders, PDFs through pdftotext; agents reach it through `docs_search`.
- **Nyxt and Lem** (P5.1): `vikix add lisp-apps` (0.69.0), Nyxt's page tools and guide (`docs/nyxt.md`).
- **The merge queue and the stuck-agent patrol** (P5.4): `.claude/release` is the one-at-a-time rebase-and-test queue, the tester batches the desks in review that share no file, the reconnect watcher wakes an agent the network dropped, Needs attention names quiet workers, the rescue thread catches a stuck StumpWM.
- **Evening summaries** (P5.2): `vikix day` (`NOVEL.md` 4); the morning side is TODO 100.
- **The site** (P2.1 to P2.3): the gallery's and the guide's header links already point at the front page's sections (`./#why`, `../#install`), the FAQ is `<details>`, Open Graph and Twitter cards are in, the footer names GitHub Issues and the mail address, Discussions is linked twice. What is left is under Website notes below.
- **A VPS as part of this Vikix** (P1.1, P6.1): TODO 117 (`vikix node`); the private network, TODO 16.
- **jj** (P4.2): `plans/APP-IDEAS.md`, to try on `~/src` first.

### Noted under existing items

TODO 6 (ZFS beside btrfs), 16 (mosh), 20 (a VM image beside the stick), 21 (investing and the company's numbers), 44 (tickers), 87 (the HUD's three candidates), 90 (the strip's columns by task), 92 (the core checked before it starts), 94 and the new 120 (the session's programs supervised, with ceilings), 97 (the agents in the bar), 99 (scopes declared before an edit), 117 (the relay VPS for the phone), To look into 5 (a rate limit on the socket); `plans/DESIGN-dependable.md` 8 and 9 (the keyring, syd and clampdown); `plans/TODO-editors.md` (gptel-agent, eca-emacs); the Nyxt and the Lisp-lesson entries below.

### Ideas kept here, none decided

- **A display for the agent's hands** (P6.2). A computer-use agent, one that clicks and types, gets an X server of its own shown as a window on the desktop: Xephyr (a nested X server, a window on ours) rather than Xvfb (which has no picture), so the agent never takes the real pointer or keyboard, and Vid watches it work as a tile or a column of the strip. With the door and the house rules it is a desk with a screen. Check Void for xorg-server-xephyr.
- **Three workers, one task** (P6.3). Three desks on one task, a provider each, the tester judging each, Vid picking the diff that stays; the Office shows them side by side. Worktrees already give the copies; a copy-on-write filesystem would only make the build folders cheaper, so that half is TODO 6's btrfs business, not a condition. The brief calls it a tournament.
- **`vikix read URL|PDF`** (P5.3). The page or paper stripped to text, its claims pulled out, matched against the notes and the docs catalogue, the result a Markdown file with its citations in a research folder of the project. Nyxt's summarize-page and `vikix docs ask` are the halves; the join is new. Local by default (`vikix ai use`).
- **A staging copy of a project for a look**, `vikix preview` (P5.4): the project's dev server in a bubblewrap sandbox with a throwaway home, on loopback, gone when the window closes; the same sandbox as "Try before you trust" below and `NOVEL.md` 10's rehearsal.
- **Ask the transcripts** (P5.4). The providers' session files are on the disk (`sessions_on_disk` in `lib/handoff.py` knows where); a `vikix agents ask-past "why did we drop X"` that searches them, with a local model only, since they hold everything typed. The brief calls it a seance.
- **A cap on API spend** (P6.1). The ledger (TODO 81) says what left; llm's log and the providers' usage endpoints say what it cost; a monthly figure in the bar and a refusal past a cap the user set, a key at a time. OpenRouter already routes between models (`vikix ai use cloud`).
- **A measure of rework** (P5.2). From the Office's events: how often a task came back from review, how many rounds its tests took, by provider and by project; a line in the morning brief, no score the agents see. TODO 119's learning phase is the home if it is ever built.
- **`vikix release draft`** (P5.4): the release's line written from the desk's hand-in and its commits instead of typed; `NOVEL.md` 11 is the user's side of the same notes.
- **Company numbers** (P5.4), beyond TODO 21's investing: burn, runway, the API spend above, the Free Zone's filing dates as reminders; figures from files Vid gives it, never advice.
- **Capture more than text for Super+i** (P5.2): a region of the screen, a terminal's error, the page's element under the pointer in Nyxt, sent to a vision model; "Ask about the screen" below is the first of these. The brief's keys are taken: `Super+c` is clipmenu, `Super+v` the split.
- **A runit lesson** for `vikix learn` (P5.1): Void's services as a course after C and Lisp (`plans/TUTORIALS.md`).

### Set against decisions already taken

Each is written down so the question isn't reopened by accident; Vid can overturn any of them.

1. **Beads, OpenSpec, Beady-Eye, Gas City, Herdr, b9s and their editor plugins as the task tracker and the agents' runtime** (P1.2, P4.1, P4.3, P4.4, P5.2, P5.4, P6.1). The Office keeps the tasks (`lib/tasks.py`, TODO 115: an id for life, provenance, named transitions, a dependency graph through `lib/plan.py`), and TODO 119 says in so many words: no second task board or scheduler. Herdr's persistent terminals are what a desk's record and `vikix agents resume` are for, and what a node (TODO 117) gives a job that must outlive the laptop. What Beads has that the Office hasn't (records synced between machines through git, `bd ready --claim`) belongs to the Office as a feature when the X1 and the Z13 share one Office (`plans/DESIGN-distributed-office.md`), not as a second store. The brief's own protocol (a `ROADMAP.md`, a repository `log.md`, `.beads/`, its provisioning script) was not followed for the same reason: this repository's lists are `TODO.md`, `IDEAS.md`, `ARCHIVE.md`, `bugs.md`, `NOVEL.md` and `plans/`, and a `log.md` is a project's, kept by `vikix project`. *Vid, 2026-10-23, after the pros and cons:* Vikix stays independent; the Office remains the one store, and the ideas are kept here. What Beads has that the Office lacks (records synced over the git remote, an atomic claim across machines, compaction of closed tasks) is borrowed as items of the distributed Office design and TODO 96 when their turn comes; a trial of `bd` on one non-Vikix project stays open as `plans/APP-IDEAS.md` keeps jj's.
2. **A command schema in place of Lisp through the door** (P3.3). Vid's choice (Leaning into Lisp below; What's next 4 in `TODO.md`): agents act through code checked first. The door is the capability gate: a form passes when every call is in `*vikix-door-allowed*` or a `:agent t` command of the registry. A new act for agents is a name in that list, which is all the brief's `window:create` would be.
3. **An MCP or A2A server inside the StumpWM image** (P3.4, P5.3). The server is `bin/vikix-mcp`, a process of its own, on purpose: StumpWM's one thread never waits on a program or a client, and a crash in a protocol library must never take the desktop (the same rule gives each Lisp app its own process). A2A is decided nowhere and has no user here; it stays an idea without one.
4. **Vikix itself as an xbps package** (P3.5). Vikix is a checkout linked into the home (`link_managed`) and updated by `vikix update`, which `--back` undoes; a system package would fight both. A `stumpwm-vikix` package is `NOVEL.md` 23 (what Vikix builds, given to Void) and stays there.
5. **Roamgate, Paseo, Takopi, Happy and Reemoat as the phone's way in** (P1.3, P6.1). Decided 2026-10-08 (`plans/DESIGN-phone.md`): Telegram to the existing Office, the questions and controls Vikix's own, no further runtime. Takopi is the nearest to that design and could be read for its Telegram handling.
6. **The order.** The brief's P0 is the roaming rig and the site; the list's is `plans/DESKTOP-1.0.md`, gate A. The rig's Vikix parts (TODO 16, 117, `DESIGN-phone.md`) are gate C's and later, and the brief's reason for it (dispatching and reviewing agents from a phone with the lid closed) is gate B's autonomy run from a phone, which gate A's containment comes before. The site's left-overs are small and can go any time.
7. **A sandbox drawn around `~/dev/<project>`** (P3.2). The unit of work is the desk, a worktree beside the repository, not a folder under `~/dev`; the sandbox of `DESIGN-dependable.md` 9 is drawn around the desk and its scratch folders.

Ideas for Vikix that nobody has decided to build yet. When one is picked up, it moves to `TODO.md` (worked out properly there: what, why, what it touches) and is taken out of here; one that ships goes to `ARCHIVE.md`. Nothing here is a promise, and no package name here has been checked against void-packages.

Gathered on 2026-09-30, in a conversation with Vid.

## Software Void doesn't have

- **Flatpak as a feature.** The easy route to apps Void doesn't package (Obsidian, Zoom, Spotify, Signal), each somewhat walled off from the rest of the system. `vikix update` would update them too.
- **Distrobox.** An Ubuntu or Arch system inside Vikix, sharing the home folder, for anything that only ships as a .deb or for Arch. The safety net.

## Working on projects

- **Per-project settings with direnv.** Entering a project's folder sets its tools and settings; leaving undoes them.
- **From Onshape (2026-10-09).** Onshape runs full 3D CAD in a browser: the server computes, the browser only draws, and every edit is a tiny commit in a database. Its API, thin-client and version-history ideas are already in Vikix (`vikix-mcp`, `plans/DESIGN-machines.md`'s `--on NAME`, `plans/DESIGN-remoteapp.md`, `vikix snapshot`/`history`/`undo`, `plans/DESIGN-restore.md`). Two gaps left:
  - *Snapshots on every change, not only at moments.* Vikix snapshots before an agent starts and before a rule changes; Onshape records every edit. A quiet snapshot whenever a file in `yours.list` is saved (inotify, debounced to a minute) would make `vikix history` a true timeline.
  - *A project reopens everything.* `vikix project open` brings back the terminal, the editor and the layout. Add the project's browser tabs and its Esploro view, as an Onshape document holds every tab of one job.

## AI

- **Ask about the screen.** Drag over any area (a chart, an error dialog, a PDF page) and ask about it: `s-i` for pictures, with a vision model.
- **Voice commands.** Hold a key and say "put Firefox on workspace 3" or "open the Vikix project": the dictation already there, then the agent acting through the MCP server.
- **Meeting notes.** Record a call, transcribe it locally, then a summary and action items. Only with everyone's consent, and the screen says a recording is running.
- **Jev (TypeSafe AI), for typed decisions.** A cloud API that answers with one of a fixed set of choices and how sure it is (not text), claimed in 70-500 ms and nearly free: https://typesafe.ai/blog/introducing-system-one-models-and-jev. Compare it with a local model held to a JSON schema (Ollama's structured outputs) when the desk's mail groups (TODO item 21), `vikix notes sort` (item 38) or voice commands are built. Against it, as seen 2026-10-02: cloud only and closed, early access, its own benchmarks, and business mail is local by default; "can't hallucinate" only means the answer is always an allowed choice, not the right one.

## Everyday business

- **Text snippets.** `;addr` becomes your address, `;thanks` a standard reply (espanso or similar), for the email you write over and over.
- **A scanner.** SANE and simple-scan, scanning straight into the desk's documents inbox (wish list: the desk), with the text read by OCR on the way in.

## Focus

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
    - **From the desktop, which only Vikix can see:** StumpWM records which keys, commands and menu entries are used. "You open Firefox and move it to workspace 2 every morning" → a window rule. "You clicked the launcher 20 times this week" → Super+d. "These five keys are never used" → offered for things you do. (The counting is in since 0.72.x: `vikix used` keeps which keys, menu entries, palette picks, typed commands and rules are used, names and counts only.)
    - **How it offers:** a short weekly digest, not pop-ups. Each suggestion shows exactly what it would add (an alias, a function, a key in `user.lisp`) with a one-key yes; every yes is a snapshot first, so `vikix undo` takes it back.
    - **How it's built:** the patterns are plain counting, no AI; a model only names and explains a suggestion. History is private and holds secrets typed by accident: a local model only, and the secrets scrubbed first, as `vikix debug` does.
- **Learn Lisp by changing your own desktop.** A `vikix learn` course where each lesson changes the running desktop: a key that tells the time, the bar's colours, your first StumpWM command. The desktop is the teaching tool. A companion to the Common Lisp books. (Gemini's audit, 2026-10-23: the same lessons with the running desktop's source opened at the definition, as `vikix what`'s `source:` lines name it; Void's services as a later course of the same runner.)
- **A readable history of your settings.** Each snapshot gets a one-line plain-English description ("added a key for the calculator"), written by a model from the diff, so `vikix history` reads like a diary of how the machine was shaped, and undoing the right thing is easy.
- **"Find that thing I saw."** Optionally, a screenshot every few minutes, kept only on this machine and encrypted, its text made searchable ("the error this morning", "that price yesterday"): a private, local Recall. Off by default, paused with one key, never taking password windows or the lock screen, old ones deleted by themselves.
- **"Explain what just went wrong."** One key, right after a command fails: the error and the recent commands are read, explained, and the fix offered, run only if you say so.

## Leaning into Lisp

Ideas that work only because the desktop is a running Lisp program you can inspect, change and question while it runs. Vid's favourites to start with were three, which make Vikix safer and easier to shape, each a real reason for Lisp rather than a novelty: errors that ask instead of crash (`errors.lisp`), a little language for desktop rules (`rules.lisp`, `vikix rules`) and agents that act through code you can check first (the door, `door.lisp`); all three are built, and layouts as plain Lisp with them (`ARCHIVE.md`). Still open:

- **A time machine for functions.** Each live redefinition (from Emacs, `vikix eval` or an agent) keeps the previous version and its source. `vikix lisp undo move-window` puts the old one back; a history says what changed and when. Snapshots do this for files; this does it for the running code.
- **Look inside any window.** Super-click a window: the Lisp inspector opens in Emacs (SLIME) on StumpWM's object for it, with its class, size, workspace and properties, changeable live. A way to learn the desktop from the inside.
- **Your configuration as a book.** `user.lisp` written as an Org document, explanations and code together, the code tangled out by org-babel. The config reads like a chapter.
- **Live-code music from the same Lisp.** A feature with SuperCollider and a Common Lisp client for it: from the Emacs that talks to StumpWM, play loops, change the tempo live, bind patterns to keys; the bar shows the beat.

## Lisp apps for the Lisp desktop

Small programs (an image viewer, a file explorer, a launcher, a video player) written in Common Lisp and driven by Vikix: the Lisp-machine idea on a modern desktop, where the desktop, the apps, the rules and the agents talk to each other in one language. A natural companion, or sequel, to the *Living Software* book (one program grown across a book), one app grown in public per book or site.

- **Where Lisp adds something: presentations.** In McCLIM, what is on screen is still the Lisp object behind it: a file shown in an explorer *is* the file object, its right-click offers the commands that apply to it, and the same object can be handed to StumpWM, a rule or an agent. That is what would make these apps new rather than copies.
- **Where it doesn't:** decoding video, rendering the web, reading every image format are years of others' work. Lisp for the interface and the behaviour, proven engines underneath: the video player is a Lisp app controlling mpv over its socket, not a decoder.
- **How they fit:** each app its own Lisp process (a crash takes down the app, never the desktop), registered with Vikix and taking commands as StumpWM does through `vikix eval`; one shared command language, so a rule (`(when-window (:class "vikix-view") …)`) or an agent can drive any of them, checked by the allow-list (Leaning into Lisp); one look, following `vikix theme`.
- **An order, smallest and most useful first:** 1. install Lem, Nyxt, McCLIM (done, 0.69.0: `vikix add lisp-apps`, with McCLIM's inspector Clouseau and its listener); 2. an **image viewer** (thumbnails, zoom, tags, renaming, all scriptable; could replace nsxiv); 3. a **file explorer** built on presentations, the showcase (became Esploro, its own project, now an Emacs window over a Lisp core: TODO 64); 4. a **launcher and menu** in Lisp, replacing rofi and joining the key help and the plugins; 5. a **video player**, a Lisp front-end on mpv; 6. the text editor stays Lem or Emacs, extended rather than rewritten.

## Nyxt: commands still to build

From the Nyxt work of 2026-10-02 (the guide is `docs/nyxt.md`; the page tools there are built and tested). Build each as those were: on a hidden display, then into `~/.config/nyxt/page-tools.lisp` and the guide.

- **Download every link of a kind**, e.g. every PDF on a course page (`a[href$=".pdf"]`), into one folder, as save-page-images does.
- **All open tabs as a Markdown list** of titles and links, to keep a research session.
- **Ask a question about the page**: summarize-page's route, with a prompt for the question.
- **Play the page's video in mpv** (with `yt-dlp`).
- **A QR code of a link or of the selection**, not only the page: `cl-qrencode` as `show-url-qrcode` uses it.
- **The page driven from Lisp for an agent** (Gemini's audit, 2026-10-23): Nyxt's document reached through a door of its own, as Cuis's and PicoLisp's are drawn, so an agent reads and fills a page through checked forms as it does the desktop (the door's walker over Nyxt's commands), through `vikix mcp` and never a server inside Nyxt.
- **Bigger:** commands joining Nyxt to the desktop (a site as a web app, show a file in Esploro, the window to a workspace); address rewrites and blocked domains (Nyxt's request hook); Ctrl+Space sources for `~/dev`'s docs, `vikix project` folders and links from notes; more on the home page Nyxt opens on (`vikix-home`, 0.72.116: the logo and the keys; it could show the projects and `vikix today`); a `vikix learn c` lesson page with a **Check** button that runs the checker beside the lesson.

## Gathered on 2026-10-03, in a conversation with Vid

Two of the day's ideas are already worked out as designs, so they go to `TODO.md` instead when picked up: `plans/DESIGN-music.md` (the musical sketchpad: patterns as Lisp, a codeless grid over them, the inbox, "send to Ardour") and `plans/DESIGN-docs.md` (one catalogue over every document on the machine, `Super+h`, the agent's `docs_search`, and the `vk` alias, prefix matching and tab completion). The rest are here, none decided.

### The desktop, from the inside

- **`vikix pick`, and rofi retired from the scripts.** Super+m and Super+F1 are already StumpWM's own `select-from-menu`; rofi is left doing the launcher, clipmenu, emoji, calc and seven `rofi -dmenu` pickers in `vikix-ask`, `-drives`, `-esploro`, `-local-ai`, `-notifications`, `-project` and `-wallpaper`. A `vikix pick` (lines in, choice out, through `vikix eval`) lets those seven drop rofi today and follow the theme for free; the launcher then needs only `.desktop` parsing and fuzzy matching in Lisp. Emoji and calc are the one thing rofi does that this wouldn't. This is item 4 of "Lisp apps for the Lisp desktop", found to be smaller than it sounds.

### Trust you can check

- **Try before you trust.** `vikix try PROGRAM`: run anything in a bubblewrap sandbox (in Void) with a throwaway home, see what it wants to touch (the ledger reports it), then install for real or let it vanish.
- **Guest.** `vikix guest`: a fresh login that sees none of your files, keys or sessions, wiped when it logs out. For lending the laptop to a visitor, or a child for ten minutes. On Void: a user, a tmpfs home, one StumpWM group.

### Documentation that acts

- **"Do it" buttons in the guides.** Every command on a guide page in Nyxt gets a button that sends the form to StumpWM through the checked route the agent uses, snapshot first. With the docs catalogue (`plans/DESIGN-docs.md`), any Markdown on the machine gets the same: a README's install steps become buttons. Nyxt is Lisp, so this is a page hook, not a program.
- **Show me how.** Ask the agent "how do I split the screen" and the desktop demonstrates instead of answering: `vikix-osd` shows the key, StumpWM performs it slowly, the bar names what changed. Teaching by doing, from the OSD and the eval route already there. The children's account would get a lot from this.

### Files and care

- **See better.** A Super+m entry that enlarges everything in one step (fonts, bar, rofi, Emacs, Firefox, through one scale in `vikix theme`), switches to a high-contrast theme and offers a dyslexia-friendly font, and back. One theme file for the whole desktop is what makes this possible to do properly.

### Cuis Smalltalk

Worked out as `plans/DESIGN-cuis.md` and being built as TODO 88. One idea stays here: **the other living image, as a book.** The Common Lisp book is *Living in the Image*; Cuis is the other image one can live in, and one language against two images is a chapter nobody has written. For the Living Series file when the time comes.

### PicoLisp

Vikix already builds pil21 from the release tarball (`65-languages`, into `~/.local/opt/picolisp`; Void has no package, checked 2026-10-03) and gives it `~/dev/picolisp`. What its particular strengths buy beyond a working language: a database that is part of the language with Pilog to query it, its own HTTP server and form library, `native` for calling any C library without glue, and a debugger in `pil +`. Four uses, in order; none decided.

- **The music catalogue, a book project and a feature at once.** Track X of *Living in PicoLisp* is "a music catalogue"; `plans/DESIGN-music.md` has an inbox of captures and renders, and a later item for a sample library by detected key and tempo. The same artefact: a pil program that watches `~/music/inbox/` and `render/`, calls aubio and libkeyfinder through `native` for tempo and key, keeps each capture as a database object, answers Pilog questions ("every loop in E minor near 90 bpm, newest first") and serves the result as a page on loopback with pil's own server. The book writes it in public; Vikix ships it (`vikix add music-catalogue`, or inside `music`). What the Living Series workshop section of `TODO.md` is for.
- **A docs adapter** (`plans/DESIGN-docs.md`): pil21 ships its whole reference as HTML in `@doc/` (the function index, the tutorial, the FAQ; `(doc 'car)` opens an entry), and Zeal has no PicoLisp docset, so the catalogue is the only way these reach `Super+h`. An hour; the files are already in `~/.local/opt/picolisp/doc/`.
- **A door, `vikix eval --pil`.** A listening task on loopback in about twenty lines of PicoLisp: the password file's first line within five seconds, then one expression a line and its value back; the same shape as Swank's and Cuis's. `vikix mcp` gets `pil_eval` behind `--allow-eval`, so the agent can read the catalogue's database and help build track X.
- **`vikix learn picolisp`.** `plans/TUTORIALS.md` lists the runner's next languages (lisp, forth, haskell, sql); PicoLisp joins them, with the site's ten tracks as the syllabus and the steps as shared files, rendered on the site and run by `vikix learn` on the laptop under the same evidence rule.

Not: a fourth implementation language for Vikix itself (bash, Python and Common Lisp are three already; PicoLisp earns a place only where its database is the point); a replacement for SQLite in `vikix records` or the docs index; the music sketchpad's face (pil's forms are server-driven pages, wrong for a sequencer that changes on the next bar).

### Areas still to look at (2026-10-03)

Parts of Vikix that haven't had the code-first pass the sections above got. Each would become a section here or a `DESIGN-*.md`. Done so far: publishing (TODO 79), security (`plans/DESIGN-security.md`), your machines and your phone (`DESIGN-machines.md`), the cloud (`DESIGN-cloud.md`) and backup and restore (`DESIGN-restore.md`). The children's account is set aside for now (Vid, 2026-10-04): it stays at the end of this list, not to be picked up before the rest.

- **The Z13 as a tablet.** Touch, pen and the detachable keyboard (TODO 58–63): what a tablet mode of a tiling desktop is. Nobody on Linux has a good answer; Viri's strip may be part of one.
- **A first visitor's path.** The site, the install line, the first hour, the release process and GitHub Actions, seen by someone who actually tries it for the first time; the everyday-user agent on a fresh VM, start to finish.
- **The children's account** (TODO 33). Several of today's ideas point at it: lessons in Cuis, Pascal, the education bundle, screen time, "show me how". Enough hangs off it that it would deserve its own design, later: a second login, a simpler desktop, apps chosen by the parent, nothing of the parent's reachable, a home for the programming course.

### Music, beyond the design

- **Reaper as a second DAW feature.** `vikix add reaper`, from reaper.fm, pinned and checksummed as Ollama is; the same OSC transport commands behind it, so the Lisp side doesn't care which DAW is listening. Ardour stays the default of `vikix add music` because it's free and in Void.
- **Carla is not in Void** (checked 2026-10-03): TODO item 22 names it; Ardour hosts LV2 itself, so drop Carla or build it from source.

### Website notes (vikix.dev, reviewed 2026-10-03)

Fixes agreed and briefed to an agent: the agent transcript and nav overflow on phones, the hero screenshot unreadable at phone width, the name repeated three times before the pitch; the AI feature list cut to three headline items with the rest folded; the Void material moved to its own page; the `llm` commit-message demo replaced or dropped; a FAQ entry on Swank that says what's true (localhost only, `~/.slime-secret`, the auth deadline in `swank-guard.lisp`), since the earlier draft of that entry wrongly said there was no authentication.

Gemini's audit, 2026-10-23, what the brief found left on the site after the 2026-10-21 refresh (`plans/website-refresh.md`): a JSON-LD `SoftwareApplication` block beside the Open Graph tags; a link to the repository in the front page's header (the gallery's footer and the guide's bar have one, the header none); the header's links at phone width (the refresh wraps them under the logo; the brief asks for a drawer under 768 px: see on a phone whether the wrap is enough first); a short silent screencast in the hero (the strip, a worker at a desk) with one concrete line under the headline, which the refresh's value-led page would have to make room for. A VM image to try it in is TODO 20's.
