# Everyday user: `vikix ai llm` (Vikix 0.44.0)

Checked on 2026-09-28 against the dev checkout, `VERSION` 0.44.0 (the installed `~/vikix` is 0.43.1, so everything was run as `bin/vikix ...`). llm 0.36, llm-ollama 0.17.1 and llm-anthropic 0.29 were already installed, Ollama was running with `llama3.2:3b`, and the default was already `llama3.2:3b`. In this shell `OPENAI_API_KEY` is set and `ANTHROPIC_API_KEY` is not. That matters for finding 1.

I sent no prompt to a paid model. The no-key errors below come from runs where the key was removed from the environment (`env -u`) and a throwaway `LLM_USER_PATH` was used, so llm stopped before it sent anything. The real default was never changed.

Most important first.

---

## 1. HIGH: with no local model, "Try:" sends your text to OpenAI, and bills it, when you have an OpenAI key

**What I did.** I ran `LLM_USER_PATH=<empty dir> llm models default`, then read what `vikix ai llm` prints when it finds no model.

**What happened.**
- llm's own built-in default is **`gpt-5.6-luna`** (OpenAI).
- When there's no local model and no `ANTHROPIC_API_KEY`, `vikix ai llm` warns "no model for llm yet …", leaves llm's default alone and still prints `Try: echo '…' | llm 'say it shorter'`.
- Vikix's own key store supports `vikix ai key set openai`, and llm reads `OPENAI_API_KEY`. So a user in that state (like this machine's shell) who follows the Try line sends the text to OpenAI and pays for it.
- The README promises "a local one … (free, offline, nothing leaves the laptop), else Claude". OpenAI is never mentioned, but it is what actually happens.
- Without an OpenAI key, llm says `Error: No key found - add one using 'llm keys set openai' …`. That is the wrong hint for Vikix (see 3), and it names a company the user never chose.

The same thing happens when Ollama is installed but not running at the moment `vikix ai llm` runs: `running` fails, so it falls through to Claude, or to nothing.

**Cost.** This bites anyone who installs llm before downloading a model and has an OpenAI key, which is exactly the case the "keys" half of the feature invites. It costs money and privacy, and nothing warns them.

**Suggestion.** When no model is found, don't print the Try lines, or print them with `-m MODEL`. Better: say plainly "llm's own default is OpenAI's `gpt-…`; with `OPENAI_API_KEY` set, a plain `llm` would go there". Or choose OpenAI deliberately (`gpt-4.1-mini`) when that is the only key, and say so. In the README, add OpenAI to the sentence about the default.

Not in TODO.md.

## 2. MEDIUM: the default Vikix picked is treated as "chosen" by you, and never gets upgraded to a local model

**What I did.** I ran `bin/vikix ai llm` on this machine, and again with a fresh `LLM_USER_PATH`.

**What happened.**
- On the real machine: `:: llm's default stays llama3.2:3b (chosen before; …)`. I never chose it. An earlier `vikix ai llm` wrote it.
- The code keeps any `default_model.txt`, whoever wrote it. So the order the README suggests ("`vikix ai key set anthropic`", then `vikix ai llm`, then `vikix ai models` later) leaves the default on **Claude, paid**, for good. Re-running `vikix ai llm` after downloading a local model just says "stays claude-sonnet-5 (chosen before)".
- The README says "A default *you* chose is never changed". That is true, but Vikix's own choice is kept the same way.

**Cost.** This happens once per user, but it goes unnoticed and money is involved. The "chosen before" wording also hides what happened.

**Suggestion.** Record the model Vikix itself set (for example in `~/.local/state/vikix/llm-default`). If `default_model.txt` still equals it, re-pick the model, preferring a local one. Word the kept case as "stays X (set earlier; …)". Also have `vikix ai models` end with a hint ("llm's default is claude-sonnet-5; vikix ai llm --default MODEL to use this one") when the default is a paid model.

Not in TODO.md.

## 3. MEDIUM: llm's "No key found" hint points to a second key store, and the docs expect a message llm never prints

**What I did.** I ran `env -u ANTHROPIC_API_KEY llm -m claude-sonnet-5 hi` with a throwaway `LLM_USER_PATH`.

**What happened.**
- llm printed `Error: No key found - add one using 'llm keys set anthropic' or set the ANTHROPIC_API_KEY environment variable`.
- A user who follows that hint gets a second copy of the key in `~/.config/io.datasette.llm/keys.json`. That is the thing Vikix's key store exists to avoid, and backups keep that file. README: "It reads the keys `vikix ai key` keeps, so there's no second copy."
- `docs/ai.md`'s trouble table has the row "`llm` says there's no model". llm never says that. The real symptom is "No key found", or a connection error when Ollama is down.
- One more trap: a key set with `vikix ai key set` only reaches terminals opened afterwards (README: "after `exec bash`"). The first `llm -m claude-…` in the terminal where the key was just set therefore gives this error and points to `llm keys set`.

**Cost.** This affects anyone trying Claude through llm for the first time. It costs a few minutes of confusion, and possibly a key copied to a place Vikix doesn't track.

**Suggestion.**
- Change the fixing row to `llm` says "No key found" → `vikix ai key set anthropic`, then `exec bash`; don't use `llm keys set`.
- Add a line to the README bullet.
- Optionally, have `vikix ai key check` or `vikix doctor` flag a non-empty `keys.json`.

Not in TODO.md.

## 4. LOW: every `llm` call spends about 3 s starting up, 1.7 s of it on the Anthropic plugin

**What I did.** I timed `llm --help` and two local prompts.

**What happened.**

| Command | Time |
|---|---|
| `llm --help` | 3.0 s |
| `LLM_LOAD_PLUGINS='' llm --help` | 1.3 s |
| `LLM_LOAD_PLUGINS=llm-ollama llm --help` | 1.35 s |
| Cold prompt (model not yet loaded) | 17.6 s |
| Warm `echo hello \| llm 'say it in french'` | 4.8 s, of which the model took 1.5 s |

- llm-anthropic's import costs about 1.7 s on every call, even for a local-only user.
- The honest timings in the README ("about 4 s to load, then about 11 s") are for Ollama itself and don't include this.
- The cold run shows nothing for the first several seconds.

**Cost.** This is felt on every pipe, and it makes llm feel slower than `vikix ai chat`.

**Suggestion.** Add a sentence to the README timings ("llm itself takes about 3 s to start"). Also consider suggesting `LLM_LOAD_PLUGINS=llm-ollama` for people without an Anthropic key, or setting it in `vikix.bash` when no Anthropic key is kept.

Not in TODO.md.

## 5. LOW: `llm models` buries the local model at line 65 of 66

**What happened.**
- `llm models` lists about 38 OpenAI models and 26 Anthropic ones before `Ollama: llama3.2:3b`.
- The name to pass to `--default` is easy to miss, and the list suggests OpenAI is part of the setup (the same confusion as finding 1).
- `llm models -q ollama` gives exactly the one line.

**Suggestion.** In the README and the Try lines, use `llm models -q ollama` (your local models) instead of the plain `llm models`, which is what the `--default` error hints at.

## 6. LOW: log times are UTC with no zone shown

**What happened.**
- `llm logs -n 3` headers read `2026-09-28T08:45:11` while the clock said 12:45 (+04).
- The README's sqlite3 query works read-only. I ran it with `sqlite3 -readonly`: exit 0, table `turns` and the columns exist, and `llm logs path` is `~/.config/io.datasette.llm/logs.db` as documented. It also prints UTC (`…+00:00`).

**Suggestion.** In the README query, use `datetime(datetime_utc,'localtime')`, and add "(times in UTC)" next to `llm logs -n 5`.

## 7. LOW: loose ends in how llm fits with the other `vikix ai` commands

- **Two chats, two logs.** `vikix ai chat` is `ollama run` (history in `~/.ollama/history`), while llm has its own `llm chat` that logs to SQLite. Neither doc mentions the other. One line would do: "for a conversation that's logged and works with Claude too: `llm chat`".
- **Help headers.** The `vikix ai help` header still says "keys, and local models", and `vikix doctor` says nothing about llm, even whether it's installed or what its default is. A doctor line like "llm 0.36, default llama3.2:3b (local)" would also catch finding 2.
- **Pins never reach existing machines.** No stage or migration re-runs `vikix ai llm`, so a later pin bump never arrives. The README's "pinned" doesn't say that you re-run `vikix ai llm` to move.
- **Silent first install.** `uv tool install --quiet` shows nothing. Re-runs take 0.3 s (cached), but a first install downloads the OpenAI and Anthropic SDKs silently. "(a minute or so the first time)" on the `installing` line would do.

## Messages and discoverability, checked

- `vikix help` lists `vikix ai llm`. `vikix ai help` and `vikix ai help-local` both describe it, with a pipe example, and both agree with the README.
- Errors are short and correct: `vikix ai llm --bogus` → `vikix ai llm [--default MODEL]`; `--default` with no model → `--default needs a model: llama3.2:3b, claude-sonnet-5 ...`; `vikix ai lm` → `unknown command lm (vikix ai help)`.
- Neither Super+m nor the key help mentions llm, which is fine for a command-line tool (TODO item 1 plans the keys).
- `claude-sonnet-5`, used in every example, really is a model name in llm-anthropic 0.29.
- `docs/map.md`'s `.config/io.datasette.llm/` line is right, and that folder is not in `yours.list`, so prompts don't end up in the snapshot history. Good.

## What felt good

- The command explains itself. It says what it's installing and which version, which default it kept and why, three things to try, and that everything is logged, with the way to search and to stop it. It fits on five lines.
- Reinstalling is quick (0.3 s cached) and changes nothing else, so running it again to "see what it says" is safe.
- Picking a local model first (llama3.2:3b by name) is the right instinct, and in the normal order (a model first, then llm) it just works. My first prompt answered correctly, in 17 s cold and 5 s warm.
- The README's sqlite3 query works exactly as written. Using the environment for keys rather than `llm keys` is the right design; it only needs the error path covered (finding 3).
- `docs/ai.md`'s three-row table (the agent, local models, llm: what each needs and where your words go) is the best single explanation of the AI side of Vikix.
