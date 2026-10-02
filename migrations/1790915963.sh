#!/usr/bin/env bash
# Why: up to 0.71.29 Vikix switched on acpid, whose /etc/acpi/handler.sh
# suspends on closing the lid (zzz). elogind suspends on the lid too, so
# each close asked for two suspends at once: some failed ("device busy" at
# the freeze step), the laptop could sleep a second time after waking
# (a blank screen for a while on opening it), and acpid's suspend skipped
# the lock screen, which only hears of elogind's. elogind alone now handles
# the lid and the power button (StumpWM has the brightness keys), so the
# acpid service is switched off. The package stays; nothing else changes.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

if [ -L "$VIKIX_SERVICE_DIR/acpid" ]; then
  say "switching off acpid: elogind alone suspends on the lid, after locking the screen"
  run sudo rm "$VIKIX_SERVICE_DIR/acpid"
else
  say "acpid already off"
fi
