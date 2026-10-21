# Vikix Desktop 1.0 — critical path

Status: **top development priority**, agreed 2026-10-21. Scope: **desktop, local AI agents, and personally owned devices**. **Vikix Cloud/product hosting is excluded.** This is a *readiness milestone*, not a claim that 1.0 has shipped or a request to change version numbers now.

## Product objective

Stop measuring progress by the number of features. Make Vikix (1) a desktop trustworthy for everyday work, (2) an AI development environment that can execute checked work with bounded supervision, and (3) a coherent experience across the X1 and ROG Z13 (Zog).

**Priority rule:** work required for a Desktop 1.0 acceptance gate takes precedence over new applications, runtimes, courses, experiments, publishing or music features. Critical security/regression fixes may interrupt any phase. Do not silently discard existing TODOs; move unrelated work to the optional backlog below. Do not deploy unverified main commits merely to make progress on the milestone.

## Critical path (ordered; each gate has evidence)

### A. Trust the desktop — P0

Dependencies: none. This gate comes before increasing unattended agent autonomy.

- [ ] **Verified release channel:** daily-driver updates track a known-good, CI-verified revision, not an unverified fast-moving main. Preserve a deliberate development override. Run a local smoke check before declaring the update successful. See `plans/DESIGN-dependable.md` (1), `plans/DESIGN-ci.md`.
- [ ] **Rollback exercised on hardware:** demonstrate `vikix update --back` / `vikix rollback` after a deliberately broken test update, restoring Vikix config/binary/package state. Test snapshot behavior on btrfs separately; do not assert it works until actually run. TODO 6.
  *Evidence 2026-10-21, Z13 (ext4):* first real `vikix update --back` on hardware. After `gup` took the machine from 0.72.130 (244c133) to 0.72.132, the StumpWM binary was moved away by hand; `vikix update --back` restored record `20261021-215442` in 5.5 s with no sudo (0 packages): `~/vikix` detached at 244c133, `VERSION` 0.72.130, 40-config re-run (snapshot e91fba3), the binary back with the record's sha256, `vikix doctor` all good; the running desktop was untouched. Found on the way: the status listing erred on a record without a `changes` file (fixed, 0.72.132); the doctor says nothing about a detached `~/vikix` or a kept record (TODO 6). Still to run: on the X1; a record with package changes (`keep packages`, `-f` reinstall); btrfs (no btrfs machine).
- [ ] **Reproducible toolchain and recovery:** pin StumpWM/SBCL/Quicklisp inputs and retain a known-working desktop executable; recovery path documented and tested. `DESIGN-dependable.md` (3).
- [ ] **Release tests that fail safely:** fast pre-release gate, full soak/load tests, visible failure details, retries for identified flakes only, CI results captured by job; no missing runner, empty test selection or skipped required check counts as green. `DESIGN-ci.md`, TODO 119.
- [ ] **Secrets and containment:** least-privilege keys per tool, scoped agent filesystem access (real enforcement, not hooks alone), permissions/approval boundaries; lock-screen security verified on actual hardware and after long idle. `DESIGN-security.md`, `DESIGN-dependable.md` (8–9), TODO 97/99.
- [ ] **Hardware health / repairs:** post-update diagnostics and safe `vikix doctor --fix` for deterministic faults; never overwrite user-owned settings. TODO 103.

**Pass evidence:** commit/tag and CI run; logged rollback rehearsal and recovery steps; security/containment tests; post-update doctor report; successful regular desktop use.

### B. Autonomous, accountable Office — P1

**Dependency:** A's release gates and isolation/security foundations.

- [ ] Finish Office TODO 115 phases 5–6: proposals and provider handoffs, crash recovery, complete task history and comprehensive tests.
- [ ] Implement TODO 119's versioned task contracts and executable acceptance gates with immutable evidence; reject weak/skipped checks.
- [ ] Record durable attempts, dependency edges, bounded retries and invalidation of affected downstream work.
- [ ] Verify risk-based approval is tied to a specific candidate/operation. Unattended releases must use the same checked path as manual releases.
- [ ] Make release queue/self-recovery and Office attention/health visible; failures cannot stall overnight without surfacing a cause. `DESIGN-accelerators.md` (1–4), TODO 100, `DESIGN-ci.md`.
- [ ] Dogfood with real Claude + Codex desks: one failing task, a successful retry, interrupted worker recovery, cross-provider handoff and release with traceable evidence.

**Pass evidence:** repeatable end-to-end scenario from goal -> dependency plan -> implementation -> verified result -> permitted release; deterministic failure/recovery demo; one-screen audit of task/worker/test/release state.

### C. One desktop across personal machines — P1

**Dependency:** A's secure access and recovery baseline. This is local/personal-device work, **not Vikix Cloud**.

- [ ] Implement `plans/DESIGN-remote.md` R0–R5 incrementally: secure SSH and encrypted private-network access; control X1's existing StumpWM session from Zog on LAN and from another network; lid-closed/headless behavior. Extended display is explicitly **experimental** and must not be represented as the same as desktop mirroring.
- [ ] Add configuration portability: TODO 19 export/import and/or TODO 102 declarative `desktop.toml` + `vikix apply`, with dry-run, safe ownership semantics and secret exclusion.
- [ ] Add opt-in file sync and phone integration where it meaningfully improves continuity (TODO 16–18); avoid inventing a custom sync protocol.
- [ ] Validate reconnection after sleep, network changes and power loss; never expose public VNC or SSH by default.

**Pass evidence:** X1 controlled from Zog on same LAN and remote network, authenticated/authorized; configuration reproduced on a fresh machine; data sync conflict/recovery scenario documented.

### D. Hardware, installer and longevity — P1

Can proceed alongside B/C after A's baseline is in place.

- [ ] Clean-install and upgrade tests on both X1 and Zog via the documented path; publish and verify a versioned install image (TODO 20).
- [ ] Finish Z13 real-world checks: rotation, sound ceiling, Bluetooth, camera, SD, USB4, suspend/resume and power profile (TODO 59/63). Record explicit pass/fail instead of assuming support.
- [ ] Recovery rehearsal for user documents and machine configuration (TODO 80, backup/setup and restore interface).
- [ ] Test daily use for **30 consecutive days** with no critical unrecoverable failure; record updates, battery/suspend faults and regressions in a log, and restart the observation window after a critical failure.
- [ ] Bound runaway logs, journals and stores (TODO 96); monitor responsiveness and battery impacts against measured baselines.

**Pass evidence:** hardware compatibility matrix, reproducible install/restore logs, sustained-use log and closed release blockers.

## Desktop 1.0 release decision

Ship only when A–D acceptance evidence exists. A skipped/untested item is **not** a pass. Document any limited hardware exception explicitly; security, rollback, isolation and core install correctness are non-waivable. “Ready for my daily use” is separate from “ready for public users”; distribution/public-support obligations are not part of this milestone.

## Later — do not block Desktop 1.0

- **Org-based notes and knowledge environment:** separate product/project roadmap; integrate with Vikix and Emacs/mobile when ready, but not a desktop release gate.
- New language runtimes, optional AI providers, Cuis, music creation, books/publishing, tutorial expansion, stylistic enhancements and other exploratory ideas.
- **Cloud hosting/commercial VPS offering:** remains in `plans/DESIGN-cloud.md` and its own TODO; **excluded** from this plan.
- The existing numbered items in `TODO.md` and full designs remain authoritative for implementation detail. This document overrides their *priority*, not their recorded history.

## Delivery practice

For each acceptance item: nominate an owner/desk, add an executable or reproducible check first, link test evidence and docs in the release, then mark checked. Update this plan as milestones ship; do not mark implemented items complete from design prose alone.
