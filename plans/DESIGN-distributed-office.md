# Distributed Vikix Office — intelligent management across machines

**Status:** Conceptual design, approved direction, not implemented. **Date:** 2026-10-22.  
**Owner:** User. **Scope:** Architecture and phased plan; no runtime or deployment changes authorized by this document.

## Vision and non-negotiable constraints

The Vikix Office becomes an intelligent, local-first organization rather than only an agent-status dashboard. One logical Office manages goals, ideas, research, plans, work, machines, evidence, decisions and outcomes across X1 Carbon, ROG Z13, later always-on compute and optional Vikix Cloud. It can manage engineering, research, knowledge and systems operations, and potentially other separately authorized projects.

**Chosen autonomy policy (2026-10-22):**
- **Research: investigate and propose.** Proactively discover, inspect approved information, investigate and draft proposals; bounded budget, no authoritative project modifications.
- **Engineering: execute approved work.** Once the human approves an immutable, scoped contract, workers may edit within isolated worktrees, run specified tests, repair within bounds and generate review artifacts. Approval to implement is NOT approval to release.
- **Operations: observe and report.** Read permitted passive diagnostics; no automatic package changes, service restarts, cleanup, backup restoration or active intrusive diagnostics. Such actions require separately approved work.
- **Releases: require explicit human approval.** No merge to protected release branch, publication, configuration rollout, or production deployment unless the human explicitly approves the exact candidate and targets. No broad standing release permission under this policy.

The Manager may suggest actions but **cannot grant itself authority, create self-approved engineering contracts, override the Policy Engine or modify its own governance**. Keep policy outside model reasoning and enforce it deterministically, at the coordinator and receiving node. No model output, retrieved README, webpage, repository comment or agent handoff is trusted instruction or proof of authorization.

**Desktop 1.0 remains the immediate release priority** (`DESKTOP-1.0.md`); this proposal must not displace gates A–D or smuggle Vikix Cloud into the 1.0 scope. This is a future architectural direction and may contribute only narrowly scoped, separately approved prerequisites to Desktop 1.0.

## Reuse what Vikix already owns

Do not build a competing Office, desk runtime, graph runner, scheduler or release mechanism.

- `DESIGN-office-tasks.md` / `lib/tasks.py`, `lib/scheduler.py`, `lib/office.py`: canonical task identity, provenance, queue, events, decisions, Office UI and scheduling.
- `DESIGN-agent-orchestration.md`, `lib/plan.py`, `tests/run.sh`: dependency contracts, acceptance gates, tested execution loops, retry and evidence design. Much is still proposed; do not describe design as shipped code.
- `DESIGN-machines.md`, `DESIGN-remote.md`, `DESIGN-cloud.md`, existing `vikix node`: connectivity, remote access and node substrate. Connectivity is not authorization.
- `DESIGN-phone.md`: eventual remote human interaction; its notification channel is not itself an approval root.
- `DESIGN-security.md` and Desktop 1.0 gates: signed updates, trust, rollback, security baseline.

The new layer adds **strategic goal management, idea lifecycle, research coordination, institutional memory, cross-machine task envelopes and enforceable authority** on top of those facilities.

## Logical architecture

```text
Emacs / terminal / ROG / X1 / eventual mobile and web interfaces
                         |
                  Office API / views
                         |
      Authoritative coordinator (single writer per Office)
      goals | idea registry | proposals | plans | decisions
      tasks/events | policy verifier | scheduler | audit
                         |
         authenticated work dispatch / event ingestion
               /                         \
     X1 Office Node                    Z13 Office Node
     isolated workers                  isolated workers
               \                         /
             approved artifacts / Git / evidence
                         |
                 verified release gate
               explicit human authorization
```

The coordinator is a small durable service supervised by runit on Void; model calls are episodic jobs, not a permanently thinking LLM. Keep the first version on one machine (initial candidate X1) with SQLite in WAL mode for one authoritative writer; interfaces and worker nodes may live elsewhere. When X1 sleeps the Office is unavailable for new authoritative actions, while clients can read cached state and prepare local drafts. Later migrate the coordinator to an always-on machine, and optionally Cloud, via controlled backup/restore and fencing — never active-active SQLite copies. Manual failover first; no split brain or speculative task reassignment.

The ROG can host an Office interface and a worker. Both machines retain their normal standalone Vikix experience if network or coordinator is unavailable.

### Office Manager, distinct from authority

Manager = goal-directed reasoning and orchestration. It reads allowed state, generates research questions, proposes priorities, composes plans, requests bounded workers and evaluates outcomes. It does **not** possess administrative credentials, push keys or the ability to alter the policy engine.

Policy Engine = deterministic trusted component which authorizes each action against identity, role, task contract, approved hash, scope, target, time, budget and revocation state. Receiving Office Node independently verifies authorization and only executes in its allowed sandbox.

Scheduler = the existing Office scheduler extended to remote execution, not another queue. Evidence checker and release path also extend existing runners, not replace them.

## First-class persistent objects

Extend existing task/event model, do not fork task identity:
- **Goal:** objective, owner, priority, excluded scope, metric/target, budget, validity and review cadence.
- **Idea:** stable ID, origin, project, relevance to goals, duplicate links, investigation state, disposition.
- **Evidence/claim:** source reference, date, file/line/commit when applicable, trust level, verified/uncertain/stale status; never treat a model claim as validation.
- **Proposal:** candidate solution, alternatives, risk, expected value, cost, affected systems, decision.
- **Plan revision:** task graph, dependencies, acceptance contract, authorized paths, required gates and budgets.
- **Task/attempt:** reuse canonical task IDs, events, providers, handoffs and attempts; immutable input refs.
- **Approval:** authenticated actor, decision, exact plan/contract/artifact digest, scope, target, expiry and revocation.
- **Machine/capability:** node identity, enrollment/revocation, service versions, test/tool capacity, available project access.
- **Artifact/outcome:** immutable build/test/report references, digests, provenance, deployment result and measured impact.
- **Policy:** versioned, protected authorization rules; no self-modification by model.

SQLite plus indexed relations/event history is enough for v1; a graph database is not required. Human-readable Markdown/Org plans are derived or linked documents, not concurrency-controlled authority records. Provide import/export and migration for existing Office records. Sensitive data partitioned by project/organization.

State machine for ideas: discovered -> investigating -> proposed -> approved/deferred/rejected -> planned -> implementing -> verified -> released -> measured; not every idea reaches implementation; multiple proposals per idea and multiple tasks per plan are normal. Separate idea state from task state and release state.

## Department responsibilities

- **Research and intelligence:** selected public sources, repo inspection, technology and failure research, deduplication, citation-backed proposals. Read-only tools; bounded retrieval, tokens and rate limits.
- **Engineering:** Research -> Plan -> Implement for complex work; approved contracts only; context packages containing relevant files, assumptions, decisions, constraints and source revisions; desk/worktree isolation; independent tests.
- **Systems operations:** passive health, disk, backup status, network and runit telemetry; clearly separated active diagnostics and remedies which are **not** autonomous under selected policy.
- **Knowledge:** store verified and source-linked architectural decisions; mark claims stale when source revisions change; no unvalidated memory becoming policy.
- **Business projects (future):** explicitly enrolled projects, separate credentials/authorities and data; no implicit access to Link Middle East/Centaur systems.

Manager standing goal example: seek evidence-supported improvements to Vikix reliability, usability, efficiency and maintainability; propose plans, do not implement until approved, do not deploy until release approval. Goals form a modest hierarchy (strategic goal -> initiative -> proposal -> plan -> tasks -> outcomes), with prioritization and measurable criteria. No unbounded autonomous backlog growth.

## Security and identity boundaries

1. **Transport:** private overlay network (e.g. Tailscale), TLS/mutual node authentication, device enrollment and per-node revocation. VPN membership alone confers no Office privileges. No unauthenticated public listener.
2. **Authorization:** human approvals authenticated separately from agent messages; bind to immutable contract revision, exact operation, candidate digest, destination, scope, policy version, expiry and nonce/idempotency key. Stale or changed candidates invalidate affected approvals and test evidence.
3. **Least privilege:** per-task short-lived scoped capabilities; never forward personal SSH agent, policy signing credentials or unrelated secrets into workers. Research has read-only datasets and restricted outbound access.
4. **OS isolation:** git worktrees and command hooks alone are not sandbox/security boundaries. Use a tested OS-enforced confinement layer (namespace/container/VM as appropriate), isolated home and mounts, controlled network/credentials; report any weaker host-run mode honestly. Project tests run as untrusted executable code.
5. **Supply chain:** untrusted research/repository text is data, never control; prevent prompt-injection from turning retrieved documents into privileged actions. Source provenance, content-addressed artifacts and independent gate results.
6. **Operations:** passive monitoring only. Active diagnostics, cleanup, restores, restarts, package/config edits require separately approved engineering/operations contract and applicable release authorization.
7. **Releases:** two explicit gates. Gate A authorizes bounded engineering; Gate B separately authorizes a specific already-verified release artifact and target(s). Signed/approved immutable candidate, fresh verification after rebase, controlled release executor and audit. Policy/security changes need independent human review.
8. **Audit and recovery:** append-only logically sequenced actions/events, protected backups, retention and redaction; no model-authored evaluator results. Reconcile crashed jobs rather than blindly restarting. Proven uncertain status blocks duplicate launch.

## Distributed execution model

Nodes advertise factual, verified capabilities (architecture, runtime, OS/Vikix version, free capacity, project access, runner capability) and heartbeat. Scheduling respects per-project authorization, resource limits, node health, machine access and approved scope. Do not infer permission from capability. `--on NAME` is a placement hint, not approval.

Dispatch envelope: office_id, task_id, attempt_id, graph_revision, contract_hash, node_id, lease/epoch, inputs, allowed actions, scope, runtime limits, policy_version, signed authorization. Results contain artifact hashes, exit status, audit metadata and test evidence. At-least-once delivery with idempotent task claim; exactly-once execution is not assumed. Worker unknown/offline is **uncertain**, not failed or available for reassignment. Never blindly duplicate side-effectful tasks.

Offline clients: read cached snapshots and write private drafts only; approvals wait for canonical acknowledgement, with version checks. Authorized local work may continue under unexpired capability without silently expanding scope. Disconnected machines do not receive new authority. Coordinator move uses manual failover + fencing to prevent dual active coordinators.

Code projects move by Git/artifact transfer, not concurrent Syncthing of live worktrees. Cloud later uses the same protocol and policy boundary; cloud coordination is optional, not required for local use.

## UX: intelligent Office

Main view emphasizes **Manager brief, strategic goals, decisions needed, evidence-backed ideas, active plans and outcomes**, with drill-down into workers. Avoid noisy stream of agent token/tool events. Each proposal answers: why relevant now, what is known/unknown, expected benefit, competing plans, risk, resource need, proposed next step. Let user say:
- "Find meaningful improvements to Vikix this week; investigate and propose."
- "Research this idea; prepare a design, but do not write code."
- "Execute this approved contract on the X1; test and present evidence."
- "Show operational issues across machines; do not fix them."
- "Prepare release review for candidate SHA; nothing ships until I approve."

Phone and remote UIs use the same canonical decisions API and must not fabricate successful authorization before coordinator acknowledgment.

## Phases and acceptance criteria

**0 — Desktop 1.0 dependencies (no new autonomous Manager):** retain trust/release/rollback, agent reliability and machine continuity as overriding priority. Inventory shipped vs proposed implementations. No Cloud dependency.

**1 — Unified Office information model:** persistent goals, ideas, proposals, source evidence and outcomes linked to existing task IDs and events. Test migration, duplicates, stale claims, events and decision provenance. Existing Office operation unchanged.

**2 — Authority & isolation:** deterministic policy verifier, immutable human approval contracts, research-vs-engineering boundaries, safe worker sandbox and protected release path. Test forged approvals, path escapes, secret leakage, changed hashes, budget exhaustion and policy self-edit attempts.

**3 — Two-machine pilot:** X1 coordinator and ROG client/worker over enrolled private connectivity; remote read-only research, authorized implementation in isolated desk, task evidence, idempotent recovery, offline cached views, test real hardware and reboots. Test disconnect during task and revoked machine.

**4 — Proactive Manager:** goal-driven scheduled/event-triggered discovery, deduplicated research, cited assessments, plan creation and decision cards. Model costs and research volume bounded; no automatic task execution without prior approved contract. Measure proposal quality.

**5 — Distributed approved execution:** capability-aware placement, cross-machine immutable evidence, retry/invalidation, active status, user review and explicitly approved release. Reuse orchestration plan gates. Test cross-machine worker failures, mixed commits, stale checks and release authorization.

**6 — Learning and operations intelligence:** versioned institutional memory, source-change invalidation, measured post-release outcomes, passive operational telemetry, monitoring reports. No autonomous remediation.

**7 — Always-on coordinator / optional Cloud:** move coordinator using tested migration/backup and fencing; add remote and mobile clients, offsite backup and opted-in compute. Keep local-first and ownership of data.

**First end-to-end demonstration:** from ROG, register/research an idea via X1; Manager proposes plan with evidence; human approves exact bounded engineering contract; worker runs on an enrolled node; independent tests produce candidate evidence; Office requests distinct human release approval; exact candidate released; audit reconstructs every step; reboot/disconnect test confirms no duplicate work. No implementation until separately authorized.

## Measures of success

Proposal acceptance rate; duplicate ideas suppressed; source-grounded claims; percentage of approved tasks passing without human repair; interruptions per completed task; time/cost per verified deliverable; regression and rollback rate; machine-offline reconciliation outcomes; approvals attempted versus correctly denied; post-release measurable impact. Never declare success solely from model confidence or green-looking UI.

## Open implementation decisions (not license to weaken defaults)

- Coordinator location and migration schedule (X1 proposed first).
- Minimum confinement mechanism for development tools on Void, and required network policy.
- Research source allowlist, budgets and scheduling frequency.
- How to authenticate user release approvals across terminal/Emacs/mobile while offline.
- Store retention, redaction, encrypted backup and policy-signing key management.
- Whether non-Vikix nodes are read-only telemetry-only at first.

These choices require engineering design and tests before coding. Do not reinterpret them as permissions.

## Cross-references

[`DESKTOP-1.0.md`](DESKTOP-1.0.md), [`DESIGN-office-tasks.md`](DESIGN-office-tasks.md), [`DESIGN-agent-orchestration.md`](DESIGN-agent-orchestration.md), [`DESIGN-machines.md`](DESIGN-machines.md), [`DESIGN-remote.md`](DESIGN-remote.md), [`DESIGN-cloud.md`](DESIGN-cloud.md), [`DESIGN-phone.md`](DESIGN-phone.md), [`DESIGN-security.md`](DESIGN-security.md).
