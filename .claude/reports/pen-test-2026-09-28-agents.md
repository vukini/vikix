# Pen test: "any agent" (Vikix 0.49.0, commit a0203a3), 2026-09-28

**Scope:** `bin/vikix-agent`, and where it hooks into the rest of Vikix:
- `bin/vikix`: agent dispatch, doctor, snapshots;
- `install/40-config.sh` (`--write-guide`);
- the agent lines in `features.list`, as run by `bin/vikix-features` `feature_cmd`;
- `config/yours.list`;
- `tests/agents.sh`.

I compared all of this with the old `cmd_agent` (`git show a0203a3^:bin/vikix`).

**Threat model:** a single-user laptop. The attackers that matter are:
- an agent acting on a prompt injection;
- another program running as the user;
- another local UID reaching loopback;
- the user expecting a safety net that isn't there.

**Method:**
- Read the code.
- Ran PoCs in throwaway `HOME`s under `mktemp -d`, with stand-in `curl`/`npm`. Nothing was downloaded and no real installer ran.
- Inspected the installed layouts in `/home/vukini/.claude/jobs/9e7c4573/tmp/realhome`.
- Read the vendors' installer scripts over HTTPS.
- On the real machine I only looked: `stat`, `ss -ltnp`, `/proc/<stumpwm>/cwd`, and the *names* of environment variables. I printed no key values and read nothing in `~/.config/vikix/secrets`.
- Changed no repository file other than this report.

---

## 1. HIGH (chain suspected, each link confirmed): any agent can use the author's SSH key, so a prompt injection can push to github.com/vukini/vikix, and every Vikix machine then runs that push

**Who, and what they gain:** a prompt injection in any of the five agents (a web page, an issue, a README the agent reads). It gets push access as the Vikix author. Every installed machine pulls `main` unverified on `vikix update`, and runs the stages under the sudo that the update asks for.

**Evidence:**
- `bin/vikix-agent:258-262`: only `*_API_KEY|*_KEY|*_TOKEN|*_SECRET` are dropped, so `SSH_AUTH_SOCK` reaches every agent.
- `bin/vikix-session:46-47` starts one `ssh-agent` for the whole session.
- `~/.ssh/config:5` has `AddKeysToAgent yes`. After the author's first push of the session, the unlocked key stays in the agent with no further prompt.
- This machine: `SSH_AUTH_SOCK` is set. The dev checkout's remote is `git@github.com:vukini/vikix.git`.
- `bin/vikix` `git_pull`/`cmd_update` pulls and runs the stages. Nothing verifies commit or tag signatures (grep finds no `verify-commit`/`verify-tag`/gpg).
- OpenCode allows `bash`, `edit` and `webfetch` without asking by default (https://opencode.ai/docs/permissions/: "Most permissions default to "allow""). So with `--default opencode`, Super+a gives the injection a shell with no prompt at all. Claude Code, Codex and Gemini ask first by default, but a `git push` inside a longer command is easy to approve.

**Not a regression:** the old `cmd_agent` passed `SSH_AUTH_SOCK` to `claude` too. What 0.49.0 adds is one agent that runs without approval, and four more agents that could be the target.

**Fix:**
- `bin/vikix-agent` `start()`: add `-u SSH_AUTH_SOCK` to `unset` unless `VIKIX_AGENT_SSH=1`, which should be documented in the header and the skill. An agent that must push for the user can be started with it.
- Author side:
  - load the push key with confirmation (`ssh-add -c`, which needs `ssh-askpass`), or use a separate GitHub key kept out of `ssh-agent`;
  - protect `main` on GitHub and require signed commits, with the signing key not in the session agent.
- Longer term, `vikix update`: pull only signed release tags (`git verify-tag` against an `allowed_signers` file shipped in the repo).
- OpenCode: see finding 4.
- No migration needed: `bin/vikix-agent` is linked.

---

## 2. MEDIUM (confirmed): `DRY_RUN=1` downloads and runs the real installers

**Who, and what they gain:** anyone previewing with `DRY_RUN=1 vikix add codex`, and any future test or CI dry run that adds an agent feature. A remote script runs, and an agent gets installed, when the user asked for a preview. This breaks the rule in CLAUDE.md that every system change goes through `run`.

**Evidence:**
- `bin/vikix-agent:127-151`: the `curl | bash`, `npm install` and `uv tool install` lines are not behind `run` or a `DRY_RUN` check.
- `bin/vikix-features:30-37`: `feature_cmd` passes `vikix agent --install NAME` through with `DRY_RUN` exported. It says "does its own dry run", but this one doesn't.
- PoC (stand-in curl that emits a script which logs itself):
  ```
  $ DRY_RUN=1 VIKIX_CURL=$T/bin/curl VIKIX_UV=/nonexistent bash bin/vikix-agent --install aider
  :: installing aider: ...
  $ cat $T/calls
  curl -LsSf https://aider.chat/install.sh
  INSTALLER EXECUTED: sh
  ```

**Fix (`bin/vikix-agent` `install_agent`), at the top:**
```bash
if [ "$DRY_RUN" = 1 ]; then printf '   would install %s with its official installer\n' "$name"; return 0; fi
```
- Add a check to `tests/agents.sh`: `DRY_RUN=1 agent --install codex` must leave `$calls` empty.
- No migration needed.

---

## 3. MEDIUM (confirmed): the API-key policy leaks in four places

**Who, and what they gain:** installer code, and agents. They see keys that the policy says they shouldn't: silent billing, and a key copied into a transcript or sent out by an injection.

### a) The installers run with every key
`install.sh:75` runs `drop_keys` because "the stages run others' code (npm, uv, Quicklisp)". `vikix agent --install`, the "Install it now?" prompt in `start()`, and `vikix add <agent>` all run `curl | bash`, npm lifecycle scripts for all of gemini-cli's dependencies, and uv, with every key in the environment.

PoC with a stand-in npm that records variable *names* only:
```
vars the installer saw: GH_TOKEN  OPENAI_API_KEY  PERPLEXITY_API_KEY  DEMO_API_KEY  CLAUDE_CODE_MESSAGING_TOKEN
```
`grep drop_keys` finds it only in `bin/vikix:158` (update) and `install.sh`, not in `bin/vikix-features` or `bin/vikix-agent`.

### b) The agent gets the keys back from any interactive bash
`config/bash/vikix.bash:45-47` sources `lib/secrets.sh` in every interactive shell. An agent that runs `bash -i`, or opens a PTY shell (as some agents do), has every key again.

PoC (throwaway `HOME`, fake key):
```
$ env -u DEMO_API_KEY bash -i -c '. config/bash/vikix.bash; echo $DEMO_API_KEY'
after interactive shell: DEMO_API_KEY=fake-not-a-key
non-interactive: <unset>
```
The agent can also simply `cat ~/.config/vikix/secrets/*`, since it runs as the same user. So the drop prevents accidents; it is not a boundary. The header comment ("so a key isn't ... shown by `env`") promises more than that.

### c) Agents started any other way get every key
Typing `claude`, `codex`, `opencode` or `gemini` in a Vikix shell (not `vikix agent`) passes every key. OpenCode picks up provider keys from the environment by itself.

Evidence: this very Claude Code session, which was not started through `vikix agent`, has `OPENAI_API_KEY` and `PERPLEXITY_API_KEY` in its environment (names checked, values not read).

### d) The pattern misses common secret names
It misses `*_PASSWORD`, `*_PASS`, `*_CREDENTIALS`, `DATABASE_URL`, `AWS_ACCESS_KEY_ID` (ends `_ID`), and lower-case names. That is fine for keys Vikix itself exports (same patterns as `lib/secrets.sh`), but not for keys the user exports in `~/.bashrc`.

### Fix
- `bin/vikix-agent`:
  - run each installer in a subshell that calls `drop_keys` first: `( drop_keys; "$CURL" -fsSL … | bash ) || die …`. A bare `drop_keys` would also strip Aider's keys later in `start()`.
  - `bin/vikix-features` `cmd_add` can call `drop_keys` once as well.
- `bin/vikix-agent` `start()`: export `VIKIX_AGENT=$name` to the agent. `lib/secrets.sh` then returns early when `VIKIX_AGENT` is set and `VIKIX_AGENT_API_KEY` isn't 1 (keep Aider's list). Interactive shells inside an agent then stay keyless.
- `config/bash/vikix.bash`: add small functions `claude`, `codex`, `opencode` and `gemini` that run `vikix agent --use NAME -- "$@"`, or at least `env -u` the keys. Then the policy holds however the agent is started. (The earlier `pen-tester-2026-09-28-ai-key.md` #3 asked for this for `claude`.)
- Extend the patterns to `*_PASSWORD|*_PASS|*_CREDENTIALS|*_PAT|DATABASE_URL|AWS_ACCESS_KEY_ID`, in both `drop_keys` (`lib/common.sh`) and `start()`. Better: make one shared function, so the two lists can't drift.
- Header and skill: say plainly that this stops accidents, not a determined agent.
- All of these files are linked, so no migration is needed.

---

## 4. MEDIUM (confirmed from OpenCode's docs): Super+a can start an agent that asks nothing, in `$HOME`

**Who, and what they gain:** a prompt injection reaching an OpenCode session (a web page it fetches, a file it reads). It gets command execution and edits across the whole home with no approval: `.bashrc`, `~/.ssh/config`, agent configs, and `git push` (finding 1).

**Evidence:**
- `config/stumpwm/vikix/commands.lisp:52` runs `alacritty -e vikix agent`. StumpWM's cwd is `/home/vukini` (`readlink /proc/1541/cwd`), so every agent starts with `$HOME` as its workspace.
- OpenCode's defaults: `edit`, `bash` and `webfetch` are `allow`; only `external_directory` is `ask`.
- The other agents differ:
  - Codex treats the whole of `$HOME` as its workspace (suspected: it asks whether to trust the folder);
  - Aider in `$HOME` offers to `git init` the home folder and auto-commits its edits there.

**Fix:**
- `bin/vikix-agent`: when starting OpenCode without `--local`, and the user's `~/.config/opencode/opencode.json` has no `permission` key, pass
  `OPENCODE_CONFIG_CONTENT='{"permission":{"bash":"ask","edit":"ask","webfetch":"ask"}}'`.
  With `--local`, merge this into the JSON already built there with `json.dumps`. Say so in `--list` and the skill, with the opt-out: set `permission` in your own config.
- Start agents in a working folder rather than `$HOME`: `~/dev` if it exists. In `vikix-agent`, `cd` before `exec` when the cwd is exactly `$HOME`, and print that it did.

---

## 5. LOW (confirmed): the snapshot safety net doesn't cover the files an agent would use to persist

**Who, and what they gain:** an agent, or an injection through it, that wants to survive the session unseen. `vikix changes` shows nothing, and `vikix undo` doesn't take it back.

**Evidence:** `config/yours.list` covers `.bashrc`, `.config/vikix/*` and the WM configs. It does not cover:
- `~/.claude/settings.json` (hooks: code on every Claude Code event);
- `~/.codex/config.toml`;
- `~/.gemini/settings.json` (MCP servers, auto-approve);
- `~/.config/opencode/` (plugins run as code);
- `~/.aider.conf.yml`;
- the Vikix checkout itself, e.g. `~/vikix/config/claude/skills/vikix/SKILL.md`. That file becomes the guide that every agent reads at every start (`write_guide`), until `vikix update` stashes the local change.

The header of `bin/vikix-agent` promises "whatever it changes can be seen with vikix changes".

**Fix:**
- `config/yours.list`: add the settings *files* by name, never whole folders, because the folders hold login tokens (`~/.codex/auth.json`, `~/.gemini/oauth_creds.json`, `~/.local/share/opencode/auth.json`, `~/.claude/.credentials.json`):
  - `.claude/settings.json`
  - `.claude/CLAUDE.md`
  - `.codex/config.toml`
  - `.gemini/settings.json`
  - `.config/opencode/opencode.json`
  - `.aider.conf.yml`
- In `bin/vikix` `yours_exclude`, also exclude those credential files by name, in case a future line names a folder.
- `vikix doctor`: warn when `git -C "$VIKIX_DIR" status --porcelain` is not empty ("Vikix's own files were changed; vikix update will set them aside").
- Reword the header to "your files (config/yours.list)".
- `yours.list` is read from the checkout, so no migration is needed.

---

## 6. LOW (confirmed from Gemini's docs): Gemini's memories are written into the shared guide, reach Codex and Aider, and are then silently lost

**Who, and what they gain:** an injection through Gemini's `save_memory`. Until the next `vikix agent` start, Codex (via `~/.codex/AGENTS.md`) and Aider (`--read`) take the text as their instructions. For the user, it is data loss: `write_guide` replaces the file on every start, so Gemini's "remembered" facts disappear.

**Evidence:**
- `link_guide` (`bin/vikix-agent:98-112`) makes `~/.gemini/GEMINI.md` a symlink to the one shared `AGENTS.md`.
- Gemini CLI's `save_memory` appends a "## Gemini Added Memories" section to the global `~/.gemini/GEMINI.md` (https://geminicli.com/docs/tools/memory/). Node's write follows the link.

Related hardening in the same function:
- `ln -s` without `-T` follows a directory symlink planted between the `[ -e ]` check and the `ln`;
- `write_guide` writes a fixed `$GUIDE.new`, which follows a symlink placed there.

Both need write access to the user's own folders, so they are informational.

**Fix:**
- For Gemini, write a small *regular* `~/.gemini/GEMINI.md` that Vikix owns. Mark it with a first-line comment, and have it import the guide (`@~/.local/share/vikix/AGENTS.md`, supported by Gemini's import syntax). Memories then append to that file, and the guide stays clean. `unlink_guide` then recognises the marker rather than the link.
- Use `ln -sT`.
- In `write_guide`, use `tmp=$(mktemp "$GUIDE.XXXXXX")`.
- A migration would replace existing `~/.gemini/GEMINI.md` links that point at the guide.

---

## 7. LOW (suspected): Local Ollama can be redefined by any local UID, and then drives a `--local` agent

**Who, and what they gain:** another local UID (on this laptop, only system daemons), or anything that binds 11434 while Ollama is down. It answers as "the model", and so chooses the tool calls of the OpenCode, Codex or Aider session: commands as the user, subject to each agent's approvals.

**Evidence:**
- `ss -ltnp`: `127.0.0.1:11434 ollama` runs as `vukini`, with no authentication. Any local UID can `POST /api/create`, replacing `qwen2.5-coder:7b` with a model that has a hostile `SYSTEM` prompt.
- `local_model` (`bin/vikix-agent:199-212`) trusts `/api/tags`, and falls back to `head -1` of it.

What is fine here: the model name cannot inject.
- It is checked with `grep -qxF` against that list.
- It is passed as its own argv element (`-m "$model"`), prefixed for Aider (`ollama_chat/…`).
- For OpenCode, it is JSON-encoded with `json.dumps`, so there is no JSON injection.

**Fix:** mostly in `bin/vikix-local-ai`:
- run Ollama on a Unix socket, or behind a token if Ollama gains one;
- `vikix doctor`: check that the listener on 11434 belongs to the user's `ollama` (`ss -ltnp` owner) before `--local` uses it.

It is low on a single-user laptop.

---

## 8. LOW (confirmed/suspected): uninstall deletes more than it installed, and install replaces a link of yours

**Who, and what they gain:** the user, by accident, or a hostile environment (which already means code running as the user). The result is lost files.

**Evidence (`bin/vikix-agent`):**
- `:166`: `rm -rf "$HOME/.opencode"`. That folder also holds OpenCode's plugin `package.json`/`node_modules` (seen in the throwaway home), and suspected, any agents, commands or plugins the user put there. Nothing is kept as `.vikix-bak`, contrary to the ownership rule.
- `:169`: `rm -rf "${CODEX_HOME:-$HOME/.codex}/packages/standalone"`. `CODEX_HOME` comes from the environment unchecked (relative, `/`, or someone else's folder). The effect is bounded by the fixed `packages/standalone` suffix.
- `:165`, `:168`: remove *any* symlink named `~/.local/bin/opencode` or `codex`, including npm's `codex` link, not only Vikix's.
- `:133-134`: `ln -sfn` replaces any existing `~/.local/bin/opencode` symlink of the user's.

**Fix:**
- For OpenCode, remove only `~/.opencode/bin`. Or move the whole folder to `~/.opencode.vikix-bak.<time>`.
- Remove the `~/.local/bin` links only when `readlink` points into `~/.opencode/bin` or `$CODEX_HOME/packages/standalone`.
- Require `CODEX_HOME` to be absolute and under `$HOME`. Otherwise refuse, and say where Codex's files are.
- Create the OpenCode link only when there is none.
- No migration needed.

---

## 9. LOW: installer integrity is only as strong as the vendor's TLS endpoint

**Who, and what they gain:** a compromise of a vendor's download host or release pipeline, or a truncated download. The result is code as the user.

**Evidence (installer scripts read over HTTPS):**
- **OpenCode:** `opencode.ai/install` redirects to `raw.githubusercontent.com/anomalyco/opencode/refs/heads/dev/install`, a moving branch. It verifies no checksum or signature of the binary.
- **Codex:** `chatgpt.com/codex/install.sh` redirects to `releases.openai.com`. It checks SHA256SUMS fetched from the same host, which protects against corruption only.
- **Claude Code:** `claude.ai/install.sh` redirects to `downloads.claude.ai`. It checks a checksum from the same host's manifest and refuses to run under sudo.
- **Aider:** the fallback `aider.chat/install.sh` is a uv 0.5.9 installer that reports "no checksums to verify". The main path, `uv tool install aider-chat@latest --with pip`, is unpinned.
- **Gemini:** `npm install -g @google/gemini-cli` is unpinned and runs dependency lifecycle scripts.
- `curl … | bash` starts running before the download ends. With `pipefail`, a failed `curl` is noticed, but only after the partial script has run.

What is fine:
- all URLs are HTTPS, and `-f` stops on HTTP errors;
- no sudo is used anywhere;
- rc files are left alone: OpenCode is given `--no-modify-path`, Aider's fallback `UV_NO_MODIFY_PATH=1`, and the Codex installer finds `~/.local/bin` already on `PATH`.

**Fix (`bin/vikix-agent` `install_agent`):**
- download to `mktemp` and run it with `bash "$tmp"` only when curl succeeded. This makes truncation impossible.
- run the installers without keys (3a).
- where the vendors allow it, pin a version that Vikix updates deliberately (OpenCode accepts a version, Codex a release, npm `@google/gemini-cli@X.Y.Z`, uv `aider-chat==X.Y.Z`).
- note in the README row that these installers are the vendors' own and unverified by Vikix.

---

## 10. INFORMATIONAL: the default agent is chosen by a file the agent can edit

`~/.config/vikix/agent` is the user's file, and an agent can change it. Switching it to `aider` hands Aider's kept keys to the next Super+a; switching it to `opencode` gets the no-approval agent from finding 4. If the new choice isn't installed, the next Super+a offers to install it.

The parsing is safe:
- `sed` keeps only `[a-z]*`;
- `is_agent` matches the fixed list with `grep -qx`;
- the file is in `yours.list`, so the change shows in `vikix changes`.

**Fix (optional):** Super+a can print the default, and when it was set, before starting. It can also ask once when the default was changed since the last snapshot.

## 11. INFORMATIONAL: installs happen before the snapshot

The order is `start()`: install, then `write_guide`/`link_guide`, then snapshot. It is the same order as the old `cmd_agent`, so not a regression. Any file an installer changed ends up inside the "before an agent session" snapshot, and `vikix add <agent>` never snapshots at all. Today the installers leave `yours.list` files alone (see 9), so this has no effect. A `vikix snapshot "before installing $name"` at the top of `install_agent` would keep it that way. A failed snapshot stops the start (`set -e`), which is correct.

---

## Checked and fine

- **Agent names:** validated against the fixed list at every entry (`--use`, `--install`, `--uninstall`, `--default`, and `chosen()`). An unknown name dies (`tests/agents.sh` covers `vscode`).
- **Keys stay out of argv and logs:**
  - keys go only through the environment and `env -u`; none is in argv or printed;
  - `vikix-agent` writes no log;
  - `AGENTS.md` is built only from `SKILL.md`, which has no user data;
  - `~/.config/vikix/secrets` stays excluded from snapshots (`yours_exclude`, `yours_stage`) and is mode 700.
- **Arguments and JSON:** `OPENCODE_CONFIG_CONTENT` is built with `json.dumps` from argv, so there is no JSON or shell injection. Model names go in as their own argv elements.
- **Local runs:** `--local` drops every key, Aider's included. `claude` and `gemini` refuse `--local`.
- **Guide links:** `link_guide` never replaces an existing file or link, and `unlink_guide` removes only a link that points at the guide.
- **Feature commands:** `feature_cmd` splits with `read -a` and has no `eval`. The agent lines in `features.list` are static.
- **Tests:** `tests/agents.sh` isolates `HOME` and `VIKIX_STATE`, unsets `CODEX_HOME`, `GEMINI_CLI_HOME`, `XDG_*` and `VIKIX_AGENT_API_KEY`, stubs curl, npm, uv and node through `VIKIX_CURL`/`VIKIX_NPM`/`VIKIX_UV`, and sets `VIKIX_SWANK_PORT=9`.
- **Regressions:** compared with the old `cmd_agent`, key dropping widened from `ANTHROPIC_API_KEY` only to all key-shaped names, which is better. The snapshot still comes before `exec`. I found no regression.
- **File modes:** home is 700. `AGENTS.md` is 644 inside it. Aider's history files are 644 inside a 700 home.
- **`40-config`:** runs `--write-guide` as the user, not under sudo, and it respects `DRY_RUN`.
