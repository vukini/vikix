# Vikix 0.57 to 0.61, AI in the editors from an everyday user's side (2026-09-29)

Checked on the running desktop: `~/vikix/VERSION` = 0.61.0, the repo's `VERSION` = 0.61.0. I worked hands-on on the empty workspace 5 and went back to workspace 1 afterwards. On 5 I opened an Emacs frame (`Super+x`) and a terminal with Neovim on a scratch file. With the local model I had a gptel chat (`C-c g`, `C-c RET`), opened gptel's menu (`C-c G`, only to look), and had a CodeCompanion chat (`Space A c`). I asked Claude Code one question through `C-c a` ("which window manager… don't change anything"). I opened `C-c A`, `Space A g` and `Space A t` and closed them without asking anything. I also tried the "what's missing" messages for each agent, and ran `vikix agent --acp/--install/--list`, `vikix doctor`, `vikix mcp status`, and the Info manual.

`~/.config/vikix/ai` said **`use=claude`**, not `use=local` as the brief assumed. So before any chat I switched it with `vikix ai use local`. For one test I also set `model=gemma3:1b`, and for others I wrote a temporary `~/.config/vikix/agent`. At the end I copied the original `ai` back (same sha256, `09b85ff…`) and removed `agent` (it hadn't existed before). The Emacs daemon's gptel default is back on Claude / claude-sonnet-5, as before. The user's two agent-shell sessions ("Claude Agent @ vukini", "@ Downloads") and their `*Claude*` and `*Local*` gptel buffers were left alone. `vikix changes` says "nothing has changed", but the snapshot history got two entries from me. See finding 3, which the user should know about.

The Emacs daemon had started at 21:21:15, during the 0.61 update, so `vikix-ai` was already loaded (`t`) and `C-c g/G/a/A` were all bound. I did **not** need to run `emacs-restart` (and running it would have ended the user's two live agent sessions, see finding 1).

Overall this works, and it's pleasant to use. The local chat answered in both editors, and Claude Code answered over ACP in Emacs in about 40 s, after one permission prompt. Every "missing" case gave a message instead of a traceback. The friction is in what happens around it: restarts, the snapshot history, a few messages that disagree with each other, and files dropped into the project.

---

## 1. After the update that brings the Emacs AI, nothing tells you to restart Emacs, and the restart ends your agent chats without asking

**What happened.** The updates that shipped and changed `vikix-ai.el` (0.59: "create mode 100644 config/emacs/vikix-ai.el"; 0.61: "config/emacs/vikix-ai.el | 90 +++") end their Emacs part with only:

    :: /home/vukini/.emacs.d is a clone; pulling
    :: editors ready: e (Emacs frame) v (Neovim)
    ...
    :: StumpWM reloaded: the new keys, bar and menu are in use

StumpWM is reloaded and says so. The Emacs daemon isn't restarted, and nothing says it needs to be. If it predates 0.59, `C-c a` and friends don't exist, and a user reading `docs/editors.md` finds `emacs-restart` only as "after you changed its config". `vikix doctor` doesn't check it either: it says "found emacs" and "~/.emacs.d is a git clone", and nothing about `vikix-ai` being loaded or agent-shell being installed.

Then `emacs-restart` (Vikix's, in `config/bash/vikix.bash`) refuses only when a *file* buffer is unsaved. On this machine there were two live agent-shell sessions and two gptel chats. None of those is a file, so `emacs-restart` would kill them all without a word. Now that Vikix puts agent conversations inside Emacs, those are what a user is most likely to have open.

**Expected.** The update says "Emacs has new AI keys: emacs-restart to use them" when `vikix-ai.el` changed and the daemon is older. `emacs-restart` warns before ending agent or chat sessions.

**How to see it.** `grep -i emacs ~/.local/state/vikix/logs/update-20260929-204704.log` (0.59). Then `emacsclient -e '(featurep (quote vikix-ai))'` on a daemon started before it. `type emacs-restart` shows the check covers only `buffer-file-name` buffers.

**Cost.** Everyone who updates past 0.59 with Emacs running hits it once, and it costs a "the keys the guide lists don't exist" moment. The restart can lose a long agent conversation (agent-shell keeps a transcript, see finding 4, but the session itself is gone).

**Suggestion.** In `45-editors`, when the daemon's start time is older than `vikix-ai.el`'s mtime, `say "Emacs is older than its AI setup: emacs-restart when you're ready"`. Or better, `emacsclient -e '(load "~/.local/share/vikix/emacs/vikix-ai" t t)'`, since the file is safe to load twice. In `emacs-restart`, list agent-shell and gptel buffers and ask before ending them, as it already does for unsaved files. Add a line to `vikix doctor`: "Emacs: Vikix's AI loaded / not loaded (emacs-restart)".

**In TODO?** No.

---

## 2. `vikix agent --acp NAME` with a misspelt name quietly starts Claude Code

**What happened.** `vikix agent --acp foo` printed

    :: your files haven't changed since snapshot b28c85b
    :: to see what the agent changed: vikix changes    to take it back: vikix undo

and started `claude-agent-acp` (exit 0 once stdin closed). `--acp` takes the name only when `is_agent` knows it. Otherwise the word is handed to your default agent as an argument. By contrast, `vikix agent --use foo` says `xx no agent called 'foo': claude opencode codex gemini aider`.

**Expected.** A typo like `--acp gemeni` in a user's own Zed or CodeCompanion config fails with the same "no agent called" message. It shouldn't start the paid agent.

**How to see it.** `vikix agent --acp foo </dev/null`.

**Cost.** Rare, but it's silent, it uses the agent that costs money, and it shows up in an editor where you can't see stderr.

**Suggestion.** In `main`, for `--exec|--acp`: if `$2` is non-empty, doesn't start with `-`, and isn't an agent, `die "no agent called '$2': …"`. Arguments for the agent can still follow a real name, or `--`.

**In TODO?** No.

---

## 3. Testing a setting while an agent chat opens records the test in the snapshot history, and `vikix snapshot --help` makes a snapshot called "--help"

**What happened.** I changed `use=local` temporarily, then opened a new agent chat with `C-c a`. `vikix agent --acp` snapshotted first, as designed: `4fe2dd5 … before an agent session (claude)`, now with `use=local` in it. After I put the file back byte for byte, `vikix changes` showed my restore as a change:

    -use=local
    +use=claude

Looking for how to record the current state, I typed `vikix snapshot --help`, and it answered

    :: snapshot ba36ad5: --help

`vikix history` now starts with `ba36ad5 … --help`, then `4fe2dd5`. **For the user:** a `vikix undo` right now would return `~/.config/vikix/ai` to `use=local` (4fe2dd5, my temporary state). `vikix undo ba36ad5` or simply leaving it is safe. I didn't try to remove the entries, because rewriting the history repo is worse.

**Expected.** `--help` on any subcommand shows help. For the first part, nothing is really wrong: the agent snapshot does its job. But it means "try a setting, open an agent, put the setting back" leaves a trap for `vikix undo`.

**How to see it.** `vikix snapshot --help; vikix history | head -2`.

**Cost.** `--help` is what people type to learn a command, so this bites often, and each time it adds junk to the history (and a checkpoint that `vikix undo` goes back to).

**Suggestion.** In `cmd_snapshot`, treat `-h|--help` (and any message starting with `-`) as a request for help. `vikix help snapshot` could print the three lines from `vikix help`. Optionally, `vikix undo` could print which files it will change and ask before doing it when run in a terminal.

**In TODO?** No.

---

## 4. agent-shell writes `.agent-shell/transcripts/*.md` into your project folder

**What happened.** Starting a chat with `C-c a` in a folder printed `Created agenttest/.agent-shell/transcripts/2026-09-29-21-40-30.md` in `*Messages*`, and the folder appeared. The user's own sessions have made `~/.agent-shell/transcripts/` and `~/Downloads/.agent-shell/`. In a git project this is a new untracked folder next to your code, with your whole conversation in it. The guide and `docs/ai.md` don't mention it, and nothing in Vikix ignores it.

**Expected.** Transcripts go somewhere of Vikix's, or at least the guide says where they are.

**How to see it.** `C-c a` from a dired buffer in any folder, then `find FOLDER -path '*.agent-shell*'`.

**Cost.** Every project you open an agent chat in. It's easy to commit by accident, and it may hold pasted secrets or code you didn't mean to publish.

**Suggestion.** In `vikix-ai.el`, set `agent-shell-transcript-file-path-function` to a function that returns `~/.local/state/vikix/agent-shell/<project>/<time>.md`. Or add `.agent-shell/` to a global git ignore that Vikix manages. Either way, one sentence in `docs/editors.md`.

**In TODO?** No.

---

## 5. The "what's missing" messages disagree with the terminal's, and Aider's names an M-x command instead of the key

With `agent=` pointed at each missing agent, `C-c a` said:

| agent= | `C-c a` in Emacs | `vikix agent --acp NAME` in a terminal |
|---|---|---|
| codex | `codex's ACP adapter isn't installed: in a terminal, vikix agent --install codex` | `codex isn't installed: Codex (OpenAI): your ChatGPT login, or local` / `to install it: vikix agent --install codex` |
| gemini | `gemini isn't installed: in a terminal, vikix agent --install gemini` | `gemini isn't installed: Gemini CLI (Google): your Google login; needs Node (vikix add javascript)` |
| opencode | (same form as gemini) | `opencode isn't installed: OpenCode: any model company, or local` |
| aider | `aider doesn't speak ACP: M-x vikix-ai-agent-terminal runs it in a terminal` | `Aider doesn't speak ACP: in an editor, run it in a terminal (vikix agent --use aider)` |

- For codex, Emacs blames the adapter when Codex itself is missing. `vikix-ai--agent-ready` checks only `codex-acp`. A user who reads "adapter" may think Codex is there.
- Aider's message points to `M-x vikix-ai-agent-terminal` when the key is `C-c A`. The guide's table uses the keys.
- The Emacs messages lose the one-line "what it is and how it signs in", which is the part that helps you choose.

**Cost.** Small, but these are exactly the messages a first-time user reads.

**Suggestion.** In `vikix-ai--agent-ready`, check the agent's own binary first ("codex isn't installed"), then the adapter. Say `C-c A` in Aider's message. Or have Emacs run `vikix agent --list`'s description for the name.

Also: `vikix agent --install claude` (already installed) says only `:: claude is already installed`, and `vikix agent --help` describes `--install` as "install one (its official installer…)". The guide's promise, "running it again for an agent you have adds only what's missing", is true, but nothing on screen confirms the adapter is there. Suggest `:: claude is already installed, with its ACP adapter` (or "…its ACP adapter added") and a word about adapters in the `--install` help line.

**In TODO?** No.

---

## 6. The first `C-c a` shows six red compiler warnings, then a question the guide doesn't explain

**What happened.** After agent-shell was installed from MELPA, `*Warnings*` held six entries like

    ⛔ Warning (native-compiler): agent-shell.el:6569:6: Warning: the function 'system-sleep-unblock-sleep' is not known to be defined.

These are harmless native-compile noise, but they're red and they pop up next to your first agent chat. Then, from a new folder, `C-c a` asked

    Start shell (default: New shell):
    New shell / New Downloads shell / New temp shell / Switch to shell buffer

The guide says `C-c a` is "a chat with your agent". It doesn't say that it reuses the session this folder already has (as `C-c a` from `*scratch*` did: it reopened the user's "Claude Agent @ vukini", 48k tokens in), or what "New Downloads shell" means (another session's folder).

**Cost.** Once per install for the warnings, and a moment's doubt each time the question comes up.

**Suggestion.** In `vikix-ai.el`, `(with-eval-after-load 'comp (add-to-list 'native-comp-async-report-warnings-errors 'silent))`, or set `warning-suppress-types` for `native-compiler`. In the guide, one line: "`C-c a` goes back to this project's chat if there is one; `C-u C-c a` (or the question it asks) starts another."

**In TODO?** No.

---

## 7. Typing in a gptel chat fills `*Messages*` with ispell backtraces

**What happened.** While I typed a prompt in the `*editors-test*` chat, corfu's auto-completion ran `ispell-completion-at-point` on each word and logged, many times over:

    Corfu detected an error:
      ...
      error("ispell-lookup-words: No plain word-list found at systemdefault locations.  Customize `ispell-alternate-dictionary' to set yours.")

There is no `/usr/share/dict/words` on this machine. Nothing visible broke, but it floods the log that the guide tells you to read when Emacs misbehaves ("the errors are in `*Messages*`"). It happens in the user's `*Claude*` buffer too.

**Cost.** In every gptel chat. It hides real errors.

**Suggestion.** This belongs to emacs-void's corfu setup, but Vikix can fix it on its side. Either install a word list with the emacs feature (a `words`-type package, if Void has one), or remove `ispell-completion-at-point` from `completion-at-point-functions` in `gptel-mode-hook` in `vikix-ai.el`.

**In TODO?** No.

---

## 8. gptel's menu offers 37 models, most of which can't answer here

**What happened.** `C-c G`, then `-m`, lists `Local:llama3.2:3b` first. Then come about 20 OpenAI models under **two** backends, `OpenAI:` and `ChatGPT:` (with prices), then `Perplexity:sonar`, and only then the 13 `Claude:` models, off the bottom of the screen until you type `Claude:`. `vikix ai key list` has only ANTHROPIC and PERPLEXITY keys, so every OpenAI/ChatGPT entry would fail. `vikix-ai--check` checks only Vikix's two backends ("one of yours is yours"), and gptel's menu isn't checked at all. The guide says the menu has "Claude, your local ones, and the config's own", which is accurate, but it doesn't warn that half of them need a key you don't have. The Claude list also includes long-retired models (claude-3-opus-20240229 and others).

**Expected.** The menu puts the two Vikix backends first, and the ones without a key are hidden or marked.

**How to see it.** `C-c G`, `-m`. Screenshots: `shots/editors-ai-emacs-models.png`, `shots/editors-ai-emacs-models-claude.png`.

**Cost.** Anyone who opens the menu to switch model. Choosing an OpenAI entry gives gptel's own error, not Vikix's helpful one.

**Suggestion.** In `vikix-ai.el`, after the backends are made, move Claude and Local to the front of `gptel--known-backends`. Drop (or don't register) the config's OpenAI/ChatGPT backends when no `OPENAI_API_KEY` is set. Or ask emacs-void to create them only when their key exists. Limit Claude's `:models` to current ones.

**In TODO?** Partly: TODO-editors decision 6 keeps "OpenAI and Perplexity kept as extras"; the no-key case isn't mentioned.

---

## 9. A missing model: good message, but the chat header changes, and the default stays broken afterwards

**What happened.** With `model=gemma3:1b` (not pulled), `C-c g` in the open chat said

    You don't have the model gemma3:1b: vikix ai models gets it, or change model= in ~/.config/vikix/ai

which is clear and exact. But the header had already switched to `[gemma3:1b]` (`shots/editors-ai-emacs-cg2.png`). `C-c RET` then answered anyway, silently on the buffer's `llama3.2:3b`, and the header flipped back. After the error, gptel's default stayed `gemma3:1b` (`(default-value 'gptel-model)`), so any gptel command other than `C-c g` (`gptel-send` in a normal buffer, `gptel-rewrite`) would use a model that isn't there until the next `C-c g`.

**Expected.** "Says what to type, and does nothing else" (the guide). So leave the default as it was when the check fails.

**Cost.** Low. It only matters after a typo in `model=`, but then the display lies for a moment.

**Suggestion.** In `vikix-ai--before-chat`, run the check before `vikix-ai-sync` commits the new default, or undo the sync when `vikix-ai--check` signals.

**In TODO?** No.

---

## 10. Neovim: the two chats look the same, and the agent's terminal opens in normal mode

**What happened.** `Space A` shows a clear which-key menu: `c Chat (vikix ai use: Claude or local)`, `g Chat with your agent (vikix agent)`, `q Ask about the code`, `t Your agent in a terminal`, and `p Open action palette`, which isn't in the guide's table (`shots/editors-ai-nvim-menu.png`). But `Space A c` and `Space A g` open identical windows: `## Me` and "Welcome to CodeCompanion ! Press ? for options". Nothing says which model or agent will answer until the reply comes back as `## CodeCompanion (Ollama)`. With `use=claude` on this machine, that's the difference between free and paid. Emacs shows `Local Ready … [llama3.2:3b]` in the header before you type (`shots/editors-ai-nvim-chat.png` vs `shots/editors-ai-emacs-chat.png`).

`Space A t` opened Claude Code in a split in **normal mode**, with line numbers down the side of the terminal (`shots/editors-ai-nvim-term.png`). I had to press `i` before its "trust this folder?" menu would take Enter. Emacs's `C-c A` (vterm) was ready to type at once.

The local chat took about 90 s for a one-line answer (433 tokens) in a folder with no `CLAUDE.md`. That fits the guide's warning.

**Suggestion.** Show the adapter and model in the chat's first line or winbar (CodeCompanion's `display.chat.show_settings = true`, or a `start_insert`/header option). Start the CLI terminal in insert mode with `number`/`relativenumber` off (a `TermOpen` autocmd in Vikix's `ai.lua`). Add `Space A p` to the guide's table, or leave it out of the menu.

**In TODO?** The speed is (TODO-editors part 3, "A local model is slow in CodeCompanion's chat"). The rest isn't.

---

## 11. The guide: the Info table drops "Neovim", and "three things" has four rows

- In `info vikix`, "AI in the editors" becomes a list where each row reads `'Space A c'` and then `Emacs: 'C-c g'`. The first column's label, **Neovim**, is lost, so a reader of the Info page doesn't know `Space A c` is Neovim's (`lib/md2texi.py`'s table conversion prefixes every column but the first). Suggest prefixing the first column too ("Neovim: 'Space A c'").
- "Both editors do the same three things", followed by a four-row table. Say "four", or merge the two agent rows.
- `docs/ai.md`'s "AI in Emacs" matches what I saw, keys and behaviour both. The guide's "Nothing starts or connects until you press a key" is also true: no adapter ran until `C-c a`, and each one went away when its buffer was killed or Neovim quit.
- `vikix ai use local` answers `Super+i now uses a model on this laptop: free, offline, the text stays here`. The guide says the editors' chats follow it too. Suggest "Super+i and the editors' chats now use…", so the connection is visible where you set it.

**In TODO?** No.

---

## 12. 0.58's MCP promise can't be seen from outside

`vikix mcp status` says `Claude Code has it; risky tools on: none` and the last five calls. Meanwhile nine `vikix-mcp serve` processes were running, the oldest started at 13:28, before four updates. The code re-execs on the next request when its files changed (`bin/vikix-mcp`, around line 514). Since `execv` keeps the PID and start time, a user can't tell whether the old servers will run the new code, and `status` doesn't say. I couldn't check it without driving one of the user's sessions. Suggest that `vikix mcp status` list the running servers with the version each last loaded (they could write it to a small state file on start and re-exec), for example "9 running, all on 0.61.0 at their next call".

**In TODO?** No.

---

## Smaller things

- agent-shell's welcome shows "Type *help* and press  for details." with a blank where the key's glyph should be, and CodeCompanion's "Welcome to CodeCompanion  !" has the same gap. The font lacks those symbols. Cosmetic.
- Every update in the logs (19:58 to 21:23, five of them) spends "a minute or two" rebuilding the docked Lazarus IDE and fails the same way each time: `!! the docked Lazarus IDE didn't build; see …/lazarus-build.log`. Outside this review, but it's the only `!!` in each update and it costs time on every run. Remember the failure and retry only when Lazarus or the recipe changes. Not in TODO.
- In `C-c a`'s one answer, Claude Code ran `ps -eo comm | grep …` behind a permission prompt instead of the vikix MCP `desktop` tool it has. That's fine, but it's one more "Yes" than it needed to be. This is TODO-editors part 5, "The Vikix MCP server … for the agents the editors start".

---

## What felt good

- **The keys are where the guide says, in both editors, and they mirror each other** (`C-c g/G/a/A` and `Space A c/q/g/t`). The which-key labels in Neovim say which setting each one follows ("vikix ai use", "vikix agent").
- **The local chat just works.** In Emacs: `C-c g`, name the buffer, type, `C-c RET`. The header shows `Local Ready [llama3.2:3b]`, and a one-sentence answer came in under 45 s. In Neovim, about 90 s. No key, no setup, nothing asked.
- **`C-c g` re-reads `~/.config/vikix/ai` each time.** A change in a terminal reached the open Emacs at once, as documented.
- **The missing-thing messages are specific and actionable**: the model name, the command to get it, and the file to edit instead. The agent ones name the exact install command. None of them started anything.
- **The agent over ACP is the real thing, with Vikix's safety rules.** A snapshot first, the "vikix changes / vikix undo" lines printed where the agent starts (in the ACP stderr buffer and at the top of `C-c A`'s terminal), permission prompts inline in the chat, and killing the buffer (`C-x k`) stopped the adapter cleanly. Each editor's session ended with its buffer: no stray `claude-agent-acp` was left behind.
- **`vikix agent --list`** is a good one-screen overview: which agents are here, how each signs in, which one `Super+a` starts, and a one-line recommendation.
- **The guide (`docs/editors.md`) is short, and it's right** about keys, file ownership, `vikix-ai.el`'s place and the language servers. It's also in `info vikix` with the same text.
