#!/usr/bin/env bash
# 70-vm — VirtualBox guest additions, only when running inside VirtualBox.
#
# On real hardware this stage does nothing. Inside VirtualBox it adds:
#   - virtualbox-ose-guest  shared clipboard, screen that follows the window
#                           size, shared folders
#   - the vboxservice service (time sync and the rest of the guest side)
#   - a udev rule so your user may open /dev/vboxuser (Void ships none)
#   - you in the 'vboxsf' group, so shared folders are readable
# The clipboard and resize helpers (VBoxClient-all) are started by
# bin/vikix-session when they are present.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

if [ "$vendor" != "innotek GmbH" ] && [ "$product" != "VirtualBox" ]; then
  say "not a VirtualBox machine ($vendor $product); nothing to do"
  exit 0
fi

say "VirtualBox detected"

if pkg_installed virtualbox-ose-guest; then
  say "guest additions already installed"
else
  run sudo xbps-install -Sy virtualbox-ose-guest
fi

if [ -e /var/service/vboxservice ]; then
  say "vboxservice already enabled"
else
  run sudo ln -s /etc/sv/vboxservice /var/service/
fi

# Void's guest package ships no udev rule, which leaves /dev/vboxuser
# root-only; VBoxClient then fails with VERR_ACCESS_DENIED. Add the rule,
# and apply it to the device that already exists.
rule=/etc/udev/rules.d/60-vboxguest.rules
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

if id -nG | tr ' ' '\n' | grep -qx vboxsf; then
  say "already in the vboxsf group"
else
  me=$(id -un)
  say "adding $me to the vboxsf group (takes effect at next login)"
  run sudo usermod -aG vboxsf "$me"
fi

say "reboot the VM once so the guest kernel modules load"
