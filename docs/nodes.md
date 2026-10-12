# Your other machines, as nodes

A **node** is another machine of yours that this Vikix knows by name: a
cheap VPS that is always on, a box at home, a build machine. The idea (the
design is `plans/DESIGN-cloud.md`) is that your computer doesn't end at
your laptop: the node is part of the one system, not a server you log
into. This first step is the part that proves it: the node named, seen and
reached. Sending a project there and pulling it back, jobs that go on while
the laptop is closed, and `--on NAME` for the other commands come later.

A node is a **Void Linux** machine (runit, xbps), usually headless, reached
over **SSH alone**, as yourself, by key. Nothing of Vikix's is installed on
it, and `ssh atlas` is the same machine: everything Vikix does here you can
do with ssh by hand.

## Adding one

```sh
vikix node add atlas vid@atlas.example.com
vikix node add forge forge-build --port 2222 --kind build
```

The name is lowercase letters, digits and dashes. The host is what you would
give ssh: `user@host`, or a name from your `~/.ssh/config`. Vikix reaches the
machine once, right then, with ssh's own prompts, so the **host key is yours
to confirm**: look at the fingerprint as you would for any new machine. From
then on the key is known, and a changed one refuses. If ssh asks for a
password here, there is no key of yours on the machine yet: `add` says so at
the end, and `ssh-copy-id vid@atlas.example.com` puts one there. Vikix never
keeps or asks a password after that: every later call is keys only, no
prompt of any kind.

A machine that isn't Void is kept, with a warning: what comes later (the
services, the jobs) is built for runit and xbps.

The node is a file of yours, `~/.config/vikix/nodes/atlas`:

```
host=vid@atlas.example.com
port=22
kind=cloud
added=2026-10-12
```

Edit it, or `vikix node remove atlas` forgets it (the file and the last
answer); the machine itself is never touched. Adds and removes are noted in
`~/.local/state/vikix/nodes/log`.

## Seeing them

```
$ vikix nodes
NAME   KIND   STATUS   SYSTEM           WHAT RUNS
x1     local  online   Void / StumpWM   up 3d 4h, load 0.42, vikix 0.72.62
atlas  cloud  online   Void / headless  up 41d 2h, load 0.03
forge  build  offline  Void / headless  up 2d 1h, load 1.20
```

This machine comes first. Each node is asked at the same time, with a few
seconds to answer (`VIKIX_NODE_TIMEOUT`, 8 by default); one that doesn't
is *offline*, and what it answered last stays on its line. `vikix nodes
--last` shows the last answers without asking anyone, with how long ago
each came. The answers are kept in `~/.local/state/vikix/nodes/NAME`.

`vikix node status atlas` is the whole answer: the system and its init, the
kernel, uptime and load, memory and disk, the Vikix in `~/vikix` there if
any, the runit services enabled, and the programs running as you. What a
node is asked is a short POSIX shell script that reads `/proc`, `/etc` and
`df`; it needs nothing installed.

## A shell, a command

```sh
vikix node shell atlas
vikix node run atlas uname -a
vikix node run atlas 'cd ~/src/vikix && tests/run.sh --quick'
```

`shell` is `ssh -t` in this terminal. `run` runs the words there as ssh
does: quote for the node's shell as you would for ssh. Your input goes
through (a pipe into it works), and the command's exit status comes back as
`vikix node run`'s own; a node that can't be reached is a message and 1.

## What it doesn't do

- **No synchronisation.** Nothing of your home goes to a node unless you
  send it. A project goes by git, the rest by rsync or scp, by hand for now;
  a command for that is the design's next step.
- **No agent, no service, no job** on a node yet. `vikix node run` is the
  only thing that runs anything there.
- **No mesh.** A node is reached at the address you gave it; Tailscale
  (TODO 16) comes later and won't be required.
- **An agent never adds a node.** `add` is interactive on purpose, so the
  host key is confirmed by you; the agent's page says as much.
