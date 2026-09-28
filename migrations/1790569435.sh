#!/usr/bin/env bash
# Why: from 0.41.0 the Windows VM is on libvirt's NAT bridge (virbr0), not
# passt. passt handed Windows this machine's 127.0.0.1 as its gateway
# address, so Windows could reach every service meant for this machine
# alone: Swank (which could run code as you; it has a password since
# 0.40.1), CUPS, and later a local model. `vikix windows network` sets up
# the bridge (the system libvirt, its default network, one line in
# /etc/qemu/bridge.conf) and moves the VM onto it. Only machines that
# chose the Windows VM (`vikix windows setup`); safe to run twice. Never
# fails the update: if it can't be done now, doctor says so until it is.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"
. "$VIKIX_DIR/lib/features.sh"

# Chosen: in ~/.config/vikix/features from 0.46, in .../optional before.
if is_chosen windows; then
  # A failure here mustn't stop the update (a failed migration would stop
  # every later one too). vikix doctor keeps saying so until it's fixed.
  "$VIKIX_DIR/bin/vikix-windows" network ||
    warn "the Windows VM's network wasn't changed (above); vikix doctor reminds you, and vikix windows network tries again"
else
  say "no Windows VM chosen here; nothing to do"
fi
