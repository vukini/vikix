#!/usr/bin/env bash
# 25-network — hand the network over to NetworkManager.
#
# The Void handbook's rules, in the order that keeps you connected:
#   1. dbus must be running (20-services switched it on)
#   2. start NetworkManager and wait until runit says it is up
#   3. only then stop the old managers (dhcpcd, wpa_supplicant, wicd),
#      because two managers fighting over one interface drops the link
#   4. put you in the 'network' group, which NetworkManager requires
#
# Over SSH the connection may pause for a few seconds at step 3 while
# NetworkManager takes the interface over. If it does not come back,
# log in on the VM's own screen and run:  nmtui

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

if [ ! -d /etc/sv/NetworkManager ]; then
  problem "NetworkManager is not installed (run the 10-packages stage first)"
fi

# 1 + 2: NetworkManager up
[ -e /var/service/dbus ] || warn "dbus is not enabled; NetworkManager will not start without it"
enable_service NetworkManager

if [ "$DRY_RUN" != 1 ]; then
  say "waiting for NetworkManager to start"
  up=0
  for _ in $(seq 1 20); do
    if sudo sv status NetworkManager 2>/dev/null | grep -q '^run:'; then up=1; break; fi
    sleep 1
  done
  [ "$up" = 1 ] || die "NetworkManager did not start; old network services left running. Check: sudo sv status NetworkManager"
fi

# 3: old managers off (every dhcpcd*, wpa_supplicant*, wicd link in /var/service)
for link in /var/service/dhcpcd* /var/service/wpa_supplicant* /var/service/wicd; do
  [ -e "$link" ] || [ -L "$link" ] || continue
  say "switching off $(basename "$link") (NetworkManager does its job now)"
  run sudo rm "$link"
done

# 4: the network group
ensure_group network "NetworkManager requires it"
