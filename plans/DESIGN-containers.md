# Containers — design

Another Linux inside Vikix, for a program that only ships as a `.deb` or for Arch, without Docker and without a root daemon.

Drafted and built 2026-10-16. What shipped is noted below; what is left stays here.

---

## The problem

Void does not package everything a person already uses. A `.deb`, or a program that assumes Arch, needs a system that is not Void. A virtual machine (the Windows feature) is the wrong weight for that: it holds memory, it does not share the home folder, and it is a second computer. Distrobox is the other way: a container that is a normal Linux, entered as yourself, with the home folder shared so the files are the same ones.

The shared home folder is the point, and it is not a wall. A program inside the box can read what the user can read, including `~/.config/vikix/secrets`. The box is a place to install packages, not a sandbox for untrusted code.

## What shipped (2026-10-16)

- **A feature**, `containers`, in `features.list`. `vikix add containers` runs `vikix containers setup`. `vikix remove containers` runs `vikix containers remove` and then uninstalls the packages only this feature needed.
- **Packages**, `packages/optional/containers.list`: `podman`, `aardvark-dns` and `crun`. Checked against void-packages on 2026-10-16. Podman 5.8.8 depends on runc, conmon, cni-plugins, slirp4netns, fuse-overlayfs, passt, netavark and the containers libraries, so those are not listed again. aardvark-dns is not a dependency, and netavark's DNS needs it. crun 1.30.1 is listed because a box needs it (below). Distrobox is not packaged.
- **Podman's engine, for runit.** Setup writes `~/.config/containers/containers.conf` and only fills a key you have not set, under `[engine]`: `cgroup_manager = "cgroupfs"`, `events_logger = "file"`, `runtime = "crun"`. Then `podman system migrate`. Void's Podman already rewrites the shared file's cgroup manager to cgroupfs, and a plain `podman run` works with that and a file log. Distrobox's create command also passes `--pids-limit=-1`. With an empty cgroup path, runc still tries to apply that limit and fails: `rootless needs no limits + no cgrouppath`, `mkdir /sys/fs/cgroup/…: permission denied`. crun 1.30's `can_ignore_cgroup_enter_errors` ignores that when the process is rootless, the OCI cgroup path is empty, and the manager is not systemd. Void builds crun with `--disable-systemd`, and cgroupfs is what leaves the path empty. A box created before the runtime changed keeps the runtime it was made with; migrate does not switch it. Create the box again (`distrobox rm`, then `vikix containers create`). That drops what was installed inside the box. The home folder stays.
- **No root daemon.** Podman's template drops runit service files and does not enable them. Vikix does not link `/var/service/podman` or `podman-docker`. Rootless Podman starts nothing until a container runs.
- **Subuid and subgid**, written once for the user who runs setup (`/etc/subuid`, `/etc/subgid`, 65536 ids). A user who already has a line in both files is left as they are. A line Vikix added is remembered in `$VIKIX_STATE/containers-subids` and removed only when it still matches. Where the kernel has `kernel.unprivileged_userns_clone` and it is 0, setup turns it on; Void's usual kernel has no such sysctl, and then nothing is written.
- **Distrobox 1.8.2.5**, fetched from the tag archive, checksummed, and installed with its own `install --prefix ~/.local`. The scripts are copied into `~/.local/bin` (Distrobox finds its siblings beside `dirname` of the command, so one symlink is not enough). The checksum is GitHub's generated archive as downloaded on 2026-10-16; GitHub publishes none. The licence is GPL-3, so the scripts are not vendored into this MIT tree.
- **A default box**, named `vikix`, image `ubuntu:24.04`, only when setup is asked (`--box`) or the user says yes at a terminal. `install.sh --with containers` has no terminal, so it does not download an image. `~/.config/vikix/containers` holds `BOX` and `IMAGE`.
- **Removal** deletes Distrobox's scripts and the subid lines Vikix wrote. Boxes and images stay unless the user types `remove` or passes `--boxes` (`distrobox rm --all --force`, then `podman image prune --all --force`). Never `--rm-home`: that home is the real one.
- **Updates.** `vikix update` and `vikix update tools` run `distrobox upgrade --all` when the feature is chosen. `vikix update core` does not: core stays the fast path.
- **Doctor.** `vikix containers check` is quiet when the feature is off, and names what is missing when it is on. `vikix doctor` runs it.
- **A key inside the desk map**, `Super+Alt+d` then `b`, and a Super+m Apps entry, both opening a terminal in the default box. The key card has no free top-level key.

## Non-goals

- **Not Docker, Incus or Flatpak.** Flatpak stays an idea in `IDEAS.md`. A root Podman service is not part of this.
- **Not a sandbox.** The box shares the home folder on purpose.
- **Not a catalogue of images.** One default, Ubuntu 24.04 LTS. `vikix containers create NAME --image IMAGE` makes another. Arch and the rest are that flag.
- **Not a migration.** A machine that never chose the feature has nothing to change. `vikix update` does not install it.

## Left

- A menu to pick which box `b` enters, when there is more than the default.
- Whether a box should be offered a mount that is not the whole home folder. That would stop being the safety net this was chosen for, so it waits for a reason.
