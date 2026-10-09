# OpenClaw and the office — design

How Vikix's agents can work with OpenClaw: as a sixth agent in a terminal, as the phone's way into the desktop and the office, and as the always-on assistant the AI desktop is for.

Drafted 2026-10-08 from a desk's task ("how can vikix agents work with open claw"), against OpenClaw's own documentation (docs.openclaw.ai, read that day) and the office as it stands in 0.71.254. It fills the slot TODO item 13 left open on 2026-10-02 ("the phone gateway and local agents: needs a design first"), where Hermes Agent was the candidate; the choice between the two is Vid's, below. Kept honest like the other designs: what ships is deleted here, what changes is dated. Facts that could only be read, not tried, are marked *unverified*.

---

> 2026-10-08: Vid clarified that phone access to the existing Office is the goal and chose Telegram. [The Office on Telegram](DESIGN-phone.md) replaces the phone gateway direction here with a direct bridge for blocking questions, replies, task assignment, pause, continue and close. OpenClaw agent integration remains a separate idea, not a dependency.

## What OpenClaw is

A personal AI agent that runs on your own machine and talks to you where you already are: WhatsApp, Telegram, Signal, Discord, Slack, iMessage, a web chat, a terminal. Born as Clawdbot in November 2025, renamed twice, MIT, and since mid-2026 held by the OpenClaw Foundation after its author went to OpenAI. Written for Node (24.16 or newer), installed with npm or its own installer; Void doesn't package it. Its parts, as far as this design needs them:

- **The Gateway** is the one process: a WebSocket and HTTP server on `127.0.0.1:18789`, with a token, that owns every session, routes each channel's messages to an agent, runs the agent loop and its tools, and serves a Control UI. The channels, the phones (its *nodes*: the companion apps), the terminal and every other client connect to it. Without it, `openclaw tui --local` runs the agent alone in a terminal.
- **An agent** is a workspace folder (`~/.openclaw/workspace` by default: `AGENTS.md` its instructions, `SOUL.md` its manner, `USER.md` about you, `MEMORY.md` and `memory/DATE.md` what it keeps, `skills/`) with a model, tools and a session store (`~/.openclaw/agents/ID/agent/openclaw-agent.sqlite`). Several agents can live in one Gateway, each with its own workspace and credentials.
- **Tools and their policy.** `exec` runs shell commands on the Gateway's host (or in a Docker or Podman sandbox, off by default; the workspace is a default folder, not a wall); `read`, `apply_patch`, `web_fetch`, `web_search`, `message`, the browser, and more. `tools.exec.mode` is `deny`, `allowlist`, `ask`, `auto` or `full`; `ask` sends the approval to you on the channel you are on, the phone included.
- **Skills** are the AgentSkills format: a folder with `SKILL.md`, frontmatter `name` and `description`, and `metadata.openclaw.requires` to gate one on a program or a variable. The same shape as Vikix's own skill for Claude Code. They are found in the workspace's `skills/`, `~/.agents/skills`, `~/.openclaw/skills`, and the plugins'.
- **Plugins** are TypeScript loaded into the Gateway (a folder with `openclaw.plugin.json` and an entry that calls `api.on(...)`). A plugin's `before_tool_call` hook sees the tool's name and parameters and answers `block: true` with a reason, rewrites the parameters, or asks for an approval; `after_tool_call` only watches. That is the shape of Vikix's house rules.
- **Both doors in both directions.** As an MCP client: `mcp.servers` names servers its agents may use. As an MCP server: `openclaw mcp serve` gives Claude Code or Codex the channels' conversations. As an ACP agent: `openclaw acp` over stdio, for Zed and anything that speaks the Agent Client Protocol, each ACP session a Gateway session. As an ACP client: with the `acpx` plugin it starts Claude Code, Codex, Gemini CLI or OpenCode itself, headless, in a folder (`/acp spawn claude`, `sessions_spawn`). `openclaw attach` starts Claude Code bound to one of its sessions through a temporary MCP config.
- **Automation.** Cron jobs (`openclaw automations`, each run a fresh session, the answer delivered to a channel), a heartbeat, and webhooks: `POST /hooks/agent` with a message and its own token runs a turn; `/hooks/wake` nudges the main session.
- **Managed worktrees.** `openclaw worktrees create REPO` makes a git worktree under `~/.openclaw/worktrees/FINGERPRINT/NAME` on a branch `openclaw/NAME`, and a chat can be started in one. Not where Vikix's desks live.
- **A terminal in it.** `openclaw tui` is a chat with the Gateway in a terminal (`--session KEY`, `--message`, `--deliver`); `openclaw agent -m "..."` is one turn and exits; `openclaw sessions --json` lists the sessions.
- **The security record.** It is the most-attacked program of its kind: a paper of March 2026 (arXiv 2603.27517) sorts 470 advisories against it, among them a chain from an LLM tool call to code on the host through the Gateway, the `exec` allow-list talked around by shell syntax, and a malicious skill that ran a dropper inside the model's context. Its answer since: auth on by default, loopback by default, a plugin allow-list, a security audit command. This design treats the Gateway as a door in the sense of `DESIGN-security.md`: it gets the rules every door gets, and the phone's agent gets no shell.

## The problem

Three things Vikix can't do today, in the order Vid's notes ask for them:

- **Nothing reaches the desktop from the phone.** TODO 13's reason for a gateway: ask the agent from Telegram or WhatsApp what the desks are doing, tell one something, start one, get the morning brief (TODO 21), without opening the laptop. `DESIGN-machines.md` gives the network (Tailscale) and the phone on the desk (KDE Connect); neither carries a conversation.
- **Nothing runs when nobody is at the keyboard.** The office's agents are terminals on workspaces. The AI desktop (`ai-desktop.md`) is bought to run all the time; nothing of Vikix yet gives it something to run.
- **A sixth agent,** for whoever has OpenClaw already: in a terminal, seen by the office like the five, under the house rules. Vid's own judgment on Hermes holds here too: "as a sixth terminal agent it adds little beside the five". It is the cheapest piece, and not the reason.

## What it is

Four connections, each useful alone, in the order to build them. Each keeps the office's rules as they are: the office makes the desks, the hook judges the edits, the handoff is the record, `vikix mcp` is the agent's small checked set of acts.

**1. OpenClaw as an agent in a terminal** (`vikix agent --use openclaw`; a day). `openclaw tui --local` in the terminal, so no Gateway is needed; with the Gateway up, the same command attaches to it and the conversation is also on your phone. The office finds it as it finds the others: `openclaw` in `*vikix-agent-programs*` and `PROGRAMS` (its process is `node .../openclaw`, and both readers take the first two words of a command line, so the script's name counts; *unverified*: the exact path npm puts it at). It shows nothing in its title, so what it is doing comes from a plugin of Vikix's (connection 2's, the same file): a note for the agent-waiting plugin at an approval or an `ask_user`, and `done` at the turn's end. Vikix's guide reaches it as a skill: the skill folder `config/claude/skills/vikix` linked to `~/.openclaw/skills/vikix`, since the format is the same and the first page is under 16 KB; nothing is written into its workspace, which is the user's. The handoff keeps its session as it keeps OpenCode's: the sqlite store read read-only (`session_store`), and `openclaw tui --session KEY` resumes it (`RESUME`); `sessions_on_disk` lists the store's sessions for the folder. Keys: it signs in its own way (`~/.openclaw`), so the agent start drops the keys from its environment as for the rest. `--acp`: `openclaw acp`, which needs the Gateway running, said so when it isn't. Installed by `vikix agent --install openclaw` from npm at a pinned version with its integrity hash, as Antigravity is pinned by URL and SHA-512; moving the pin is a release.

**2. The house rules as an OpenClaw plugin** (`config/openclaw/vikix-office/`; a day, with 1). A folder with `openclaw.plugin.json` (`id: "vikix-office"`) and an entry whose `before_tool_call` runs `vikix agents touch --for openclaw` with the tool's name and parameters as JSON on stdin (`exec`'s `command` and `workdir`; `apply_patch`'s `derivedPaths`, which the docs call best-effort, so the patch text is read too), and answers in OpenClaw's shape: `block: true, blockReason` for a refusal (the desk rule), `requireApproval` with the reason for a clash (the approval reaches you on the phone when that is where you are), nothing for a crossing but a note in the journal, since the hook can't tell the agent something without deciding, as Antigravity's can't. `HOOK_FOR = "openclaw"` in `bin/vikix-agents` is one more answer shape beside Gemini's. `vikix agents hooks openclaw --install` links the folder under `~/.openclaw/extensions/vikix-office` and sets `plugins.entries.vikix-office.enabled` (*unverified*: the install path; `openclaw plugins install PATH` is the documented way and may be the right one), a folder of the user's own left alone, as for OpenCode. The same plugin writes the agent-waiting note (connection 1) from `before_tool_call` of `ask_user`, from an approval requested, and from the end of a turn. `ADAPTERS` gains the line; the guide's "What holds the rules, for each agent" too. `tests/house.sh` drives `touch --for openclaw` with planted JSON, no Gateway.

**3. The phone's way in: the Gateway as a feature** (`vikix add openclaw`; a weekend). The Gateway runs on the laptop while the desktop is up: started by `vikix-session` when the feature is on (`vikix openclaw on|off`, a bar note while it runs, the quiet colour), bound to loopback with its own token, never on passt, never on the LAN; from the phone it is reached over the tailnet (`DESIGN-machines.md`, Tailscale, which OpenClaw's own documentation prefers for remote use) or by a channel's own servers (a Telegram bot needs no network of ours: the Gateway talks out). One channel first, Telegram (a bot token, pairing by approving one sender; OpenClaw ignores unapproved senders by default), the others as wanted. What the phone's agent can do is `vikix mcp`'s set and nothing else: `mcp.servers.vikix` runs `vikix-mcp serve` (stdio, as every other agent gets it), `tools.exec.mode: "deny"` for that agent, no browser, web fetch and search left to the user's choice. So from the phone: *what's on my desktop*, *which desks are working and which wait for me* (`agents`, `office`, `handoff`), *tell the wifi desk to skip the test* (a `tell` tool, new and small: `vikix agents tell DESK TEXT` behind it, which the hook delivers at the agent's next edit), *switch to workspace 3*, *notify*, *snapshot*, and, through `run_command`, only what the registry marks for agents. Starting a desk from the phone is `desk` as an MCP tool (`vikix agents desk PROJECT TOPIC --task`): it opens a terminal on the desktop, which must be up, and the agent works there under the house rules as if started at the keyboard; the record is the same, the Office shows it, the handoff says what it did when you are back. The door's rules from `DESIGN-security.md` hold: the MCP log already keeps every call; the ledger, when it comes, shows "asked from the phone". The guide gets a page (`docs/openclaw.md`: what reaches your phone, what the phone can do, how to approve a sender, how to stop it).

**4. Always on** (with `ai-desktop.md` and `DESIGN-machines.md`; later). The laptop's Gateway stops when the lid closes. The always-on one is the same feature on the AI desktop, reached over the tailnet, with the laptop a node of it rather than a host; the desks it starts are on that machine's desktop (`vikix agent --on office` is the same reach). The morning brief and the business mail (TODO 21) are a second OpenClaw agent there, on a local model (its Ollama provider wants the native API, `baseUrl: "http://z13:11434"`, never the `/v1` form), with `exec` denied and no channel but the brief's delivery, as TODO 21's rule says: the step that reads mail can do nothing else. That is a design of its own when 21 is picked up.

```
  phone ── Telegram ──► OpenClaw Gateway (laptop, 127.0.0.1:18789; the office machine later)
                          │  agent "main": tools = vikix mcp only, exec denied
                          │  plugin vikix-office: before_tool_call ──► vikix agents touch --for openclaw
                          ▼
                        vikix-mcp serve ──► desktop, agents, office, handoff, tell, desk, run_command
                                             (the registry's :agent t only; every call logged)
  terminal ── openclaw tui [--local] ──► the same agent, seen by the office as "openclaw",
                                         its note from the plugin, its session in the handoff
```

## OpenClaw or Hermes, for item 13

Both fill the slot: a gateway to the phone, scheduled jobs, memory and skills of their own, local models. What tells them apart, for Vikix:

| | OpenClaw | Hermes Agent |
|---|---|---|
| Runtime | Node 24+, npm; a daemon | Python with uv; its installer also brings Chromium and a computer-use driver unless told not to |
| Channels | WhatsApp, Telegram, Signal, Discord, Slack, iMessage, web; phones as nodes with approvals on them | Telegram, WhatsApp, Signal, Discord |
| A hook that can refuse a tool | Yes: a plugin's `before_tool_call`, so the house rules hold before the edit | Not found in its docs on 2026-10-02 |
| MCP, ACP | Both, in both directions | MCP client; `hermes acp` |
| Skills | AgentSkills format: Vikix's skill links in as it is; a marketplace of thousands | Its own, which it writes and refines itself |
| Memory | Files in the workspace, loaded at session start | Its strength: curated, grows with use |
| Local models | Ollama's native API, a recipe for small models | Any OpenAI-compatible address |
| Security | 470 advisories sorted by a paper; loud, patched, audited; a foundation now | Quieter; less looked at |
| Who stands behind it | The OpenClaw Foundation, OpenAI's support | Nous Research, a model maker |

The recommendation is OpenClaw for the gateway slot, for two reasons that are Vikix's rather than general: the plugin hook that can block, which is what lets the house rules hold for an agent that has no terminal; and the two doors in both directions, which make the office's MCP server its whole set of acts without a line of glue. Hermes keeps a line in TODO 13 as the agent to try on the Z13 for its memory and its local models, when the Z13 is there. Vid decides.

## What is decided here

- The office makes the desks, not OpenClaw. Its managed worktrees (`~/.openclaw/worktrees/...`, branches `openclaw/NAME`) are not desks and aren't used for Vikix's projects; `desks` keeps looking beside the repository for `TOP-TOPIC`. Its ACP sessions (Claude Code started headless by the Gateway) are not used on the laptop either: a desk is a terminal you can sit at when you are back, and the hook's desk rule would in any case refuse edits in a project's own folder from one.
- The phone's agent has no shell. Its acts are `vikix mcp`'s, which were built as "a small, checked set"; `exec` stays denied for it even when the user allows it for the terminal's agent.
- Nothing of Vikix is written into `~/.openclaw/workspace`: `AGENTS.md`, `SOUL.md` and the memory there are the user's. Vikix's guide comes in as a skill, through a link.
- Secrets stay apart: the Gateway's token and the channels' credentials are OpenClaw's in `~/.openclaw`; Vikix's keys aren't handed to it, and `vikix ai key check` learns `~/.openclaw/openclaw.json` as a place keys end up.
- The feature is off unless added. `vikix add openclaw` installs and starts it; a plain install has no Gateway.

## How it is built

**Phase 0, an afternoon, in the VM first:** `vikix agent --install openclaw` (npm, pinned; `openclaw --version` and `openclaw doctor` as the check), `--use openclaw` as `openclaw tui --local`, the skill linked into `~/.openclaw/skills/vikix`, `openclaw` in both program lists, `tests/agents.sh` for the skill link. What to learn there: the process tree and command line under a terminal, whether `openclaw tui --local` works with no `~/.openclaw` set up or wants `openclaw onboard` first, and what the Gateway does on a machine without systemd (`openclaw gateway run` in the foreground is what `vikix-session` would start; the service install is the only part that wants systemd, by reports).

**Phase 1, a day:** the plugin (connection 2), `touch --for openclaw`, the agent-waiting note, `ADAPTERS`, the handoff's store and resume, `tests/house.sh` and `tests/handoff.sh` with planted JSON and a planted sqlite store. `docs/agents.md`'s table of what holds the rules.

**Phase 2, a weekend:** the feature (connection 3): `features.list` and a list for npm's part (a `setup` command, as the other agents' installers are), `vikix openclaw on|off|status` (`bin/vikix-openclaw`), the start from `vikix-session`, the bar note (a plugin in the plugins repo, as `agent-waiting` is), `mcp.servers.vikix` written by `vikix mcp register`, `exec` denied for the channel's agent, the `tell` and `desk` tools in `bin/vikix-mcp` (each logged; `desk` refused when no desktop is up), Telegram's pairing in the guide, `docs/openclaw.md`, a line in the security plan's door list. `tests/openclaw.sh`: the config written, the server registered, the start and stop with a stand-in `openclaw`.

**Phase 3, with the machines design:** the Gateway on the AI desktop, the laptop as a node, `vikix machines` saying where it runs.

## Open questions, for Vid

- OpenClaw or Hermes for item 13, or OpenClaw for the gateway and Hermes as a terminal agent later?
- Which channel first: Telegram (a bot token, nothing of ours on the network), WhatsApp (pairing a phone), Signal (a number and `signal-cli`)?
- May the phone's agent run any command at all, or only `vikix mcp`'s tools? This design says tools only.
- Does the Gateway run on the laptop now, stopping at the lid, or wait for the AI desktop?
- Does the morning brief belong here (a second agent with a local model) or in TODO 21's own design?

## Unverified, to try on a machine

The `before_tool_call` event's working folder (the docs give `exec`'s `workdir` parameter and `derivedPaths`, no `cwd` of the session); where `openclaw plugins install PATH` puts a plugin and whether a link under `~/.openclaw/extensions` is read; the process's command line under a terminal (`node` and the script's path); the Gateway in the foreground under `vikix-session` without systemd; the sqlite store's schema for the handoff; `openclaw tui --local` before any onboarding; the `mcp.servers` entry's exact shape for a stdio server.
