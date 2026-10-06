# Agents at work

One agent is a terminal you talk to. Three or four at once are a small office: each needs a place to work, you need to see who is doing what, and when two reach for the same thing somebody has to say so. This page is how that office runs on Vikix: starting an agent, seeing them all, giving each a desk, and the house rules that hold when they meet. [Working with AI](ai.md) has the rest: which agents there are, keys and models, the desktop as tools.

Three habits carry the whole page:

1. **Start agents with Vikix**, `Super+a` or `vikix agent`, never plain `claude`: that is how they get a snapshot of your files, the Vikix skill, no API keys, and the house rules.
2. **One desk per piece of work**: `vikix agents desk PROJECT TOPIC`. No desk, no work: an agent off a desk is refused when it reaches for a project's files, and told how to sit down.
3. **`vikix agents` when you lose track.**

## One agent

`Super+a` opens a terminal with your agent in it (Claude Code, unless you chose another: `vikix agent --default codex`). Before the agent starts, Vikix takes a snapshot of your files, so afterwards:

```sh
vikix changes      # what the agent changed in your config, notes, dotfiles
vikix undo         # put it all back
```

The agent knows the desktop from the Vikix skill: ask it in words. *Make Firefox open on workspace 2. Why did this window float? Set the theme to paper.* It proposes rules rather than writing them, asks before it edits, and never gets your API keys or your SSH agent (see *What the agent doesn't get* in [Working with AI](ai.md)).

A second `Super+a` is a second agent, and so on. Nothing stops you; the rest of this page is what to do once you have several.

## Seeing them all

```
$ vikix agents
3 agents, 1 waiting for you:
  claude   ~/src/vikix-wifi (wifi, 2 uncommitted)      workspace 4   35 min      working
           ◑ Wi-Fi picker
  claude   ~/src/novel-chapter-3 (chapter-3, nothing uncommitted)  workspace 5   2 h 10 min  waits for your yes
           May I run the spell check over the whole book?
  codex    ~                                           workspace 2   12 min      running
```

A line an agent: which one; the folder it works in, with its branch and how many files wait uncommitted there; its workspace; how long it has run; and what it is doing. *Working* and *at its prompt* come from the mark Claude Code keeps at the front of its window's title; *waits for your yes*, *asked you something* and *finished its turn* from the agent-waiting plugin, when you have it ([Plugins](plugins.md)); under one that waits is what it asked. An agent whose shell is held by a release or by tests says so instead: *waiting for a release* (its release is in `.claude/release`'s queue, behind another's; under it, since when and behind which), *releasing* (what step the release is at), *waiting for a test slot* (its tests wait for one of the machine's `tests/run.sh` slots, other runs testing) or *testing*. An agent with no window of its own (one in Emacs, one on a text console) comes last, with where it runs.

The same list on the desktop: `Super+m` → *AI* → *Agents: who is running, and go to one*. Pick a line and you are on that agent's workspace, at its window. `vikix agents --json` is the list for a script, and the MCP tool `agents` gives it to an agent, so one agent can see the others.

Nothing here stops, signals or types into an agent: the list only reads what is there.

## A desk each

An agent started with `Super+a` sits in your home folder, and works wherever you send it. Two of them on one project then edit one working copy: git can't tell whose change is whose, one's half-written edit breaks the other's tests, and neither can commit cleanly. A desk gives each agent its own copy, on a workspace of its own:

```sh
vikix agents desk vikix wifi-fix
a desk for the agent: in ~/src/vikix-wifi-fix, a new worktree on the branch wifi-fix, on workspace 4
```

What happened: the first empty workspace (4) was taken; a git worktree of `~/src/vikix` was made beside it, `~/src/vikix-wifi-fix`, on a new branch `wifi-fix`; and a terminal opened there with your agent in it, the same way `Super+a` does. `Super+4` is now that agent. It commits on its branch, in its folder; `~/src/vikix` and every other desk stay as they are.

The project is any of `vikix project list`'s, by any part of its name (`vikix`, `novel`, `nov`). The topic is a word or two for the work: it becomes the folder's ending and the branch's name, so choose one that says what the agent is doing (`wifi-fix`, `chapter-3`, `typos`), not who (`agent-2`). A topic that gives no name for a branch is refused.

`Super+m` → *AI* → *Agents: start one on a project, at a desk of its own* asks for the project in a menu, then for the topic. Other forms:

```sh
vikix agents desk notes                # a project that is no repository: its own folder, a workspace to itself
vikix agents desk novel typos --here   # in this terminal, no new workspace
vikix agents desk novel typos --use codex
```

A desk that is already there is used again, never made twice: the second `vikix agents desk vikix wifi-fix` starts another agent in the same worktree (for a reviewer beside the writer). A project inside a collection (`books/novel`) gets its own folder inside the collection's worktree, `~/src/books-typos/novel`. A project that isn't a git repository has no worktrees: its agent works in the folder itself, and a topic isn't needed. A repository without a topic is refused: its own folder is for merging only, and no agent works there.

### No desk, no work

Desks only help if agents use them. So the rule, held by Claude Code's hook before every edit: **an agent changes a project's repository only from a desk, and never in the project's own folder.** An agent started with `Super+a` sits in your home folder; the moment it reaches for a file in `~/src/vikix` or `~/src/novel`, the edit is refused, and it reads why:

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

`vikix agents close` takes a desk down: its worktree is removed, and its branch deleted once the work is in. Name the desk by its topic, its branch, its folder, or as `PROJECT TOPIC`; with nothing named, `Super+m` → *AI* → *Agents: close a desk* (or the command on the desktop) asks which, and in a terminal without a desktop it lists them:

```sh
vikix agents close
The desks:
  ~/src/novel-chapter-3  (branch chapter-3, in; nothing uncommitted)
  ~/src/vikix-wifi-fix  (branch wifi-fix, not in main yet; 3 uncommitted; at work: claude 48213)
```

It refuses while an agent still works there (*claude 48213 still at work in ~/src/vikix-wifi-fix: let it finish, or close its terminal*) and while files wait uncommitted (*3 files uncommitted: commit there first, or --force throws them away*). A branch that isn't merged yet is kept, and the message says so: merge it, then `git branch -d` in the project, or `--force`, which throws the branch and its work away. The workspace the desk had is simply empty again.

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

### What the rules don't do

A clash and a crossing stop nothing on their own: the one that decides is you, at Claude Code's prompt. Only the desk rule refuses outright, and it names the way out. The rules hold for Claude Code and Antigravity CLI: Codex, Gemini CLI, OpenCode and Aider have no such hook, so a clash with one of them is seen afterwards, in `vikix agents` and `vikix agents clash`, not before the edit, and nothing keeps them off a project's own folder. Antigravity's hooks can't tell the agent something without deciding, so there a crossing asks you, with the reason, where Claude Code is told and goes on; its hook is a plugin of Vikix's that `vikix agent` puts in place (`agy plugin list` shows `vikix`), so it stays between sessions, and `agy plugin disable vikix` switches it off. A Claude Code session started before the update, or with `VIKIX_OFFICE=0 vikix agent`, has no hook either; one started before the desk rule has the edit hook but not the one on shell commands, since Claude Code reads its hooks at the start. A shell command that writes through a program the hook doesn't know (a Python script of the agent's own) passes. And they know files, not meaning: two agents editing different files of one feature are not a clash to them.

## From the agent's side

The Vikix skill tells every agent the same rules, so you can hold it to them: look at `vikix agents` before changing files in a folder another agent is in; take a desk before touching a repository (`vikix agents sit`), commit there on that branch and leave the project's own folder alone; when the work is merged, say so and let you close the desk; never stop, signal or type into another agent's window, and never answer a question another agent asked you. An agent with the MCP tools has `agents` to see the others and `focus_window` to go to one, and the second is recorded as a crossing.

## Not there yet

A workspace and a bar colour each; `vikix agents stop NAME`; handing a window from one agent to another; a permission list per agent; a key for the desk (the key card has no line left). Each will come as it is needed; the pieces that are here are the ones the first weeks with several agents asked for.
