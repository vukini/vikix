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
