# Everyday user: the Windows VM's new network (0.41.0)

Checked 2026-09-28. The dev checkout is **0.41.0**; the installed desktop (`~/vikix`) is still **0.40.1**, so the migration hasn't run here yet. On this machine the VM was already moved by hand: it's on `virbr0`, the default network is active and autostarted, `/etc/qemu/bridge.conf` has `allow virbr0`, and the VM was shut off.

What I did (read-only): read README "Windows, in a VM", `bin/vikix-windows help`, `migrations/1790569435.sh`, the skill's Windows line and the site card. I ran `bin/vikix-windows status` (0.37 s), `DRY_RUN=1 bin/vikix-windows network` (0.10 s) and two misspelt subcommands, and read the VM's libvirt log and inactive XML. I read the code only to explain what I saw and to follow the failure path, which I couldn't safely trigger. Nothing was started, stopped, changed or run with sudo.

Nothing below is in `TODO.md`.

---

## 1. If the system libvirt won't start, the whole `vikix update` stops early, and it keeps stopping on every later update

**What happens (from the code; I couldn't trigger it safely):** the migration runs `vikix windows network`. That links the libvirtd service, then waits up to 20 seconds without printing anything. If libvirt never answers, `net_info` comes back empty, so it goes on to `sudo virsh net-define`. That fails with virsh's raw error (something like `error: failed to connect to the hypervisor … libvirt-sock: No such file or directory`), and `set -e` ends the script. `cmd_migrate` then `die`s with `migration 1790569435 failed; nothing after it was run`. Because `die` exits, the rest of `cmd_update` never runs:
- StumpWM isn't reloaded, so the new keys, bar and menu aren't in use.
- The "these stages failed" summary isn't printed.
- The "up to date; log: …" line isn't printed.
- Every later migration is blocked until libvirt is fixed.

So one optional feature that someone may use once a month can stall every update.

`vikix windows setup` has the same problem: `cmd_network` runs before the drivers disc is downloaded, so setup dies part-way with the same raw virsh error.

**Expected:** a plain sentence saying what went wrong and where to look, and the rest of the update carrying on.

**How to see it:** in the test VM, pick the Windows VM, break libvirtd (for example `sv down libvirtd` and move its run script aside), then run `vikix update`.

**Cost:** rare, but expensive when it happens. The user sees a libvirt socket error after a system update, with no hint that it's about Windows, and nothing gets better on the next update.

**Suggestion:**
- After the 20-second wait, check that libvirt answered. If it didn't, print something like: `the system libvirt service didn't start, so Windows stays on its old network for now. See: sudo sv status libvirtd. Then: vikix windows network`.
- In the migration, turn that failure into a `warn` and exit 0, so it doesn't block the update. `status` (item 2) and `doctor` (item 6) keep showing that the VM hasn't moved.
- Alternatively, have `cmd_migrate` record a failure the way failed stages are recorded, instead of `die`.
- Also print one line before the wait (`starting the system libvirt…`) so the 20-second silence doesn't look like a hang.

## 2. `status` says "isolated" while a running Windows is still on the old network

**What happens:** `status` decides the network from the VM's *saved* configuration (`dumpxml --inactive`), not from the Windows that is actually running. When `vikix update` runs while Windows is up, the migration rewrites the saved config. From then on `status` prints:

```
network:       isolated (virbr0): this machine's 127.0.0.1 is out of Windows's reach
```

But the running Windows is still on passt and can still reach Swank and CUPS. That lasts until Windows is shut down and started again. README says Log out leaves Windows running, so for someone who suspends instead of shutting down, that can be days.

The only warning is one line in the middle of a long update log: `Windows uses it from its next start (vikix windows stop, then vikix windows)`. The README doesn't mention a restart at all.

**Expected:** `status` tells the truth about the running Windows, and the README says a restart is needed.

**How to see it:** in the test VM, start a passt VM, run `vikix migrate`, then `vikix windows status`.

**Cost:** it bites exactly the people the change is meant to protect, and it tells them they're safe.

**Suggestion:**
- When the VM is running, compare the live XML with the saved XML. If they differ, print `network: moves to the private network at its next start; until then Windows can still reach this machine's own services. Restart it: vikix windows stop, then vikix windows`.
- Add "(from Windows's next start)" to the README bullet.
- Optionally, send a notification from the migration when Windows is running.

## 3. Jargon: "isolated", "NAT bridge", "virbr0", "127.0.0.1", "passt", "Swank", "CUPS"

**What happens:** the README bullet starts well ("Its network is kept apart from this machine"), then jumps straight into "libvirt's NAT bridge, `virbr0`", "192.168.122.1", "127.0.0.1", "Swank, CUPS", "qemu-bridge-helper", "/etc/qemu/bridge.conf" and "passt". `help` is denser still. The one line a user is most likely to read, in `status`, is `isolated (virbr0): this machine's 127.0.0.1 is out of Windows's reach`.

A non-technical reader learns neither why this matters nor what they have to do. The real reason is "a program in Windows could have run commands as you on Linux", and that's only in the migration's `# Why:` comment, which nobody sees. The README says only "Swank", which means nothing to them.

The word "isolated" also clashes with libvirt. In virt-manager, an "isolated" virtual network is a mode with **no internet**, and `virbr0`'s network shows there as "NAT". So a virt-manager user reads "isolated" as "Windows is offline", which is the opposite of what's true.

**Expected:**
- One plain sentence on why it matters.
- One on what the user has to do: nothing, apart from one restart of Windows.
- The technical details after that.

**Suggestion:**
- In `status`, `help` and the say lines, replace "isolated" with "private" or "kept apart".
- Status: `network: kept apart (virbr0): Windows reaches the internet, not this computer's own services`.
- README bullet, first sentences: "Programs in Windows can reach the internet but not the services only this computer should use: before 0.41.0 a program in Windows could have run commands as you on Linux. You don't need to do anything: `vikix update` moves the VM, and it takes effect the next time Windows starts." The details go after that.

## 4. The first thing `vikix windows network` shows on a machine that's already set up is a bare sudo prompt

**What happens:** `network_ready` calls `sudo virsh net-info` *before* anything is printed. On a machine that's already set up, running `vikix windows network` by hand (the fix `status` suggests) first shows `[sudo] password for …:` with no explanation. Only afterwards does it say `the isolated network (virbr0) is ready`. So it asks for a password even when there's nothing to do. (In a first-time setup the service check fails first, so the explanation does come before the prompt.)

**Expected:** an explanation first, and ideally no password when nothing needs changing.

**Cost:** small, but an unexplained password prompt is exactly what people learn to distrust.

**Suggestion:**
- Print `checking the private network for the Windows VM (needs sudo)` before the first `sudo`.
- Or check without sudo first. The dry-run path already does this, and it works for users in the libvirt group, as on this machine. Use sudo only when a change is needed.

## 5. The dry run always says "setting up" and never says what's already done

**What happens:** here, where everything was already in place, `DRY_RUN=1 bin/vikix-windows network` printed:

```
:: setting up the isolated network (virbr0): libvirt's NAT, for the VM
:: service virtlogd already enabled
:: service libvirtd already enabled
```

Then it stopped. There's no "would run" line and no word about the default network, bridge.conf or the VM. It reads as if it's about to set something up and then gave up half-way. A real run would print "is ready".

A second, smaller issue: the dry run asks libvirt without sudo. For a user outside the `libvirt` group it gets an empty answer and would claim it's going to `net-define` a network that already exists.

**Suggestion:**
- In a dry run, print each check's result (`default network: active, autostarted`, `bridge.conf: allows virbr0`, `VM: already on virbr0`), or end with `nothing to change`.
- Say "checking" rather than "setting up" until something actually needs doing.

## 6. `vikix doctor` doesn't check the Windows VM's network, and `vikix help` doesn't list `network`

**What happens:**
- `doctor` checks that Swank has a password and explains, in a comment, that it's because "the Windows VM, too" can reach 127.0.0.1. It doesn't check whether the VM has moved. If the migration failed (item 1) or someone switched the NIC back in virt-manager (item 7), doctor says nothing.
- `vikix help` lists `windows [setup|create ISO|stop|status|remove]` without `network`, the command `status` tells you to run.

**Suggestion:**
- When `windows` is in `~/.config/vikix/optional`, have doctor warn `the Windows VM can reach this machine's own services: vikix windows network`.
- Add `network` to the list in `vikix help`.

## 7. What a virt-manager user notices after the move

What I saw, and what follows from it:
- **Windows gets a new network card.** The move uses `virt-xml … clearxml=yes`, which drops the old MAC address. In this machine's VM log the MAC went from `…:d4:df:dc` (passt) to `…:0c:20:1d` (tap/virbr0). Windows treats that as a new adapter ("Ethernet 2"). Anything set on the old adapter is lost: a static IP or DNS, the network profile (it may ask again whether the PC should be discoverable), and a VPN client bound to the adapter.
  - Suggestion: keep the MAC by passing `mac=<old>` to `virt-xml`. Otherwise, add one README line: "Windows sees a new network adapter; settings made on the old one need redoing."
- **Programs in Windows lose access to anything served only on the Linux side.** A web developer testing in Edge could open `http://10.0.2.2:3000` or the gateway address under passt; now a dev server bound to 127.0.0.1 is unreachable. The README says "sees this machine only as 192.168.122.1", but not the practical recipe.
  - Suggestion: one line such as "To let Windows reach something on purpose, have it listen on 192.168.122.1 (or all addresses) and open http://192.168.122.1:PORT in Windows."
- **Services that listen on all addresses are now reachable from Windows** at 192.168.122.1: sshd, or a dev server started with `--host 0.0.0.0`. "Like another computer" covers this, but "another computer on your own machine, with no firewall between" would be more honest.
- **The system libvirt now runs all the time**, with a dnsmasq and NAT rules, even on days Windows is never started. Someone who opens virt-manager's default connection (qemu:///system) now sees a "default" network running that they never made. The README doesn't mention this new always-on background service.
  - Suggestion: one clause, "(the system libvirt service now starts at boot for this)".
- **In virt-manager (qemu:///session)** the NIC shows "Bridge device… virbr0". If the user picks "Usermode networking" there, `status` will say `passt` even if the backend is slirp. That's minor, but the line is really "not on virbr0", so say that.

## 8. Small things

- The migration output is fine as far as it goes (`migration 1790569435`, then `vikix windows network`'s lines), but nothing in it names the reason in plain words. One say line from the migration, such as "Windows VM: moving it to a private network so programs in Windows can't reach this computer's own services", would make the update log readable.
- `help`'s `network` line says "setup and vikix update do it; asks for sudo once". It's good that it says both. `vikix update` already asks for sudo once at the start, so there's no second prompt during the migration, and that's right. The README could say so: "`vikix update` does this with the sudo it already asks for".
- Wrong subcommands (`vikix windows foo`, `netwrok`) give `unknown command foo (vikix windows help)`. That's clear and quick, though it doesn't suggest the nearest command.

---

## What felt good

- `status` is fast (0.37 s) and reads well line by line. Its passt line names the risk and the fix in one line: `passt: Windows can reach this machine's 127.0.0.1 services; fix it: vikix windows network`. Keep that shape.
- The user doesn't have to do anything: setup does it, and update does it only where Windows was chosen. Everyone else sees `no Windows VM chosen here; nothing to do`.
- One command (`vikix windows network`) that is safe to run again, and a dry run that changes nothing and returns in a tenth of a second.
- The README bullet's headline, "Its network is kept apart from this machine", is exactly the right plain sentence. It just needs the "why" and the "what to do" next to it.
- The site card says it in one phrase ("on a network kept apart from this machine's own services") without jargon.
- The move keeps the VM's disk, TPM and shared folder untouched; only the network card changes.
