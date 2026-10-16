# Agents at work

One agent is a terminal you talk to. Three or four at once are a small office: each needs a place to work, you need to see who is doing what, and when two reach for the same thing somebody has to say so. This page is how that office runs on Vikix: starting an agent, seeing them all, giving each a desk, and the house rules that hold when they meet. [Working with AI](ai.md) has the rest: which agents there are, keys and models, the desktop as tools.

For Grok Bot research and cloud work, use [Grok Bot handoffs](ai.md#grok-bot-handoffs): a separate local queue of briefs and answers to review. A Grok handoff does not start an Office worker; you can pass its reviewed findings to a worker here.

Three habits carry the whole page:

1. **Start agents with Vikix**, `Super+a` or `vikix agent`, never plain `claude`: that is how they get a snapshot of your files, the Vikix skill, no API keys, and the house rules.
2. **One desk per piece of work**: `vikix agents desk PROJECT TOPIC` makes the place, `vikix agents worker TOPIC "the task"` puts an agent to work there. No desk, no work: an agent off a desk is refused when it reaches for a project's files, and told how to sit down.
3. **`vikix agents` when you lose track.**

## One agent

`Super+a` asks *Agent here* or *Agent at a new desk*, then which agent; the first, with yours (Claude Code, unless you chose another: `vikix agent --default codex`), opens a terminal with it in your home folder (`vikix agents here`; a Codex there gets the house mode, as at a desk: [Modes](#modes-how-free-a-codex-worker-is)). Before the agent starts, Vikix takes a snapshot of your files, so afterwards:

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

A desk is the place: the worktree, its branch, its record. A worker is one agent on one task there, and a desk takes its workers one after another, on the same branch: when the first has finished (or you dismissed it), `vikix agents worker wifi-fix "now the password dialog"` starts the next, and the record moves the task before, with how it ended and the agent's handoff whole (its status, account, next step and estimate), into the desk's history, which `vikix agents handoff wifi-fix` shows under *Workers before this one*; what is the desk's stays in the live record for the next worker, whose first prompt carries it: the acceptance criteria with their ticks, the decisions, the defects and the review findings (the first day with two providers lost four findings and three defects at a new worker, 2026-10-11). Two at once are refused: in one worktree git can't say whose files are whose, so the house rules couldn't either; `vikix agents tell` speaks to the one there, `dismiss` ends it. `vikix agents worker wifi-fix` with no task is a session at the desk, an agent to talk with, the record left as it is.

The agent's terminal is named for its desk on the desktop: `wifi-fix · Claude`, the topic and the provider, in the title bar, the window list (`Super+g`), the overview and the palette, from the moment the agent is at the desk (started there, seated with `vikix agents sit`, or taken up again with `resume`) until it leaves. Two of one provider at a desk are `wifi-fix · Claude 1` and `wifi-fix · Claude 2`, each keeping its number while it runs; another provider at the same desk is `wifi-fix · Codex`. The title the agent itself writes (Claude Code's turning mark, which is how *working* and *at its prompt* are read) is kept apart, so nothing it does to its title changes the name, and nothing is lost: `vikix agents` shows both. A terminal whose agent has gone is plain again, or named for the next agent run in it, within half a minute; a terminal with no agent at a desk, and a name you gave a window yourself with StumpWM's `title` command, are left alone.

**Three colours say what a terminal needs of you.** In the bar's window list and in the window's title bar, an agent's terminal takes a colour while something is yours to do with it, and is plain the rest of the time. While the agent *waits for you* (a permission, a question, its last words asking something: what the agent-waiting plugin notes) it has the first colour. Once its desk is gone while the agent still sits in the terminal (a release removed the worktree, or you closed the desk) and the project's own branch has commits its origin hasn't, it has the second: the release waits for `gup`. Once that is pushed too, the third: nothing is left but to close the terminal. The name stays on such a terminal (`wifi-fix · Claude`) so you know which it was. The colours are the theme's, so a light theme and a dark one each have their own: `agent_asks`, `agent_released` and `agent_pushed` in the theme file, or the terminal's yellow, green and cyan where a theme names none (see [Making it yours](customize.md#the-look)). `vikix agents` says the same in words (*its desk is gone; main has commits to push: gup*; *its desk is gone and main is pushed: close the terminal*), and the Office draws the desk in the same colour. Whether the branch is pushed is read from the repository's own ref files, so a push from anywhere (your `gup`, `git push` in a shell) is seen within seconds; nothing here pushes or closes anything.

The project is any of `vikix project list`'s, by any part of its name (`vikix`, `novel`, `nov`). The topic is a word or two for the work: it becomes the folder's ending and the branch's name, so choose one that says what the agent is doing (`wifi-fix`, `chapter-3`, `typos`), not who (`agent-2`). A topic that gives no name for a branch is refused.

`Super+a`, *Agent at a new desk*, or `Super+Alt+d` then `n` (the desk keys: `Super+Alt+d` opens a small card of them, `n` a new desk, `w` a worker at one, `r` take one up again, `c` close one, `h` its handoff, `o` the Office, `t` test a desk's work, `p` pause its agent or let it go, `i` a note for it, `x` dismiss it, `b` a terminal in the default box), or `Super+m` → *AI* → *Agents: a new desk, with a worker when you give it a task*, asks for the project in a menu, then for the topic, then for the task. Enter with nothing is the desk alone. A task typed goes on to the worker's questions: which agent, yours first, the others as `vikix agent --list` has them (one not installed yet is offered its installer in the terminal), and the ones that can run on a model on this laptop; then whether the agent may push as you. No is the usual: the agent commits, you push. Yes sends your SSH agent with it (`vikix agent` keeps it back otherwise: after your first push of the day it holds your unlocked key), so `git push` works at that desk. The Office has the same as a form, **New desk…**, with the worker's choices as boxes to tick (see [The Office](#the-office)). Other forms:

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

Three kinds of line, kept apart and each signed. The **task** is yours, in your words: `vikix agents worker wifi-fix "..."` sets it as the worker starts and gives it to the agent as its first prompt (the task of the worker before goes into the desk's history, with how it ended), so the desk starts working at once (Claude Code, Codex, OpenCode, Gemini CLI and Antigravity CLI take one; Aider doesn't, and is told to read the record); or `vikix agents handoff --task "..."` sets it later; each task has a record of its own as well, with an id and a launch number (*The work: tasks and their history*, below). The **handoff** is the agent's: a status (working, waiting, review, finished, or parked: kept aside, to be started later), an estimate, what it changed and decided, what is left and the very next action. The **estimate** is how long the work will take from the moment it is written, assuming no major issue turns up (`--estimate "40 min, if the picker needs no new test"`: a duration first, in minutes, hours or days, and what it assumes after a comma); an agent started with a task is asked for one as soon as it knows the shape of the work. The record and `vikix agents` count it down (*28 min left of 40 min*, *10 min over its 40 min*), and once the status is finished they say how it went (*finished in 45 min against 40 min, 5 min over*). The clock is the wall's, so time spent waiting for you counts, as it would for a person; an estimate written again starts it afresh. What **Vikix read itself** is the rest: the commit and the uncommitted files at each write, and for a check the commit it ran on and whether the tree was dirty then. A check is marked *stale* the moment the code differs from what it ran on, by another commit or other uncommitted changes, so an old green never passes for a new one. The sessions are the providers' conversation ids and nothing more: no transcript is copied, and a line that looks like a key or a token is refused outright.

The agent writes with the same command, or with the MCP tools `handoff` and `handoff_update`, whichever agent it is:

```sh
vikix agents handoff --status working --estimate "40 min, if the picker needs no new test"
vikix agents handoff --status review --summary "..." --next "..."
vikix agents handoff check "tests/run.sh wifi" --ok
vikix agents handoff session codex 01a111e5-…      # a conversation that can be resumed here
echo '{"status":"waiting","next":"needs the laptop"}' | vikix agents handoff --from -
vikix agents park wifi-fix --next "once the new laptop is here"   # kept aside: Parked in the Office, not Needs you
```

`vikix agents park [DESK]` is the status *parked* by its own name, yours or the agent's: the desk is kept aside, to be started later, and the Office lists it under **Parked** however its agent left it (a question it asked with a *waiting* status would otherwise keep it under *Needs you*); `--next "..."` replaces the next step with what to do when it is started again. Nothing is stopped by it: an agent still at the desk goes on, and the desk counts as working until it is gone (`vikix agents pause` holds one). A worker started there, or any status written, takes it up again.

Given any of those settings, `handoff` writes instead of showing (`vikix agents handoff set` says the same, a word longer); from outside the desk, name it first, as for `close`: `vikix agents handoff wifi-fix --task "..."`.

**The hand-in** (from 0.72.34) is the rest of the record, the fields a worker fills as it goes so that whoever takes the desk next, you, a reviewer or another provider, starts from facts rather than from a conversation. Each line is signed as the others are, each list keeps fifty, a line is cut at a thousand characters, and a line that looks like a key is refused.

```
Acceptance (user, 2 h ago): 2 of 3 done
  [x] the picker scans before it lists  (claude 48213, 30 min ago)
  [x] the old order stays under --no-scan  (claude 48213, 25 min ago)
  [ ] a test covers the scan
Decided (1):
  the scan runs in the bar's thread, never in StumpWM's  (claude 48213, 1 h ago)
Defects: 1 open
  open      a card that takes longer than two seconds to scan shows an empty list first  (claude 48213, 20 min ago)
Review: 0 open, 1 addressed
  addressed bin/vikix-wifi:88 the timeout is read twice  (codex 51002, 15 min ago; addressed by claude 48213)
Changed (vikix, 20 min ago): 2 files against 3a9f1c0
  +41 -6  bin/vikix-wifi
  +12 -0  tests/wifi.sh (uncommitted)
Commits (vikix, 20 min ago): 1 past 3a9f1c0
  7c1e0f2  wifi: scan before the list
```

The **acceptance** criteria are yours, given with the task, a line each: `vikix agents worker wifi-fix "..." --acceptance "the picker scans before it lists" --acceptance "..."` (`desk --task` takes them the same way, a plan file as `acceptance = ["...", "..."]`, and `vikix agents handoff --acceptance "..."` later, which replaces the list whole). The worker ticks one with `vikix agents handoff --done 2`, and the record, the listing and the Office say *2 of 3*. **Decisions** (`--decided "..."`) are the choices made, so the next worker doesn't reopen them; **defects** (`--defect "..."`, closed with `--defect-done N`) are what the worker knows is wrong or missing; **review** findings (`--review "bin/vikix-wifi:88 the timeout is read twice"`, which keeps the place apart; `--review-done N` marks one addressed) are a reviewer's, or yours. What **changed** and the **commits** are never typed: Vikix reads them from git at every write of the handoff and at the tester's run, against the base, the commit where the desk's branch left the project's own, with the uncommitted files marked and a new untracked one said to be new. The MCP tool `handoff_update` takes the same fields by their names (`acceptance` as a list, `done`, `defect`, `defect_done`, `review`, `review_done`, `decided`), `--from` takes them as JSON, and the Office's desk page shows them all under *What the agent says* and *Observed Git state*.

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

A worker is what `vikix agents worker wifi-fix "the Wi-Fi picker should scan first"` starts (or `vikix agents desk vikix wifi-fix --task "..."`, the desk and the worker together). The agent is started on the task, its first prompt, with where the desk's record is, so it opens on what the desk is for rather than at an empty prompt. The worker reports by construction. When its status comes to *review*, *waiting* or *finished*, a notification on the desktop says so, with its next step (never for a status that stayed, or for your own change). And a worker that ends a turn having changed files without writing its handoff is asked once, by Claude Code's Stop hook (`vikix agents stopping`, set by `vikix agent` with the house rules; Codex's hooks file has the same), to write it before it stops; the stop after that is let go, so nothing goes round. A desk with no task, a session you are simply talking with, is asked the same way until its record has a status, and then left alone: one line, so the Office never shows the desk with *no handoff*. And a desk the release closes with no status gets *finished* and the release's line, since the work is on main whatever the agent left unsaid.

**The task has a record of its own** (from 2026-10-14; `lib/tasks.py`, the first phase of `plans/DESIGN-office-tasks.md`), apart from the desk it is done at and the agent doing it: `~/.local/state/vikix/office/tasks/ID.json`, made by every way work starts (`worker`, `desk --task`, `sit --task`, `handoff --task`, the Office's forms, a plan), with an id for life (`t-20261014-7f3a9c`), who made it (*yours*; an agent's own, for one that sat down with `--task`; *by plan NAME* for the plan runner's; *unknown* for one from before), its priority (normal, until the queue comes), when it was created, launched and done, the handoff as the agent left it, and each launch with its number: `office/sequence` gives one to every worker the office starts, so the order they were started in is kept and two Claude workers are told apart (`#104 claude`). The desk's record points at its task by id, and the task keeps its history when the desk's workers change: a second worker on another task leaves the one before *blocked on worker* at the desk's back, a session or a `resume` is a launch of the same task with the next number, and a resume with another provider is noted as a handoff between them. **Two states, kept apart.** The worker's state is what was observed, each time, with where it was read and how sure (*idle, reliable: the title's mark*; *exited, inferred: the process gone*). The task's state is recorded, and moves only by a named step: *ready* when made, *running* at a launch, *needs decision* when the agent's handoff says waiting, *needs review* when it says review, *ready for release* when it says finished (the agent's work is done; yours is not), *blocked* on its worker when the worker's process ends (every worker's terminal runs its agent under an exit line, `vikix agents exited`, so the code reaches the record whatever the provider, hooks or none; the SessionEnd hook says the same), on the tests when they fail with nobody at the desk, or *parked*; *completed* by the release (`.claude/release`, with the version), by the desk closed with its branch in, or *cancelled* by the desk closed with `--force`. A worker's exit never completes or cancels anything. `vikix agents tasks` lists them, the open ones in launch order, the unnumbered after, then the day's done ones (`--all`: every one; `--json` the records); `vikix agents task ID` is one task's page with its history, `vikix agents events [TASK | DESK | --all] [--since 2h]` the office's event log itself (one line an act, a file a month, never rewritten: the same log the plan runner wakes on, grown), and the MCP tool `tasks` gives agents the same. The desks from before are adopted once by an update (`vikix agents tasks adopt`): a record for each desk's task and for each worker in its history, with what the desk's record knew, the rest *unknown* (the launch order, for one) and never invented.

**What done means**, the one table every worker is given at the end of its first prompt, a step a row, whichever provider it is (`DONE` in `lib/handoff.py`; the skill's `projects.md` has it as *A worker's day*):

| Step       | What |
|------------|------|
| Understand | the task and its acceptance criteria; read the handoff and the project's instructions. |
| Estimate   | once you know the shape of the work, say how long it will take, assuming no major issue turns up: `vikix agents handoff --status working --estimate "40 min"`, or the MCP tool `handoff_update`. |
| Look       | at the files the task touches before changing them. |
| Change     | at your desk, on its branch. |
| Test       | the tests the change reaches, through the project's runner (`tests/run.sh --changed`); fix what fails, run them again. |
| Guides     | update the ones the change makes wrong, in the same commit. |
| Commit     | only the files you changed, by name. |
| Hand-in    | status, what changed and why, what is decided, what is left, the tests run, the defects you know of. |
| Hand back  | through the office (`vikix agents handoff --status review`); don't merge, release or push unless the task or the house says so. |
| Ask        | when something essential is missing, or an action would lose data, open a hole or change the design; decide the routine yourself. |
| Sandbox    | if yours keeps the desk's `.git` or the office's state read-only (Codex's does), run git, the tests and `vikix` outside it: ask to escalate; the house's rules let a desk's day through without a prompt. |

The Stop hook holds Claude Code and Codex to the hand-in (a worker that changed files is asked once for its handoff before it stops); a provider with no hook is held by the table alone, and the handoff's protection lines say which it is.

A note for a worker at work: `vikix agents tell wifi-fix "try the laptop's second card too"`. It waits at the desk, shown by `vikix agents handoff` and counted under the agent's line in `vikix agents`, and the hook hands it to the agent at its next tool call, signed and timed, so nothing types into its window. An agent at its prompt makes no tool call until you speak to it, so `tell` says when that is so: the note waits on your next question to it, not on the hook. `tell wifi-fix "..." --now` wakes it instead: an agent at its prompt (a stop let through, nothing since) whose conversation its provider can resume is asked to exit and resumed with the note as its prompt, in a terminal at the desk, and the record logs *woken*; when it can't be (the agent is working, two are at the desk, no conversation is noted, no desktop), why is said and the note waits as usual. Only Claude Code's and Codex's hooks can carry words to the agent: for the others `tell` says so, the note stays in the handoff for the agent to read there, and `resume` reads the notes out to whichever agent takes the desk up. A note is for whoever works the desk, now or next; what `dismiss` and `handover` leave (*write your handoff, then stop*) is for the one agent they address, and dropped once it is gone, and a worker is never handed a note from before it started unless it is yours (the first day with two providers delivered a dismissal to the next fresh worker, which obeyed and stopped, 2026-10-11). A note is text like the handoff's: a line that looks like a key is refused.

### The work: tasks and their history

A desk is a place, and a worker is whoever sits at it; the work itself is a **task**, and each one has a record of its own, apart from the desk it is done at and the agent doing it. One is made by every way work starts (`vikix agents desk vikix wifi-fix --task "..."`, `vikix agents worker`, `vikix agents sit --task`, `vikix agents handoff --task`, the Office's forms, a plan) and lives in `~/.local/state/vikix/office/tasks/`, one file a task, named by its **id**: the day it was made and six hex digits, `t-20261014-0d2c16`, which it keeps for life. Workers come and go at the desk; the task keeps its id, who made it (you, an agent, a plan), its priority, when it was created, launched and done, every launch that worked it, and the agent's handoff as it stood at the last write. The desk's record names its task by id, and the task names its desk, so `vikix agents handoff` and `vikix agents task` show the same work from two sides.

Each launch has a **number**, the order the workers were started in: `#1`, `#2`, and so on from one counter for the whole office (`office/sequence`, taken under a lock, so two launches at once never share a number and it never goes down). A desk's row in the Office carries it before the project, and `vikix agents resume` takes the next one: a worker resumed is a new launch of the same task, whichever provider it is. An agent you started yourself and seated with `vikix agents sit --task`, or a task given to a desk with `handoff --task` while an agent is there, runs with no number: the office never started that agent, and no number is made up.

**Two states, never one.** What the worker is doing (working, at its prompt, waiting for your yes, gone) is read from its terminal at each look, with where it was read and how sure (*reliable*, *inferred*, *unknown*). What the task is at is recorded, and moves only by a named step: *ready* when it is made, *running* when launched, *needs decision* when the agent's handoff says waiting, *needs review* when it says review, *ready for release* when it says finished (its work is done, yours is not), *blocked* on its worker when the worker's process ended, on the tests when they failed with no worker there, or on *parked* when the handoff says so; *completed* by the release, or by closing the desk with its branch merged; *cancelled* by closing it with `--force`. A word that asks for the state the task is in moves nothing. A worker's exit never completes or cancels anything: the task is blocked on its worker and stays in view, to be resumed, handed on or cancelled; a new worker at the same desk leaves the task before it blocked the same way, at the desk's back.

`vikix agents tasks` lists them, the open ones in launch order, then the done ones of the last day (`--all` for every one):

```
$ vikix agents tasks
3 tasks open; the last launch number is 2:
  #1     blocked            vikix/bar-clock                  claude   normal   just now         the seconds, then the date on hover  [t-20261014-5ec49e]
  #2     running            vikix/wifi-fix                   claude   normal   just now         the Wi-Fi picker should scan first, then show the list  [t-20261014-0d2c16]
  #?     blocked            vikix/bar-clock                  ?        normal   just now         the bar's clock should show seconds  [t-20261014-0d68eb]
```

A row is the launch number, the task's state, its desk as project / branch, the provider, the priority, when something last happened to it, its words and its id. `#?` is a task with no launch number: one adopted from before the records (below), or one whose agent the office never started. `vikix agents task ID` is one task's page, with its history; a desk's name does for its task:

```
$ vikix agents task wifi-fix
Task t-20261014-0d2c16: the Wi-Fi picker should scan first, then show the list
Status: running (user, just now): desk --task
Origin: yours
Priority: normal
Project: vikix
Desk: ~/src/vikix-wifi-fix (branch wifi-fix)  [c23757154330]
Launch: #2 claude · just now · by user
Created: just now; queued: unknown; launched: just now; last activity: just now; done: unknown
Text:
  the Wi-Fi picker should scan first, then show the list
Handoff (the agent's words, as the desk's record had them at the last write):
  status working (user, just now)
Launches: 1
  #2  claude  just now  by user  (desk --task)  not ended
History (4 events, newest first; vikix agents events t-20261014-0d2c16 has them all):
  2026-10-14 07:14  handoff  by user  status working
  2026-10-14 07:14  launched #2  by user  provider claude, how desk --task, from ready
  2026-10-14 07:14  worker  by user  task the Wi-Fi picker should scan first, then show the list
  2026-10-14 07:14  created  by user  title the Wi-Fi picker should scan first, then show the list
```

*Unknown* on a page is a time or a fact the record never had: this task was never queued and isn't done, so both say so, and nothing is guessed in their place. The page of the stopped worker says how it ended:

```
$ vikix agents task t-20261014-5ec49e
Task t-20261014-5ec49e: the seconds, then the date on hover
Status: blocked (vikix, just now): the worker stopped
Blocked on worker: the worker stopped
...
Launch: #1 claude · just now · by user · ended
...
Launches: 1
  #1  claude  just now  by user  (worker)  ended just now, exit 0
History (5 events, newest first; vikix agents events t-20261014-5ec49e has them all):
  2026-10-14 07:14  blocked  by vikix  running -> blocked, on worker, reason the worker stopped
  2026-10-14 07:14  exited  by vikix  code 0
  2026-10-14 07:14  launched #1  by user  provider claude, how worker, from ready
  2026-10-14 07:14  worker  by user  task the seconds, then the date on hover
  2026-10-14 07:14  created  by user  title the seconds, then the date on hover
```

The exit code comes from the terminal itself: every worker's terminal runs its agent under one line that notes how the process ended (`vikix agents exited`), so the task's history has it whatever the provider, with hooks or none.

**The desks from before.** A desk made before the records existed has a task in its own record and no task record: the first `vikix update` with this (the migration, or `vikix agents tasks adopt` by hand, safe to run again) makes one for each desk's task and for each worker in its history, with what the desk's record knew and nothing more. Who gave the task and when it was written are there; the handoff's last status is read into a state (working is *running*, finished on a desk the release closed is *completed*, a history entry with no status at all is *cancelled*); what the record never had is left empty and shown as *unknown*: the launch order, for one, which is why such a task shows `#?` in the list and *launch order unknown* in the Office, and when it was launched. Nothing is made up to fill a gap, and the desk's record is touched in nothing but the ids written back into it. The adopted task's page says what it couldn't know:

```
$ vikix agents task bar-clock
Task t-20261014-0d68eb: the bar's clock should show seconds
Status: blocked (user, just now): another task started at its desk
Blocked on worker: another task started at its desk
Origin: yours
Priority: normal
Project: vikix
Desk: ~/src/vikix-bar-clock (branch bar-clock)  [c16d6c81c1e6]
Launch: not launched
Created: just now; queued: unknown; launched: unknown; last activity: just now; done: unknown
Text:
  the bar's clock should show seconds
Handoff (the agent's words, as the desk's record had them at the last write):
  status working (user, just now)
  done and decided (user): half done
History (2 events, newest first; vikix agents events t-20261014-0d68eb has them all):
  2026-10-14 07:14  blocked  by user  running -> blocked, on worker, reason another task started at its desk
  2026-10-14 07:14  adopted  by vikix  status running, unknown: its launch order; when it was launched, title the bar's clock should show seconds
```

**The events.** Every step is a line in one log, `~/.local/state/vikix/office/events-YYYY-MM.jsonl`, a file a month, appended and never rewritten, which outlives the records: a task created, launched with its number, a hand-in, a check, a question asked (the handoff's waiting) and answered (work taken up again), blocked and unblocked, exited, handed off, released, completed, cancelled, adopted; a line names its task and its desk, and a record's own log keeps only the last forty, so the whole history is read back from here. `vikix agents events` shows it newest first, for the desk you sit at, a task's or a desk's by name, or all of it (`--all`), back to a time (`--since 2h`, `30 min`, `3 days`, `2026-10-10`), `--limit N` lines (a hundred), `--json` the lines as they are:

```
$ vikix agents events --all --since 1h
2026-10-14 07:14  handoff  by user  status working
2026-10-14 07:14  launched #2  by user  provider claude, how desk --task, from ready
2026-10-14 07:14  worker  by user  task the Wi-Fi picker should scan first, then show the list
2026-10-14 07:14  created  by user  title the Wi-Fi picker should scan first, then show the list
2026-10-14 07:14  blocked  by vikix  running -> blocked, on worker, reason the worker stopped
2026-10-14 07:14  exited  by vikix  code 0
2026-10-14 07:14  launched #1  by user  provider claude, how worker, from ready
2026-10-14 07:14  blocked  by user  running -> blocked, on worker, reason another task started at its desk
2026-10-14 07:14  worker  by user  task the seconds, then the date on hover
2026-10-14 07:14  created  by user  title the seconds, then the date on hover
2026-10-14 07:14  adopted  by vikix  status running, unknown: its launch order; when it was launched, title the bar's clock should show seconds
```

Each line is signed, as the handoff's are: *user* for your act, *vikix* for what the office read itself (an exit, a release, an adoption), an agent by name and number for its handoff. The same records are what the Office draws (the launch number on the row, the **Task record** box and the history on a desk's page), what `vikix agents office --json` and the MCP tool `office` carry in their version 2, and what the read-only MCP tool `tasks` gives an agent; the release appends *released* and completes the desk's tasks. The task board's settings (`at_once`, `auto`, `quiet`, `delegate`, `delegate_max`) are written as comments with their defaults into `~/.config/vikix/office` by the same update; the attention list and scheduler read these settings now. The full five-section task board remains a later phase (`plans/DESIGN-office-tasks.md`).

### Priorities and the task queue

A task's priority is `critical`, `high`, `normal` or `low`. Its position
within that priority is separate. `vikix agents queue` shows both, the next
eligible task, and why any task must wait. Reading the queue or refreshing
the Office never starts a worker.

Make a task without starting it, then queue it:

```sh
vikix agents task new vikix picker "Improve the picker" --use codex --priority high
vikix agents queue add TASK
vikix agents queue start
```

Replace `TASK` with the id printed by `task new`. Repeat `--after TASK`
when a new task depends on other tasks. A dependency must be completed;
when both tasks use the same desk, *ready for release* is sufficient,
since the next task builds on that branch. The new desk is made only when
its task starts. To queue a task already ready at an existing desk, use
its id from `vikix agents task DESK`.

- `queue add TASK --first` puts it first within its priority.
- `queue next TASK` makes it the next eligible task across priorities.
- `queue up TASK` and `queue down TASK` move it within its priority.
- `task priority TASK high` changes priority without changing manual order.
- `queue defer TASK` returns it to ready; `--later` returns it to backlog.
- `task ready TASK` makes a deferred or blocked task ready and approves it.
  A worker still at its desk must finish or be closed first.
- `task cancel TASK "reason"` cancels the task. An existing worker continues;
  cancellation is not a command to dismiss or signal it.
- `queue start [TASK]` starts one eligible task. `queue pause` and `queue go`
  hold and resume scheduling without pausing workers.

Only the user changes priorities, orders the queue, cancels tasks, or
starts a queued worker. Agents can read `queue --json`; its information
also appears in the read-only Office snapshot and MCP `office` tool.

The Office has **Queue** and **Blocked** boxes. Each queue row shows its
position, priority and blocker, with buttons for its actions. On a queue
row, `!` means run next, `+`/`-` changes priority, `M-p`/`M-n` moves up/down,
`d` defers, `k` cancels with confirmation, and `S` starts it. On a desk's
ready task, `Q` adds it to the queue. **Start next** chooses the first
eligible task. `K` now shows or hides parked desks (formerly `k`).

#### Capacity and automatic starts

The settings are in `~/.config/vikix/office`:

```text
at_once=2
auto=off
```

Defaults apply when these lines are absent. `auto=on` explicitly lets
scheduler events start approved tasks up to the capacity. Nothing changes
this setting for you. Without it, an event only announces newly eligible
work. Events include handoffs, exits, answers, releases, queue changes and
closing desks. `queue tick` processes an event by hand and obeys the same
setting. There is no polling daemon or scheduler work in StumpWM's thread.

The scheduler counts observed workers on running or review tasks and
pending terminal starts. Paused workers do not use a slot. A task waits
when discovery is unavailable, its provider is unavailable, it is not
approved, an answer or dependency is outstanding, its desk is paused or
occupied, or its branch is being released. It never takes missing
observations as permission to launch. Plan workers use this same capacity
and launch lock; a plan's own `at-once` may impose a smaller limit. A plan
explicitly started by you still runs its approved steps with `auto=off`;
its dependency and release gates remain the plan runner's.

A start reserves its launch number and slot before opening the terminal.
The queued task keeps its id, history and recorded worker choices. A
reservation stays until the worker is observed or its exit is recorded.
After two minutes, a later tick with reliable discovery marks an ambiguous
start blocked; it never launches it again automatically. Inspect the desk
before making that task ready again.

`queue bump TASK --over DESK` is an explicit preemption: it pauses DESK's
worker at its next tool call and starts TASK at a different desk. The old
task records what it was paused for. `vikix agents go DESK` restores it.
The scheduler never preempts on its own. Its pause is cooperative, so the
old worker may finish its current tool call before it waits.

### Modes: how free a Codex worker is

Codex runs what it is asked in a sandbox of its own (bubblewrap and seccomp on Void), and asks you before each step out of it. At a desk that is many steps: the desk's `.git` is a file pointing into the repository's, which the sandbox keeps read-only, so every commit asks; so do a snapshot, the tests and the handoff, which write under `~/.local/state`. And the sandbox as your own `~/.codex/config.toml` may widen it can reach the project's own folder and every other desk. So Vikix starts Codex with a **mode**, `vikix agent --mode supervised|autonomous|unrestricted`, and `vikix agents worker`, `desk --task` and `resume` take the same word:

- **supervised**: Codex's sandbox is the desk alone (the folder and `/tmp`; your `writable_roots` are set aside for the session, so the project's own folder, `~/vikix` and the other desks are read-only to whatever it runs), the network off, and every step out of it asks you, unless Vikix's rules allow it (below).
- **autonomous**: the same sandbox, the network on (for `pip`, `cargo`, a fetch over HTTPS), and a reviewer of Codex's own (`--approve-for-me`) answering the steps out of it in your place. This is what a worker at a desk gets when nothing says otherwise, and what Super+a's *Agent here* gets in your home folder (a folder of no repository; there the sandbox is your home and `/tmp`): the house default is `mode=autonomous` in `~/.config/vikix/office`, which Vikix writes with its meaning the first time Codex starts, and you may change. In a repository that isn't a desk (a project's own folder, a stranger's) Codex runs as your own `~/.codex/config.toml` says.
- **unrestricted**: no sandbox and no approvals (`--dangerously-bypass-approvals-and-sandbox`), for a VM or a container. It is never a default: typed each time, warned about in the terminal and in a notification, refused in a project's own folder, and written into the desk's record, so the handoff's protection lines say *no sandbox: unrestricted, by the user* under that agent.

**Vikix's rules for Codex**, `config/codex/vikix.rules`, linked as `~/.codex/rules/vikix.rules` by `vikix agents hooks codex --install` (Codex reads every `.rules` file there, so a file of your own beside it stands, and one in the way is left alone), let a desk's day run outside the sandbox without a prompt: `git` on the desk's branch (add, commit, status, diff, log, rebase, checkout, fetch, merge, stash, a plain `branch` or `tag`), `tests/run.sh`, `vikix` (snapshot, changes, agents, try, docs, what, why, rules, eval, project, records, doctor, theme) and `.claude/release`, which refuses the dangerous cases itself. `git push` and `vikix update` prompt (a worker started `--push` is meant to push), deleting a branch, a tag or a worktree prompts (closing a desk is `vikix agents close`), and `sudo`, `doas` and a force-push are forbidden outright. `codex execpolicy check --rules ~/.codex/rules/vikix.rules -- git commit -m x` shows what a command gets. Codex matches a rule from the command's first word, so `timeout 20s vikix snapshot ...` matched nothing and asked every time (2026-10-11, each snapshot's message approved once more): the house rules' hook on each step out of the sandbox (below) allows the same commands under `timeout`, `env`, `nice`, a `VAR=value` or `bash -lc`, when every command of the line is one of them; the prompting and forbidden cases stay Codex's.

**The repository's instructions.** Codex reads `AGENTS.md` from the repository's root down to the folder it works in, never `CLAUDE.md`. Vikix gives it, for the session, `CLAUDE.md` as the file to fall back on where a folder has no `AGENTS.md`, with Codex's cap raised to hold Vikix's whole; a repository with an `AGENTS.md` is read as its author meant. So a Codex worker on Vikix reads the same instructions Claude Code does. The desktop's guide stays `~/.codex/AGENTS.md`, as before.

**The hook's trust.** Codex runs a hook of yours only once you trusted it in `/hooks`, by the file's hash, which every release that changes the file undoes. When `~/.codex/hooks.json` is Vikix's (the link `--install` makes, or a copy of the file) and the folder is one of your projects (`vikix project list`) or no repository at all (your home, Super+a's *Agent here*), `vikix agent` passes `--dangerously-bypass-hook-trust`: Vikix vets that file by making it. In a repository that is no project of yours Codex's own prompt stays, so a stranger's `.codex/hooks.json` never runs untrusted; `VIKIX_CODEX_HOOK_TRUST=ask` keeps the prompt everywhere. `vikix agents hooks codex` says which holds, and reads your `~/.codex/config.toml` for a setting under a header Codex doesn't read (`sandbox_mode` under a `[section]` line did nothing, and Codex ran read-only, asking for every write, 2026-10-11); `vikix doctor` says the same. The file is yours: Vikix never writes it.

The modes are Codex's for now: `--mode` with another agent is refused with the words, and each other provider's mapping comes as it is tried (Claude Code's `--permission-mode`, OpenCode's `permission` block, Gemini CLI's `--approval-mode`). What the mode changes is who answers a step out of the sandbox; the house rules' hook runs before either sees it, and the sandbox under both. What it does not do: a command that writes through a program the hook doesn't know still passes the hook (the sandbox holds it to the desk), and the reviewer in *autonomous* is a model's judgement and no rule. What the first live run showed (2026-10-10, `tests/codex.sh --live`, by hand: one `codex exec` at a scratch desk under the *autonomous* row): the sandbox is as said, the desk writable and the project's own folder, the desk's `.git` and the repository's worktree folder read-only; Codex's hooks fire ([What holds the rules](#what-holds-the-rules-for-each-agent)); and a Codex told only its task ran `git commit` and the handoff inside the sandbox, saw both fail on the read-only `.git` and state, and stopped, where one given a worker's first prompt, which ends with the definition of done and its sentence on the sandbox, asked to run each outside, and the rules let the estimate, the commit and the hand-in through with no prompt. So start a Codex worker through the office (`vikix agents worker`, `desk --task`, `handover`), which gives it that prompt. The run of 2026-10-11 (Codex 0.162.1) added one step: `timeout 20s vikix snapshot ...`, which no rule matches, got out of the sandbox through the hook's allow, noted in the journal as a command of the agent's; `codex exec` forces `approval never` without `--approve-for-me` (*Escalated retry is prohibited by this environment*), so the *supervised* row is probed only in a session of its own.

### Pausing a worker, and taking turns

`vikix agents pause wifi-fix` holds the worker: the next thing it does, an edit, a command or a read, waits in the hook with its context whole, costing nothing, until `vikix agents go wifi-fix`. The pause takes hold at that next call, not this instant, so a long think or a read finishes first. After ten minutes the waiting call is refused with why, the turn ends cleanly, and the worker says it is paused. `go` then wakes it rather than wait for your next words (until 2026-10-11 it sat at its prompt until you spoke to it): as `tell --now` does, the one agent at the desk, at its prompt, with a conversation its provider can resume, is asked to exit and resumed with the words to carry on where it was, and the record logs *woken*; when it can't be (two at the desk, no conversation to resume, no desktop) `go` says why and the words wait in its inbox, read at its next tool call. `vikix agents go wifi-fix` says how long the desk was paused and who goes on; the held call then goes through with a word from the hook, so the worker, which saw nothing of the wait, knows it was paused, by whom and for how long, and carries on from where it was, with a note you left meanwhile (`tell`) after it. `vikix agents` and the Office show the desk as paused, by whom and since when. `--hard` freezes the agent's process this instant instead (SIGSTOP, found by its process descriptor, never by name) and `go` thaws it: for an agent with no hook, such as Aider, or an emergency, and said as such, since a request in flight may time out while frozen.

Two workers reaching for one file are stopped at your prompt, as the house rules say below. With `vikix agents turns wifi-fix on`, the worker at that desk waits instead: an edit of a file another agent has changed, uncommitted, waits for that agent's commit, up to ten minutes, and goes on with "your turn" when it comes, or asks you when it doesn't. A journal entry alone holds nobody: once the file is committed in the other's worktree, the turn is free. Two waiting for each other is seen, and the later one asks you at once. It is off by default, because silence is wrong for a session you are talking with; `turns off` puts the question back.

### When the network goes

Claude Code retries a request for a few minutes when the network is down, then gives up and ends the turn with an API error (*Can't reach the API server*, *Connection lost mid-response*); until 2026-10-14 the agent then sat at its prompt until you typed *continue*, once you had noticed. Now a watcher follows each Claude Code at a desk, started by its hook at its first tool call (one small process, reading only the end of the transcript, and only when it has grown; `VIKIX_RECONNECT=0` in the agent's environment keeps the hook from starting one). It sees the turn end that way, notes the stop in the journal, so `vikix agents` says *stopped by the network: taken up again when it is back*, and asks the API's host for a connection every ten seconds, nothing sent (`api.anthropic.com`, or the host of `ANTHROPIC_BASE_URL`). When it answers twice in a row the agent is woken as `go` wakes one: asked to exit and its conversation resumed with the words to carry on, naming the error and how long the network was gone, and the record logs *the network was back*. A watcher stands down when the conversation went on by itself (you typed *continue* before it), ends with its agent (a woken agent is a new process, which gets a watcher of its own at its first call), and gives up after a day. `vikix agents reconnect wifi-fix` does the same by hand, now, for one desk or `--all` of them: it says when the agent's last turn wasn't ended by the network, or when the host doesn't answer yet (`--wait` waits for it there). A login that expired and the credits running out end a turn the same way and are not the network's: those stay yours. Only Claude Code's transcript says how a turn ended, so a Codex worker stopped by the network is still taken up by hand, and an agent in your home folder (*Agent here*) has no desk to be resumed at.

### The tester: a hand-in comes back checked

The Office also follows runs a worker starts directly with `tests/run.sh`.
The desk's Testing row shows completed/total and remaining counts, the names
running now, and a rough time left. Its Testing box has the run as a table,
a row a test in the runner's order: the test, its state (passed, failed,
running, queued), how long it took or has run so far, its estimate (about so
long left, past estimate, about so long once started, or unknown), and
*suspected stalled* in the last column when it is. Estimates use each test's
last successful duration on this machine; parallel work is accounted for, but
time waiting for other runs' slots is additional. The first run has no
history, and an overrun makes the total ETA unknown. A running test past
three times its previous duration (and at least five minutes), or fifteen
minutes without history, is **suspected stalled**. This is a long-runtime
warning, not proof: quiet tests can still be working. Queued tests are never
marked stalled, and nothing is stopped automatically. Direct runs keep their
output and stop control in the worker's terminal; **Skip tests** and
**Test log** belong to runs started by the Office's tester.


When a worker sets its status to *review*, its desk's tests run by themselves: `vikix agents test wifi-fix` is what runs, a script and never an agent. It runs the project's `tests/run.sh` in the desk's worktree, `--changed` from where the branch left the project's own, through the runner's queue like any other run (and after a release's tests, when one of the project is testing: the two at once failed for load alone; not for a change no test covers, a plan or a design, which `tests/changed.sh` says and runs at once; a wait taken is said in the check apart from the run's time), and writes the result into the record as a check signed *vikix*, the failing tests named and the first failure's line kept, and into the worker's inbox, so the worker reads it at its next tool call and fixes its own failures; `vikix agents test --log wifi-fix` shows the whole run. `vikix agents` says *testing* while it runs, and the Office lists the desk under **Testing**, its row saying what runs and since when, with **Skip tests** on the row; the desk's **Testing** box has the release it waits for, the last lines of the run (each test's output comes whole when it ends) and **Test log**, the whole run so far in the desk pane. **Skip tests** (`vikix agents test --skip wifi-fix`, the key `s`) is for when you won't wait: the tester is ended, the runner and its tests with it, and the record gets a check marked *skipped* on the commit as it stands, which a plan's chain takes as the hand-in checked, so the next task starts; the worker is told in its inbox. The release never takes a skipped check for a run of its own. A project with no `tests/run.sh` is said so, with no check. The release reads the same checks: `.claude/release` skips its own run, and says so, when the record has a passing run of the runner as wide as its own on the very commit it merges, with a clean tree (one commit was tested four times in a day, 2026-10-11); a run of named tests, a check on an older commit or a failed run after the passing one vouch for nothing, and `--tests none` stays as typed. A desk made, or a worker started, with `--no-tests` (the Office's *No tests by themselves* box) runs nothing at the hand-in: the tests are yours to run, with `vikix agents test wifi-fix`, the Office's *Test* or the desk key `t`, and `vikix agents test --all` leaves such a desk out and says so. The setting is the desk's, kept in its record and shown by `vikix agents handoff` and in the Office (*tests off*); a worker started on a task without `--no-tests` has the tests again.

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

A plan starts from a template. `vikix agents plan templates` lists them: Vikix's (`config/plans/`: *one-task*, a single job, one worker at one desk, released when its work is in; *build-chain*, build it, then its tests, then its guide, three workers in turn at one desk, released once at the end; *two-desks*, two desks at once, each its own part, then a task joining them at a fresh desk) and your own, `~/.config/vikix/plans/templates/*.toml`, a plan each whose first line is `# NAME — what it is for`, with `PROJECT` where the project goes, `topic` in each desk's name and `EDIT:` beginning the lines that are yours to write; one of yours with a Vikix name stands in for it. `vikix agents plan new TEMPLATE NAME PROJECT [--at-once N] [--gate me|none]` writes the copy to `~/.config/vikix/plans/NAME.toml` with the project, and the two settings when given, filled in, each desk named for the plan (`topic` becomes `NAME`, `topic-one` `NAME-one`), and the template's comments kept, so the file explains itself. Then you write its `EDIT:` lines in your own words: `plan run` refuses a task still holding one, and until the plan has run it is a *draft*, which `plan status` lists and the Office's Plans box shows with its Run. The Office's **New plan…** is a form with the template's tasks as its fields, which writes the words in (see [The Office](#the-office)).

Its state is worked out each time from the plan file and the desk records (which task is the record's, what came before in its history, the checks and their freshness, who is at the desk), so a reboot loses nothing and `plan run` again carries on; only its switches are its own, in `~/.local/state/vikix/office/plans/`. It wakes on the office's event log, `~/.local/state/vikix/office/events-YYYY-MM.jsonl`, one line a hand-in, a check, a worker started, a desk closed or an agent that left, written by every record write (and, from 2026-10-14, every step of a task's record: created, launched with its number, blocked, exited, released, completed; `vikix agents events` reads it back), and looks round by itself once a minute besides. `vikix agents plan status` says where each plan stands, a line a desk and a line a task; `plan pause` starts nothing new, `plan stop` ends the runner (the workers at work carry on), `plan log` is what it did. What it can't know: which files two desks will touch; turns and the clash rules handle that.

### Dismissing a worker, and how it left

`vikix agents dismiss wifi-fix` asks the desk's agent to exit and keeps the desk, its branch and its files, so `vikix agents resume` takes it up later; it is the Office's *Close agent* from the terminal. A note goes to the worker first, "dismissed: write your handoff if you can, then stop", for that agent alone: one mid-turn reads it at its next tool call, and no later agent at the desk ever does; the record notes the dismissal and how many files were left uncommitted. An agent never dismisses itself. Whichever way an agent leaves a desk, dismissed, exited or logged out, Claude Code's SessionEnd hook (`vikix agents left`; Codex's hooks file has the same, though `codex exec` fires none, so a Codex's leaving is noted from a session of its own) notes it in the record, so the next one at the desk, and the Office, see *Left: dismissed, 3 uncommitted then*.

### Handing a desk over

Claude Code designs at a desk, Codex implements, Claude reviews: each step is a handover, and `vikix agents handover wifi-fix --to codex` is the one command that does it. It is refused while the desk's agent is mid-turn (an edit, a command or a turn begun in the last minute, as the hooks' journal says) unless `--now`; then the agent is asked for its handoff in a note (for it alone) and given up to two minutes to write it, the record's handoff watched for the change (an agent at its prompt reads no note, so it isn't waited for); then the next agent's task is settled: `--task "..."`, or the record's next step as the agent left it, never the task as it stood, which was the last agent's (the designer's *a plan, no code* became Codex's orders on the first day, and it handed in after 27 seconds), and with neither the handover is refused and the agent stays; then it is dismissed as `dismiss` does, the task before and its handoff go into the desk's history whole, and the next agent is started with `vikix agents resume wifi-fix --use codex --fresh` (`--mode` as a worker's), its first prompt its task, the desk's fields (the criteria, the decisions, the defects, the findings, what changed, the commits) and the last agent's account and next step, so it starts from what the last one left rather than from an empty prompt. The record logs *handed over: claude -> codex* and keeps both sessions, so `vikix agents resume --use claude` later finds Claude's conversation and `--use codex` Codex's. Nothing of either conversation is copied: git, the record and the project's documents are the common ground. An agent never hands its own desk over.

### A review by another agent

`vikix agents review wifi-fix --use codex` has another provider read a desk's work and say what it finds, without ever sitting at the desk. The desk's last commit is checked out in a throwaway worktree of its own (the uncommitted files are left out, and said so), and the reviewer is run there with no window and no way to write: Codex as `codex exec --sandbox read-only` with approvals off and an output schema, Claude Code as `claude -p --permission-mode plan` with the same schema asked for on the line; its keys and your SSH agent are withheld as `vikix agent` withholds them. It is given the task, the acceptance criteria as the worker ticked them, the decisions already made, the worker's own account and where the branch left the project's own, and asked for findings in one shape: where (`FILE:LINE`), how much it matters (high, medium, low) and one or two sentences a person acts on. It runs apart from your shell, as a hand-in's review does, and says so (a review read from a pipe under a timeout orphaned the reviewer and lost its findings on the first day); `--here` waits for it. Each finding goes into the handoff's *Review* signed by the reviewer (*codex 1234*), a line goes into the desk's inbox and the record's log, and the worktree is removed; `vikix agents review --log wifi-fix` keeps the reviewer's words. A worker at work reads the findings at its next tool call, as it reads any note; one that handed in sits at its prompt and makes none, so it is woken as `tell --now` wakes it: asked to exit and resumed with the review's line as its prompt, its conversation kept, and when it can't be (its state unknown, no conversation to resume) the desktop is told it must be. The worker addresses them and marks each one with `vikix agents handoff --review-done N`. `--use` unsaid takes the provider that isn't the desk's (Codex's work is read by Claude, Claude's by Codex); `--prompt "look hard at the retry loop"` adds your words. `vikix agents` and the Office say *under review by codex* under the desk's agent while it runs, name the reviewer's own process *reviewing* when it has a terminal, and refuse a second review until the first is done; a reviewer that fails, or answers in prose, is kept as it is (one finding holding its words, or the failure in the log) rather than lost. A review by itself at each hand-in is one line in `~/.config/vikix/office`, `review=codex`; it is off unless you write it, since a review costs a model's time and is asked for, not assumed. The Office's *Review by…* button (the key `r`) starts one on the selected desk, asking which reviewer when both are installed, and the desk's page shows the findings open or addressed.

Each of the worker's commands has a form for the desktop: in the desk keys (`Super+Alt+d`) `w` starts a worker at a desk (the desk picked in a menu, the task typed, nothing for a session, then which agent and whether it may push, as a new desk asks; a desk with an agent at it is refused in a notification), `t` tests a desk's work, `p` pauses its agent or lets it go, `i` leaves it a note, `x` dismisses it, each asking which desk in a menu, and `Super+m` → *AI* has the same (*Agents: a worker at a desk*); the Office has them as buttons.

### A day with the two providers

The office's commands make the day the design in `plans/DESIGN-codex-integration.md` describes, one record from start to end. Claude Code designs, Codex implements, Claude reviews, Codex corrects, the house releases:

```sh
vikix agents desk vikix wifi-fix --task "design the Wi-Fi picker's rescan: a plan in plans/, no code" --use claude
vikix agents handoff wifi-fix                  # Claude's hand-in: status review, the design decided, its next step written
vikix agents handover wifi-fix --to codex      # Codex starts on that next step (or --task "..."), with the record; it implements, tests, hands in
vikix agents review wifi-fix --use claude      # Claude reads Codex's last commit: findings into the record, Codex woken with them
vikix agents handoff wifi-fix                  # the findings addressed (--review-done N), the tests' check fresh
.claude/release wifi-fix "the Wi-Fi picker rescans"   # the house's release step, from any shell; a fresh check on the commit spares its tests
```

The first such day was run on Vikix itself on 2026-10-11, at the desk `random-guide` (a guide page at random, `vikix docs random`). What it ran, from the desk's record, and what each step found:

```sh
vikix agents desk vikix random-guide --task "design a guide page at random: a plan in plans/, no code" --use claude
                                               # claude: the design (plans/DESIGN-random-guide.md), status review in 15 min
vikix agents handover random-guide --to codex  # codex got the task unchanged, "no code": it handed in review after 27 s, having done nothing
vikix agents dismiss random-guide
vikix agents worker random-guide "Implement plans/DESIGN-random-guide.md as it stands" --use codex
                                               # the dismissal's note reached the new worker at its first tool call: it obeyed, and stopped; and once more
vikix agents worker random-guide "Implement plans/DESIGN-random-guide.md as it stands" --use codex
                                               # the third codex implemented it: commit 7f9f534, its tests, status review
vikix agents review random-guide --use claude  # four findings (a guide's table, the deck's round, a dead line, apostrophes); run under a timeout, the reviewer was orphaned once
vikix agents worker random-guide "Address the review of your commit 7f9f534 ..." --use codex
                                               # the new worker found the findings, the defects and the decisions gone from the record; it put them back from its task
                                               # its tests/run.sh --changed hit the queue's deadline waiting for rescue; a named rerun passed
.claude/release random-guide "..."             # refused twice: a timing check in tests/house.sh at a load of 5.5 on 4 cores, then a screen test
```

Six defects of the office came out of it (the handover's task, the notes' addressee, the review in the foreground, the findings unread at a prompt, the record's history, the signing of an agent's commands) and four costs (one commit tested four times; a change of two plans tested for thirty minutes, the tester waiting on a release; a timing check failing for load; the alone tests holding `--changed` runs past their deadline), each fixed in the release after it with a test of its own. The commands above are the day as it should go now.

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
codex     hooks in ~/.codex/hooks.json: PreToolUse (apply_patch read for its files, Bash; a clash refused once, since it can't ask), PermissionRequest (a step out of the sandbox: off the desk denied, a routine command allowed, ...), UserPromptSubmit, Stop and SessionEnd (...); and Vikix's rules in ~/.codex/rules/vikix.rules (...). Seen firing here on 2026-10-10 (tests/codex.sh --live, Codex 0.160): UserPromptSubmit, PreToolUse, PermissionRequest (...) and Stop; SessionEnd not in codex exec
          not installed (vikix agents hooks codex --install links ~/.codex/hooks.json)
          not installed (vikix agents hooks codex --install links ~/.codex/rules/vikix.rules)
          trust: vikix agent passes --dangerously-bypass-hook-trust in your projects and in a folder of no repository (your home, Super+a's here) when the hook file is Vikix's ...
          ~/.codex/config.toml: sandbox_mode, approval_policy stand under [section], a table Codex doesn't read, so they do nothing; move the lines above the first [...] header (your file: Vikix doesn't write it)
opencode  a plugin on tool.execute.before (edit, write, bash): a refused edit throws, with the reason ...
          not installed (vikix agents hooks opencode --install links ~/.config/opencode/plugins/vikix-office.js)
gemini    a BeforeTool hook to merge into ~/.gemini/settings.json by hand ... unverified here
antigravity a plugin of Vikix's that vikix agent installs with agy plugin install ...: pre-edit and pre-shell hooks
aider     no hooks: instructions only (the guide it reads), and git
```

Three levels, and the listing never claims more than there is. *Instructions only*: the agent has read the rules in its guide, and git shows afterwards what it did. *Pre-edit hooks*: the house rules run before each edit and shell command and can refuse it; Claude Code and Antigravity CLI have them from `vikix agent`, Codex and OpenCode get them from an adapter you install once (`--install` links a file of Vikix's into their folders and leaves a file of your own alone; Codex's hooks were seen firing here on 2026-10-10, `tests/codex.sh --live`; Gemini's shape is from its documentation and marked unverified until one has fired here). *Filesystem enforcement*: none from Vikix. A worktree keeps copies apart, and the hook reads a shell command's words; neither is a sandbox, and the page doesn't call them one. Codex brings a sandbox of its own, and in the *supervised* and *autonomous* modes ([Modes](#modes-how-free-a-codex-worker-is)) Vikix narrows it to the desk; the handoff says so under a Codex at the desk (*sandboxed to its desk*), and *no sandbox: unrestricted, by the user* when you asked for that. A hook that a provider lacks keeps nothing else from working: the handoff and the resume are the same for every agent.

**Codex's hooks**, `config/codex/hooks.json` linked as `~/.codex/hooks.json`, are the same rules at Codex's tools, since its hooks differ from Claude Code's in three ways. Its edit tool is `apply_patch`, whose input is the patch text, so the hook reads every file the patch names (its Update File, Add File, Delete File and Move to lines; a patch applied through a Bash heredoc the same) and judges each as an edit: off a desk or in the project's own folder denied, a crossing told, a note from `vikix agents tell` delivered. Its hook can't ask, so a clash (another agent on the file) is refused once, with the reason and `vikix agents clash FILE`, and the same edit within ten minutes goes through, Codex having told you, as OpenCode's does. And it has a hook on each step out of its sandbox (`PermissionRequest`, `vikix agents touch --for codex --escalation`): one that would write into the project's own folder, `~/vikix`, another desk or `~/.config/vikix/secrets/` is denied with the reason, whatever the mode and wherever the agent sits (a session in your home folder too), so in *autonomous* the reviewer never sees those; a routine one is allowed, so no prompt: the commands Vikix's rules file lets out (`vikix snapshot` and the other `vikix` commands, `git` on the branch, `tests/run.sh`, `.claude/release`), under `timeout`, `env`, `nice`, a `VAR=value` or `bash -lc` as well, every command of the line one of them, nothing substituted into it (`$(...)`), no redirection but to `/dev/null`; any other step is left to you or the reviewer, and when it is yours the agent-waiting note says Codex *waits for your yes*. Three more hooks give the states: a turn begun (`UserPromptSubmit`) is noted in the journal, so a Codex thinking before its first tool call is *working*; its Stop hook asks a worker for its handoff as Claude Code's does and writes the plugin's *finished its turn* note with Codex's last words, and a stop let through is *at its prompt* until the next turn; its SessionEnd notes how it left (Codex gives no reason, so the record says *left*). The handoff's page says which of these a Codex at the desk has: its edits seen through the hook, or the hook file installed and none seen yet, or instructions only. Codex's session id reaches the record through the same hooks, so `vikix agents resume` finds its conversation without you typing it, in its rollout files or, from Codex 0.160, its thread store (`session_index.jsonl`, `thread_history_1.sqlite`, read only).

The hook notes an edit before it happens, so a note in the journal is a proposal; what actually changed is git's to say (`vikix agents` counts the uncommitted files, `vikix agents clash FILE` shows the diff). Nothing here resolves another agent's changes, answers its prompts, stops it or closes its desk: those are yours.

### What the rules don't do

A clash and a crossing stop nothing on their own: the one that decides is you, at Claude Code's prompt (OpenCode's plugin can only refuse or let through, so it refuses a clash once and lets the same edit through when tried again within ten minutes, the agent having told you). Only the desk rule refuses outright, and it names the way out. The rules hold for Claude Code, Antigravity CLI and Codex, and OpenCode's plugin holds the edit hook; Gemini CLI and Aider have no such hook, so a clash with one of them is seen afterwards, in `vikix agents` and `vikix agents clash`, not before the edit, and nothing keeps them off a project's own folder. Antigravity's hooks can't tell the agent something without deciding, so there a crossing asks you, with the reason, where Claude Code is told and goes on; its hook is a plugin of Vikix's that `vikix agent` puts in place (`agy plugin list` shows `vikix`), so it stays between sessions, and `agy plugin disable vikix` switches it off. A Claude Code session started before the update, or with `VIKIX_OFFICE=0 vikix agent`, has no hook either; one started before the desk rule has the edit hook but not the one on shell commands, since Claude Code reads its hooks at the start. A shell command that writes through a program the hook doesn't know (a Python script of the agent's own) passes. And they know files, not meaning: two agents editing different files of one feature are not a clash to them.

## From the agent's side

The Vikix skill tells every agent the same rules, so you can hold it to them: look at `vikix agents` before changing files in a folder another agent is in; take a desk before touching a repository (`vikix agents sit`), commit there on that branch and leave the project's own folder alone; read the handoff when joining a desk, and write it when handing work back, when blocked, and when done; when the work is merged, say so and let you close the desk, and once the desk is closed (by a release or by you) tell you so in its last message, with what remains for you to do; never stop, signal or type into another agent's window, and never answer a question another agent asked you. An agent with the MCP tools has `agents` to see the others, `handoff` and `handoff_update` for the desk's record, and `focus_window` to go to one, and the last is recorded as a crossing.

## Not there yet

A workspace and a bar colour each; handing a window from one agent to another; a permission list per agent. A foreman agent that writes plans for you to approve (never one that runs them). Gemini CLI's hook shape and its resume, tried on a machine that has them; a full day with the two providers on Vikix itself ([above](#a-day-with-the-two-providers)), and the mode for the other providers. Each will come as it is needed; the pieces that are here are the ones the first weeks with several agents asked for.

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

Above the desks, a **Plans** box when a plan has run or been written (`vikix agents plan`): a plan a group, its name, project and whether its runner runs, a line a desk saying where that desk's chain stands, and what needs you; a desk of a plan says which in its **Plan** line. A plan written and not run yet (`plan new`, or **New plan…**) is a *draft* there, with the tasks still holding the template's `EDIT:` lines under *Needs you*. Each plan ends with the acts its state takes, each `vikix agents plan` from the Office: **Run** for a draft whose words are written (**Run again** for one stopped or whose runner isn't running: it carries on), **Pause** and **Stop** while it runs, **Go on** when paused, **Edit**, which opens the plan's file in the desk pane (`RET` on a desk brings the pane back), and **Log**, what the runner did. A plan done, every desk of it released, leaves the box for the Archive page, where a **Plans done** box lists it with when it ended and its desks released, keeping **Edit** and **Log**; the Archive button counts the plans done apart from the records (*Archive (3, 1 plan)*).

The left side groups desks into **Needs you**, **Testing**, **Working** and **Finished**
on its first page, and **Parked** and **Closed** on a page of their own (the
**Parked and closed** button, or `K`; **Back to desks**, or `K` again, returns),
so the first page holds only the desks with something to do at them. A desk whose task has a record (*The work: tasks and their history*, above) carries its launch number before the project (`#104 · vikix · claude · workspace 2`), or *launch order unknown* for a task adopted from before the records, which had no number to keep; its page has a **Task record** box (the id, the origin and priority, the state the office recorded with why, the launch, the worker's state as observed with how sure, the times, *unknown* where the record never had one) and under it the task's history from the event log, newest first, the same lines `vikix agents task` prints. Each
group is drawn in a box of its own, a rule between its
desks. Beside the project, each live agent's name has its workspace clearly
labelled (`codex · workspace 2`); several agents each keep their own label.
An agent without a desktop window says so, and an unavailable workspace
says *workspace unknown*. A desk's lines are labelled rows (Task, Live,
Handoff, Next, Before); the desk
pane draws each of its sections (the task, what the agent says, the Git
state, the checks, the agents, the saved conversations) in a box the same
way, so neither pane reads as a wall of text. The box **What the agent
says** is the handoff as the agent wrote it, which Vikix doesn't check: the
status with what it means (*review · the agent asks you to look at its
work*), the estimate against the clock, the summary and the next step, then
the criteria, the decisions, the defects and the review findings as
bulleted lists, each row signed in the shade at its end with who wrote it
and when; a desk whose agent has written nothing yet says so in one line. The boxes are as wide as
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
a palette. A desk whose tests run (the tester, after a hand-in or **Test**) is
testing, whatever else it does, with **Skip tests** on its row; a waiting agent or a waiting/review handoff needs you, as does a
terminal waiting for `gup` or to be closed;
a live agent otherwise counts as working; a finished record whose desk
still stands counts as finished (it is yours to release or close); a desk
kept aside with `vikix agents park` (the status *parked*, by you or by its
agent) is parked, to be started later, and so are the
remaining desks, on the second page. A desk closed in the last day (`vikix agents
close`, or the release that removed it) is **Closed**, on the same page: newest first, its
row saying who closed it and when, nothing to do at it, and *Forget this
record…* in its details; after a day its record is in the Archive. When nothing
needs you and nothing is at work, the first page says that the desks are on
the parked page. Unavailable
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

Click **Archive** (or press `A`) to see historical tasks, handoffs and checks,
the third page, and above them the plans done. Archived entries say no action is needed; Go to agent, Continue and Close
agent are absent. Their old next actions are historical, not new instructions.
**Forget this record…** removes that one record after confirmation (as
`vikix agents handoff forget` does); its files, branch and saved
conversations stay. **Back to desks** (`A` again) returns to current work.
Each page's button counts that page's desks; the New desk, New plan and New project
buttons, the Releases box and the Plans box are the first page's alone, the Plans done box the Archive's.

**Purge archive** permanently deletes the archived desk records after
confirmation. It rechecks the exact records, worktree paths and live agents;
changed records, reopened desks or unavailable discovery require a refresh
and a new confirmation. Project files, branches and the providers' saved
conversations are untouched. There is no automatic age or size cutoff.

Click a desk, or use `n`/`p` to select it. `RET` enters its details; `C-x o`
moves between panes. Only available action buttons are shown. `Tab` visits buttons, `N` makes a new desk, `L` writes a new plan, `R` makes a new project, `w` starts a worker at the selected one, `a` goes to an agent, `c` continues
a desk, `P` pauses its agent or lets it go, `t` runs its tests, `s` skips them while they run, `r` has another provider review its last commit, `i` leaves its agent a note, `C` closes a desk, `h` opens this chapter of the manual, `g` refreshes and `q` closes the Office. A button's answer (*let go, paused 3 min; claude 48213 goes on at its next call*) stays in the header line over the refreshes that follow, until `g` or the next button, and the row is drawn again at once, so a desk let go loses its *paused by* and its Go button says Pause again. A row says when its desk is paused and by whom, when its tests run, who is reviewing it, and how many notes wait for its agent; the details say how the last agent left. An Office that shows no desk at all and a header line naming a *snapshot version* has a page older than its backend: Emacs loaded `vikix-office.el` before an update brought a newer `vikix agents office --json`. Load the file again (`M-x load-file ~/.local/share/vikix/emacs/vikix-office.el`) or restart Emacs. Details keep the user's task,
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

**New plan…** (`L`, above the groups) writes a plan from a template as a
form, drawn where the desk forms are, its own settings in a box with a
rule between them: the template (Vikix's and your own,
each with its line about itself; a click or `RET` on the `[choice]` opens
the list), the project (the repositories alone, since a plan's desks are
worktrees), the plan's name (a word: the file's name under
`~/.config/vikix/plans/`, and its desks'), workers at once and the gate
(empty, the template's). Nothing is picked for you. Once a template is
picked, its tasks come up as the form's fields, in order, each task in a
box of its own (closed again on the right as its fields grow) with a rule
between its parts: the task's name,
desk (`topic` becomes the plan's name) and the tasks it waits for, its
words, its release line (one line, what the release brings: what the
release's commit and tag say after the version, `Vikix 0.72.44: that
line`; for the last task at a desk, since a desk is released once, at its
chain's end), its acceptance lines, the agent and its switches (a local
model, may push, no tests) and the mode. A line the template asks you to
write (`EDIT:`) is the hint under an empty field, with an example after
*e.g.* that shows the shape; any other words of the template are the
field's, to edit. **Add a task** puts an empty task
after the rest and **Remove this task** takes one out, what you typed
staying. **Write plan** writes the file with your words in (`vikix agents
office --plan … --tasks`, the tasks as JSON on its stdin; the template's
head comment is kept, so the file still explains itself) and opens it in
the desk pane; the Plans box has it as a draft with its **Run**. A task's words left empty keep the template's `EDIT:` line, for
the file later, and the draft says so under *Needs you*. Nothing runs
until Run. A name taken, a task without a name or words, or a template
that doesn't read as a plan, is said in the form's own header line and
leaves the form open.

**New project…** (`R`, above the groups) makes a project from a form, drawn
where the other forms are: `vikix project new` with its words. The name (a
word: the folder under `~/src`, or the first `root=` of
`~/.config/vikix/projects`, and the repository's name), where it goes
(nothing is picked for you: *GitHub, public*; *GitHub, private*; *Here, a
repository*, a git repository on this machine alone; *A folder*, a folder
with a log and no git), the title (the log's heading and the README's;
empty, the name as words), a description (one line: the README's second
line and GitHub's About; for a repository) and the first step (the log's
*Next* line, which the New desk form then shows), and *Log apart*, which
keeps the log in `~/src/project-logs/NAME`, out of the repository, for a
public one whose log is yours. A repository gets a README, the log unless
apart, and one commit on your git's default branch (`main` when it says
nothing). On GitHub it is made by `gh` with the description as its About,
origin set as gh sets it, and pushed once through gh's login over HTTPS, so
your SSH key's passphrase is never asked for; the form says which account
gh is signed in as, and refuses the two GitHub choices, saying why, when
gh isn't installed, isn't signed in (`gh auth login`) or GitHub is out of
reach. The Office waits up to two and a half minutes for the push. The
backend's last line (the GitHub URL, or where the log is) is the Office's
header line, and the project is in the New desk form's list at once. A
name taken on GitHub, or a folder that has a log or is in a repository
already, is said in the form's own header line and leaves the form open;
a GitHub refusal leaves the repository here, with the `gh repo create`
line to run later.

**Guide** (`h`, above the groups) opens this chapter of the Vikix manual
(`info vikix`, the one `vikix update core` writes to
`~/.local/share/info/`) in the desk pane; `RET` on a desk brings the pane
back. Without the manual installed, the button says so.

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

## Needs attention and decisions

The Office starts with **Needs attention**: individual questions, permissions,
failed tests, reviews, releases, stopped workers, and uncertain activity.
Each item names its task and worker, says why it needs you, and shows how
long it has waited when that time is known. An idle terminal alone never
means a task is finished. Failed tests appear only while their result is
fresh and the worker is idle or gone. A review's Accept control requires
fresh passing tests, or the desk's explicit no-tests setting.

`vikix agents attention` prints the same list; `--json` exposes its records.
`Super+Alt+d` then `?`, or Super+m → AI → Agents: what needs you, opens its
menu. The Office refresh and `attention --notify` notify once per item,
including across Office restarts; a registered question notifies at once.
Read-only snapshots and the MCP `office` tool do not notify.

Workers register choices explicitly, so the question survives a restart:

```sh
vikix agents ask "Keep the old order?" \
  --choice "keep: compatible with existing scripts" \
  --choice "drop: simpler implementation" \
  --recommend keep --reason "Existing scripts still use it" \
  --context "The guide documents both orders" --blocks
```

There can be ten open questions per task. For an active task, `--blocks`
puts it in *needs decision*; a stopped task stays blocked. Without it, the
worker may continue independent work.
In the Office, **Answer…** (or `D` on a question or its desk) offers the
choices and **Other…** for your own words. No recommendation is submitted
without your choice. You can also run `vikix agents answer ID "your answer"`.
Agents cannot answer through the CLI or MCP. The free-text answer remains
text; it is never executed as a command.

An answer enters the task's inbox, which hooks deliver at the next call.
Providers without hooks can run `vikix agents ask --wait ID`: it waits up to
ten minutes, then exits 3 if still unanswered. `VIKIX_ASK_LIMIT` chooses a
shorter deadline in seconds. MCP `decide` registers a question and `decision`
reads it. The answer is retained in `office/decisions/ID.json`, even after
inbox delivery, and appears in handoff and resume. Answering the last
blocking question lets a waiting task run again; it never starts a process
or resumes a task blocked because its worker exited.

An inferred question has **Register decision…** to give it a record.
Permission requests stay in the worker's own approval interface; **Go to
agent** takes you there. **Accept review** marks work ready for release;
**Back to work…** leaves feedback in the inbox. **Release…** asks for a
summary and opens the project's release script in a terminal; it does not
push. Other items' **Desk** button opens the existing task controls.

A running task with an inferred or unknown worker state and no recent
activity becomes *uncertain* after 20 minutes. `quiet=MINUTES` in
`~/.config/vikix/office` changes that threshold. Unavailable discovery is
shown explicitly; missing evidence is not a claim that a worker stopped.
