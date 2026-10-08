# Agents at work

One agent is a terminal you talk to. Three or four at once are a small office: each needs a place to work, you need to see who is doing what, and when two reach for the same thing somebody has to say so. This page is how that office runs on Vikix: starting an agent, seeing them all, giving each a desk, and the house rules that hold when they meet. [Working with AI](ai.md) has the rest: which agents there are, keys and models, the desktop as tools.

Three habits carry the whole page:

1. **Start agents with Vikix**, `Super+a` or `vikix agent`, never plain `claude`: that is how they get a snapshot of your files, the Vikix skill, no API keys, and the house rules.
2. **One desk per piece of work**: `vikix agents desk PROJECT TOPIC`. No desk, no work: an agent off a desk is refused when it reaches for a project's files, and told how to sit down.
3. **`vikix agents` when you lose track.**

## One agent

`Super+a` asks *Agent here* or *Agent at a new desk*, then which agent; the first, with yours (Claude Code, unless you chose another: `vikix agent --default codex`), opens a terminal with it in your home folder (`vikix agents here`). Before the agent starts, Vikix takes a snapshot of your files, so afterwards:

```sh
vikix changes      # what the agent changed in your config, notes, dotfiles
vikix undo         # put it all back
```

The agent knows the desktop from the Vikix skill: ask it in words. *Make Firefox open on workspace 2. Why did this window float? Set the theme to paper.* It proposes rules rather than writing them, asks before it edits, and never gets your API keys or your SSH agent (see *What the agent doesn't get* in [Working with AI](ai.md)).

A second `Super+a`, *Agent here*, is a second agent, and so on. Nothing stops you; the rest of this page is what to do once you have several.

## Seeing them all

```
$ vikix agents
3 agents, 1 waiting for you:
  claude   ~/src/vikix-wifi (wifi, 2 uncommitted)      workspace 4   35 min      working
           wifi · Claude: ◑ Wi-Fi picker
  claude   ~/src/novel-chapter-3 (chapter-3, nothing uncommitted)  workspace 5   2 h 10 min  waits for your yes
           May I run the spell check over the whole book?
  codex    ~                                           workspace 2   12 min      running
```

A line an agent: which one; the folder it works in, with its branch and how many files wait uncommitted there; its workspace; how long it has run; and what it is doing. *Working* and *at its prompt* come from the mark Claude Code keeps at the front of its window's title; *waits for your yes*, *asked you something* and *finished its turn* from the agent-waiting plugin, when you have it ([Plugins](plugins.md)); under one that waits is what it asked, under the others the title the agent writes in its terminal, after the name its window has on the desktop when it is at a desk (`wifi · Claude`: see [A desk each](#a-desk-each)). An agent whose shell is held by a release or by tests says so instead: *waiting for a release* (its release is in `.claude/release`'s queue, behind another's; under it, since when and behind which), *releasing* (what step the release is at), *waiting for a test slot* (its tests wait for one of the machine's `tests/run.sh` slots, other runs testing) or *testing*. An agent with no window of its own (one in Emacs, one on a text console) comes last, with where it runs. A provider's program that is no session isn't listed at all: one run as a server (`codex app-server`, the daemon runit keeps; `claude mcp serve`; `opencode serve`), or one with no controlling terminal and no window here. A session in a terminal, in tmux, over ssh or in an Emacs terminal has a terminal; an adapter on pipes alone (ACP) has none.

The same list on the desktop: `Super+m` → *AI* → *Agents: who is running, and go to one*. Pick a line and you are on that agent's workspace, at its window. `vikix agents --json` is the list for a script, and the MCP tool `agents` gives it to an agent, so one agent can see the others.

Nothing here stops, signals or types into an agent: the list only reads what is there.

## A desk each

An agent started with `Super+a`, *Agent here*, sits in your home folder, and works wherever you send it. Two of them on one project then edit one working copy: git can't tell whose change is whose, one's half-written edit breaks the other's tests, and neither can commit cleanly. A desk gives each agent its own copy, on a workspace of its own:

```sh
vikix agents desk vikix wifi-fix
a desk for the agent: in ~/src/vikix-wifi-fix, a new worktree on the branch wifi-fix, on workspace 4
```

What happened: the first empty workspace (4) was taken (when all nine have windows, a new one named `wifi-fix` is made instead, reached with `Super+0` and gone again once it is left empty); a git worktree of `~/src/vikix` was made beside it, `~/src/vikix-wifi-fix`, on a new branch `wifi-fix`; and a terminal opened there with your agent in it, the same way `Super+a` does. `Super+4` is now that agent. It commits on its branch, in its folder; `~/src/vikix` and every other desk stay as they are.

The agent's terminal is named for its desk on the desktop: `wifi-fix · Claude`, the topic and the provider, in the title bar, the window list (`Super+g`), the overview and the palette, from the moment the agent is at the desk (started there, seated with `vikix agents sit`, or taken up again with `resume`) until it leaves. Two of one provider at a desk are `wifi-fix · Claude 1` and `wifi-fix · Claude 2`, each keeping its number while it runs; another provider at the same desk is `wifi-fix · Codex`. The title the agent itself writes (Claude Code's turning mark, which is how *working* and *at its prompt* are read) is kept apart, so nothing it does to its title changes the name, and nothing is lost: `vikix agents` shows both. A terminal whose agent has gone is plain again, or named for the next agent run in it, within half a minute; a terminal with no agent at a desk, and a name you gave a window yourself with StumpWM's `title` command, are left alone.

The project is any of `vikix project list`'s, by any part of its name (`vikix`, `novel`, `nov`). The topic is a word or two for the work: it becomes the folder's ending and the branch's name, so choose one that says what the agent is doing (`wifi-fix`, `chapter-3`, `typos`), not who (`agent-2`). A topic that gives no name for a branch is refused.

`Super+a`, *Agent at a new desk*, or `Super+Alt+d` then `n` (the desk keys: `Super+Alt+d` opens a small card of them, `n` a new desk, `r` take one up again, `c` close one, `h` its handoff, `o` the Office), or `Super+m` → *AI* → *Agents: start one on a project, at a desk of its own*, asks for the project in a menu, then for the topic, then for the task (in your words; it becomes the agent's first prompt, as `--task` does below, and Enter with nothing typed makes a desk with no task), then which agent: yours first, the others as `vikix agent --list` has them (one not installed yet is offered its installer in the terminal), and the ones that can run on a model on this laptop. Other forms:

```sh
vikix agents desk notes                # a project that is no repository: its own folder, a workspace to itself
vikix agents desk novel typos --here   # in this terminal, no new workspace
vikix agents desk novel typos --use codex
vikix agents desk novel typos --use antigravity
vikix agents desk novel typos --use aider --local   # on a model on this laptop
```

A desk that is already there is used again, never made twice: the second `vikix agents desk vikix wifi-fix` starts another agent in the same worktree (for a reviewer beside the writer). A project inside a collection (`books/novel`) gets its own folder inside the collection's worktree, `~/src/books-typos/novel`. A project that isn't a git repository has no worktrees: its agent works in the folder itself, and a topic isn't needed. A repository without a topic is refused: its own folder is for merging only, and no agent works there.

### No desk, no work

Desks only help if agents use them. So the rule, held by Claude Code's hook before every edit: **an agent changes a project's repository only from a desk, and never in the project's own folder.** An agent started with `Super+a`, *Agent here*, sits in your home folder; the moment it reaches for a file in `~/src/vikix` or `~/src/novel`, the edit is refused, and it reads why:

> Vikix office: ~/src/vikix/bin/vikix-wifi is in the project vikix, and you are not at a desk. An agent works on a repository only from a desk of its own, a worktree of it. Take one from here: run `vikix agents sit vikix TOPIC` (a word or two for the work; it makes ~/src/vikix-TOPIC on the branch TOPIC, or takes the one that is there, and seats you at it), then work in that folder and commit there. The project's own folder, ~/src/vikix, is for merging only.

The agent sits down by itself, with no restart:

```
$ vikix agents sit vikix wifi-fix
claude 48213 is seated at ~/src/vikix-wifi-fix: a new worktree on the branch wifi-fix. Work there (cd ~/src/vikix-wifi-fix) and commit there, on the branch wifi-fix; the house rules take that folder as yours now, and vikix agents shows you at it.
```

From then on the desk is that agent's: its edits there pass, `vikix agents` lists it at `~/src/vikix-wifi-fix (wifi-fix, 2 uncommitted)` with the branch and what waits there, and `vikix agents close` refuses the desk while it is seated. An agent that has a worktree already, made by hand or by Claude Code's own worktree support, sits at it with `vikix agents sit` and no more, run from inside it; an agent you started with `vikix agents desk` is at one from the start. A project that isn't a repository has no desks and no rule: the agent works in its folder.

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
vikix agents desk vikix wifi-fix       # workspace 4: "the Wi-Fi picker should scan first"
vikix agents desk vikix docs-pass      # workspace 5: "read docs/ for anything stale"
```

Tell each what to do on its own workspace. Each works in its worktree and, when done, finishes with the project's own release step (for Vikix, `.claude/release wifi-fix "..."`), which merges the branch and removes the worktree and the branch: the desk clears itself. `vikix agents` meanwhile shows `~/src/vikix-wifi-fix (wifi-fix, 3 uncommitted)` and `~/src/vikix-docs-pass (docs-pass, 1 uncommitted)`, so you can see at a glance who has what in hand.

### A book

```sh
vikix agents desk novel chapter-3
a desk for the agent: in ~/src/novel-chapter-3, a new worktree on the branch chapter-3, on workspace 5
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
  no filesystem enforcement: a worktree keeps copies apart, it is no sandbox
```

Three kinds of line, kept apart and each signed. The **task** is yours, in your words: `vikix agents desk vikix wifi-fix --task "..."` sets it as the desk is made and gives it to the agent as its first prompt, so the desk starts working at once (Claude Code, Codex, OpenCode, Gemini CLI and Antigravity CLI take one; Aider doesn't, and is told to read the record); or `vikix agents handoff set --task "..."` sets it later. The **handoff** is the agent's: a status (working, waiting, review, finished), an estimate, what it changed and decided, what is left and the very next action. The **estimate** is how long the work will take from the moment it is written, assuming no major issue turns up (`--estimate "40 min, if the picker needs no new test"`: a duration first, in minutes, hours or days, and what it assumes after a comma); an agent started with a task is asked for one as soon as it knows the shape of the work. The record and `vikix agents` count it down (*28 min left of 40 min*, *10 min over its 40 min*), and once the status is finished they say how it went (*finished in 45 min against 40 min, 5 min over*). The clock is the wall's, so time spent waiting for you counts, as it would for a person; an estimate written again starts it afresh. What **Vikix read itself** is the rest: the commit and the uncommitted files at each write, and for a check the commit it ran on and whether the tree was dirty then. A check is marked *stale* the moment the code differs from what it ran on, by another commit or other uncommitted changes, so an old green never passes for a new one. The sessions are the providers' conversation ids and nothing more: no transcript is copied, and a line that looks like a key or a token is refused outright.

The agent writes with the same command, or with the MCP tools `handoff` and `handoff_update`, whichever agent it is:

```sh
vikix agents handoff set --status working --estimate "40 min, if the picker needs no new test"
vikix agents handoff set --status review --summary "..." --next "..."
vikix agents handoff check "tests/run.sh wifi" --ok
vikix agents handoff session codex 01a111e5-…      # a conversation that can be resumed here
echo '{"status":"waiting","next":"needs the laptop"}' | vikix agents handoff set --from -
```

Claude Code's session id and Antigravity CLI's conversation id are noted by the hook itself; the others say theirs with `session`. `vikix agents handoff list` is every desk with a record, `vikix agents` shows each agent's desk status under its line, and `Super+m` → *AI* → *Agents: a desk's handoff* picks one. `vikix agents close` marks the record closed and keeps it, and so does a release that removes the desk (`.claude/release`), so a desk whose work is in shows as finished, not as waiting. A record no longer wanted, of a desk whose worktree is gone, is removed with `vikix agents handoff forget DESK` (the Office's Archive has the same, one record at a time, and *Purge archive* for all of them); without a desk named it lists the ones that could go. It refuses while the folder stands (close the desk instead) or an agent is still in it, and takes nothing else with it: no file, no branch, no saved conversation.

### Taking a desk up again

```
$ vikix agents resume wifi-fix
Desk ~/src/vikix-wifi-fix ...            (the handoff, as above)

resumed: claude session 0f1e2d3c-… at ~/src/vikix-wifi-fix, its conversation continues (its store has it)
on workspace 4
```

`vikix agents resume` shows the handoff, the git state and the checks' freshness, then starts an agent at the desk. When the record names a session and the provider's store still has it, that very conversation is resumed: `claude --resume ID`, `codex resume ID`, `opencode --session ID`, `agy --conversation ID`, each as its installed help says. Otherwise a fresh conversation starts, with the handoff on the terminal above it, and the line says why: no session noted, the provider's store lost it, or the provider can't resume one (Aider has no session ids; Gemini CLI's `--resume` is from its documentation, unverified here). When the provider's own store has a conversation for that folder which the record doesn't name, it is suggested, with the command that notes it, and never taken: nothing resumes the most recent conversation lying about, and nothing starts a second agent at a desk that has one (`--another` does, on purpose). `--fresh` asks for a new conversation, `--use codex` another provider, `--here` this terminal.

### A worker: a desk with a task

Give a desk a task and the agent at it is a worker: `vikix agents desk vikix wifi-fix --task "the Wi-Fi picker should scan first"`. The agent is started on the task, its first prompt, with where the desk's record is, so it opens on what the desk is for rather than at an empty prompt. The worker reports by construction. When its status comes to *review*, *waiting* or *finished*, a notification on the desktop says so, with its next step (never for a status that stayed, or for your own change). And a worker that ends a turn having changed files without writing its handoff is asked once, by Claude Code's Stop hook (`vikix agents stopping`, set by `vikix agent` with the house rules), to write it before it stops; the stop after that is let go, so nothing goes round, and a desk with no task, a session you are simply talking with, is never held to it.

A note for a worker at work: `vikix agents tell wifi-fix "try the laptop's second card too"`. It waits at the desk, shown by `vikix agents handoff` and counted under the agent's line in `vikix agents`, and the hook hands it to the agent at its next tool call, signed and timed, so nothing types into its window. An agent at its prompt makes no tool call until you speak to it, so `tell` says when that is so: the note waits on your next question to it, not on the hook. Only Claude Code's hook can carry words to the agent: for the others `tell` says so, the note stays in the handoff for the agent to read there, and `resume` reads the notes out to whichever agent takes the desk up. A note is text like the handoff's: a line that looks like a key is refused.

### Pausing a worker, and taking turns

`vikix agents pause wifi-fix` holds the worker: the next thing it does, an edit, a command or a read, waits in the hook with its context whole, costing nothing, until `vikix agents go wifi-fix`. The pause takes hold at that next call, not this instant, so a long think or a read finishes first. After ten minutes the waiting call is refused with why, the turn ends cleanly, and the worker says it is paused; `go` and your next words to it start it again. `vikix agents` and the Office show the desk as paused, by whom and since when. `--hard` freezes the agent's process this instant instead (SIGSTOP, found by its process descriptor, never by name) and `go` thaws it: for an agent with no hook, such as Aider, or an emergency, and said as such, since a request in flight may time out while frozen.

Two workers reaching for one file are stopped at your prompt, as the house rules say below. With `vikix agents turns wifi-fix on`, the worker at that desk waits instead: an edit of a file another agent has changed, uncommitted, waits for that agent's commit, up to ten minutes, and goes on with "your turn" when it comes, or asks you when it doesn't. A journal entry alone holds nobody: once the file is committed in the other's worktree, the turn is free. Two waiting for each other is seen, and the later one asks you at once. It is off by default, because silence is wrong for a session you are talking with; `turns off` puts the question back.

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

### What holds the rules, for each agent

`vikix agents hooks` says it plainly, and the handoff's last lines say it for the agents at a desk:

```
$ vikix agents hooks
claude    given to Claude Code by vikix agent at every start (--settings): pre-edit and pre-shell hooks
codex     PreToolUse hook in ~/.codex/hooks.json; Codex needs [features] hooks = true ... unverified on this machine
          not installed (vikix agents hooks codex --install links ~/.codex/hooks.json)
opencode  a plugin on tool.execute.before (edit, write, bash): a refused edit throws, with the reason ...
          not installed (vikix agents hooks opencode --install links ~/.config/opencode/plugins/vikix-office.js)
gemini    a BeforeTool hook to merge into ~/.gemini/settings.json by hand ... unverified here
antigravity a plugin of Vikix's that vikix agent installs with agy plugin install ...: pre-edit and pre-shell hooks
aider     no hooks: instructions only (the guide it reads), and git
```

Three levels, and the listing never claims more than there is. *Instructions only*: the agent has read the rules in its guide, and git shows afterwards what it did. *Pre-edit hooks*: the house rules run before each edit and shell command and can refuse it; Claude Code and Antigravity CLI have them from `vikix agent`, Codex and OpenCode get them from an adapter you install once (`--install` links a file of Vikix's into their folders and leaves a file of your own alone; Codex's hook shape and Gemini's are taken from their documentation and marked unverified until tried here). *Filesystem enforcement*: none. A worktree keeps copies apart, and the hook reads a shell command's words; neither is a sandbox, and the page doesn't call them one. A hook that a provider lacks keeps nothing else from working: the handoff and the resume are the same for every agent.

The hook notes an edit before it happens, so a note in the journal is a proposal; what actually changed is git's to say (`vikix agents` counts the uncommitted files, `vikix agents clash FILE` shows the diff). Nothing here resolves another agent's changes, answers its prompts, stops it or closes its desk: those are yours.

### What the rules don't do

A clash and a crossing stop nothing on their own: the one that decides is you, at Claude Code's prompt (OpenCode's plugin can only refuse or let through, so it refuses a clash once and lets the same edit through when tried again within ten minutes, the agent having told you). Only the desk rule refuses outright, and it names the way out. The rules hold for Claude Code and Antigravity CLI: Codex, Gemini CLI, OpenCode and Aider have no such hook, so a clash with one of them is seen afterwards, in `vikix agents` and `vikix agents clash`, not before the edit, and nothing keeps them off a project's own folder. Antigravity's hooks can't tell the agent something without deciding, so there a crossing asks you, with the reason, where Claude Code is told and goes on; its hook is a plugin of Vikix's that `vikix agent` puts in place (`agy plugin list` shows `vikix`), so it stays between sessions, and `agy plugin disable vikix` switches it off. A Claude Code session started before the update, or with `VIKIX_OFFICE=0 vikix agent`, has no hook either; one started before the desk rule has the edit hook but not the one on shell commands, since Claude Code reads its hooks at the start. A shell command that writes through a program the hook doesn't know (a Python script of the agent's own) passes. And they know files, not meaning: two agents editing different files of one feature are not a clash to them.

## From the agent's side

The Vikix skill tells every agent the same rules, so you can hold it to them: look at `vikix agents` before changing files in a folder another agent is in; take a desk before touching a repository (`vikix agents sit`), commit there on that branch and leave the project's own folder alone; read the handoff when joining a desk, and write it when handing work back, when blocked, and when done; when the work is merged, say so and let you close the desk, and once the desk is closed (by a release or by you) tell you so in its last message, with what remains for you to do; never stop, signal or type into another agent's window, and never answer a question another agent asked you. An agent with the MCP tools has `agents` to see the others, `handoff` and `handoff_update` for the desk's record, and `focus_window` to go to one, and the last is recorded as a crossing.

## Not there yet

A workspace and a bar colour each; a tester that runs a desk's tests on its hand-in, and dismissing an agent from the terminal (`DESIGN-workers.md`); handing a window from one agent to another; a permission list per agent. Gemini CLI's and Codex's hook shapes, and Gemini's resume, tried on a machine that has them. Each will come as it is needed; the pieces that are here are the ones the first weeks with several agents asked for.

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

The left side groups desks into **Needs you**, **Working**, **Parked** and
**Finished**, each group drawn in a box of its own, a rule between its
desks, and a desk's lines as labelled rows (Live, Handoff, Next); the desk
pane draws each of its sections (the task, the agent's claims, the Git
state, the checks, the agents, the saved conversations) in a box the same
way, so neither pane reads as a wall of text. The boxes are as wide as
their window and are drawn again when it is resized; a terminal that
can't show the box characters gets ASCII ones. The task is the title,
with project/topic as the fallback.
Each row distinguishes **Live** activity from the recorded **Handoff**,
counts down the agent's estimate while one stands, and shows the next
action. A waiting agent or a waiting/review handoff needs you;
a live agent otherwise counts as working; a finished/closed record without
an agent counts as finished; the remaining desks are parked. Unavailable
live discovery is **unknown**, never proof that an agent stopped. Desks
without handoffs still appear. A folder an agent merely runs in (one
started in `~`, or in a project's own folder) gets a row too, marked
**Not a desk**: its title is the folder, its details name the agents
running there, and Go to agent and Close agent work as on a desk. It has
no Git state, no handoff and no Continue, since there is no desk to
continue; `vikix agents sit PROJECT TOPIC` from the agent's own shell
seats it at one. Removed worktrees with no live agent go into
**Archive**, separate from current desks. A handoff saying "finished" alone
does not archive an existing desk or remove any files.

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

Click a task, or use `n`/`p` to select it. `RET` enters its details; `C-x o`
moves between panes. Only available action buttons are shown. `Tab` visits buttons, `a` goes to an agent, `c` continues
a desk, `g` refreshes and `q` closes the Office. Details keep the user's task,
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
the same snapshot to scripts, including discovery errors; the read-only MCP
tool `office` returns it too. It is a view of
existing desks and handoffs, not another task store.
