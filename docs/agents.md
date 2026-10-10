# Agents at work

One agent is a terminal you talk to. Three or four at once are a small office: each needs a place to work, you need to see who is doing what, and when two reach for the same thing somebody has to say so. This page is how that office runs on Vikix: starting an agent, seeing them all, giving each a desk, and the house rules that hold when they meet. [Working with AI](ai.md) has the rest: which agents there are, keys and models, the desktop as tools.

Three habits carry the whole page:

1. **Start agents with Vikix**, `Super+a` or `vikix agent`, never plain `claude`: that is how they get a snapshot of your files, the Vikix skill, no API keys, and the house rules.
2. **One desk per piece of work**: `vikix agents desk PROJECT TOPIC` makes the place, `vikix agents worker TOPIC "the task"` puts an agent to work there. No desk, no work: an agent off a desk is refused when it reaches for a project's files, and told how to sit down.
3. **`vikix agents` when you lose track.**

## One agent

`Super+a` asks *Agent here* or *Agent at a new desk*, then which agent; the first, with yours (Claude Code, unless you chose another: `vikix agent --default codex`), opens a terminal with it in your home folder (`vikix agents here`). Before the agent starts, Vikix takes a snapshot of your files, so afterwards:

```sh
vikix changes      # what the agent changed in your config, notes, dotfiles
vikix undo         # put it all back
```

The agent knows the desktop from the Vikix skill: ask it in words. *Make Firefox open on workspace 2. Why did this window float? Set the theme to vikix-light.* It proposes rules rather than writing them, asks before it edits, and never gets your API keys or your SSH agent (see *What the agent doesn't get* in [Working with AI](ai.md)).

A second `Super+a`, *Agent here*, is a second agent, and so on. Nothing stops you; the rest of this page is what to do once you have several.

## Seeing them all

`vikix agents help` is the map of the commands, a line each, in the order of this page: seeing them, a desk each, workers, the agent's own, the house rules. `vikix agents help desk` is one command in full, as `vikix agents desk -h` is; `man vikix-agents` has all of it.

```
$ vikix agents
3 agents, 1 waiting for you:
  claude   ~/src/vikix-wifi (wifi, 2 uncommitted)      workspace 4   35 min      working
           wifi · Claude: ◑ Wi-Fi picker
  claude   ~/src/novel-chapter-3 (chapter-3, nothing uncommitted)  workspace 5   2 h 10 min  waits for your yes
           May I run the spell check over the whole book?
  codex    ~                                           workspace 2   12 min      running
```

A line an agent: which one; the folder it works in, with its branch and how many files wait uncommitted there; its workspace; how long it has run; and what it is doing. *Working* and *at its prompt* come from the mark Claude Code keeps at the front of its window's title, or, for an agent whose title says nothing (Codex writes no mark), from the office journal its hooks write: a turn begun, an edit or a command in the last minute is *working (a command 12 s ago)*, a stop let through with nothing after it *at its prompt* ([What holds the rules](#what-holds-the-rules-for-each-agent)); *waits for your yes*, *asked you something* and *finished its turn* from the agent-waiting plugin, when you have it ([Plugins](plugins.md)); under one that waits is what it asked, under the others the title the agent writes in its terminal, after the name its window has on the desktop when it is at a desk (`wifi · Claude`: see [A desk each](#a-desk-each)). An agent whose shell is held by a release or by tests says so instead: *waiting for a release* (its release is in `.claude/release`'s queue, behind another's; under it, since when and behind which), *releasing* (what step the release is at), *waiting for a test slot* (its tests wait for one of the machine's `tests/run.sh` slots, other runs testing) or *testing*. One whose desk is gone while it runs says what is left: *its desk is gone; main has commits to push: gup*, then *its desk is gone and main is pushed: close the terminal* (`--json` has it as `attention`: `asks`, `gup`, `close` or empty; the desktop colours the terminal the same way, see [A desk each](#a-desk-each)). An agent with no window of its own (one in Emacs, one on a text console) comes last, with where it runs. A provider's program that is no session isn't listed at all: one run as a server (`codex app-server`, the daemon runit keeps; `claude mcp serve`; `opencode serve`), or one with no controlling terminal and no window here. A session in a terminal, in tmux, over ssh or in an Emacs terminal has a terminal; an adapter on pipes alone (ACP) has none.

The same list on the desktop: `Super+m` → *AI* → *Agents: who is running, and go to one*. Pick a line and you are on that agent's workspace, at its window. `vikix agents --json` is the list for a script, and the MCP tool `agents` gives it to an agent, so one agent can see the others.

Nothing here stops, signals or types into an agent: the list only reads what is there.

## A desk each

An agent started with `Super+a`, *Agent here*, sits in your home folder, and works wherever you send it. Two of them on one project then edit one working copy: git can't tell whose change is whose, one's half-written edit breaks the other's tests, and neither can commit cleanly. A desk gives each piece of work its own copy, and a worker is an agent put to work at one:

```sh
vikix agents desk vikix wifi-fix
a desk: in ~/src/vikix-wifi-fix, a new worktree on the branch wifi-fix. Nobody sits at it: vikix agents worker wifi-fix "the task" starts a worker there
vikix agents worker wifi-fix "the Wi-Fi picker should scan first"
a worker at ~/src/vikix-wifi-fix, the task its first prompt, on workspace 4
```

What happened: a git worktree of `~/src/vikix` was made beside it, `~/src/vikix-wifi-fix`, on a new branch `wifi-fix`, with a record of its own and nobody at it; then the first empty workspace (4) was taken (when all nine have windows, a new one named `wifi-fix` is made instead, reached with `Super+0` and gone again once it is left empty), and a terminal opened in the worktree with your agent in it, started on the task, the same way `Super+a` does. `Super+4` is now that worker. It commits on its branch, in its folder; `~/src/vikix` and every other desk stay as they are. `vikix agents desk vikix wifi-fix --task "..."` does both in one go.

A desk is the place: the worktree, its branch, its record. A worker is one agent on one task there, and a desk takes its workers one after another, on the same branch: when the first has finished (or you dismissed it), `vikix agents worker wifi-fix "now the password dialog"` starts the next, and the record moves the task before, with how it ended and the agent's last account of it, into the desk's history, which `vikix agents handoff wifi-fix` shows under *Workers before this one*. Two at once are refused: in one worktree git can't say whose files are whose, so the house rules couldn't either; `vikix agents tell` speaks to the one there, `dismiss` ends it. `vikix agents worker wifi-fix` with no task is a session at the desk, an agent to talk with, the record left as it is.

The agent's terminal is named for its desk on the desktop: `wifi-fix · Claude`, the topic and the provider, in the title bar, the window list (`Super+g`), the overview and the palette, from the moment the agent is at the desk (started there, seated with `vikix agents sit`, or taken up again with `resume`) until it leaves. Two of one provider at a desk are `wifi-fix · Claude 1` and `wifi-fix · Claude 2`, each keeping its number while it runs; another provider at the same desk is `wifi-fix · Codex`. The title the agent itself writes (Claude Code's turning mark, which is how *working* and *at its prompt* are read) is kept apart, so nothing it does to its title changes the name, and nothing is lost: `vikix agents` shows both. A terminal whose agent has gone is plain again, or named for the next agent run in it, within half a minute; a terminal with no agent at a desk, and a name you gave a window yourself with StumpWM's `title` command, are left alone.

**Three colours say what a terminal needs of you.** In the bar's window list and in the window's title bar, an agent's terminal takes a colour while something is yours to do with it, and is plain the rest of the time. While the agent *waits for you* (a permission, a question, its last words asking something: what the agent-waiting plugin notes) it has the first colour. Once its desk is gone while the agent still sits in the terminal (a release removed the worktree, or you closed the desk) and the project's own branch has commits its origin hasn't, it has the second: the release waits for `gup`. Once that is pushed too, the third: nothing is left but to close the terminal. The name stays on such a terminal (`wifi-fix · Claude`) so you know which it was. The colours are the theme's, so a light theme and a dark one each have their own: `agent_asks`, `agent_released` and `agent_pushed` in the theme file, or the terminal's yellow, green and cyan where a theme names none (see [Making it yours](customize.md#the-look)). `vikix agents` says the same in words (*its desk is gone; main has commits to push: gup*; *its desk is gone and main is pushed: close the terminal*), and the Office draws the desk in the same colour. Whether the branch is pushed is read from the repository's own ref files, so a push from anywhere (your `gup`, `git push` in a shell) is seen within seconds; nothing here pushes or closes anything.

The project is any of `vikix project list`'s, by any part of its name (`vikix`, `novel`, `nov`). The topic is a word or two for the work: it becomes the folder's ending and the branch's name, so choose one that says what the agent is doing (`wifi-fix`, `chapter-3`, `typos`), not who (`agent-2`). A topic that gives no name for a branch is refused.

`Super+a`, *Agent at a new desk*, or `Super+Alt+d` then `n` (the desk keys: `Super+Alt+d` opens a small card of them, `n` a new desk, `w` a worker at one, `r` take one up again, `c` close one, `h` its handoff, `o` the Office, `t` test a desk's work, `p` pause its agent or let it go, `i` a note for it, `x` dismiss it), or `Super+m` → *AI* → *Agents: a new desk, with a worker when you give it a task*, asks for the project in a menu, then for the topic, then for the task. Enter with nothing is the desk alone. A task typed goes on to the worker's questions: which agent, yours first, the others as `vikix agent --list` has them (one not installed yet is offered its installer in the terminal), and the ones that can run on a model on this laptop; then whether the agent may push as you. No is the usual: the agent commits, you push. Yes sends your SSH agent with it (`vikix agent` keeps it back otherwise: after your first push of the day it holds your unlocked key), so `git push` works at that desk. The Office has the same as a form, **New desk…**, with the worker's choices as boxes to tick (see [The Office](#the-office)). Other forms:

```sh
vikix agents desk notes                       # a project that is no repository: a desk is its own folder
vikix agents worker ~/src/notes "sort them"   # a worker there, on a workspace to itself
vikix agents worker typos "..." --here        # in this terminal, no new workspace
vikix agents worker typos "..." --use codex
vikix agents worker typos "..." --use antigravity
vikix agents worker typos "..." --use aider --local   # on a model on this laptop
vikix agents worker typos "..." --push                # it may push as you (your SSH agent goes with it)
vikix agents worker typos "..." --no-tests            # its tests don't run by themselves when it hands in
vikix agents desk novel typos --task "..." --use codex   # the desk and the worker in one go, with the worker's words
```

A desk that is already there is used again, never made twice: the second `vikix agents desk vikix wifi-fix` says so, and who is at it. A project inside a collection (`books/novel`) gets its own folder inside the collection's worktree, `~/src/books-typos/novel`. A project that isn't a git repository has no worktrees: its desk is the folder itself, and a topic isn't needed; name the folder to `worker`. A repository without a topic is refused: its own folder is for merging only, and no agent works there.

### No desk, no work

Desks only help if agents use them. So the rule, held by Claude Code's hook before every edit: **an agent changes a project's repository only from a desk, and never in the project's own folder.** An agent started with `Super+a`, *Agent here*, sits in your home folder; the moment it reaches for a file in `~/src/vikix` or `~/src/novel`, the edit is refused, and it reads why:

> Vikix office: ~/src/vikix/bin/vikix-wifi is in the project vikix, and you are not at a desk. An agent works on a repository only from a desk of its own, a worktree of it. Take one from here: run `vikix agents sit vikix TOPIC` (a word or two for the work; it makes ~/src/vikix-TOPIC on the branch TOPIC, or takes the one that is there, and seats you at it), then work in that folder and commit there. The project's own folder, ~/src/vikix, is for merging only.

The agent sits down by itself, with no restart:

```
$ vikix agents sit vikix wifi-fix
claude 48213 is seated at ~/src/vikix-wifi-fix: a new worktree on the branch wifi-fix. Work there (cd ~/src/vikix-wifi-fix) and commit there, on the branch wifi-fix; the house rules take that folder as yours now, and vikix agents shows you at it.
```

From then on the desk is that agent's: its edits there pass, `vikix agents` lists it at `~/src/vikix-wifi-fix (wifi-fix, 2 uncommitted)` with the branch and what waits there, and `vikix agents close` refuses the desk while it is seated. An agent that has a worktree already, made by hand or by Claude Code's own worktree support, sits at it with `vikix agents sit` and no more, run from inside it; an agent you started with `vikix agents worker` is at one from the start. A project that isn't a repository has no desks and no rule: the agent works in its folder.

Two more refusals. The project's own folder is refused from any desk, naming the agent's desk (*~/src/vikix is the project's own folder, which is for merging only: no agent changes it. Your desk is ~/src/vikix-wifi-fix: make the change there*). And a shell command is held to the rule when it would write there (`sed -i`, a `>` into a file, `mv`, `git commit`, `git rebase` and the like): the hook reads the command, finds the places it names, and refuses it the same way; a command that only reads (`cat`, `grep`, `git log`, `git worktree list`) passes. The rule holds for every project `vikix project list` knows that is a git repository; a repository that is no project (`~/.dotfiles`) is not ruled. Each refusal is kept in the record store (`vikix records list office --kind refused`).

The listing says who still sits nowhere:

```
  claude   ~ (no desk)                                workspace 1   1 d        at its prompt
  claude   ~/src/vikix-wifi-fix (wifi-fix, 2 uncommitted)   workspace 4   35 min     working
```

### Trying a desk's work on the desktop

A desk's work reaches the running desktop only when it is released, and a release is a version number. Iterating ten times before one is the usual case, so there is a way to run a desk's work on the desktop as it stands:

```
$ vikix try agent-work
:: the desktop takes ~/src/vikix-agent-work: agent-work at 3e23404, not main (vikix try off, or vikix update core, puts main back)
:: stage 10-packages
...
:: StumpWM reloaded: the new keys, bar and menu are in use
!! the desktop runs ~/src/vikix-agent-work (agent-work at 3e23404, since 2026-10-06 21:10; vikix try), not main: vikix update core (gup) puts it back on main
```

The installed checkout, `~/vikix`, is put at the desk's last commit instead of main, and the core update's steps run as after a `gup`: packages new to the lists, services, config links, migrations, StumpWM reloaded. Name the desk by its topic, its branch or its folder, or run `vikix try` with nothing from inside it. The agent commits, you try, you look, you say what is wrong, it commits again, you try again. `vikix try status` says what the desktop runs, and `vikix agents` says it in its first line.

Three things to know. It takes commits: files uncommitted at the desk are refused, and the message says so. One desk at a time: the next `vikix try` replaces the one before, and says which. And a try is never kept over an update: `gup` or `vikix update core` puts `~/vikix` back on main before it pulls, and `vikix try off` does the same at once, with the steps, when you want the released desktop back without pulling. The project's own folder is refused, as everywhere.

### A day with two agents on Vikix

```sh
vikix agents desk vikix wifi-fix --task "the Wi-Fi picker should scan first"   # workspace 4
vikix agents desk vikix docs-pass --task "read docs/ for anything stale"        # workspace 5
```

Each starts on its task, on its own workspace. Each works in its worktree and, when done, finishes with the project's own release step (for Vikix, `.claude/release wifi-fix "..."`), which merges the branch and removes the worktree and the branch: the desk clears itself. A shell of yours still standing in that folder is told so by the next `gup` or `vikix update core` (*the folder this was started from is gone: running from /home/you*), which runs all the same. `vikix agents` meanwhile shows `~/src/vikix-wifi-fix (wifi-fix, 3 uncommitted)` and `~/src/vikix-docs-pass (docs-pass, 1 uncommitted)`, so you can see at a glance who has what in hand.

### A book

```sh
vikix agents desk novel chapter-3 --task "draft chapter three from the outline"
a desk, and a worker at it: in ~/src/novel-chapter-3, a new worktree on the branch chapter-3, the task its first prompt, on workspace 5
```

The agent drafts and commits on `chapter-3`. When you like it:

```sh
cd ~/src/novel && git merge chapter-3     # the work comes in
vikix agents close chapter-3              # the desk goes
the desk is closed: ~/src/novel-chapter-3 removed, the branch chapter-3 deleted
```

Or tell the agent: *merge your branch into main*; the skill tells it how, and it tells you when the desk can go.

### Closing a desk

`vikix agents close` takes a desk down: its worktree is removed, and its branch deleted once the work is in. Name the desk by its topic, its branch, its folder, or as `PROJECT TOPIC`; with nothing named, `Super+Alt+d` then `c`, or `Super+m` → *AI* → *Agents: close a desk*, asks which, and in a terminal without a desktop it lists them:

```sh
vikix agents close
The desks:
  ~/src/novel-chapter-3  (branch chapter-3, in; nothing uncommitted)
  ~/src/vikix-wifi-fix  (branch wifi-fix, not in main yet; 3 uncommitted; at work: claude 48213)
```

It refuses while an agent still works there (*claude 48213 still at work in ~/src/vikix-wifi-fix: let it finish, or close its terminal*) and while files wait uncommitted (*3 files uncommitted: commit there first, or --force throws them away*). A branch that isn't merged yet is kept, and the message says so: merge it, then `git branch -d` in the project, or `--force`, which throws the branch and its work away. The workspace the desk had is simply empty again. When a desk is closed, the agent tells you so in its last message: that the desk is gone, which branch was merged or kept, and what is left for you to do (a push, or trying it on the desktop).

### The handoff: what the desk remembers

A desk outlives the agent at it. Each keeps a small record (`~/.local/state/vikix/office/desks/`, one file a desk, named by the repository and the worktree, never by a process), and `vikix agents handoff` shows it:

```
$ vikix agents handoff wifi-fix
Desk ~/src/vikix-wifi-fix (branch wifi-fix), project vikix  [3f9a1c2b7d4e]
Task (user, 2 h ago): the Wi-Fi picker should scan first, then show the list
Status: review (claude 48213, 20 min ago)
Estimate (claude 48213, 1 h ago): 40 min, if the picker needs no new test; finished in 45 min against 40 min, 5 min over
Done and decided (claude 48213, 20 min ago):
  scan before the list in bin/vikix-wifi; kept the old order under --no-scan
Left to do, next (claude 48213, 20 min ago):
  Vid tries it on the laptop; then release
Checks:
  passed  tests/run.sh wifi  (claude 48213, 25 min ago, on 7c1e0f2, clean tree)  fresh
Now: wifi-fix at 7c1e0f2, nothing uncommitted
Sessions: claude 0f1e2d3c-… (2 h ago)
At the desk now: claude 48213
  claude 48213: pre-edit and pre-shell hooks (vikix agents touch): 14 edits proposed through them
  no filesystem enforcement by Vikix: a worktree keeps copies apart, it is no sandbox
```

Three kinds of line, kept apart and each signed. The **task** is yours, in your words: `vikix agents worker wifi-fix "..."` sets it as the worker starts and gives it to the agent as its first prompt (the task of the worker before goes into the desk's history, with how it ended), so the desk starts working at once (Claude Code, Codex, OpenCode, Gemini CLI and Antigravity CLI take one; Aider doesn't, and is told to read the record); or `vikix agents handoff --task "..."` sets it later. The **handoff** is the agent's: a status (working, waiting, review, finished), an estimate, what it changed and decided, what is left and the very next action. The **estimate** is how long the work will take from the moment it is written, assuming no major issue turns up (`--estimate "40 min, if the picker needs no new test"`: a duration first, in minutes, hours or days, and what it assumes after a comma); an agent started with a task is asked for one as soon as it knows the shape of the work. The record and `vikix agents` count it down (*28 min left of 40 min*, *10 min over its 40 min*), and once the status is finished they say how it went (*finished in 45 min against 40 min, 5 min over*). The clock is the wall's, so time spent waiting for you counts, as it would for a person; an estimate written again starts it afresh. What **Vikix read itself** is the rest: the commit and the uncommitted files at each write, and for a check the commit it ran on and whether the tree was dirty then. A check is marked *stale* the moment the code differs from what it ran on, by another commit or other uncommitted changes, so an old green never passes for a new one. The sessions are the providers' conversation ids and nothing more: no transcript is copied, and a line that looks like a key or a token is refused outright.

The agent writes with the same command, or with the MCP tools `handoff` and `handoff_update`, whichever agent it is:

```sh
vikix agents handoff --status working --estimate "40 min, if the picker needs no new test"
vikix agents handoff --status review --summary "..." --next "..."
vikix agents handoff check "tests/run.sh wifi" --ok
vikix agents handoff session codex 01a111e5-…      # a conversation that can be resumed here
echo '{"status":"waiting","next":"needs the laptop"}' | vikix agents handoff --from -
```

Given any of those settings, `handoff` writes instead of showing (`vikix agents handoff set` says the same, a word longer); from outside the desk, name it first, as for `close`: `vikix agents handoff wifi-fix --task "..."`.

Claude Code's session id and Antigravity CLI's conversation id are noted by the hook itself; the others say theirs with `session`. `vikix agents handoff list` is every desk with a record, `vikix agents` shows each agent's desk status under its line, and `Super+m` → *AI* → *Agents: a desk's handoff* picks one. `vikix agents close` marks the record closed and keeps it, and so does a release that removes the desk (`.claude/release`), so a desk whose work is in shows as closed, not as waiting. A record no longer wanted, of a desk whose worktree is gone, is removed with `vikix agents handoff forget DESK` (the Office's Archive has the same, one record at a time, and *Purge archive* for all of them); without a desk named it lists the ones that could go. It refuses while the folder stands (close the desk instead) or an agent is still in it, and takes nothing else with it: no file, no branch, no saved conversation.

### Taking a desk up again

```
$ vikix agents resume wifi-fix
Desk ~/src/vikix-wifi-fix ...            (the handoff, as above)

resumed: claude session 0f1e2d3c-… at ~/src/vikix-wifi-fix, its conversation continues (its store has it)
on workspace 4
```

`vikix agents resume` shows the handoff, the git state and the checks' freshness, then starts an agent at the desk. When the record names a session and the provider's store still has it, that very conversation is resumed: `claude --resume ID`, `codex resume ID`, `opencode --session ID`, `agy --conversation ID`, each as its installed help says. Otherwise a fresh conversation starts, with the handoff on the terminal above it, and the line says why: no session noted, the provider's store lost it, or the provider can't resume one (Aider has no session ids; Gemini CLI's `--resume` is from its documentation, unverified here). When the provider's own store has a conversation for that folder which the record doesn't name, it is suggested, with the command that notes it, and never taken: nothing resumes the most recent conversation lying about, and nothing starts a second agent at a desk that has one (`--another` does, on purpose). `--fresh` asks for a new conversation, `--use codex` another provider, `--here` this terminal.

### A worker: an agent at a desk, on a task

A worker is what `vikix agents worker wifi-fix "the Wi-Fi picker should scan first"` starts (or `vikix agents desk vikix wifi-fix --task "..."`, the desk and the worker together). The agent is started on the task, its first prompt, with where the desk's record is, so it opens on what the desk is for rather than at an empty prompt. The worker reports by construction. When its status comes to *review*, *waiting* or *finished*, a notification on the desktop says so, with its next step (never for a status that stayed, or for your own change). And a worker that ends a turn having changed files without writing its handoff is asked once, by Claude Code's Stop hook (`vikix agents stopping`, set by `vikix agent` with the house rules), to write it before it stops; the stop after that is let go, so nothing goes round. A desk with no task, a session you are simply talking with, is asked the same way until its record has a status, and then left alone: one line, so the Office never shows the desk with *no handoff*. And a desk the release closes with no status gets *finished* and the release's line, since the work is on main whatever the agent left unsaid.

A note for a worker at work: `vikix agents tell wifi-fix "try the laptop's second card too"`. It waits at the desk, shown by `vikix agents handoff` and counted under the agent's line in `vikix agents`, and the hook hands it to the agent at its next tool call, signed and timed, so nothing types into its window. An agent at its prompt makes no tool call until you speak to it, so `tell` says when that is so: the note waits on your next question to it, not on the hook. Only Claude Code's hook can carry words to the agent: for the others `tell` says so, the note stays in the handoff for the agent to read there, and `resume` reads the notes out to whichever agent takes the desk up. A note is text like the handoff's: a line that looks like a key is refused.

### Modes: how free a Codex worker is

Codex runs what it is asked in a sandbox of its own (bubblewrap and seccomp on Void), and asks you before each step out of it. At a desk that is many steps: the desk's `.git` is a file pointing into the repository's, which the sandbox keeps read-only, so every commit asks; so do a snapshot, the tests and the handoff, which write under `~/.local/state`. And the sandbox as your own `~/.codex/config.toml` may widen it can reach the project's own folder and every other desk. So Vikix starts Codex with a **mode**, `vikix agent --mode supervised|autonomous|unrestricted`, and `vikix agents worker`, `desk --task` and `resume` take the same word:

- **supervised**: Codex's sandbox is the desk alone (the folder and `/tmp`; your `writable_roots` are set aside for the session, so the project's own folder, `~/vikix` and the other desks are read-only to whatever it runs), the network off, and every step out of it asks you, unless Vikix's rules allow it (below).
- **autonomous**: the same sandbox, the network on (for `pip`, `cargo`, a fetch over HTTPS), and a reviewer of Codex's own (`--approve-for-me`) answering the steps out of it in your place. This is what a worker at a desk gets when nothing says otherwise: the house default is `mode=autonomous` in `~/.config/vikix/office`, which Vikix writes with its meaning the first time Codex starts, and you may change.
- **unrestricted**: no sandbox and no approvals (`--dangerously-bypass-approvals-and-sandbox`), for a VM or a container. It is never a default: typed each time, warned about in the terminal and in a notification, refused in a project's own folder, and written into the desk's record, so the handoff's protection lines say *no sandbox: unrestricted, by the user* under that agent.

**Vikix's rules for Codex**, `config/codex/vikix.rules`, linked as `~/.codex/rules/vikix.rules` by `vikix agents hooks codex --install` (Codex reads every `.rules` file there, so a file of your own beside it stands, and one in the way is left alone), let a desk's day run outside the sandbox without a prompt: `git` on the desk's branch (add, commit, status, diff, log, rebase, checkout, fetch, merge, stash, a plain `branch` or `tag`), `tests/run.sh`, `vikix` (snapshot, changes, agents, try, docs, what, why, rules, eval, project, records, doctor, theme) and `.claude/release`, which refuses the dangerous cases itself. `git push` and `vikix update` prompt (a worker started `--push` is meant to push), deleting a branch, a tag or a worktree prompts (closing a desk is `vikix agents close`), and `sudo`, `doas` and a force-push are forbidden outright. `codex execpolicy check --rules ~/.codex/rules/vikix.rules -- git commit -m x` shows what a command gets.

**The repository's instructions.** Codex reads `AGENTS.md` from the repository's root down to the folder it works in, never `CLAUDE.md`. Vikix gives it, for the session, `CLAUDE.md` as the file to fall back on where a folder has no `AGENTS.md`, with Codex's cap raised to hold Vikix's whole; a repository with an `AGENTS.md` is read as its author meant. So a Codex worker on Vikix reads the same instructions Claude Code does. The desktop's guide stays `~/.codex/AGENTS.md`, as before.

**The hook's trust.** Codex runs a hook of yours only once you trusted it in `/hooks`, by the file's hash, which every release that changes the file undoes. When `~/.codex/hooks.json` is Vikix's (the link `--install` makes, or a copy of the file) and the folder is one of your projects (`vikix project list`), `vikix agent` passes `--dangerously-bypass-hook-trust`: Vikix vets that file by making it. In a repository that is no project of yours Codex's own prompt stays, so a stranger's `.codex/hooks.json` never runs untrusted; `VIKIX_CODEX_HOOK_TRUST=ask` keeps the prompt everywhere. `vikix agents hooks codex` says which holds.

The modes are Codex's for now: `--mode` with another agent is refused with the words, and each other provider's mapping comes as it is tried (Claude Code's `--permission-mode`, OpenCode's `permission` block, Gemini CLI's `--approval-mode`). What the mode changes is who answers a step out of the sandbox; the house rules' hook runs before either sees it, and the sandbox under both. What it does not do: a command that writes through a program the hook doesn't know still passes the hook (the sandbox holds it to the desk), the reviewer in *autonomous* is a model's judgement and no rule, and Codex's hooks ([What holds the rules](#what-holds-the-rules-for-each-agent)) are from its documentation: none has fired on this machine yet, and they are marked unverified until one has.

### Pausing a worker, and taking turns

`vikix agents pause wifi-fix` holds the worker: the next thing it does, an edit, a command or a read, waits in the hook with its context whole, costing nothing, until `vikix agents go wifi-fix`. The pause takes hold at that next call, not this instant, so a long think or a read finishes first. After ten minutes the waiting call is refused with why, the turn ends cleanly, and the worker says it is paused; `go` and your next words to it start it again. `vikix agents go wifi-fix` says how long the desk was paused and who goes on; the held call then goes through with a word from the hook, so the worker, which saw nothing of the wait, knows it was paused, by whom and for how long, and carries on from where it was, with a note you left meanwhile (`tell`) after it. `vikix agents` and the Office show the desk as paused, by whom and since when. `--hard` freezes the agent's process this instant instead (SIGSTOP, found by its process descriptor, never by name) and `go` thaws it: for an agent with no hook, such as Aider, or an emergency, and said as such, since a request in flight may time out while frozen.

Two workers reaching for one file are stopped at your prompt, as the house rules say below. With `vikix agents turns wifi-fix on`, the worker at that desk waits instead: an edit of a file another agent has changed, uncommitted, waits for that agent's commit, up to ten minutes, and goes on with "your turn" when it comes, or asks you when it doesn't. A journal entry alone holds nobody: once the file is committed in the other's worktree, the turn is free. Two waiting for each other is seen, and the later one asks you at once. It is off by default, because silence is wrong for a session you are talking with; `turns off` puts the question back.

### The tester: a hand-in comes back checked

When a worker sets its status to *review*, its desk's tests run by themselves: `vikix agents test wifi-fix` is what runs, a script and never an agent. It runs the project's `tests/run.sh` in the desk's worktree, `--changed` from where the branch left the project's own, through the runner's queue like any other run (and after a release's tests, when one of the project is testing: the two at once failed for load alone), and writes the result into the record as a check signed *vikix*, the failing tests named and the first failure's line kept, and into the worker's inbox, so the worker reads it at its next tool call and fixes its own failures; `vikix agents test --log wifi-fix` shows the whole run. `vikix agents` and the Office say *testing* while it runs. A project with no `tests/run.sh` is said so, with no check. A desk made, or a worker started, with `--no-tests` (the Office's *No tests by themselves* box) runs nothing at the hand-in: the tests are yours to run, with `vikix agents test wifi-fix`, the Office's *Test* or the desk key `t`, and `vikix agents test --all` leaves such a desk out and says so. The setting is the desk's, kept in its record and shown by `vikix agents handoff` and in the Office (*tests off*); a worker started on a task without `--no-tests` has the tests again.

`vikix agents test --all` takes every desk in review. In the order they went to review, a desk joins a batch when it changed no file the batch has; the batch is merged onto the project's own branch in a throwaway worktree, gone afterwards, and tested once, each desk's check saying with which, since passing alone and failing together is what a batch is for. A desk that overlaps one in the batch runs alone, in its own worktree as it stands, told which it overlaps on what. Nothing touches a desk's branch: a merge that conflicts only sends that desk to run alone.

### A plan: tasks in order, run for you

Several tasks that belong together, some building on others, are a plan: a TOML file naming the project and its tasks, each one worker's job, and `vikix agents plan run plan.toml` runs it, making the desks and starting the workers through `vikix agents desk` and `vikix agents worker` as you would by hand.

```toml
project = "vikix"
at-once = 2            # workers running together, at most
gate = "me"            # a desk's release waits for your yes

[[task]]
name = "events"
desk = "office-events"
task = "An event log for the office: one line a hand-in, a check, a release."

[[task]]
name = "runner"
desk = "office-events"               # the same desk: the next worker in the chain
after = ["events"]
task = "The plan runner, waking on the event log."
release = "The office's event log and the plan runner"

[[task]]
name = "box"
after = ["runner"]                   # at another desk: waits for office-events to be released
task = "A Plans box in the Office, above the desks."
agent = "codex"                      # the worker's choices, as the New worker form has them
push = false
no-tests = false
```

Tasks at one desk are a chain, its workers in turn on one branch, in the file's order: the next starts once the last has handed in (status *review* or *finished*) and its tests pass, with the handoff the last one left to read, and the desk is released once, at the chain's end, with the project's `.claude/release`. Tasks at different desks run side by side, up to `at-once`. A task after a task at another desk waits for that desk to be released and starts at a fresh desk, made from main as it then is, which is why such a task must be the first at its desk. A task with `no-tests`, or a project with no `tests/run.sh`, goes on the hand-in alone. `desk` left out is the task's name.

The runner is a script, never an agent: it edits no file, answers no prompt, never puts two workers at one desk, and never merges or pushes (the release script merges, `gup` stays yours). A worker that handed in is dismissed once its tests are in, since a worker at its prompt never reads a note. A round is one worker on a task; one whose tests failed, or that left without handing in, failed, and the next round's worker is told why in the desk's inbox; the third failure stops that desk under **Needs you**, with the desk's status set *waiting* by vikix, as a release that failed does, and a hand-in left with files uncommitted when its worker is gone. You go on from there by hand: hand the task in yourself, or fix and run the release again with `vikix agents plan release DESK`, which is also your yes when the gate is *me*.

Its state is worked out each time from the plan file and the desk records (which task is the record's, what came before in its history, the checks and their freshness, who is at the desk), so a reboot loses nothing and `plan run` again carries on; only its switches are its own, in `~/.local/state/vikix/office/plans/`. It wakes on the office's event log, `~/.local/state/vikix/office/events-YYYY-MM.jsonl`, one line a hand-in, a check, a worker started, a desk closed or an agent that left, written by every record write, and looks round by itself once a minute besides. `vikix agents plan status` says where each plan stands, a line a desk and a line a task; `plan pause` starts nothing new, `plan stop` ends the runner (the workers at work carry on), `plan log` is what it did. What it can't know: which files two desks will touch; turns and the clash rules handle that.

### Dismissing a worker, and how it left

`vikix agents dismiss wifi-fix` asks the desk's agent to exit and keeps the desk, its branch and its files, so `vikix agents resume` takes it up later; it is the Office's *Close agent* from the terminal. A note goes to the worker first, "dismissed: write your handoff if you can, then stop", which one mid-turn reads at its next tool call, and the record notes the dismissal and how many files were left uncommitted. An agent never dismisses itself. Whichever way an agent leaves a desk, dismissed, exited or logged out, Claude Code's SessionEnd hook (`vikix agents left`) notes it in the record, so the next one at the desk, and the Office, see *Left: dismissed, 3 uncommitted then*.

Each of the worker's commands has a form for the desktop: in the desk keys (`Super+Alt+d`) `w` starts a worker at a desk (the desk picked in a menu, the task typed, nothing for a session, then which agent and whether it may push, as a new desk asks; a desk with an agent at it is refused in a notification), `t` tests a desk's work, `p` pauses its agent or lets it go, `i` leaves it a note, `x` dismisses it, each asking which desk in a menu, and `Super+m` → *AI* has the same (*Agents: a worker at a desk*); the Office has them as buttons.

### When a desk doesn't appear

`vikix agents` shows no new line and the workspace is empty: the desk wasn't made. From a terminal the reason is printed (*no project called ...*: `vikix project list` names them, and any part of a name does); from `Super+m` it comes as a notification. The usual cause is a name that isn't the project's (`novel-second-edition` when the project is `novel`).

## The house rules

Desks keep agents apart. The rules say what happens when they meet all the same, and they are held by Claude Code itself: an agent Vikix started runs `vikix agents touch` before every edit (a hook, given to Claude Code for that session with `--settings`; nothing is written to your own Claude settings). The hook takes a fifth of a second, asks nothing of the desktop, and notes the file in the office's journal, `~/.local/state/vikix/office/journal.jsonl`, which keeps only the agents still running.

### Two agents on one file

The agent on workspace 5 is about to edit `bin/vikix-wifi`, which the agent on workspace 4 has changed in its worktree and not yet committed. Claude Code stops and asks you, in its own permission prompt:

> Vikix office: another agent is on this file. claude 48213 (~/src/vikix-wifi-fix) has changed it in ~/src/vikix-wifi-fix, uncommitted. `vikix agents clash ~/src/vikix-docs-pass/bin/vikix-wifi` shows both changes. Let this one edit it too?

You have three answers. *Yes*: both changes go in, and whoever merges second settles the overlap. *No*: this agent is told the edit was refused, and you tell it why (*leave bin/vikix-wifi to the other agent*). Or look first:

```
$ vikix agents clash ~/src/vikix-docs-pass/bin/vikix-wifi
~/src/vikix-docs-pass/bin/vikix-wifi: 2 agents on it. Each one's change, uncommitted:

== claude 48213, changed in ~/src/vikix-wifi-fix ==
diff --git a/bin/vikix-wifi b/bin/vikix-wifi
...
== claude 51002, edited it ==
(no change in the worktree: the edit is still to come)

Which stays is yours to say: tell the other agent to drop its change, or let both go in and settle the merge.
```

The same holds inside one working copy: when two agents share a desk and the second edits a file the first has edited, the journal knows, and Claude Code asks the same way (*claude 48213 edited it too, 4 min ago*).

`vikix agents clash` alone lists every file two agents are on, and `vikix agents` marks such a file under each agent:

```
  claude   ~/src/vikix-docs-pass (docs-pass, 1 uncommitted)   workspace 5   1 h    working
           on bin/vikix-wifi with claude 48213 too (vikix agents clash bin/vikix-wifi)
```

### A crossing

An agent may edit a file in another agent's desk, and may go to another agent's window (the MCP tool `focus_window`), but never quietly. The edit goes through, and the agent is told, in words it reads before it acts: *this file is in ~/src/vikix-wifi-fix, the folder claude 48213 works in, not yours; the crossing is recorded; edit it only if the user asked for that, else leave it to that agent and tell the user.* The crossing is kept in the record store, and `vikix agents crossings` lists the last ones:

```
$ vikix agents crossings
1  2026-10-06 11:42  office/crossing  claude 51002 edited ~/src/vikix-wifi-fix/bin/vikix-wifi, in claude 48213's folder
```

An agent in your home folder owns no folder, so nothing is a crossing into it: everything under home would be.

### Shells left sleeping in a loop

A command an agent typed may loop waiting for a line that never comes (`until grep -q exit log; do sleep 20; done`, with the log named wrong): the agent goes on to its prompt and the loop stays, a shell with nothing but `sleep` under it, for hours. The Office sees the agent at its prompt and says the terminal can be closed; `vikix agents` and the Office's worker row say how many such shells it has, and `vikix agents tidy` lists them by agent and ends them on yes (`--yes` from a script). A shell counts after ten minutes of only sleeping, and only one given its command on the line (`bash -c`): a script that sleeps between its steps, `tests/run.sh` waiting for a slot, is doing something. A loop the agent means to keep, a watch, looks the same, so nothing is ended unasked; `vikix memory left` lists them among the maybes too.

### What holds the rules, for each agent

`vikix agents hooks` says it plainly, and the handoff's last lines say it for the agents at a desk:

```
$ vikix agents hooks
claude    given to Claude Code by vikix agent at every start (--settings): pre-edit and pre-shell hooks
codex     hooks in ~/.codex/hooks.json: PreToolUse (apply_patch read for its files, Bash; a clash refused once, since it can't ask), PermissionRequest (...), UserPromptSubmit, Stop and SessionEnd (...); and Vikix's rules in ~/.codex/rules/vikix.rules (...) ... unverified on this machine until one has fired
          not installed (vikix agents hooks codex --install links ~/.codex/hooks.json)
          not installed (vikix agents hooks codex --install links ~/.codex/rules/vikix.rules)
          trust: vikix agent passes --dangerously-bypass-hook-trust in your projects when the hook file is Vikix's ...
opencode  a plugin on tool.execute.before (edit, write, bash): a refused edit throws, with the reason ...
          not installed (vikix agents hooks opencode --install links ~/.config/opencode/plugins/vikix-office.js)
gemini    a BeforeTool hook to merge into ~/.gemini/settings.json by hand ... unverified here
antigravity a plugin of Vikix's that vikix agent installs with agy plugin install ...: pre-edit and pre-shell hooks
aider     no hooks: instructions only (the guide it reads), and git
```

Three levels, and the listing never claims more than there is. *Instructions only*: the agent has read the rules in its guide, and git shows afterwards what it did. *Pre-edit hooks*: the house rules run before each edit and shell command and can refuse it; Claude Code and Antigravity CLI have them from `vikix agent`, Codex and OpenCode get them from an adapter you install once (`--install` links a file of Vikix's into their folders and leaves a file of your own alone; Codex's hook shapes and Gemini's are taken from their documentation and marked unverified until one has fired here). *Filesystem enforcement*: none from Vikix. A worktree keeps copies apart, and the hook reads a shell command's words; neither is a sandbox, and the page doesn't call them one. Codex brings a sandbox of its own, and in the *supervised* and *autonomous* modes ([Modes](#modes-how-free-a-codex-worker-is)) Vikix narrows it to the desk; the handoff says so under a Codex at the desk (*sandboxed to its desk*), and *no sandbox: unrestricted, by the user* when you asked for that. A hook that a provider lacks keeps nothing else from working: the handoff and the resume are the same for every agent.

**Codex's hooks**, `config/codex/hooks.json` linked as `~/.codex/hooks.json`, are the same rules at Codex's tools, since its hooks differ from Claude Code's in three ways. Its edit tool is `apply_patch`, whose input is the patch text, so the hook reads every file the patch names (its Update File, Add File, Delete File and Move to lines; a patch applied through a Bash heredoc the same) and judges each as an edit: off a desk or in the project's own folder denied, a crossing told, a note from `vikix agents tell` delivered. Its hook can't ask, so a clash (another agent on the file) is refused once, with the reason and `vikix agents clash FILE`, and the same edit within ten minutes goes through, Codex having told you, as OpenCode's does. And it has a hook on each step out of its sandbox (`PermissionRequest`, `vikix agents touch --for codex --escalation`): one that would write into the project's own folder, `~/vikix`, another desk or `~/.config/vikix/secrets/` is denied with the reason, whatever the mode, so in *autonomous* the reviewer never sees those; any other step is left to you or the reviewer, and when it is yours the agent-waiting note says Codex *waits for your yes*. Three more hooks give the states: a turn begun (`UserPromptSubmit`) is noted in the journal, so a Codex thinking before its first tool call is *working*; its Stop hook asks a worker for its handoff as Claude Code's does and writes the plugin's *finished its turn* note with Codex's last words, and a stop let through is *at its prompt* until the next turn; its SessionEnd notes how it left (Codex gives no reason, so the record says *left*). The handoff's page says which of these a Codex at the desk has: its edits seen through the hook, or the hook file installed and none seen yet, or instructions only. Codex's session id reaches the record through the same hooks, so `vikix agents resume` finds its conversation without you typing it, in its rollout files or, from Codex 0.160, its thread store (`session_index.jsonl`, `thread_history_1.sqlite`, read only).

The hook notes an edit before it happens, so a note in the journal is a proposal; what actually changed is git's to say (`vikix agents` counts the uncommitted files, `vikix agents clash FILE` shows the diff). Nothing here resolves another agent's changes, answers its prompts, stops it or closes its desk: those are yours.

### What the rules don't do

A clash and a crossing stop nothing on their own: the one that decides is you, at Claude Code's prompt (OpenCode's plugin can only refuse or let through, so it refuses a clash once and lets the same edit through when tried again within ten minutes, the agent having told you). Only the desk rule refuses outright, and it names the way out. The rules hold for Claude Code, Antigravity CLI and Codex, and OpenCode's plugin holds the edit hook; Gemini CLI and Aider have no such hook, so a clash with one of them is seen afterwards, in `vikix agents` and `vikix agents clash`, not before the edit, and nothing keeps them off a project's own folder. Antigravity's hooks can't tell the agent something without deciding, so there a crossing asks you, with the reason, where Claude Code is told and goes on; its hook is a plugin of Vikix's that `vikix agent` puts in place (`agy plugin list` shows `vikix`), so it stays between sessions, and `agy plugin disable vikix` switches it off. A Claude Code session started before the update, or with `VIKIX_OFFICE=0 vikix agent`, has no hook either; one started before the desk rule has the edit hook but not the one on shell commands, since Claude Code reads its hooks at the start. A shell command that writes through a program the hook doesn't know (a Python script of the agent's own) passes. And they know files, not meaning: two agents editing different files of one feature are not a clash to them.

## From the agent's side

The Vikix skill tells every agent the same rules, so you can hold it to them: look at `vikix agents` before changing files in a folder another agent is in; take a desk before touching a repository (`vikix agents sit`), commit there on that branch and leave the project's own folder alone; read the handoff when joining a desk, and write it when handing work back, when blocked, and when done; when the work is merged, say so and let you close the desk, and once the desk is closed (by a release or by you) tell you so in its last message, with what remains for you to do; never stop, signal or type into another agent's window, and never answer a question another agent asked you. An agent with the MCP tools has `agents` to see the others, `handoff` and `handoff_update` for the desk's record, and `focus_window` to go to one, and the last is recorded as a crossing.

## Not there yet

A workspace and a bar colour each; handing a window from one agent to another; a permission list per agent. A foreman agent that writes plans for you to approve (never one that runs them). Gemini CLI's and Codex's hook shapes, and Gemini's resume, tried on a machine that has them; the hand-in's fields, a review by another agent, handing a desk over, and the mode for the other providers (the rest of `plans/DESIGN-codex-integration.md`). Each will come as it is needed; the pieces that are here are the ones the first weeks with several agents asked for.

## The Office

`Super+m` → **AI** → **Office: tasks, desks and agents**, the palette's
**office**, or `vikix agents office` opens a dedicated Emacs frame. It
inherits Emacs's Vikix theme. The existing agent menu and terminal commands
remain available; without Emacs, the command opens the existing agent menu.
Conversations stay in each agent's terminal. Opened while it is open
already, the Office comes to the front instead: the desktop goes to its
window's workspace, or brings it here from a hidden one.

The Office connects to your existing Emacs server and explicitly opens an X11
window on the launching desktop, including when Emacs runs as a daemon with
only terminal frames. If it is unavailable,
busy, or reports an error, the launcher says why; it never starts another
Emacs or restores a second copy of your saved session. In your existing
Emacs, use `M-x server-start` if its server is not running, then try again.
An inherited `ALTERNATE_EDITOR` setting cannot start a second instance here.

**In a terminal.** With no display, on a headless server or over SSH, or
with `vikix agents office --tty` anywhere, the Office opens in the terminal
you typed in instead: `emacsclient -nw` makes a text frame of your running
Emacs there, with the same two panes (the desk below the list when the
terminal is narrower than a hundred columns), and `q` closes that frame, so
the shell comes back. It is the same Emacs and the same server: with none
running, the same message as on the desktop, and still never a second
Emacs. Inside Emacs, `M-x vikix-office-open-here` opens it in the frame you
are in, and `q` then puts that frame's windows back as they were.

Above the desks, a **Plans** box when a plan has run (`vikix agents plan`): a plan a group, its name, project and whether its runner runs, a line a desk saying where that desk's chain stands, and what needs you; a desk of a plan says which in its **Plan** line.

The left side groups desks into **Needs you**, **Working**, **Parked**,
**Finished** and **Closed**, each group drawn in a box of its own, a rule between its
desks, and a desk's lines as labelled rows (Task, Live, Handoff, Next, Before); the desk
pane draws each of its sections (the task, the agent's claims, the Git
state, the checks, the agents, the saved conversations) in a box the same
way, so neither pane reads as a wall of text. The boxes are as wide as
their window and are drawn again when it is resized; a terminal that
can't show the box characters gets ASCII ones. A row is a desk: its title
is the place, project / branch (the folder, for an agent in a plain
folder), and under it its **Task** now, the user's words (a desk with none
says so: it stands for a worker later), its workers **Before** this task,
newest first, as the record's history keeps them (how each ended, which
agent, its task; three in the row, all of them in the desk pane under
*Workers before this one*, each with who gave the task, when it ended and
the agent's last word on it), and a **New worker…** button when the desk
stands with nobody at it, which opens the worker's form for that desk.
Each row distinguishes **Live** activity from the recorded **Handoff**,
counts down the agent's estimate while one stands, and shows the next
action. A desk whose terminal needs you is drawn in the colour the desktop
gives that terminal (its title and Live row, and the agent's line in the
details): one colour while the agent waits for you, another once its desk
is released and waits for `gup`, a third once that is pushed and the
terminal can be closed; the theme's `agent_asks`, `agent_released` and
`agent_pushed`, or Emacs's own warning, success and constant faces without
a palette. A waiting agent or a waiting/review handoff needs you, as does a
terminal waiting for `gup` or to be closed;
a live agent otherwise counts as working; a finished record whose desk
still stands counts as finished (it is yours to release or close); the
remaining desks are parked. A desk closed in the last day (`vikix agents
close`, or the release that removed it) is **Closed**: newest first, its
row saying who closed it and when, nothing to do at it, and *Forget this
record…* in its details; after a day its record is in the Archive. Unavailable
live discovery is **unknown**, never proof that an agent stopped. Desks
without handoffs still appear. A folder an agent merely runs in (one
started in `~`, or in a project's own folder) gets a row too, marked
**Not a desk**: its title is the folder, its details name the agents
running there, and Go to agent and Close agent work as on a desk. It has
no Git state, no handoff and no Continue, since there is no desk to
continue; `vikix agents sit PROJECT TOPIC` from the agent's own shell
seats it at one. Removed worktrees with no live agent go into
**Archive**, separate from current desks, once their day in Closed is
over (at once, when the worktree went without the desk being closed). A
handoff saying "finished" alone does not archive an existing desk or
remove any files.

**Releases.** Above the groups, a **Releases** box lists the releases under
way in your projects, as `.claude/release --queue` does: each one's topic,
what it is doing (checking, testing, waiting for its turn) and since when,
with the project and the line it brings; the one whose turn it is comes
first, the ones waiting for the lock after it. A desk whose branch is being
released says so too, a **Release** row under its Handoff, and in its Git
state. The box is read from the notes each release keeps of itself
(`.git/vikix-release-queue/`, one file a running release); a note of a
release that ended is skipped, never removed. When none is under way, a
repository that has released before gets the line *No release under way*,
and a machine that never released shows nothing.

Click **Archive** (or press `A`) to see historical tasks, handoffs and checks.
Archived entries say no action is needed; Go to agent, Continue and Close
agent are absent. Their old next actions are historical, not new instructions.
**Forget this record…** removes that one record after confirmation (as
`vikix agents handoff forget` does); its files, branch and saved
conversations stay. **Back to desks** (`A` again) returns to current work.

**Purge archive** permanently deletes the archived desk records after
confirmation. It rechecks the exact records, worktree paths and live agents;
changed records, reopened desks or unavailable discovery require a refresh
and a new confirmation. Project files, branches and the providers' saved
conversations are untouched. There is no automatic age or size cutoff.

Click a desk, or use `n`/`p` to select it. `RET` enters its details; `C-x o`
moves between panes. Only available action buttons are shown. `Tab` visits buttons, `N` makes a new desk, `w` starts a worker at the selected one, `a` goes to an agent, `c` continues
a desk, `P` pauses its agent or lets it go, `t` runs its tests, `i` leaves its agent a note, `C` closes a desk, `g` refreshes and `q` closes the Office. A button's answer (*let go, paused 3 min; claude 48213 goes on at its next call*) stays in the header line over the refreshes that follow, until `g` or the next button, and the row is drawn again at once, so a desk let go loses its *paused by* and its Go button says Pause again. A row says when its desk is paused and by whom, when its tests run, and how many notes wait for its agent; the details say how the last agent left. Details keep the user's task,
signed agent account, observed Git state, reported checks and saved
conversation availability separate. **Review does not mean merged.** A
fresh check means its recorded code matches the current observation; it does
not independently verify the agent's report.

**Go to agent** lets you choose when several agents share a desk. It resolves
the chosen process again through the desktop before focusing it. An agent
without a desktop window is identified and cannot be focused here.

**Close agent** (`x`) asks which agent when a desk has several, then asks
for confirmation before requesting its exit. Running work stops; the desk,
branch and files stay for later. The process identity is checked again so a
stale view cannot close a replacement process. If it is still exiting after
three seconds, the Office says so; it does not force-kill it. `q` closes only
the Office window.

**New desk…** (`N`, above the groups) and **New worker…** (`w`, in a desk's
row and in the details of a desk that stands with nobody at it) are forms,
drawn in the desk pane and in the terminal alike. New desk asks for the project (a menu of `vikix
project list`'s, a click or `RET` on the `[choice]` opens it; it is always
picked, never guessed from the desk selected), the topic (a word or two; a
repository needs one, a project that is no repository works in its own
folder), and the task; nothing typed for the task is the desk alone, for a
worker later. New worker asks for the task alone; nothing typed is a session, an
agent to talk with, the record left as it is; a desk with an agent at it
takes no second, and says so. Both have the worker's choices
as boxes to tick: the agent (yours, or any `vikix agent --list` has, one not
installed yet offered its installer in the terminal), *on a model on this
laptop* (the ones that can are named), *may push as you* (your SSH agent
goes with it, as `--push` does) and *no tests by themselves when it hands
in* (`--no-tests`: the Test button still runs them). `TAB` moves between
the fields, `C-c C-c` is the button, `C-c C-k` cancels. The form hands its
words to `vikix agents desk` or `vikix agents worker` as they are, which
answer in the Office's header line; a refusal (a project not picked, a topic
that gives no branch name, an agent at the desk already) is said in the
form's own header line and leaves the form open to fix. A worker's
terminal opens on the desktop, so from a terminal Office with no display
only the desk alone can be made.

**Close desk…** (`C`, in the details of a desk with nobody at it) is
`vikix agents close` from the Office: after a yes, the worktree is removed
and the branch deleted when its work is in, kept and said otherwise, and
the record is kept as closed. A desk with files uncommitted asks a yes of
its own first, to throw them away (`--force`, which takes an unmerged
branch with them); no to that closes nothing. A desk with an agent at it
is not offered: Close agent first, or let it finish.

**Continue** offers a named provider and either its recorded saved
conversation or an explicit **Start fresh** choice. It uses `vikix agents
resume`, including its duplicate-session checks. A saved conversation that
disappears after the choice fails instead of silently starting fresh. The
Office does not offer a second agent at an occupied desk or recreate a
removed worktree; the existing CLI remains available for those operations.

Refresh runs in the background every ten seconds, with one refresh at a
time and a timeout. It preserves selection and pane position, never focuses
a window, and stops when the view closes. On failure the header says why,
previous information stays visible and live activity becomes unknown;
actions wait for a successful refresh. `vikix agents office --json` exposes
the same snapshot to scripts, including discovery errors and the release
queue; the read-only MCP tool `office` returns it too. It is a view of
existing desks and handoffs, not another task store.
