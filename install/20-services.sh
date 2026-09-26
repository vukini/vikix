#!/usr/bin/env bash
# 20-services — switch on the runit services named in services.list.
#
# Void uses runit, not systemd: enable_service (lib/common.sh) links a
# service's folder into /var/service. `vikix update` runs this stage too,
# so a service whose package arrives with an update is switched on.
#
# Also adds you to the 'video' group so brightnessctl can change the
# screen brightness without sudo (takes effect at your next login).

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

while IFS= read -r sv; do
  if [ ! -d "/etc/sv/$sv" ]; then
    say "service $sv: its package isn't installed yet; skipped (part two or vikix update switches it on)"
    continue
  fi
  enable_service "$sv"
done < <(read_list "$VIKIX_DIR/services.list")

ensure_group video "for screen brightness"
