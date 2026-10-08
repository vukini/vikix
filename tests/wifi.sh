#!/usr/bin/env bash
# tests/wifi.sh — vikix-wifi, the Wi-Fi picker that scans first.
#
#   the list: one line a network, strongest first after the one in use,
#   saved and open ones marked, a hidden one left out, a colon in a name
#   kept; the picker scans first every time, waiting five seconds at most,
#   the line over the list says when NetworkManager last scanned, and
#   "Scan again" scans once more;
#   a saved network joins by its connection, an open one straight away, a
#   new one asks its password in rofi and hands it over in a file (0600,
#   gone after), never on the command line, and a refused password leaves
#   nothing saved; WEP and a company login go to nmtui; Disconnect is
#   offered only when connected; no Wi-Fi device says so; list prints
#   without a menu
#
# nmcli, dbus-send, rofi, notify-send and the terminal are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME" "$t/bin" "$t/run"; chmod 700 "$t/run"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
log="$t/log"

# nmcli: the networks from $t/aps (nmcli -t's shape), the saved connections
# from $t/saved (NAME, then its ssid on the next line), every other call
# logged; a connect fails while $t/refuse is there.
cat > "$t/bin/nmcli" <<EOF
#!/bin/sh
echo "nmcli \$*" >> "$log"
case "\$*" in
  *"device wifi list --rescan yes"*) [ -e "$t/slow" ] && exec sleep 30; [ -e "$t/no-wifi" ] && exit 0; cat "$t/aps" ;;
  *"device wifi list"*) [ -e "$t/no-wifi" ] && exit 0; cat "$t/aps" ;;
  "-t -f DEVICE,TYPE,DBUS-PATH device") [ -e "$t/no-wifi" ] || echo 'wlp4s0:wifi:/org/freedesktop/NetworkManager/Devices/3'; echo 'lo:loopback:/org/freedesktop/NetworkManager/Devices/1' ;;
  "-t -f NAME,TYPE connection show") awk 'NR%2==1{print \$0":802-11-wireless"}' "$t/saved" ;;
  "-g 802-11-wireless.ssid connection show "*) name=\${*#-g 802-11-wireless.ssid connection show }; awk -v n="\$name" 'NR%2==1&&\$0==n{getline; print}' "$t/saved" ;;
  "connection up "*) [ -e "$t/refuse" ] && { echo "Error: Connection activation failed: Secrets were required, but not provided." >&2; exit 4; }
    case "\$*" in *passwd-file*) f=\${*##* }; cp "\$f" "$t/password-file"; stat -c %a "\$f" > "$t/password-mode" ;; esac ;;
  "connection add "*) printf '%s\n%s\n' "\$5" "\$9" >> "$t/saved" ;;
  "connection delete "*) name=\${*#connection delete }; awk -v n="\$name" 'NR%2==1&&\$0==n{getline; next} {print}' "$t/saved" > "$t/saved.new"; mv "$t/saved.new" "$t/saved" ;;
  "device wifi connect "*) [ -e "$t/refuse" ] && { echo "Error: no such network" >&2; exit 10; } ;;
esac
exit 0
EOF
# dbus-send: LastScan in ms of uptime, from $t/lastscan.
cat > "$t/bin/dbus-send" <<EOF
#!/bin/sh
echo "dbus-send LastScan" >> "$log"
printf 'method return time=1.0 sender=:1.10 -> destination=:1.5 serial=1 reply_serial=2\n   variant       int64 %s\n' "\$(cat "$t/lastscan")"
EOF
# rofi: the lines offered are kept; the answer is \$t/answer (a line number,
# or the password), none closes it.
cat > "$t/bin/rofi" <<EOF
#!/bin/sh
echo "rofi \$*" >> "$log"
cat > "$t/offered"
case "\$*" in *-password*) [ -s "$t/password" ] || exit 1; cat "$t/password"; exit 0 ;; esac
[ -s "$t/answer" ] || exit 1
head -1 "$t/answer"; sed -i 1d "$t/answer"
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
echo "notify \$*" >> "$log"
case "\$*" in *-p*) echo 9 ;; esac
EOF
cat > "$t/bin/term" <<EOF
#!/bin/sh
echo "term \$*" >> "$log"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_NMCLI="$t/bin/nmcli" VIKIX_DBUS_SEND="$t/bin/dbus-send" VIKIX_UPTIME="$t/uptime" VIKIX_TERMINAL="$t/bin/term"
echo '1000.00 2000.00' > "$t/uptime"
echo 990000 > "$t/lastscan"            # 10 s ago
# IN-USE:SIGNAL:SECURITY:SSID, as nmcli -t writes them (\: for a colon).
cat > "$t/aps" <<'EOF'
*:82:WPA2:LIVING ROOM
 :75:WPA2:LIVING ROOM
 :55:WPA1 WPA2:VID
 :49:WPA2:Mrs KINI\: BDRM
 :30::Open Cafe
 :90:WPA2:
 :20:WPA2 802.1X:Office
 :22:WEP:Old Router
EOF
printf '%s\n' 'LIVING ROOM' 'LIVING ROOM' 'home-5' 'VID' > "$t/saved"
wifi() { : > "$log"; : > "$t/offered"; bash "$here/bin/vikix-wifi" "$@"; }
offered() { cat "$t/offered"; }

# The list: in use first, then by signal; marks; the hidden one out; a colon kept.
out=$(wifi list)
check "the one in use should come first, marked: $out" test "$(sed -n 1p <<<"$out")" = '▂▄▆█  82%  LIVING ROOM  (in use)'
check "a saved one should say so: $out" grep -qx '▂▄▆   55%  VID  (saved)' <<<"$out"
check "an open one should say so: $out" grep -qx '▂▄    30%  Open Cafe  (open)' <<<"$out"
check "a colon in a name should be kept: $out" grep -q 'Mrs KINI: BDRM$' <<<"$out"
check "a hidden network should be left out: $out" test "$(wc -l <<<"$out")" = 6
check "list should ask nothing to scan: $(cat "$log")" test -z "$(grep -- '--rescan yes' "$log" || true)"

# A scan first, every time, waited for, and said; then the list, with the
# scan's age as NetworkManager tells it.
echo 999000 > "$t/lastscan"            # 1 s ago: the scan just made
: > "$t/answer"
wifi || true
check "the picker should scan first: $(cat "$log")" grep -q -- 'device wifi list --rescan yes' "$log"
check "the scan should be said: $(cat "$log")" grep -q 'Scanning for networks' "$log"
check "the scan should come before the list: $(cat "$log")" grep -q -- '--rescan yes' <<<"$(grep -e '--rescan yes' -e '^rofi' "$log" | head -1)"
check "after the scan the menu should say just now: $(cat "$log")" grep -q 'mesg Scanned just now' "$log"
check "the menu should end with Scan again, Disconnect and nmtui: $(offered)" test "$(tail -3 "$t/offered" | tr '\n' '|')" = 'Scan again|Disconnect from LIVING ROOM|Everything else (nmtui)|'
echo 900000 > "$t/lastscan"            # 100 s ago: NetworkManager refused the scan
wifi || true
check "a scan that didn't happen should show as its age: $(cat "$log")" grep -q 'mesg Scanned 100 s ago' "$log"
echo -1 > "$t/lastscan"
wifi || true
check "never scanned should still scan, and say so: $(cat "$log")" grep -q -- '--rescan yes' "$log"
check "never scanned should be said: $(cat "$log")" grep -q 'mesg Not scanned yet' "$log"
echo 999000 > "$t/lastscan"
# A scan that goes on: five seconds at most, then the list as it is.
touch "$t/slow"
SECONDS=0; wifi || true; took=$SECONDS
rm -f "$t/slow"
check "a long scan should be given up after five seconds, not $took" test "$took" -ge 4 -a "$took" -le 9
check "and the list shown all the same: $(offered)" grep -q 'LIVING ROOM' "$t/offered"
check "the scan's wait should be said: $(cat "$log")" grep -q '5 seconds at most' "$log"
printf '6\n' > "$t/answer"             # Scan again (6 networks: 0-5), then closed
wifi || true
check "Scan again should scan once more: $(cat "$log")" test "$(grep -c -- '--rescan yes' "$log")" = 2
check "and show the list again: $(grep -c '^rofi' "$log")" test "$(grep -c '^rofi' "$log")" = 2

# Joining: saved by its connection; the one in use left alone; open at once.
printf '1\n' > "$t/answer"             # VID, saved as home-5
wifi || true
check "a saved network should join by its connection: $(cat "$log")" grep -q '^nmcli connection up home-5$' "$log"
check "joining should be said: $(cat "$log")" grep -q 'notify.*On VID' "$log"
printf '0\n' > "$t/answer"
wifi || true
check "the one in use should be left alone: $(cat "$log")" test -z "$(grep 'connection up' "$log" || true)"
printf '3\n' > "$t/answer"             # Open Cafe
wifi || true
check "an open network should join at once: $(cat "$log")" grep -q '^nmcli device wifi connect Open Cafe$' "$log"
check "an open network should be said to be open: $(cat "$log")" grep -q 'nothing is private' "$log"

# A new network: the password asked, handed over in a file, nothing on the command line.
printf '2\n' > "$t/answer"; printf 'secret pass\n' > "$t/password"
wifi || true
check "a new network should ask for its password: $(cat "$log")" grep -q 'rofi.*-password.*Password for Mrs KINI: BDRM' "$log"
check "the connection should be added with its key management: $(cat "$log")" grep -q 'connection add type wifi con-name Mrs KINI: BDRM ifname wlp4s0 ssid Mrs KINI: BDRM wifi-sec.key-mgmt wpa-psk' "$log"
check "the password should go through a file: $(cat "$t/password-file" 2>/dev/null)" test "$(cat "$t/password-file" 2>/dev/null)" = '802-11-wireless-security.psk:secret pass'
check "the file should be yours alone: $(cat "$t/password-mode" 2>/dev/null)" test "$(cat "$t/password-mode" 2>/dev/null)" = 600
check "the password should never be on a command line" test -z "$(grep 'secret pass' "$log" || true)"
check "the file should be gone after" test -z "$(find "$t/run" -name 'vikix-wifi.*')"
check "joining should be said, and saved: $(cat "$log")" grep -q 'On Mrs KINI: BDRM saved' "$log"
# Refused: said, and nothing kept, so the next try asks afresh.
touch "$t/refuse"; printf '2\n' > "$t/answer"
wifi || true
check "a refused password should be said: $(cat "$log")" grep -q "Couldn't join Mrs KINI: BDRM.*Secrets were required.*Nothing saved" "$log"
check "a refused password should leave nothing saved: $(cat "$t/saved")" test -z "$(grep 'Mrs KINI' "$t/saved" || true)"
rm -f "$t/refuse"
# Escape at the password: nothing done.
: > "$t/password"; printf '2\n' > "$t/answer"
wifi || true
check "Escape at the password should do nothing: $(cat "$log")" test -z "$(grep 'connection add' "$log" || true)"
printf 'x\n' > "$t/password"

# The ones a password can't join go to nmtui; so does "Everything else".
printf '5\n' > "$t/answer"             # Office, 802.1X (weakest)
wifi || true
check "a company login should go to nmtui: $(cat "$log")" grep -q 'term --class vikix-nmtui -e nmtui' "$log"
check "and say why: $(cat "$log")" grep -q 'Office needs more than a password' "$log"
printf '4\n' > "$t/answer"             # Old Router, WEP
wifi || true
check "WEP should go to nmtui: $(cat "$log")" grep -q 'nmtui' "$log"
printf '8\n' > "$t/answer"             # Everything else
wifi || true
check "Everything else should open nmtui: $(cat "$log")" grep -q 'term --class vikix-nmtui -e nmtui' "$log"

# Disconnect: only while connected.
printf '7\n' > "$t/answer"
wifi || true
check "Disconnect should disconnect the device: $(cat "$log")" grep -q '^nmcli device disconnect wlp4s0$' "$log"
sed -i 's/^\*/ /' "$t/aps"
: > "$t/answer"
wifi || true
check "not connected, the menu shouldn't offer Disconnect: $(offered)" test -z "$(grep Disconnect "$t/offered" || true)"
check "not connected, nothing comes first by use: $(offered)" test "$(sed -n 1p "$t/offered")" = '▂▄▆█  82%  LIVING ROOM  (saved)'
printf '7\n' > "$t/answer"             # the last line is now nmtui
wifi || true
check "the last line should still be nmtui: $(cat "$log")" grep -q 'nmtui' "$log"

# No Wi-Fi device: said; list prints nothing.
touch "$t/no-wifi"
wifi || true
check "without Wi-Fi it should say so: $(cat "$log")" grep -q 'No Wi-Fi here' "$log"
check "without Wi-Fi list should print nothing" test -z "$(wifi list)"

[ "$fail" = 0 ] && echo "wifi: the networks scanned first and listed with their signal, saved and in use, joined by Enter, a new one's password through a file, the rest to nmtui"
exit "$fail"
