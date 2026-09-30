#!/usr/bin/env bash
# tests/idle.sh — vikix-idle suspends only on battery, only after the idle
# time in its settings, and never while keep awake is on.
#
# Stand-ins: a fake battery and charger (VIKIX_POWER_SUPPLY), a fake
# xprintidle, a fake loginctl that writes down a suspend instead of doing
# one, and a fake sleep that ends the watcher after its first look.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/power/AC" "$t/power/BAT0" "$t/config/vikix" "$t/state/vikix"
printf '#!/bin/sh\necho "$@" >> "%s/suspended"\n' "$t" > "$t/bin/loginctl"
printf '#!/bin/sh\ncat "%s/idle-ms"\n' "$t" > "$t/bin/xprintidle"
# The first sleep (the watcher's minute) returns; the next stops it.
printf '#!/bin/sh\n[ -e "%s/slept" ] && kill -PIPE "$PPID"\ntouch "%s/slept"\n' "$t" "$t" > "$t/bin/sleep"
chmod +x "$t/bin/"*

# watch AC BATTERY-STATUS IDLE-MINUTES [awake] — did it suspend?
watch() {
  echo "$1" > "$t/power/AC/online"
  echo "$2" > "$t/power/BAT0/status"
  echo $(($3 * 60000)) > "$t/idle-ms"
  rm -f "$t/suspended" "$t/slept" "$t/state/vikix/awake"
  [ "${4:-}" = awake ] && touch "$t/state/vikix/awake"
  PATH="$t/bin:$PATH" VIKIX_POWER_SUPPLY="$t/power" XDG_CONFIG_HOME="$t/config" \
    XDG_STATE_HOME="$t/state" timeout 10 sh "$here/bin/vikix-idle" --watch || true
  [ -e "$t/suspended" ] && echo yes || echo no
}
fail=0
expect() { local want=$1; shift; [ "$(watch "$@")" = "$want" ] || { echo "FAIL: $* -> suspend should be $want"; fail=1; }; }

expect yes 0 Discharging 25            # on battery, idle 25 minutes (default 20)
expect no  0 Discharging 5             # on battery, but only 5 minutes
expect no  1 Charging    25            # plugged in
expect no  1 "Not charging" 25         # plugged in, battery full
expect no  0 Discharging 25 awake      # keep awake is on
echo "SUSPEND=30" > "$t/config/vikix/idle"
expect no  0 Discharging 25            # the settings say 30 minutes
expect yes 0 Discharging 31
echo "SUSPEND=0" > "$t/config/vikix/idle"
expect no  0 Discharging 600           # 0: never

[ "$fail" = 0 ] && echo "idle: suspends on battery after the set time, never plugged in or kept awake"
exit "$fail"
