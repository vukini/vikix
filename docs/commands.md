# The commands

Every `vikix` command: its forms, what each does, and the files it keeps. This page is made from the header each command's script starts with (`lib/man.py --guide`): the lines its `-h` prints, and the ones its man page is made from (`man vikix-backup`), so the three always say the same. Nobody edits it by hand.

`vikix` is the one you type, and most of the others are reached through it: `vikix backup` runs `vikix-backup`. A few are what the desktop itself runs: the bar's fields, the session, the lock.

- [vikix](#vikix): the everyday command
- [vikix-agent](#vikix-agent): an AI agent in this terminal, after a snapshot of your files
- [vikix-agents](#vikix-agents): the agents at work on this desktop, in one place
- [vikix-ai](#vikix-ai): AI services on Vikix: keys, and local models
- [vikix-ask](#vikix-ask): AI on the text you selected, anywhere on the desktop (Super+i)
- [vikix-back](#vikix-back): where you were, when you come back to the laptop
- [vikix-backup](#vikix-backup): your home folder, backed up with restic
- [vikix-battery](#vikix-battery): warn on low battery and suspend before it runs out
- [vikix-bitwarden](#vikix-bitwarden): your Bitwarden vault on the desktop
- [vikix-bt](#vikix-bt): Bluetooth as one short line, for the mode line
- [vikix-cuis](#vikix-cuis): Cuis Smalltalk as a Vikix program
- [vikix-day](#vikix-day): the day as the desktop saw it, kept as a diary
- [vikix-debug](#vikix-debug): one file that says what's going on, to attach to an issue or hand to an agent
- [vikix-dictate](#vikix-dictate): speak, and it types what you said
- [vikix-docs](#vikix-docs): every document on the machine in one catalogue, found from one key
- [vikix-docs-open](#vikix-docs-open): open guides, tutorials and offline docs in the docs browser
- [vikix-door](#vikix-door): the Lisp agents sent that the door held, and what passes
- [vikix-drives](#vikix-drives): USB drives: mounted when plugged in, ejected from a menu
- [vikix-dropbox](#vikix-dropbox): Dropbox as one short line, for the mode line
- [vikix-esploro](#vikix-esploro): Esploro, Vid's file explorer
- [vikix-eval](#vikix-eval): run Lisp inside the running StumpWM and print the result
- [vikix-features](#vikix-features): what you add to Vikix beyond the base
- [vikix-fingerprint](#vikix-fingerprint): a fingerprint for sudo and the lock screen
- [vikix-firewall](#vikix-firewall): the firewall, ufw
- [vikix-firmware](#vikix-firmware): firmware updates from LVFS, through fwupd
- [vikix-font](#vikix-font): the one font file StumpWM draws its bar, menus and messages in
- [vikix-gestures](#vikix-gestures): a three-finger swipe on the touchpad moves the focus
- [vikix-grok](#vikix-grok): local task briefs and reviewed results for Grok Bot
- [vikix-hype](#vikix-hype): Hype, Markdown presentations with a visual slide editor
- [vikix-idle](#vikix-idle): what happens when you leave the computer alone
- [vikix-image](#vikix-image): open an image in nsxiv together with the rest of its folder
- [vikix-jupyter](#vikix-jupyter): JupyterLab in `~/dev`, with the Python that 67-dev set up
- [vikix-keyboard](#vikix-keyboard): apply the layout and options in `~/.config/vikix/keyboard`
- [vikix-lazarus](#vikix-lazarus): start Lazarus: the docked IDE that 65-languages builds in `~/.lazarus`
- [vikix-learn](#vikix-learn): courses in the terminal
- [vikix-ledger](#vikix-ledger): what left this laptop, by program and destination: the outbound ledger
- [vikix-lisp-apps](#vikix-lisp-apps): programs written in Common Lisp, and programmable in it, as StumpWM is
- [vikix-local-ai](#vikix-local-ai): AI models that run on this machine, with Ollama
- [vikix-lock](#vikix-lock): lock the screen, with only ever one locker
- [vikix-mcp](#vikix-mcp): the Vikix desktop as an MCP server, for any agent that speaks MCP
- [vikix-memory](#vikix-memory): what uses the memory, what's left over, a warning when it runs low
- [vikix-music](#vikix-music): a Lisp musical sketchpad, with SuperCollider making the sound
- [vikix-net](#vikix-net): the network link as one short line, for the mode line
- [vikix-network](#vikix-network): the Network Office: nearby devices, ports and connections
- [vikix-nightlight](#vikix-nightlight): a warmer screen in the evening (gammastep)
- [vikix-node](#vikix-node): a remote Void machine as a node of this Vikix
- [vikix-notes](#vikix-notes): ask your notes, from any terminal (`note` for short)
- [vikix-notifications](#vikix-notifications): the notifications dunst has put away, in rofi, newest first
- [vikix-obsidian](#vikix-obsidian): an Obsidian vault, converted to Org notes, a folder at a time
- [vikix-osd](#vikix-osd): change volume or brightness and show a bar for it
- [vikix-palette](#vikix-palette): everything in one box (Super+Space)
- [vikix-pkg](#vikix-pkg): single programs, beyond the features
- [vikix-plugin](#vikix-plugin): small additions to Vikix, from the vikix-plugins repo
- [vikix-project](#vikix-project): your projects, each a folder with a log.md
- [vikix-publish](#vikix-publish): books from Markdown
- [vikix-record](#vikix-record): record the screen to a video, without sound
- [vikix-records](#vikix-records): where plugins keep what they found, to search and use later
- [vikix-rescue](#vikix-rescue): a way out when the desktop is stuck
- [vikix-resume](#vikix-resume): your windows back after a restart
- [vikix-rofi](#vikix-rofi): rofi's plugin modes, set up the Vikix way
- [vikix-rules](#vikix-rules): the desktop's rules, seen and steered
- [vikix-screens](#vikix-screens): the screens: a new one lights up by itself, and a menu for the rest
- [vikix-screenshot](#vikix-screenshot): keep a picture of an area, a window or the whole screen
- [vikix-session](#vikix-session): everything that runs for the length of a desktop session
- [vikix-steam](#vikix-steam): Steam, with everything a game needs on Void
- [vikix-theme](#vikix-theme): the colour theme, everywhere
- [vikix-times](#vikix-times): how long the desktop takes
- [vikix-updates](#vikix-updates): what `vikix update` would bring
- [vikix-used](#vikix-used): what gets used: the keys you press and the commands you run
- [vikix-versions](#vikix-versions): every version of a file, from both histories, and one brought back
- [vikix-vm](#vikix-vm): virtual machines: every one libvirt has, in a menu
- [vikix-voice](#vikix-voice): talk to the AI, and it talks back
- [vikix-wallpaper](#vikix-wallpaper): the picture behind the windows
- [vikix-wallpapers](#vikix-wallpapers): more wallpapers: Vid's collection, a git repository
- [vikix-webapp](#vikix-webapp): a website as a program of its own
- [vikix-welcome](#vikix-welcome): the welcome: first steps on a new desktop, in a terminal, each ticked off once done
- [vikix-what](#vikix-what): what is this? A part of the running computer, on a card
- [vikix-why](#vikix-why): why did that happen? What the desktop did lately, and what made it
- [vikix-wifi](#vikix-wifi): Wi-Fi: pick a network from a list that is scanned first
- [vikix-windows](#vikix-windows): Windows in a VM, for the programs that only run there

## vikix

The everyday command.

- `vikix update` — pull Vikix, update Void, add new packages and their services, refresh config links, pull the editor configs, run new migrations, reload StumpWM, and upgrade your pipx, uv and cargo programs
- `vikix update core|system|tools` — one part: Vikix only (seconds), Void's packages only, or the editors, languages and tools
- `vikix try [DESK]` — the desktop runs a desk's work before it is released: `~/vikix` is put at the desk's last commit and the core update's steps run; DESK is a desk's folder, topic or branch, none the desk this shell is in (vikix try help)
- `vikix try off|status` — back to main now; what the desktop runs
- `vikix migrate` — run only the migrations not yet applied
- `vikix rebuild-wm` — rebuild the StumpWM executable (after a Quicklisp update)
- `vikix docs find WORDS` — every document on the machine, searched: Vikix's guides, your projects and notes, man pages, manuals (Super+F2; vikix docs help for the rest)
- `vikix docs get` — download the offline programming docs into `~/dev` (a few GB, slow; update and the installer skip them)
- `vikix doctor` — check the pieces are all there
- `vikix screens [extend|mirror|external|laptop|pick]` — the screens: a plugged one lights up by itself; this lays them out otherwise (Super+Ctrl+p)
- `vikix wifi [list|scan]` — Wi-Fi: pick a network from a list scanned first
- `vikix network [status]` — Network Office: nearby devices, ports and connections
- `vikix nodes [--last]` — your other machines as nodes of this Vikix: each asked over SSH, online or not, what runs there
- `vikix node add|remove|status|shell|run NAME ...` — a node: a Void machine reached by key; a shell or a command there (vikix node help)
- `vikix tray [on|off|status]` — a tray at the bar's end: network and Bluetooth icons (nm-applet, blueman-applet); alone it switches, as Super+m's Tray does
- `vikix memory [left|clean]` — what uses the memory, biggest first, and the programs left over (hidden screens, tests nobody ended); clean ends those; a warning comes by itself when memory runs low (vikix memory help)
- `vikix rescue [free|undo|lock]` — when the desktop is stuck: how it is and what it is doing; free = out of a loop (rules paused, focus on clicks, a fresh event loop); works from a text console too (vikix rescue help)
- `vikix resume [now|save|ask|always|never]` — your windows back after a restart: what is saved, bring them back now, and whether a login asks first (vikix resume help)
- `vikix used [never|all|forget]` — what gets used: the keys you press most, the menu entries and commands, and the keys you never have; names and counts only, kept on this machine (vikix used help)
- `vikix times [measure|soak]` — how long logging in and a reload take; measure = on a hidden screen: start, reload, a key, an Emacs frame, StumpWM answering, against limits; soak = an hour of it worked hard (vikix times help)
- `vikix features` — what you can add (languages, editors, LibreOffice, printing, Windows, local AI ...), and what you have
- `vikix add NAME...` — add features, or a bundle (essentials, developer, everything); every update keeps them
- `vikix remove NAME...` — stop keeping them, and uninstall what only they needed (it shows the list and asks first)
- `vikix pkg add|drop|list` — single programs: search and install, or uninstall (and keep out); vikix pkg help
- `vikix welcome [add]` — the first steps (it opens by itself at the first login): add software, keys, theme, keyboard, guide
- `vikix theme [NAME]` — the colour theme, everywhere: the current one and the list, or switch to NAME
- `vikix theme import URL|OWNER/REPO [NAME]` — an Omarchy theme as one of yours, then switch to it (vikix theme --help)
- `vikix version|-v|--version` — the version you have (the checkout's VERSION)
- `vikix layout save NAME | NAME [--no-start] | list | rm NAME` — this workspace's layout (its splits or its strip, and which window is where) saved, put back (the windows it had that aren't open started, unless --no-start), listed, removed
- `vikix rules [off|on|forget N] [why [CLASS]] [test|apply [N]] [verbs|now|proposed]` — the desktop's rules: the list, one off or on, why a window is where it is, what they'd do with the windows open now, and doing it; forget takes one out of your rules.lisp (vikix rules help)
- `vikix door [run N|drop N|check FORM|allowed]` — the Lisp an agent sent that the door held for you: run one as you, drop it, see what passes (vikix door help)
- `vikix why [N]` — why did that happen? the last things the desktop did (a key and its command, a rule and its window, the menu, an agent) and where each is written (Super+?)
- `vikix what [KIND] [NAME]` — what is this? the bar's field under the pointer or the window in front, or a thing by name (a field, a key, a process, a service, a package, a command, a file): what it is doing now, what such a thing is, and where it is explained: your own chapters first (Super+Alt+?)
- `vikix viri [on|off]` — this workspace as a strip that scrolls sideways (Super+h/l along it), or tiled again; no word switches
- `vikix gestures [on|off]` — three fingers swept on the touchpad move the focus, as Super+h/j/k/l do; alone: how it is
- `vikix eval FORM` — run Lisp in the running StumpWM, print the result
- `vikix debug` — one file saying what's going on, secrets taken out, to attach to an issue
- `vikix diagnose` — that report, handed to your AI agent: what's wrong?
- `vikix dictate setup|models|file|status|uninstall` — speak, and it types what you said (Super+F9), on this laptop
- `vikix voice setup|say|quiet|new|voices|status|uninstall` — talk to the AI (Super+F10) or the agent (Super+F11), and it answers aloud (Piper, on this laptop)
- `vikix notes setup|uninstall` — ask your notes from any terminal: note index `~/Notes`, then note ask "..." (vikix-notes; on this laptop)
- `vikix project [list|show|path|log|open|build|check|new] [NAME]` — your projects, each a folder with a log.md (in `~/src`): where each is and what's next; log NAME "what was done" adds today's entry; new NAME makes one (vikix project help)
- `vikix today [yesterday|DATE]` — what was done today across your projects (log entries and commits), and what's next
- `vikix back` — where you were: how long away, the project and its next step, Emacs's unsaved files, your last commands there, the last note; shown by itself when you come back after ten minutes away
- `vikix day [yesterday|DATE] [--week] [--for NAME]` — the day as the desktop saw it, kept as a diary in `~/journal`: how long each project had the screen, its entries and commits, files moved, agents' sessions; day log offers the missing log entries (vikix day help)
- `vikix learn [c]` — a course in the terminal: edit, save, it's checked (vikix learn c list, hint, go NN, reset NN)
- `vikix hype setup|status|uninstall` — Hype: Markdown slides with a visual editor, in your theme's colours (vikix add hype)
- `vikix publish [NAME] [epub|pdf|check|links]` — a book from Markdown: an EPUB checked for e-ink readers, and a PDF (vikix add publish)
- `vikix wallpapers setup|update|status|uninstall` — Vid's wallpapers, in the Super+m picker (vikix add wallpapers)
- `vikix obsidian [convert FOLDER...|--all] [report FOLDER]` — an Obsidian vault into Org notes, a folder at a time, links kept (`~/Dropbox/notes/vault`)
- `vikix records search|list|get|export|forget|stats` — what plugins found and kept (flights, meetings, plan use ...), searchable (vikix records help)
- `vikix grok new|list|show|prompt|claim|result|fail|accept|cancel|status|instructions` — local briefs and reviewed results for Grok Bot
- `vikix plugin list|add|remove|off|on|safe|status` — small additions from the vikix-plugins repo: bar words, Super+m entries, keys (vikix plugin help)
- `vikix bitwarden setup|pick|lock|sync|status|uninstall` — your Bitwarden vault: Super+Alt+v types a password into any window (vikix add bitwarden)
- `vikix lisp-apps setup|status|uninstall` — Nyxt, Lem and McCLIM's Listener: programs in Common Lisp (vikix add lisp-apps)
- `vikix esploro setup|status|doctor|uninstall` — Esploro, a file explorer in Common Lisp (vikix add esploro; Super+e)
- `vikix music setup|doctor|check|tone|play|repl|uninstall` — a first musical sketchpad: Lisp patterns and a quiet SuperCollider tone (vikix add music)
- `vikix cuis setup|rebuild|run|desktop|status|doctor|uninstall` — Cuis Smalltalk: a live image built from Vikix's packages, with a door for vikix eval --cuis (vikix add cuis)
- `vikix mcp register|unregister|tools|status` — the desktop as an MCP server, for Claude Code and other agents
- `vikix agent` — the AI agent, after a snapshot of your files (alias: a): Claude Code, or --use opencode|codex|gemini|antigravity|aider, --local on this laptop, --default NAME, --list; --exec [NAME] for editors (stdout is the agent's), --which
- `vikix agents [--json]` — the agents at work here: each one's folder, branch and uncommitted files, its workspace, how long it has run, and whether it works or waits for you
- `vikix agents desk [PROJECT [TOPIC]]` — start an agent at a desk of its own: a workspace to itself and a git worktree of the project on a branch of that name; resume takes a desk up again, close takes it down, handoff is its record (the task, the status, what is left), tell, pause, test and dismiss are for a worker: vikix agents help is the map
- `vikix snapshot [MESSAGE]` — record your files as they are now
- `vikix changes [ID]` — what changed since the last snapshot (or in snapshot ID)
- `vikix history` — the snapshots, newest first
- `vikix undo [ID]` — put your files back as they were one snapshot ago (or at ID)
- `vikix versions PATH` — every version of a file or folder, from the backups and the snapshots, newest first (vikix versions --help)
- `vikix restore PATH ID [--beside|--replace]` — bring one back beside the file as NAME (DATE).ext, or in its place through the Trash
- `vikix backup [now]` — back up your home folder with restic (vikix backup help: setup, status, list, restore, check, off)
- `vikix firmware [update]` — firmware updates from LVFS (BIOS, Thunderbolt, ...): what's waiting, or install it (on AC power)
- `vikix fingerprint [on|off|enrol]` — a finger for sudo and the lock screen, where fprintd supports the reader
- `vikix firewall [on|off|allow PORT|close PORT]` — the firewall (ufw): nothing comes in but SSH and the ports you allow
- `vikix ledger [today|DATE|PROGRAM|on|off|status]` — what left the laptop, by program and destination (vikix ledger --help)
- `vikix webapp add|open|list|remove` — a website as a program of its own (presets: fastmail, gmail, outlook, outlook-live, superhuman)
- `vikix ai setup|models|chat|list|remove|status|stop|uninstall` — AI models that run on this laptop (Ollama)
- `vikix ai llm` — the llm command, with those models and your keys
- `vikix ai use [local|claude|codex]` — the model for Super+i, AI on the selected text
- `vikix ai key set|list|remove|check` — API keys (`ANTHROPIC_API_KEY` ...) kept safely, out of your dotfiles and their history
- `vikix windows [setup|create ISO|stop|status|network|remove]` — Windows in a VM: set it up once, install it by itself, then open its desktop in a window (vikix windows help)
- `vikix windows app NAME [FILE] | apps [setup|add NAME|remove NAME|restore|forget]` — one Windows program in a window of its own, and the programs Windows has
- `vikix vm [list|start|open|pause|resume|save|stop|off|status NAME]` — every virtual machine libvirt has, yours and the system's, in a menu: its state, start, pause, save, shut down, open its screen (Super+m, Apps)
- `vikix steam [setup|status|uninstall]` — Steam, with the 32-bit libraries and the Vulkan driver your graphics card needs; Windows games too, through Proton (vikix steam help)

Each command has a man page with the whole of it: man vikix-NAME (man vikix is this list; man -k vikix lists the pages).

vk is the same command, shorter. A command can be given by the start of its name when only one begins so (vk upd), and so can the word after it (vk docs f runit); a command's start that fits several says which, unless the shortest of them starts all the others (vk vers is version, not versions). Tab completes them.

## vikix-agent

An AI agent in this terminal, after a snapshot of your files.

- `vikix agent [ARGS]` — your agent (Claude Code, unless you chose another); ARGS go to it
- `vikix agent --use NAME [ARGS]` — another one, this time: claude, opencode, codex, gemini, antigravity, aider
- `vikix agent --local [--model M]` — on a model on this laptop (Ollama): opencode, codex and aider can. Small models do little as agents, and a laptop CPU takes minutes per answer
- `vikix agent --mode supervised|autonomous|unrestricted [--use codex]` — how free Codex is this session (Codex only, for now): supervised, its sandbox narrowed to this folder and every step out of it asked of you; autonomous, the same sandbox, a reviewer of Codex's own answering those steps and the network on, what a worker at a desk gets when nothing says otherwise (mode= in `~/.config/vikix/office`); unrestricted, no sandbox and no approvals, for a VM or a container: typed each time, warned about, and refused in a project's own folder
- `vikix agent --default NAME` — the one Super+a starts
- `vikix agent --list` — the agents, which are here, and yours
- `vikix agent --ask TEXT` — start with this question (vikix diagnose)
- `vikix agent --exec [NAME] [ARGS]` — for editors: the same start (the guide, no keys, a snapshot), but nothing of Vikix's on stdout (it's the agent's: ACP talks over it), no questions, and an error if it isn't installed. NAME: yours when left out. Editors run e.g. vikix agent --exec gemini --experimental-acp
- `vikix agent --acp [NAME] [ARGS]` — the same, as an ACP agent (Agent Client Protocol: Neovim's CodeCompanion, Emacs's agent-shell, Zed): claude and codex through their adapters (installed with them), gemini and opencode as they are; aider and antigravity don't speak it
- `vikix agent --which` — the agent Super+a starts, one word
- `vikix agent --install NAME` — install one (its official installer, or
- `vikix agent --uninstall NAME` — for antigravity Google's release pinned and checked here; also vikix add/remove NAME), or take it away. For one you have, --install adds only what's missing (its ACP adapter, say)

An AI agent in this terminal, after a snapshot of your files (so whatever it changes can be seen with vikix changes, and undone with vikix undo). Super+a and `vikix agent` (alias: a) start it.

Every agent is told how Vikix works by the same guide: Claude Code and OpenCode read the Vikix skill (`~/.claude/skills/vikix`); the others read `~/.local/share/vikix/AGENTS.md`, made from that skill at each update and each start: linked as `~/.codex/AGENTS.md`, imported by a one-line `~/.gemini/GEMINI.md`, included by a rule file of Vikix's own for Antigravity CLI (`~/.gemini/antigravity-cli/rules/vikix.md`), given to Aider with --read; never over a file of yours.

Antigravity CLI (agy) is where a personal Google account signs in now: in June 2026 Gemini CLI stopped serving the free, AI Pro and AI Ultra accounts, and keeps working with a Gemini API key or a Code Assist licence from work. Both are here. Antigravity signs in in your browser at its first start and keeps the sign-in in the system keyring (/logout in it drops it); with modelProvider gemini in its settings it uses `GEMINI_API_KEY` instead, which it then keeps from vikix ai key.

What an agent doesn't get, so a prompt injection (a web page, a README it reads) can't use it: your API keys and other secrets from the environment (each agent signs in its own way; Aider has no login, so it keeps the model companies' keys; `VIKIX_AGENT_API_KEY=1` keeps them all), and your SSH agent, which after your first push would let it push as you (`VIKIX_AGENT_SSH=1` keeps it). This prevents accidents; it isn't a sandbox: the agent runs as you and can read your files.

Nor the marks a running agent leaves on its children (`CHILD_MARKS` below): an agent started from inside a Claude Code session (its Bash tool, the MCP server's office tool opening a desk) would take itself for a child of that session, and Claude Code then saves no transcript of it ("Transcript saving is off: inherited `CLAUDE_CODE_CHILD_SESSION` marker"; vikix agents resume finds nothing). A desk's agent is a session of its own.

Claude Code and Antigravity CLI also get the office's house rules: a hook that runs vikix agents touch before each edit, so two agents on one file are caught and a crossing into another agent's folder is recorded (see vikix agents). Claude Code gets it for the session; agy takes no such option, so for it the hook is a plugin of Vikix's (agy plugin list shows vikix), put in place at each start. `VIKIX_OFFICE=0` leaves it out, and for agy leaves the plugin as it is.

Codex gets three more things on its command line, for the session only (`~/.codex/config.toml` is yours and is never written). The repository's instructions: Codex reads AGENTS.md from the repository's root down to the folder, never CLAUDE.md, so a repository with only a CLAUDE.md (Vikix, most projects made with Claude Code) is given it as the file to fall back on, with Codex's cap raised to hold it whole; a repository with an AGENTS.md is read as its author meant. A mode (--mode above): at a desk (a git worktree) and in a folder of no repository (your home, where Super+a's "agent here" starts) the house default, mode= in `~/.config/vikix/office`, which Vikix writes as autonomous the first time; in a repository that isn't a desk (a project's own folder, a stranger's) Codex runs as your own settings say unless --mode is typed. (Until 0.72.50 the home session ran on `~/.codex/config.toml` alone, and a header out of place there, [section], had Codex read-only and asking for every write: vikix doctor and vikix agents hooks codex now say so.) The two sandboxed modes make this folder Codex's only writable root (your `writable_roots` are set aside for the session), so from a desk the project's own folder, `~/vikix` and the other desks are read-only to what Codex runs, and link Vikix's rules (`~/.codex/rules/vikix.rules`, through vikix agents hooks codex --install) which let a desk's day (git on its branch, the tests, vikix, the release) out of the sandbox without a prompt once Codex asks to (inside it a desk's .git and `~/.local/state` are read-only, so a commit or a handoff fails there; the worker's first prompt says so); Codex's own matching stops at the first word (timeout 20s vikix snapshot ... asked each time), so the house rules' hook on each step out of the sandbox (PermissionRequest) allows the same commands whatever wraps them. And trust for that hook: Codex runs a hook of yours only once you trusted it in /hooks, by its hash, which every release that changes the file undoes; when `~/.codex/hooks.json` is Vikix's and the folder is one of your projects (vikix project list) or no repository at all, the start passes --dangerously-bypass-hook-trust, since Vikix vets that file by making it; in a stranger's repository Codex's own prompt stays. `VIKIX_CODEX_HOOK_TRUST=ask` keeps the prompt everywhere.

## vikix-agents

The agents at work on this desktop, in one place.

- `vikix agents [--json]` — each agent running in a terminal here, and what it is doing. Which it is (claude, codex, opencode, gemini, antigravity, aider), the folder it works in with its branch and how many files it has left uncommitted there, its workspace, how long it has run, and what it is doing: working, at its prompt, finished its turn, or waiting for you (a dialog open, a question asked); under it, its window's title, or what it asked. An agent whose shell is held by a release (.claude/release) or by tests (tests/run.sh) says so instead: waiting for a release (its turn in the release queue), releasing (what step), waiting for a test slot (other runs are testing), testing. --json: the same for a script
- `vikix agents office [--tty]` — The Office: tasks, desks and handoffs, in Emacs. Go to an agent or continue a desk from it. On the desktop an Emacs frame of its own; in a terminal with no display (a server, SSH), or with --tty, it takes over this terminal through emacsclient -nw, and q gives the shell back. Either way it is your running Emacs (M-x server-start if needed): a second one is never started, and the Office open already comes to the front instead, from whichever workspace it is on
- `vikix agents clash [FILE]` — the files two agents are on at once. Each file with the agents that have changed it, uncommitted, in worktrees of one repository, or that have edited the same file; with FILE, each agent's change to it in full (both plans, one under the other), for you to say which stays
- `vikix agents crossings [--limit N]` — the last crossings recorded. An agent that edited a file in another agent's folder, or went to another agent's window
- `vikix agents tidy [--yes]` — the shells agents left sleeping in a loop, ended. A shell of an agent's given its command on the line (bash -c, as the agent's tool runs one) whose only child is sleep, for ten minutes or more: a loop waiting for a line that never comes, while the agent sits at its prompt. Listed by agent, then ended on yes (--yes from a script). vikix agents and the Office say how many each agent has; a loop the agent means to keep (a watch) looks the same, so nothing is ended unasked. vikix memory left lists them too, among the maybes
- `vikix agents help [COMMAND]` — the commands in short, or one of them in full. -h (and man vikix-agents) is all of it
- `vikix agents here [--use NAME] [--local]` — an agent in your home folder, with no desk. In a terminal on this workspace (Super+a, Agent here): it asks which agent, as desk does, when --use and --local don't say
- `vikix agents desk [PROJECT [TOPIC]] [--task "..."] [--acceptance "..."] [--use NAME] [--local] [--here] [--push] [--no-tests] [--mode MODE]` — make a desk: a worktree of the project, a branch, a record. In PROJECT (one of vikix project's, by any part of its name), a git worktree of the project made for it: the folder PROJECT-TOPIC beside the project, on a new branch TOPIC, so one agent's work can't collide with another's; a desk that is there is used again, not made twice. Nobody sits at it yet: vikix agents worker starts a worker there, on a task, and the desk keeps the history of its workers. --task "...": the shortcut that does both, the desk and a worker at it with that task; the agent's words (--acceptance, --use, --local, --here, --push, --mode) are worker's, and want a task here. Without PROJECT it asks which, then for a topic (a repository's desk is a worktree, so one is needed; a project that is no repository works in its own folder, with none), then for the task: nothing typed is the desk alone, a task the worker's questions after it. --no-tests: the desk's tests don't run by themselves when a worker hands in (vikix agents test runs them still)
- `vikix agents worker DESK ["..."] [--acceptance "..."] [--use NAME] [--local] [--here] [--push] [--no-tests] [--mode MODE] | --menu` — start a worker at a desk: an agent on a task there. DESK is the folder (`~/src/PROJECT-TOPIC`), the topic or the branch; the task in your words, written in the desk's record and given to the agent as its first prompt (aider takes none: it reads the record), on a workspace to itself. The desk's task and the worker's handoff before it go into its history whole (vikix agents handoff shows the workers before); the desk's own stay: the checks, the acceptance criteria, the decisions, the defects and the review findings, which the new worker's first prompt carries. Without a task, a session at the desk: an agent to talk with, the record left as it is. Refused while an agent is at the desk: vikix agents tell leaves it a note, dismiss ends it first. --acceptance "...": a criterion the work is judged by, once per line; the worker ticks them (handoff --done N) and the record shows 2 of 3; --use: another agent than yours (vikix agent --use); --local: on a model on this laptop (vikix agent --local; opencode, codex and aider can); --here: in this terminal, no new workspace; --push: the agent may push as you: your SSH agent goes with it (vikix agent keeps it back otherwise, since after your first push of the day it holds your unlocked key), so git push works at the desk; --no-tests: the tester doesn't run by itself when this worker hands in (status review); a worker started without it has the tests again; --mode supervised|autonomous|unrestricted: how free the worker is (Codex's, for now: vikix agent -h says what each is; the house default, mode= in `~/.config/vikix/office`, when unsaid), kept in the record and shown in the row. The Office has both desk and worker as a form, with these as boxes to tick. --menu, from Super+m or the desk key w: the desk picked in rofi, then the task typed (nothing for a session), then which agent and whether it may push, as desk asks them
- `vikix agents resume [DESK] [--use NAME] [--here] [--fresh] [--another] [--mode MODE] [--prompt "..."]` — take a desk up again, its conversation resumed. Its handoff, git state and checks shown, then an agent started there, its conversation resumed where it can be (--menu, from the desktop: pick the desk in rofi). A session the record names, which the provider's store still has, is resumed (claude --resume ID, codex resume ID, opencode --session ID, agy --conversation ID); else a fresh conversation, and why is said. Refused while an agent is at the desk (--another: a second one). --require-saved refuses a fresh fallback if the saved conversation is no longer available; --expect-session ID also refuses if the recorded conversation changed since the choice was shown; --mode as worker's (unsaid: the last launch's for the same provider, else the house default). --fresh at a desk with a task gives the agent the task, the handoff and the hand-in's fields as its first prompt; --prompt "..." gives a resumed conversation its next words (what tell --now and a review use to wake a worker at its prompt)
- `vikix agents handover DESK --to NAME [--task "..."] [--mode MODE] [--now] [--here]` — pass a desk from its agent to a fresh one of another provider. Claude's design to Codex's hands, or the other way: the agent at the desk is asked for its handoff in a note (for it alone) and given up to two minutes to write it (not one at its prompt, which reads no note), dismissed, and the next started with resume --use NAME --fresh on a task of its own: --task, or the record's next step as the agent left it; never the task as it stood, which was the last agent's ("design, no code" became Codex's orders once), and refused when neither says. The task before, with the agent's handoff whole, goes into the desk's history; the desk's fields stay (acceptance, decisions, defects, findings, what changed, the commits), and the next agent's first prompt is its task, those, and the last agent's account; the record logs "handed over: claude -> codex" and keeps both sessions, so resume with either finds its conversation. Refused while the agent is mid-turn (an edit or a command in the last minute), unless --now; --mode as worker's
- `vikix agents close [DESK] [--force]` — close a desk whose work is in. Its worktree is removed and its branch deleted. DESK is the folder (`~/src/PROJECT-TOPIC`), the topic or the branch, or PROJECT TOPIC; without one it asks which on the desktop, or lists them. Refused while an agent still works there, or with files uncommitted; a branch not merged yet is kept and said. --force: uncommitted files and the unmerged branch are thrown away
- `vikix agents sit [PROJECT [TOPIC]]` — take a desk without being started again. For an agent, from its own shell: the worktree PROJECT-TOPIC is made (or the one there used), and the agent that runs this is seated at it: from then on the house rules take that folder as its own, and vikix agents shows it there. Without PROJECT, the desk the agent's folder is in. A repository's desk is a worktree, so TOPIC is needed for one; a project that is no repository seats the agent in its folder
- `vikix agents handoff [DESK] [--json]` — the desk's record: task, status, what was done, what is left. Also the checks with whether each still speaks for the code (stale once the code moved on), the git state now, the sessions that can be resumed, who is at the desk and what holds the rules for each. DESK as for close; none: the desk you sit at
- `vikix agents handoff [DESK] [--status S] [--estimate "..."] [--summary "..."] [--next "..."] [--task "..."] [--from FILE|-]` — set the record's task, status, estimate, account or next step. The user's task; the agent's status (working, waiting, review, finished, parked), its account of changes and decisions, what is left and the next action; --estimate how long the work will take from now, barring a major issue (40 min, 2 h 30 min, 1.5 h; what it assumes may follow after a comma), which the record and the listing then count down; --from takes the same as JSON (task, status, summary, next, estimate, check {name, ok, note}, session {provider, id}, and the hand-in's fields below by their names, done, `defect_done` and `review_done` with a number). Each line says who wrote it. "handoff set", and --desk DESK, are the same
- `vikix agents handoff [DESK] [--acceptance "..."] [--done N] [--defect "..."] [--defect-done N] [--review "..."] [--review-done N] [--decided "..."]` — the hand-in: criteria, defects, findings, decisions; each signed. --acceptance, once per criterion, is the list the work is judged by (yours, with the task: worker, desk --task and a plan file's acceptance take it too); the worker ticks one with --done N, and the record shows 2 of 3. --defect adds a known defect or limit, --defect-done N closes one; --review adds a finding (a reviewer's, or yours; "FILE:LINE the words" keeps where), --review-done N marks it addressed; --decided adds a choice made, a line, so the next worker doesn't reopen it. What changed against the base (where the branch left the project's own) and the commits past it are read from git at every write and at the tester's run, signed vikix, never typed. Fifty of each are kept
- `vikix agents handoff check NAME --ok|--failed [--note "..."] [--desk DESK]` — a check that ran (the command), and whether it passed. Kept with the commit it ran on and whether the tree was dirty, read by Vikix
- `vikix agents handoff session PROVIDER ID [--desk DESK]` — a conversation that can be resumed at this desk. Claude's session id, codex's thread, opencode's session; Claude Code's is noted by the hook itself
- `vikix agents handoff list [--json]` — every desk with a record, newest change first. --menu, from Super+m: pick one, read it in a terminal
- `vikix agents handoff forget [DESK]` — remove the record of a desk whose worktree is gone. Released, or closed: the Office's Closed group for a day, then its Archive, one at a time. Refused while the folder stands (close it) or an agent is still in it. Nothing else goes: no file, no branch, no saved conversation. Without DESK: the records that could be forgotten
- `vikix agents queue [--json]` — queue order, capacity, the next eligible task and every blocker. Read-only. Automatic starts default off; set auto=on in `~/.config/vikix/office` to opt in, `at_once=2` by default
- `vikix agents queue add TASK [--first]` — queue a ready task, last or first within its priority
- `vikix agents queue next TASK` — run this queued task next, ahead of every priority
- `vikix agents queue up|down TASK` — move one place within its priority
- `vikix agents queue defer TASK [--later]` — return to ready, or backlog with --later
- `vikix agents queue start [TASK]` — start one eligible task now, with its recorded worker choices
- `vikix agents queue pause|go` — hold or resume the scheduler; workers keep their state
- `vikix agents queue bump TASK --over DESK` — pause DESK's worker and start TASK at a different desk
- `vikix agents queue tick` — process a scheduler event; starts only with auto=on
- `vikix agents task new PROJECT TOPIC "task" [--use PROVIDER] [--priority LEVEL] [--after TASK]` — make a ready task without opening a desk or starting a worker
- `vikix agents task priority TASK critical|high|normal|low` — change priority independently of queue order; user only
- `vikix agents task cancel TASK ["why"]` — cancel the task; a worker already running is not stopped
- `vikix agents task ready TASK` — make a deferred or blocked task ready and approved; no worker starts
- `vikix agents tasks [--json] [--all] [--sort KEY]` — the task board in text: every task, a record of its own, apart from its desk and its agent. A task is made by every way work comes into being (desk --task, worker, sit --task, handoff --task, the Office's forms, a plan) and kept for life in `~/.local/state/vikix/office/tasks/ID.json`: its id, who made it (yours, an agent's, a plan's; unknown for a record from before), its priority, when it was created, launched and done, the number of each launch (the order the workers were started in, office/sequence), the agent's handoff as it stood, and its state, which moves only by a named step: ready, running, needs decision (the agent's waiting), needs review, blocked (on its worker, when it stopped; on the tests; parked), ready for release (the agent's finished: its work is done, yours is not), completed (the release, the desk closed with its branch in) or cancelled. The board is the Office's sections: Needs attention, Running (a row a task: its launch number, provider, desk, how long, its state in a word, its words), Queue (in queue order, with why each waits), Blocked (on what), Completed (the last day's, with the release; --all: every one), then the desks standing empty and the ones closed today. --sort orders Running and Completed: launch (oldest first), newest, created, activity, priority, status, project, provider. --json: the board as the Office reads it
- `vikix agents tasks adopt` — task records for the desks from before. One for each desk record's task and for each entry of its workers history, with what the record knew: who, when, the status read into a state; what it didn't know is null and shown as unknown (the launch order, for one), never made up. Run once by an update; safe to run again
- `vikix agents task ID [--json]` — one task's page, with its history. Its metadata (origin, priority, desk, the launch with its number, the times), its words, the handoff as the desk's record had it, every launch, then its history from the event log, newest first. ID is the task's, or a desk's name for the desk's task
- `vikix agents office --answer ID TEXT` — answer a decision (the user's action)
- `vikix agents office --accept DESK` — accept a review after fresh passing tests
- `vikix agents office --back DESK TEXT` — send a review back with feedback
- `vikix agents office --release DESK TEXT` — open its release in a terminal
- `vikix agents office --new-task PROJECT "task" [--desk FOLDER | --topic TOPIC] [--priority LEVEL] [--after ID]... [--use NAME] [--local] [--push] [--no-tests] [--mode MODE] [--queue]` — the Office's New task form: a task record, ready, at a desk that stands (--desk: its record names the task, the project is the desk's, PROJECT may be -) or with the topic of the desk to make; --queue puts it in the queue at once. Nothing is started: the scheduler does that on your word
- `vikix agents ask QUESTION [--choice "label: consequence"] [--recommend LABEL]` — register a decision at your desk; repeat --choice; --context TEXT and --reason TEXT explain it, --blocks waits on this choice; --desk DESK for the user
- `vikix agents ask --wait ID` — wait up to ten minutes for a decision's answer; `VIKIX_ASK_LIMIT` sets seconds (0 to 600), exit 3 if none
- `vikix agents answer ID TEXT` — the user answers with a choice label or free text
- `vikix agents attention [--json | --menu | --notify]` — questions, failed tests, reviews and stopped workers; --notify tells each item once, --menu opens the list
- `vikix agents events [TASK | DESK | --all] [--since WHEN] [--limit N] [--json]` — the office's event log, newest first. One line an act (a task created, launched with its number, a hand-in, a check, blocked, exited, released, completed, adopted, ...), a file a month in `~/.local/state/vikix/office/`, appended and never rewritten; a task's, a desk's, or all (--all); none named: the desk you sit at. --since 2h, 30 min, 3 days or 2026-10-10; --limit N (100)
- `vikix agents tell DESK "..." [--now] | --menu` — a note for the desk's agent, at its next tool call. Delivered by Claude Code's and Codex's hooks (another agent reads it in vikix agents handoff, and resume reads it out); said when the agent is at its prompt, since it makes none until you speak to it. --now: an agent at its prompt is woken with the note as its prompt (asked to exit, its conversation resumed with it; the record logs "woken"), and when it can't be (working, two at the desk, no conversation to resume, no desktop) why is said and the note waits. A note is for whoever works the desk, now or next; what dismiss and handover leave is for the one agent they address, and a worker never gets a note from before it started unless it is yours. DESK as for close
- `vikix agents pause DESK [--hard] | --menu` — hold the desk's agent at its next tool call, until go. It waits with its context whole and at no cost, for ten minutes at most, after which the call is refused with why and the turn ends, go then waking it. --hard freezes the agent's process this instant instead (SIGSTOP; for an agent with no hook, or an emergency: a request in flight may time out)
- `vikix agents go DESK` — let a paused agent go on, told it was paused and to carry on where it was (SIGCONT after --hard). One whose turn the pause ended at its limit sits at its prompt, making no call for the lifted pause to go through: it is woken as tell --now wakes one, asked to exit and its conversation resumed with the words to carry on where it was (the record logs "woken"); when it can't be (two at the desk, no conversation to resume, no desktop) why is said and the words wait in its inbox, read at its next tool call
- `vikix agents park [DESK] [--next "..."]` — keep the desk aside, to be started later. Its status becomes parked, signed by you (or by the agent that runs it), and the Office lists it under Parked however its agent left it: a question it asked stays in the Next line, which --next replaces. Nothing is stopped: an agent still at the desk goes on, and the desk counts as working until it is gone. A worker started there, or any status written, takes it up again. DESK as for close; none: the desk you sit at
- `vikix agents reconnect [DESK | --all] [--wait]` — an agent the network stopped, taken up again now it is back. Claude Code gives a request up after its own retries when the network is down, and ends the turn with an API error; until now you typed "continue" once the network was back. Now a watcher follows each Claude Code at a desk (started by its hook at its first tool call), sees the turn end that way, waits for the API's host to answer again, and wakes the agent as go does: its conversation resumed with the words to carry on where it was; the listing says "stopped by the network" meanwhile, and the record logs it. This command does the same by hand, for one desk or every one with an agent: nothing when the agent's last turn wasn't ended by the network, or the user went on already; --wait waits for the network here. Only an agent at a desk, and only Claude Code (its transcript says how a turn ended; Codex's doesn't)
- `vikix agents turns DESK on|off` — take turns on a file instead of asking you. With turns on, an edit of a file another agent has changed, uncommitted, waits for that agent's commit (ten minutes at most, then it asks); two waiting for each other is seen, and the later one asks you at once
- `vikix agents test [DESK | --all | --menu] [--log DESK] [--skip DESK]` — the tester: the tests a desk's changes reach, run for it. Its project's tests/run.sh, --changed from where its branch left the project's own, run in its worktree through the runner's queue, and after a release's tests (.claude/release) when one is testing; the result goes into its handoff as a check by vikix, with the failing tests named, and into its inbox, so the worker fixes its own failures. A desk set to review runs this by itself, once per hand-in. --all: every desk in review; those that changed no file in common are merged onto the project's own branch in a throwaway worktree and tested together once (passing alone and failing together is what a batch is for), the overlapping ones each alone, told which it overlaps; a merge that conflicts sends that desk to run alone. --log: the last run's output. --skip: the tests running at the desk not waited for: the tester is ended, the runner and its tests with it, and the record gets a check marked skipped on the commit as it stands (a plan's chain goes on from the hand-in; the release never counts it, and runs its own); the worker is told in its inbox. The Office's Skip tests, on the row of a desk whose tests run
- `vikix agents review DESK [--use NAME] [--prompt "..."] [--here] [--log DESK] | --menu` — a review by another provider, read-only, its findings into the handoff. The desk's last commit is checked out in a throwaway worktree, and the reviewer (--use codex or claude; unsaid, the one that isn't the desk's) reads it there with no window and no way to write (codex exec -s read-only, claude -p --permission-mode plan), given the task, the criteria, the decisions and the worker's account, and asked for findings in one shape; the worktree is removed after. It runs apart from this shell, as a hand-in's does (a review read here under a timeout once orphaned the reviewer and lost its findings), and says so; --here waits for it. Each finding goes into the handoff's Review signed by the reviewer (codex 1234), and a line into the desk's inbox; a worker at its prompt is woken with that line as its prompt (its conversation resumed, as tell --now does), one at work reads it at its next tool call, and when it can't be woken the desktop is told; the worker marks each finding addressed with handoff --review-done N, and the reviewer never sits at the desk. vikix agents and the Office say reviewing while it runs. --prompt: more words for the reviewer (what to look at). review=codex in `~/.config/vikix/office` starts one by itself at each hand-in (status review); off by default, since a review costs a model's time. --log: the last review's words. --menu: the desk and the reviewer in rofi
- `vikix agents plan new TEMPLATE NAME PROJECT [--at-once N] [--gate me|none]` — a plan written from a template, for you to edit and run. The copy goes to `~/.config/vikix/plans/NAME.toml` (NAME with a slash, or ending .toml, is the file itself) with PROJECT, and at-once and gate when given, filled in, each desk named for the plan (the template's "topic", "topic-one"... become NAME, NAME-one...), and the template's comments kept, so the file explains itself. The lines beginning EDIT: are yours to write; plan run refuses a task still holding one. Until it has run it is a draft, which plan status lists and the Office's Plans box shows with its Run. The Office's New plan… is this as a form, with the template's tasks as its fields
- `vikix agents plan templates` — the plan templates: Vikix's (config/plans) and yours. Yours are `~/.config/vikix/plans/templates/*.toml`, a plan each whose first line is "# NAME — what it is for", with PROJECT where the project goes, topic in each desk's name and EDIT: on the lines to write; one of yours with a Vikix name stands in for it
- `vikix agents plan run FILE [--here | --once]` — a plan file's tasks run as workers at desks, in order. FILE is TOML: project, at-once (workers together, 1), gate ("me": a desk's release waits for your yes), then a [[task]] each with name, task (the worker's words), desk (the topic; the name when unsaid), after (the tasks it builds on) and the worker's choices as the New worker form has them (agent, local, push, no-tests), and release (the release's line). Tasks at one desk are its workers in turn, on one branch: the next starts once the last has handed in and its tests pass, and reads the handoff it left; the desk is released once, at the chain's end, with the project's .claude/release. Tasks at different desks run side by side; a task after one at another desk waits for that desk's release and starts at a fresh one. The runner is a script: it edits no file, answers no prompt, never puts two workers at one desk, never merges or pushes (gup stays yours); a worker that handed in is dismissed once its tests are in. A round that fails (tests, or the worker left) starts the next, told why in the inbox; the third stops that desk under Needs you, as a release that fails does. It works its state out each time from the plan file and the desk records, so a reboot loses nothing and running it again carries on; it wakes on the office's event log. Run again, a paused or stopped plan goes on. It runs apart from this terminal; --here keeps it in it, --once looks and acts one round and ends
- `vikix agents plan status [PLAN]` — where each plan stands: a line a desk, a line a task, what needs you. PLAN is its file or its name; none: every plan that has run, then the drafts not run yet. A file not run yet is read and shown, which checks it
- `vikix agents plan pause PLAN` — nothing new starts and no release goes; the workers at work carry on
- `vikix agents plan stop PLAN` — the runner ends; the workers at work carry on. plan run FILE carries on from where it stands
- `vikix agents plan release DESK` — your yes to the desk's release, when the plan's gate is me. Also tries again after a release that failed
- `vikix agents plan log PLAN` — what the runner did, in order
- `vikix agents dismiss DESK | --menu` — ask the desk's agent to exit, and keep the desk for later. Its branch and files stay (vikix agents resume): the Office's Close agent, from the terminal. A note first, "dismissed: write your handoff if you can", for that agent alone, which one mid-turn reads at its next call and no later agent ever does; the record notes the dismissal and the files left uncommitted. Never your own process. --menu, on each of these: the desk picked in rofi, and for tell the note typed there; the desks' map, Super+Alt+d: t test, p pause or go, i tell, x dismiss
- `vikix agents hooks [PROVIDER] [--install]` — what holds the house rules for each agent program. Claude Code's hooks, given at each start; Codex's (seen firing here, 2026-10-10) and OpenCode's as adapters --install links into their folders; Gemini's a snippet to merge by hand; Aider none. Instructions only, where no hook is. For Codex also what is wrong in `~/.codex/config.toml`, when something is: a setting under a header Codex doesn't read
- `vikix agents desks` — every desk there is, one a line, for scripts. Tab-parted: its folder, its branch and the project's own folder (vikix try reads it; close says them in words)
- `vikix agents place [FOLDER]` — two words for the launcher: whether the folder's repository is one of your projects (known, unknown, none) and what the folder is in it (desk; own, the project's own folder; none). vikix agent reads them to pass Codex the hook's trust in your projects alone and to refuse --mode unrestricted in a project's own folder
- `vikix agents touch [FILE] [--for PROVIDER] [--pause-only|--escalation|--turn]` — the house rules for one edit: Claude Code's PreToolUse hook. Run before every Edit, Write and Bash, by Antigravity CLI's before each edit and command (vikix agent sets both), and by Codex's hooks (--for codex, from `~/.codex/hooks.json`: vikix agents hooks codex --install) before each `apply_patch`, read for every file it names, and each command; it reads the hook's JSON on stdin when no FILE is given, and answers in the shape of whichever asked (Codex's and OpenCode's take no ask: a clash is refused once, and the same edit within ten minutes goes through, the agent having told you). A file of a project's repository is refused unless the agent is at a desk (a worktree of its own: vikix agents desk or sit), and always in the project's own folder, which is for merging only; a Bash command that would write there (sed -i, a redirection, mv, git commit...) the same. An allowed edit is noted in the office journal; one in another agent's folder is a crossing, recorded and told to the agent; a file another agent has changed too makes Claude Code ask you first, naming that agent. No agent above it: nothing happens. --escalation is Codex's PermissionRequest hook, run when a command or a patch would leave its sandbox: one that would write into the project's own folder, `~/vikix`, another desk or `~/.config/vikix/secrets/` is denied, whatever the mode, with the reason; a routine one is allowed, so no prompt: the commands Vikix's rules file lets out (vikix snapshot and the other vikix commands, git on the branch, tests/run.sh, .claude/release), under timeout, env, nice, a VAR=value or bash -lc too, which Codex's own matching misses, every command of the line one of them; any other is left to you, or in autonomous mode to Codex's reviewer. --turn is Codex's UserPromptSubmit hook: a turn begun, noted in the journal, which is how the listing says working for an agent whose title says nothing
- `vikix agents stopping [--for PROVIDER]` — Claude Code's and Codex's Stop hook: a worker is asked once for its handoff. A worker, an agent at a desk with a task, that changed files in this turn and left the handoff unwritten is asked to write it before it stops (vikix agent sets Claude Code's hook; Codex's is in `~/.codex/hooks.json`). A stop let through is noted: the listing's "at its prompt" for an agent whose title says nothing; for Codex the agent-waiting plugin's note is written here too
- `vikix agents left [--for PROVIDER]` — Claude Code's and Codex's SessionEnd hook: how the agent left its desk. Exit, logout, dismissed, and the files left uncommitted, noted in the record for the next one at the desk (Codex says no reason: left)
- `vikix agents exited --code N [--task ID]` — the launcher's exit line: how the worker's process ended. Every worker's terminal runs its agent under this line (`agent_start`), so the exit code reaches the task's events whatever the provider, hooks or none: the task's last launch ends with it, and from running the task is blocked on its worker, never completed or cancelled by an exit. --task names the launch's task; else the desk this shell is in
- `vikix agents office --json` — the Office's snapshot for scripts: desks, live activity, handoffs. Unknown on failure; the checks with their freshness
- `vikix agents office --go PID` — go to that live agent through the desktop. Fails if it ended or has no desktop window
- `vikix agents office --close-agent PID START` — request an agent's exit, keeping its desk and files. START is `process_start` from the Office JSON snapshot
- `vikix agents office --forget ID` — forget one archived desk record by its id. As handoff forget does (the Office's "Forget this record")
- `vikix agents office --purge-archive TOKEN` — delete the archived desk records in the confirmed snapshot. TOKEN is its `archive_token`. Refused if records or live discovery changed; leaves project files and provider conversations alone
- `vikix agents office --form` — what the Office's forms offer, as JSON. The projects (name, folder, whether a repository, so a topic is needed, and the next step), the agents as vikix agent --list has them (yours first, which can run on a local model), whether a terminal can open here (a display), and for the New plan form the templates (plan templates), each with its settings and tasks as read, and the folder a plan goes to; for the New project form the projects' root, the logs folder, and the GitHub account gh is signed in as (null when it can't be asked)
- `vikix agents office --plan TEMPLATE NAME PROJECT [--at-once N] [--gate me|none] [--tasks]` — the Office's New plan: vikix agents plan new with its words. With --tasks, the form's tasks come as JSON on stdin (a list, a task each with its keys as the plan file has them) and the plan is composed from them, the template's head comment kept. Answers with the file's path alone, which the Office opens
- `vikix agents office --desk PROJECT [TOPIC] [--task "..."] [--use NAME] [--local] [--push] [--no-tests]` — the Office's New desk: vikix agents desk with its words, asking nothing. PROJECT is the project's full name; a task starts a worker at the new desk, and the agent's words are the worker's
- `vikix agents office --worker DESK ["..."] [--use NAME] [--local] [--push] [--no-tests]` — the Office's Worker: vikix agents worker with its words, asking nothing. DESK is the desk's folder, as the snapshot's id is
- `vikix agents office --close-desk DESK [--force]` — the Office's Close desk: vikix agents close, asking nothing. DESK is the desk's folder; refused with an agent at it or files uncommitted, --force throws the files and an unmerged branch away
- `vikix agents office --project NAME --where public|private|local|folder [--title "..."] [--next "..."] [--description "..."] [--log-apart]` — the Office's New project: vikix project new with its words, asking nothing. public and private are on GitHub (--github), local a git repository here alone (--git), folder a folder with a log and no git; --log-apart keeps the log in the logs folder, out of the repository
- `vikix agents --waits PID...` — for the desktop's menu: what holds each of these agents. A line each: pid, the words, the line under, from the notes alone (agents.lisp)

Several agents run side by side, each in a terminal of its own, and five windows called "Alacritty" don't say which is which. The desktop starts them (vikix agent, Super+a), so it knows: it finds the agent in each terminal, started by vikix agent or by hand at a shell, and reads what it is doing from the agent-waiting plugin's note for its window (when you have that plugin: vikix plugin add agent-waiting) and from the mark Claude Code keeps at the front of its window's title. Nothing is asked of the agents themselves.

An agent an editor started (vikix agent --acp: Emacs's agent-shell, Neovim's CodeCompanion) has no window of its own; it is listed last, with what started it.

Super+m, AI, "Agents: who is running" is the same list on the desktop: pick one to go to its window.

A desk: Super+a starts an agent in your home folder, and what it works on is whatever you tell it; two of them on one project then edit the same files. vikix agents desk gives each its own copy to work in. The worktree is an ordinary git one: the agent commits on its branch there, and when its work is in (merged, as the project's own notes say), the desk goes with `git worktree remove FOLDER` and `git branch -d TOPIC` in the project; `vikix agents close` does both once the agent there has finished, and keeps a branch that isn't merged yet. A desk that is still there is used again, not made twice. A project that isn't a git repository has no worktrees: its agent works in the folder itself. Super+m, AI, "Agents: start one on a project" and "Agents: close a desk" are the same, asking which.

An agent's terminal is named for its desk on the desktop: "wifi-fix · Claude", the topic and the provider, in the title bar, the window list, the overview and the palette, from the moment the agent is at the desk (started there, seated with sit, or resumed) until it leaves. Two of one provider at a desk are "wifi-fix · Claude 1" and "wifi-fix · Claude 2", each keeping its number while it runs. The title the agent itself writes (Claude Code's turning mark) is kept apart, and still says what it is doing; a terminal with no agent at a desk is left as it is. The listing and the Office show the same name (`desk_title` in --json).

No desk, no work on a repository: an agent edits the files of a project's repository (any of vikix project's that is one) only from a desk, a worktree of its own, and never in the project's own folder, which is for merging only. Claude Code's hook refuses the edit otherwise and tells the agent how to take a desk from where it sits: `vikix agents sit PROJECT TOPIC` seats it at the worktree PROJECT-TOPIC without a restart (the seats: `~/.local/state/vikix/office/seats.jsonl`, kept while the agent runs). An agent started by vikix agents desk is at one already. A Bash command that would write into a repository (sed -i, a redirection, mv, git commit and the like) is held to the same rule; one that only reads is not. A repository that is no project (`~/.dotfiles`) is not ruled.

A handoff: each desk keeps a small record across agent exits and reboots (`~/.local/state/vikix/office/desks/ID.json`, lib/handoff.py; the id is the repository's and the worktree's, never a process's): the user's task in their words, what the agent says of its work (status, an estimate of how long barring a major issue, account, next), what Vikix read itself (commit, branch, uncommitted files at each write; for a check, the commit it ran on and whether the tree was dirty) and the providers' resumable session ids. The three stay apart, each line says who wrote it, no transcript is copied and no credential is kept. Agents of every kind use the same commands (and the MCP tools handoff and `handoff_update`): read the handoff when joining a desk, say how long when starting, set it when handing work back, blocked, or done. vikix agents close marks the record closed and keeps it.

A desk is a place: the worktree, its branch, its record; a worker is an agent at a desk with a task. vikix agents desk makes the place, vikix agents worker starts an agent on a task there, the task its first prompt, and a desk takes its workers one after another on the same branch, the record keeping each one's task and how it ended (desk --task does both in one go). A worker reports by construction: an agent's status coming to review, waiting or finished is a notification on the desktop, and a worker that changed files in a turn without writing its handoff is asked once to, by Claude Code's Stop hook, before it stops. A note for a worker at work (vikix agents tell) reaches it at its next edit or command, through the same hook that holds the house rules, and never by typing into its window. The same hook holds a paused worker (vikix agents pause) at its next call, a second entry of it before every tool, Read too, so a pause takes hold at the next thing it does; and with turns on (vikix agents turns) it waits at a clash for the other agent's commit rather than asking you. A hand-in (status review) runs the desk's tests (vikix agents test): a script, never an agent, whose result lands in the record and the worker's inbox; not again after a run of tests/run.sh that passed at the desk on that very commit (a run at a desk records itself), nor beside one still going.

The house rules: the office keeps a journal of what each agent edits (`~/.local/state/vikix/office/journal.jsonl`, pruned to the agents still running), fed by the hook vikix agent gives Claude Code (vikix agents touch). From it and from git it knows when two agents are on one file: the one that comes second is stopped at Claude Code's own question to you, with the other agent's name, and `vikix agents clash FILE` shows both changes for you to choose; `vikix agents` marks the file under both agents. An agent may edit a file in another agent's folder, or go to another agent's window (the MCP tool `focus_window`), but never quietly: the crossing is told to it and recorded (vikix records, plugin office, kind crossing), and `vikix agents crossings` lists them. Antigravity CLI (agy) runs the same hook, as a plugin of Vikix's that vikix agent puts in place (agy plugin list shows vikix); its hooks can't tell the agent something without deciding, so there a crossing asks you, with the reason. Codex runs it from `~/.codex/hooks.json` (vikix agents hooks codex --install; vikix agent trusts the file for you in your projects): its `apply_patch` is read for every file it names, a clash is refused once since its hook can't ask, a step out of its sandbox that would write off the desk is denied and a routine one (vikix snapshot, a commit, the tests, wrapped or not) allowed (PermissionRequest), and a turn begun and a stop let through are noted, so the listing says working and at its prompt for it as it does for Claude Code. OpenCode's plugin holds the edit hook alone. Gemini CLI and Aider have none: for them the rules hold through git alone, so a clash with one of them is seen in the listing, not before the edit.

## vikix-ai

AI services on Vikix: keys, and local models.

- `vikix ai setup | models | chat | list | remove | status | stop | restart | share | uninstall` — models that run on this machine, with Ollama (vikix ai help-local tells more)
- `vikix ai llm [--default MODEL]` — the llm command, with your local models and your keys: cat notes.md | llm "summarise"
- `vikix ai use [local|claude|codex]` — which model Super+i (AI on the selected text) uses; alone, says which (one word)
- `vikix ai key set NAME` — ask for a key (it isn't shown as you paste it) and keep it. NAME is a service (anthropic, openai, gemini, perplexity, openrouter, groq, mistral, deepseek, xai, huggingface, github ...) or the variable itself (`MY_SERVICE_API_KEY`). Piped in, the key comes from stdin: pass show api/openai | vikix ai key set openai
- `vikix ai key list` — the keys kept: names and a fingerprint, never the key
- `vikix ai key remove NAME` — forget one
- `vikix ai key check` — look for keys left in your files (and dotfiles such as `~/.profile`), or in their history; vikix doctor runs this

The keys are kept in `~/.config/vikix/secrets/`, only yours to read, and every new shell and the desktop session have them as variables (`ANTHROPIC_API_KEY` ...). They're never in the snapshot history of your files: a key in `~/.bashrc` would be kept there for ever.

## vikix-ask

AI on the text you selected, anywhere on the desktop (Super+i).

- `vikix-ask` — a menu: Ask, Proofread, Rewrite, Translate, Explain
- `vikix-ask ACTION` — one of those straight away (ask, proofread, rewrite, translate, explain): for keys of your own in user.lisp
- `vikix-ask use [local|claude|codex]` — which model answers (vikix ai use); alone, says which
- `vikix-ask which [translate]` — the model (Translate's with translate), where the text goes, which of the three it is and Codex's effort, tab-separated (for vikix-voice: Super+F10 asks the same model)

The text is what you last highlighted (X keeps it after the highlight is gone), else the clipboard: the notification while it works shows it. Proofread, Rewrite and Translate put their result on the clipboard, to paste where you want it; Ask and Explain show the answer, in a notification when it's short, else in a terminal. A local model and Claude answer through llm (vikix ai llm), so it's all in llm logs too.

Which model answers is yours to choose, in `~/.config/vikix/ai` (made on first use): a local one (free, offline, the text stays on this laptop), Claude (better, paid, the text goes to Anthropic), or Codex (the Codex you installed and signed in to with codex login; the text goes to OpenAI). It never leaves the local model by itself.

Codex is an agent, so Super+i asks it with its tools switched off: no commands, no web search, none of the apps connected to your ChatGPT account, and nothing kept of the session. What you select can come from any page, and a line in it written for an agent finds nothing to act with. It takes some ten seconds an answer, fewer with a faster model (model=) and effort=low in that file, which leave Codex in the terminal as it was; the editors' chats and note know only local and Claude, and stay on the local model meanwhile.

## vikix-back

Where you were, when you come back to the laptop.

- `vikix back` — how long you were away, the project you were in (its next step and last commit), the files with changes not yet saved in Emacs, your last commands there, and the last note you captured
- `vikix back --card` — the same, short, as a notification: what the desktop shows by itself when you come back after ten minutes or more away (a break, a lock, a meeting)

Everything is read from what is kept anyway: the desktop's screen log (vikix day: the workspace, project, program and folder that had the screen, and when nobody was at the keyboard), the project's log and its git history (vikix project), Emacs (asked over its socket, for two seconds at most), your shell history (atuin's, for the project's folder, when you use atuin; else the end of `~/.bash_history`) and the inbox's file (the inbox plugin). Nothing is written.

The card comes when the desktop sees you back (day.lisp, every 30 seconds), so not when the screen log is off ((setf `*vikix-day-on*` nil)). Another wait: (setf `*vikix-back-after*` 1800) in `~/.stumpwm.d/user.lisp`, in seconds; nil, never.

## vikix-backup

Your home folder, backed up with restic.

- `vikix backup setup PLACE` — once: where backups go, usually a USB drive (/run/media/you/DRIVE), or any restic place (sftp:host:/path, b2:bucket:path, ...)
- `vikix backup [now]` — back up now: all of ~, minus what `~/.config/vikix/backup-exclude` leaves out
- `vikix backup status` — where, when the last one was, what is left out
- `vikix backup list` — the backups, newest last
- `vikix backup restore PATH [ID]` — bring back PATH (a file or folder) from the latest backup, or backup ID, into `~/Restored/<time>/`; nothing is overwritten
- `vikix backup check` — make sure the backups can be read back (vikix versions PATH lists a file's versions from the backups and the snapshots together, and vikix restore PATH ID brings one back beside it: vikix versions --help)
- `vikix backup off` — stop the reminder; the backups stay where they are

Every backup is encrypted with the password in `~/.config/vikix/backup-password`, made at setup and readable only by you. Keep a copy somewhere else: without it, a lost laptop means backups nobody can read. Old backups thin out after each run: one a day for a week, one a week for a month, one a month for a year. The bar says "backup 9d" once the last backup is older than DAYS (7) in `~/.config/vikix/backup`; nothing runs by itself.

## vikix-battery

Warn on low battery and suspend before it runs out.

- `vikix-battery` — watch the battery until the session ends
- `vikix-battery --once` — check now, print and warn, never suspend

vikix-session starts it on machines that have a battery. Once a minute it reads the first battery's charge, every 15 seconds at 15% or below. While discharging it warns at 15%, then urgently at 5% and suspends if no power supply is online. xss-lock locks before sleep in a Vikix session. After a successful request it waits two minutes before checking again, giving you time after waking to plug in. A failed request retries after one minute. Plugging in resets both warnings.

`VIKIX_BATTERY_LOW` and `VIKIX_BATTERY_CRITICAL` change the two levels. Critical sleep also applies while keep-awake is on or idle sleep is off. Sleep still uses power: plug in before the remaining charge runs out.

## vikix-bitwarden

Your Bitwarden vault on the desktop.

- `vikix bitwarden setup [--eu|--server URL]` — install rbw and the picker (vikix add bitwarden runs this), ask your account's email, then sign in: your master password and two-factor code go into pinentry's box. --eu for an account made on bitwarden.eu; --server for your own (Vaultwarden)
- `vikix bitwarden pick` — the picker (Super+Alt+v): asks for the master password first when the vault is locked
- `vikix bitwarden lock` — lock the vault now
- `vikix bitwarden sync` — fetch changes made on your other devices now (the picker syncs by itself every hour)
- `vikix bitwarden status`
- `vikix bitwarden uninstall` — sign out and forget the vault's copy on this machine (vikix remove bitwarden)

Your Bitwarden vault on the desktop: Super+Alt+v opens a picker of your logins, and Enter types the password into the window you were in. rbw reads the vault (an agent keeps it unlocked for an hour, as ssh-agent does); rofi-rbw is the picker; your master password is only ever typed into pinentry's box, never seen by Vikix.

In the picker (rofi-rbw's keys): Enter types the username, Tab, then the password, for a sign-in form; Alt+3 types the password alone (a password box), Alt+2 the username, Alt+4 the two-factor code (a Premium account's); Alt+c copies the password, Alt+u the username, Alt+t the code (gone from the clipboard after 45 seconds); Alt+m shows every field of the login; Alt+s syncs. Its settings are yours: `~/.config/rofi-rbw.rc`.

## vikix-bt

Bluetooth as one short line, for the mode line.

- `vikix-bt` — print the line; it takes no arguments

```
bt                  on, nothing connected
bt WH-1000XM4 80%   a device connected: its name, and its battery if it says
bt Buds +1          and another one besides
```

Prints nothing when there is no Bluetooth, when it's switched off, or when bluetoothd isn't answering, so the bar leaves the field out. Asks bluez through bluetoothctl, each question with a time limit: a hung bluetoothd must not hold up the bar.

## vikix-cuis

Cuis Smalltalk as a Vikix program.

- `vikix cuis setup` — Cuis 7.8 (the tag #BaseForCuis7.8 of Cuis-Smalltalk-Dev, 134 MB once, checksummed) into `~/.local/opt/cuis`; your image, `~/cuis/vikix.image`, built with no window from its base image, its core updates, Vikix's packages (VikixServer, the door; VikixTheme; VikixDesktop; VikixLessons) and the Vikix font; the cuis command and the launcher's entry (vikix add cuis)
- `vikix cuis rebuild` — a fresh image from the base and the packages, with your own packages in `~/cuis/NewPackages` loaded on top; refused while Cuis runs
- `vikix cuis run [--headless] [--port N] [ARG...]` — what the cuis command runs: your image, with the door on 127.0.0.1:4005 (`VIKIX_CUIS_PORT`, or --port; 0 for none) when `~/.slime-secret` exists; --headless draws nothing, for a script (-s FILE.st, which must end in Smalltalk quit)
- `vikix cuis desktop` — the desktop as objects, in the running image: a window with the bar's fields along the top, a column a workspace and a box a window, read from StumpWM once a second (VikixDesktop open, in a Workspace there); drag a box to another column and the real window moves there, click one and its window takes the focus, click a column's name and the desktop goes there; halos and inspectors work on the morphs
- `vikix cuis lessons` — a first course in Smalltalk, in the running image: eight lessons down the left, each a task, a pane to type in and Check (VikixLessons open there); the image is the exercise book, and a lesson done stays done in it
- `vikix cuis status [--json]` — what is installed, built and running; --json adds what the running image shows (its theme, font, packages, windows, how many expressions its door holds), for vikix mcp's `cuis_state`
- `vikix cuis doctor` — the VM runs, the release is at the pin, the image is built with Vikix's packages, the door answers and the theme is Vikix's (when Cuis runs)
- `vikix cuis uninstall` — removes the release, the command and the entry; `~/cuis`, your image, packages and changes, stays

Cuis Smalltalk as a Vikix program: a live image, pinned, built from packages, with a door for vikix eval and the agents.

The door: vikix eval --cuis '3 + 4' prints 7. The image evaluates what it is sent in its own UI process, after the first line of `~/.slime-secret`, as Swank in StumpWM does (port 4004) and Nyxt (4006). An agent's expression is walked first (VikixWalker, in the image): every global it names and every message it sends must be on the walker's lists, or it is held in the image for you (VikixServer held in a Workspace, then VikixServer runHeld: N or dropHeld: N), with a notification; your own names for the lists go in `~/.config/vikix/door`, the Lisp door's file. The theme: vikix theme writes the Vikix theme as a class, `~/.config/vikix/theme/cuis.st` (VikixTheme's colours and the font), and files it into the running image through the door; cuis reads it as it starts. Cuis's own files (UserChanges, Logs, NewPackages, your preferences) are in `~/cuis`: the image is started with -ud there, so nothing lands in the folder you started it from.

## vikix-day

The day as the desktop saw it, kept as a diary.

- `vikix day [yesterday|DATE] [--no-file]` — that day (today): how long you were at the screen, and for each project how long it had it, its log entries, its commits and what's next; then the rest of the screen's time, the files Esploro changed, the agents' sessions and what changed in your settings after each, Vikix's updates, the rules that ran, the documents opened from the catalogue and what the plugins recorded. Printed, and kept as `~/journal/DATE.org` (--no-file: printed only)
- `vikix day --week [DATE]` — the seven days ending that day, project by project: hours, commits and log entries, a line a day
- `vikix day --for NAME [--week] [DATE]` — only that project
- `vikix day log [yesterday|DATE]` — for each project worked on that day that has no log entry for it: an entry drafted from its commits, the next step and the percentage, each written only on your yes (through vikix project log)
- `vikix day path [yesterday|DATE]` — the day's file

Nothing is asked of you during the day. Everything here is read from records Vikix keeps anyway: the projects' logs and commits (vikix project), Esploro's journal of changes, the snapshot history of your settings (vikix history), the record store (vikix records), and one of its own: `~/.local/state/vikix/day/screen-YYYY-MM.log`, where the desktop notes every 30 seconds which workspace, project, program and folder had the screen when that changed (day.lisp; never a window's title). Five minutes without a key or the pointer is time away, and so is a suspend. A window counts for a project when its workspace was opened for it (vikix project open) or its program is in the project's folder, or in a git worktree of it. A commit counts for the project whose folder holds a file it changed, so a repo of many projects (a collection) gives each its own.

The file is yours and private: `~/journal` is made 700 and each day 600, it is in vikix backup like the rest of your home, and nothing sends it anywhere. Each run writes the day again from the records, so yesterday can be asked for tomorrow; what you write under its last heading, Notes, is kept. Another folder: a line `folder=~/Notes/journal` in `~/.config/vikix/day`. To record nothing about the screen: (setf `*vikix-day-on*` nil) in `~/.stumpwm.d/user.lisp`; the rest still works.

An agent asked "what did I do on Tuesday" runs vikix day DATE --no-file, or reads the day's file.

## vikix-debug

One file that says what's going on, to attach to an issue or hand to an agent.

- `vikix debug [--out FILE]` — write it (default `~/vikix-debug-<time>.txt`), readable only by you; read it before you share it: nothing is sent anywhere
- `vikix diagnose [--use NAME] [--local]` — write it, then ask your AI agent (or NAME) "what's wrong, and how do I fix it?"; the agent starts read-only where it can

In it: the problems at a glance, Vikix's version and checkout, what changed lately, the system, the hardware and screens, your features, what vikix doctor says, the services, and Vikix's own lines from the logs (the session's start and end, the last install and update), the desktop's latest errors (`~/.local/state/vikix/errors/`), X's errors. Left out: other programs' log lines (a browser's carry the pages you had open, and text a web page chose), web addresses' paths, and (by lib/debug-report.py) your secrets, whatever their shape, your home path, user, full and machine names. The finished file is checked once more.

## vikix-dictate

Speak, and it types what you said.

- `vikix dictate setup` — build whisper.cpp (pinned) and fetch its model (checked); a few minutes, once; no password
- `vikix dictate toggle` — start listening, or stop and type it (Super+F9); a recording that stopped by itself (after 5 minutes) is typed by the next press
- `vikix dictate toggle ask | agent` — the same, but what you said goes to the AI, which answers aloud (vikix voice: Super+F10 the chat model, Super+F11 the agent)
- `vikix dictate start [ask|agent] | stop`
- `vikix dictate cancel` — stop listening, type nothing (Super+Shift+F9)
- `vikix dictate models [base.en|small|large-v3-turbo]` — which model: base.en, English (150 MB, a second or two a sentence); small, many languages (490 MB, a few seconds); large-v3-turbo, the best, many languages (1.6 GB, a few seconds on a big CPU)
- `vikix dictate file WAV` — print what a recording says
- `vikix dictate status`
- `vikix dictate uninstall [--models]`

Speak, and it types what you said. On this laptop only: whisper.cpp, built from source, turns your voice into text on the CPU.

While it listens, the bar says mic. On stop, the text is typed into the window you were in when you pressed the key, once it's written down (and put on the clipboard, in case that window didn't take it; if you've moved to another window meanwhile, it's only put on the clipboard). The recording is kept only until it's written down, in your runtime folder (memory, yours alone); nothing leaves the laptop.

## vikix-docs

Every document on the machine in one catalogue, found from one key.

- `vikix docs find WORDS... [--source S] [--limit N] [--json|--tsv]` — the documents that match, best first: words as in a search box (the start of a word is enough), "exact words", a OR b
- `vikix docs page [WORDS...]` — the catalogue as a page in Nyxt (when you have it): the hits by where they're from, each with buttons to open it either way
- `vikix docs pick` — a search box, then the hits to open (Super+F2): Enter opens it, Ctrl+Enter in the other place (a terminal for a man page, Emacs for a page of Markdown)
- `vikix docs open ID [--other]` — open one, by the id find shows
- `vikix docs random [--other]` — one of Vikix's guides at random, as open opens it; every page once before any twice
- `vikix docs read ID` — one as plain text (what the agents read)
- `vikix docs ask QUESTION... [--source S]... [--claude|--local] [--model M] [--limit N] [--show]` — a question answered from the documents found for it, which the answer names: Vikix's guides, your projects, `~/dev` and your notes unless --source says which (own, man, all...; once each, or commas); a local model (Ollama) unless --claude, which sends the passages found to Anthropic and says so; --show prints what would be sent instead
- `vikix docs index [--full] [--quiet]` — read again what changed (--full: all of it); vikix update does it
- `vikix docs watch on|off|status` — one inotifywait on `~/src`, so a document that changes there is read within a second (until off, or the session ends)
- `vikix docs status` — how many from where, and when last read
- `vikix docs list [--source S]` — how many from each source, a line each (source, count, tab between); with --source, its documents by title, as find --tsv prints them
- `vikix docs get` — download the offline programming docs into `~/dev` (a few GB, slow; what plain vikix docs did before)

What it covers, each with whose words they are: Vikix's guides (vikix); the README, DESIGN, TODO, CLAUDE and log files, plans/ and docs/ of your projects in `~/src` (repo); the language guides in `~/dev` (dev); your Org notes in `~/Dropbox/notes` (note); your own documents, the folders you name (own, below); the classes of the Cuis Smalltalk image (cuis: a row a package and a row a class, its comment and its method categories, read from the package files, Vikix's in the checkout, yours in `~/cuis/NewPackages` and Cuis's own in `~/cuis/Packages`, when Cuis is installed); every man page (man) and Info manual (info) on the machine; the tldr pages (tldr: a command's worked examples, where a man page has its options) and the ArchWiki (arch), the English pages of each as wikiman keeps them in /usr/share/doc, when they're there; the READMEs, notes and PDFs packages keep in /usr/share/doc (doc); every package there is, installed or not (pkg); the entries of Zeal's docsets (zeal: a function, a class, a method by name, read in place from each docset's own index, nothing copied); and links to the web (web: the websites of the packages installed, the links the language guides in `~/dev` list, and your own in `~/.config/vikix/docs-links`, a URL and its title a line). A web hit wears a globe: it is the one kind that opens on the web, and nothing of it is ever fetched, not when the catalogue is read, not when it is searched. Vikix's guides rank first, then yours, then tldr with the man pages, then the rest of the system's; a docset's entry named by words written as code (str.split, `read_dir`) stands with the documents named by them, and a plain word (keyboard, split) keeps the catalogue's own hits first, the docsets' entries after.

A PDF (in a project's docs/ or at its top, in /usr/share/doc, or in a folder of yours by a `*.pdf` pattern) is read by the text it carries, its first twenty pages (pdftotext, from poppler-utils; without it a PDF is listed by its name, saying so), a row for the whole and a row a page, so a hit opens at its page (zathura, evince or mupdf take a page; another viewer opens the file). A scanned PDF with no text is listed by its name alone.

It reads again by itself what changed, when a search finds the catalogue more than a day old (a few seconds); vikix update reads the man pages and manuals again; vikix docs watch on reads a document of `~/src` the moment it changes. A man page, a tldr page or a Markdown file opens as a page in the docs browser, styled as the guide is (made by mandoc and pandoc, cached in `~/.cache/vikix/docs/`); an ArchWiki page as the copy is; a package as a short page (installed or not, how to add it, its website); an Info manual and your notes in Emacs; a Cuis class in a Browser in the running image, through its door (vikix eval --cuis), or its package file in Emacs at the class when Cuis isn't running; a docset's entry as its page in the docs browser, at the entry, or in Zeal when the docset keeps its pages compressed; a web link in your default browser. Ctrl+Enter (or --other) opens the other way: Emacs, or a terminal; an ArchWiki page as it is today, on the web; a docset's entry in Zeal; a PDF's text in a terminal. vikix docs random opens a guide page at random, every one before any twice.

vikix docs ask answers a question from the documents it finds for it (the words they share), a local model by default, so nothing leaves the laptop unless --claude is said; the answer ends with the documents it drew on, by id. Under an agent, your own documents (own) stay closed to it as they are to `docs_search`, unless a folder is opened with agents=. The web's links are never read for an answer, and a docset's entries are found by name, not asked.

Your own documents (own) are the folders named in `~/.config/vikix/docs`, yours to make, a line each: `own=~/books` (every Markdown file under it), or `own=~/books` `one/*.md` `two/out/*.html` (those files, as patterns from that folder; HTML pages only when asked for). Unlike the other sources they are read a section at a time (a Markdown heading, an HTML heading with an id or a data-at tag), so a search lands on the section, and so does a chapter a page of vikix what names. They open in the docs browser at that section, styled as the guide is, or in Emacs. They are closed to agents: `docs_search` and `docs_read` leave them out, unless a line `agents=~/books` opens that folder to them. The same file names the folders of your own pages for vikix what (what=FOLDER; vikix what help says what a page is).

The catalogue is one SQLite file, `~/.local/share/vikix/docs/index.db`: table docs (id, source, kind, title, path, excerpt, mtime) and `docs_fts`, its full-text index. Nothing in it leaves the machine.

## vikix-docs-open

Open guides, tutorials and offline docs in the docs browser.

- `vikix-docs-open FILE|URL...`

The docs browser is Nyxt when it's installed (the feature lisp-apps): a browser written in Common Lisp, changeable in Lisp as StumpWM is, so the guides can grow keys and pages of their own there. The rest of the web stays with your default browser (xdg-open, `~/.config/mimeapps.list`). Without Nyxt, this is xdg-open.

`~/.config/vikix/docs-browser`, if you make it, names another program to use instead: one word on a line, such as firefox, chromium or xdg-open.

A running Nyxt takes the pages as new buffers in its window (Nyxt hands them over through its socket), and StumpWM then brings that window forward, from whichever workspace it's on.

## vikix-door

The Lisp agents sent that the door held, and what passes.

- `vikix door` — the forms held for you: each one's number, when, which agent, why it was held, and the form
- `vikix door run N` — run one, as you (nothing of it ran before), and forget it: what it printed and its values
- `vikix door drop N` — forget one without running it
- `vikix door check FORM` — would the door let FORM through? "ok", or "held:" and why. For an agent, before sending; for you, to see what the list means
- `vikix door allowed` — every name a form may call, one a line: the door's own list, the registry's commands agents may run, and `~/.config/vikix/door`
- `vikix door used` — what agents send and what the door holds, counted since counting began (vikix used): how many forms passed and were held, the names on the list called most often, the names that held a form with how often you ran or dropped it, and the names on the list never called. What says whether the list is right: a name never called can go, one held often and always run is wanted

The door (config/stumpwm/vikix/door.lisp) stands between an agent and the running desktop. An agent's Lisp (vikix eval under Claude Code or another agent, the MCP server's eval tool) is read without running anything and walked: every function it calls must be on one list, of what reads the desktop and what is put back as easily as done. A form that runs a program, touches a file, defines or changes code, sets a global or waits on the desktop is held here instead, and the agent is told why. Super+m, Door is the same list in a menu. Your own vikix eval isn't checked.

Your own names go in `~/.config/vikix/door`, one a line (# for a comment): a function of your user.lisp that an agent may call. The count (used) is kept with the keys' in `~/.local/state/vikix/used`: names and numbers only, never a form's text; vikix used forget starts it again.

## vikix-drives

USB drives: mounted when plugged in, ejected from a menu.

- `vikix-drives start` — run udiskie (vikix-session does, at login): it mounts a drive when it's plugged in, says so with an "Open" button (PCManFM), and asks for an encrypted drive's passphrase in rofi
- `vikix-drives eject` — pick a mounted drive in rofi (Super+Ctrl+e, or Super+m, Eject a drive); it is unmounted and powered off, and a notification says when it's safe to pull out
- `vikix-drives list` — the mounted drives, one mount folder per line
- `vikix-drives bar` — "usb" while a drive is mounted, for the bar

udiskie calls back for two things: `password DEVICE` (the rofi prompt) and `event EVENT MOUNT_PATH`. On a mount, if it's the drive `vikix backup setup` chose and a backup is due, the backup starts by itself.

Drives are what udisks mounts for you, under /run/media/$USER.

## vikix-dropbox

Dropbox as one short line, for the mode line.

- `vikix-dropbox` — print the line; it takes no arguments

```
dbx ↓1,204 ↑3   syncing: files left to download, and to upload
dbx sync        syncing, with no count to show
dbx paused      syncing is paused
dbx …           starting, connecting or indexing
dbx !           it can't sync, and says why in `dropbox status`
dbx off         set up on this machine, but not running
```

Prints nothing while it's up to date, when Dropbox isn't installed, or before it was ever set up here (no `~/.dropbox`), so the bar leaves the field out. `dropbox status` asks the daemon over a socket, with a time limit: a stuck daemon must not hold up the bar.

## vikix-esploro

Esploro, Vid's file explorer.

- `vikix esploro setup [--rebuild]` — build its command from a pinned commit into `~/.local/opt/esploro` (SBCL alone, seconds); the window's code is emacs/esploro.el beside it, which the command loads into Emacs the first time. --rebuild builds it again (vikix add esploro runs this; vikix update runs it too, and it builds only when the pin moved)
- `vikix esploro status`
- `vikix esploro doctor` — is it built at the pin, linked, the folder program, answering Show in folder, loaded in Emacs (vikix doctor runs this when you have the feature)
- `vikix esploro menu` — Esploro's file commands for the file behind the focused window, in rofi (Super+Alt+x): open it, copy its path, compress, extract, shrink, yours; one that changes files is a plan to review first
- `vikix esploro try [CLONE]` — your clone's commit (`~/src/esploro`) on the desktop now: built, linked, the running Emacs reloaded; no GitHub. Kept by updates while it's newer than the pin; a release whose pin passes it takes over
- `vikix esploro uninstall` — removes it (vikix remove esploro)

Esploro, Vid's file explorer (github.com/vukini/esploro): a frame of Emacs, on dired, with menus, a tool bar, the mouse and drag and drop; its core, which does every change to files (journaled, so it can be undone), is Common Lisp, and knows which window has each file open.

Command: esploro [FOLDER] (through Emacs's server: Vikix runs Emacs as a daemon); Super+e opens it, or goes to its frame; it's in the launcher (Super+d) and Super+m, Apps; M-x esploro in Emacs once it's been opened.

## vikix-eval

Run Lisp inside the running StumpWM and print the result.

- `vikix eval '(current-group)'` — one or more forms as an argument
- `vikix eval < file.lisp` — or read them from standard input, a file or a pipe: echo '(vikix-apply-theme :vikix-light)' | vikix eval
- `vikix eval --door FORM` — check the forms as an agent's, whoever sends them
- `vikix eval --socket FORM` — over Vikix's socket only (no Swank), or --swank over Swank only; alone it tries the socket first
- `vikix eval --whose` — say whose a form from here would be: yours, or an agent's and which, and whether the door stands
- `vikix eval --cuis '3 + 4'` — Smalltalk, in the running Cuis image instead (vikix add cuis; its door, VikixServer, on 127.0.0.1:4005, `VIKIX_CUIS_PORT`): one expression, "=> " and its printString, or "error: ..."; an agent's is walked first, --door makes anyone's so

The forms are read in the STUMPWM package, so Vikix's and StumpWM's own names work without a prefix. For each form it prints what the form printed, then "=> " and the value.

It talks to Vikix's own socket, `$XDG_RUNTIME_DIR/vikix.sock` (`VIKIX_SOCKET` names another; config/stumpwm/vikix/socket.lisp serves it, 0600 in a folder that is yours alone, so nothing is sent to prove who you are), where a form that only reads the desktop's state is answered by a thread of its own, even while a menu is open, and anything else goes to the main thread as before. Without the socket (an older desktop, a session without elogind) it talks to the Swank server that swank.lisp starts on 127.0.0.1:4004 (`VIKIX_SWANK_PORT` changes the port). When `~/.slime-secret` exists (40-config makes it), Swank lets in only a client that sends its first line first, as Emacs's SLIME does; so does this. The Lisp side, vikix-eval-for-agent, catches errors, so a bad form prints "error: ..." instead of leaving this command waiting.

Exit status: 0 when every form ran, 1 when one failed, 2 when StumpWM could not be reached, 3 when the door held the forms.

The door (config/stumpwm/vikix/door.lisp). When an agent is above this command in the process tree (Claude Code, Codex, OpenCode, Gemini, Aider or Antigravity, with no script of Vikix's between: `vikix theme` run by an agent sends Vikix's Lisp, not the agent's), the forms are an agent's, and the desktop walks each before anything runs: every function it calls must be on the door's list (`vikix door allowed`). A form that runs a program, touches a file, defines or changes code, sets a global or waits on the desktop is held for the user instead (Super+m, Door; `vikix door`), with why printed here. Your own `vikix eval` at a terminal is yours and isn't checked. The door stands only at the desktop's own Swank (port 4004): a test's StumpWM on another port asks for it with --door.

Changes made this way live in the running StumpWM only. They are gone after a restart or a reload; to keep one, put it in `~/.stumpwm.d/user.lisp`.

The Cuis door (--cuis; cuis/VikixServer.pck.st, loaded by vikix cuis setup) takes the same first line of `~/.slime-secret`, then lines ending with a line of one dot (a line starting with a dot gets one more), and answers "ok" or "error", the lines of the answer the same way, and a dot. An agent's expression (or anyone's with --door) goes with a first line "door: WHO", and the image's walker (VikixWalker) parses it and checks every global it names and every message it sends against its lists before anything runs; one that runs a program, touches a file, evaluates text, reaches the system, defines code or waits is held in the image (VikixServer held; the user runs it there with VikixServer runHeld: N, or drops it), with a notification here and exit 3, as the Lisp door holds.

## vikix-features

What you add to Vikix beyond the base.

- `vikix features` — what there is, and what you have ([x])
- `vikix add NAME...` — add features or bundles: their packages now, and every update keeps them
- `vikix remove NAME... [--yes]` — stop keeping them, and uninstall their packages: only those nothing else you have needs. It shows the list and asks first.

What you add to Vikix beyond the base (`vikix add`, `vikix remove`, `vikix features`).

A feature is a line in features.list (a language, an editor, LibreOffice, printing, Windows, local AI ...); a bundle, in bundles.list, is several (essentials, developer, everything). Your choices are the lines of `~/.config/vikix/features`. Your own files are never touched: `~/dev`, your editor configs, a Windows VM's disk (vikix windows remove asks for that).

## vikix-fingerprint

A fingerprint for sudo and the lock screen.

- `vikix fingerprint` — is there a reader? which fingers are enrolled? and, the first time, enrol one
- `vikix fingerprint enrol [FINGER]` — enrol a finger (right-index-finger unless named: left-thumb, right-middle-finger, ...)
- `vikix fingerprint on` — let sudo and the lock screen take a finger
- `vikix fingerprint off` — take that out again: the password only

With it on, your password works exactly as before. To use the finger instead, press Enter at the password prompt (sudo's, or the lock screen's) with nothing typed, then touch the reader. Over SSH the reader is never asked.

fprintd does the work; it only knows the readers libfprint has a driver for (fprint.freedesktop.org/supported-devices.html). With no such reader, this says so and changes nothing.

## vikix-firewall

The firewall, ufw.

- `vikix firewall` — on or off, and the rules (sudo, to read them)
- `vikix firewall on` — switch it on: nothing comes in unless a rule lets it, everything goes out, SSH is let in; and the programs below that are installed get their port
- `vikix firewall off` — switch it off (the rules are kept for next time)
- `vikix firewall allow PORT[/tcp|/udp] [NAME]` — let a port in (both tcp and udp unless one is named)
- `vikix firewall close PORT[/tcp|/udp]` — take that rule out again

Replies to what this computer asked for always come back in: web pages, updates, mail. A rule is only needed for a program others connect to. Printers and other devices that announce themselves (mDNS, as avahi uses) are let in by ufw's own rules, and the VMs on libvirt's network by libvirt's. Ports opened by `on` when the program is there:

```
LocalSend   53317 (tcp and udp), to send files to and from a phone
```

ufw keeps everything in /etc/ufw, and its runit service puts the rules back at boot. Every change asks for your sudo password.

## vikix-firmware

Firmware updates from LVFS, through fwupd.

- `vikix firmware` — fetch the latest list from LVFS and show what's waiting
- `vikix firmware update` — install it: on AC power only, and some of it (the BIOS, say) finishes during the next reboot
- `vikix firmware devices` — what fwupd knows about, and each one's firmware version
- `vikix firmware count` — how many devices have an update (for the bar), or ?

Laptop makers, Lenovo among them, publish BIOS, Thunderbolt, dock and fingerprint-reader firmware on LVFS (fwupd.org). fwupd itself starts when asked (D-Bus); there is no service to switch on. The bar says "firmware" when an update is waiting: vikix-updates checks every 6 hours.

## vikix-font

The one font file StumpWM draws its bar, menus and messages in.

- `vikix-font` — make wm.ttf if it's missing or a stand-in; print its path
- `vikix-font --force` — make it again
- `vikix-font --family` — the family name wm.ttf carries (Iosevka, or the stand-in's), for the programs that take a font by name: Cuis's theme (vikix theme writes it)

StumpWM's TrueType module (ttf-fonts) reads only single .ttf files, and Void's font-iosevka ships Iosevka as .ttc collections of every weight. So this takes Iosevka Regular out of the collection (with fontTools) into

```
~/.local/share/vikix/fonts/wm.ttf
```

which theme.lisp loads. Until Iosevka is installed (fonts.list, in the base), wm.ttf is a link to Noto Sans Mono instead. The folder is outside fontconfig's paths, so other programs don't see a second Iosevka.

## vikix-gestures

A three-finger swipe on the touchpad moves the focus.

- `vikix gestures` — whether it's listening, and what a swipe does
- `vikix gestures on` — listen from now on, and at each login (and again, after you changed a setting)
- `vikix gestures off` — stop listening, and don't start at login
- `vikix gestures --watch` — listen for swipes and pans (the session starts this)

A three-finger swipe on the touchpad moves the focus; two fingers on a touchscreen walk a strip (`vikix gestures`).

Three fingers swept left or right go to the window that way, as Super+h and Super+l do: along a strip (vikix viri), a column at a time, and between the splits of a tiled workspace. Swept up or down, they go up and down a column or the splits. A long sweep goes on going: a step for each stretch of the way. The direction is the one your touchpad scrolls in: where scrolling isn't "natural" the focus goes the way the fingers do, fingers to the left to the window on the left; where it is, they bring the next window on the right, as they move a page. (Two fingers swept sideways walk along a strip too: that is the strip's own, `*viri-scroll-walks*`.)

On a touchscreen, two fingers dragged sideways over a strip walk it, a column for each stretch, the way they drag: fingers to the left bring what's on the right. The X server hands every touch to this listener first (a passive touch grab on the root window), which decides at once: a two-finger sideways drag over a strip is its own, and the program under it sees nothing; one finger, three, fingers going up or down, a tap, or anything over a tiled workspace goes to the program as if nothing were listening (one finger held still for 0.15 s goes too, so a long press reaches it). StumpWM says which it is in `_VIKIX_STRIP` on the root window (viri.lisp). Stylus touches aren't taken.

Settings are yours, in `~/.config/vikix/gestures`, one a line:

```
fingers = 3      how many fingers make the sweep (3 or 4)
pan = 150        on a touchscreen, over a strip: a column for each PAN
                 pixels two fingers drag sideways; pan = no leaves the
                 screen alone
distance = 120   how far they go for each step: less is quicker
natural = no     yes: fingers to the left bring what's on the right;
                 not said, it is as your touchpad scrolls
```

It listens through the X server (XInput 2.4, touchpad gestures), so it needs no group or password; a program that takes the sweep for itself keeps it. It is off while `~/.config/vikix/gestures-off` exists, and stops by itself on a machine with no touchpad.

## vikix-grok

Local task briefs and reviewed results for Grok Bot.

- `vikix grok new TITLE --brief FILE [--project NAME]` — queue an explicitly chosen UTF-8 brief; FILE - reads stdin; prints the task id
- `vikix grok list [--state STATE] [--json]` — tasks, newest first; no brief or result bodies
- `vikix grok show ID [--json]` — the brief, result, and transition history
- `vikix grok prompt ID` — instructions to paste into Grok Bot
- `vikix grok instructions` — the local handoff protocol for a Bot
- `vikix grok claim ID` — atomically claim a queued task; prints its brief
- `vikix grok result ID --file FILE` — return JSON for a running task, for review; FILE - reads stdin; identical retries are safe
- `vikix grok fail ID REASON` — record why a running task could not finish
- `vikix grok accept ID` — mark a result reviewed; applies no files or code
- `vikix grok cancel ID` — cancel a queued, running, or failed task, or a result
- `vikix grok status` — client availability and local queue counts; this does not test Grok's account or connection

Tasks are local, in `~/.local/share/vikix/grok/tasks.db` (private, backed up). `VIKIX_GROK_DIR` overrides that directory. Creating a task sends nothing; paste its prompt into Grok Bot and approve its local commands. The Bot returns summary, sources, artifacts, and questions as JSON. Sources and artifacts are HTTP(S) links, never automatically fetched or executed. States: queued, running, review, accepted, failed, cancelled. There is no automatic retry, remote API, service, or Office worker launched by this helper. A failed task remains readable; create a new task to retry it. Keep Grok's local execution policy at Ask every time. This helper is a handoff convention, not a sandbox around Grok's other local commands.

## vikix-hype

Hype, Markdown presentations with a visual slide editor.

- `vikix hype setup [--rebuild]` — the packages it needs, then Hype built from source (a pinned release) into `~/.local/opt/hype`: a minute or two, once. Also the launcher entry, the portal's file dialogs, and the skill that lets your agent write slides
- `vikix hype status`
- `vikix hype uninstall`

Hype, Markdown presentations with a visual slide editor (https://github.com/omacom/hype, by DHH; MIT). Made for Omarchy; Vikix gives it what it looks for there: the desktop's colours, themes to choose for the slides, and the desktop portal for its file dialogs.

Then: hype open talk.md (or Super+d, Hype), hype help for the rest.

The colours: Hype's window follows `vikix theme` as it changes, and every Vikix theme (yours too) is a theme to choose for the slides. `vikix theme` writes them in Omarchy's form: `~/.local/state/omarchy/current/theme/` colors.toml (the current one, where Hype looks) and `~/.local/share/vikix/omarchy/themes/NAME/colors.toml` (the hype command sets `OMARCHY_PATH` there).

## vikix-idle

What happens when you leave the computer alone.

- `vikix-idle apply` — set the lock and screen-off times (the session does this at login)
- `vikix-idle awake [on|off|toggle]` — keep awake: no idle lock, dark screen or suspend, for a film or a talk; the bar says "awake". Every login starts with it off.
- `vikix-idle --watch` — suspend on battery after SUSPEND minutes idle; the session runs this on machines with a battery

```
after LOCK minutes       the screen locks (xss-lock runs vikix-lock)
after SCREEN_OFF minutes the screen goes dark
after SUSPEND minutes    on battery only, the computer suspends
```

The times are minutes, from `~/.config/vikix/idle` when it exists, e.g.

```
LOCK=10
SCREEN_OFF=11
SUSPEND=20          # 0: never suspend by itself
```

Anything not set there keeps the value below. Critical battery sleep is separate: vikix-battery still suspends at 5%, even with keep-awake on or SUSPEND=0.

## vikix-image

Open an image in nsxiv together with the rest of its folder.

- `vikix-image FILE` — FILE, with the other images of its folder to move through
- `vikix-image FILE...` — just those

Given one file, nsxiv shows only that file. This hands it every image in the same folder, in name order, starting at the one asked for, so n / p (or the arrow keys) move on through the folder and Enter shows them all as thumbnails. Given several files, it opens just those.

xdg-open and the file managers use it through vikix-image.desktop, which `~/.config/mimeapps.list` names for images.

## vikix-jupyter

JupyterLab in `~/dev`, with the Python that 67-dev set up.

- `vikix-jupyter` — start it, or open the page of the one already running

Started by `jlab`, the launcher (s-d: type JupyterLab, or jlab) or the menu (s-m). If a JupyterLab is already running, its page is opened again rather than a second one started. The server's messages go to `~/.local/state/vikix/jupyter.log`.

## vikix-keyboard

Apply the layout and options in `~/.config/vikix/keyboard`.

- `vikix-keyboard` — apply them now

Run at login by vikix-session; run again after editing the file.

## vikix-lazarus

Start Lazarus: the docked IDE that 65-languages builds in `~/.lazarus`.

- `vikix-lazarus [ARGS]` — start it; ARGS (a project's .lpi file) go to the IDE

Start Lazarus: the docked IDE that 65-languages builds in `~/.lazarus` (one window, which StumpWM tiles), or Void's plain one if that build isn't there. Void's startlazarus would pick the plain one. config/applications/lazarus.desktop runs this, so the launcher (Super+d) and opening a .lpi file both come here.

## vikix-learn

Courses in the terminal.

- `vikix learn` — the courses there are
- `vikix learn COURSE` — two panes on the desktop: the lesson you're on, from the top, and a shell in its folder; each save is checked in the lesson pane (Super+m, Learn C, is the same)
- `vikix learn COURSE --here` — the lesson pane in this terminal instead
- `vikix learn COURSE next` — on to the next lesson; prev goes back one
- `vikix learn COURSE list` — every lesson, ticked when done
- `vikix learn COURSE go NN` — go to lesson NN
- `vikix learn COURSE hint` — the next hint for this lesson
- `vikix learn COURSE check` — check once (passing moves you on)
- `vikix learn COURSE watch` — the old way: check each save, in this terminal
- `vikix learn COURSE reset NN` — lesson NN's files as they came (after a snapshot)

Courses in the terminal (`vikix learn`): every lesson is a real program you edit, save, and watch get checked.

In the lesson pane: the arrows, PgUp/PgDn and Space scroll; n or Right the next lesson, p or Left the one before; h a hint, c check now, r reset, q quit. It remembers the lesson and where you were in it, and opens there.

The course comes from Vikix (learn/COURSE/ in the checkout). Its lessons are copied to `~/learn/COURSE/` the first time: those are your files, never overwritten (but lesson.md, the text, which follows Vikix's), and in your snapshot history (vikix undo). The checks stay Vikix's, so a fix to one reaches you with vikix update. Your progress is in `~/.local/state/vikix/learn/COURSE/`.

This knows nothing about any language: a course is a folder with a course.conf (TITLE, and WORK, the files you work in) and lessons NN-name/, each with lesson.md, the files to copy, a check.sh and hints.md; a lesson whose work is in other files names them in its own file "work". A course that renames lessons lists them in "renames" (OLD NEW a line): your folders and progress move with them.

## vikix-ledger

What left this laptop, by program and destination: the outbound ledger.

- `vikix ledger [today|yesterday|DATE|PROGRAM] [--json]` — the page: every connection a program opened out of this machine that day (today unless said), by program, each destination with its port, how many times, the first and the last; a PROGRAM alone: its days
- `vikix ledger on` — switch it on: a log rule for new outbound connections in the firewall's rules (sudo once; the firewall must be on), and the watcher that reads the log
- `vikix ledger off` — take the rule out; what was recorded stays
- `vikix ledger status` — on or off, the watcher, today's count
- `vikix ledger watch` — what the session runs: read the kernel log and record each connection (--log FILE --once reads a file through, for tests)

The site says nothing leaves the laptop unless you ask; this is how anyone checks. The firewall (ufw) logs every new outbound connection, not on the loopback, with the user id, into the kernel log socklog keeps (/var/log/socklog/kernel/current, readable by you). The watcher tails that log and, for each line, asks `ss` which program holds the socket's port (its name, its executable, its folder, and whether it is an agent or an agent's child: claude, codex), then records the connection in the records store (`vikix records`, plugin ledger, kind connection): one record a day for each program, destination and port, with a count and the first and last time. Who talked to whom and when: no payload is ever kept, and a destination is an address and its name when one resolves.

A program that is gone before `ss` is asked (a quick DNS query) is recorded as "?" with its user. The rule is a block in /etc/ufw/after.rules and after6.rules, before their COMMIT, as `vikix firewall` keeps ufw's own; it logs at most a hundred new connections a second. `~/.config/vikix/ledger` says it is on; the session starts the watcher when it is.

## vikix-lisp-apps

Programs written in Common Lisp, and programmable in it, as StumpWM is.

- `vikix lisp-apps setup [--rebuild]` — Nyxt from Void; Lem built from source (a pinned commit, its libraries pinned by its qlfile.lock); McCLIM, the Listener and Clouseau from Quicklisp, saved as one program. A few minutes, once; no password when the packages are there. --rebuild builds Lem and the Listener again
- `vikix lisp-apps status`
- `vikix lisp-apps uninstall` — removes Lem and the Listener; the feature stays, as Nyxt does: it goes with vikix remove lisp-apps

Programs written in Common Lisp, and programmable in it, as StumpWM is: Nyxt (a web browser), Lem (an editor) and McCLIM's Listener (a Lisp prompt whose output is live objects), with Clouseau, the inspector.

Commands: nyxt, lem, clim-listener; all three are in the launcher (Super+d).

## vikix-local-ai

AI models that run on this machine, with Ollama.

- `vikix ai setup` — install Ollama (its CPU and Vulkan parts, as you, in `~/.local/opt/ollama`; no password) and start it. It starts with the desktop from then on
- `vikix ai models` — pick a model to download: each says what it's for, its size, and how it runs on this machine (fast, well, slowly: on the CPU, or on a graphics chip that shares the memory); ones too big aren't offered unless already installed
- `vikix ai chat [MODEL]` — talk to one, in the terminal (/bye or Ctrl+D to leave); Super+m, Local AI: talk to a model
- `vikix ai list` — the models you have, and their sizes
- `vikix ai remove MODEL` — delete one (it can be downloaded again)
- `vikix ai status` — installed? running? on the graphics? which model is loaded, how much memory it holds and until when
- `vikix ai stop` — unload the model now (it unloads by itself after 5 minutes unused)
- `vikix ai restart` — start Ollama again (after a change of graphics= in `~/.config/vikix/ai`)
- `vikix ai share [most|half]` — how much of the memory the graphics chip may take (a Ryzen AI Max): the kernel gives it half at first; most leaves the rest of the machine 16 GB, half puts the kernel's half back. It changes how the machine boots (sudo), and the next boot applies it
- `vikix ai uninstall [--models]` — take Ollama away; --models deletes the downloaded models too
- `vikix ai llm [--default MODEL]` — Simon Willison's llm on the command line (with its Ollama and Anthropic plugins), so that cat notes.md | llm "summarise" works. Its default is a local model if you have one, else Claude when `ANTHROPIC_API_KEY` is set (vikix ai key)

Its API is on http://127.0.0.1:11434 (only this machine; the Windows VM can't reach it). The bar says "ai" while a model is loaded in memory. Models are big: they're in `~/.ollama/models`, and backups leave them out.

Honest about a laptop without a graphics card. Measured on an i7-7500U with llama3.2:3b: about 4 s to load, then about 11 s for two sentences. Models of 1-2 billion parameters are about twice as quick, 7-8 billion about three times as slow; bigger ones don't fit.

A graphics chip that shares the main memory (AMD's Ryzen AI Max: 128 GB, of which the chip may take 65) runs a model many times faster than the CPU, and holds ones a CPU can't: Ollama leaves such a chip out unless asked (`OLLAMA_IGPU_ENABLE=1`), so `serve` asks when graphics= in `~/.config/vikix/ai` says on, or says nothing (auto) and the chip may take 32 GB or more; off keeps the CPU. Measured on the Ryzen AI Max+ 395 (2026-10-19, Ollama 0.34.4): gpt-oss-120b answers at 51 words a second through Vulkan, 35 through ROCm (which sees 61 of the chip's 65 GB and leaves 9 GB of the model on the CPU), so Vulkan it stays. Ollama's own context there is the model's longest (4.6 GB more for gpt-oss-120b), which once took the whole of the chip's memory: the X server, refused its share, ended the session (three times that day). So `serve` sets a 32k context (`OLLAMA_CONTEXT_LENGTH`; a request may still ask for more) and keeps 8 GB from Ollama's sums (`OLLAMA_GPU_OVERHEAD`), which stop it loading a second model beside. llama-server's own margin (`LLAMA_ARG_FIT_TARGET`) is no help on such a chip: what it moves to "the CPU" is memory the chip maps all the same, and it only cost speed (44). The 120B leaves the desktop about 3 GB there until the kernel's share is raised. The picker counts that memory and rates the models that fit in it by the parameters at work on each word (lib/ai-models.tsv).

The kernel lets such a chip take half of the memory (TTM's page limit) until told otherwise. `share most` writes a block into /etc/default/grub (`ttm.pages_limit` and `ttm.page_pool_size` in 4 KiB pages, amdgpu.gttsize in MiB: all but 16 GB) and runs update-grub, so from the next boot the chip may take most of it, which the biggest models need; `half` takes the block out. `setup` offers it on such a machine, asking first, since it changes how the machine boots. The picker reads the chip's share as the kernel gives it, so it follows the next boot by itself.

## vikix-lock

Lock the screen, with only ever one locker.

- `vikix-lock` — lock now
- `vikix-lock --locker` — the locker itself, for xss-lock to start

The session runs xss-lock, which starts `vikix-lock --locker` after 10 idle minutes and before a suspend. The key (s-Escape) and the menu run plain `vikix-lock`, which asks xss-lock to lock now: a second i3lock started beside xss-lock's would need unlocking twice. Without xss-lock (another session), it locks by itself.

The lock screen is i3lock-color: the wallpaper (the one showing, through vikix-wallpaper which), a clock and the date, and a ring that shows what is typed, in the theme's colours (vikix theme writes them to `~/.config/vikix/theme/palette`). The ring is the accent; a key lights it in the foreground, backspace in the alert colour; while the password is checked it goes subtle, and wrong turns it the alert colour and says so. With plain i3lock instead, a screen in the theme's background colour.

While the screen is locked, notifications wait: dunst draws its windows above everything, i3lock's too, so a message could be read on a locked screen. They are shown once it's unlocked, unless they were already paused (Do not disturb), which is kept.

A key that wakes the dark screen isn't kept as part of the password.

## vikix-mcp

The Vikix desktop as an MCP server, for any agent that speaks MCP.

- `vikix mcp register [--allow-eval] [--allow-undo]` — add it to Claude Code and Antigravity CLI (claude mcp add and agy mcp add, for you, each when it is installed), and print the lines for Codex, Gemini CLI and OpenCode; register again without a flag to take that tool away
- `vikix mcp status` — whether Claude Code (and Antigravity CLI) has it, with which tools, and the last calls
- `vikix mcp unregister`
- `vikix mcp tools` — what it offers
- `vikix-mcp serve [--allow-eval] [--allow-undo]` — the server itself, on stdin and stdout: what an agent starts (nothing listens on a port)

The Vikix desktop as an MCP server, for any agent that speaks MCP (Claude Code, Antigravity CLI, Codex, Gemini CLI, OpenCode).

Why: your agent can already run commands, but each needs your yes. These tools are a small, checked set: allow them once (in Claude Code, "always allow" for vikix), and the agent can look at the desktop and make small, undoable changes without asking each time, while other commands still ask.

The tools, a fixed set:

```
read only   desktop (workspaces, windows, screens, theme), keys, commands
            (the desktop's commands an agent may run), rules (the
            desktop's rules, and why a window is where it is), why (what
            the desktop did lately, and what made it), agents (the
            agents at work on the desktop, and what each is doing),
            office (tasks and desks), tasks (the task records), handoff (a desk's record),
            doctor, history, changes, themes, cuis_state (the Cuis
            image: installed, running, what it shows), version
small acts  notify, snapshot, set_theme, switch_workspace, focus_window,
            run_command: each checked against what's there, and easy to
            take back. run_command runs one of the desktop's own commands
            by name, and only those its registry marks for agents
            (registry.lisp, :agent t: do not disturb, night light, gaps,
            focus left ...); the desktop refuses any other
proposals   propose_file_changes (a plan shown in Esploro) and
            propose_rule (a rule shown under Super+m, Rules): checked
            whole, and only your choice there changes anything
off unless  eval (Lisp in the window manager, through the door) and
switched on  cuis_eval (Smalltalk in the Cuis image, through its own
            walker: --allow-eval), and undo (your files back a snapshot:
            --allow-undo). These are a convenience, not a wall: an agent
            that can run commands can run vikix eval, or register the
            server again, itself; the doors stand on that road too.
```

Nothing an agent sends reaches Lisp or a shell except as a value checked against the desktop (a workspace that exists, a theme there is, a number), or, for `propose_rule`, as text the window manager reads without running and holds until you decide; eval's form is read the same way and walked by the door (door.lisp) first, and runs only when every function it calls is on the door's list, else it waits for you (Super+m, Door; vikix door); `cuis_eval's` expression the same way by the image's walker (VikixWalker), and waits there (VikixServer held) when it may not run. Every call, refused ones too, is logged in `~/.local/state/vikix/mcp.log` (600): the tool, whether it worked, its arguments (secrets taken out, long ones cut, with their length and a hash).

## vikix-memory

What uses the memory, what's left over, a warning when it runs low.

- `vikix memory` — memory and swap, the biggest programs (each with all its processes), files kept in memory (/tmp), and the programs left over
- `vikix memory left` — only the programs left over, each with why
- `vikix memory clean` — end the left-over ones: those that surely are, after a yes; the "maybe" ones one by one
- `vikix memory clean --yes` — end those that surely are, without asking
- `vikix memory watch` — what vikix-session starts: looks every 15 seconds, warns once when memory is low (under 15% free for programs) and again, urgently, when it's nearly full (under 7%, or the machine already stalls), says when left-over programs pile up, and writes the bar's field (mem 91%); nearly full, it ends the programs surely left over by itself, and says so
- `vikix memory watch --once` — one look, printed

Left over means nobody can be using it:

```
for sure   a program on a hidden screen (Xvfb) whose starter has gone, or
           on a screen that no longer exists, or a test's program whose
           home is a temporary folder
maybe      a program an AI agent's command started and left behind, one
           whose folder was deleted, an editor with no window
```

and always: its starter has gone (it belongs to nobody), it has no terminal, no window on your screen, and it's older than 10 minutes, so a test that's running is left alone.

The last resort is earlyoom, a system service Vikix switches on: when memory is all but gone (5% free, and a quarter of the swap used) it ends one program rather than letting everything stall: a test's or a build's first (Xvfb, sbcl, compilers), then the biggest of the rest, an AI agent's session, the browser itself and a virtual machine only when nothing else is left, and never the desktop (Xorg, StumpWM, Emacs, sound, a terminal). The watcher says what it ended. /etc/sv/earlyoom/conf is Vikix's (config/earlyoom/conf).

`VIKIX_MEMORY_LOW` and `VIKIX_MEMORY_CRITICAL` change the two levels (percent free), `VIKIX_MEMORY_LEFT_AFTER` the minutes; `VIKIX_MEMORY_AUTOCLEAN=0` keeps the watcher from ending anything.

## vikix-music

A Lisp musical sketchpad, with SuperCollider making the sound.

- `vikix music setup` — compile the sound palette and prepare a first pattern (vikix add music)
- `vikix music doctor` — check the engine, PipeWire JACK and prepared palette
- `vikix music check FILE` — check pattern data without making sound
- `vikix music send [FILE] [--pattern NAME] [--repeat N] [--format both|midi|wav]` — export finite per-pattern MIDI and offline WAV into song/render
- `vikix music tone [HZ]` — one quiet, short tone (880 Hz by default)
- `vikix music play [FILE] [--pattern NAME] [--bars N]` — repeat a pattern, loading edits at the next bar; Ctrl+C stops it and its own engine
- `vikix music repl` — a separate Lisp REPL: (tone 440), (play "FILE"), (stop), (quit); also usable as an Emacs inferior Lisp
- `vikix music serve [FILE]` — prototype shared session; Ctrl+C ends its player
- `vikix music web` — open the browser grid for the running session
- `vikix music control play|stop [--notify]` — control the running shared session (never start a service)
- `vikix music control bank [1..32]` — play an assigned pad; without a slot, pick one
- `vikix music control state` — print shared session state as JSON
- `vikix music control bar` — quiet sampled beat/tempo text; empty when stopped
- `vikix music control record [--source engine|microphone|mixed] [--device NODE]` — explicitly start a take (default engine only; play first)
- `vikix music control record-stop` — stop recording, preserving partial audio on failure
- `vikix music control record-state [--notify]` — show the active recording source or last capture error
- `vikix music control inbox` — list preserved takes as JSON
- `vikix music control preview|loop --take ID` — listen once or loop a stopped take
- `vikix music control preview-stop` — stop capture preview or looping
- `vikix music control file --take ID --song NAME` — copy a take under a song; keep the inbox original
- `vikix music cuis` — open a disposable Cuis grid for the same session
- `vikix music uninstall` — remove the prepared sounds; keep your music

Patterns are yours, `~/music/first-song/patterns.lisp` to begin with. Use (tempo 120) and (defpattern bass '(c4 - e4 -)); - is a rest. Files are read as data, never evaluated. A bad edit keeps the last good pattern. Optional (bank 1 bass) saves pad assignments (slots 1–32); without a bank, pads use file order. Edit assignments in the browser, with snapshot undo. Patterns optionally take :sound 'sine|kick|snare|closed-hat|bass|bell, :gain 0..1 (relative to session gain), and :swing 0..0.5 (even step counts). Drums use x hits and - rests; melodic x remains 220 Hz. The browser edits these data fields with undo. Session gain stays at 0.08 by default, capped at 0.1. Run setup again to compile the palette after an older Music install. Progressions use (defprogression verse '(I (vi 2) - V) :key 'f): major uppercase/minor lowercase triads, whole-bar blocks and silent rests. The browser edits degrees, key, durations and order with undo; see the Music guide. Snapshot before editing; vikix undo restores patterns at the next bar. The REPL evaluates your Lisp locally. There is no remote evaluation service.

## vikix-net

The network link as one short line, for the mode line.

- `vikix-net` — print the line; it takes no arguments

```
wifi VID       Wi-Fi: the network's name
wifi VID 42%   and its signal, when it is weak (under 60%)
wired      a cable, and no Wi-Fi
offline    neither
```

Asks NetworkManager. Prints nothing when it isn't running, so the bar leaves the field out instead of showing something wrong.

## vikix-network

The Network Office: nearby devices, ports and connections.

- `vikix network` — open the Network Office in your existing Emacs
- `vikix network status` — local network information as JSON; no scan
- `vikix network refresh` — apply saved discovery choices, then return status
- `vikix network discover ID` — discover devices on the selected network
- `vikix network ports ID ADDRESS` — check common TCP ports on a local device
- `vikix network identify ID ADDRESS` — probe services for names, versions and OS clues
- `vikix network name ID ADDRESS NAME` — save a friendly name; an empty NAME clears it
- `vikix network policy ID MODE` — remember manual, discover or ports for this network
- `vikix network watch` — watch joins and apply each network's saved choice

ID is the network id from status. New or incompletely identified networks start in manual mode. Discovery checks directly connected IPv4 subnets, at most 1024 addresses altogether; it never sweeps a VPN or an IPv6 prefix. Port checks cover common TCP services, not every port or UDP. They run as you, without sudo. Discovery looks up DNS names and tries Avahi when available. Identify explicitly probes service versions; OS clues are tentative, not OS fingerprints. Ordinary port names are suggestions, not proof of what is listening. Devices can be hidden by a firewall or Wi-Fi isolation; a missing reply does not mean a device is off.

Preferences live in `~/.config/vikix/network/preferences.json`. Results are temporary, in the session's runtime directory, and expire after ten minutes. Friendly names use the network identity and device MAC, never its IP alone. No device history is kept. The session starts watch at login; after an update, log in again for discovery on joins while the Office is closed. Opening the Office applies saved choices too. See the guide's Network Office page.

## vikix-nightlight

A warmer screen in the evening (gammastep).

- `vikix-nightlight start` — at login: start it, unless you switched it off
- `vikix-nightlight toggle` — on or off, and remember that (Super+Ctrl+l)
- `vikix-nightlight on|off` — the same, one way
- `vikix-nightlight status` — say whether it is on, and when it warms

The times and colours are in `~/.config/gammastep/config.ini`. Switched off, gammastep ends and puts the screen's colours back; the choice lasts across logins, until you switch it on again.

## vikix-node

A remote Void machine as a node of this Vikix.

- `vikix nodes [--last]` — the nodes, one line each: name, kind, online or not, the system, what runs there; this machine first. Each is asked over SSH (a few seconds at most); --last shows the last answers, asking none
- `vikix node add NAME [USER@]HOST [--port N] [--kind WORD]` — a node: it is reached once now, so you confirm its host key yourself, then kept in `~/.config/vikix/nodes/NAME`; the kind is cloud unless you say (build, home, ...)
- `vikix node remove NAME` — forget it; nothing on the machine is touched
- `vikix node status NAME` — the system, kernel, uptime, load, memory, disk, the services and the programs running there
- `vikix node shell NAME` — a shell there, in this terminal
- `vikix node run NAME COMMAND...` — run it there, your input and its output passed through, its exit status yours

A node is reached by SSH alone, as yourself, by key: nothing of Vikix's is on the node, and ssh HOST is the same machine. Keys only: no password is ever kept or asked after add, so a node without your key says so (ssh-copy-id puts it there). The host key is verified: add shows it for you to confirm, and from then on a changed one refuses. Nothing is sent to a node but what you ask; nothing is synchronised.

The nodes are files, `~/.config/vikix/nodes/NAME` (host=, port=, kind=), yours to edit; what each answered last is `~/.local/state/vikix/nodes/NAME`, and add and remove are noted in `~/.local/state/vikix/nodes/log`.

## vikix-notes

Ask your notes, from any terminal (`note` for short).

- `note index ~/Notes --skip Private` — the first time: the folder, and folders to leave out
- `note index` — again: only the notes that changed
- `note ask "what did I write about runit?"`
- `note ask --claude "..."` — Claude answers this one (--local: the laptop)
- `note find "runit"` — the nearest notes, without an answer: quick
- `note status` — the folder, the index, who answers
- `vikix notes setup` — the feature notes: uv's libraries and the embedding model (all-minilm, 46 MB), once
- `vikix notes uninstall [--index]` — --index deletes the index too

Ask your notes, from any terminal (`note` for short). A folder of Markdown (an Obsidian vault) is read into an index on this laptop; a question finds the passages nearest it, and a model answers from those alone, naming the notes.

Who answers follows Super+i: `vikix ai use local|claude`. Locally nothing leaves the laptop; with Claude, the six passages found (never the whole folder) go to Anthropic. The folder and skips are yours, in `~/.config/vikix/notes`; the index is `~/.local/share/vikix/notes/index.db`. lib/notes.py does the work, run by uv with its libraries pinned at its top.

## vikix-notifications

The notifications dunst has put away, in rofi, newest first.

- `vikix-notifications` — the list, in rofi
- `vikix-notifications last` — the newest one, in a line: its id, the program that sent it, its title and how many seconds ago it came, tab-separated; nothing when there is none. For "why did that happen?" (vikix why)

The notifications dunst has put away, in rofi, newest first. Pick one and it shows again. (s-N, or s-m then "Notifications: earlier ones".)

## vikix-obsidian

An Obsidian vault, converted to Org notes, a folder at a time.

- `vikix obsidian` — what's in the vault, folder by folder, and which are converted
- `vikix obsidian convert FOLDER...` — convert those folders of the vault ("." for the notes at its top); a report of each
- `vikix obsidian convert --all` — every folder not left out
- `vikix obsidian report [FOLDER]` — the last conversion's report

The vault is only read, never changed. Each note becomes an Org file in the same place under `~/Dropbox/notes/vault/`, with an ID, so links between notes become org-roam links (C-c n f finds them, backlinks and the graph follow), even to a folder not converted yet: they work once it is. The note's title, aliases and tags come from its file name and front matter; pandoc does the rest of the Markdown.

What Obsidian has and Org hasn't is said in the report: a link to a note that isn't there (or is in a folder left out), a note embedded in another (it becomes a link), ==highlights== (bold), callouts (a quote). Files a note embeds or links (pictures, PDFs, sound) are copied beside the notes, in vault/attachments/, as they are in the vault; only those, not every file in it.

Converting a folder again rewrites its notes, except any you've changed since (the report names them; --force rewrites them too).

Settings: `~/.config/vikix/obsidian` (vault=, to=, skip=: folders left out).

## vikix-osd

Change volume or brightness and show a bar for it.

- `vikix-osd volume up|down|mute|mic`
- `vikix-osd brightness up|down`

The bar is a dunst notification with a progress value. The stack tag makes each new press replace the last bar instead of piling up.

## vikix-palette

Everything in one box (Super+Space).

- `vikix-palette` — open it: the launcher, listing your windows on every workspace, the workspaces in use and the named ones, every Vikix command (with its key), your projects, web apps and saved layouts, and the programs, all at once. Type a few letters, Enter.
- `vikix-palette --list [TEXT]` — what it would offer, in the terminal; with TEXT starting with a sigil, what that search finds

Enter on a window goes to it, wherever it is; on a workspace, goes there (the ones with windows, and the named ones past the nine); on a command, runs it; on a project, opens it (a terminal in its folder, its log in the editor); on a web app, brings it forward or starts it; on a layout, puts this workspace back as it; on a program, starts it.

A sigil first asks for one kind of thing, and Enter searches instead of picking; the hits fill the box, and Enter on one opens it. The empty box names them (its placeholder: "Type, or  > menu  @ desks  # docs  ? what / files"), and the line goes as you type:

```
> words      the Vikix menu (Super+m), every entry of every section,
             and the commands: Enter runs the one picked
@ words      your projects and the agents' desks: Enter opens the
             project, or goes to the desk's window
# words      the docs catalogue (vikix docs): Vikix's guides, your
             projects' documents and notes, man and tldr pages, the
             manuals; Enter opens the hit, Ctrl+Enter the other way
             (a terminal for a man page, Emacs for Markdown)
? name       what is this: the card for a field of the bar, a key, a
             process, a service, a package, a command or a file (vikix
             what); ? alone lists what the desktop did lately (vikix
             why), and Enter on a line opens Super+?'s choices
/ words      a file or folder under your home folder, by its name (fd:
             the first word is the pattern, the others must be in the
             path; hidden folders and mounted drives left out); Enter
             opens it, Ctrl+Enter shows it in its folder (Esploro, or
             the file manager)
```

The launcher's own ! filters its lists by mode (!drun), so no sigil of Vikix's is !. Super+d is still the plain launcher, programs only. When the desktop doesn't answer within a second and a half, the box opens with the projects and the programs alone.

## vikix-pkg

Single programs, beyond the features.

- `vikix pkg add [NAME...]` — install these; without names (or with words that aren't one), search Void's packages and pick
- `vikix pkg drop [NAME...]` — uninstall these, or pick from what's installed by name. One that Vikix's lists name goes on your skip list, so vikix update doesn't bring it back
- `vikix pkg list` — the packages you dropped (your skip list)

A whole language, an editor or LibreOffice is a feature: vikix add and vikix remove. This is for one program: GIMP, a game, a font.

Your skip list is `~/.config/vikix/packages-skip`, one package a line; 10-packages leaves those out. Adding a package again takes it off.

## vikix-plugin

Small additions to Vikix, from the vikix-plugins repo.

- `vikix plugin list` — the plugins there are; yours marked, those from another repository with it
- `vikix plugin add NAME [--yes]` — shows what it runs, needs and changes, asks, then adds it (its packages, its setup)
- `vikix plugin add NAME --from REPO [--at COMMIT] [--yes]` — the same for a plugin from another repository (an address, or a folder on this machine): the folder NAME/ in it, or the repository itself when its manifest is at the top; pinned at COMMIT (a commit, a branch or a tag; none: its newest), written in your list
- `vikix plugin pin NAME [COMMIT]` — move one from another repository to COMMIT (none: its newest) and fetch it
- `vikix plugin remove NAME` — runs its remove, and takes it away; your settings for it stay
- `vikix plugin off NAME` — stop loading it, nothing else changed (from a text console too, for one that hangs the desktop); vikix plugin on NAME brings it back
- `vikix plugin safe` — the next login loads no plugin, once
- `vikix plugin status` — the pinned commit, and yours; each from another repository with its own
- `vikix plugin sync` — the repo to its pinned commit, and each plugin from another repository to its (vikix update does this when you have plugins)

Small additions to Vikix, from the vikix-plugins repo (github.com/vukini/vikix-plugins) or from a repository of your own: a few words in the bar, Super+m entries, keys, a program started with the desktop.

Vikix keeps the repo in `~/.local/share/vikix/plugins` at the commit pinned below, one it has checked: an update can't swap a plugin's code in silently. Your plugins are named in `~/.config/vikix/plugins.list`, your settings for each in `~/.config/vikix/plugins/NAME` (copied once, yours). A plugin from another repository is a line "NAME from REPO at COMMIT" there: the commit is yours to move (vikix plugin pin), its checkout is `~/.local/share/vikix/plugins-from/NAME`, and Vikix hasn't checked its code. A plugin's programs (its bin/) are linked into `~/.local/bin` while it's added, each with its man page (man inbox). Its Lisp runs inside StumpWM (plugins.lisp loads it).

## vikix-project

Your projects, each a folder with a log.md.

- `vikix project [list] [--all]` — one line each, most recently logged first: name, % done, the last entry's date, the next step (--all: projects with no entries yet, too)
- `vikix project show NAME` — title, folder, log, its Status, the last 3 entries
- `vikix project path NAME` — the folder: cd "$(vikix project path lambda)"
- `vikix project log NAME "what was done" [--next "..."] [--status "few words"] [--agent]` — a new entry for today at the top of the log, marked (Vid) unless --agent (or run from Claude Code); never committed: it says how
- `vikix project open NAME` — the project on a workspace of its own: a terminal in the folder, the editor on its log, placed as you left them (its saved layout); the workspace it has still, if it's open
- `vikix project save [NAME]` — save the layout of its workspace now (leaving the workspace saves it too): vikix layout project-NAME
- `vikix project build NAME [-n]` — run its build in its folder (-n: only say which)
- `vikix project check NAME [-n]` — run its checks in its folder: the log's Check line, check.sh, check, tests/run.sh, test.sh, make check or test, npm test (-n: only say which)
- `vikix project new NAME [--in COLLECTION | --log-apart] [--title "..."] [--next "..."]` — a new project: `~/src/NAME` (the first root) with a log.md (a Status and a first entry); --in: inside a collection; --log-apart (--private, its old name): the repo `~/src/NAME's` log in the logs folder, out of a public repo; a FOLDER (with a /, or .) gives that folder a log.md
- `vikix project new NAME --git | --github public|private [--description "..."] [--log-apart]` — the same, as a git repository: a README.md (the title, the description), the log unless apart, one commit; --github makes the repository on GitHub too (gh, signed in: gh auth login), public or private, with the description as its About, origin set, and pushes once through gh's login over HTTPS, so your SSH key is not asked for (origin keeps gh's protocol for your pushes)
- `vikix project today [yesterday|DATE] [--no-git]` — (also: vikix today) what was done that day, project by project: the log entries and the commits (any branch), then what's next
- `vikix project pick` — choose one with rofi and open it (Super+Alt+p)

What a project is: a folder under a root (`~/src` unless `~/.config/vikix/projects` says otherwise), at most `depth` levels down (2), with a log.md in it. A folder inside a project folder is a project of that collection (living-series/living-in-lambda). Hidden folders, `node_modules` and git worktrees (their .git is a file: they'd count a project twice) are skipped. A public repo keeps its log apart: a repo with no log.md whose name has `<logs>/NAME/log.md` (`logs=~/src/project-logs`) is a project with that log.

A log, newest first:

```
# Log: Title
**Status** (...), as of 2026-09-12: 93% complete.
- Standing: where it is
- Next: what comes next
- Build: make site          (optional: overrides the build found)
- Check: make test          (optional: overrides the checks found)
```

```
## 2026-09-18 · status words (Vid)
What was done.
Next: what comes next.
```

Names match exactly, then by a prefix or a part of the name that only one project has; a collection's project also answers to collection/name.

## vikix-publish

Books from Markdown.

- `vikix publish [NAME|DIR] [epub|pdf|check|links] [--no-log]` — build the book in DIR, or the project called NAME in `~/src` (the folder's name, or the name in its publish.yml), or the folder you're in: an EPUB and a PDF into its out/ (both, without a format), and an entry in the project's log.md saying what was built (--no-log: none); check checks the spelling and the links, then builds both into a scratch folder and keeps nothing; links checks the links alone: a #heading must be in the book, a file beside the text must be there, an address on the web must answer (asked once a week; with no network, left for next time)
- `vikix publish [NAME|DIR] --send [--to FOLDER]` — build the EPUB, then put it on the reader plugged in: a Kindle or Kobo mounted as a drive (into documents/, or the top), any drive with a Books folder, an Android reader such as a BOOX in file transfer mode (its Books folder, over MTP), or one with USB debugging (adb, /sdcard/Books); --to names the folder
- `vikix publish [NAME|DIR] spell [--keep] [--no-commit]` — the words the dictionary doesn't know, by chapter; --keep adds them to the book's words.txt, to read, and in a git repository commits that file
- `vikix publish new DIR [--title TITLE] [--lang LANG] [--no-commit]` — start a book in DIR (made if it isn't there): publish.yml, a first chapter, an empty words.txt, out/ in .gitignore, and the make targets in its Makefile (the line added to one already there); never over a book that's there. In a git repository what it wrote is committed
- `vikix publish skill [ZIP]` — the doc-to-epub skill for claude.ai, made from this pipeline (its SKILL.md, fix-tables.py and epub.css), as a zip to upload (Settings, Capabilities, Skills); `~/Downloads/doc-to-epub.zip` without ZIP
- `vikix publish setup` — the packages, epubcheck (a pinned release, checked against its checksum), the British English, Esperanto and Arabic dictionaries (LibreOffice's, pinned and checked the same way) and the shared make targets
- `vikix publish status` — which tools and fonts are here
- `vikix publish uninstall`

Books from Markdown: an EPUB and a PDF, built and checked the same way in every project (vikix add publish).

A book is a folder with publish.yml (pandoc's metadata: title, author, lang; and Vikix's: name, chapters, mainfont) and its text in `chapters/*.md` (taken in name order) or book.md. The EPUB goes through pandoc, then the fix for e-ink readers (tables become row cards, one-cell boxes asides: what the doc-to-epub skill learned on a 7-inch screen), then epubcheck; one epubcheck rejects is kept as NAME.epub.rejected, not as the book. The PDF goes through pandoc's Typst writer, in IBM Plex Serif (Amiri when lang is Arabic, or mainfont in publish.yml), and one Typst warned about is NAME.pdf.rejected. The spelling is the book's lang (any English is checked as British), and a passage marked ::: {lang=eo} or [vorto]{lang=ar} in its own; code isn't prose. words.txt beside publish.yml holds the book's own words, one a line.

A build into out/ is noted in the project's log (the log.md vikix project knows, when the book is a project): a dated entry, "published", with the files and their sizes. --no-log, or `VIKIX_PUBLISH_LOG=0`, leaves the log alone.

What this command writes into a book that is in a git repository (its words.txt, a new book's first files, the log's entry) it commits, those files alone: nobody else would, and the project would say "not committed" at every push. A file that had changes of yours waiting is left to you, and said; so is everything during a merge or a rebase. --no-commit, or `VIKIX_PUBLISH_COMMIT=0`, leaves git alone.

In a project's Makefile, last, the same as make targets (epub, pdf, check):

```
-include $(HOME)/.local/share/vikix/publish/publish.mk
```

## vikix-record

Record the screen to a video, without sound.

- `vikix-record area` — drag out an area, or click a window, and record it
- `vikix-record screen` — record the whole monitor the pointer is on
- `vikix-record stop` — stop, and save `~/Videos/Recordings/<date>.mp4`
- `vikix-record toggle [area|screen]` — stop if recording, else start (Super+Ctrl+v)
- `vikix-record status` — say whether it is recording

While it records, the bar says rec. The file holding ffmpeg's process id is also what the bar reads, so it is removed whenever ffmpeg ends, however it ends.

## vikix-records

Where plugins keep what they found, to search and use later.

- `vikix records search TEXT [--plugin P] [--limit N] [--json]` — full text (title and body), newest first; words as in a search box: dubai emirates, "exact words", dxb OR sin
- `vikix records list [PLUGIN] [--kind K] [--since 30d] [--limit N] [--json]` — newest first; --since takes 2h, 30d, 6w, 1y
- `vikix records get ID [--json]` — one record, with all its data
- `vikix records add` — a record (or a list of them) as JSON on stdin: plugin, kind, title (needed); key, body, data, link, at (Unix time) as wanted. The same plugin, kind and key again updates that record rather than adding another
- `vikix records export [--org|--jsonl|--csv] [PLUGIN]` — everything, to read in Emacs (Org) or to give a program
- `vikix records forget PLUGIN [--kind K] [--older 1y]` — remove records (asks, unless --yes)
- `vikix records stats` — how many, by plugin and kind

The store is one SQLite file, `~/.local/share/vikix/records.db`, kept by vikix backup. Any program can read it with SQL: the table is records (id, plugin, kind, key, at, title, body, data, link), and `records_fts` is its full-text index.

## vikix-rescue

A way out when the desktop is stuck.

- `vikix rescue` — how the desktop is: coming round, waiting (a menu is open), or stuck; what its main thread is doing, which rules ran in the last second, and whether a lock screen is up
- `vikix rescue free` — free a stuck desktop: pause every rule and make focus follow clicks, not the mouse; if its loop still doesn't come round, start a fresh event loop (your windows and settings stay as they are)
- `vikix rescue undo` — put rules and focus back as they were (a reload, Super+m then Reload config, does the same)
- `vikix rescue lock` — bring the lock screen in front of the windows, when the screen is locked and you can't see it

`vikix eval` and the agents' tools go through StumpWM's one main thread, so they time out when it is stuck. This asks over the same door (Swank, 127.0.0.1:4004, with its password) but is answered by another thread. It works from any terminal, from a text console (Ctrl+Alt+F2, log in) and over ssh.

On the desktop itself, Super+Ctrl+Alt+Escape does what `vikix rescue free` does: StumpWM reads that key on a connection of its own, so it works when the other keys don't. A watcher inside StumpWM tells you when the desktop is stuck, and frees it by itself after a while (rescue.lisp).

Exit status: 0 the desktop is coming round (or was freed), 1 it is stuck or waiting, 2 StumpWM could not be asked.

## vikix-resume

Your windows back after a restart.

- `vikix resume` — what is saved (how many windows, on how many workspaces, when), and what a login does with it
- `vikix resume now` — bring them back now: each workspace in turn as it was, its programs started again in their folders
- `vikix resume save` — save the workspaces now (it is done by itself every five minutes, and when the desktop ends)
- `vikix resume ask` — at login, ask first (as it starts out)
- `vikix resume always` — at login, bring them back without asking
- `vikix resume never` — at login, leave it; `vikix resume now` still works

The desktop saves each workspace as a layout (which windows, where, and how each was started) in `~/.local/state/vikix/resume/`. What comes back is what can be started again: a terminal in its folder with the program that ran in it, a program by its command line, a web app, an Emacs frame on its file. What a program had open inside it is its own to bring back. Super+m has "Bring my windows back" too.

## vikix-rofi

Rofi's plugin modes, set up the Vikix way.

- `vikix-rofi emoji` — pick an emoji: Enter types it into the window you were in (and copies it too), Ctrl+c only copies it. Search by name or keyword: heart, cat, thumbs up.
- `vikix-rofi calc` — a calculator that answers as you type (qalculate): 340 `*` 12%, 5 ft to cm, 100 USD to EUR, today + 30 days. (Not "12% of 340": qalculate reads that % as a remainder.) Enter copies the answer to the clipboard; Ctrl+Enter keeps it in the list below instead.

Both are rofi plugins (rofi-emoji, rofi-calc in packages/desktop.list). Without one, a notification says what to install instead of rofi failing silently.

## vikix-rules

The desktop's rules, seen and steered.

- `vikix rules` — the list: each rule's number, on or off, how often it ran and when last, the rule, where it's written; under one that is off or failed, why
- `vikix rules off N|NAME` — switch a rule off, until the next reload: by its number in the list, its :name, or words only its text has
- `vikix rules on N|NAME` — switch it on again (one switched off after three failures gets three more tries)
- `vikix rules why [CLASS]` — why a window is where it is: the rules that ran for it, and those that match it but haven't run, each with the reason. The window in front, or those of that class (or with CLASS in their title)
- `vikix rules test [N|NAME]` — what the rules for a window opening would do with the windows open now (or that rule alone); nothing is done
- `vikix rules apply [N|NAME]` — do it: run them on the windows open now. A reload never moves windows already open; this does
- `vikix rules forget N|NAME` — take a rule out of `~/.stumpwm.d/rules.lisp` and off the desktop, after a snapshot (vikix undo puts the file back). Only a rule written in that file: one Super+Shift+t remembered, or one of yours
- `vikix rules verbs` — what a rule can be, match and do: the rules, the matchers and the verbs, each with its line
- `vikix rules now` — what the rules for screens, networks and drives see now: each one's name, as a rule writes it
- `vikix rules proposed` — the rules an agent has proposed and you haven't decided on: each with its why, and what it would run. Super+m, Rules adds one or drops it

The rules are written in `~/.stumpwm.d/rules.lisp` (or user.lisp):

```
(when-window (:class "Firefox") (workspace 2))
(at "09:00" :weekdays (open-project "vikix"))
```

and live in the running StumpWM, which this asks (vikix eval): the counts are since the last reload, and off lasts until the next one, which reads the files again. Super+m, Rules is the same list in a menu.

An agent doesn't write your rules: it proposes one (the MCP server's `propose_rule`), checked to be a rule made only of verbs and plain values, and the rule waits until you add it or drop it under Super+m, Rules.

Super+Shift+t writes one for you: the rule that puts a window like the one in front where it is (its workspace, and when it floats its size and place), shown first, then added to rules.lisp as "remembered: ...".

## vikix-screens

The screens: a new one lights up by itself, and a menu for the rest.

- `vikix screens` — what's connected: each screen, on or off, its mode
- `vikix screens pick` — a menu (Super+Ctrl+p, or the laptop's display key): extend, mirror, the other screen only, the laptop only, arrange by hand (arandr), save as it is
- `vikix screens extend` — every screen on, the others to the right of the laptop's, each at its best mode
- `vikix screens mirror` — every screen showing the same, at the largest size all of them can
- `vikix screens external` — the other screen(s) only, the laptop's off
- `vikix screens laptop` — the laptop's screen only
- `vikix screens auto` — as autorandr does on a plug (below), now

When a screen is plugged in, autorandr (its udev rule) looks for a layout saved for these screens and puts it back. For screens it has never seen it did nothing: the screen stayed dark. Vikix's hook (predetect, which autorandr runs first) lays them out instead: the others to the right of the laptop's screen, each at the largest size it shows at 50 Hz or more (a 4K screen on an HDMI 1.4 port gets 2560x1440 at 60, not 4K at 30), and saves that, so next time it comes straight back. A screen unplugged: the laptop's alone again. Whatever you pick in the menu is saved the same way, for these screens. A notification says what was done. StumpWM follows by itself.

The layouts are autorandr's, in `~/.config/autorandr` (yours): Vikix's are named auto-..., and one you save under a name of your own wins.

## vikix-screenshot

Keep a picture of an area, a window or the whole screen.

- `vikix-screenshot [WHAT] [WHERE]`

```
WHAT    area     drag out an area, or click a window    (Print)
        window   the focused window                     (Ctrl+Print)
        screen   the whole monitor the pointer is on    (Super+Print)
WHERE   clip     to the clipboard, ready to paste
        file     to ~/Pictures/Screenshots/<date>.png   (add Shift)
```

- `vikix-screenshot text` — drag out an area: the text in it, read by tesseract (OCR), to the clipboard
- `vikix-screenshot colour` — click anywhere: that colour, as #rrggbb, to the clipboard (xcolor)
- `vikix-screenshot --geometry area|screen` — print the area as WxH+X+Y (vikix-record uses it)

Text and colour are both in the Super+Ctrl+Print menu. The OCR language is English; `VIKIX_OCR_LANG=deu+eng` (with tesseract-ocr-deu installed) reads others.

Both words are optional: plain vikix-screenshot is "area clip", and "vikix-screenshot file" is "area file", as before there were three kinds. Escape or a right-click while choosing an area cancels, and nothing is kept.

## vikix-session

Everything that runs for the length of a desktop session.

- `vikix-session` — the session; `~/.xinitrc` runs it, nobody else should

Started by `~/.xinitrc` inside dbus-run-session, so every program here shares one session bus. Without systemd there are no "user services": the background programs are simply started here, and they end when StumpWM (the last line) exits.

## vikix-steam

Steam, with everything a game needs on Void.

- `vikix steam setup` — once: the multilib repository, Steam and its 32-bit libraries, the Vulkan driver for your graphics card in both widths, and a higher open-files limit for Proton. vikix add steam runs the same
- `vikix steam status` — what is there and what isn't: the repository, the packages, the card and its drivers, the limit, and where Steam keeps your games
- `vikix steam check` — the same for vikix doctor: one line when all is well, nothing when Steam isn't chosen, exit 1 otherwise
- `vikix steam uninstall` — before vikix remove steam takes the packages: the card's 32-bit driver and the limit go; your games, in `~/.local/share/Steam`, stay

Steam is a 32-bit program on a 64-bit machine, and that is why it was a headache on Void: a plain Void has no 32-bit libraries at all, they live in a repository of their own (multilib) that is off by default, and the right ones depend on the graphics card, so one missing library stopped the client, and the next one the first game. This script reads the card from /sys/class/drm (never asks a program), and knows which packages each card wants:

```
Intel (i915, xe)        mesa-vulkan-intel, mesa-vulkan-intel-32bit
AMD (amdgpu, radeon)    mesa-vulkan-radeon, mesa-vulkan-radeon-32bit
NVIDIA, open (nouveau)  mesa-vulkan-nouveau, mesa-vulkan-nouveau-32bit
NVIDIA, proprietary     nvidia-libs-32bit (470: nvidia470-libs-32bit, 390:
                        nvidia390-libs-32bit), from multilib-nonfree
```

What every card needs is packages/optional/steam.list, which vikix update keeps. A card not in the table (a VM's) still gets Steam, and a warning: games that need Vulkan won't run there.

The limit: Proton's esync opens an eventfd for every Wine object, and Void's hard limit of 4096 open files is far too few for a game, so the setup writes /etc/security/limits.d/50-vikix-steam.conf with 524288 for you (the hard limit only; programs raise their own soft one). It takes effect at your next login. Game controllers need nothing: steam-udev-rules tags them for the seat, and elogind hands them to whoever is logged in.

Steam's own files are yours: `~/.local/share/Steam` (the client, the games; tens of GB) and `~/.steam`. Nothing here deletes them.

For the tests: `VIKIX_DRM` stands in for /sys/class/drm, `VIKIX_LIMITS_DIR` for /etc/security/limits.d.

## vikix-theme

The colour theme, everywhere.

- `vikix theme` — the current theme, and the ones there are
- `vikix theme NAME` — switch to NAME, everywhere, now
- `vikix theme import SOURCE [NAME] [--force] [--no-switch]` — an Omarchy theme, as a theme of yours, then switch to it. SOURCE is an https git URL, OWNER/REPO on GitHub, or a folder with a git repository. NAME is the repository's name without omarchy- and -theme, unless you give one. --force replaces a theme of yours with that name (the old files are kept as .vikix-bak); --no-switch only imports
- `vikix theme --refresh` — write the current theme's files again (40-config does this, so a Vikix update reaches them)

A theme is a file of named colours: themes/NAME.theme in Vikix, or your own in `~/.config/vikix/themes/`. Switching remembers the choice and writes the colours out for each program into `~/.config/vikix/theme/`, which your config files include; the programs that are running pick the new colours up now (StumpWM, dunst, kitty, the editors, Nyxt, GTK and Qt, Cuis), and the theme's own wallpaper comes with it. Super+m → Theme is the same, with each theme shown as you move to it. An agent's TUI (Codex, Claude Code) is the exception: it reads the terminal's background once, as it starts, so a switch between a light theme and a dark one names the agent sessions running, which keep their colours until started again. vikix (the everyday command) hands `vikix theme` over to this script.

## vikix-times

How long the desktop takes.

- `vikix times` — this desktop's own measures: logging in (the session started to the desktop ready) and each Reload config, the last and the usual (the median of the last 10), against their limits
- `vikix times files` — the last load of the config (a login or a reload), file by file: how long each took, and whether it came from its compiled copy or from its text
- `vikix times soak [MINUTES]` — the desktop used hard for an hour (or MINUTES) on a hidden screen: windows opening, closing, moving, floating, splits, reloads; fails when StumpWM answers slowly, grows, keeps timers or hooks, or writes an error (lib/soak.py)
- `vikix times soak --ask` — first asks in a dialog (cron, weekly), then runs at low priority and says how it went in a notification
- `vikix times measure` — measure now on a hidden screen, with this checkout's config (a few seconds, nothing on your screen): StumpWM's start, a reload, a key to its command, an Emacs frame, StumpWM answering (and answering with a tiled xterm open, when xterm is installed); kept, so the next one says what changed

The limits are lib/times.limits; tests/times.sh fails above them.

## vikix-updates

What `vikix update` would bring.

- `vikix-updates` — check now, print the result, and save it
- `vikix-updates --watch` — check a minute from now, then every 6 hours; vikix-session runs this for the whole session

What `vikix update` would bring: Void packages with a newer version, and new Vikix commits; and firmware updates waiting on LVFS (`vikix firmware update` installs those). The bar shows it (modeline.lisp).

The result goes to `~/.local/state/vikix/updates` as "PACKAGES COMMITS FIRMWARE", with ? for a count that couldn't be checked (offline, say). Checking takes a few seconds of network, so it happens here, in the background, and the bar only reads the file.

## vikix-used

What gets used: the keys you press and the commands you run.

- `vikix used` — the keys you use most, the menu entries, palette picks, typed commands, rules and agents' commands, and how many keys you have never pressed
- `vikix used never` — the keys never pressed since counting began
- `vikix used all` — every count, most used first, with when each was last used
- `vikix used forget` — start counting again from now

The desktop counts each key that runs a command, each entry picked in Super+m and the other menus, each pick in the palette (Super+Space), each command typed after Ctrl+t ;, each rule that runs, each command an agent runs, and at the door (vikix door) the names an agent's Lisp calls, the name that held a form and whether you ran or dropped it. It keeps names and numbers only: the key, the command it is bound to, the entry's words, and when each was first and last used. Never a window's title, never what you typed into a program or after a command's name.

The counts are in `~/.local/state/vikix/used`, a text file that is yours to read or delete. Nothing sends it anywhere. They are written every five minutes and when the desktop ends.

## vikix-versions

Every version of a file, from both histories, and one brought back.

- `vikix versions PATH [--json] [--limit N]` — every version of a file or folder, newest first, from the backups (vikix backup, restic) and the snapshots (vikix snapshot, the history of your settings): when, where it comes from, the size, what changed. One list; --json for Esploro
- `vikix restore PATH ID [--beside|--replace] [--json]` — bring one back, by the ID the list shows (its start is enough): beside the file as NAME (DATE).ext, or in its place, the current one going to the Trash first
- `vikix versions --help`

Vikix keeps two histories of your files. `vikix backup` holds daily, weekly and monthly versions of all of ~ (restic, encrypted, on a drive or a remote); `vikix snapshot` holds every change to your settings, the files `~/.config/vikix/yours.list` names (git, in `~/.local/state/vikix/yours.git`). This is the one window onto both: the list, from the file, and a restore that never overwrites unless you say --replace, and then only through the Trash. The list is kept for a minute in `~/.cache/vikix/versions/`, since restic takes a few seconds over a year of backups on a USB drive. A backup whose content is the one before it (same size and time) is folded into that row, which then says from when to when; a snapshot is one row per change. A folder's version is everything under it (its size is theirs together), folded the same way.

A restore beside writes NAME (Mon 29 Sep).ext next to the file, or NAME (Mon 29 Sep, 2).ext when that is taken; a folder comes back as NAME (Mon 29 Sep)/. --replace puts the current one in the Trash (gio trash), then the version in its place; what the Trash holds comes back from there (Esploro, or gio trash --restore).

## vikix-vm

Virtual machines: every one libvirt has, in a menu.

- `vikix vm` — the VMs in rofi: yours (qemu:///session, where vikix windows keeps Windows) and the system's (qemu:///system), each with its state, memory and CPUs. Enter on one offers what fits its state: open its screen, start, pause, resume, save (its memory to disk, then off: the next start takes it up where it was), shut down, switch off. After an act the list is shown again, with the new state. Super+m, Apps, Virtual machines opens the same
- `vikix vm list` — the same lines, no menu
- `vikix vm start|open|pause|resume|save|stop|off NAME` — one VM from a shell, by the name the list shows. open shows its screen (virt-viewer), starting it first when it's off; stop asks it to shut down, off switches it off as pulling the plug would
- `vikix vm fresh NAME` — start a saved VM afresh, its saved state thrown away
- `vikix vm status NAME` — one VM: state, memory, CPUs, and which libvirt it's in

A VM that is paused keeps its memory but uses no processor; a saved one uses neither, and starts where it was. The Windows VM (vikix windows) opens as `vikix windows` does, so its checks run. The system's libvirt answers when you are in the libvirt group; when it doesn't, only yours are listed. Nothing here needs sudo.

## vikix-voice

Talk to the AI, and it talks back.

- `vikix voice setup` — install Piper (pinned, with uv) and its voice (checked); a minute, once; no password
- `vikix voice ask TEXT` — what Super+F10 does with what you said
- `vikix voice agent TEXT` — what Super+F11 does
- `vikix voice say TEXT` — read TEXT aloud (- reads it from stdin)
- `vikix voice quiet` — stop talking
- `vikix voice new` — forget the conversation: the next question starts afresh
- `vikix voice voices [NAME]` — which voice: lessac, amy (American), alan (British)
- `vikix voice status`
- `vikix voice uninstall [--voices]`

Talk to the AI, and it talks back. Dictation writes down what you said (on this laptop, whisper.cpp); this sends it on, and Piper reads the answer aloud (a neural voice, on this laptop too).

```
Super+F10         speak, Super+F10 again: the chat model answers
                  (Super+i's: local, Claude or Codex), shown and
                  spoken. Follow-ups carry on the conversation; after
                  5 quiet minutes (idle= below) the next one starts
                  afresh. Codex answers each question on its own
Super+F11         speak, Super+F11 again: it goes to the agent (Claude
                  Code) in its own terminal; follow-ups go to the same
                  one, and Claude's replies are read aloud
Super+Shift+F10   stop talking
```

The choices are yours, in `~/.config/vikix/voice` (made on first use): the voice, speak=no to only show answers, idle= minutes. The chat's words go where Super+i's do (vikix ai use local|claude|codex); the agent's go to Anthropic, as with Super+a. What's said aloud stays on this laptop.

## vikix-wallpaper

The picture behind the windows.

- `vikix-wallpaper` — show the wallpaper (vikix-session runs this at login)
- `vikix-wallpaper pick` — choose one in rofi, with pictures (Super+m, Wallpaper)
- `vikix-wallpaper FILE` — use FILE from now on
- `vikix-wallpaper cycle [MINUTES]` — a new picture every MINUTES (30 unless set), and one at once: the default
- `vikix-wallpaper next` — the next picture now, when cycling
- `vikix-wallpaper theme` — follow the theme
- `vikix-wallpaper off` — leave the wallpaper alone: for your own tool (feh, nitrogen, a script that rotates them)
- `vikix-wallpaper which` — print the picture it would show
- `vikix-wallpaper --watch` — change it on time; vikix-session runs this

Unless you choose otherwise, the wallpaper cycles: every picture once, in a shuffled order, before any comes again, and one you add is shown next, from Vid's collection (the feature wallpapers, in `~/.local/share/vikix/wallpapers`, which a fresh install has), `~/Pictures/Wallpapers` and `~/wallpapers` (put yours in either). The one showing is remembered in `~/.local/state/vikix/wallpaper-now`, the round in wallpaper-queue and wallpaper-shown beside it, the minutes in `~/.config/vikix/wallpaper-minutes`.

Following the theme (`~/.config/vikix/wallpaper-theme`), its own picture is the one next to its theme file with the same name (themes/vikix-dark.jpg, or `~/.config/vikix/themes/mine.jpg` beside mine.theme), so `vikix theme` changes it too. A theme without a picture gets a plain background in its own colour; so does cycling with no pictures to cycle. Your choice is `~/.config/vikix/wallpaper`, a link to the file; off is `~/.config/vikix/wallpaper-off`. Each choice ends the others.

The picker lists the theme's, Cycle, then all the pictures; its last entry is off.

## vikix-wallpapers

More wallpapers: Vid's collection, a git repository.

- `vikix wallpapers setup` — clone it into `~/.local/share/vikix/wallpapers` (vikix add wallpapers runs this)
- `vikix wallpapers update` — pull new pictures (vikix update runs this)
- `vikix wallpapers status`
- `vikix wallpapers uninstall` — delete the clone (vikix remove wallpapers)

More wallpapers: Vid's collection, a git repository (github.com/vukini/wallpapers), kept beside Vikix rather than in it, so the checkout stays small and a fresh install needs no pictures from the network.

The wallpaper cycles through them (vikix-wallpaper), and they show in the picker (Super+m, Wallpaper) beside `~/Pictures/Wallpapers` and `~/wallpapers`. A fresh install adds them. `VIKIX_WALLPAPERS_REPO` names another repository. If `~/wallpapers` is already a clone of it (your own working copy), the folder is a link to that, and Vikix never pulls into it.

## vikix-webapp

A website as a program of its own.

- `vikix webapp add NAME [URL] [--key KEY] [--media|--no-media]` — make one (or change its address). Without a URL, NAME is a preset: mail (fastmail, gmail, outlook for work or school Microsoft 365, outlook-live for outlook.com, superhuman) or meetings (teams, meet for Google Meet, zoom). KEY is a Super key as the key help writes it: s-M-m is Super+Alt+m, which the first mail web app gets; --key none for no key. Adding one again keeps its key unless you give another. --media lets the site use the camera and microphone (the meeting presets do by themselves; --no-media for one that shouldn't)
- `vikix webapp key NAME KEY|none` — give it another key, or none
- `vikix webapp media NAME on|off` — let it use the camera and microphone, or not (from its next start)
- `vikix webapp open NAME` — bring it to the front, or start it (its key, the launcher, and Super+m all do this)
- `vikix webapp list` — the web apps you have, and any logins left over
- `vikix webapp remove NAME [--forget]` — take it away (rm works too); --forget also deletes what it kept: its logins and cookies

Each one is a Chromium window with no tabs and no address bar, with its own window class (vikix-NAME), so StumpWM can find it on any workspace, and its own profile in `~/.local/share/vikix/webapps/NAME`: work logins stay apart from personal ones, and from your everyday Firefox. Its notifications come through dunst while its window is open.

The camera and microphone: a web app's window has no address bar, so Chromium's "allow camera and microphone?" is easily missed, and a meeting's settings then show every device greyed out. A web app with media on (a .vikix-media file in its profile) has both allowed for its own site, written into its profile as it starts (Chromium rewrites that file while it runs, so never before).

Your list is `~/.config/vikix/webapps` (one "NAME URL [KEY]" per line; your own # comments are kept). StumpWM reads it (webapps.lisp) for the keys, the key help and Super+m.

## vikix-welcome

The welcome: first steps on a new desktop, in a terminal, each ticked off once done.

- `vikix welcome` — the steps: add software, the keys that matter, a theme, the keyboard layout, the guide
- `vikix welcome add` — only the software picker (Super+m, Add software)

StumpWM opens it by itself at the first login (commands.lisp), and Super+m, Welcome brings it back. What's done is kept in `~/.local/state/vikix/welcome`, one step a line; that it exists means the welcome has been shown.

The pickers are fzf, which the base installs: type to narrow the list, Tab to pick several, Enter to go, Esc to go back.

## vikix-what

What is this? A part of the running computer, on a card.

- `vikix what` — the thing the pointer is on in the bar (a field, a workspace's number, a window's title), else the window in front: what it is doing now, a few lines on what such a thing is, and where it is explained
- `vikix what NAME` — a thing by its name: a field of the bar (battery, network, clock ...), a key (Super+t, or s-t as StumpWM writes it), a process (its number or its name), a service, a command, a package, a file; when a name fits more than one, the first is the card and the others its rows
- `vikix what KIND [NAME]` — the same, saying which kind: field, key, process, port, service, package, command, file, window, workspace; without a name, what such a thing is
- `vikix what ... --open N` — open the Nth of the card's explanations
- `vikix what ... --card` — the card as a menu on the desktop, which is what the key shows: Enter opens the first explanation
- `vikix what ... --json` — the card as data, for a script
- `vikix what kinds` — the kinds of thing it knows, and which have a page
- `vikix what gaps` — what has no page or no chapter yet: the kinds, the bar's fields, and the services that run here; a writing list, drawn from the machine
- `vikix what check [--vikix]` — the pages, Vikix's and yours (--vikix: Vikix's alone, what its tests ask): every guide, manual, chapter and file they name is there, and none says more than a card holds

Super+Alt+? is the same on the desktop: point at a field of the bar and press it, or press it with a window in front. A click on a field that does nothing else when clicked (the battery, the clock, updates) opens its card too.

A card has three depths. First what this very thing is doing now, read a moment ago: a process's memory and what started it, where a key is written and how often you press it, what a field of the bar shows and where that comes from. Then a short paragraph on what such a thing is. Then the explanations, the nearest first: the section of Vikix's guide, the manual page, the file it is written in, and the things beside it (a window's process, a process's package).

The paragraphs and what each kind points at are pages, a file a kind: the paragraph, then lines such as guide: fixing.md#The desktop feels slow, manual: ps(1), source: bin/vikix-net and see: process. Vikix's are in its config/what. Yours are in the folders `~/.config/vikix/docs` names with what=FOLDER (process.md, service.md, and service-sshd.md for one thing by name, which falls back to service.md): your paragraph replaces Vikix's, your lines come first, and yours may say chapter: PATH#HEADING, a section of one of your own documents (a folder an own= line there names, which the catalogue reads a section at a time; vikix docs help), opened as the catalogue opens it. A window's title and whatever you pointed at are shown on the card and written nowhere.

## vikix-why

Why did that happen? What the desktop did lately, and what made it.

- `vikix why [N]` — the last N things the desktop did (20), newest first: when, what it was (a key, a rule, an entry of the menu, an agent, a notification, a command something asked for), what it did, and where that is written

A window jumped to another workspace, a key did something odd, the layout changed under you: the desktop notes the key pressed and the command it ran, each rule that runs and the window it ran for, the menu's entries, what an agent or a script asked for. The same thing again is one line, counted (×3). It is kept in the running desktop only, fifty at most, until StumpWM starts again; nothing is written down.

Super+? shows the same list on the desktop. Pick a line there and it offers what can be done: edit it where it is written (user.lisp, line 42, in Emacs), take it back when it is a switch or changed the layout, bring a window a rule moved here, switch the rule off until the next reload.

## vikix-wifi

Wi-Fi: pick a network from a list that is scanned first.

- `vikix wifi` — scan, then the networks in rofi: the signal, the name, whether it's saved or in use; Enter joins (a saved or open one at once, a new one asks its password); "Scan again", "Disconnect", and nmtui for the rest (a hidden network, a company login). A click on the bar's Wi-Fi field, or Super+m, System, opens the same list
- `vikix wifi list` — the networks as the list shows them, no menu
- `vikix wifi scan` — scan now and wait for it (five seconds at most)

The list is only as fresh as NetworkManager's last scan, which is what the tray's applet shows, often stale: NetworkManager scans on its own now and then, so a recent stamp is no sign the list is right. So the picker scans every time it opens, waiting five seconds at most (a notification says so; what the scan has found by then is shown), and "Scan again" scans once more. The line over the list says when NetworkManager last scanned, so a scan it refused (one asked too soon after the last) or one still going shows as what it is.

A new network's password goes to NetworkManager through a file of your own (0600, deleted at once), never on a command line. A network that can't be joined this way (WEP, a login with a user name) is sent to nmtui. A password refused leaves nothing saved.

## vikix-windows

Windows in a VM, for the programs that only run there.

- `vikix windows setup [--disk DIR]` — once: the packages, the drivers disc, the shared folder. The disk goes in DIR (default `~/.local/share/libvirt/images`), which needs 40 GB free
- `vikix windows create ISO [--key KEY]` — install Windows from ISO, by itself: about 25 minutes, and a notification when it's ready. Asks for the password of your Windows account. Without a key, Windows 11 Pro installs unactivated.
- `vikix windows [open]` — start it if it's off, and show its desktop in a window
- `vikix windows stop [--force]` — shut Windows down (--force: switch it off)
- `vikix windows status` — is it running, is it installed, where things are
- `vikix windows network` — put the VM on its private network (setup and vikix update do it; asks for sudo only to change something)
- `vikix windows remove` — delete the VM and its disk (asks first)
- `vikix windows apps setup` — once: Windows programs in windows of their own. FreeRDP, Remote Desktop and RemoteApp switched on in Windows (through its guest agent; reachable from this machine only), your account's password kept, `~/Documents` as drive Y: in Windows
- `vikix windows apps` — the programs in Windows' Start menu
- `vikix windows apps add NAME` — one of them in the launcher (Super+d); remove NAME takes it out again
- `vikix windows apps restore` — write again an entry of those that went missing (vikix update does it too)
- `vikix windows app NAME [FILE]` — that program as a window of its own, tiled like any other (Windows started first if it's off); a FILE in `~/Windows` or `~/Documents` is opened in it
- `vikix windows apps forget` — delete the kept password (--all: the launcher entries and the list of programs too, as remove does)

The VM runs as you (libvirt's qemu:///session), so its disk, its TPM and its shared folder are all yours, in your home. `~/Windows` is drive Z: in Windows, and `vikix backup` covers it; the VM's disk it leaves out. The display is SPICE with no network port: only this user can open it.

Its network is private: libvirt's NAT bridge, virbr0 (through qemu-bridge-helper): Windows reaches the internet, and sees this machine only as 192.168.122.1, where nothing that listens on 127.0.0.1 alone can be reached: Swank, CUPS, a local model. (passt, the first network, handed Windows this machine's 127.0.0.1 as its gateway address.)
