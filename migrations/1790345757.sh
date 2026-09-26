#!/usr/bin/env bash
# Why: Vikix 0.1–0.2 switched on the elogind runit service. dbus also
# starts elogind on demand, often first, and then the runit service loops
# forever printing "elogind is already running as PID ..." on the console.
# elogind works through dbus alone, so the runit service is switched off.
# The running elogind is left alone; nothing is restarted.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

if [ -L /var/service/elogind ]; then
  say "switching off the elogind runit service (dbus starts elogind itself)"
  run sudo rm /var/service/elogind
else
  say "elogind runit service already off"
fi
