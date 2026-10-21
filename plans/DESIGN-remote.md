# DESIGN: Vikix Remote — one desktop across machines

Status: proposed / not implemented. Added 2026-10-21.
Owner scenario: ASUS ROG Z13 ("zog") controls Lenovo X1 ("x1"), both running Vikix on Void Linux / runit / X11 / StumpWM, first on a LAN and ultimately across different networks. Future targets include Vikix Cloud nodes.

## Goal

One coherent Vikix interface for four separate modes:
1. **Terminal and jobs**: SSH to x1; Emacs/agent/shell sessions continue on x1.
2. **Desktop control**: view and operate x1's *existing* StumpWM/X11 session from zog.
3. **Extended screen**: use x1's physical display as a true extra display for windows rendered by zog (not merely mirror); experimental, different data direction from remote control.
4. **Headless / remote internet**: leave x1 running with its lid shut and securely reach it from another Wi-Fi, hotspot, or country.

This is a plan, not a claim that these capabilities are already supported.

## Fit with existing Vikix

- **Reuse** `vikix node add`, `vikix nodes`, `vikix node status` and the SSH-key trust model in `docs/nodes.md`; do **not** invent an independent device registry. A laptop is a node with roles/capabilities, not necessarily a cloud VM.
- Integrate connection actions with the existing **Network Office** (`docs/network.md`) while preserving its manual discovery/privacy rules. Cross-network nodes are *registered*, not scanned.
- Reconcile with `plans/DESIGN-cloud.md`, `plans/DESIGN-machines.md`, and `plans/DESIGN-remoteapp.md`; RemoteApp (Windows application forwarding) is distinct from sharing an X11 desktop.
- Proposed user-facing entry points (final CLI names subject to consistency audit): `vikix nodes`, `vikix node connect x1`, `vikix node desktop x1`, `vikix node display x1`. Optionally convenient aliases `vikix connect x1`, `vikix desktop x1`. Avoid colliding with existing commands.

## Transport and security

- P0 LAN path: OpenSSH on x1 under runit; key-based auth, verified host fingerprint, least-privilege account, SSH config alias; do not alter firewall automatically.
- P1 cross-network path: user-consented Tailscale/WireGuard overlay. Validate package availability on current Void before promising `xbps-install`; provide a reproducible, pinned and reviewed alternative where absent. SSH to node's stable overlay address or MagicDNS name; test from zog's phone hotspot while x1 remains on home Wi-Fi. No public SSH/VNC ports or router port-forwarding by default.
- VPN enrollment is explicit; show exactly which devices are trusted. Prefer policy/ACL restrictions where feasible, and support revocation, key rotation, node removal and lost-device response. Future option: self-hosted Headscale/controller; do not couple CLI to one vendor.
- Desktop streaming binds to loopback and crosses SSH/overlay securely. Never expose an unauthenticated VNC listener. Differentiate SSH host identity from overlay device identity.
- Report when direct peer-to-peer fails and relay is used, without inventing speed guarantees.

## Work packages and acceptance checks

### R0 — audit and design (first)
- [ ] Inspect current node CLI, runit service patterns, network UI, dependencies, docs and laptop hardware/X11 session setup.
- [ ] Decide a node capability schema: ssh, desktop, headless, display-sink; preserve backward compatibility for existing node files.
- [ ] Specify machine naming, connection UX, supported local/remote networks, failure states and safe defaults.
- [ ] Document security threat model for compromised/lost laptop, malicious LAN, compromised VPN, stolen key, abandoned desktop session.

**Green:** design documents compatibility, supported platforms, fallback commands and explicit permission boundaries; no behavior changed.

### R1 — SSH everywhere (MVP)
- [ ] X1: install/enable openssh runit service after verifying packages and existing status; SSH key enrollment and fingerprint validation.
- [ ] Zog: register x1 with existing `vikix node add` and confirm `vikix node status x1` and interactive shell.
- [ ] Add optional overlay setup with dependency detection, explicit authentication, stable hostname/IP registration, and diagnostics.
- [ ] Test LAN; test *different networks* (zog on hotspot, x1 at home); test reconnect, VPN down, offline, DNS stale, revoked access.

**Green:** `vikix node connect x1` (or existing equivalent) works from LAN AND hotspot with public inbound ports closed; failed connections explain why; secrets never appear in logs.

### R2 — control existing X1 desktop
- [ ] Detect X11 display, Xauthority and active seat/session; distinguish logged-in X1 desktop from headless virtual session.
- [ ] Evaluate x11vnc + SSH tunnel as simple baseline; test clipboard, keyboard layout, multi-monitor, scaling, audio limitations and StumpWM shortcuts.
- [ ] Evaluate Sunshine/Moonlight as optional low-latency alternative *only after* checking Void packaging and hardware encoding compatibility.
- [ ] Add a single UI/CLI action to start/stop a secured session; ensure listeners stay on localhost, no implicit firewall opening.

**Green:** while x1 has an active StumpWM session, zog can control exactly that desktop; session can be closed cleanly; reconnect works; access denied without authorization.

### R3 — laptop lid closed / headless
- [ ] Examine logind/acpid/elogind policy actually used by Vikix; configure a documented opt-in lid-close behavior, with AC/battery, thermal and security safeguards.
- [ ] Persist network/SSH/overlay under runit independently of GUI login; ensure power management does not suspend unexpectedly.
- [ ] For GUI without a physical display, test a virtual X11 display (or hardware dummy plug) and distinguish it from reconnecting to the existing desktop.
- [ ] Test reboot, logout, lid close/open, power loss, battery drain, screen lock, and remote session reconnection; document that power-off and suspend cannot be reached without a supported wake mechanism.

**Green:** x1 can remain safely reachable with lid shut on supported power/network conditions; SSH remains usable after GUI exits; no misleading promise of remote power-on.

### R4 — true extended display (research spike)
- [ ] Prototype a virtual output on zog and transmit *that output only* to an x1 viewer in a full-screen StumpWM window; compare VNC/Deskreen/WayVNC-compatible options against actual X11 constraints.
- [ ] Test feasibility of adding/removing a virtual X11 output without dummy hardware, RandR behavior, cursor movement, input ownership, resolution and refresh rate.
- [ ] Define local-LAN-first latency, bandwidth, compression, scaling, and session-drop UX; prefer direct peer-to-peer.
- [ ] Explicitly compare mirroring, remote desktop, keyboard/mouse sharing (e.g. Input Leap) and **true extension**. Do not mark delivered if only mirror works.
- [ ] Decide whether to ship software-only, require dummy adapter, or defer after real hardware testing; cross-network display-sink is optional and latency-sensitive.

**Green:** zog's display settings expose a distinct extended desktop region physically shown on x1, with windows draggable there and input behaving correctly; otherwise document unmet prerequisites and do not ship it as extension.

### R5 — Vikix UX and integration
- [ ] Add registered remote devices to Network Office and node list with online/offline, network path and available capabilities; never auto-scan distant networks.
- [ ] One action each: shell, existing desktop, headless session, extended display, open files. Explain unavailable actions.
- [ ] Add connection health, explicit disconnect/revoke, session lifecycle, and optional trusted auto-reconnect; no invisible remote control.
- [ ] Explore remote file browsing through existing Emacs/SSH mechanisms (TRAMP, sshfs or SFTP), without automatically syncing/replacing authoritative files.
- [ ] Extend to Vikix Cloud nodes without assuming every node is a graphical laptop.

**Green:** both laptops present comprehensible device status; every action can be reproduced from CLI; no duplicate node inventory.

## Engineering rules

- Build in small independently testable phases with checks written before implementation; do not mark checkboxes done without hardware evidence.
- Keep runit/Void and StumpWM/X11 as first-class targets, avoiding assumptions about systemd or Wayland.
- Never push credentials, device keys, private IP inventory, or enrollment tokens into the repository.
- Update docs and tests in the same changes as CLI/service code. Show error paths, rollback/recovery, and what remains experimental.
- Do not implement cloud-dependent login as a hard prerequisite for LAN SSH.
