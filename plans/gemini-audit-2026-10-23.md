> **Kept as brought.** Vid worked this roadmap out with Gemini and brought it on 2026-10-23. It was sorted into Vikix's lists the same day: `IDEAS.md`, section "Gemini's audit (2026-10-23)", says what of it is already built, what became a dated note under a `TODO.md` item, what stays an idea, and what runs against a decision already taken. Two cautions for a reader: its table of the system is Gemini's reading, not the repository's (the layer is `config/stumpwm/vikix/`, not `~/vikix/lisp/`; the socket is `socket.lisp`, the door the checker in `door.lisp`; there is no `vikix startx`, no `ROADMAP.md`, no repository `log.md`, no `.beads/`), and its execution protocol and Beads script were not run: this repository's lists are `TODO.md`, `IDEAS.md`, `ARCHIVE.md`, `bugs.md`, `NOVEL.md` and `plans/`, and the Office keeps the tasks (TODO 115, 119). None of the programs it names has been checked against void-packages.

# Claude Agent Handover Brief: Vikix Roadmap & Ecosystem Integration

> **Usage Instructions for Human Operator:**
> Feed this file directly to Claude Code (or `vikix-agent`) inside your `~/vikix` (or `~/dev/vikix`) repository:
> ```bash
> claude "Read vikix_claude_handover.md and execute the Handover Mission to populate the Vikix TODOs, roadmap, and Beads tracker."
> ```

## 1. Mission Brief for Claude Agent

You are operating inside the **Vikix** codebase ([vikix.dev](https://vikix.dev/) / [Guide](https://www.google.com/search?q=https://vikix.dev/guide/)), an open-source, keyboard-driven, AI-native Linux desktop workspace built on **glibc Void Linux** (`runit`, `xbps`) and **StumpWM** (running on SBCL Common Lisp).

Your mission is to translate the comprehensive architectural, security, UX, mobile-roaming, and open-source ecosystem audit below into structured, actionable project tasks.

### Step-by-Step Execution Protocol
1. **Inspect Current State & Snapshot First:**
   * Inspect the current repository layout (`~/vikix`, `~/dev/`, `log.md`, `TODO.md`, `ROADMAP.md`, `features.list`, and `.beads/` if present).
   * If `vikix snapshot` is available, run `vikix snapshot` before making changes; otherwise verify a clean working tree with `git status`.
2. **Update Human-Readable Project Tracking (`ROADMAP.md` / `TODO.md` / `log.md`):**
   * Write or update the master roadmap in the repository's primary markdown tracking file (`TODO.md` or `ROADMAP.md`, and append a summary entry to `log.md`), preserving all six phases, architectural notes, and reference repository URLs below.
3. **Populate Machine-Executable Tasks in Beads (`bd`), If Installed:**
   * Check if the [Beads (`bd`)](https://github.com/gastownhall/beads) CLI is installed (`command -v bd`).
   * If `bd` is installed (or after installing it in Phase 1), initialize `.beads/` (`bd init --quiet`) and execute the **Automated Beads Provisioning Script** in Section 4 to create all Epics, Tasks, Priorities, and Dependency DAG links.

## 2. Current Vikix System Context (v0.72.148 Baseline)

| Layer | Current Implementation | Target Files & Directories |
| :--- | :--- | :--- |
| **OS & Init** | Void Linux (`glibc`), `runit`, `xbps` package manager | `features.list`, `services.list`, `install.sh` |
| **Session Startup** | TTY1 -> `~/.bash_profile` -> `vikix startx` -> `~/.xinitrc` -> `vikix-session` (spawns `pipewire`, `dunst`, `clipmenud`, `udiskie`, `picom`, `xss-lock`, Emacs daemon, Ollama via `&`) | `vikix-session`, `~/.local/state/vikix/session.log` |
| **Window Manager** | SBCL Common Lisp + [StumpWM](https://ghe.derekchia.com/repo/stumpwm/stumpwm) (`~/.stumpwm.d/init.lisp`) | `~/vikix/lisp/` (`errors.lisp`, `theme.lisp`, `groups.lisp`, `registry.lisp`, `commands.lisp`, `windows.lisp`, `rules.lisp`, `viri.lisp`, `drawer.lisp`, `layouts.lisp`, `overview.lisp`, `resume.lisp`, `day.lisp`, `webapps.lisp`, `modeline.lisp`, `door.lisp`, `swank-guard.lisp`, `swank.lisp`, `user.lisp`) |
| **Spatial Canvas** | **The Strip** (horizontal scrolling workspace canvas) | `~/vikix/lisp/viri.lisp` |
| **Agent IPC & MCP** | Swank (`127.0.0.1:4004`, `~/.slime-secret`), UNIX socket (`vikix-door`), MCP server (`vikix-mcp`) | `~/vikix/lisp/door.lisp`, `~/vikix/lisp/swank.lisp`, `vikix-mcp`, `vikix-agent`, `vikix-ask`, `vikix-ai` |
| **State & Recovery** | User config history in `~/.local/state/vikix/yours.git`, diagnostics via `vikix doctor` | `vikix snapshot`, `vikix changes`, `vikix undo`, `vikix update`, `vikix rollback`, `vikix-day`, `vikix-project` (`~/dev/<project>/log.md`) |

## 3. Master Phased Todo List & Architecture Specifications

### Phase 1 (P0): Personal Roaming & Mobile Development Rig (Days 1–3)
*Rationale: Unblock development while traveling so the founder can dispatch, monitor, and review agents from a phone even when the laptop lid is closed.*

* [ ] **P1.1 — Provision Always-On Void Linux Relay VPS on Tailscale & Mosh:**
  * Set up a persistent Void Linux VPS connected to the laptop and mobile phone over [Tailscale](https://getmoshi.app/articles/best-setup-coding-agent-phone).
  * Install [Mosh (Mobile Shell)](https://getmoshi.app/articles/mac-remote-endless-agent-setup) for UDP roaming resilience across Wi-Fi/5G handoffs.
* [ ] **P1.2 — Initialize Git + Beads (`bd`) + Herdr Sync Loop:**
  * Install [Beads (`bd`)](https://github.com/gastownhall/beads) ([Docs](https://beads.gascity.com/)) and [Herdr (`herdrdev/herdr`)](https://github.com/herdrdev/herdr) ([herdr.dev](https://herdr.dev/)) on both laptop and VPS.
  * Configure pre-travel sync workflow (`git push && bd dolt push` on laptop -> `git pull && bd dolt pull` on VPS) ([Beads README](https://github.com/gastownhall/beads/blob/main/README.md)) so background agents continue running inside persistent `herdr` PTYs while the laptop is suspended.
* [ ] **P1.3 — Deploy Mobile Control Surfaces (Roamgate, `b9s` Web, Paseo, Takopi):**
  * Deploy [Roamgate (`powerfooI/roamgate`)](https://github.com/powerfooI/roamgate) ([roamgate.dev](https://roamgate.dev/)) over Tailscale as the mobile PWA client for `herdr` terminals, worktrees, and file diffs.
  * Run [`b9s` web mode (`vanderheijden86/b9s`)](https://pkg.go.dev/github.com/vanderheijden86/b9s/pkg/web) for mobile browser Kanban triage and issue editing.
  * Configure optional low-bandwidth/voice mobile controllers: [Paseo (`getpaseo/paseo`)](https://github.com/getpaseo/paseo) ([paseo.sh](https://paseo.sh/)) with [`beads-viewer`](https://github.com/gastownhall/beads/blob/main/docs/community-tools.md) for voice dictation, or [Takopi (`banteg/takopi`)](https://github.com/banteg/takopi) ([takopi.dev](https://takopi.dev/tutorials/install/)) for Telegram thread control (or [Happy (`slopus/happy`)](https://github.com/slopus/happy) / [Reemoat](https://reemoat.com/)).

### Phase 2 (P0): `vikix.dev` Website, UX & Onboarding Friction Fixes (Days 4–7)
*Rationale: Self-contained frontend and packaging tasks ideal for testing the Phase 1 mobile agent workflow while removing visitor conversion barriers on [vikix.dev](https://vikix.dev/).*

* [ ] **P2.1 — Fix Subpage Header Navigation Links:**
  * On `/gallery.html` ([Gallery](https://www.google.com/search?q=https://vikix.dev/gallery.html)) and `/guide/` ([Guide](https://www.google.com/search?q=https://vikix.dev/guide/)), change relative anchor links (`#why`, `#agent`, `#install`) to root-relative paths (`/#why`, `/#agent`, `/#install`).
* [ ] **P2.2 — Add Mobile Navigation Drawer & Explicit Footer Links:**
  * Implement a responsive collapsible menu drawer below `768px` so the six nav items and theme toggle do not crowd narrow screens.
  * Update footer links (*"Say hello"*, *"Report an issue"*) to clearly indicate their destinations (`mailto:` address preview or GitHub Issues URL) and place a prominent GitHub repository link in the top header.
* [ ] **P2.3 — Refactor FAQ Accordions to Semantic HTML & Add SEO/OG Metadata:**
  * Convert custom JS click handlers in the *"Before you begin"* FAQ section to native `<details>` and `<summary>` elements (or add `aria-expanded` / keyboard `Enter`/`Space` support).
  * Add Open Graph (`og:image`, `og:title`, `og:description`), Twitter Card tags, and Schema.org `SoftwareApplication` / `OperatingSystem` JSON-LD metadata.
* [ ] **P2.4 — Add Above-the-Fold Workflow Screencast & Concrete Subtitle:**
  * Embed a 15–30 second silent, looping `.webm` screencast in the hero section showing StumpWM tiling, **The Strip** (`viri.lisp`), and an AI worker executing tasks alongside code.
  * Add a concrete 1-sentence technical subtitle under the main headline and a link to a community hub (GitHub Discussions, Matrix, or Discord).
* [ ] **P2.5 — Publish Non-Destructive Trial Artifacts (VM Image / Live ISO):**
  * Build and host a pre-configured QEMU/VirtualBox image or bootable Live USB ISO so prospective users on macOS, Ubuntu, or Arch can evaluate Vikix in 5 minutes without wiping hardware.

### Phase 3 (P1): Void Linux Supervision, Sandboxing & Lisp IPC Hardening (Weeks 2–3)
*Rationale: Eliminate single-threaded WM freezes, unsupervised daemon crashes, and unrestricted `$HOME` access before scaling up concurrent agents.*

* [ ] **P3.1 — Migrate `vikix-session` Daemons to Void Linux `turnstile` + `runit`:**
  * Replace unmanaged shell background jobs (`&`) in `vikix-session` with Void's native [`turnstile`](https://docs.voidlinux.org/config/services/user-services.html) session manager and per-user `runit` services in `~/.config/service/` using `chpst(8)` `envdir` (`TURNSTILE_ENV_DIR`).
  * Enforce `cgroups v2` memory and CPU ceilings on background agent processes and local LLM servers (Ollama) so OOM events never kill X11/StumpWM.
* [ ] **P3.2 — Sandbox `vikix-agent` Execution with `syd` (SydB☮x 3) or `clampdown`:**
  * Wrap agent CLI invocations in [`syd` (SydB☮x 3)](https://crates.io/crates/syd) ([manual](https://man.archlinux.org/man/syd.5.en)) or [`89luca89/clampdown`](https://github.com/89luca89/clampdown) (using Landlock LSM, `seccomp-bpf`, and user namespaces / `bubblewrap`), restricting write access strictly to the active `~/dev/<project>` workspace.
  * Move plaintext API keys out of `~/.config/vikix/secrets` into the Linux kernel keyring (`keyctl`) or `pass`, brokering short-lived tokens via `vikix-ai`.
* [ ] **P3.3 — Decouple `door.lisp` & `swank.lisp` from StumpWM's Main Event Loop:**
  * Offload IPC socket evaluation onto background SBCL worker threads via `bordeaux-threads` with thread-safe queues and token-bucket rate limiting so heavy agent RPCs cannot freeze X11 window rendering.
  * Replace raw arbitrary Lisp `eval` over `vikix-door` with a capability-gated RPC command schema (`window:create`, `workspace:focus`, `notification:send`).
* [ ] **P3.4 — Embed Native Common Lisp MCP & A2A Servers Inside SBCL:**
  * Integrate [`cl-ai-project/cl-mcp`](https://github.com/cl-ai-project/cl-mcp) or [`40ants/mcp`](https://github.com/40ants/mcp) directly into the StumpWM Lisp image for native stdio/HTTP JSON-RPC 2.0 MCP tools.
  * Add [`jsulmont/mcp-lisp`](https://github.com/jsulmont/mcp-lisp) to support Agent-to-Agent (A2A) protocol handoffs natively in Common Lisp.
* [ ] **P3.5 — Atomic FASL Validation & Native XBPS Packaging:**
  * Update `vikix update` to compile and validate FASL files in a staging directory before swapping symlinks into `~/.cache/vikix/fasl/`.
  * Create native Void Linux XBPS package templates (`vikix-core`, `stumpwm-vikix`) and expand `vikix doctor --fix` to verify cgroup bounds, `turnstile` services, and orphan processes.

### Phase 4 (P1): Multi-Agent Memory, Specs & Pre-Collision Stack (Weeks 4–6)
*Rationale: Replace flat markdown task lists with a dependency-aware DAG, spec-driven planning, and semantic conflict prevention.*

* [ ] **P4.1 — Standardize the OpenSpec -> Beads (`bd`) -> Beady-Eye (`bdi`) Pipeline:**
  * Add [OpenSpec (`Fission-AI/openspec`)](https://github.com/Fission-AI/openspec) ([openspec.dev](https://openspec.dev/)), [Beads (`gastownhall/beads`)](https://github.com/gastownhall/beads), and [Beady-Eye (`CodeForBreakfast/beady-eye`)](https://github.com/CodeForBreakfast/beady-eye/blob/main/docs/configuration.md) ([Lib.rs](https://lib.rs/crates/beady-eye)) to `features.list` (`developer` bundle).
  * Update `vikix-project` and `vikix-agent` so `log.md` remains the human narrative journal while agents automatically run `bd prime`, claim unblocked tasks via `bd ready --claim`, and get woken automatically by `beady-eye` (`bdi watch` / `bdi gates`) when blockers or GitHub PR gates resolve.
* [ ] **P4.2 — Integrate Foremerge & Jujutsu (`jj`) for Conflict-Free Parallel Work:**
  * Bundle [Foremerge (`naw103/foremerge`)](https://github.com/naw103/foremerge) ([foremerge.com](https://foremerge.com/)) and wire its 18-tool MCP server (`foremerge setup all`) so parallel agents declare symbol scopes (`--scope symbol:Name=replace`) *before* editing code.
  * Add [Jujutsu (`jj`)](https://github.com/netresearch/jujutsu-workflow-skill) alongside Git ([Jujutsu Guide](https://wavect.io/blog/git-worktrees-vs-jujutsu-ai-coding-agents/)) for automatic working-copy commits, conflict-as-data rebasing, and atomic `jj undo` rollbacks, paired with `bd init --stealth` / `BEADS_DIR`.
* [ ] **P4.3 — Wire Herdr, Beads Gates & Molecules into StumpWM (`viri.lisp` & `modeline.lisp`):**
  * Poll `herdr` socket and `bd gate` status in `modeline.lisp` to show real-time agent counts (`working` / `blocked` / `idle`) and pending human gates.
  * Build an **Agent Inbox** and gate-review hotkey (`Super+r`, modeled on [`Gaurav-Gosain/tuios`](https://github.com/Gaurav-Gosain/tuios)) to inspect diffs and approve/reject `bd` gates with single keystrokes.
  * Extend **The Strip** (`viri.lisp`) with project swimlanes that automatically tile windows for active Beads Molecules and close tiles when `bd close` runs.
* [ ] **P4.4 — Bundle Editor Extensions, TUIs & ACP Support:**
  * Add [Agent Client Protocol (ACP)](https://github.com/agentclientprotocol/agent-client-protocol) ([zed.dev/acp](https://zed.dev/acp)) adapter support so any ACP-compliant agent plugs into Vikix.
  * Pre-configure [`beads.el`, `beads.nvim`](https://github.com/gastownhall/beads/blob/main/docs/community-tools.md), [`karthink/gptel-agent`](https://github.com/karthink/gptel-agent/), [`editor-code-assistant/eca-emacs`](https://github.com/editor-code-assistant/eca-emacs), [`quietpublish/mardi-gras` (`mg`)](https://github.com/quietpublish/mardi-gras), and [`zjrosen/perles` (BQL)](https://github.com/zjrosen/perles).

### Phase 5 (P2): Productivity, Self-Learning, Research & Investment Workflows (Weeks 7–9)
*Rationale: Deliver high-leverage daily tools for solo builders across system learning, shipping, deep research, and financial analysis.*

* [ ] **P5.1 — Build "Inspect Anything" HUD (`Super+?`), `vikix lab`, and Nyxt Integration:**
  * Use SBCL introspection so pressing `Super+?` on any window, widget, or daemon displays its live source definition in `~/vikix/lisp/`, PID tree, and AI-synthesized explanation of `vikix changes` / `vikix doctor` output.
  * Create interactive live-reload tutorials (`vikix lab`) for Common Lisp, StumpWM hooks, and Void `runit` services.
  * Integrate [`atlas-engineer/nyxt`](https://github.com/atlas-engineer/nyxt) (Common Lisp web browser) and [`lem-project/lem`](https://github.com/lem-project/lem) so agents can inspect and drive browser DOMs via native Lisp forms over Swank.
* [ ] **P5.2 — Multimodal Capture (`Super+c`), Voice (`Super+v`), and Automated Standups:**
  * Expand `vikix-ask` (`Super+i`) into an omni-capture tool (`Super+c`) for screen regions, terminal error buffers, and DOM trees, plus a PipeWire push-to-talk hotkey (`Super+v`).
  * Integrate [`stringer` and `Thread`](https://github.com/gastownhall/beads/blob/main/docs/community-tools.md) with `vikix-day` to auto-generate evening standup summaries and DuckDB agent rework/compliance scores.
* [ ] **P5.3 — Local Semantic Knowledge Base (`sqlite-vec`) & Headless Research (`vikix read`):**
  * Run a local embedding indexer over `~/dev/`, `log.md`, and saved PDFs/articles exposed via `cl-mcp`.
  * Build `vikix read <url|pdf>` to strip clutter, extract claims, cross-reference local notes, and save structured markdown citations in `~/dev/research/`.
* [ ] **P5.4 — Ship Gas Town Patterns & Domain Beads Formulas (Dev, Research, Investing):**
  * Implement [Gas Town (`gastownhall/gastown`)](https://github.com/gastownhall/gastown) patterns as declarative [Beads Formulas](https://beads.gascity.com/): a local **Refinery** bisecting merge queue, **Seance** (`vikix seance` to query prior `.events.jsonl` agent transcripts), and **Witness/Deacon** stuck-agent patrol hooks.
  * Add `vikix preview` (ephemeral containerized localhost staging) and `vikix release draft` (automated changelogs from `log.md` and closed beads).
  * Build `vikix invest analyze <ticker>` (automated 10-K/earnings/ratio dossier generator), `vikix finance runway` (burn rate, MRR, API spend, and UAE Free Zone tax modeling), and configurable financial tickers in `modeline.lisp`.

### Phase 6 (P2): Productizing `vikix mobile` / `vikix cloud` & Next-Gen Isolation (Months 3+)
*Rationale: Turn the founder's personal roaming rig and future-proof virtualization into turn-key features for all Vikix users.*

* [ ] **P6.1 — Package `vikix cloud` & `vikix mobile` CLI / Gas City Topology:**
  * Wrap the Phase 1 roaming stack (`Tailscale + Mosh + Herdr + Roamgate + b9s + bd dolt sync`) into a one-command setup (`vikix cloud init` / `vikix mobile`) or declarative [Gas City (`gastownhall/gascity`)](https://github.com/gastownhall/gascity/blob/main/README.md) `city.toml` pack.
  * Include an optional model router and cost firewall for unified API billing and fallback routing.
* [ ] **P6.2 — Virtualize Displays (`Xvfb`) for GUI "Computer-Use" Agents:**
  * Isolate visual browser/GUI agents inside dedicated `Xvfb` or headless framebuffers rendered as live picture-in-picture tiles on **The Strip** (`viri.lisp`) so computer-use agents never hijack the user's physical cursor or keyboard.
* [ ] **P6.3 — Upgrade `vikix snapshot` to Btrfs/ZFS Copy-on-Write & "Tournament Mode":**
  * Extend `vikix snapshot` and `vikix rollback` to support Btrfs/ZFS subvolumes for instantaneous block-level rollbacks.
  * Add `vikix-agent --tournament` to fork three zero-overhead CoW workspace snapshots in parallel, assign three different frontier models to the same Bead, run tests against each, and tile the winning diff on The Strip.

## 4. Automated Beads (`bd`) Provisioning Script for Claude

If `bd` ([Beads](https://github.com/gastownhall/beads)) is installed in the environment, Claude can execute the following idempotent shell script to populate the entire dependency-aware task graph automatically:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v bd >/dev/null 2>&1; then
  echo "Beads (bd) is not installed yet. Install via:"
  echo "  curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash"
  exit 1
fi

# Initialize Beads in repo if not already initialized
if [ ! -d ".beads" ]; then
  bd init --quiet
fi

create_bead() {
  local title="$1"
  local priority="$2"
  local type="$3"
  local desc="$4"
  bd create "$title" -p "$priority" -t "$type" --description="$desc" --json | jq -r '.id'
}

echo "Creating Vikix Roadmap Epics and Tasks in Beads..."

# Epic 1: Mobile & Roaming Rig (P0)
E1=$(create_bead "Epic 1: Personal Roaming & Mobile Dev Rig" 0 "epic" "Unblock mobile development while traveling using Tailscale, Mosh, Void VPS, Beads Dolt sync, Herdr, Roamgate, and b9s.")
T1_1=$(create_bead "Provision Void Linux relay VPS with Tailscale and Mosh" 0 "task" "Connect laptop, phone, and VPS via Tailscale mesh + Mosh UDP shell.")
T1_2=$(create_bead "Configure Git + bd dolt push/pull + Herdr daemon sync" 0 "task" "Install gastownhall/beads and herdrdev/herdr on laptop and VPS so agent PTYs survive closed laptop lids.")
T1_3=$(create_bead "Deploy Roamgate PWA, b9s web mode, and Paseo/Takopi mobile bridges" 0 "task" "Set up powerfooI/roamgate and vanderheijden86/b9s web over Tailscale, plus getpaseo/paseo or banteg/takopi.")
bd dep add "$T1_2" "$T1_1"
bd dep add "$T1_3" "$T1_2"

# Epic 2: Website & Trial Friction Fixes (P0)
E2=$(create_bead "Epic 2: vikix.dev Website, UX & Onboarding Fixes" 0 "epic" "Fix navigation, accessibility, SEO, hero screencast, and VM trial image on vikix.dev.")
T2_1=$(create_bead "Fix relative header anchor links on /gallery.html and /guide/" 0 "bug" "Update #why, #agent, #install to root-relative /#why, /#agent, /#install.")
T2_2=$(create_bead "Add mobile menu drawer (<768px) and explicit footer/GitHub links" 1 "task" "Prevent top nav wrapping on mobile and expose explicit GitHub repo and mailto/issue URLs.")
T2_3=$(create_bead "Refactor FAQ accordions to <details>/<summary> and add OG/Schema.org metadata" 1 "task" "Improve keyboard/screen-reader accessibility and add og:image + SoftwareApplication JSON-LD.")
T2_4=$(create_bead "Embed 20s hero workflow screencast and concrete technical subtitle" 0 "task" "Show StumpWM + The Strip + AI worker in action above the fold on vikix.dev.")
T2_5=$(create_bead "Build and publish downloadable QEMU/VirtualBox VM image and Live ISO" 1 "task" "Allow macOS/Linux/Windows developers to try Vikix in 5 minutes without repartitioning hardware.")

# Epic 3: Void Supervision, Sandboxing & Lisp IPC Hardening (P1)
E3=$(create_bead "Epic 3: Void Linux Supervision, Sandboxing & Lisp IPC Hardening" 1 "epic" "Harden vikix-session, sandbox vikix-agent, and make StumpWM IPC multi-threaded and capability-gated.")
T3_1=$(create_bead "Migrate vikix-session background daemons to Void turnstile + user runit + cgroups v2" 1 "task" "Replace loose & jobs with turnstile ~/.config/service/ and cgroups v2 memory limits.")
T3_2=$(create_bead "Sandbox vikix-agent with Syd (SydBox 3) or Clampdown + kernel keyring secrets" 1 "task" "Enforce Landlock LSM + seccomp restricted to ~/dev/<project> and move API keys out of plaintext ~/.config/vikix/secrets.")
T3_3=$(create_bead "Offload door.lisp and swank.lisp to background SBCL threads with capability RPC" 1 "task" "Use bordeaux-threads queues, rate limiting, and replace raw eval over vikix-door.")
T3_4=$(create_bead "Embed cl-mcp and mcp-lisp inside StumpWM SBCL image" 1 "task" "Integrate cl-ai-project/cl-mcp and jsulmont/mcp-lisp for native MCP and A2A support.")
T3_5=$(create_bead "Validate FASL compilation atomically in vikix update and create XBPS templates" 2 "task" "Prevent broken Lisp builds from breaking StumpWM startup and package vikix-core for XBPS.")
bd dep add "$T3_4" "$T3_3"

# Epic 4: Multi-Agent Memory, Specs & Pre-Collision Stack (P1)
E4=$(create_bead "Epic 4: Multi-Agent Memory, Specs & Pre-Collision Stack" 1 "epic" "Integrate OpenSpec, Beads, Beady-Eye, Foremerge, Jujutsu, and ACP into Vikix.")
T4_1=$(create_bead "Wire OpenSpec -> Beads (bd) -> Beady-Eye (bdi) into vikix-project and vikix-agent" 1 "task" "Auto-run bd prime and bd ready --claim in workers; use beady-eye + herdr to wake sleeping agents on gate resolution.")
T4_2=$(create_bead "Bundle Foremerge MCP and Jujutsu (jj) for conflict-free parallel agents" 1 "task" "Integrate naw103/foremerge pre-edit symbol scope declarations and jj working-copy snapshots.")
T4_3=$(create_bead "Connect Herdr states, Beads Gates, and Molecules to modeline.lisp and viri.lisp" 1 "task" "Show working/blocked/idle agent counts on modeline, build Super+r Agent Inbox, and map Molecules to Strip swimlanes.")
T4_4=$(create_bead "Add Agent Client Protocol (ACP) and bundle beads.el, beads.nvim, gptel-agent, mardi-gras, perles" 2 "task" "Add editor plugins and TUI dashboards to features.list.")
bd dep add "$T4_1" "$T1_2"
bd dep add "$T4_3" "$T3_3"
bd dep add "$T4_3" "$T4_1"

# Epic 5: Productivity, Self-Learning, Research & Investing (P2)
E5=$(create_bead "Epic 5: Productivity, Self-Learning, Research & Investment Workflows" 2 "epic" "Layer HUD inspection, local semantic search, Gas Town formulas, and financial tools onto Vikix.")
T5_1=$(create_bead "Build Super+? Inspect Anything HUD, vikix lab tutorials, and Nyxt Lisp bridge" 2 "task" "Expose live ~/vikix/lisp/ definitions, explain vikix changes diffs, and connect atlas-engineer/nyxt over Swank.")
T5_2=$(create_bead "Add Super+c multimodal capture, Super+v voice push-to-talk, and Stringer/Thread standups" 2 "task" "Upgrade vikix-ask and integrate stringer + Thread into vikix-day evening summaries.")
T5_3=$(create_bead "Deploy sqlite-vec local semantic search over cl-mcp and build vikix read <url|pdf>" 2 "task" "Index ~/dev/ and ~/dev/research/ locally for offline agent retrieval.")
T5_4=$(create_bead "Author Beads Formulas for Gas Town Refinery/Seance, vikix preview, and vikix invest/finance" 2 "task" "Implement bisecting merge queue, session seance, financial 10-K analyzer, and UAE Free Zone runway modeler.")
bd dep add "$T5_3" "$T3_4"
bd dep add "$T5_4" "$T4_1"

# Epic 6: Vikix Cloud & Next-Gen Virtualization (P2)
E6=$(create_bead "Epic 6: Productizing Vikix Mobile/Cloud & Next-Gen Isolation" 2 "epic" "Turn the roaming setup into a turn-key command, isolate GUI agents in Xvfb, and add Btrfs/ZFS CoW Tournament Mode.")
T6_1=$(create_bead "Package Phase 1 roaming stack into vikix mobile / vikix cloud CLI and Gas City pack" 2 "task" "Automate Tailscale + Herdr + Roamgate + b9s + bd dolt sync and add API cost router.")
T6_2=$(create_bead "Isolate GUI Computer-Use agents inside virtual Xvfb displays on The Strip" 2 "task" "Render virtual displays as picture-in-picture windows in viri.lisp so GUI agents never hijack the physical cursor.")
T6_3=$(create_bead "Upgrade vikix snapshot to Btrfs/ZFS CoW subvolumes and add Multi-Model Tournament Mode" 2 "task" "Enable instant CoW workspace branching to race 3 frontier models on the same Bead in parallel.")
bd dep add "$T6_1" "$T1_3"
bd dep add "$T6_3" "$T4_1"

echo "All Vikix Roadmap Epics and Tasks created. Run 'bd ready' to view claimable work."
```
