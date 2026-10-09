# Ideas

## Architecture review with Codex (2026-10-05)

Suggestions from a read of the projects in `~/src`, saved at Vid's request.
These are recommendations, not agreed priorities or a replacement for the
order in [TODO.md](TODO.md). No implementation was started in this review.

Vikix already has a broad set of features. The strongest next step is to
connect the command registry, rules, snapshots, projects and live Lisp
desktop so that everyday work takes less managing.

1. **Finish the agent office.** Starting an agent should attach it to a
   project, worktree, workspace and task. Its desk should show what changed,
   which checks passed and what needs Vid's attention. Agent discovery is
   already in; the `desk` work is underway. Build on [NOVEL.md, idea
   22](NOVEL.md#22-an-office-for-agents), rather than a second agent manager.
2. **Restore the work, including the conversation.** Session restoration
   brings agent terminals back in their folders; the remaining step is to
   resume the conversations where the agent supports it. After a reboot,
   recover the project, layout and resumable session, and say clearly what
   could not be restored. This follows the session work in TODO's saved
   layouts item.
3. **Make "why?" offer a useful next action.** Connect an explanation to the
   rule, setting or guide behind it. "This window moved because of this
   rule" should lead to inspecting the rule, testing a revision or disabling
   it. Existing provenance and rule controls are the foundation; the addition
   is the route from an explanation to a fix.
4. **Bring file versions into Esploro.** The planned "Versions…" interface
   should list available versions, preview or compare one, and restore
   through a reversible plan. This makes backups useful during ordinary
   work. Continue [DESIGN-restore.md](DESIGN-restore.md), TODO item 80.
5. **Show what changed after an update.** Keep a small "Since your last
   update" page, filtered by installed features and linked to examples.
   Features arriving quickly need a way to become habits. This develops
   [NOVEL.md, idea 11](NOVEL.md#11-whats-new-for-you), rather than adding a
   separate release-notes mechanism.

**Another addition: a project handoff card.** When leaving a project, keep
a short account of the task, unfinished changes, last check results and
next action. On returning, or starting another agent, show it beside the
actual Git state. Existing project logs, agent discovery and saved layouts
provide much of the foundation. Distinguish observed facts from an agent's
summary or uncertain claims; associate check results with the revision
tested so that old results do not look current. First try a card for one
project, using its existing log rather than a second task database.

Suggested order from this review: finish the agent office, then reliable
session restoration. Both address friction in Vid's current workflow and
make the existing features more useful.

Ideas for Vikix that nobody has decided to build yet. When one is picked up, it moves to `TODO.md` (worked out properly there: what, why, what it touches) and is deleted from here. Nothing here is a promise, and no package name here has been checked against void-packages.

Gathered on 2026-09-30, in a conversation with Vid.

## Software Void doesn't have

- **Flatpak as a feature.** The easy route to apps Void doesn't package (Obsidian, Zoom, Spotify, Signal), each somewhat walled off from the rest of the system. `vikix update` would update them too.
- **Distrobox.** An Ubuntu or Arch system inside Vikix, sharing the home folder, for anything that only ships as a .deb or for Arch. The safety net.

## Working on projects

- **Per-project settings with direnv.** Entering a project's folder sets its tools and settings; leaving undoes them.
- **From Onshape (2026-10-09).** Onshape runs full 3D CAD in a browser: the server computes, the browser only draws, and every edit is a tiny commit in a database. Its API, thin-client and version-history ideas are already in Vikix (`vikix-mcp`, `DESIGN-machines.md`'s `--on NAME`, `DESIGN-remoteapp.md`, `vikix snapshot`/`history`/`undo`, `DESIGN-restore.md`). Two gaps left:
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
    - **From the desktop, which only Vikix can see:** StumpWM records which keys, commands and menu entries are used. "You open Firefox and move it to workspace 2 every morning" → a window rule. "You clicked the launcher 20 times this week" → Super+d. "These five keys are never used" → offered for things you do.
    - **How it offers:** a short weekly digest, not pop-ups. Each suggestion shows exactly what it would add (an alias, a function, a key in `user.lisp`) with a one-key yes; every yes is a snapshot first, so `vikix undo` takes it back.
    - **How it's built:** the patterns are plain counting, no AI; a model only names and explains a suggestion. History is private and holds secrets typed by accident: a local model only, and the secrets scrubbed first, as `vikix debug` does.
- **Learn Lisp by changing your own desktop.** A `vikix learn` course where each lesson changes the running desktop: a key that tells the time, the bar's colours, your first StumpWM command. The desktop is the teaching tool. A companion to the Common Lisp books.
- **A readable history of your settings.** Each snapshot gets a one-line plain-English description ("added a key for the calculator"), written by a model from the diff, so `vikix history` reads like a diary of how the machine was shaped, and undoing the right thing is easy.
- **"Find that thing I saw."** Optionally, a screenshot every few minutes, kept only on this machine and encrypted, its text made searchable ("the error this morning", "that price yesterday"): a private, local Recall. Off by default, paused with one key, never taking password windows or the lock screen, old ones deleted by themselves.
- **"Explain what just went wrong."** One key, right after a command fails: the error and the recent commands are read, explained, and the fix offered, run only if you say so.

## Leaning into Lisp

Ideas that work only because the desktop is a running Lisp program you can inspect, change and question while it runs. Vid's favourites to start with were three, which make Vikix safer and easier to shape, each a real reason for Lisp rather than a novelty: the first, errors that ask instead of crash, is built (`errors.lisp`); the second, a little language for desktop rules, is being built (`rules.lisp`; the rest in `TODO.md`, items 68 to 71); the third is the first below.

- **Agents that act through code you can check first.** Done as the door (`door.lisp`, `vikix door`, 2026-10-08): an agent's form is read without running and walked, every function it calls checked against one list; a move passes, a shell command or a file is held for your yes.
- **A time machine for functions.** Each live redefinition (from Emacs, `vikix eval` or an agent) keeps the previous version and its source. `vikix lisp undo move-window` puts the old one back; a history says what changed and when. Snapshots do this for files; this does it for the running code.
- **Look inside any window.** Super-click a window: the Lisp inspector opens in Emacs (SLIME) on StumpWM's object for it, with its class, size, workspace and properties, changeable live. A way to learn the desktop from the inside.
- **Layouts as plain Lisp.** Done as saved layouts (`layouts.lisp`, `vikix layout`).
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

- **Download every link of a kind**, e.g. every PDF on a course page (`a[href$=".pdf"]`), into one folder, as save-page-images does.
- **All open tabs as a Markdown list** of titles and links, to keep a research session.
- **Ask a question about the page**: summarize-page's route, with a prompt for the question.
- **Play the page's video in mpv** (with `yt-dlp`).
- **A QR code of a link or of the selection**, not only the page: `cl-qrencode` as `show-url-qrcode` uses it.
- **Bigger:** commands joining Nyxt to the desktop (a page into a project's log, a site as a web app, show a file in Esploro, the window to a workspace); address rewrites and blocked domains (Nyxt's request hook); Ctrl+Space sources for `~/dev`'s docs, `vikix project` folders and links from notes; Lisp-made `nyxt:` pages (a start page with the projects, `vikix today`, the key card from StumpWM); a `vikix learn c` lesson page with a **Check** button that runs the checker beside the lesson.

## Gathered on 2026-10-03, in a conversation with Vid

Two of the day's ideas are already worked out as designs, so they go to `TODO.md` instead when picked up: `DESIGN-music.md` (the musical sketchpad: patterns as Lisp, a codeless grid over them, the inbox, "send to Ardour") and `DESIGN-docs.md` (one catalogue over every document on the machine, `Super+h`, the agent's `docs_search`, and the `vk` alias, prefix matching and tab completion). The rest are here, none decided.

### The desktop, from the inside

- **`vikix pick`, and rofi retired from the scripts.** Super+m and Super+F1 are already StumpWM's own `select-from-menu`; rofi is left doing the launcher, clipmenu, emoji, calc and seven `rofi -dmenu` pickers in `vikix-ask`, `-drives`, `-esploro`, `-local-ai`, `-notifications`, `-project` and `-wallpaper`. A `vikix pick` (lines in, choice out, through `vikix eval`) lets those seven drop rofi today and follow the theme for free; the launcher then needs only `.desktop` parsing and fuzzy matching in Lisp. Emoji and calc are the one thing rofi does that this wouldn't. This is item 4 of "Lisp apps for the Lisp desktop", found to be smaller than it sounds.

### Trust you can check

- **Try before you trust.** `vikix try PROGRAM`: run anything in a bubblewrap sandbox (in Void) with a throwaway home, see what it wants to touch (the ledger reports it), then install for real or let it vanish.
- **Guest.** `vikix guest`: a fresh login that sees none of your files, keys or sessions, wiped when it logs out. For lending the laptop to a visitor, or a child for ten minutes. On Void: a user, a tmpfs home, one StumpWM group.

### Documentation that acts

- **"Do it" buttons in the guides.** Every command on a guide page in Nyxt gets a button that sends the form to StumpWM through the checked route the agent uses, snapshot first. With the docs catalogue (`DESIGN-docs.md`), any Markdown on the machine gets the same: a README's install steps become buttons. Nyxt is Lisp, so this is a page hook, not a program.
- **Show me how.** Ask the agent "how do I split the screen" and the desktop demonstrates instead of answering: `vikix-osd` shows the key, StumpWM performs it slowly, the bar names what changed. Teaching by doing, from the OSD and the eval route already there. The children's account would get a lot from this.

### Files and care

- **See better.** A Super+m entry that enlarges everything in one step (fonts, bar, rofi, Emacs, Firefox, through one scale in `vikix theme`), switches to a high-contrast theme and offers a dyslexia-friendly font, and back. One theme file for the whole desktop is what makes this possible to do properly.

### Cuis Smalltalk

Worked out as `DESIGN-cuis.md`: `vikix add cuis` from pinned packages, a `vikix eval --cuis` door with Swank's password and guard, the desktop drawn as objects in Morphic, the music sketchpad's second face, lessons that change the running image, and a docs adapter for class comments. One idea stays here: **the other living image, as a book.** The Common Lisp book is *Living in the Image*; Cuis is the other image one can live in, and one language against two images is a chapter nobody has written. For the Living Series file when the time comes.

### PicoLisp

Vikix already builds pil21 from the release tarball (`65-languages`, into `~/.local/opt/picolisp`; Void has no package, checked 2026-10-03) and gives it `~/dev/picolisp`. What its particular strengths buy beyond a working language: a database that is part of the language with Pilog to query it, its own HTTP server and form library, `native` for calling any C library without glue, and a debugger in `pil +`. Four uses, in order; none decided.

- **The music catalogue, a book project and a feature at once.** Track X of *Living in PicoLisp* is "a music catalogue"; `DESIGN-music.md` has an inbox of captures and renders, and a later item for a sample library by detected key and tempo. The same artefact: a pil program that watches `~/music/inbox/` and `render/`, calls aubio and libkeyfinder through `native` for tempo and key, keeps each capture as a database object, answers Pilog questions ("every loop in E minor near 90 bpm, newest first") and serves the result as a page on loopback with pil's own server. The book writes it in public; Vikix ships it (`vikix add music-catalogue`, or inside `music`). What the Living Series workshop section of `TODO.md` is for.
- **A docs adapter** (`DESIGN-docs.md`): pil21 ships its whole reference as HTML in `@doc/` (the function index, the tutorial, the FAQ; `(doc 'car)` opens an entry), and Zeal has no PicoLisp docset, so the catalogue is the only way these reach `Super+h`. An hour; the files are already in `~/.local/opt/picolisp/doc/`.
- **A door, `vikix eval --pil`.** A listening task on loopback in about twenty lines of PicoLisp: the password file's first line within five seconds, then one expression a line and its value back; the same shape as Swank's and Cuis's. `vikix mcp` gets `pil_eval` behind `--allow-eval`, so the agent can read the catalogue's database and help build track X.
- **`vikix learn picolisp`.** `TUTORIALS.md` lists the runner's next languages (lisp, forth, haskell, sql); PicoLisp joins them, with the site's ten tracks as the syllabus and the steps as shared files, rendered on the site and run by `vikix learn` on the laptop under the same evidence rule.

Not: a fourth implementation language for Vikix itself (bash, Python and Common Lisp are three already; PicoLisp earns a place only where its database is the point); a replacement for SQLite in `vikix records` or the docs index; the music sketchpad's face (pil's forms are server-driven pages, wrong for a sequencer that changes on the next bar).

### Areas still to look at (2026-10-03)

Parts of Vikix that haven't had the code-first pass the sections above got. Each would become a section here or a `DESIGN-*.md`. In Vid's order of interest: publishing (TODO 79, worked out as `DESIGN-publish.md`), then security (now `DESIGN-security.md`). The children's account is set aside for now (Vid, 2026-10-04): it stays at the end of this list, not to be picked up before the rest.

- **Security.** Worked out as `DESIGN-security.md` (2026-10-04): the four pen-test reports and TODO items 4 and 5 as one ordered plan.
- **Your machines and your phone.** Worked out as `DESIGN-machines.md` (2026-10-04): Tailscale, Syncthing, KDE Connect and `vikix export`/`import` as one design, with `--on NAME` for the doors.
- **The computer extended into the cloud.** Vid's idea, kept as he wrote it in `DESIGN-cloud.md` (2026-10-09): rented always-on machines as *nodes* of the one Vikix (`vikix nodes`, `vikix node shell|run`, `vikix run --on atlas`, projects sent by git, jobs that outlive the laptop), over SSH first and the mesh of `DESIGN-machines.md` later; and, if it works for Vid, the product: Vikix Cloud sells nodes that attach to your Vikix, not a VPS. First milestone: the laptop and one cheap Void VPS feeling like one system.
- **Backup and restore.** Worked out as `DESIGN-restore.md` (2026-10-04): `vikix versions` over both histories, Esploro's "Versions…" as a plan with undo, a guided setup.
- **The Z13 as a tablet.** Touch, pen and the detachable keyboard (TODO 58–63): what a tablet mode of a tiling desktop is. Nobody on Linux has a good answer; Viri's strip may be part of one.
- **A first visitor's path.** The site, the install line, the first hour, the release process and GitHub Actions, seen by someone who actually tries it for the first time; the everyday-user agent on a fresh VM, start to finish.
- **The children's account** (TODO 33). Several of today's ideas point at it: lessons in Cuis, Pascal, the education bundle, screen time, "show me how". Enough hangs off it that it would deserve its own design, later: a second login, a simpler desktop, apps chosen by the parent, nothing of the parent's reachable, a home for the programming course.

### Music, beyond the design

- **Reaper as a second DAW feature.** `vikix add reaper`, from reaper.fm, pinned and checksummed as Ollama is; the same OSC transport commands behind it, so the Lisp side doesn't care which DAW is listening. Ardour stays the default of `vikix add music` because it's free and in Void.
- **Carla is not in Void** (checked 2026-10-03): TODO item 22 names it; Ardour hosts LV2 itself, so drop Carla or build it from source.

### Website notes (vikix.dev, reviewed 2026-10-03)

Fixes agreed and briefed to an agent: the agent transcript and nav overflow on phones, the hero screenshot unreadable at phone width, the name repeated three times before the pitch; the AI feature list cut to three headline items with the rest folded; the Void material moved to its own page; the `llm` commit-message demo replaced or dropped; a FAQ entry on Swank that says what's true (localhost only, `~/.slime-secret`, the auth deadline in `swank-guard.lisp`), since the earlier draft of that entry wrongly said there was no authentication.
