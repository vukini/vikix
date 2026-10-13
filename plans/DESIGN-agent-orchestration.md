# Agent orchestration — design

A graph decides which work exists and what must precede it. A worker loop produces one result, checks it against conditions written before the work, corrects a failure and repeats within a budget. Vikix owns the graph and the checks; providers do the work at desks. The Office shows the evidence and asks for a decision only at the boundary the user chose.

Drafted 2026-10-13 for TODO item 119, continuing Vid's *Assess Vikix Fit* brief. This is proposed work, except for the existing pieces identified below. Decisions marked *decided here* are implementation defaults for Vid to overturn. As in the other designs, remove what ships from the remaining work and date changes. No new agent runtime, provider-specific orchestrator or second Office is needed.

## 1. Where this fits

Reviewed against main at `f13b8e61a835f2fcff128f4f1e334dcb060b0315` (0.72.66), including the six references requested in the brief and the implementing runner, tester and release code. The designs describe different dates; a proposed feature in one is not proof it shipped.

| Existing source | What it already owns | What this design adds |
|---|---|---|
| [Office tasks](DESIGN-office-tasks.md), TODO 115 | Proposed task identity, provenance, task transitions apart from worker observations, queue, decisions, launch intents, attention and history; `lib/tasks.py` and `lib/scheduler.py` are its proposed modules | Execution contracts, attempts, gate evidence and graph revision references on those records; no duplicate board or scheduler |
| [Workers](DESIGN-workers.md) | Desks apart from workers, one worker per desk, handoffs, inbox, pause, turns, dismissal, script tester; plan runner shipped beyond that design | A loop whose exit requires explicit acceptance evidence, with bounded correction and failure classification |
| [Codex integration](DESIGN-codex-integration.md), archived item 116 | Shipped modes, hooks, sandbox boundaries, signed hand-in fields, provider handover and read-only cross-provider review | Provider-independent contracts and approval policy; model review remains useful evidence, never a deterministic test |
| [two-desks template](../config/plans/two-desks.toml), `lib/plan.py` | Tasks in TOML, `after`, `at-once`, same-desk chains, fresh desks after another desk's release, `gate = "me"`; earlier-name validation already makes dependencies acyclic | Explainable graph validation, contract versioning, scope and resource declarations, acceptance gates and affected-node recovery |
| [test runner](../tests/run.sh), `lib/agents/tester.py` | Named and changed test selection, global slots, exclusive tests, per-test live files, successful duration history, elapsed/remaining estimates, suspected stalls; release reuses fresh wide checks | Durable structured outcomes, gate coverage, retained completed rows, estimate confidence and per-case adapters where available |
| [TODO](../TODO.md), `.claude/release`, `tests/changed.sh` | Existing work order; release serializes, rebases, checks and merges; designs and TODO alone select no executable tests | One follow-on item; no version bump for writing this plan |

The current plan runner already retries failed hand-ins or exits, stops after three failed rounds, and reconstructs work from desk records and history. It already waits for fresh passing checks before advancing a tested same-desk chain; cross-desk dependencies wait for release onto main. This design tightens those semantics. It does not claim DAG execution, retries or live ETA are absent.

TODO 115 supplies persistent task records before the unified scheduler moves ownership. Until then, implement compatible evidence on handoff/plan records and adopt it once; never run both schedulers against the same plan. TODO 99 remains the separate work on advisory filesystem reservations.

## 2. The contract, before the worker

Each node has a stable task id, human-readable name, task words, graph revision, input refs, dependencies, desk, provider/mode, declared paths, acceptance criteria, required gates, resources, retry budget, risk and release boundary. A criterion is either executable or explicitly judged by the user. The agent's acceptance ticks are claims pointing to evidence, not the evidence itself.

| Criterion | Evaluator | Success |
|---|---|---|
| The record command keeps its old behavior | Named test through `tests/run.sh` | Required test is present, completed and exited 0 |
| Changes stay within the agreed scope | Script comparing normalized Git paths to declared patterns | Every added, changed, deleted and renamed path is covered, including both sides of renames |
| Every factual claim has a source location | A project-specific manifest validator | Every claim id resolves to a recorded source and location; factual correctness may still need review |
| The result reads clearly | User review | User accepts the pinned result; no automatic green |
| No errors were raised / the model is confident | None | Not an acceptance condition |

An empty selection, missing runner, skipped requirement, lost log or parser failure cannot pass a required gate. Documentation-only work can legitimately require scope/link checks and a user review with no executable tests; record that policy before launch. Existing `no-tests` and no-runner behavior remain readable for old plans, shown as *unchecked under legacy policy*, never silently promoted to validated.

**Proposed TOML extension** (illustration only; today's strict parser refuses these new keys). Existing `acceptance` strings stay valid. Add `contract-version = 1` at plan level, `paths`, `risk`, `max-attempts`, and typed nested gates; unversioned plans retain today's behavior.

```toml
project = "vikix"
at-once = 2
gate = "me"
contract-version = 1

[[task]]
name = "records"
desk = "topic-records"
task = "Add seen marks while preserving the record commands."
acceptance = ["A record can be marked seen and found by that mark."]
paths = ["bin/vikix-records", "tests/records.sh"]
risk = "local"
max-attempts = 3
release = "Records can be marked seen"

[[task.gates]]
id = "records-behavior"
kind = "tests"
names = ["records"]
required = true

[[task.gates]]
id = "records-scope"
kind = "scope"
required = true

[[task]]
name = "guide"
desk = "topic-guide"
task = "Clarify the existing record workflow in the agents guide."
acceptance = ["The guide links resolve and Info builds without warnings."]
paths = ["docs/agents.md"]
risk = "local"
max-attempts = 3
release = "The agents guide explains the record workflow"

[[task.gates]]
id = "guide-build"
kind = "tests"
names = ["info"]
required = true

[[task.gates]]
id = "guide-scope"
kind = "scope"
required = true

[[task]]
name = "together"
desk = "topic-together"
after = ["records", "guide"]
task = "Integrate the two released parts and check the whole behavior."
acceptance = ["The integrated behavior passes the agreed regression tests."]
paths = ["bin/vikix-records", "tests/records.sh", "docs/agents.md"]
risk = "local"
max-attempts = 3
release = "The integrated behavior is checked"

[[task.gates]]
id = "integration-behavior"
kind = "tests"
names = ["records", "info"]
required = true

[[task.gates]]
id = "integration-scope"
kind = "scope"
required = true
```

The task words and test names must fit the actual change; this example shows the schema and joins. A required dependency such as makeinfo missing from the host makes the info gate unavailable, not green. *Decided here:* first milestone retains one project per plan and existing cross-desk release semantics. Cross-repository plans or dependencies on unpublished artifacts need a separate design; do not smuggle them into `after`.

Gate ids map to approved evaluator kinds and argument arrays. Do not accept arbitrary shell strings as trusted policy. Checks run in isolated test worktrees with withheld credentials and a captured environment; repository tests are executable project code and receive no extra rights because they are called a gate. Policy and runner provenance are pinned, and changes to either require review.

## 3. The graph and scheduling

Compile explicit `after` edges plus implicit same-desk sequence edges before launch. Validate unique ids/names, existing dependencies, cycles with a readable path, required gates, budgets, declared outputs, release lines and the current cross-desk fresh-desk constraint. Retain the earlier-task ordering rule initially; supporting forward references later requires whole-graph cycle detection.

A node is runnable only when its dependencies meet the required boundary, its contract is authorized, its input revisions still match, its desk has no worker, and worker/resource capacity is available. The task-board scheduler owns priority and manual queue order; the plan runner supplies graph eligibility. The reason appears in the Office: *waiting for records to release*, *desk occupied*, *at-once 2 reached*, *gate stale*, *approval needed*.

```text
records ── validated ── approved release ──┐
                                         ├── fresh together desk ── integration gates ── release
independent ── validated ── approved release┘
```

Independent nodes run together within `at-once`; same-desk nodes remain sequential. Test slots stay owned by `tests/run.sh`, including exclusive `times`, `soak` and `rescue`. Worker capacity and test capacity are separate: a test waiting for a slot is not a stuck worker. File declarations identify likely overlap before launch, but remain advisory where hooks cannot enforce them. Overlap serializes or asks for a scope change; no agent resolves another desk's changes.

Graph edits are revisions, never mutations hidden under a running attempt. Show added/removed nodes, edges, scope, rights and estimated cost; user-created edits or approved proposals become the next revision. Old attempts keep their original revision. Reject cycles and invalidate affected evidence before scheduling. Already released work cannot be undone by deleting a node: corrective work is a new task.

The scheduler's launch intent from TODO 115 uses task id, attempt id and graph revision as its idempotency key, persisted before spawning. One lock protects claiming capacity and transition. Reconcile intent with provider/process/session and record before retrying after a crash; an ambiguous launch blocks with *uncertain*, rather than spawning a second worker. Events wake evaluation; periodic reconciliation remains as recovery, not a source of new task identity.

## 4. The worker loop and evidence

The loop is `produce → check → correct → check`, stopping at validated success, a decision boundary, cancellation or an exhausted budget. Attempt state is a subrecord; it does not introduce another task state vocabulary alongside TODO 115.

1. Freeze the contract, input commits, policy version and budget. Start the worker with acceptance conditions, scope and required gates in its first prompt.
2. The worker implements, commits named files and hands in through today's fields. A worker's `review` or `finished` requests evaluation; it never completes the task by itself.
3. The script tester records candidate commit/tree, base, clean/dirty state, runner/policy fingerprint, exact test selection, machine/environment facts and each gate outcome.
4. Green means all required evaluators completed successfully on the candidate inputs, manual criteria were accepted where required, and blocking findings were resolved with evidence. A second model agreeing adds no deterministic green.
5. On a repairable failure, send structured failures and links through the inbox. Resume or replace the worker through existing wake/handover paths; an idle worker must be given the failure as a prompt, since an inbox alone waits unread.
6. On validation, move to review/release through the task-board transitions. Same-desk continuation follows the validated boundary; cross-desk continuation still waits for release.

A proposed gate record contains `task_id`, `attempt_id`, `graph_revision`, `gate_id`, `candidate_commit`, `tree`, `base`, `input_refs`, `contract_hash`, `runner_hash`, `environment_hash`, timestamps, outcome, exit code, selected/completed/skipped tests, artifact hashes and log references. Outcomes are `passed`, `failed`, `skipped`, `cancelled`, `timed_out`, `unavailable` or `unknown`; only `passed` satisfies an automatic required gate.

The tester writes results with Vikix's provenance. Workers cannot set the evaluator's fields through `handoff_update`. Keep checks on old handoffs readable and signed as today; strict contracts require the new evidence. Input, candidate, scope, evaluator or policy changes invalidate a gate. Dirty-tree runs are useful feedback but cannot vouch for a different later commit.

A batch tester's combined tree has its own identity. A combined pass is integration evidence; individual task credit requires explicit attribution and matching scope/input coverage, never copying one green result to every participating desk. Rebase or changed main invalidates integration/release evidence as the release's freshness check already requires.

## 5. Granular test progress and honest ETA

Build on the shipped live protocol: `tests/run.sh` writes plan/run files, per-test `.started` and atomic `.done`, outputs and expected durations; slot notes distinguish waiting/running/exclusive access. `test_progress` reads direct worker runs too, ignores stale runner pids, reports elapsed/remaining time and suspected stalls. Its ETA uses the last successful duration on this machine, excludes queue time and becomes unknown when duration is missing or exceeded. These are existing capabilities, not Phase 0 work to rebuild.

Extend that protocol with a versioned durable run manifest and sequenced JSONL events, copied into the Office's test artifacts before temporary logs disappear. Each event has run/task/attempt/test ids, sequence, timestamp, kind and outcome; atomic final manifest is authoritative. Older runners remain supported with lower-detail observations.

Show all selected tests, including completed ones: queued (reason), waiting for a slot, waiting for exclusive access, running, passed, failed, skipped and interrupted. Counts distinguish `completed / selected` from `passed / required`; failure is never hidden behind “done.” Per-case progress is optional through TAP/JUnit or an explicit adapter; do not infer case completion from arbitrary output or invent a denominator for scripts with none.

Separate:
- elapsed wall time, active test time and queue wait;
- approximate execution remaining and unknown capacity wait;
- user/approval wait, which has no automatic ETA;
- node estimate and plan estimate, which includes dependencies and release boundaries.

Store a bounded history by test, runner/version and machine/resource profile, with sample count, median and spread. Start with the existing duration as a one-sample hint; insufficient or incomparable samples say *low confidence* or *unknown*. Estimate parallel remaining work using available slots and exclusive phases; graph ETA uses critical-path estimates constrained by worker capacity. It is a forecast, never an acceptance gate. An exceeded estimate says *past estimate*; suspected stall remains a suspicion and never automatically kills a process. A separate explicit deadline may stop only the owned run and records `timed_out`.

Office example: `records · checking · 8/12 completed (7 passed, 1 failed), 2 running, 2 queued · about 40–90s execution left; slot wait unknown · attempt 2/3`. Expand to test/case rows and logs in both terminal and Emacs. Notify once for a meaningful failure or required decision, not every progress event.

## 6. Targeted retries and invalidation

*Decided here:* keep the current three attempts as the default total, including the first, with separate finite test-retry and wall-time/cost caps. Restarting the runner never resets a budget. Repeated identical failure fingerprints with no changed candidate or new evidence stop early and ask for a decision.

| Failure | Recovery | Evidence retained |
|---|---|---|
| Deterministic test or scope failure | Repair the owning node; run the named failing tests for fast feedback, then every required gate for the new candidate | Old results as history only |
| Test infrastructure unavailable or interrupted | Retry the affected test under a bounded infrastructure budget after the cause changes; do not ask the worker to rewrite correct code | Matching completed evidence may be reused only under the gate's coverage/fingerprint rules |
| Suspected flake | Record all outcomes; reproduce in isolation through shared slots; quarantine only with explicit policy/user approval | A later pass does not erase the failure or prove correctness |
| Review finding | Route a finding id and pinned location to its worker; verify the fix or explicit user dismissal | Finding history and resolution evidence |
| Worker exit without hand-in | Preserve task and changes; inspect/reconcile session, then resume/replace that worker | No fabricated success |
| Dependency output changed | Mark consuming nodes' evidence stale transitively and rerun only affected descendants | Independent validated nodes stay valid |
| Release conflict, policy denial, scope expansion | Needs decision; no retry that increases rights or merges around the release path | Original branch/evidence remains |

Test selection alone is not a permission to reuse success after a source change. Initial strict implementation reruns all required gates on a new candidate. Later per-test reuse needs a declared dependency closure including fixtures, configuration, runner and environment; unknown coverage widens to the required set. Installation/package/dev changes retain repository full-test requirements.

A failed integration node does not restart both independent predecessors. Diagnose and repair integration first; if a predecessor is at fault, create its corrective attempt/task and invalidate consumers of the changed output. Released predecessors need corrective commits through the release path, never history rewriting.

Before any irreversible action persist intent, then reconcile external state using its operation id/ref. A crash after merge or push must not repeat the action. Tests can be re-executed safely under a budget; external operations require operation-specific reconciliation.

## 7. Risk-based approvals

Provider modes still determine how tools execute. They do not grant a graph authority to launch, release or publish. Apply the stricter of user authorization, project policy, task contract, provider protection and operation risk.

| Boundary | Default |
|---|---|
| Read/reference inspection and approved local desk edits/checks | Proceed within declared scope and budgets |
| New task proposed by an agent or graph/scope/budget expansion | Proposal in TODO 115's decision mechanism; launch only within user-authorized delegation limits |
| Network use or sensitive inputs | Proceed only for the configured destinations and rights; changed destination or data scope asks |
| Validated release of local reversible work | `gate = "me"` asks once with the concrete evidence; `gate = "none"` retains explicitly configured release authorization |
| Push, publication, mail, deployment, secrets, destructive/system changes | Require operation-specific existing authorization; otherwise register a decision for the user |
| Unrestricted mode or rights expansion | Explicit user choice; cannot be inferred from a test pass or a learning recommendation |

Do not ask again for an action already authorized and still within its bounds. At a boundary present candidate commit, base/inputs, graph revision, scope/diff summary, gates and failures/skips, review findings, risk, expected effect and recovery. An approval binds the action and these fingerprints; changed content, base, scope, rights or policy invalidates it. Ordinary progress and test retries within the approved budget do not.

Use Office tasks' decisions, user answers and inbox delivery. Agents may request decisions but cannot answer another's or silently promote `gate = "me"` to `none`. Explicit overrides record user, reason, unmet gates and exact candidate; show *accepted with override*, never deterministic green. Until enforcement exists for an operation/provider, display the boundary as advisory.

The release remains `.claude/release`, with serialization, rebase and current checks. Hosted/cloud-style sessions push topic branches without version/tag changes and leave local release to the dev machine. This design does not replace that convention.

## 8. Validated learning feedback

Learning is a proposal backed by outcomes. Keep operational duration statistics separate from policy/instruction learning. A worker saying “this worked” is a candidate observation, not a durable lesson.

A learning record references task/attempt/graph ids, input and candidate refs, failure fingerprint, correction, gate/test/review evidence, machine context, proposed applicability, exclusions, author and status. Status is `proposed → replay-validated → accepted → retired` (or rejected), stored through the same event/history system, with bounded local artifacts. These are learning statuses, not task states.

Validation has three steps:
1. Reproduce the original failure where possible and show the correction passes required gates on the pinned result. If reproduction is impossible, retain an unvalidated hypothesis.
2. Replay against representative held-out fixtures/tasks and negative cases. Reject a shortcut that passes its own example but weakens unrelated behavior, scope, privacy or rights. Keep training and evaluation examples distinct.
3. User accepts changes to guides, rules, templates, test-selection/retry policy or approval policy as reviewable versioned patches. Runtime observations may update forecasts automatically, but cannot expand permissions, skip a gate, raise a budget or add an allowed destination.

Record before/after success rate, recurrence, unnecessary retries, validation coverage, test time and user interventions with denominators and sample sizes. Measure comparable contexts; do not optimize a confidence score or task count at the expense of correctness. An accepted lesson can be rolled back/retired when regressions or contradictory evidence arrive.

Logs and external material are untrusted data. Redact credentials through existing cleaning, allow-list stored fields, cap retention and access, and never extract source instructions into policy. No cross-project transfer of private examples by default. Evidence references remain auditable when raw artifacts expire; expiry removes eligibility for replay claims that need those artifacts.

## 9. Implementation and migration

| Owner | Change |
|---|---|
| `lib/plan.py` | Versioned contract parser, compiled edges, plan revision/hash, eligibility reasons and attempt reconstruction |
| TODO 115's `lib/tasks.py` / `lib/scheduler.py` | Stable ids, durable attempt/gate references, invalidation, decisions and one launch owner |
| `lib/handoff.py` / `lib/agents/handoffs.py` | Backward-compatible evidence links, stricter validation of tester-owned fields, worker feedback |
| `lib/agents/tester.py`, `tests/run.sh` | Structured manifests/events, required-gate evaluation, durable artifacts and bounded retry selection |
| `tests/changed.sh` | Map new runtime modules and changes to contract/progress/recovery tests |
| `lib/office.py`, `config/emacs/vikix-office.el` | Graph reasons, attempt/gate detail, retained progress, ETA confidence, approval evidence and learning proposals |
| `config/plans/*.toml` | Opt-in strict templates once parser support ships; keep today's two-desks example working |
| `docs/agents.md`, installed skill pages and generated command guides | Explain strict vs legacy plans, evidence, recovery and real provider protections once commands exist |

Do not create `lib/tasks.py` independently of TODO 115. Adopt desk history with unknown fields preserved and an adoption event; never invent past validations or launches. Keep old CLI, handoff states, plan templates and snapshots readable. New schemas are versioned; unsupported versions fail before launch. Artifact manifests are atomic, writes lock read/modify/write operations, event ids deduplicate replay, and recovery scans snapshots plus events.

## 10. Delivery order and acceptance

Each phase is separately releasable and leaves legacy plans working. This document and TODO entry are documentation only.

1. **Contracts and evidence.** Add strict parsing and evaluator schema, scope and required test gates, immutable candidate fingerprints and legacy labeling. First useful milestone: a strict node cannot advance on no runner, empty selection, missing required test, dirty/stale check or agent tick.
2. **Attempts and graph recovery.** Integrate with TODO 115 identity/launch intents, explicit implicit edges, explanation of eligibility, bounded correction and descendant invalidation. Demonstrate independent work survives a failed integration and restart never launches twice or resets attempts.
3. **Progress and ETA extensions.** Preserve the shipped protocol, add durable completed outcomes, confidence/history and optional per-case adapters. Demonstrate queued time is separate, all failed/skipped tests stay visible, and missing samples yield unknown ETA.
4. **Approval boundaries.** Bind user decisions to action/evidence and policy; reconcile release/external intents. Demonstrate content or rights changes invalidate approval, existing authorization is honored, and agents cannot grant their own expansion.
5. **Validated learning.** Proposals, replay/negative cases, acceptance and retirement. Demonstrate a successful local fix cannot weaken another gate or change rights, and a rejected/retired lesson stops influencing suggestions.

**Required implementation tests** use made-up homes, repositories/worktrees, fake providers and a controllable clock; live-provider smoke checks supplement them:
- `tests/plan.sh`: malformed contract/version/gates, explicit-plus-implicit cycles, same-desk order, cross-desk release and fresh main, capacity, revised plans, stale inputs and affected descendants.
- `tests/tester.sh` / `tests/handoff.sh`: absent/empty/skipped gates, nonzero/timeout/malformed evidence, changed runner/env/commit, dirty tree, batch attribution, forged worker result refused, targeted feedback plus complete revalidation.
- `tests/run.sh` protocol tests: atomic/sequenced completion, concurrent runs and global slots, exclusive phases, interruptions, pid reuse, retained outcomes, missing durations, deterministic ETA bounds and optional case adapters.
- TODO 115's `tests/tasks.sh`: concurrent claims, crash before/after spawn, lost events, attempt persistence and idempotent reconciliation.
- `tests/office-ui.py` / `.el`: terminal and Emacs parity, failed versus completed counts, blocking reasons, unknown ETA, approval invalidation and explicit override labels.
- `tests/codex.sh` / `tests/house.sh` / `tests/mcp.sh`: provider parity, decision delivery/wake, denied scope/rights, no self-approval and no tester-field mutation.
- `tests/release.sh`: fresh-wide-check reuse, rebased candidates invalidated, release intent reconciled, no duplicate merge/version; hosted documentation branches remain without release.
- New learning tests mapped by `tests/changed.sh`: reproduction plus negative/held-out replay, unsupported claims rejected, secret redaction, evidence expiry, rollback and no automatic authority change.

Run through `tests/run.sh` with repository test selection and full checks where required. Roll out strict mode on a small two-independent-nodes-and-one-join fixture, then one real Vikix plan with `gate = "me"`; compare failures, wait time and user decisions against the current runner before broadening defaults.

## 11. Decisions left for Vid

Defaults here keep release-gated cross-desk inputs, three total worker attempts, manual final release unless already configured otherwise, strict contracts opt-in, and learning policy changes reviewed. Questions to settle after the first real run: which projects should opt into strict mode by default; which acceptance criteria merit project-specific evaluators; how long artifacts and comparable duration histories should live; and whether unpublished cross-desk artifacts ever justify relaxing the existing release boundary. No implementation should assume those relaxations.
