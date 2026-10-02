# Ideas

Ideas for Vikix that nobody has decided to build yet. When one is picked up, it moves to `TODO.md` (worked out properly there: what, why, what it touches) and is deleted from here. Nothing here is a promise, and no package name here has been checked against void-packages.

Gathered on 2026-09-30, in a conversation with Vid.

## Software Void doesn't have

- **Flatpak as a feature.** The easy route to apps Void doesn't package (Obsidian, Zoom, Spotify, Signal), each somewhat walled off from the rest of the system. `vikix update` would update them too.
- **Distrobox.** An Ubuntu or Arch system inside Vikix, sharing the home folder, for anything that only ships as a .deb or for Arch. The safety net.

## Working on projects

- **A project switcher** on Super+p. Pick a project (from `~/dev`, or the vault's projects) and Vikix opens its saved layout (wish list: save and restore layouts), the editor, a terminal in its folder, and optionally the agent.
- **Per-project settings with direnv.** Entering a project's folder sets its tools and settings; leaving undoes them.
- **`vikix today`.** An end-of-day summary from the day's commits, captured notes (the notes plugin) and time per project: a work log written by the machine.

## AI

- **Ask about the screen.** Drag over any area (a chart, an error dialog, a PDF page) and ask about it: `s-i` for pictures, with a vision model.
- **Voice commands.** Hold a key and say "put Firefox on workspace 3" or "open the Vikix project": the dictation already there, then the agent acting through the MCP server.
- **Meeting notes.** Record a call, transcribe it locally, then a summary and action items. Only with everyone's consent, and the screen says a recording is running.

## Everyday business

- **A password manager.** KeePassXC or `pass`, with a rofi picker that types the password, and one-time 2FA codes.
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
- **An order, smallest and most useful first:** 1. install Lem, Nyxt, McCLIM (done, 0.69.0); 2. an **image viewer** (thumbnails, zoom, tags, renaming, all scriptable; could replace nsxiv); 3. a **file explorer** built on presentations, the showcase; 4. a **launcher and menu** in Lisp, replacing rofi and joining the key help and the plugins; 5. a **video player**, a Lisp front-end on mpv; 6. the text editor stays Lem or Emacs, extended rather than rewritten.
