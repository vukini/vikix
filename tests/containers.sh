#!/usr/bin/env bash
# tests/containers.sh — vikix containers, with stand-ins for xbps, sudo and
# Distrobox:
#
#   the list names podman, aardvark-dns and crun, and not docker, incus,
#   flatpak or distrobox (those were checked against void-packages; distrobox
#   is fetched, the others are not this feature)
#   setup writes cgroupfs, a file log and crun into containers.conf, leaving
#   a value already set, and runs podman system migrate
#   setup records the feature, installs the list through 10-packages, writes
#   a subuid and a subgid line once, installs Distrobox from the archive, and
#   does not create a box when stdin is not a terminal
#   setup --box creates the box; a second setup installs nothing again
#   a user who already has both lines is left alone; a line in only one file
#   is copied to the other; a taken range is not reused
#   a dry run changes nothing and records nothing
#   check is silent when containers isn't chosen, and exit 1 when it is and
#   podman is missing
#   remove without a terminal keeps boxes and still returns 0; --boxes deletes
#   them and unused images, and never passes --rm-home
#   the subuid lines Vikix wrote go; a line the user already had stays
#   upgrade runs distrobox upgrade --all when the feature is on
#   no runit service is enabled
#
# Nothing real runs: sudo, xbps-query, podman and the Distrobox scripts are
# stand-ins. The archive is a tiny one made here, with its own checksum.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
export VIKIX_SUBUID="$t/subuid" VIKIX_SUBGID="$t/subgid"
export VIKIX_SYSCTL_PROC="$t/no-such-sysctl" VIKIX_SYSCTL_FILE="$t/sysctl.conf"
export VIKIX_FUSE="$t/fuse" VIKIX_DISTROBOX_PREFIX="$t/prefix"
export VIKIX_DISTROBOX_TARBALL="$t/distrobox.tar.gz"
export VIKIX_CONTAINER_CALLS="$t/calls" VIKIX_CONTAINER_BOXES="$t/boxes"
mkdir -p "$HOME" "$t/bin" "$VIKIX_STATE" "$t/prefix"
: > "$t/subuid"; : > "$t/subgid"; : > "$t/fuse"; : > "$t/calls"; : > "$t/boxes"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has() { grep -q -- "$1" <<<"$2"; }
me=$(id -un)

cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
case \$1 in
  -l) while read -r p; do echo "ii \$p-1.0_1 a package"; done < "$t/installed" ;;
  -R) exit 0 ;;
  -*) exit 0 ;;
  *) grep -qx -- "\$1" "$t/installed" ;;
esac
EOF
cat > "$t/bin/sudo" <<'EOF'
#!/bin/bash
echo "sudo $*" >> "$VIKIX_CONTAINER_CALLS"
case "$1" in
  xbps-install)
    case "$2" in
      -y|-Sy) shift 2; for p; do [ "$p" = xbps ] || echo "$p" >> "$VIKIX_TEST_INSTALLED"; done ;;
    esac ;;
  tee)
    # A stand-in for root: the file may have been made unwritable on purpose.
    if [ "$2" = -a ]; then chmod u+w "$3"; cat >> "$3"; else chmod u+w "$2"; cat > "$2"; fi ;;
  rm) shift; rm -f "$@" ;;
  install) shift; install "$@" ;;
esac
exit 0
EOF
# The installed file is named in the stub via the environment, so the
# script above can be quoted. Point it at the test's file.
export VIKIX_TEST_INSTALLED="$t/installed"
: > "$t/installed"
printf '#!/bin/sh\necho podman "$*" >> "$VIKIX_CONTAINER_CALLS"\nexit 0\n' > "$t/bin/podman"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/newuidmap"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/newgidmap"
cat > "$t/bin/term" <<'EOF'
#!/bin/sh
echo "term $*" >> "$VIKIX_CONTAINER_CALLS"
exit 0
EOF
chmod +x "$t/bin/xbps-query" "$t/bin/sudo" "$t/bin/podman" "$t/bin/newuidmap" "$t/bin/newgidmap" "$t/bin/term"
export PATH="$t/bin:$PATH" VIKIX_TERMINAL="$t/bin/term"

# A one-file Distrobox: install copies the stub, which records every call.
stage=$t/stage/distrobox-1.8.2.5
mkdir -p "$stage"
cat > "$stage/distrobox" <<'EOF'
#!/bin/sh
echo "distrobox $*" >> "$VIKIX_CONTAINER_CALLS"
case $1 in
  version) echo "distrobox: 1.8.2.5" ;;
  list)
    echo "ID | NAME | STATUS | IMAGE"
    [ -f "$VIKIX_CONTAINER_BOXES" ] || exit 0
    while read -r n; do [ -n "$n" ] && echo "1 | $n | Up | ubuntu:24.04"; done < "$VIKIX_CONTAINER_BOXES"
    ;;
  create)
    prev=
    for a in "$@"; do
      if [ "$prev" = --name ]; then echo "$a" >> "$VIKIX_CONTAINER_BOXES"; fi
      prev=$a
    done
    ;;
  rm) : > "$VIKIX_CONTAINER_BOXES" ;;
esac
exit 0
EOF
cat > "$stage/install" <<'EOF'
#!/bin/sh
prefix=
while [ $# -gt 0 ]; do
  case $1 in
    --prefix) prefix=$2; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$prefix/bin"
cp distrobox "$prefix/bin/distrobox"
chmod +x "$prefix/bin/distrobox"
EOF
chmod +x "$stage/distrobox" "$stage/install"
tar -C "$t/stage" -czf "$VIKIX_DISTROBOX_TARBALL" distrobox-1.8.2.5
export VIKIX_DISTROBOX_SHA256
VIKIX_DISTROBOX_SHA256=$(sha256sum "$VIKIX_DISTROBOX_TARBALL" | awk '{print $1}')

choices="$HOME/.config/vikix/features"
boxes() { bash "$here/bin/vikix-containers" "$@"; }
reset() {
  rm -rf "$VIKIX_STATE" "$t/prefix" "$HOME/.config"
  mkdir -p "$VIKIX_STATE" "$t/prefix"
  : > "$t/subuid"; : > "$t/subgid"; : > "$t/calls"; : > "$t/boxes"; : > "$t/installed"
  rm -f "$VIKIX_SYSCTL_FILE"
}

# --- the data -----------------------------------------------------------------------
check "features.list names optional/containers with setup and remove" \
  grep -q '^containers *| *optional/containers *| *| *vikix containers setup *| *vikix containers remove *|' "$here/features.list"
check "the list has podman" grep -q '^podman ' "$here/packages/optional/containers.list"
check "the list has aardvark-dns" grep -q '^aardvark-dns ' "$here/packages/optional/containers.list"
check "the list has crun" grep -q '^crun ' "$here/packages/optional/containers.list"
for p in docker incus flatpak distrobox slirp4netns passt netavark fuse-overlayfs; do
  check "the list does not name $p itself" bash -c "! grep -q '^$p ' '$here/packages/optional/containers.list'"
done
check "the script never enables a runit service" bash -c "! grep -q 'enable_service\|/var/service' '$here/bin/vikix-containers'"
check "the script never passes --rm-home" bash -c "! grep -q -- '--rm-home' '$here/bin/vikix-containers'"
check "the desk map opens a box" grep -q ':map "desks b"' "$here/config/stumpwm/vikix/registry.lisp"
check "Apps has the box" grep -q 'A box: a terminal in Ubuntu (distrobox)' "$here/config/stumpwm/vikix/registry.lisp"
check "doctor asks containers" grep -q 'vikix-containers" check' "$here/bin/vikix"
check "update tools upgrades boxes" grep -q 'vikix-containers" upgrade' "$here/bin/vikix"

# --- setup, with no terminal --------------------------------------------------------
reset
out=$(boxes setup 2>&1) || { echo "FAIL: setup failed: $out"; fail=1; }
check "setup records the feature" grep -qx containers "$choices"
check "the list went in through 10-packages" grep -q '^sudo xbps-install -y podman aardvark-dns crun$' "$t/calls"
check "Podman is told to use cgroupfs" grep -qx 'cgroup_manager = "cgroupfs"' "$HOME/.config/containers/containers.conf"
check "Podman logs events to a file" grep -qx 'events_logger = "file"' "$HOME/.config/containers/containers.conf"
check "Podman uses crun" grep -qx 'runtime = "crun"' "$HOME/.config/containers/containers.conf"
check "setup migrates Podman's store" grep -q '^podman system migrate$' "$t/calls"
check "a subuid line was written" grep -qx "$me:100000:65536" "$t/subuid"
check "the same line in subgid" grep -qx "$me:100000:65536" "$t/subgid"
check "the stamp remembers both lines" grep -qx "subuid $me:100000:65536" "$VIKIX_STATE/containers-subids"
check "Distrobox was installed from the archive" test -x "$t/prefix/bin/distrobox"
check "the manifest names that script" grep -qx "$t/prefix/bin/distrobox" "$VIKIX_STATE/distrobox-installed"
check "no box without a terminal: $out" bash -c "! grep -q '^distrobox create' '$t/calls'"
check "setup says how to create one" has 'vikix containers create' "$out"
check "the config names the default box" grep -qx 'BOX=vikix' "$HOME/.config/vikix/containers"
check "the config names ubuntu:24.04" grep -qx 'IMAGE=ubuntu:24.04' "$HOME/.config/vikix/containers"
check "no sysctl file when the kernel has none" test ! -e "$VIKIX_SYSCTL_FILE"

out=$(boxes check 2>&1) || { echo "FAIL: check with everything there failed: $out"; fail=1; }
check "check says all is well" has 'Podman is rootless' "$out"

: > "$t/calls"
out=$(boxes setup 2>&1) || { echo "FAIL: a second setup failed: $out"; fail=1; }
check "a second setup installs no packages" bash -c "! grep -q 'xbps-install -y' '$t/calls'"
check "a second setup adds no second subuid line" test "$(grep -c "^$me:" "$t/subuid")" = 1
check "a second setup does not repeat the engine keys" test "$(grep -c '^cgroup_manager ' "$HOME/.config/containers/containers.conf")" = 1

# A box, when asked. The second time it is already there.
: > "$t/calls"
out=$(boxes setup --box vikix --image ubuntu:24.04 2>&1) || { echo "FAIL: setup --box failed: $out"; fail=1; }
check "setup --box creates it" grep -q '^distrobox create --name vikix --image ubuntu:24.04 --yes$' "$t/calls"
: > "$t/calls"
out=$(boxes create 2>&1) || { echo "FAIL: a second create failed: $out"; fail=1; }
check "a second create does not run create again" bash -c "! grep -q '^distrobox create' '$t/calls'"
check "a second create says it is there" has 'already there' "$out"

# --- subids -------------------------------------------------------------------------
reset
echo "other:100000:65536" > "$t/subuid"
echo "other:100000:65536" > "$t/subgid"
boxes setup >/dev/null
check "a taken range is skipped" grep -qx "$me:165536:65536" "$t/subuid"
check "and in subgid too" grep -qx "$me:165536:65536" "$t/subgid"

reset
echo "$me:200000:8192" > "$t/subuid"
boxes setup >/dev/null
check "an existing subuid line is kept" grep -qx "$me:200000:8192" "$t/subuid"
check "and copied to subgid" grep -qx "$me:200000:8192" "$t/subgid"
check "the stamp names only the line Vikix added" bash -c "grep -qx 'subgid $me:200000:8192' '$VIKIX_STATE/containers-subids' && ! grep -q subuid '$VIKIX_STATE/containers-subids'"

reset
echo "$me:300000:65536" > "$t/subuid"
echo "$me:300000:65536" > "$t/subgid"
boxes setup >/dev/null
check "both lines already there: subuid unchanged" test "$(cat "$t/subuid")" = "$me:300000:65536"
check "no stamp when Vikix wrote nothing" test ! -e "$VIKIX_STATE/containers-subids"

# A file that isn't writable goes through sudo.
reset
chmod a-w "$t/subuid" "$t/subgid"
boxes setup >/dev/null
check "a read-only subuid is written with sudo" grep -q "sudo tee -a $t/subuid" "$t/calls"
check "the line arrived" grep -qx "$me:100000:65536" "$t/subuid"
chmod u+w "$t/subuid" "$t/subgid"

# The sysctl, only when the kernel has it and it is off.
reset
echo 0 > "$VIKIX_SYSCTL_PROC"
boxes setup >/dev/null
check "a switched-off userns sysctl is turned on in a file" grep -qx 'kernel.unprivileged_userns_clone = 1' "$VIKIX_SYSCTL_FILE"
echo 1 > "$VIKIX_SYSCTL_PROC"
rm -f "$VIKIX_SYSCTL_FILE"
: > "$t/calls"
boxes setup >/dev/null
check "a sysctl already on is left alone" test ! -e "$VIKIX_SYSCTL_FILE"

# --- check, remove, upgrade ---------------------------------------------------------
reset
out=$(boxes check 2>&1) || { echo "FAIL: check should be silent when not chosen: $out"; fail=1; }
check "check says nothing when not chosen" test -z "$out"

mkdir -p "$(dirname "$choices")"
echo containers > "$choices"
out=$(boxes check 2>&1) && { echo "FAIL: check should fail when podman is missing"; fail=1; }
check "check names podman" has "podman isn't installed" "$out"

reset
boxes setup >/dev/null
echo vikix > "$t/boxes"
: > "$t/calls"
out=$(boxes remove 2>&1) || { echo "FAIL: remove without a terminal failed: $out"; fail=1; }
check "remove without a terminal does not delete boxes" bash -c "! grep -q '^distrobox rm' '$t/calls'"
check "and does not prune images" bash -c "! grep -q 'podman image prune' '$t/calls'"
check "it says the boxes stay" has 'boxes and images stay' "$out"
check "Distrobox's script is gone" test ! -e "$t/prefix/bin/distrobox"
check "the subuid line Vikix wrote is gone" bash -c "! grep -q '^$me:' '$t/subuid'"
check "the box list was kept" grep -qx vikix "$t/boxes"

reset
echo "$me:300000:65536" > "$t/subuid"
echo "$me:300000:65536" > "$t/subgid"
boxes setup >/dev/null
boxes remove >/dev/null
check "a subuid line the user already had stays" grep -qx "$me:300000:65536" "$t/subuid"

reset
boxes setup >/dev/null
echo vikix > "$t/boxes"
: > "$t/calls"
boxes remove --boxes >/dev/null
check "remove --boxes deletes every box" grep -q '^distrobox rm --all --force$' "$t/calls"
check "and prunes unused images" grep -q '^podman image prune --all --force$' "$t/calls"
check "never --rm-home" bash -c "! grep -q rm-home '$t/calls'"
check "the planted box is gone" test ! -s "$t/boxes"

reset
boxes setup >/dev/null
: > "$t/calls"
boxes upgrade >/dev/null
check "upgrade runs distrobox upgrade --all" grep -q '^distrobox upgrade --all$' "$t/calls"
rm -f "$choices"
: > "$t/calls"
boxes upgrade >/dev/null
check "upgrade does nothing when the feature is off" bash -c "! grep -q distrobox '$t/calls'"

# Opening from the menu: no terminal yet, so the configured one is started.
reset
boxes setup --box vikix >/dev/null
: > "$t/calls"
boxes open >/dev/null
check "open starts a terminal in the default box" grep -q "term -e $t/prefix/bin/distrobox enter vikix" "$t/calls"

# A dry run writes nothing.
reset
out=$(DRY_RUN=1 boxes setup --box vikix 2>&1) || { echo "FAIL: dry run failed: $out"; fail=1; }
check "a dry run records no feature" test ! -e "$choices"
check "a dry run writes no subuid" test ! -s "$t/subuid"
check "a dry run installs no Distrobox" test ! -e "$t/prefix/bin/distrobox"
check "a dry run would create the box" has 'would run: distrobox create --name vikix' "$out"
check "a dry run would set the engine" has 'would set cgroup_manager="cgroupfs"' "$out"
check "a dry run writes no containers.conf" test ! -e "$HOME/.config/containers/containers.conf"

# A value already set is left, and check names a runtime that is not crun.
reset
mkdir -p "$HOME/.config/containers"
cat > "$HOME/.config/containers/containers.conf" <<'EOF'
# kept
[containers]
userns = "keep-id"

[engine]
runtime = "runc"
volume_path = "/tmp/v"

[network]
dns_bind_port = 53
EOF
out=$(boxes setup 2>&1) || { echo "FAIL: setup with an existing engine failed: $out"; fail=1; }
check "a comment is kept" grep -qx '# kept' "$HOME/.config/containers/containers.conf"
check "another section is kept" grep -qx 'dns_bind_port = 53' "$HOME/.config/containers/containers.conf"
check "a runtime the user set is kept" grep -qx 'runtime = "runc"' "$HOME/.config/containers/containers.conf"
check "the missing engine keys are added" grep -qx 'cgroup_manager = "cgroupfs"' "$HOME/.config/containers/containers.conf"
check "events_logger is added beside them" grep -qx 'events_logger = "file"' "$HOME/.config/containers/containers.conf"
out=$(boxes check 2>&1) && { echo "FAIL: check should fail when the runtime is runc: $out"; fail=1; }
check "check names the runtime" has 'runtime is runc, not crun' "$out"

# A box that already exists still has its old runtime. Setup says so, and
# does not delete it.
reset
echo oldbox > "$t/boxes"
out=$(boxes setup 2>&1) || { echo "FAIL: setup with an old box failed: $out"; fail=1; }
check "an old box is named" has 'oldbox' "$out"
check "setup says to create it again" has 'vikix containers create NAME' "$out"
check "the old box was not deleted" grep -qx oldbox "$t/boxes"
out=$(boxes remove 2>&1) || { echo "FAIL: remove failed: $out"; fail=1; }
check "remove leaves Podman's config" test -f "$HOME/.config/containers/containers.conf"

# The command is reached through vikix.
reset
out=$(bash "$here/bin/vikix" containers status 2>&1) || { echo "FAIL: vikix containers failed: $out"; fail=1; }
check "vikix containers status runs" has "isn't chosen" "$out"

[ "$fail" = 0 ] && echo "containers: setup, subids, the box, remove and upgrade"
exit "$fail"
