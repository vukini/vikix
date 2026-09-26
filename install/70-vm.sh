#!/usr/bin/env bash
# 70-vm — guest tools, only when running inside a virtual machine.
#
# On real hardware this stage does nothing.
#
# Inside VirtualBox it adds:
#   - virtualbox-ose-guest  shared clipboard, screen that follows the window
#                           size, shared folders
#   - the vboxservice service (time sync and the rest of the guest side)
#   - a udev rule so your user may open /dev/vboxuser (Void ships none)
#   - you in the 'vboxsf' group, so shared folders are readable
#
# Inside KVM/QEMU (virt-manager, GNOME Boxes, plain qemu) it adds:
#   - spice-vdagent  shared clipboard, screen that follows the window size
#   - the spice-vdagentd service, when the VM has a Spice channel
#   - qemu-ga and its service, when the VM has a guest-agent channel
#     (lets the host shut the VM down cleanly and sync its clock)
#
# The per-session helpers (VBoxClient-all, spice-vdagent) are started by
# bin/vikix-session when they are present.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

virtualbox() {
  say "VirtualBox detected"

  if pkg_installed virtualbox-ose-guest; then
    say "guest additions already installed"
  else
    run sudo xbps-install -Sy virtualbox-ose-guest
  fi

  enable_service vboxservice

  # Void's guest package ships no udev rule, which leaves /dev/vboxuser
  # root-only; VBoxClient then fails with VERR_ACCESS_DENIED. Add the rule,
  # and apply it to the device that already exists.
  local rule=/etc/udev/rules.d/60-vboxguest.rules
  if cmp -s "$VIKIX_DIR/config/udev/60-vboxguest.rules" "$rule"; then
    say "vboxuser device rule already in place"
  else
    say "installing the vboxuser device rule"
    # -D: Void ships no /etc/udev/rules.d folder; install creates it.
    run sudo install -Dm644 "$VIKIX_DIR/config/udev/60-vboxguest.rules" "$rule"
  fi
  [ -e /dev/vboxuser ] && run sudo chmod 0666 /dev/vboxuser

  # Void's guest package does not create the vboxsf group, but VBoxService
  # gives automounted shared folders to that group when it exists.
  if ! getent group vboxsf >/dev/null; then
    say "creating the vboxsf group"
    run sudo groupadd -r vboxsf
  fi

  ensure_group vboxsf "for shared folders"

  say "reboot the VM once so the guest kernel modules load"
}

# enable_if_channel SERVICE PORT HOW
# Both daemons exit at once when their virtio channel is missing, and
# runit would restart them every second forever. So a service is only
# switched on when the VM actually has the channel it talks through.
enable_if_channel() {
  local sv=$1 port=/dev/virtio-ports/$2 how=$3
  if [ -e "/var/service/$sv" ] || [ -e "$port" ]; then
    enable_service "$sv"
  else
    warn "no $2 channel in this VM, so $sv is left off"
    warn "  to add it: $how"
    warn "  then run: $VIKIX_DIR/install.sh --only 70-vm"
  fi
}

kvm() {
  say "KVM/QEMU detected"

  local pkg
  for pkg in spice-vdagent qemu-ga; do
    if pkg_installed "$pkg"; then
      say "$pkg already installed"
    else
      run sudo xbps-install -Sy "$pkg"
    fi
  done

  enable_if_channel spice-vdagentd com.redhat.spice.0 \
    "virt-manager → Add Hardware → Channel → com.redhat.spice.0 (and Display: Spice)"
  enable_if_channel qemu-ga org.qemu.guest_agent.0 \
    "virt-manager → Add Hardware → Channel → org.qemu.guest_agent.0"

  say "log out and back in (or reboot) so the session starts spice-vdagent"
}

if [ "$vendor" = "innotek GmbH" ] || [ "$product" = "VirtualBox" ]; then
  virtualbox
elif [ "$vendor" = "QEMU" ] || [[ "$product" == *KVM* ]]; then
  kvm
else
  say "not a virtual machine Vikix knows ($vendor $product); nothing to do"
fi
