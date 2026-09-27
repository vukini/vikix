#!/usr/bin/env bash
# tests/firmware.sh — vikix firmware installs only on mains power (or on a
# desktop with no battery), fetches the LVFS list before showing or
# installing, and counts the devices with an update for the bar.
#
# fwupdmgr is a stand-in that writes down what it was asked; the power
# supplies are made-up folders; vikix-updates (which the update calls to
# refresh the bar) is a stand-in too. A copy of the script runs, in a
# made-up checkout, so nothing real is fetched or written.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
mkdir -p "$t/bin" "$t/vikix/bin" "$t/vikix/lib" "$t/power"
cp "$here/bin/vikix-firmware" "$t/vikix/bin/"
cp "$here/lib/common.sh" "$t/vikix/lib/"
log="$t/log"
printf '#!/bin/sh\necho "updates-check" >> %s\n' "$log" > "$t/vikix/bin/vikix-updates"
chmod +x "$t/vikix/bin/vikix-updates"
cat > "$t/bin/fwupdmgr" <<EOF
#!/bin/sh
echo "fwupdmgr \$*" >> $log
json=\${FWUPD_JSON:-}
[ -n "\$json" ] || json='{"Devices": [{}, {}]}'
case "\$*" in *get-updates*--json*) echo "\$json" ;; esac
EOF
chmod +x "$t/bin/fwupdmgr"
export PATH="$t/bin:$PATH" VIKIX_POWER_SUPPLY="$t/power" HOME="$t/home"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
fw() { : > "$log"; bash "$t/vikix/bin/vikix-firmware" "$@"; }

# power SUPPLY TYPE ONLINE — a made-up power supply
power() { mkdir -p "$t/power/$1"; echo "$2" > "$t/power/$1/type"; echo "$3" > "$t/power/$1/online"; }

# --- on battery: refused ------------------------------------------------------------
power BAT0 Battery 0
power AC Mains 0
if fw update >/dev/null 2>&1; then echo "FAIL: an update on battery should be refused"; fail=1; fi
check "on battery, fwupd shouldn't be asked to update" test -z "$(grep 'update' "$log" | grep -v get-updates || true)"

# --- on the charger: installs, then refreshes the bar ------------------------------
power AC Mains 1
fw update >/dev/null 2>&1 || true
sleep 0.3                        # the bar's check runs in the background
check "on the charger, the list should be fetched first" grep -qx 'fwupdmgr --no-unreported-check refresh' "$log"
check "on the charger, fwupd should be asked to update" grep -qx 'fwupdmgr --no-unreported-check update' "$log"
check "after updating, the bar's count should be checked again" grep -qx 'updates-check' "$log"

# --- a desktop: no battery, no charger reported -----------------------------------
rm -rf "$t/power"; mkdir -p "$t/power"
fw update >/dev/null 2>&1 || true
check "with no battery at all, an update should go ahead" grep -qx 'fwupdmgr --no-unreported-check update' "$log"

# --- looking, and counting for the bar ------------------------------------------------
fw >/dev/null 2>&1
check "vikix firmware should fetch the list, then show updates" \
  test "$(cat "$log")" = "$(printf 'fwupdmgr --no-unreported-check refresh\nfwupdmgr --no-unreported-check get-updates')"
check "two devices with updates should count 2" test "$(fw count)" = 2
check "none should count 0" test "$(FWUPD_JSON='{"Devices": []}' fw count)" = 0
check "an answer it can't read should count ?" test "$(FWUPD_JSON='oops' fw count)" = '?'
rm "$t/bin/fwupdmgr"
check "without fwupd the count should be 0" test "$(fw count)" = 0
if fw update >/dev/null 2>&1; then echo "FAIL: without fwupd, update should say it's missing"; fail=1; fi

[ "$fail" = 0 ] && echo "firmware: installs only on mains power; fetches the list first; counts updates for the bar"
exit "$fail"
