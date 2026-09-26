#!/usr/bin/env bash
# Why: before 0.10.0, 70-vm only knew VirtualBox. A Vikix installed in
# virt-manager (KVM/QEMU) got no guest tools, so the screen didn't follow
# the window and copy and paste didn't cross to the host. Re-running the
# stage adds them there; on VirtualBox and real hardware it changes nothing.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

bash "$VIKIX_DIR/install/70-vm.sh"
