#!/usr/bin/env bash
# tests/firewall.sh — vikix firewall on refuses what comes in, lets
# everything out, always lets SSH in (so turning it on over SSH can't lock
# anyone out), opens LocalSend's port only where LocalSend is, and links the
# runit service; allow and close take only real ports; off and status say
# the right thing; and the migration leaves alone a firewall already on.
#
# ufw is a stand-in that writes its arguments to a log; ufw.conf and the
# runit folders are made up, and nothing runs with sudo.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
mkdir -p "$t/bin" "$t/home" "$t/sv/ufw" "$t/service"
log="$t/log"
conf="$t/ufw.conf"
# The stand-in: logs each call, and keeps ufw.conf's ENABLED as ufw does.
cat > "$t/bin/ufw" <<EOF
#!/bin/sh
echo "\$*" >> "$log"
case "\$*" in
  *enable) echo ENABLED=yes > "$conf" ;;
  disable) echo ENABLED=no > "$conf" ;;
  "status verbose") echo "Status: active" ;;
esac
EOF
chmod +x "$t/bin/ufw"
# Only the system's programs besides the stand-ins: a real LocalSend in
# ~/.local/bin would open its port in every run.
export PATH="$t/bin:/usr/bin:/bin" HOME="$t/home" VIKIX_UFW_CONF="$conf" VIKIX_FIREWALL_SUDO='' \
       VIKIX_SV_DIR="$t/sv" VIKIX_SERVICE_DIR="$t/service" VIKIX_STATE="$t/state"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
fw() { : > "$log"; bash "$here/bin/vikix-firewall" "$@"; }
# Lines of the log in order: the line numbers of each pattern.
line() { grep -n -x -- "$1" "$log" | head -1 | cut -d: -f1; }

# --- on ------------------------------------------------------------------------------
echo ENABLED=no > "$conf"
# ln -s into the made-up service folder needs no root; the stand-in sudo is none.
fw on >/dev/null
check "on should refuse what comes in" grep -qx 'default deny incoming' "$log"
check "and let everything out" grep -qx 'default allow outgoing' "$log"
check "SSH should be let in" grep -qx 'allow 22/tcp comment SSH' "$log"
check "the rules should come before the firewall goes on" \
  test "$(line 'allow 22/tcp comment SSH')" -lt "$(line '--force enable')"
check "without LocalSend, its port should stay shut" test -z "$(grep 53317 "$log" || true)"
check "on should switch it on" grep -qx 'ENABLED=yes' "$conf"
check "and link the runit service, so the rules come back at boot" test -L "$t/service/ufw"
printf '#!/bin/sh\n' > "$t/bin/localsend"; chmod +x "$t/bin/localsend"
fw on >/dev/null
check "with LocalSend, on should let its port in, tcp and udp" grep -qx 'allow 53317 comment LocalSend' "$log"
rm "$t/bin/localsend"

# --- a dry run changes nothing ---------------------------------------------------------
echo ENABLED=no > "$conf"
out=$(DRY_RUN=1 fw on 2>&1)
check "a dry run should only print" test ! -s "$log"
check "and say what it would run" grep -q 'would run: ufw --force enable' <<<"$out"

# --- allow and close ---------------------------------------------------------------------
echo ENABLED=yes > "$conf"
fw allow 8080/tcp web >/dev/null
check "allow should pass the port and its name" grep -qx 'allow 8080/tcp comment web' "$log"
fw allow 53317 >/dev/null
check "allow without a name" grep -qx 'allow 53317' "$log"
fw close 8080/tcp >/dev/null
check "close should delete the rule" grep -qx 'delete allow 8080/tcp' "$log"
for bad in 'ssh; rm -rf ~' '70000x' '6000:6010' '22/icmp' ''; do
  fw allow "$bad" >/dev/null 2>&1 && { echo "FAIL: allow '$bad' should be refused"; fail=1; }
  check "a refused allow ('$bad') should reach no ufw" test ! -s "$log"
done
echo ENABLED=no > "$conf"
out=$(fw allow 6000:6010/udp 2>&1)
check "a range with a protocol is a port" grep -qx 'allow 6000:6010/udp' "$log"
check "allow while off should say the rule waits" grep -q 'vikix firewall on' <<<"$out"

# --- status and off ------------------------------------------------------------------------
out=$(fw 2>&1)
check "status while off should say off, and ask no password" grep -q '^.*off: ' <<<"$out"
check "status while off shouldn't call ufw" test ! -s "$log"
echo ENABLED=yes > "$conf"
out=$(fw 2>&1)
check "status while on should show ufw's rules" grep -q 'Status: active' <<<"$out"
fw off >/dev/null
check "off should disable" grep -qx 'disable' "$log"

# --- the migration ---------------------------------------------------------------------------
# It reads the real /etc/ufw/ufw.conf, so only the case without ufw can run
# here: no ufw on PATH, nothing done, and it still succeeds.
m=$(grep -l 'vikix firewall' "$here"/migrations/*.sh | head -1)
check "there should be a migration that switches the firewall on" test -n "$m"
mkdir -p "$t/noufw"
for c in bash sh grep dirname cat; do ln -sf "$(command -v "$c")" "$t/noufw/$c"; done
: > "$log"
out=$(PATH="$t/noufw" VIKIX_DIR="$here" bash "$m" 2>&1) || { echo "FAIL: the migration should succeed without ufw: $out"; fail=1; }
check "without ufw the migration should change nothing" test ! -s "$log"

[ "$fail" = 0 ] && echo "firewall: on shuts the way in but SSH (and LocalSend where it is), allow and close take only ports"
exit "$fail"
