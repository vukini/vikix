# Working with AI

Vikix gives you three ways to use AI, from the most capable to the most private:

| | What it is | What it needs | Where your words go |
|---|---|---|---|
| **The agent** | Claude Code (or another agent), in a terminal, able to change the desktop for you | A Claude account (Pro or Max), or an Anthropic API key; others need their own | Anthropic, or the agent's company; nowhere with `--local` |
| **Local models** | A model that runs on this laptop, to chat with | `vikix ai setup`, and a few GB of disk | Nowhere: it all stays here |
| **`llm`** | One command for any model, fed from a pipe | `vikix ai llm`, and a local model or a key | Here, or to the model's company |
| **Super+i** | Proofread, rewrite, translate, explain or ask about the text you selected, in any program | `vikix ai llm`, and a local model (or Claude, if you choose) | Here, unless you choose Claude |

You can use any of them, all of them, or none. Nothing AI runs until you start it.

## The agent

An agent is an AI that does things, not only talks about them. Claude Code reads files, runs commands and edits your settings, and it knows how Vikix is put together, so you can ask for a change in plain words.

### Starting it

Press **Super+a**, or type `a` in a terminal. A terminal opens with your agent in it: Claude Code, unless you chose another ([Another agent](#another-agent), below).

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

- **A guide for the agent.** Vikix installs a skill in `~/.claude/skills/vikix`: where every file is, which ones are yours to change, the keys, and the `vikix` commands. Its main rule is the one in [Where everything is](map.md): change your files, never Vikix's.
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

This covers your settings (the files in `~/vikix/config/yours.list`), not everything in your home folder. For your work, keep backups: [README: Backups](../README.md#backups).

### Another agent

Claude Code isn't the only one. Four others work the same way, with the same snapshot first and the same guide:

| Agent | Signs in with | Can run on this laptop |
|---|---|---|
| **OpenCode** | Any model company you have an account with | Yes |
| **Codex** (OpenAI) | Your ChatGPT account | Yes |
| **Gemini CLI** (Google) | Your Google account | No |
| **Aider** | An API key (`vikix ai key set anthropic`) | Yes |

```sh
vikix agent --list                # which are installed, and which Super+a starts
vikix agent --use opencode        # try one: it offers to install it first
vikix agent --default opencode    # make Super+a start it
vikix agent --default claude      # back to Claude Code
vikix add codex                   # or install one as a feature (vikix remove codex takes it away)
```

**Which one?** Claude Code is the one Vikix is made with and tested with. OpenCode or Aider if you want to work offline.

**Always through Vikix:** start them with `vikix agent --use NAME` (or Super+a), not by typing `codex` or `opencode`: that skips the snapshot, and the protections below.

**Offline**, on a local model: `vikix agent --use opencode --local` (or codex, or aider; `--model NAME` picks one). It picks the best of your models for code. Be warned: on a laptop's CPU each answer takes minutes (Aider on llama3.2:3b took over four minutes for one sentence), and a small model rarely carries out a change on its own. A bigger model (`vikix ai models`) does more, more slowly still.

**What an agent doesn't get**, so that a trick hidden in a web page or a file it reads can't use it:

- **Your API keys**, and other secrets in the environment (passwords, tokens): each agent signs in its own way, so a key isn't billed without you knowing. Aider can't sign in, so it gets the model companies' keys (Anthropic, OpenAI, Google, OpenRouter, DeepSeek, Mistral, Groq, xAI), and no others. A shell the agent opens doesn't read them back either.
- **Your SSH agent.** After your first `git push` of the day, it holds your unlocked key: an agent with it could push, as you, to anything you can. If you want the agent to push for you: `VIKIX_AGENT_SSH=1 vikix agent`.

This prevents accidents; it isn't a wall. The agent runs as you, and can read your files. OpenCode is set to ask before it runs a command or edits a file, as Claude Code does, unless your own OpenCode settings say otherwise.

**How they know Vikix:** OpenCode reads the same skill as Claude Code. Codex, Gemini and Aider read `~/.local/share/vikix/AGENTS.md`, the same text: Vikix links it as `~/.codex/AGENTS.md`, writes a one-line `~/.gemini/GEMINI.md` that imports it, and hands it to Aider (not to a small local model, for which it's too long). If you have one of those files already, it's yours and stays; Vikix says how to add the guide to it.

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

To switch, pick *Use Claude instead* (or *Use the local model instead*) at the end of the Super+i menu, or type `vikix ai use claude` or `vikix ai use local`. The choice is kept in `~/.config/vikix/ai`, which starts as:

```sh
use=local          # free, offline, the text stays on this laptop
model=             # empty: llama3.2:3b, or your first local model
languages=English Esperanto French Spanish Arabic Hindi
```

For better answers, above all translations into Esperanto, which small models get wrong, use Claude. Then each use costs a little and the text you selected goes to Anthropic, so it needs your key first: `vikix ai key set anthropic`. Super+i never switches to Claude by itself, and its menu always names the model and where the text goes.

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
| Super+i says "AI is still working on the last one" | Wait for its answer: one at a time |
| Super+i says "You don't have the model …" | `vikix ai models` gets it, or empty `model=` in `~/.config/vikix/ai` |
| Super+i says "Claude needs your Anthropic key" | `vikix ai key set anthropic`, or back to local: `vikix ai use local` |
| Super+i says "AI didn't answer" | The notification says why; a local model: `vikix ai status` |
| Super+i says something in `~/.config/vikix/ai` looks wrong | Fix that line (`use=local` or `use=claude`; `model=` a name from `llm models`), or delete the file: the next Super+i writes it afresh |
| Super+i took the wrong text | It takes the last highlight before the clipboard: highlight the text you mean |
| You don't like what the agent changed | `vikix changes`, then `vikix undo` |
