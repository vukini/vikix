# Everyday user: `vikix ai key` (2026-09-28)

Version checked: **0.40.0** in the dev checkout (`bin/vikix ai ...`). The installed `~/vikix` is 0.39.0 and doesn't have the command yet.

How I tested: I read README "API keys", docs/customize.md (shell) and the skill. All hands-on work ran in a throwaway home (`HOME=<mktemp -d> VIKIX_STATE=<it>/state`) with fake keys, and that home is now deleted. On the real home I only ran the read-only `vikix-ai key check`, plus a pattern test on one line that printed yes/no, never the value. Nothing under the real `~/.config/vikix/secrets` was read. The folder doesn't exist yet. None of these items are in TODO.md. TODO item 5 (`vikix debug` scrubbing keys) will reuse the same patterns, so findings 3 and 6 matter there too.

---

## 1. `vikix ai key set PATH` (or HOME) is accepted and breaks every new shell and the desktop session

**What happened.** `echo x | vikix ai key set PATH` printed ":: kept PATH ...", with no warning. After that, every new shell had `PATH=x`: `ls`, `grep`, `git`, `env` all gave "command not found". `HOME` was accepted the same way. `lib/secrets.sh` is also sourced by `bin/vikix-session`, so the next login would start the desktop with that PATH too. You can't fix it with `vikix ai key remove PATH`, because `vikix` can no longer be found. You need `/usr/bin/rm ~/.config/vikix/secrets/PATH`, typed in a shell that has lost its tools.

**Expected.** The command should refuse any name that isn't a key.

**How to see it.** `echo FAKE | vikix ai key set PATH`, then open a new terminal. (Only try this in a throwaway HOME.)

**Cost.** It takes a typo or an adventurous guess. The help says "or the variable itself", so `vikix ai key set DISPLAY` or `EDITOR` looks allowed. It's rare, but the result is a desktop that won't work plus a recovery a non-technical user can't do.

**Suggestion.** In `var_name`, accept a variable name only if it ends in `_KEY`, `_TOKEN` or `_SECRET`, and refuse anything else with "that isn't a key's name". Belt and braces: `secrets.sh` could also skip `PATH`, `HOME`, `SHELL`, `USER`, `DISPLAY`, `LD_*`, `XDG_*`.

## 2. `vikix doctor` says "no API keys in your files" on this machine, but a literal key sits in `~/.profile`

**What happened.** On the real home, `vikix-ai key check` printed ":: no API keys in your files or their history". But `~/.profile` line 5 is `export PERPLEXITY_API_KEY=<literal value>`. It matches the check's own pattern, and new shells here really do get that variable. The check only looks at files listed in `config/yours.list`, and `~/.profile` isn't one of them. My fish-config test was missed the same way.

**Expected.** The README says doctor "looks for keys left where they shouldn't be: in any of your files". A user reads "no API keys" as an all-clear. Strictly, `~/.profile` isn't in the snapshot history, so it isn't kept "for ever". But it is in every restic backup, and it's exactly where people put keys.

**How to see it.** `bin/vikix-ai key check` on this machine, then `grep -c '_API_KEY=' ~/.profile`.

**Cost.** This affects the person who wrote the feature, which suggests it's common. The false all-clear is worse than no check at all.

**Suggestion.** Also scan the usual startup files that aren't in yours.list (`~/.profile`, `~/.zshrc`, `~/.zprofile`, `~/.config/fish/config.fish`, `~/.xprofile`) and give them their own advice ("not in the history, but in your backups: move it"). Or make the all-clear say what it covered: "no API keys in the files Vikix keeps history for (~/.bashrc, ...)".

## 3. A key in a `~/.bashrc` that links into a dotfiles repo gets the wrong advice

**What happened.** On this machine `~/.bashrc` is a symlink to `~/.dotfiles/bash/.bashrc`, and `~/.dotfiles` is a git repo. When I recreated that setup with a fake key, the check followed the link, which is good. But it says "in ~/.bashrc, line 1 ... delete that line from the file, and take a snapshot". That doesn't mention that the real file sits in another git repo, whose history now holds the key and which may have been pushed somewhere public.

**Expected.** The check should name the real file, warn that a git repo there has the key in its history, and say that if it was ever pushed, you should replace the key at once.

**Cost.** Anyone with a dotfiles repo, which is common among people who hand-edit `.bashrc`. The leak it misses is the serious kind.

**Suggestion.** When the file is a symlink, print `~/.bashrc (a link to ~/.dotfiles/bash/.bashrc)`. If `git -C <dir> rev-parse` works there, add one line: "that folder is a git repository: the key is in its history, and on any remote you pushed to. Replace the key."

## 4. The README's example `open-router` doesn't give the variable it names

**What happened.** The README says "any name works: open-router, OPENROUTER_API_KEY". `vikix ai key set open-router` stores `OPEN_ROUTER_API_KEY`, which OpenRouter tools won't read. Only `openrouter` or `OPENROUTER_API_KEY` works.

**How to see it.** `echo x | vikix ai key set open-router; vikix ai key list`

**Cost.** Anyone following the README example gets a key that silently does nothing.

**Suggestion.** Fix the README line to "openrouter → OPENROUTER_API_KEY". Also, `set` could print "programs will see it as OPEN_ROUTER_API_KEY" whenever the variable name differs from what was typed.

## 5. A misspelt service name is kept without a word

**What happened.** `vikix ai key set antropic` printed ":: kept ANTROPIC_API_KEY". No tool reads that variable, and the user believes their Anthropic key is set. Overwriting an existing key is silent too: setting `anthropic` twice gives the same "kept" message.

**Expected.** Something like "ANTROPIC isn't a service I know; did you mean anthropic?", and "replaced ANTHROPIC_API_KEY (set 2026-09-20)" on a second set.

**Cost.** Typing "anthropic" wrong is easy, and the result is a long "why doesn't it work" hunt.

**Suggestion.** Keep a short list of known services (anthropic, openai, gemini, openrouter, groq, mistral, perplexity, deepseek, xai, together, huggingface). For a lowercase name not on the list, warn but still keep the key. Print "replaced" when the file already existed.

## 6. `key check` misses common key shapes (tokens), and its advice could be one step shorter

**What happened.** The check caught `sk-ant-...`, `sk-proj-...`, `sk-or-...`, `AIza...` and `gsk_...` whenever they were assigned to a `*_API_KEY` variable. It rightly ignored `$(pass show ...)`. It missed `export HF_TOKEN=hf_...` and `MY_TOKEN=ghp_...` (GitHub), because only `*_API_KEY=` and `sk-` count. The advice itself was clear and worked when I followed it: move, delete the line, snapshot, then the `mv ... && vikix snapshot` fresh start, then the check turned green. The rough edges:
- "Move it: vikix ai key set anthropic (or openai, ...)". The line says which variable it is, so the check could name the exact command.
- "paste it there" leaves the user to copy the key out of the file by hand. A `vikix ai key move FILE LINE` (or an offer to do it) would remove the step where people make mistakes.
- Before the fresh start there's a "take a snapshot" step. That snapshot then shows up as "a key is in ... snapshots 728e460 6327e03", even though 728e460 is the snapshot where the key was *removed*.
- The fresh start throws away all undo history. The advice doesn't say so ("vikix undo can't go back before today"), although that is the real cost of following it.
- After the fresh start, doctor goes green even though `yours.git.with-key` still holds the key. It could remind the user until that folder is deleted.

**Suggestion.** Add `[A-Z_]*_TOKEN=` literals and `ghp_`/`github_pat_`/`hf_` prefixes to `KEY_PATTERN`. Name the variable in the advice. Add one line about losing the older snapshots. Make the check notice `yours.git.with-key`.

## 7. A multi-line paste at the hidden prompt keeps only the first line; the rest goes to the shell

**What happened.** On a pty, pasting `sk-ant-api03-FAKE⏎PART2⏎` stored only `sk-ant-api03-FAKE` and printed "kept". In a real terminal, `PART2` would then be run as a command at the prompt and saved in `~/.bash_history`, which backups include. That's half a key in the history this feature was built to avoid. Keys copied out of wrapped web pages or emails sometimes carry a line break.

**Suggestion.** For Anthropic and OpenAI, warn when the key is shorter than their keys usually are ("that looks short: only 17 characters; was it cut?"). After storing, show a fingerprint, such as `sk-ant-…cdef (108 characters)`, so the user can check it against the console. `list` could show the same, which also answers "is this the new key or the old one?" (today `list` only shows a date).

## 8. Smaller wording and usability points

- **`vikix ai help` mentions `lib/secrets.sh`**. That's a source-file path a user can't act on. "Every new terminal and the desktop session have the keys" says the same thing.
- **"This one: exec bash"** is fine for terminal users. "To use it in this terminal now, type: exec bash" is clearer to others.
- **"The desktop's programs (Emacs), from the next login."** A user who set a key for gptel in Emacs has to log out. Offer a way now: `vikix ai key set` could push the variable into the running Emacs daemon (`emacsclient -e '(setenv ...)'`) and StumpWM (`vikix eval '(setf (getenv ...))'`), or at least say what to do.
- **Ctrl-D at the prompt** exits with status 1, no message and no newline. The next prompt then lands on the same line. "nothing kept" would be clearer.
- **`vikix ai key remove`** with no name says "For example: vikix ai key set anthropic". The example should be `remove`.
- **`vikix ai key sett`** says "set NAME, list, remove NAME or check": clear enough. `vikix ai keys` says "unknown command keys". Accepting `keys` as an alias, or suggesting `key`, would be friendlier.
- An Anthropic key pasted under `openai` gets no warning: `sk-ant-` passes the `sk-*` check. "that looks like an Anthropic key" would catch the swap.
- **`vikix ai key list` with a typo'd or odd entry** gives no hint. Once the known-services list from finding 5 exists, `list` could mark unknown names.

## 9. Claude Code and ANTHROPIC_API_KEY: explained, but only once, and there's no way back

The `set` message and the README both say Claude Code "asks once whether to use it instead of your login; using it bills the key's account". That's the right warning, and good that it's in the output itself. What's missing:
- **How to change your answer later.** A user who pressed "yes" by accident is now billed per token and doesn't know where the choice lives. It's stored in `~/.claude.json`, and `/logout` / `/login` or `/status` inside Claude Code show or change it. One line in the README would help.
- **Why you'd set it at all when you have a plan.** Most people setting `anthropic` want it for another tool (llm, aider, gptel), not Claude Code. The README could say: "If you only use Claude Code with your subscription, you don't need this key; if you set it for other tools, answer *No* when Claude Code asks."
- `vikix agent` could check for this and mention it once, since it's the Vikix path into Claude Code.
- The skill (SKILL.md) is good: never ask for a key, never read secrets/, tell the user to run `set`. It doesn't tell the agent what to say when the user asks "why does Claude Code bill my API account?". One sentence would cover it.

---

## What felt good

- **The idea and the defaults are right**: one file per key, folder 700 and files 600, written atomically through a temp file, and never in snapshots (even if yours.list names it, with a warning).
- **The hidden prompt** "ANTHROPIC_API_KEY (it won't show as you paste it):" tells a non-technical user exactly what to expect.
- **Piped input works** for `pass show ... |`, and trailing newlines and spaces are removed.
- **`list` never shows values**, and it has a helpful empty state ("no keys kept (vikix ai key set anthropic)").
- **`remove` tells the truth**: "Shells and programs started before now still have it until they end."
- **The check never prints the key**, only file and line. It ignores `$(pass show ...)` and `$VAR` lines, finds commented-out keys, follows the `~/.bashrc` symlink, and looks into the history as well as the files.
- **The history advice is safe**: the old history is set aside, not deleted, and the text says to check `vikix history` before removing it. The advice also reminds the user that a leaked key should be replaced, not just moved.
- **Wrong-command messages** name the valid choices and point to `vikix ai help`.
- **The docs are consistent**: the README section, the one-line customize.md warning and the skill agree on names, paths and commands, apart from the `open-router` example.
