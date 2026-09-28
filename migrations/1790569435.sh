#!/usr/bin/env bash
# Why: from 0.41.0 the Windows VM is on libvirt's NAT bridge (virbr0), not
# passt. passt handed Windows this machine's 127.0.0.1 as its gateway
# address, so Windows could reach every service meant for this machine
# alone: Swank (which could run code as you; it has a password since
# 0.40.1), CUPS, and later a local model. `vikix windows network` sets up
# the bridge (the system libvirt, its default network, one line in
# /etc/qemu/bridge.conf) and moves the VM onto it. Only machines that
# chose the Windows VM (`vikix windows setup`); safe to run twice.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

optional="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/optional"
if [ -f "$optional" ] && read_list "$optional" | grep -qx windows; then
  "$VIKIX_DIR/bin/vikix-windows" network
else
  say "no Windows VM chosen here; nothing to do"
fi
