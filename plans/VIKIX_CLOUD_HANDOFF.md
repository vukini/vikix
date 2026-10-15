# Vikix Cloud / Nodes — Development Handoff

> **Repository note — 2026-10-15:** Imported from Vid's development handoff.
> The original planning text below is retained as context, not a second roadmap.
> Follow [the Cloud design](DESIGN-cloud.md) and [TODO 117](../TODO.md)
> for current scope and progress. The node registry and SSH commands shipped
> on 2026-10-12 in `bin/vikix-node`; `vikix nodes` is the chosen name.
> The initial implementation prompts below predate that work: continue from
> explicit project send/pull and a real laptop-to-Void-VPS trial rather than
> rebuilding the shipped commands. See [the node guide](../docs/nodes.md)
> for the implemented interface. Later commercial and infrastructure ideas
> remain context, outside TODO 117.

**Repository:** `https://github.com/vukini/vikix`  
**Primary target:** TODO 117  
**Existing design:** `plans/DESIGN-cloud.md`  
**Related design:** `plans/DESIGN-machines.md`  
**Status:** Planning complete enough to begin the first implementation slice.

---

# 1. Read this first

This is a handoff for continuing Vikix development on the computer using Codex, Claude Code, or another coding agent.

Do **not** start by building a hosting company.

Do **not** start with billing, customer accounts, SolusVM, WHMCS, multi-region infrastructure, a web dashboard, or automatic VPS provisioning.

The immediate goal is much smaller:

> Make one remote Void Linux machine feel like a natural extension of the existing local Vikix machine.

The first real user is Vid.

The first test environment is:

```text
LOCAL
Existing Vikix laptop
Void Linux + StumpWM

        │
        │ SSH initially
        ▼

REMOTE
One inexpensive VPS
Void Linux
headless
Vikix-compatible environment
```

If this is genuinely useful in everyday development, it can later become Vikix Cloud as a commercial product.

---

# 2. Important: this idea is already in the repository

Do not create a duplicate plan.

The current repository already contains:

- `plans/DESIGN-cloud.md`
- `plans/DESIGN-machines.md`
- `TODO.md` item **117**
- `plans/README.md` entry for the cloud design
- `CLAUDE.md`, which is deliberately also the instruction source for Codex

TODO 117 currently defines the v0.1 milestone as:

- node configuration/state
- `vikix nodes`
- `vikix node add NAME USER@HOST`
- `vikix node remove NAME`
- `vikix node status NAME`
- `vikix node shell NAME`
- `vikix node run NAME COMMAND`
- explicit project send/pull
- real-world testing between the local laptop and one cheap Void VPS

The agent should work from and update these existing files rather than inventing another roadmap.

---

# 3. Product idea

Vikix Cloud is not primarily a VPS hosting product.

The core idea is:

> **Vikix extends the local computer into the cloud.**

The user should think:

> My computer does not end at my laptop.

not:

> I rented a server and need to administer it.

A Vikix system may eventually contain several nodes:

```text
Vikix
├── x1          local laptop
├── desktop     local/home workstation
├── atlas       always-on cloud node
└── forge       future high-power/GPU node
```

A node can be:

- local
- remote
- always-on
- cloud-hosted
- a build machine
- an AI workstation
- a future business/internal server

All remain ordinary Linux systems underneath.

---

# 4. Vikix technical identity

Do not accidentally genericize Vikix while implementing cloud support.

Vikix is currently:

```text
glibc Void Linux
+
xbps
+
runit
+
StumpWM on the desktop
+
Vikix tooling and configuration
```

For the cloud:

```text
glibc Void Linux
+
xbps
+
runit
+
Vikix Core
+
headless operation
```

The default cloud node should **not** require:

- Ubuntu
- Debian
- systemd
- Wayland
- a graphical desktop
- StumpWM

StumpWM belongs on interactive desktop nodes.

Void is the shared platform.

Use **glibc Void**, not musl, for the first cloud node because third-party developer and AI tooling is more likely to work cleanly.

---

# 5. Architectural principle

The architecture should move toward:

```text
                         VIKIX
                           │
                       VIKIX CORE
                           │
              ┌────────────┴────────────┐
              │                         │
         LOCAL NODE                 REMOTE NODE
              │                         │
      Void + StumpWM              Void headless
              │                         │
              └────── one Vikix ────────┘
```

Do not prematurely split Vikix into two unrelated products called Desktop and Cloud.

The cloud service, if it exists later, supplies remote Vikix nodes.

---

# 6. What belongs where

## Local node

Good local workloads:

- StumpWM
- editors
- browser
- interactive terminal work
- audio/video
- local devices
- offline work
- private local-only files
- low-latency interaction

## Remote node

Good remote workloads:

- long-running jobs
- builds
- tests
- development services
- websites
- databases
- scheduled jobs
- downloads
- backups
- rendering
- persistent AI agents
- work that should continue after the laptop sleeps

The purpose is not to move everything to the cloud.

The purpose is to add an **always-on half** to the same system.

---

# 7. Existing Vikix designs that overlap

Before modifying architecture, read:

```text
plans/DESIGN-cloud.md
plans/DESIGN-machines.md
TODO.md
CLAUDE.md
bin/vikix-project
```

There is deliberate overlap between two earlier concepts:

## `DESIGN-machines.md`

This predates Cloud and describes:

- `vikix machines`
- Tailscale
- Syncthing
- KDE Connect
- `--on NAME`
- export/import
- existing personal machines as one Vikix

## `DESIGN-cloud.md`

This extends the idea with:

- rented always-on nodes
- `vikix nodes`
- remote execution
- projects on nodes
- jobs
- future services
- future agent execution
- possible commercial Vikix Cloud

The repository explicitly says that where `machines` and `nodes` conflict in naming, **the implementation should decide what ships**.

Do not blindly implement both concepts as separate overlapping registries.

The first architectural task is to decide whether:

1. a node is the general abstraction and `machines` becomes a view/subset, or
2. machine remains the general abstraction and cloud nodes are a machine kind.

Prefer one source of truth.

Do not add parallel state stores for the same physical computer.

---

# 8. Existing project model

`bin/vikix-project` already knows where projects live and how they are identified.

Do not write a second project discovery system.

Current project concepts include:

- project roots
- `log.md`
- public repos with separate project logs
- collections
- build/check commands
- project path lookup

Cloud project commands should build on this.

For example, a future command:

```bash
vikix project send vikix --to atlas
```

should obtain the local project path through the existing project machinery.

---

# 9. Core v0.1 UX

The first useful interface should be small.

## List nodes

```bash
vikix nodes
```

Conceptual output:

```text
NAME       KIND       STATUS     SYSTEM
x1         local      online     Void / StumpWM
atlas      remote     online     Void / headless
```

Do not overbuild the table initially.

## Add a node

```bash
vikix node add atlas vid@atlas.example.com
```

This should:

1. validate the node name
2. record the endpoint
3. require key-based SSH or at least avoid storing passwords
4. verify SSH host identity using normal OpenSSH behaviour
5. test reachability
6. record enough information for later commands

Do not invent an SSH implementation.

Use OpenSSH.

## Status

```bash
vikix node status atlas
```

Useful initial status:

```text
atlas
  endpoint: vid@atlas.example.com
  online:   yes
  system:   Void Linux
  vikix:    <version or not installed>
```

Later this can grow to CPU/RAM/storage/jobs/services.

## Shell

```bash
vikix node shell atlas
```

This should effectively be a convenient, correctly-configured SSH connection.

SSH must remain visibly accessible as SSH.

## Remote command

```bash
vikix node run atlas uname -a
```

or:

```bash
vikix node run atlas -- make test
```

The implementation must preserve arguments safely.

Do not build remote commands by unsafe shell string concatenation.

The command should return the remote command's exit status.

---

# 10. Node configuration and state

TODO 117 already says:

- configuration belongs below `~/.config/vikix/`
- runtime/discovered state belongs below `~/.local/state/vikix/`
- use the format/conventions Vikix already uses

Do not choose TOML merely because the design document contains an example.

First inspect how Vikix currently stores equivalent settings.

Possible conceptual separation:

```text
~/.config/vikix/nodes
    user choices / declared nodes

~/.local/state/vikix/nodes/
    cached/discovered state
    last-seen
    versions
    capabilities
```

Requirements:

- configuration should be human-readable
- it must be easy to back up
- secrets must not be stored in it
- no plaintext SSH passwords
- avoid state that duplicates information OpenSSH already owns
- do not hide or bypass `~/.ssh/config`

Consider allowing a node to refer naturally to an existing SSH host alias.

For example:

```bash
ssh atlas
vikix node add atlas atlas
```

may be better than duplicating hostname/user/port configuration.

The agent should inspect the current Vikix style and propose the smallest clean design before implementing.

---

# 11. Security principles for v0.1

Required:

- SSH keys
- standard SSH host-key checking
- no plaintext passwords
- no automatic disabling of host verification
- no broad root requirement
- no public service exposure merely because a node was added
- no secret copying as part of project transfer
- no whole-home synchronization
- preserve normal Unix permissions
- remote command argument handling must be safe

Do not use conveniences such as:

```text
StrictHostKeyChecking=no
```

as a default.

A new host can be accepted interactively by normal SSH or through an explicit Vikix enrollment process, but trust must not be silently bypassed.

---

# 12. Project movement

This comes after the basic node commands work.

The first version should be explicit.

Possible UX:

```bash
vikix project send vikix --to atlas
vikix project pull vikix --from atlas
```

Do not build transparent synchronization.

## Git repository

Git is the preferred transport/coordination mechanism.

A sensible workflow is:

```text
local work
    ↓
commit
    ↓
push
    ↓
remote fetch/pull
    ↓
build/test/run
```

Vikix may wrap this where useful.

The implementation must respect:

- dirty working trees
- unpushed commits
- divergent branches
- repositories without remotes

Do not silently discard or overwrite any work.

## Non-Git project

Use an existing Unix transport such as:

- `rsync`
- `scp`

Do not invent a new synchronization protocol.

Avoid:

- `.git` duplication when Git transport is being used
- caches
- build artefacts where appropriate
- secrets
- dependency directories such as `node_modules`

Exact default exclusions should be conservative and documented.

---

# 13. What v0.1 deliberately does NOT include

Do not implement any of these as part of TODO 117 unless the repository's owner explicitly expands the scope:

- VPS provider integration
- machine purchasing
- cloud-provider APIs
- WHMCS
- SolusVM
- Proxmox control
- customer accounts
- subscriptions
- payments
- commercial pricing logic
- a web dashboard
- mobile application
- whole-home synchronization
- distributed filesystem
- automatic conflict resolution
- process migration/checkpointing
- Kubernetes
- automatic resource scheduling
- `--best`
- GPU scheduling
- public service exposure
- managed databases
- commercial backup product
- multi-region infrastructure

These are future product possibilities, not the personal prototype.

---

# 14. Networking: SSH first, mesh later

The first prototype should work over ordinary SSH.

This deliberately keeps the proof small.

Later, the existing machines design can add a private network, probably Tailscale initially.

Possible future topology:

```text
x1
 │
 │ private tailnet
 │
 ├──────── atlas
 ├──────── office
 └──────── forge
```

But TODO 117 explicitly says the mesh is not required for the first milestone.

Do not block v0.1 on it.

---

# 15. Long-term features — context only

These explain why the node abstraction matters, but they are not immediate implementation work.

## Persistent jobs

Eventually:

```bash
vikix job run --on atlas "make test"
vikix jobs
```

The important property:

> the job survives the laptop disconnecting.

## Agents

Eventually:

```bash
vikix agent codex --on atlas
vikix agent claude --on atlas
vikix agent gemini --on atlas
```

AI is a workload, not the product identity.

Do not make Vikix Cloud dependent on one provider.

## Services

Eventually:

```bash
vikix service start postgres --on atlas
vikix service expose app
```

Private-by-default services should eventually fit naturally into the node model.

## Resource awareness

Eventually:

```text
NODE       CPU      RAM      GPU    ALWAYS ON
x1         ...      ...      no     no
atlas      ...      ...      no     yes
forge      ...      ...      yes    yes
```

Later:

```bash
vikix run --best ...
```

may recommend a node.

No automatic scheduler in v0.1.

## "Move this work"

Possible future UX:

```bash
vikix move --to atlas
```

This would initially mean reconstructing the work remotely, not live process migration.

---

# 16. Commercial direction — context only

If personal usage validates the concept, Vikix Cloud could eventually sell managed remote Vikix nodes.

The product message should not lead with:

- VPS
- Void Linux
- AI
- vCPU/RAM/storage specifications

The conceptual promise is closer to:

> **Vikix extends your computer into the cloud.**

or:

> **One Vikix system. Local and cloud.**

The infrastructure is a means to provide:

- always-on compute
- persistent jobs
- services
- builds
- remote storage
- agents
- access from anywhere

Void Linux is the foundation, not necessarily the marketing headline.

AI tools are supported workloads, not the identity of the product.

---

# 17. Why the personal prototype comes first

Commercial hosting is a much larger project.

Before building it, prove:

> Vid actually prefers using the remote Vikix node for some real work over using a generic VPS.

Good evidence would be:

- remote builds become normal
- persistent jobs are useful
- the same project is comfortably usable local and remote
- connecting to the remote node feels like a Vikix operation rather than server administration
- the cloud node is missed when unavailable

Bad evidence would be:

- commands are just cosmetic aliases
- using the node requires constant manual SSH/server work
- project movement is risky/confusing
- Void compatibility creates excessive friction
- Vid continues ignoring the remote node

If the personal prototype does not create daily value, do not build the hosting business.

---

# 18. Likely personal infrastructure

For development/dogfooding, one server is enough initially.

Suggested class:

```text
4–8 vCPU
8–16 GB RAM
100–200 GB SSD/NVMe
Void Linux glibc
public SSH initially
```

16 GB RAM is useful if the node will eventually run:

- development builds
- containers
- Codex/Claude/Gemini CLIs
- several services
- Creator tooling

A second cheap disposable VPS can later be used for destructive clean-install tests.

Do not buy hardware or colocation for this phase.

---

# 19. Internal-company use later

Vikix Cloud may eventually also become useful internally at Link Middle East and Centaur.

This is not TODO 117, but it is strategically relevant.

FACTS ERP on Azure should remain the system of record initially.

Potential Vikix-hosted additions later:

- production dashboards
- sales-order → production workflows
- BOM/BOQ tooling
- raw-material planning
- machine loading
- quotation tools
- alerts
- operational analytics
- document automation
- internal workflow apps
- management dashboards
- Centaur opportunity/project tooling

The ERP should not be replaced as part of the cloud-node prototype.

Any future ERP writes should use controlled supported integration/API paths rather than unrestricted database access.

---

# 20. Agent workflow: Claude + Codex

Vikix deliberately supports multiple coding agents.

There is no inherent problem mixing Claude and Codex if the repository is the source of truth.

The current repository uses `CLAUDE.md` for both.

Do not create a competing `AGENTS.md` unless project conventions explicitly change.

Important:

- both agents read the same design
- one task has one owner at a time
- agents work in separate worktrees/desks
- architecture belongs in repo docs, not model memory
- commits should be small enough for another agent to review
- do not have two agents make open-ended edits to the same feature simultaneously

A useful pattern is:

```text
spec/design
    ↓
Codex implementation
    ↓
Claude review
    ↓
Codex fixes
    ↓
tests
    ↓
release
```

The roles may be reversed.

---

# 21. Mandatory Vikix repository working rules

Read `CLAUDE.md` fully before making changes.

Important current rules include:

## Never edit `~/vikix`

`~/vikix` is the installed checkout.

Development happens in `~/src/vikix` or, normally, a dedicated worktree.

## Take a desk

Before writing:

```bash
cd ~/src/vikix
vikix agents sit vikix cloud-nodes
```

Work only in the resulting worktree.

If already launched in an agent desk, verify it with the existing Vikix agent commands and use that desk.

The repository's house rules intentionally reject writes when an agent has not taken a desk.

## Parallel work

Each agent/session gets its own worktree.

Do not use the main checkout as a scratch working tree.

## Commit only files you changed

Do not:

```bash
git add -A
git commit -a
```

Add specific file paths.

## Try on the installed desktop

The repository has `vikix try` for testing a committed branch on the installed Vikix environment.

Read the exact current instructions in `CLAUDE.md`.

Do not manually edit the installed checkout.

## Release

Use the repository's `.claude/release` workflow.

Do not hand-roll the version bump/merge/release process.

---

# 22. Documentation rules

Every `bin/vikix*` command has a documented header format.

When adding a new command, follow existing headers exactly.

After changing a command header, regenerate:

```bash
python3 lib/man.py --guide > docs/commands.md
```

Do not edit `docs/commands.md` manually.

Update the user guide when a public command or path changes.

TODO handling:

- work is tracked in `TODO.md`
- TODO number 117 is already assigned to this feature
- when a part ships, update TODO 117
- if fully shipped, move it to `ARCHIVE.md`
- never reuse TODO numbers

Design handling:

- `plans/DESIGN-cloud.md` already exists
- update it if the design changes
- do not create another equivalent cloud-design file

---

# 23. Testing expectations

Before saying a change is complete:

- test the public command, not only helper functions
- bound every diagnostic/test command with a timeout where hanging is possible
- clean up all processes started by tests
- do not broadly kill processes by name
- preserve the user's running desktop/session
- distinguish unit tests from real-machine validation
- report exactly what was tested

The first milestone should have isolated tests that do not require a real remote VPS.

Mock/stub `ssh` where appropriate.

Then separately perform a real test with the cheap Void VPS.

---

# 24. Suggested implementation architecture

The agent must inspect the repository first; this is guidance, not permission to force a structure that conflicts with existing conventions.

A likely approach:

```text
bin/vikix-node
    node CRUD
    node status
    node shell
    node run

possibly:
lib/nodes.py
    configuration/state parsing
    node matching
    ssh command construction
    capability/status helpers

tests/nodes.sh
    isolated node CLI tests
    stubbed SSH
```

But follow existing Vikix style.

If the normal pattern is a single executable rather than a library split, use that.

Do not introduce a framework for six commands.

Prefer standard library + existing shell/Python tools already used in Vikix.

---

# 25. Naming decision to make before substantial code

There is an unresolved conceptual collision:

```text
vikix machines
```

vs.

```text
vikix nodes
```

Before implementing two systems, inspect the existing state of TODO items 16–19 and any code already present.

Then propose one coherent model.

Possible model:

```text
Node
├── local-computer
├── remote-computer
├── cloud
└── phone/device where applicable
```

or:

```text
Machine
├── local
├── remote
└── cloud
```

Phones may not fit the same execution abstraction, so do not force them into `node` solely for conceptual purity.

The decision should optimize:

- simple user mental model
- no duplicate config
- future `--on NAME`
- future Tailscale integration
- future cloud nodes
- compatibility with the existing designs

Document the decision in `plans/DESIGN-cloud.md` and/or `DESIGN-machines.md`.

---

# 26. Phase plan

## Phase 0 — architecture reconnaissance

Before edits:

1. read `CLAUDE.md`
2. read TODO 117 in `TODO.md`
3. read `plans/DESIGN-cloud.md`
4. read `plans/DESIGN-machines.md`
5. inspect `bin/vikix`
6. inspect `bin/vikix-project`
7. inspect similar small commands with config/state
8. inspect test conventions
9. inspect whether any `machines`, Tailscale, or `--on` implementation has already landed
10. decide the node-vs-machine relationship

Deliverable:

A brief implementation note in the agent session describing:

- files to add/change
- config/state representation
- command routing
- SSH invocation model
- tests
- naming decision

Then proceed unless a genuine architectural blocker appears.

## Phase 1 — node registry

Implement:

```bash
vikix nodes
vikix node add
vikix node remove
```

Acceptance:

- human-readable config
- names validate
- duplicate names handled
- nonexistent removals handled clearly
- config directory creation safe
- no secrets
- tests pass

## Phase 2 — connection/status

Implement:

```bash
vikix node status NAME
vikix node shell NAME
vikix node run NAME COMMAND...
```

Acceptance:

- SSH key workflow
- normal host checking
- safe argument handling
- exit status preserved
- offline node reported clearly
- local command cannot accidentally be interpreted as remote shell syntax unless explicitly intended
- tests use stubbed SSH
- real smoke test against a Void VPS

## Phase 3 — remote Vikix awareness

When connecting to a node, detect useful non-invasive facts:

- Void or not
- Vikix installed or not
- Vikix version
- maybe hostname/kernel

Do not require Vikix on a node merely to SSH/run a command unless product design deliberately decides otherwise.

The first real cloud VPS should be Void.

## Phase 4 — projects

Implement explicit project transfer/update.

Start with Git repositories.

Then non-Git transfer using rsync/scp.

Acceptance:

- never silently overwrites uncommitted work
- clear dry-run/status where valuable
- no entire `$HOME`
- no automatic continuous sync
- secrets excluded
- tests cover dirty/divergent cases where possible

## Phase 5 — dogfood

Use the remote machine for real work.

Examples:

```bash
vikix node run atlas uname -a
vikix node shell atlas
vikix node run atlas '...'
vikix project send vikix --to atlas
```

Then actually:

- run Vikix tests there
- run a build there
- leave something running remotely
- use the node from another local device if available

Record friction in the project log/TODO rather than papering over it.

---

# 27. Definition of done for TODO 117

TODO 117 should not be marked complete merely because the commands exist.

It is complete when:

1. node configuration/state has a stable documented representation
2. `vikix nodes` works
3. add/remove works
4. status/shell/run works
5. project movement works explicitly
6. tests cover the local logic
7. one real Void VPS has been used
8. the laptop and VPS have been dogfooded enough to judge whether the concept feels coherent
9. relevant docs are updated
10. TODO 117 is moved/updated according to repository rules

The design explicitly requires the real trial.

---

# 28. Questions the implementation should answer through use

Do not over-discuss these before building the small prototype.

Use the prototype to answer them.

### Node vs machine

Which term feels right after using it?

### Does the remote need Vikix installed?

Possible levels:

1. any SSH host can be a node
2. Void host required
3. Vikix Core required
4. full Vikix Cloud image eventually

v0.1 can support level 1 operationally while testing the intended level 2/3 environment.

### Project transport

Does Git-only cover nearly all important developer workflows?

If yes, keep non-Git copying secondary.

### State

What remote information is genuinely useful enough to cache?

Avoid creating a stale mini-CMDB.

### Remote command UX

Which feels better:

```bash
vikix node run atlas make test
```

or:

```bash
vikix run --on atlas make test
```

The design can support the explicit node form first and add `--on` later.

### Private network

Does public SSH create enough friction/risk that Tailscale should move earlier?

Measure rather than assume.

---

# 29. Future personal-cloud milestones after TODO 117

These should become separate TODO items/design phases, not creep into 117.

Possible order:

1. Tailscale / unified private node network
2. `--on NAME` across selected existing Vikix commands
3. persistent remote jobs
4. remote agents
5. remote services
6. backup integration
7. resource/capability discovery
8. StumpWM node UI
9. automatic cloud-node provisioning
10. commercial account/billing layer

---

# 30. Commercial hypothesis — save for later

Possible eventual product:

> **A persistent Vikix developer machine that attaches to your existing Vikix system.**

Potential customer value:

- no server setup ritual
- consistent local/remote environment
- work survives laptop shutdown
- remote builds
- persistent agents
- easy services/deployment
- accessible from multiple devices

Potential commercial tiers discussed during planning were roughly:

```text
4 GB
8 GB
16 GB
```

with pricing above bargain-VPS levels because the product must sell the Vikix environment, not raw RAM.

Do not encode commercial pricing into the current implementation.

The hypothesis first needs personal validation and then 5–10 external users.

---

# 31. Financial guardrail

For the personal prototype, infrastructure should remain trivial.

Think:

```text
one 8–16 GB VPS
possibly one disposable smaller test VPS later
cheap backup/object storage only when required
```

No capital hardware.

No rack.

No Dubai colo.

No multi-region cluster.

Commercial infrastructure comes only after users demonstrate willingness to pay.

---

# 32. Product guardrails

Keep these principles visible during development:

1. **Vikix Cloud is not primarily an AI product.**
2. **Vikix Cloud is not primarily marketed as a Void VPS.**
3. **Void remains the native technical foundation.**
4. **The first customer is the existing Vikix user.**
5. **The first cloud product is an extension of the local computer.**
6. **AI agents are workloads, not the identity.**
7. **Normal Linux tools always remain available.**
8. **Do not recreate SSH, Git, rsync, runit, xbps, WireGuard, or backup engines.**
9. **Do not build commercial hosting until the personal node is genuinely useful.**
10. **The repository, not an AI agent's memory, is the source of truth.**

---

# 33. First prompt to give the coding agent

Use this after opening the Vikix repository on the development machine:

```text
We are starting TODO 117: Vikix nodes / the first Vikix Cloud prototype.

Read CLAUDE.md fully first. Then read TODO 117, plans/DESIGN-cloud.md,
plans/DESIGN-machines.md, bin/vikix-project, and inspect the current code
for machines/Tailscale/--on work so you do not duplicate anything that has
already landed.

Take a proper Vikix agent desk/worktree according to CLAUDE.md before making
any writes.

Goal for this first implementation slice:

    one local Vikix machine
    +
    one remote Void Linux machine

with the smallest coherent node abstraction.

Initial public interface:

    vikix nodes
    vikix node add NAME TARGET
    vikix node remove NAME
    vikix node status NAME
    vikix node shell NAME
    vikix node run NAME COMMAND...

Use ordinary OpenSSH underneath. Do not store passwords, disable host-key
checking, invent a transport protocol, or introduce Ubuntu/systemd assumptions.

Before editing, inspect existing Vikix configuration/state conventions and
the overlap between DESIGN-machines.md's `vikix machines` and
DESIGN-cloud.md's `vikix nodes`. Decide on one source of truth so we do not
create two registries for the same computers.

Present a concise implementation plan describing:
- naming decision (machines vs nodes relationship)
- files to add/change
- config/state format and locations
- SSH invocation/argument handling
- tests
- how the command will be routed from `vikix`

Then implement the smallest complete Phase 1/2 slice, with tests and docs,
following all repository conventions in CLAUDE.md.

Do not implement project synchronization, Tailscale, jobs, agents, services,
billing, provisioning, a dashboard, or commercial hosting in this first
slice unless existing code makes a tiny piece unavoidable.

When complete, report:
- exact files changed
- commands implemented
- tests run and results
- anything not tested on a real remote host
- the next smallest step
- whether TODO 117 should be partially updated

Do not claim the cloud-node concept is validated until it has been tried on
a real cheap Void VPS.
```

---

# 34. Recommended immediate sequence for Vid

On the computer:

```bash
cd ~/src/vikix
git status
git pull
```

Read the current status if desired:

```bash
grep -n "117\." TODO.md
less plans/DESIGN-cloud.md
less plans/DESIGN-machines.md
```

Then start the agent through the existing Vikix agent/Office workflow.

If starting manually, make sure the session takes a desk according to `CLAUDE.md`.

Give it the prompt in section 33.

The **first coding session should stop after a clean node registry + SSH execution slice**.

Do not ask it to "build Vikix Cloud" in one prompt.

---

# 35. Success criterion for the first development day

A successful first slice would look roughly like this:

```bash
$ vikix node add atlas vid@203.0.113.10
added atlas

$ vikix nodes
atlas    remote    online    Void

$ vikix node status atlas
atlas
  target: vid@203.0.113.10
  online: yes
  system: Void Linux
  vikix: not installed

$ vikix node run atlas uname -a
Linux atlas ...

$ vikix node shell atlas
[SSH session]
```

with:

- tests
- no security shortcuts
- no duplicated machine registry
- repository docs/headers kept consistent
- work done in the proper worktree
- no changes to `~/vikix`

That is enough progress.

The next session can decide how to bootstrap Vikix Core on the remote node and how project transfer should work.

---

# 36. The strategic question

Do not lose sight of this during implementation:

> Can a remote Void machine become sufficiently integrated that it feels like part of the same Vikix computer?

If yes, a commercial Vikix Cloud becomes plausible.

If not, the correct result of the prototype is to learn that cheaply before building a hosting company.
