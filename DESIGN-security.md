# Vikix Security — the plan

What could go wrong, in order of how much it matters, and what closes each gap. Drafted 2026-10-04 from the pen-tester's four reports (2026-09-28 and 29: the agents, `vikix debug`, the MCP server, `vikix ai key`), TODO "to look into" items 4 and 5, and the code as of 0.71.129. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## Who we are defending against

Vikix's position is unusual: it invites an AI agent onto the desktop and gives it tools. So the list of adversaries starts somewhere most desktops' lists don't.

1. **A prompt-injected agent.** The agent reads a web page, a log, a window title or a note that tells it to do something, and it has `vikix eval`, the MCP tools, a shell and your files. This is the main adversary, and it is on the machine by invitation.
2. **An upstream that changes under us.** `vikix update` pulls `main`; installers fetch from release pages and moving branches; a compromised or mistaken upstream runs with sudo on every machine.
3. **Another process on this machine.** The Windows VM (now on its own bridge), a sandboxed program, another local user, anything that can reach loopback.
4. **The laptop itself, lost or picked up.** Disk encryption, the lock screen, the backup password.
5. **What leaves the machine.** Agents, package fetches, Dropbox, the agent's logs: not an attacker, but the site promises "nothing left the laptop" and should be able to prove it.

## Where things stand (from the code, 2026-10-04)

Done since the reports: the SSH agent is withheld from agents (`vikix-agent` unsets `SSH_AUTH_SOCK` unless `VIKIX_AGENT_SSH=1`, 0.51.1); `drop_keys` clears API keys in the installer, `vikix update` and the agents' installers; Swank has a password and a guard; the Windows VM moved from passt to its own bridge so it can't reach loopback; `vikix lock` pauses dunst; the MCP server's `set_theme` name problem and the exit on bad input were fixed in later releases; `vikix firewall` is on from the start with only SSH in; the record store and the docs index are 600.

Still open, by adversary:

| # | Gap | Adversary | From |
|---|---|---|---|
| A | `vikix update` pulls `main` unchecked and runs stages with sudo | 2 | TODO 4 |
| B | Installers from moving targets: `aider-chat@latest`, OpenCode's branch, npm and uv `@latest`; checksums only from the download's own host | 2 | TODO 4 |
| C | No allow-list on what an agent may run through `vikix eval`, the MCP `eval`, or the new doors (Cuis 4005, the music socket) | 1 | IDEAS "Leaning into Lisp" |
| D | `vikix debug`'s report carries web-page text (injection into the agent that reads it), URLs and paths (privacy), and secrets the scrubber misses | 1, 5 | debug report, items 1–3 |
| E | The secrets folder exports any variable name; its changes are hidden from `vikix changes`; symlinks are followed | 1 | ai-key report, items 2, 6 |
| F | No rate limit on the MCP `notify`; `vikix doctor` silent about `--allow-eval` being registered | 1 | TODO 5 |
| G | Nothing says whether `/` is encrypted; the backup password's safekeeping is a sentence in a guide | 4 | ai-desktop.md's note |
| H | Local Ollama can be redefined by any local UID and then drives a `--local` agent | 3 | agents report, item 7 |
| I | No ledger of what left the machine | 5 | IDEAS, TODO 81 |
| J | The lock screen once showed the desktop in the VM (picom's stale frame, likely) | 4 | TODO "to look into" 1 |

## The plan

In the order to do them. Each is small enough for one commit and a test.

### 1. Updates that can't be forged (A)

- Releases are tagged already (`vX.Y.Z`). Sign the tags: a key kept off the laptop's agent, used only at release (`git tag -s`), its public half committed to the checkout as `keys/release.asc`.
- `vikix update` fetches, then takes the newest tag that `git verify-tag` accepts against that key, and fast-forwards to it. An unsigned or badly signed tag is refused with a plain sentence. `main` between tags is never pulled; `vikix update --from PATH` (the `gtry` route) stays as it is, since it is the developer's own disk.
- The key that pushes is loaded with `ssh-add -c`, so each push asks; or kept out of the session's agent altogether. Written into `CLAUDE.md`'s release steps.
- The install line: `site/install` is fetched over HTTPS and is short by design; it then clones the repo. Make it check out the newest signed tag rather than `main`, with the same key embedded, so a first install is as checked as an update.
- Test: `tests/update.sh` makes a repo with a signed and an unsigned tag and checks which one `update` takes.

### 2. Pinned installers, checksums from elsewhere (B)

- Every fetch outside Void goes through one helper, `fetch_pinned URL SHA256` in `lib/common.sh`, which refuses to run anything whose checksum isn't in the repo. Today Ollama, virtio-win and WinFsp do this by hand; aider, OpenCode, the npm agents and uv's `@latest` do not.
- Pins: `aider-chat==VERSION`, OpenCode at a release tag not a branch, npm packages at exact versions, `uv tool install` with `==`. A table in `lib/pins.sh` so a release moves them deliberately, as the plugins' pin is moved.
- Where a project publishes checksums, take them from its release page, not from the file's own host; where it doesn't, compute once on the dev machine, record in the repo, and say so in the comment.
- `vikix doctor` lists every pinned thing and whether what's installed matches its pin.

### 3. The allow-list: agents act through code we check first (C)

This is the idea from IDEAS made concrete, and it covers every door at once.

- One module, `lib/door/`, used by `vikix eval`, `vikix-mcp`'s `eval` and `cuis_eval`, and the music process's socket: password from `~/.slime-secret` as the first line, a five-second deadline, one client's failure never stopping the server, and an audit line per call in `~/.local/state/vikix/door.log`. The Swank guard already does this for one door; the others get it by sharing code, not by copying.
- The walker: a form is read, not evaluated, and every function it calls is checked against a list: `move-window`, `gselect`, `vikix-apply-theme` and their kind pass; `run-shell-command`, `load`, `open`, file streams, the secrets folder, `(setf (fdefinition …))` are refused or need the user's yes through the existing review panel (Esploro's). Smalltalk's walker does the same for `cuis_eval`.
- Modes: `vikix mcp register --allow-eval` keeps its meaning, but `eval` now means "any form the list allows"; `--allow-anything` is the new name for today's unchecked behaviour, so the dangerous one is the one that sounds dangerous.
- The agents' guide and `SKILL.md` describe the list, so a well-meaning agent doesn't guess.
- Test: a list of forms that must pass and must fail, run against the walker without a desktop.

*2026-10-08: the walker is in* (`config/stumpwm/vikix/door.lisp`, a layer file rather than `lib/door/`, since the loader and the compiled copies are the layer's; `bin/vikix-door`, Super+m → Door, `tests/door.sh`). As built: an agent's form is held for the user (as a proposed rule is), never asked for in a menu at the time; `--allow-eval` keeps its meaning and there is no `--allow-anything`, since agents have no way round on purpose (your own `vikix eval` at a terminal is yours, not checked); the refused attempts go to `~/.local/state/vikix/errors/` rather than a `door.log` of their own. Still to come from this section: the shared module for Cuis's and the music socket's doors, and the review panel for a held form.

### 4. `vikix debug` tells the agent only what it should (D)

- Web-page text in logs (Firefox, Nyxt) is dropped from the report, not scrubbed; the agent that reads the report sees the error lines and the system facts, never page content.
- URLs are reduced to their host; file names under `~` are kept, their folders replaced by `~/…/`; the scrubber learns the common key shapes (`sk-`, `ghp_`, `AKIA`, JWTs, 32- and 64-hex) and the known files (`~/.slime-secret`, git credentials, the agents' logins).
- The report is written to a fresh file with mode 600 before anything goes in it; `--out` onto an existing file or a FIFO is refused.
- One invalid byte in a log no longer stops the report (read as bytes, decode with replacement).

### 5. Secrets, tightened (E)

- `lib/secrets.sh` exports only names that match `^[A-Z][A-Z0-9_]*_(API_)?KEY$` or are listed in `~/.config/vikix/secrets/.names`; anything else in the folder is reported by `vikix ai key check`, not exported.
- Symlinks in or at the folder are refused by `check` and `set`, with the reason.
- `vikix changes` says "the secrets folder changed" (by name, never content) when it did, so a change there is visible without being recorded.
- `check` reads `git ls-files -z`, includes binary files, and looks at the reflog; its advice no longer leaves a copy of a key in a set-aside repo.

### 6. Small things with no excuse (F, H)

- `notify` in the MCP server: at most one every five seconds and ten a minute per server process; beyond that the tool answers that it waited.
- `vikix doctor`: a line when the MCP server is registered with `--allow-eval` or `--allow-undo`, and with the new `--allow-anything`.
- Ollama: `vikix ai setup` runs it as a service owned by the user with its socket under `$XDG_RUNTIME_DIR`, not a shared TCP port, where Ollama allows; where it doesn't, `vikix doctor` says the port is shared with every local user. `--local` agents check they are talking to the Ollama Vikix started (its PID file), not any process on the port.

### 7. The laptop, lost (G, J)

- `vikix doctor` reports whether `/` and `/home` are on LUKS (`lsblk -o TYPE` shows `crypt`), and the install guide's Void chapter says to choose encryption and why.
- The backup password: `vikix backup setup` offers to print it as a card (one page, in large type) and reminds at setup and in `doctor` until the user says it is kept somewhere else.
- The lock screen: follow TODO "to look into" 1 to its end (`use-damage = false` for picom's xrender in VMs; the long-idle test on real hardware). A lock screen that may show the desktop is a HIGH, however rarely.

### 8. The outbound ledger (I)

TODO 81, which belongs to this plan: one page listing what left the machine today, by program (agents' calls through `vikix mcp status` and the door log, `llm logs`, package fetches, Dropbox, the agents' installers), with a bar note when something new talked out for the first time. It is how a user checks the site's claim, and how the pen-tester checks ours. Design when 1–3 are in; its sources are the logs those steps create.

## What this does not do

- **Not sandboxing every program.** `vikix try` (IDEAS) sandboxes one on request; a desktop that sandboxes everything is a different desktop.
- **Not a security audit of Void.** Void's own packages are Void's; the plan covers what Vikix adds.
- **Not perfect prompt-injection defence.** The walker and the review panel make an agent's harmful action need a human's yes; they don't make the agent wise.

## Measure

- `tests/run.sh` gains `update` (signed tags), `pins` (every pin matches), `door` (the walker's pass and fail lists), `debug` (the scrubber's cases), `secrets` (names, symlinks).
- The pen-tester agent runs again on the release that closes items 1–6, in the VM, and its report is the measure: each of today's open findings either closed or re-dated here.

## Open questions

Blocking:
- **Where the release signing key lives.** (Vid) A hardware key, a passphrase-protected key on the dev machine outside the agent, or `ssh-keygen`'s signing (git supports SSH signatures; the same key that pushes could sign, but then one key does two jobs). Proposed: a separate SSH signing key, passphrase-protected, `ssh-add -c`.
- **Does `site/install` embed the public key, or fetch it?** Embedding means the install line is the trust root, which it already is. Proposed: embed.

Non-blocking:
- The walker's first list: generate it from `define-vikix-command` (TODO 75) when that exists, by hand until then.
- Whether `--allow-anything` should exist at all, or be `vikix eval` from a shell only.

## Order and size

1 and 2 first (a weekend together; they close the HIGH and most of the MEDIUMs about upstream). Then 3 (the door module and the walker: two or three days; it is the one that makes Vikix's claim about agents true). 4 and 5 (a day each). 6 and 7 (hours). 8 when there are logs to read.
