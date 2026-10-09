# Vikix Cloud — the computer extended into the cloud

An idea of Vid's, written down 2026-10-09 and kept here as he gave it, for a design to be drawn up in the house style when it is picked. It builds on `DESIGN-machines.md` (2026-10-04: Tailscale, Syncthing, KDE Connect, `vikix machines` and `--on NAME` for the doors): that design joins the machines Vid already has; this one adds machines rented to be always on, and the product that could sell them. Where the two name the same thing differently (`vikix machines` there, `vikix nodes` here), the one that ships decides.

---

## Core idea

Vikix Cloud should not primarily feel like a VPS that the user logs into.

It should feel like a **literal extension of the user's existing Vikix computer**.

The local laptop/desktop and one or more remote cloud machines should behave as parts of a single Vikix environment.

The user should think:

> My computer does not end at my laptop.

rather than:

> I have rented a remote server.

---

## Product concept

A Vikix installation can contain multiple **Vikix Nodes**.

For example:

```text
Vikix
├── x1          local laptop
├── desktop     local/home workstation
├── atlas       cloud node
└── forge       powerful remote build node
```

Nodes may be:

- local computers
- remote computers
- Vikix Cloud machines
- dedicated build machines
- GPU machines
- future business/internal infrastructure

All nodes belong to the same Vikix environment.

---

## Architecture

```text
                         VIKIX
                           │
                       VIKIX CORE
                           │
              ┌────────────┴────────────┐
              │                         │
         LOCAL NODE                 CLOUD NODE
              │                         │
      Void + StumpWM              Void headless
              │                         │
              └──────── Vikix Mesh ─────┘
```

The local node remains the interactive desktop environment.

The cloud node provides persistent remote resources.

---

## Local node responsibilities

Typical local-machine workloads:

- StumpWM desktop
- GUI applications
- editing
- browser
- audio/video
- local hardware
- low-latency interaction
- offline work
- private local files

The local node should remain a normal Void/Vikix machine.

---

## Cloud node responsibilities

Typical cloud workloads:

- long-running processes
- AI agents
- builds
- automated tests
- websites
- services
- databases
- cron/scheduled jobs
- downloads
- backups
- large storage
- rendering
- workloads that should continue when the laptop is off

Cloud nodes should normally be headless Void Linux systems using runit and the same Vikix Core concepts as the desktop.

---

## Important design principle

Do not treat Vikix Desktop and Vikix Cloud as two unrelated products.

Instead:

```text
Vikix Desktop = local Vikix node
Vikix Cloud   = remote Vikix node
```

Vikix Cloud can eventually become the commercial service that supplies remote nodes.

---

## Initial CLI concept

Add the concept of nodes.

Possible commands:

```bash
vikix nodes
vikix node status atlas
vikix node shell atlas
vikix node run atlas <command>
```

Example:

```bash
vikix nodes
```

Possible output:

```text
NAME       TYPE       STATUS     SYSTEM
x1         local      online     Void / StumpWM
atlas      cloud      online     Void / headless
forge      cloud      stopped    Void / headless
```

---

## Remote execution

The user should be able to execute work explicitly on another node.

Example:

```bash
vikix run --on atlas make test
```

or:

```bash
vikix node run atlas make test
```

Normal execution remains local:

```bash
vikix run make test
```

Later we may add:

```bash
vikix run --best make test
```

where Vikix selects or recommends an appropriate node.

Do not implement automatic scheduling in the first version.

---

## Projects

Vikix should understand projects independently of machines.

Example:

```text
PROJECT        LOCAL       ATLAS       FORGE
vikix          yes         yes         -
creator        yes         yes         yes
word-wizard    yes         yes         -
```

Possible commands:

```bash
vikix project list
vikix project status vikix
vikix project send vikix --to atlas
vikix project pull vikix --from atlas
```

For the initial version, project transfer should be explicit.

Do NOT attempt transparent Dropbox-style bidirectional home-directory synchronization.

---

## Git should be the primary synchronization mechanism initially

For software projects, prefer Git.

Possible flow:

```text
local work
    ↓
git commit/push
    ↓
cloud node pulls
    ↓
build/test/run
```

Vikix may provide convenience commands around this.

Example:

```bash
vikix project update vikix --on atlas
```

This could perform a controlled Git fetch/pull on the remote workspace.

Avoid inventing a complex file synchronization protocol in v0.1.

---

## Non-Git file transfer

For files that are not Git-managed, provide explicit transfer commands.

Possible commands:

```bash
vikix send ./file.zip atlas:
vikix get atlas:/path/result.zip
```

or:

```bash
vikix node push atlas ./data
vikix node pull atlas ~/results
```

Implementation can initially use standard tools such as rsync/scp.

Vikix should orchestrate proven Unix tools rather than reimplement file transport.

---

## Vikix Mesh

Nodes should eventually communicate over a private encrypted network.

Possible implementation underneath:

- WireGuard
- Tailscale initially if useful
- later native WireGuard management

Concept:

```text
x1       10.x.x.2
atlas    10.x.x.10
forge    10.x.x.11
```

The user should not normally need to remember addresses.

Friendly names should work conceptually:

```text
atlas.vikix
forge.vikix
db.vikix
```

Exact naming implementation can be decided later.

---

## Private services

A major benefit of the Vikix Mesh is that services do not have to be exposed publicly.

Example:

```bash
vikix service start postgres --on atlas
```

A local application could connect privately to the database on atlas.

Public exposure should be an explicit action.

Example:

```bash
vikix service expose myapp
```

This could later configure:

- reverse proxy
- DNS
- TLS
- firewall
- health checks

Do not require this for the first node prototype.

---

## Jobs

Remote nodes should eventually support persistent jobs.

Example:

```bash
vikix job run --on atlas "make test"
```

Possible:

```bash
vikix jobs
```

Output:

```text
ID      NODE      STATUS       COMMAND
101     atlas     complete     make test
102     atlas     running      codex ...
103     forge     running      render ...
```

The key value is that jobs continue after the local laptop disconnects or shuts down.

---

## AI agents

AI should be treated as one workload category, not the identity of the product.

Examples:

```bash
vikix agent codex --on atlas
vikix agent claude --on atlas
vikix agent gemini --on atlas
```

Potential future behaviour:

```bash
vikix agent run --on atlas "upgrade dependencies and run tests"
```

The cloud node can keep an agent working after the laptop is closed.

Do not make Vikix Cloud dependent on a specific AI provider.

---

## Moving work to the cloud

Long term, a useful abstraction could be:

```bash
vikix move --to atlas
```

This should not initially mean true process migration.

Instead, Vikix could:

1. determine the current project
2. synchronize project state
3. reproduce required environment on the remote node
4. restart/reconstruct the job remotely

From the user's perspective this feels like:

> Continue this work on the cloud machine.

True process/checkpoint migration is out of scope.

---

## Storage model

Vikix may eventually classify data into three categories:

```text
LOCAL
Only exists on the current node.

SYNCED
Deliberately replicated between selected nodes.

CLOUD
Stored primarily on a remote/cloud node.
```

Do not synchronize the complete `$HOME` automatically.

Potential examples:

```text
~/Projects/vikix      Git-managed
~/Documents/notes     optionally synced
~/Videos/raw          local
~/Cloud/builds        cloud
~/Cloud/backups       cloud
```

The user should retain explicit control over where data lives.

---

## Resource awareness

Nodes should eventually advertise capabilities.

Example:

```text
NODE       CPU        RAM       GPU       ALWAYS ON
x1         8 cores    32 GB     no        no
atlas      8 vCPU     16 GB     no        yes
forge      16 vCPU    64 GB     yes       yes
```

Later:

```bash
vikix run --best <command>
```

could recommend or select a suitable node.

Examples:

- compile on a faster node
- render on a GPU node
- run persistent agents on an always-on node
- keep interactive work local

Automatic scheduling is a future feature, not v0.1.

---

## StumpWM integration

The local Vikix desktop uses Void + StumpWM.

Cloud nodes should normally remain headless.

StumpWM can later expose cloud/node functions.

Potential menu:

```text
Vikix Nodes

x1
atlas
forge

Actions:
- shell
- projects
- jobs
- services
- agents
- files
```

This is a future convenience layer.

The CLI and underlying APIs should remain primary.

---

## Core principle

Anything Vikix automates must remain accessible using normal Linux tools.

Examples:

- SSH remains SSH
- runit remains runit
- xbps remains xbps
- Git remains Git
- rsync remains available
- WireGuard remains accessible
- services remain normal Linux processes

Vikix should provide a coherent layer on top rather than create a proprietary prison.

---

## Suggested first prototype

Do NOT build a hosting platform yet.

Use:

```text
Node 1:
Existing Vikix laptop
Void Linux + StumpWM

Node 2:
One inexpensive VPS
Void Linux
headless
Vikix Core
```

The first objective is to make these two machines feel like one system.

---

## v0.1 scope

Implement only enough to prove the node concept.

Suggested minimum:

```bash
vikix nodes
vikix node add
vikix node remove
vikix node status
vikix node shell
vikix node run
```

Then:

```bash
vikix project send
vikix project pull
```

or equivalent explicit project transfer.

Initial networking may simply use SSH.

Do not require a mesh/VPN for the first prototype if that slows development.

---

## Possible v0.1 workflow

Add remote node:

```bash
vikix node add atlas user@server.example.com
```

List nodes:

```bash
vikix nodes
```

Connect:

```bash
vikix node shell atlas
```

Run remotely:

```bash
vikix node run atlas uname -a
```

Run tests remotely:

```bash
vikix node run atlas "cd ~/Projects/vikix && make test"
```

Send project:

```bash
vikix project send vikix --to atlas
```

Then execute:

```bash
vikix run --on atlas make test
```

---

## Configuration concept

Potential config:

```text
~/.config/vikix/nodes/
```

For example:

```text
~/.config/vikix/nodes/atlas.toml
```

Possible state:

```toml
name = "atlas"
type = "cloud"
host = "atlas.example.com"
user = "vid"
transport = "ssh"
```

Do not commit to TOML if the existing Vikix project already has a preferred configuration format.

Follow existing Vikix conventions.

---

## Security requirements

Initial implementation should:

- use SSH keys
- never store plaintext passwords
- verify host keys
- avoid exposing remote services by default
- avoid running commands as root unless necessary
- preserve normal Unix permissions
- keep secrets outside project repositories
- log important node operations where useful

Later we can design a full Vikix secrets subsystem.

---

## What not to build yet

Explicitly out of scope for the first implementation:

- customer accounts
- billing
- WHMCS
- SolusVM
- automatic VPS provisioning
- multi-region hosting
- transparent whole-home-directory synchronization
- distributed filesystem
- true process migration
- automatic workload scheduling
- web dashboard
- GPU scheduling
- commercial cloud API
- mobile app
- Kubernetes
- replacement for SSH/Git/rsync/WireGuard

Keep the first implementation small.

---

## Product direction

If this works well personally, the eventual commercial product becomes:

> Vikix Cloud supplies remote Vikix Nodes that attach directly to a user's existing Vikix environment.

Therefore the user is not primarily buying:

```text
4 vCPU
8 GB RAM
120 GB SSD
```

They are buying:

```text
always-on compute
remote execution
persistent jobs
remote storage
services
build capacity
agents
access from anywhere
```

The infrastructure specification becomes secondary.

---

## Product message

Possible conceptual positioning:

> **Vikix extends your computer into the cloud.**

or:

> **One Vikix system. Local and cloud.**

or:

> **Your computer doesn't end at your laptop.**

Do not make the primary message about:

- VPS hosting
- Void Linux
- AI
- infrastructure specifications

Those are supporting technical details.

---

## Immediate agent task

Before implementing large changes:

1. Inspect the existing Vikix repository.
2. Understand its current architecture, conventions, language, configuration format, CLI design, tests, and addon system.
3. Identify where a node abstraction fits naturally.
4. Do not replace or rewrite working Vikix architecture unnecessarily.
5. Propose a minimal implementation plan for the following first milestone:

```text
Laptop + one remote Void machine

vikix nodes
vikix node add
vikix node status
vikix node shell
vikix node run
```

6. Prefer SSH and existing Unix tooling for the first implementation.
7. Include tests.
8. Preserve compatibility with the existing Void Linux + StumpWM Vikix environment.
9. Do not introduce Ubuntu, Debian, systemd, or Wayland assumptions.
10. Present the proposed file changes and architecture before making major invasive modifications.

The objective of this milestone is not to build Vikix Cloud commercially.

The objective is to prove that a remote Void machine can feel like a natural extension of the existing Vikix computer.
