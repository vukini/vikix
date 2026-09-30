# Working with AI

Vikix gives you these ways to use AI, from the most capable to the most private:

| | What it is | What it needs | Where your words go |
|---|---|---|---|
| **The agent** | Claude Code (or another agent), in a terminal, able to change the desktop for you | A Claude account (Pro or Max), or an Anthropic API key; others need their own | Anthropic, or the agent's company; nowhere with `--local` |
| **Local models** | A model that runs on this laptop, to chat with | `vikix ai setup`, and a few GB of disk | Nowhere: it all stays here |
| **`llm`** | One command for any model, fed from a pipe | `vikix ai llm`, and a local model or a key | Here, or to the model's company |
| **Super+i** | Proofread, rewrite, translate, explain or ask about the text you selected, in any program | `vikix ai llm`, and a local model (or Claude, if you choose) | Here, unless you choose Claude |
| **Super+F9** | Speak, and it types what you said, in any program | `vikix add dictation` (a few minutes, once) | Nowhere: it all stays here |
| **In Neovim** | A chat about your code, and your agent in a side window (`Space A`) | `vikix add neovim`, and a local model, a key or an agent | As Super+i's, or the agent's |
| **In Emacs** | The same, with gptel (`C-c g`) and agent-shell (`C-c a`) | `vikix add emacs`, and a local model, a key or an agent | As Super+i's, or the agent's |

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

In a terminal, `vikix undo` first lists the files it would change and asks. Answer no when the snapshot one back isn't the one you meant (an agent started from an editor takes one too), and pick one from `vikix history` with `vikix undo ID`. This covers your settings (the files in `~/vikix/config/yours.list`), not everything in your home folder. For your work, keep backups: [README: Backups](../README.md#backups).

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

**From an editor:** an editor that starts an agent itself should run `vikix agent --exec NAME` and the agent's own options after it, or `vikix agent --exec` for yours. It's the same start, with the same protections, but quiet: nothing of Vikix's in the agent's output, and no questions. Editors that speak ACP, the Agent Client Protocol (Neovim's CodeCompanion, below; Emacs's agent-shell; Zed), run `vikix agent --acp NAME`: Gemini CLI and OpenCode speak it themselves, and Claude Code and Codex need a small adapter, which `vikix agent --install claude` (or `codex`) puts next to them. It uses the agent you have, and your login. It needs Node 22 or newer, which `vikix add neovim` brings. Aider doesn't speak ACP. `vikix agent --which` says which agent is yours, and `vikix ai use` which model Super+i uses.

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

The chat follows `vikix ai use`: `local` (a model on this laptop, `vikix ai setup` first) or `claude` (your key: `vikix ai key set anthropic`). A model set with `model=` in `~/.config/vikix/ai` is used here too. On a laptop's CPU, a local model's first answer takes minutes, because it reads CodeCompanion's instructions first; Claude answers in seconds. In the chat, `ga` changes the model or the agent for that chat.

The agent in `Space A g` is started by `vikix agent --acp`, so it's the same as Super+a's: the guide, no API keys, and a snapshot first, so `vikix changes` shows what it did and `vikix undo` takes it back. It signs in with its own login, the one it uses in a terminal. Claude Code and Codex need their adapter, which `vikix agent --install claude` adds (running it again for an agent you have only adds what's missing). `Space A t` runs `vikix agent` itself, so Aider works there too.

Nothing starts or connects until you press a key. When something's missing (a key, Ollama, the agent or its adapter), the key says what to type, and does nothing else.

## AI in Emacs

Emacs's config has [gptel](https://github.com/karthink/gptel) for the chat and [agent-shell](https://github.com/xenodium/agent-shell) for your agent, and Vikix sets both up:

| Keys | What they do |
|---|---|
| `C-c g` | A chat, on the model Super+i uses: a local one, or Claude. With a selection, the chat starts from it |
| `C-c G` | gptel's menu: another model for this chat (Claude, your local ones, and the config's own), and what to send |
| `C-c a` | A chat with your agent (the one Super+a starts), which can read and change your files |
| `C-c A` | Your agent in a terminal inside Emacs |

The chat follows `vikix ai use` and `model=`, as Neovim's does, and Emacs reads them again at each `C-c g`, so a change reaches an Emacs that's already open. A model you pick in the menu stays until you change that file. The agent starts through `vikix agent --acp`, with the same rules as in Neovim, above; `C-c A` runs `vikix agent` itself, so Aider works there too. When something's missing, the key says what to type. [Neovim and Emacs](editors.md) compares the two.

## The desktop as tools (MCP)

MCP is how an AI agent is given tools of its own. `vikix mcp register` gives your agent a fixed set of them for this desktop, so it can look at it and make small changes without writing commands.

Why, when the agent can run commands anyway? Each command needs your yes. These tools are few, checked, and easy to take back, so you can allow them once: in Claude Code, answer "always allow" for a vikix tool (or allow `mcp__vikix__*`). Then the agent looks at the desktop and switches a theme or a window without asking each time, while every other command still asks.

```sh
vikix mcp register     # for Claude Code, then restart it; it prints the lines for Codex, Gemini CLI and OpenCode
vikix mcp status       # is it on, with which tools, the servers running (and their version), the last calls
vikix mcp tools        # what it offers
vikix mcp unregister   # take it away
```

| Tool | What it does |
|---|---|
| desktop | The workspaces and their windows, the screens, the theme |
| keys | Every key Vikix binds, and what it does |
| doctor, history, changes, themes, version | What `vikix doctor`, `vikix history`, `vikix changes`, `vikix theme` and `vikix version` say |
| notify | Shows a notification, marked as the agent's |
| snapshot | Records your settings before a change |
| set_theme, switch_workspace, focus_window | Small changes, easily undone |

Two more are off unless you turn them on, because they can change a lot: `vikix mcp register --allow-eval` adds **eval** (any Lisp in the window manager) and `--allow-undo` adds **undo** (your settings back one snapshot). `vikix mcp register` again, without them, takes them away. They're a convenience, not a lock: an agent that may run commands could run `vikix eval` itself.

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

To take it away: `vikix remove dictation` (the models stay; `vikix dictate uninstall --models` removes them too).

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
| Super+F9 says "Heard nothing" | The microphone: `pavucontrol`, *Input devices*, check it isn't muted and moves when you speak |
| Super+F9 types in the wrong place | It types where the focus is when you press the second Super+F9; the text is on the clipboard too |
| Super+i says "AI is still working on the last one" | Wait for its answer: one at a time |
| Super+i says "You don't have the model …" | `vikix ai models` gets it, or empty `model=` in `~/.config/vikix/ai` |
| Super+i says "Claude needs your Anthropic key" | `vikix ai key set anthropic`, or back to local: `vikix ai use local` |
| Super+i says "AI didn't answer" | The notification says why; a local model: `vikix ai status` |
| Super+i says something in `~/.config/vikix/ai` looks wrong | Fix that line (`use=local` or `use=claude`; `model=` a name from `llm models`), or delete the file: the next Super+i writes it afresh |
| Super+i took the wrong text | It takes the last highlight before the clipboard: highlight the text you mean |
| You don't like what the agent changed | `vikix changes`, then `vikix undo` |
