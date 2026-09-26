#!/usr/bin/env bash
# 20-services — switch on the runit services named in services.list.
#
# Void uses runit, not systemd. A service is enabled by symlinking its
# folder in /etc/sv into /var/service; runit notices and starts it.
# There is no "systemctl enable" — this symlink is the whole mechanism.
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
  if [ -e "/var/service/$sv" ]; then
    say "service $sv already enabled"
  else
    say "enabling service $sv"
    run sudo ln -s "/etc/sv/$sv" /var/service/
  fi
done < <(read_list "$VIKIX_DIR/services.list")

if id -nG | tr ' ' '\n' | grep -qx video; then
  say "already in the video group"
else
  me=$(id -un)
  say "adding $me to the video group"
  run sudo usermod -aG video "$me"
fi
