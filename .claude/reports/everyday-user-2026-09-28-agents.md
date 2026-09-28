# Everyday user review: "any agent, not just Claude Code" (2026-09-28)

Checked: the dev checkout at **0.49.1** (`VERSION`); the installed desktop, `~/vikix`, is **0.49.0**. `bin/vikix-agent` and `bin/vikix-features` are the same in both where it matters.

What I read first, as a new user: README "Any agent, not just Claude Code", docs/ai.md "Another agent", `vikix agent --help`, `vikix features`, the Super+a label in the key help and the menu.

What I ran:

- **On the real machine** (read-only): `vikix agent --help`, `vikix agent --list`, `vikix features`, `vikix doctor`.
- **In the throwaway home** (`/home/vukini/.claude/jobs/9e7c4573/tmp/realhome`, where OpenCode, Codex and Aider were already installed): `--list`, `--default codex`, `--uninstall codex`, `--install codex` (real download), `--use gemini` (with and without a terminal), `--use claude --local`, `--use gemini --local`, `--model nosuch`, `--uninstall gemini` and `--uninstall claude` (neither installed), `vikix add claude`, a dry run of `vikix remove`, and Aider on `llama3.2:3b` with `--local --message ... --yes`.
- **In scratch homes** in /tmp (dry runs only): `vikix remove`, to pin down a failure.

Nothing was installed into the real home, the real default agent wasn't changed, and no agent was started there or pointed at a paid model.

---

## High

### 1. `vikix remove NAME` fails silently once you have two features that don't install packages (two agents, or local-ai and llm)

- **What happened:** In the throwaway home (features: everything, opencode, codex, aider), `vikix remove opencode` printed **nothing at all** and exited with status 1. Nothing was removed, and no question was asked. The same happens on this machine's own feature set: with a copy of `~/.config/vikix/features` (everything, windows, webapps, local-ai, llm), `DRY_RUN=1 vikix remove printing` also exits 1 with no output. Adding an agent makes it more likely, because every agent is a feature without a package list.
- **Expected:** the usual "removing: … Go ahead? [y/N]", or at worst an error message.
- **How to see it** (dry run, safe):
  ```sh
  mkdir -p /tmp/vxh/.config/vikix; printf 'emacs\ncodex\n' > /tmp/vxh/.config/vikix/features
  env -i HOME=/tmp/vxh PATH=/usr/bin:/bin VIKIX_SWANK_PORT=9 DRY_RUN=1 bash bin/vikix remove emacs; echo $?   # 1, no output
  printf 'emacs\n' > /tmp/vxh/.config/vikix/features
  env -i HOME=/tmp/vxh PATH=/usr/bin:/bin VIKIX_SWANK_PORT=9 DRY_RUN=1 bash bin/vikix remove emacs; echo $?   # 0, works
  ```
- **Why** (read afterwards to explain it): in `cmd_remove` (bin/vikix-features, around line 155), `stay_pkgs=$({ …; lists_of "${stay[@]}"; } | while read -r l; do [ -f "$VIKIX_DIR/packages/$l.list" ] && read_list …; done | sort -u)`. A feature with no lists makes `lists_of` print an empty line. When that empty line is the last one, the loop's last `[ -f packages/.list ]` is false, so the loop exits 1. Under `pipefail` the whole substitution fails, and `set -e` quietly ends the script. The loop just below it, over the going features' lists, has the same pattern.
- **Cost:** high. This is the command the README gives for taking an agent away, and on this machine any `vikix remove` already fails with no message. A user has no way to tell what went wrong.
- **Suggestion:** use `if [ -f … ]; then read_list …; fi` in both loops (or skip empty names in `lists_of`), and add a test to `tests/features.sh` that removes a feature while two list-less features stay.
- **In TODO.md:** no.

## Medium

### 2. `vikix agent --uninstall NAME` and `vikix remove NAME` do different things, but the README says they're the same

- **What happened:** README: "`vikix remove NAME` (or `vikix agent --uninstall NAME`) removes the program". After `--uninstall codex`, codex was gone, but `~/.config/vikix/features` still listed `codex`, and `vikix features` still showed `[x] codex`. `--install` records the feature (`vikix-features record`), but `--uninstall` never removes the record.
- **Expected:** both routes leave the same state, or the docs say which one to use.
- **How to see it:** in the throwaway home, run `vikix agent --uninstall codex`, then `vikix features | grep codex`, which shows `[x]`.
- **Cost:** confusing, not harmful: `vikix features` lies after the uninstall.
- **Suggestion:** have `--uninstall` call a `vikix-features forget NAME` (the mirror of `record`). Or send users to `vikix remove` only.
- **In TODO.md:** no.

### 3. `vikix remove <agent>` asks for your sudo password and talks about unrelated folders

- **What happened:** Removing an agent is only a `rm` in your home, yet `cmd_remove` always runs `sudo_keepalive` ("your password, once…"). Its summary also says "your files stay: ~/dev, ~/.emacs.d, ~/.config/nvim, ~/Windows", which has nothing to do with Codex. The useful line ("its settings, login and sessions stay: ~/.codex") comes from the agent's own uninstall, after the question. Seen in the dry run of `vikix remove codex`. `vikix add codex` asks for the password too, though it installs nothing system-wide.
- **Cost:** a password prompt for a home-only change teaches users to type their password without thinking, and the "your files stay" list is noise.
- **Suggestion:** ask for sudo only when there are packages to remove or add, or stages to run. Build "your files stay" from the features that are actually going.
- **In TODO.md:** no.

### 4. `--model` without `--local` is silently ignored

- **What happened:** `vikix agent --use aider --model llama3.2:3b` looks like "Aider on my local model". But the code only uses `--model` together with `--local`, so Aider starts on its usual model, which is a paid API model if a key is set. `--help` lists `--model` only on the `--local` line, so it's easy to miss. I didn't start this, because it could reach a paid model; this finding is from reading `main`/`start` in bin/vikix-agent.
- **Cost:** rare, but it's the one mistake here that can cost money, which is the thing the rest of the design is careful to avoid.
- **Suggestion:** make `--model` imply `--local`, or refuse with "--model is for --local models; add --local".
- **In TODO.md:** no.

### 5. Local agents: the guide makes the first answer very slow on a laptop CPU

- **What happened:** `vikix agent --use aider --local --message "In one sentence: what is Vikix?" --yes` on llama3.2:3b (this laptop: 4 cores, Intel HD 620, so Ollama runs 100% on the CPU). The first run was killed at the 4-minute timeout with no answer. A second run, with the model already loaded, answered correctly ("Vikix is an opinionated desktop layer on top of Void Linux, built around the StumpWM window manager…") after **260 seconds**: "Tokens: 6.6k sent, 33 received". Nearly all that time goes on reading the prompt. The whole 21 KB guide (`AGENTS.md`, about 5-6k tokens) goes in with every start (`--read`), on top of Aider's own prompt and repo map. Ollama's context was 16k, so the guide fits, but reading it takes minutes on a CPU. The warning Vikix prints ("small models do little as agents") is about quality, not about waiting minutes before the first word.
- **Expected:** a one-sentence answer in well under a minute, or a warning that the first answer will take minutes.
- **Cost:** a user who tries `--local` sees a frozen-looking prompt and gives up.
- **Suggestion:** for `--local`, say "the first answer can take a few minutes on this machine (no GPU)". Or give local models a short guide: the first screen of the skill plus "run `vikix help`", rather than all of it.
- **In TODO.md:** no.

### 6. An error from Super+a closes the window before you can read it

- **What happened:** Only one path waits for Enter ("not installed. Press Enter to close."). Every `die` exits straight away, and Super+a runs `terminal -e vikix agent`, so the window vanishes. That includes "X didn't install (above)" after a failed download, "no local model…", and "claude has no local models…". docs/ai.md's troubleshooting table admits this ("Super+a opens a terminal that closes at once: run `vikix agent` in a terminal"). The reverse also happens: when you run `vikix agent --use gemini` in your own terminal and answer N, it says "Press Enter to close" and waits, though there's no window to close.
- **Cost:** only when something goes wrong, and then it costs a trip to the docs.
- **Suggestion:** have Super+a pass a flag (or `VIKIX_AGENT_WINDOW=1`) so that on any failure the script waits ("Press Enter to close") after the error. When it isn't set, don't wait.
- **In TODO.md:** no.

## Low

### 7. `--use gemini --local` offers to install Gemini, then would refuse it for `--local`

With a terminal, `vikix agent --use gemini --local` asks "Install it now…?" first. The "gemini has no local models" refusal only comes after the install. `--use claude --local` does the same when Claude Code isn't installed. **Suggestion:** check `--local` support before the install question. Not in TODO.md.

### 8. Messages that say what to run, prefixed as errors

Without a terminal (for example from a script), `vikix agent --use gemini` prints `xx vikix agent --install gemini`. The `xx` error prefix on a bare command reads as "this command failed". **Suggestion:** `xx gemini isn't installed: vikix agent --install gemini`. Similarly `--use` or `--default` with no name gives "no agent called '': …". Better: "--use needs a name: claude opencode codex gemini aider".

### 9. Uninstall never says it uninstalled anything, and doesn't notice when there was nothing

`--uninstall codex` prints only "its settings, login and sessions stay: ~/.codex" and "Super+a starts claude from now on". It never says "codex removed". `--uninstall gemini` when Gemini isn't there runs npm ("up to date in 752ms"), then "its settings and login stay: ~/.gemini", which suggests it did something. **Suggestion:** start with "removing codex (~/.codex/packages/standalone, ~/.local/bin/codex)", and say "gemini isn't installed" when it isn't.

### 10. After uninstalling your default, Super+a falls back to Claude Code even when it isn't installed

After `--default codex` and then `--uninstall codex`, the default became `claude`, which wasn't installed in that home. So the next Super+a offers to install Claude Code. **Suggestion:** fall back to an installed agent, or add "(not installed: Super+a will offer to install it)".

### 11. Claude is an agent but not a feature

The README table lists `claude` beside the others, and `vikix add gemini` works, but `vikix add claude` and `vikix remove claude` say "no feature or bundle called 'claude'". `--uninstall claude` points to a URL. That's reasonable, since Claude Code is part of the base, but `vikix add claude` could say "Claude Code is part of the base: vikix agent --install claude".

### 12. Codex's installer tells you to run plain `codex`

At the end of `--install codex`, Codex's own installer says "Future terminals: open a new terminal and run: codex". Plain `codex` skips the snapshot (and keeps your API keys). Vikix's next line does say `vikix agent --use codex`, but the two instructions disagree. **Suggestion:** end the install with a clearer last word: "start it with `vikix agent --use codex` (the snapshot first); plain `codex` works but takes none". The install took 1 min 52 s with a single "Downloading Codex CLI" line and no progress, which is fine.

### 13. Docs that still say Super+a is Claude Code

The key help, the README key table and the menu are right ("Claude Code, or the one you chose"). A few older sentences aren't:
- docs/ai.md:20: "A terminal opens with Claude Code in it."
- docs/ai.md:103: "Super+a doesn't use it. The agent uses your Claude login…"
- docs/customize.md:16: "`Super+a` starts Claude Code"
- README.md:303: "`s-a`, or `a` in a shell, starts Claude Code."

Each wants a short "(or the agent you chose with `vikix agent --default`)".

### 14. Aider's keys: the docs and the code disagree on which keys it keeps

docs/ai.md says Aider gets "the model companies (Anthropic, OpenAI, Google)". The code keeps ANTHROPIC, OPENAI, GEMINI, OPENROUTER and DEEPSEEK keys. It doesn't keep MISTRAL, GROQ or XAI keys, though `vikix ai key set` offers all of those. Someone with only a Groq key gets an Aider that can't reach Groq, and no message says why. **Suggestion:** keep every model-company key `vikix ai key` knows about (all but GITHUB_TOKEN and HF_TOKEN), and list them in the docs.

### 15. Unknown options go to the agent, after a snapshot

`vikix agent --lsit` (a typo) doesn't say "unknown option". It snapshots and starts your agent with `--lsit`. That's by design ("ARGS go to it"), but typos in Vikix's own options (`--lsit`, `--defualt`) could be caught. Suggestion: refuse unknown `--x` options that are close to one of Vikix's own. Also `vikix agnet` gives "unknown command: agnet (try: vikix help)" with no did-you-mean; that one is general, not specific to agents.

### 16. Picking an agent: the one thing a newcomer needs isn't said

The tables tell you how each agent signs in, but not which to pick. One line would do it: "Have a Claude plan: keep Claude Code. ChatGPT plan: codex. Google account, free: gemini. Offline: opencode --local." `vikix agent --list` could also show which ones can run `--local`, as the README table does.

`vikix doctor` checks for Claude and for the guide file, but doesn't say which agent Super+a starts or whether it's installed. One line ("Super+a starts codex: installed") would catch a default that points at a missing program.

---

## What felt good

- **`vikix agent --list`** is exactly the right size: which agents exist, which are here, which Super+a starts, and how to change it, in six lines.
- **`--default` answers in words**: "Super+a starts codex from now on: Codex (OpenAI): your ChatGPT login, or local".
- **Typos in agent names** get the full list of valid names ("no agent called 'gemni': claude opencode codex gemini aider").
- **The install offer** in a terminal ("Install it now, with its official installer? [y/N]"), with No as the default.
- **Refusals that point the right way:** "claude has no local models; opencode, codex and aider do (--use NAME --local)", and "you don't have nosuch (vikix ai list)".
- **The snapshot and "to see what the agent changed: vikix changes / to take it back: vikix undo"** on every start, whatever the agent. This is the feature's best promise, and it holds.
- **Keys removed by default**, and Aider keeping only model keys (not GITHUB_TOKEN). That's a careful, sensible default, and it's explained in `--help`.
- **Settings and logins kept on uninstall**, and said so. The Codex guide link (`~/.codex/AGENTS.md`) came back correctly on reinstall.
- **The key help and the menu** use the same wording ("AI agent in a terminal: Claude Code, or the one you chose"), which matches the README key table.
- **Uninstalling the default agent resets Super+a** and says so, rather than leaving Super+a pointing at nothing.
