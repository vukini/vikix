#!/usr/bin/env bash
# Why: from 0.71.7 Vikix has a firewall (ufw, `vikix firewall`). A fresh
# install switches it on in 25-network; machines installed before never run
# that stage again, so this switches it on once for them. Once only: after
# this, `vikix firewall off` is your choice and updates leave it off.
#
# ufw itself came with this update (network.list) and 20-services linked its
# service. Without ufw (taken out with vikix pkg drop) this does nothing, and
# a firewall already on (set up by hand) is left as it is.
set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

if ! command -v ufw >/dev/null 2>&1; then
  say "ufw isn't installed; no firewall (vikix pkg add ufw, then vikix firewall on)"
elif grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then
  say "the firewall is already on; left as it is"
else
  "$VIKIX_DIR/bin/vikix-firewall" on
fi
