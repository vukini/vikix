# Working with AI

Vikix gives you these ways to use AI, from the most capable to the most private:

| | What it is | What it needs | Where your words go |
|---|---|---|---|
| **The agent** | Claude Code (or another agent), in a terminal, able to change the desktop for you | A Claude account (Pro or Max), or an Anthropic API key; others need their own | Anthropic, or the agent's company; nowhere with `--local` |
| **Local models** | A model that runs on this laptop, to chat with | `vikix ai setup`, and a few GB of disk | Nowhere: it all stays here |
| **`llm`** | One command for any model, fed from a pipe | `vikix ai llm`, and a local model or a key | Here, or to the model's company |
| **Super+i** | Proofread, rewrite, translate, explain or ask about the text you selected, in any program | `vikix ai llm`, and a local model (or Claude, if you choose) | Here, unless you choose Claude |
| **Super+F9** | Speak, and it types what you said, in any program | `vikix add dictation` (a few minutes, once) | Nowhere: it all stays here |
| **Super+F10, Super+F11** | Talk to the AI or the agent, and it answers aloud | `vikix add voice` (a minute, once) | As Super+i's, or the agent's; the listening and the voice stay here |
| **In Neovim** | A chat about your code, and your agent in a side window (`Space A`) | `vikix add neovim`, and a local model, a key or an agent | As Super+i's, or the agent's |
| **In Emacs** | The same, with gptel (`C-c g`) and agent-shell (`C-c a`) | `vikix add emacs`, and a local model, a key or an agent | As Super+i's, or the agent's |
| **`note`** | Questions answered from your own notes, an Obsidian vault say, in any terminal | `vikix add notes` (it brings local AI) | Nowhere with a local model; to Anthropic, only the passages found, with Claude |
| **`~/dev/ai`** | Small programs of your own that call Claude or a local model, and one that answers from your notes | `vikix add python`, and a key or a local model | Here, or to Anthropic when you run the Claude ones |

You can use any of them, all of them, or none. Nothing AI runs until you start it.

## The agent

An agent is an AI that does things, not only talks about them. Claude Code reads files, runs commands and edits your settings, and it knows how Vikix is put together, so you can ask for a change in plain words.

### Starting it

Press **Super+a**. It asks: *Agent here*, or *Agent at a new desk*; then which agent: yours first (Claude Code, unless you chose another: [Another agent](#another-agent), below), the others, and the ones that can run on a model on this laptop. Enter twice, or `a` in a terminal, opens a terminal with your agent in it. The second choice is for an agent on a project, with a copy of the repository to itself; it asks for the project, a topic, the task and which agent: [Agents](agents.md#a-desk-each) says when you want that.

The first time, it offers to install Claude Code (with Anthropic's installer, into `~/.local/bin`), then asks you to log in. Log in with your Claude account: the agent then uses your plan. If you'd rather pay per use with an API key, see [API keys](#api-keys) below.

Type what you want and press Return. `/exit` or Ctrl+D leaves.

### What to ask it

Anything about this desktop, in your own words. For example:

- "Make Super+t open a second terminal."
- "Switch to the light theme, and make the terminal font bigger."
- "Start Firefox and Emacs on workspace 2 when I log in."
- "Why is the Wi-Fi not connecting? Look at the logs."
- "Install GIMP, and put it in the launcher."
- "What does the key Super+g do?"

It isn't limited to the desktop: it can write and run code in `~/dev`, explain an error, or tidy a folder.

### How it knows what to do

- **A guide for the agent.** Vikix installs a skill in `~/.claude/skills/vikix`: where every file is, which ones are yours to change, the keys, and the `vikix` commands. Its first page is short (the rules that always hold); the rest is a page a subject, which the agent reads when it needs it. Its main rule is the one in [Where everything is](map.md): change your files, never Vikix's.
- **It can try before it writes.** `vikix eval` runs Lisp in the running window manager, so the agent can try a key or a colour on the live desktop, see that it works, and only then save it in `~/.stumpwm.d/user.lisp`.
- **It asks first.** By default Claude Code shows each command and each edit and waits for your yes. You can let it do more on its own; its `/permissions` command shows what it may do without asking.

### Taking a change back

Before every session, Vikix saves a snapshot of your settings. The terminal says so in its first lines:

```
:: snapshot 99e03a6: before an agent session (claude)
:: to see what the agent changed: vikix changes    to take it back: vikix undo
```

So after a session:

```sh
vikix changes      # what the agent changed in your files
vikix undo         # put them back as they were before it started
vikix undo         # again: take the undo back
vikix history      # every snapshot, newest first
```

In a terminal, `vikix undo` first lists the files it would change and asks. Answer no when the snapshot one back isn't the one you meant (an agent started from an editor takes one too), and pick one from `vikix history` with `vikix undo ID`. This covers your settings (the files in `~/vikix/config/yours.list`), not everything in your home folder. For your work, keep backups: [README: Backups](../README.md#backups).

### Another agent

Claude Code isn't the only one. Five others work the same way, with the same snapshot first and the same guide:

| Agent | Signs in with | Can run on this laptop |
|---|---|---|
| **OpenCode** | Any model company you have an account with | Yes |
| **Codex** (OpenAI) | Your ChatGPT account | Yes |
| **Antigravity CLI** (Google, `agy`) | Your Google account (free, AI Pro or AI Ultra), or a Gemini API key | No |
| **Gemini CLI** (Google) | A Gemini API key, or a Code Assist licence from work | No |
| **Aider** | An API key (`vikix ai key set anthropic`) | Yes |

```sh
vikix agent --list                # which are installed, and which Super+a starts
vikix agent --use opencode        # try one: it offers to install it first
vikix agent --default opencode    # make Super+a start it
vikix agent --default claude      # back to Claude Code
vikix add codex                   # or install one as a feature (vikix remove codex takes it away)
```

**Which one?** Claude Code is the one Vikix is made with and tested with. OpenCode or Aider if you want to work offline. With a Google account, Antigravity CLI: in June 2026 Gemini CLI stopped serving personal accounts (the free tier, AI Pro and AI Ultra) and sent them there; Gemini CLI stays for a Gemini API key (`vikix ai key set gemini`, then `VIKIX_AGENT_API_KEY=1 vikix agent --use gemini`, since keys are kept from agents) or a Code Assist Standard or Enterprise licence.

**Antigravity CLI** is installed from the release Vikix has pinned and checked (its SHA-512 is in `vikix agent`), not with Google's installer, which would write a PATH line into your `.bashrc`, `.profile` and `.bash_profile`; `~/.local/bin` is on your PATH already. An `agy` that Google's installer put there is found and left as it is. At its first start it signs you in in your browser and keeps the sign-in in the system keyring (`/logout` in it drops it); to use a Gemini API key instead, set `"modelProvider": "gemini"` in `~/.gemini/antigravity-cli/settings.json`, and Vikix then lets that one key through. From then on `agy` updates itself in the background (`AGY_CLI_DISABLE_AUTO_UPDATE=true` stops that). It has no local models and doesn't speak ACP. `agy -c` picks up the last conversation in this folder: `vikix agent --use antigravity -c`. It can work at a desk of its own (`vikix agents desk PROJECT TOPIC --use antigravity`); its conversation id is recorded on handoff automatically, and `vikix agents resume DESK` picks that conversation back up (`agy --conversation ID`). `vikix mcp register` adds the desktop's MCP tools to it (`agy mcp add vikix -- ...`).

**Always through Vikix:** start them with `vikix agent --use NAME` (or Super+a), not by typing `codex` or `opencode`: that skips the snapshot, and the protections below.

**From an editor:** an editor that starts an agent itself should run `vikix agent --exec NAME` and the agent's own options after it, or `vikix agent --exec` for yours. It's the same start, with the same protections, but quiet: nothing of Vikix's in the agent's output, and no questions. Editors that speak ACP, the Agent Client Protocol (Neovim's CodeCompanion, below; Emacs's agent-shell; Zed), run `vikix agent --acp NAME`: Gemini CLI and OpenCode speak it themselves, and Claude Code and Codex need a small adapter, which `vikix agent --install claude` (or `codex`) puts next to them. It uses the agent you have, and your login. It needs Node 22 or newer, which `vikix add neovim` brings. Aider and Antigravity CLI don't speak ACP. `vikix agent --which` says which agent is yours, and `vikix ai use` which model Super+i uses.

**Offline**, on a local model: `vikix agent --use opencode --local` (or codex, or aider; `--model NAME` picks one). It picks the best of your models for code. Be warned: on a laptop's CPU each answer takes minutes (Aider on llama3.2:3b took over four minutes for one sentence), and a small model rarely carries out a change on its own. A bigger model (`vikix ai models`) does more, more slowly still.

**What an agent doesn't get**, so that a trick hidden in a web page or a file it reads can't use it:

- **Your API keys**, and other secrets in the environment (passwords, tokens): each agent signs in its own way, so a key isn't billed without you knowing. Aider can't sign in, so it gets the model companies' keys (Anthropic, OpenAI, Google, OpenRouter, DeepSeek, Mistral, Groq, xAI), and no others. A shell the agent opens doesn't read them back either.
- **Your SSH agent.** After your first `git push` of the day, it holds your unlocked key: an agent with it could push, as you, to anything you can. If you want the agent to push for you: `VIKIX_AGENT_SSH=1 vikix agent`; at a desk, the picker asks (the last question, no unless you say yes), or `vikix agents desk PROJECT TOPIC --push`.

This prevents accidents; it isn't a wall. The agent runs as you, and can read your files. OpenCode is set to ask before it runs a command or edits a file, as Claude Code does, unless your own OpenCode settings say otherwise.

**How they know Vikix:** OpenCode reads the same skill as Claude Code. Codex, Gemini, Antigravity and Aider read `~/.local/share/vikix/AGENTS.md`, the skill's first page, which names the other pages where they can open them: Vikix links it as `~/.codex/AGENTS.md`, writes a one-line `~/.gemini/GEMINI.md` that imports it, writes a rule file of its own for Antigravity, `~/.gemini/antigravity-cli/rules/vikix.md`, that includes it (Antigravity reads every rule there), and hands it to Aider (not to a small local model, for which it's too long). If you have one of those files already, it's yours and stays; Vikix says how to add the guide to it.

**The house rules** (`vikix agents touch`, [Agents at work](agents.md)) reach Claude Code and Antigravity CLI: Claude Code gets the hook for the session, Antigravity as a plugin of Vikix's that stays (`agy plugin list` shows `vikix`; `agy plugin disable vikix` switches it off).

### Several at once

Agents run side by side, each in a terminal of its own, and a row of windows all called "Alacritty" doesn't say which is which. `vikix agents` (and `Super+m` → *AI* → *Agents: who is running, and go to one*) lists them: which agent, its folder with branch and uncommitted files, its workspace, how long, and what it is doing. `vikix agents desk PROJECT TOPIC` gives an agent a desk of its own, a workspace and a git worktree, and the house rules say what happens when two agents reach for one file. All of it, with examples, is its own page: [Agents at work](agents.md).

## API keys

Programs find an API key in a variable such as `ANTHROPIC_API_KEY`. Don't put it in `~/.bashrc`: that file's history keeps every version for ever. Vikix has a safe place instead:

```sh
vikix ai key set anthropic     # paste the key; it isn't shown
vikix ai key list              # the names, and a short fingerprint, never the key
vikix ai key remove anthropic
```

Other names work too: `openai`, `gemini`, `openrouter`, `mistral`, `groq`, `github`, and more (`vikix ai help` lists them).

- **Every new terminal** has the key from then on. A terminal that was already open gets it after `exec bash`; programs the desktop starts get it at the next login.
- **Super+a doesn't use it.** The agent uses your Claude login and plan, not the key, so you're not billed twice. To bill the agent to the key instead: `VIKIX_AGENT_API_KEY=1 vikix agent`.
- **Never type a key on the command line** (`vikix ai key set sk-ant-...`): it would stay in your shell's history. `set` refuses it and tells you how to clear it.
- **`vikix doctor`** looks for keys left in the wrong place, such as `~/.bashrc`, and says how to move them.

The keys are kept in `~/.config/vikix/secrets/`, which only you can read. The [README](../README.md#api-keys) has the details.

## Local models

A local model runs on this laptop: no account, no cost, and nothing leaves the machine. It's smaller and slower than Claude, but good for questions, writing and small bits of code, and it works offline.

### Getting a model

```sh
vikix ai setup       # once: installs Ollama, about 100 MB, no password needed
vikix ai models      # choose a model to download
```

`vikix add local-ai` does the same as `vikix ai setup`, and `vikix remove local-ai` the same as `vikix ai uninstall`: local AI is one of the features.

`vikix ai models` (or **Super+m** → *Local AI: choose a model*) looks at this laptop's memory and says how each model will run here: fast, well, or slowly. Bigger ones it doesn't offer. Good first choices:

- `llama3.2:3b` (2 GB), for questions and writing
- `qwen2.5-coder:3b` (1.9 GB), for code

On a laptop without a graphics card, a 3B model takes a few seconds to load, then about ten seconds to write a couple of sentences.

### Talking to it

```sh
vikix ai chat        # talk to it; /bye or Ctrl+D leaves
```

Or **Super+m** → *Local AI: talk to a model*.

While a model is loaded, the bar says **ai**. It holds a few GB of memory, and lets go of it after five minutes unused. To free it now: `vikix ai stop`, or **Super+m** → *Local AI: unload the model*.

### Keeping track

```sh
vikix ai status      # running? which model is loaded, and for how long
vikix ai list        # the models you have
vikix ai remove llama3.2:3b
vikix ai uninstall   # take Ollama away (add --models to delete the models too)
```

The models are in `~/.ollama/models`. They're big, so backups leave them out; you can download them again.

## `llm` on the command line

`llm` sends text to a model and prints the answer, so it fits in a pipe with other commands. The same command works with a local model and with Claude.

```sh
vikix ai llm                               # once: install it (or vikix add llm)
cat notes.md | llm "summarise this"
git diff | llm "write the commit message"
llm "what does chmod 750 mean?"
llm -m llama3.2:3b "..."                   # a local model, by name
llm -m claude-sonnet-5 "..."               # Claude, with your API key
```

Its default model is a local one if you have one, otherwise Claude if you've set an Anthropic key. To choose: `vikix ai llm --default MODEL`.

Everything you ask is logged: `llm logs -n 5` shows the last five, and `llm logs off` stops the logging.

## Asking your notes: `note`

`note` answers questions from a folder of Markdown, an Obsidian vault say, in any terminal. `vikix add notes` installs it (and local AI, which it needs), then:

```sh
note index ~/General --skip Admin,Readwise   # the first time: about five minutes a thousand notes
note ask "what did I write about runit?"     # the answer, and the notes it came from
note index                                   # after changes, from anywhere: only what changed
```

`note find "..."` lists the nearest notes without an answer, and `note status` shows the folder, the index and who answers.

It works in two steps. `note index` cuts each note into passages at its headings and turns each into an embedding, a list of numbers standing for its meaning, with a small model on the laptop. `note ask` does the same with the question, takes the six nearest passages, and has a model answer from them alone, naming the notes. The list of notes printed under each answer lets you check it: a small local model sometimes answers from the wrong one.

Who answers follows Super+i (`vikix ai use local` or `claude`); `note ask --claude` or `--local` chooses for one question. Locally, nothing leaves the laptop. With Claude, the six passages found, never the whole folder, go to Anthropic, and the answers are much better. Folders you'd never send anywhere, leave out with `--skip`: they're never even read. Hidden files and folders (`.obsidian`, the `.#note.md` Emacs leaves while a note is unsaved) never are either.

Your choices are in `~/.config/vikix/notes`: `folder=`, `skip=`, and `embed=`, the embedding model. `nomic-embed-text` (after `ollama pull nomic-embed-text`) finds better passages than all-minilm but is slower; changing it reads every note again. The index is `~/.local/share/vikix/notes/index.db`, in a folder only you can read; `vikix notes uninstall --index` deletes it.

## Your own programs: `~/dev/ai`

To see how the rest works, or to build something of your own, `~/dev/ai` has four small programs to read, run and change. Each has a README and `make run`:

| Example | What it shows | What it needs |
|---|---|---|
| `claude` | One question to Claude: `ask.py` with Anthropic's Python library, `ask.sh` with curl and jq, one HTTP request | An Anthropic key (`vikix ai key set anthropic`) |
| `local` | The same question to a model on the laptop, through Ollama's API | `vikix add local-ai` and a model |
| `embeddings` | Sentences turned into numbers, kept in SQLite (sqlite-vec), the nearest to a question found by meaning | Ollama, and `make setup` (all-minilm, 46 MB) |
| `ask-notes` | A folder of Markdown notes, searched and answered from | The same, and a model to answer (or a key) |

`ask-notes` is `note` made small, to read and change; for everyday use, `note` is the one. It works on your own notes too:

```sh
cd ~/dev/ai/examples/ask-notes
make setup                                          # once
make index NOTES=~/General SKIP=Admin,Readwise      # about five minutes a thousand notes; later, only what changed
make ask QUESTION="What did I write about runit?"   # the local model answers, naming the notes
make ask QUESTION="..." CLAUDE=1                    # Claude answers: those six passages go to Anthropic
```

The index, `notes.db`, stays in that folder and holds passages from your notes: `make clean` deletes it. Hidden files and folders (`.obsidian`, the `.#note.md` Emacs leaves while a note is unsaved) are never read, and `SKIP` leaves out the ones you'd never send anywhere.

The small models are quick but miss things: all-minilm sometimes ranks the wrong note first, and a 3B model answers from whatever it's given. Each answer lists the notes it was given, so you can check. `EMBED_MODEL=nomic-embed-text` (after `ollama pull nomic-embed-text`, then index again) finds better passages, and `CLAUDE=1` answers better.

The Python ones name their libraries at their top, pinned (`# /// script`), and `uv run` fetches them the first time, so nothing is installed for the whole machine.

## AI on the selected text

Select some text anywhere, in a web page, an email, a terminal, and press **Super+i**. A menu asks what to do with it:

| Choice | What you get |
|---|---|
| Ask about it | Type a question about the text (or select nothing, and ask anything) |
| Proofread | The text with its mistakes fixed, on the clipboard |
| Rewrite: clearer | The same thing said more clearly, on the clipboard |
| Translate | Into the language you pick, on the clipboard |
| Explain | What it means; for an error message, how to fix it |

What goes on the clipboard is also shown in a notification; paste it where you want it. Proofread also lists what it changed: small models sometimes "correct" what was right. A short answer comes as a notification, a longer one in a terminal (`q` closes it). The text is what you last highlighted, even if it's no longer highlighted on screen; only when there's none does it use what you copied. The notification while it works shows the start of the text it took.

It needs `llm` (`vikix ai llm`) and a local model. A small one takes some seconds: about 10 for a sentence to proofread or explain.

### Local or Claude

To switch, pick *Use Claude instead* (or *Use the local model instead*) at the end of the Super+i menu, or type `vikix ai use claude` or `vikix ai use local`. A third choice, Codex, is below. The choice is kept in `~/.config/vikix/ai`, which starts as:

```sh
use=local          # free, offline, the text stays on this laptop
model=             # empty: llama3.2:3b, or your first local model
languages=English Esperanto French Spanish Arabic Hindi
```

For better answers, above all translations into Esperanto, which small models get wrong, use Claude. Then each use costs a little and the text you selected goes to Anthropic, so it needs your key first: `vikix ai key set anthropic`. Super+i never switches to Claude by itself, and its menu always names the model and where the text goes.

### Codex

If you have Codex (`vikix add codex`) and are signed in (`codex login`), it can answer Super+i too: `vikix ai use codex`, or *Use Codex instead* at the end of the menu. It uses Codex's own sign-in, your ChatGPT account, so it needs no key, and the text you selected goes to OpenAI. The model is the one Codex is set to (`~/.codex/config.toml`), or the one `model=` names. An answer takes some ten seconds.

For quicker answers, name a faster model and a lower effort (how hard it thinks) in `~/.config/vikix/ai`. They hold for Super+i and Super+F10 only, so Codex in a terminal stays as you set it:

```sh
use=codex
model=gpt-6-luna   # Codex's /model lists them
effort=low         # low, medium or high; empty: Codex's own setting
```

That brings an answer down to five or six seconds, and not much lower: every answer carries Codex's own instructions with it. `model=` is one line for all three choices, so empty it before `vikix ai use claude` or `local`; `effort=` is Codex's alone.

Codex is an agent, not a chat model: by itself it runs commands, searches the web and reaches the apps connected to your ChatGPT account, such as mail and GitHub. The text you select can come from any page, and a page can hold a line written for an agent. So Super+i asks Codex with all of that switched off, read-only, in an empty folder, and keeps nothing of the session: such a line finds nothing to act with. If a later Codex no longer knows one of those switches, Super+i says so and gives no answer, until `vikix update` brings the new list.

Super+F10 follows, one question at a time: Codex doesn't carry the conversation on. The editors' chats and `note` know only local and Claude, and stay on the local model while Super+i is on Codex.

## AI in Neovim

Vikix's Neovim has [CodeCompanion](https://codecompanion.olimorris.dev), under **Space A**:

| Keys | What they do |
|---|---|
| `Space A c` | A chat beside your code, on the model Super+i uses: a local one, or Claude |
| `Space A q` | Ask about the selection (or the file), or ask for a change to it |
| `Space A a` | Add the selection to the chat |
| `Space A g` | A chat with your agent (the one Super+a starts), which can read and change your files |
| `Space A t` | Your agent in a terminal inside Neovim |
| `Space A p` | Everything else CodeCompanion does |

The chat follows `vikix ai use`: `local` (a model on this laptop, `vikix ai setup` first) or `claude` (your key: `vikix ai key set anthropic`). A model set with `model=` in `~/.config/vikix/ai` is used here too. On a laptop's CPU, a local model's first answer takes minutes, because it reads CodeCompanion's instructions first; Claude answers in seconds. The chat's top line says who answers, before you type: the model, and whether it's on this laptop or sent to Anthropic (or which agent). In the chat, `ga` changes the model or the agent for that chat.

The agent in `Space A g` is started by `vikix agent --acp`, so it's the same as Super+a's: the guide, no API keys, and a snapshot first, so `vikix changes` shows what it did and `vikix undo` takes it back. It signs in with its own login, the one it uses in a terminal. Claude Code and Codex need their adapter, which `vikix agent --install claude` adds (running it again for an agent you have only adds what's missing). `Space A t` runs `vikix agent` itself, so Aider works there too.

Nothing starts or connects until you press a key. When something's missing (a key, Ollama, the agent or its adapter), the key says what to type, and does nothing else.

## AI in Emacs

Emacs's config has [gptel](https://github.com/karthink/gptel) for the chat and [agent-shell](https://github.com/xenodium/agent-shell) for your agent, and Vikix sets both up:

| Keys | What they do |
|---|---|
| `C-c g` | A chat, on the model Super+i uses: a local one, or Claude. With a selection, the chat starts from it |
| `C-c G` | gptel's menu: another model for this chat, and what to send. Claude and your local models come first; one of the config's own (OpenAI, Perplexity) shows only when its key is there |
| `C-c a` | A chat with your agent (the one Super+a starts), which can read and change your files. It goes back to this project's chat when there is one; from a folder without one, it asks (*New shell* starts one here; the others go to a chat in another folder). `C-u C-c a` always starts a new one |
| `C-c A` | Your agent in a terminal inside Emacs |

The chat follows `vikix ai use` and `model=`, as Neovim's does, and Emacs reads them again at each `C-c g`, so a change reaches an Emacs that's already open. A model you pick in the menu stays until you change that file. The agent starts through `vikix agent --acp`, with the same rules as in Neovim, above; `C-c A` runs `vikix agent` itself, so Aider works there too. When something's missing, the key says what to type. [Neovim and Emacs](editors.md) compares the two.

## The desktop as tools (MCP)

MCP is how an AI agent is given tools of its own. `vikix mcp register` gives your agent a fixed set of them for this desktop, so it can look at it and make small changes without writing commands.

Why, when the agent can run commands anyway? Each command needs your yes. These tools are few, checked, and easy to take back, so you can allow them once: in Claude Code, answer "always allow" for a vikix tool (or allow `mcp__vikix__*`). Then the agent looks at the desktop and switches a theme or a window without asking each time, while every other command still asks.

```sh
vikix mcp register     # for Claude Code and Antigravity CLI, then restart them; it prints the lines for Codex, Gemini CLI and OpenCode
vikix mcp status       # is it on, with which tools, the servers running (and their version), the last calls
vikix mcp tools        # what it offers
vikix mcp unregister   # take it away
```

| Tool | What it does |
|---|---|
| desktop | The workspaces and their windows (a [strip](strip.md)'s columns too, in order), the screens, the theme |
| keys | Every key Vikix binds, and what it does |
| rules | The desktop's rules (each one's number, on or off, where it's written, how often it ran), and for a window you name, which rules ran for it and which match it but haven't. Nothing is switched or run |
| why | What the desktop did lately and what made it: a key and its command, a rule and its window, the menu, an agent; each with where it is written. For "why did my window move?" |
| agents | The agents at work on the desktop, the asking one among them: each one's folder, branch, uncommitted files, workspace, how long, and what it is doing. So an agent can see another is at work in a folder before it changes files there |
| handoff, handoff_update | Reads or updates a desk's handoff record: task, status, summary, next, checks with freshness, sessions |
| doctor, history, changes, themes, version | What `vikix doctor`, `vikix history`, `vikix changes`, `vikix theme` and `vikix version` say |
| docs_search, docs_read | Finds and reads the documents on this machine, the ones `Super+F2` searches: these guides, man pages, your projects' documents, your notes. So the agent can answer from the man page, not from memory |
| records_search, records_get | Finds and reads what your plugins kept (`vikix records`): flight searches, meetings, your Claude plan's use. It can't add or change a record |
| file_changes | Every change made to your files through Esploro (`vikix add esploro`), newest first, in words, and whether it was undone. For "where did that file go?". Nothing is undone here: that stays yours, in Esploro's Edit → Changes… |
| notify | Shows a notification, marked as the agent's |
| snapshot | Records your settings before a change |
| set_theme, switch_workspace, focus_window | Small changes, easily undone |
| commands | The desktop's commands the agent may run by name: switches and moves put back as easily as done (do not disturb, night light, gaps, title bars, focus left ...) |
| run_command | Runs one of those, as its key would. The desktop refuses any other command, and says why |
| propose_file_changes | Proposes a plan of changes to your files (copy, move, rename, new folders, the Trash, tags), which waits for you: checked whole first, then shown in Esploro with why, where only your Apply runs it, and undo takes it back. Without Esploro there is nowhere to show it, and the tool says so |
| propose_rule | Proposes a rule for the desktop, which waits for you: checked first to be only a rule (verbs and plain values, no Lisp of its own), then shown under `Super+m` → *Rules*, where you add it to your `rules.lisp` or drop it ([Rules](rules.md#a-rule-an-agent-proposes)) |

Two more are off unless you turn them on, because they can change a lot: `vikix mcp register --allow-eval` adds **eval** (Lisp in the window manager, through the door, below) and `--allow-undo` adds **undo** (your settings back one snapshot). `vikix mcp register` again, without them, takes them away. They're a convenience, not a lock: an agent that may run commands could run `vikix eval` itself, and that goes through the door too.

### The door

An agent's Lisp is checked before it runs. Whatever road it takes, `vikix eval` at the agent's own shell or the MCP server's `eval`, the form is read without running anything (nothing of `#.`), then walked: every function it calls is looked up in one list, of what reads the desktop (the windows, the workspaces, a key) and what is put back as easily as done (a workspace switch, a move, a theme, the commands `run_command` may run). A form made only of those runs. One that runs a program, touches a file, defines or changes code, sets a global of the desktop's, waits for input or ends the session is **held** instead: nothing of it runs, the agent is told why (and that it mustn't try another way), and a notification says an agent sent Lisp the door held. `Super+m` → *Door* lists what waits: pick one to see it, run it as you, or drop it. The same from a terminal:

```sh
vikix door                 # what waits: when, which agent, why, the form
vikix door run 1           # run it, as you
vikix door drop 1          # forget it
vikix door check '(form)'  # would it pass? "ok", or why not
vikix door allowed         # every name a form may call
```

A function of your own `user.lisp` that an agent may call goes in `~/.config/vikix/door`, one name a line. Your own `vikix eval` at a terminal is yours and isn't checked; only a shell under an agent (Claude Code, Codex, OpenCode, Gemini, Aider, Antigravity) is an agent's, and a script of Vikix's run by the agent (`vikix theme vikix-light`) sends Vikix's Lisp, not the agent's. A form that reaches a shell, a file, eval or the system is also written in `~/.local/state/vikix/errors/`, so `vikix doctor` and `vikix debug` keep the attempt. Ten forms wait at most; past that an agent is refused until you have looked.

It works only for the agent that starts it: nothing listens on the network. Everything the agent asks of it is checked first (a workspace that exists, a theme you have). Secrets are taken out of what it hands back (`changes` shows your files' differences). Every call, refused ones too, is written in `~/.local/state/vikix/mcp.log`, yours alone: the tool, whether it worked, and its arguments. Its notifications start "Agent:". After `vikix update` it runs the new version by itself, without the agent reconnecting.

## Dictation

Press **Super+F9** and speak. Press **Super+F9** again, and a moment later what you said is typed into the window you were in: two or three seconds for a sentence, about ten seconds for a minute of speech. It's also put on the clipboard, in case that window didn't take it. If you move to another window while it's written down, it isn't typed there: it's only put on the clipboard, and a notification says so. **Super+Shift+F9** stops without typing anything. While it listens, the bar says **mic**, in red.

It's a press, speak, press: StumpWM sees a key go down, not come up, so holding the key while you speak isn't possible (a held key's repeats count as one press).

It listens for five minutes at most. Then it stops, says so, and the next **Super+F9** types what it heard. A space follows each dictation, so the next one doesn't run into it.

To set it up, once (a few minutes, no password):

```sh
vikix add dictation          # or: vikix dictate setup
```

That builds [whisper.cpp](https://github.com/ggml-org/whisper.cpp) for this computer, into `~/.local/opt/whisper.cpp`, and downloads its model (150 MB) and a voice detector (1 MB) into `~/.local/share/vikix/whisper/`, each checked against its published checksum. Everything runs on the laptop: your voice never leaves it, and the recording is deleted once it's written down.

**English, or many languages.** The model it starts with, `base.en`, knows English only, and writes down a sentence in about a second. `small` knows many languages (French, Spanish, Arabic, Hindi and more; not Esperanto) and takes a few seconds:

```sh
vikix dictate models          # which is used
vikix dictate models small    # many languages (490 MB)
vikix dictate models base.en  # back to English
```

**Silence and noise aren't typed.** The voice detector passes only speech to whisper, and whisper's notes about sounds, such as "(music)", are left out: anything it writes in brackets goes, so a spoken aside in brackets would too. A very short clip (a second or so) can come out as a word or two nobody said.

**What stays afterwards:** the recording is deleted once it's written down. The text stays where it was typed, on the clipboard (so in its history, Super+c), and in the "Typed" notification (Super+Shift+n shows earlier ones).

`vikix dictate status` says whether it's set up, and with which model. `vikix dictate file talk.wav` prints what a recording you already have says, without typing it anywhere.

To take it away: `vikix remove dictation` (the models stay; `vikix dictate uninstall --models` removes them too).

## Talking with the AI

Dictation types what you say. Voice sends it to the AI instead, and the answer comes back aloud.

| Key | What happens |
|---|---|
| **Super+F10**, speak, **Super+F10** | The chat model answers: the one Super+i uses (local, Claude, or Codex, which takes each question on its own). You hear the answer and see it in a notification (a long one opens in a terminal) |
| **Super+F11**, speak, **Super+F11** | It goes to the agent, Claude Code, in a terminal of its own. Claude's replies are read aloud |
| **Super+Shift+F10** | Stop the talking |

**It remembers the conversation.** Ask "What's the capital of France?", then "And how many people live there?", and it knows you mean Paris. After five quiet minutes the next question starts afresh; Super+m → *Voice: a new conversation* does it at once. With the agent, every question after the first goes to the same terminal, so it carries on there too; close that terminal to start over.

**It stops talking when you start.** Pressing Super+F10 or Super+F11 to speak stops it at once, so the microphone doesn't hear it.

To set it up, once (a minute, no password):

```sh
vikix add voice            # brings dictation and llm, if they aren't here
```

That installs [Piper](https://github.com/OHF-Voice/piper1-gpl), a voice that runs on this laptop, and downloads a voice for it (60 MB, checked against its published checksum).

**Where your words go.** The listening is dictation's: on this laptop. A question to Super+F10 goes where Super+i's text does (nowhere, with a local model; to Anthropic, with Claude; to OpenAI, with Codex: `vikix ai use`). A question to Super+F11 goes to the agent's company, as with Super+a. The answer is spoken on this laptop.

**Your choices** are in `~/.config/vikix/voice`:

```sh
vikix voice voices          # which voice: lessac, amy (American), alan (British)
vikix voice voices alan     # switch (it downloads the voice)
```

Set `speak=no` there to only see the answers, or `idle=` to change the five minutes. `vikix voice say "any text"` reads anything aloud.

Only Claude Code's replies are read aloud: with another agent (`vikix agent --default`), Super+F11 still sends your question, and the answer stays on the screen.

To take it away: `vikix remove voice` (the voices stay; `vikix voice uninstall --voices` removes them too).

## When AI doesn't work

| What happens | What to do |
|---|---|
| Super+a shows a message and "Enter closes this window" | It says what's missing: an agent to install, a key, a local model |
| Super+a opens a terminal that closes at once | Run `vikix agent` in a terminal to see the message |
| The agent asks you to log in every time | Run `claude` once in a terminal and finish the login there |
| The agent says it can't reach the desktop | `vikix doctor`: it checks that `vikix eval` works |
| A local model doesn't answer, or is slow | See [Local AI doesn't answer](fixing.md#local-ai-doesnt-answer) |
| `llm` has no model, asks for a key, or can't connect | See [`llm` doesn't answer](fixing.md#llm-doesnt-answer) |
| Super+i says "Super+i needs llm", "No local model yet" or "Local AI isn't running" | Do what it says: `vikix ai llm`, a model with Super+m → *Local AI: choose a model*, or `vikix ai setup` |
| Super+i says "Select some text first" | Highlight the text (or copy it), then press Super+i again |
| Super+F9 says "Dictation isn't set up" | `vikix add dictation`, once |
| Super+F10 answers, but nothing is heard | `vikix voice status`; `speak=no` in `~/.config/vikix/voice` turns the voice off; check the volume and the output in pavucontrol |
| "Voice isn't set up" | `vikix add voice`, once |
| Super+F9 says "Heard nothing" | The microphone: `pavucontrol`, *Input devices*, check it isn't muted and moves when you speak |
| Super+F9 types in the wrong place | It types where the focus is when you press the second Super+F9; the text is on the clipboard too |
| Super+i says "AI is still working on the last one" | Wait for its answer: one at a time |
| Super+i says "You don't have the model …" | `vikix ai models` gets it, or empty `model=` in `~/.config/vikix/ai` |
| Super+i says "Claude needs your Anthropic key" | `vikix ai key set anthropic`, or back to local: `vikix ai use local` |
| Super+i says "AI didn't answer" | The notification says why; a local model: `vikix ai status` |
| Super+i says "Codex isn't installed" or "isn't signed in" | `vikix add codex`, then `codex login`; or back to local: `vikix ai use local` |
| Super+i says something in `~/.config/vikix/ai` looks wrong | Fix that line (`use=local`, `use=claude` or `use=codex`; `model=` a name from `llm models`, or one of Codex's; `effort=` a word such as `low`), or delete the file: the next Super+i writes it afresh |
| Super+i took the wrong text | It takes the last highlight before the clipboard: highlight the text you mean |
| `note` says "no folder yet" or "no index yet" | `note index ~/Notes` once (your folder; `--skip A,B` leaves folders out) |
| `note` says the index needs local AI, or can't reach Ollama | The index is made on this laptop: `vikix add local-ai`, then `vikix ai status` |
| `note ask` answers from the wrong note | The notes it was given are listed under the answer. `note ask --claude` answers better; `embed=nomic-embed-text` in `~/.config/vikix/notes` finds better passages (after `ollama pull nomic-embed-text`; the next `note index` reads every note again) |
| The agent has no vikix tools | `vikix mcp register`, then restart the agent; `vikix mcp status` says whether it's on (see [When something breaks](fixing.md#the-agent-doesnt-have-the-desktops-tools)) |
| You don't like what the agent changed | `vikix changes`, then `vikix undo` |
