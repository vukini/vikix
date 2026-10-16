# A box, another Linux

A box is another Linux running as you, with Podman, sharing your home folder. Ubuntu is the default. A program that only ships as a `.deb`, or that assumes Arch, is installed inside the box, and the files it opens are the same files as outside. It is not a wall: anything you can read, the box can read, including `~/.config/vikix/secrets`.

## Adding it

```sh
vikix add containers
```

Or pick it in the welcome (Super+m → Add software). At a terminal it asks whether to create a box named `vikix` from `ubuntu:24.04`. That downloads the image once. Without a terminal (an install that named the feature, `./install.sh --with containers`) it does not download anything; create the box when you want it:

```sh
vikix containers create              # the default: vikix, from ubuntu:24.04
vikix containers create arch --image archlinux:latest
vikix containers setup --no-box      # Podman and Distrobox, and no box
```

What the setup does:

- **installs Podman** from Void, and aardvark-dns, which container DNS needs, and crun (`packages/optional/containers.list`). Podman brings runc, conmon, slirp4netns, passt, fuse-overlayfs, netavark and the rest. No root service is switched on: a container starts when you enter the box, and not before.
- **tells Podman this machine runs runit**, in `~/.config/containers/containers.conf`: `cgroup_manager = "cgroupfs"`, `events_logger = "file"` and `runtime = "crun"`. A value you already set is left as it is. Then it runs `podman system migrate`. cgroupfs is enough for `podman run`. A box also sets a pids limit (`--pids-limit`), and runc refuses that when you cannot write a cgroup, with `rootless needs no limits + no cgrouppath`. crun ignores that failure (Void builds it without systemd), so the box starts. runc stays installed, because Podman depends on it.
- **gives your user a range of subuids and subgids** in `/etc/subuid` and `/etc/subgid`, if you have none. A range you already set is left as it is.
- **installs Distrobox 1.8.2.5** into `~/.local` (Void does not package it). The checksum is the tag's archive as it was on 2026-10-16.

A box created before this engine still uses the runtime it was made with. `podman system migrate` does not change that. Create it again:

```sh
distrobox rm vikix
vikix containers create
```

That drops what was installed inside the box. Your home folder stays.

The names live in `~/.config/vikix/containers` (`BOX`, `IMAGE`), which the snapshot history covers.

## Day to day

Super+Alt+d, then `b`, opens a terminal in the default box. So does Super+m → Apps → *A box*, and:

```sh
vikix containers open           # the default box
vikix containers open arch      # one you named
vikix containers list
```

Inside it, `apt` or `pacman` install into the box, not into Void. Leaving the terminal leaves the box running; `distrobox stop vikix` stops it.

`vikix update` and `vikix update tools` run `distrobox upgrade --all` when this feature is on, so the boxes keep up with their own distributions. `vikix update core` (what `gup` runs) does not: that path stays short. `vikix containers upgrade` does the same on its own.

```sh
vikix containers status
```

says whether Podman, crun, Distrobox and your subuids are in place, and whether Podman is set for runit (cgroupfs, a file log, crun). `vikix doctor` checks the same once containers is one of your features, and names a runtime that is still runc.

## Removing it

```sh
vikix remove containers
```

takes the packages away, and Distrobox's scripts. Your boxes and their images stay, under `~/.local/share/containers`, unless you type `remove` when asked (or run `vikix containers remove --boxes`). The home folder is never deleted: it is your home folder. Subuid lines Vikix wrote are removed only when they are still the lines it wrote.
