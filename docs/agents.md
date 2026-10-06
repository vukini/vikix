# Agents at work

One agent is a terminal you talk to. Three or four at once are a small office: each needs a place to work, you need to see who is doing what, and when two reach for the same thing somebody has to say so. This page is how that office runs on Vikix: starting an agent, seeing them all, giving each a desk, and the house rules that hold when they meet. [Working with AI](ai.md) has the rest: which agents there are, keys and models, the desktop as tools.

Three habits carry the whole page:

1. **Start agents with Vikix**, `Super+a` or `vikix agent`, never plain `claude`: that is how they get a snapshot of your files, the Vikix skill, no API keys, and the house rules.
2. **One desk per piece of work**: `vikix agents desk PROJECT TOPIC`.
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

A line an agent: which one; the folder it works in, with its branch and how many files wait uncommitted there; its workspace; how long it has run; and what it is doing. *Working* and *at its prompt* come from the mark Claude Code keeps at the front of its window's title; *waits for your yes*, *asked you something* and *finished its turn* from the agent-waiting plugin, when you have it ([Plugins](plugins.md)); under one that waits is what it asked. An agent with no window of its own (one in Emacs, one on a text console) comes last, with where it runs.

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
vikix agents desk novel                # no topic: the project's own folder, a workspace to itself
vikix agents desk novel typos --here   # in this terminal, no new workspace
vikix agents desk novel typos --use codex
```

A desk that is already there is used again, never made twice: the second `vikix agents desk vikix wifi-fix` starts another agent in the same worktree (for a reviewer beside the writer). A project inside a collection (`books/novel`) gets its own folder inside the collection's worktree, `~/src/books-typos/novel`. A project that isn't a git repository has no worktrees: its agent works in the folder itself.

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
cd ~/src/novel && git merge chapter-3                     # the work comes in
git worktree remove ~/src/novel-chapter-3 && git branch -d chapter-3   # the desk goes
```

Or tell the agent: *merge your branch into main and remove your desk*; the skill tells it how. A project with no release step of its own needs these two lines from somebody: Vikix doesn't yet remove a desk by itself.

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

They don't stop anything on their own: the one that decides is you, at Claude Code's prompt. They hold only for Claude Code: Codex, Gemini and Aider have no such hook, so a clash with one of them is seen afterwards, in `vikix agents` and `vikix agents clash`, not before the edit. A session started before the update, or with `VIKIX_OFFICE=0 vikix agent`, has no hook either. And they know files, not meaning: two agents editing different files of one feature are not a clash to them.

## From the agent's side

The Vikix skill tells every agent the same rules, so you can hold it to them: look at `vikix agents` before changing files in a folder another agent is in; at a desk, commit there on that branch and leave the project's own folder alone; when the work is merged, remove the desk; never stop, signal or type into another agent's window, and never answer a question another agent asked you. An agent with the MCP tools has `agents` to see the others and `focus_window` to go to one, and the second is recorded as a crossing.

## Not there yet

A workspace and a bar colour each; `vikix agents stop NAME`; handing a window from one agent to another; a permission list per agent; a key for the desk (the key card has no line left). Each will come as it is needed; the pieces that are here are the ones the first weeks with several agents asked for.
