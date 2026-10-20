#!/usr/bin/env bash
# tests/ledger.sh — the outbound ledger (vikix ledger), in a made-up home:
# `on` puts the log rule into made-up after.rules and after6.rules before
# their COMMIT, once (a second `on` doesn't double it), and `off` takes it
# out; the watcher reads a made-up kernel log through, names each
# connection's program through a stand-in `ss` and /proc (an agent's child
# is said to be the agent's), folds the day's connections by program,
# destination and port with a count and the first and last time, and
# writes them to the records store, the same again replacing rather than
# doubling; the page says it by program, a private destination as this
# network's, a program gone before it was named as "?"; status and the
# watcher that isn't on both stop at once.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'kill $(cat "$t/pids" 2>/dev/null) 2>/dev/null; rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

export HOME="$t/home" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME" "$t/run" "$t/ufw" "$t/bin"
export VIKIX_LEDGER_RULES_DIR="$t/ufw" VIKIX_LEDGER_SUDO="" VIKIX_LEDGER_NO_NAMES=1
vl() { python3 "$here/bin/vikix-ledger" "$@"; }
vr() { python3 "$here/bin/vikix-records" "$@"; }

# --- the rule ---------------------------------------------------------------------
printf '*filter\n:ufw-after-input - [0:0]\n:ufw-after-output - [0:0]\n-A ufw-after-input -p udp --dport 137 -j ufw-skip-to-policy-input\nCOMMIT\n' > "$t/ufw/after.rules"
printf '*filter\n:ufw6-after-output - [0:0]\nCOMMIT\n' > "$t/ufw/after6.rules"
check "status before on doesn't say off" grep -q '^the ledger is off' <<<"$(vl status || true)"
vl on >/dev/null 2>&1 || { echo "FAIL: on failed"; fail=1; }
check "the rule isn't in after.rules" grep -q -- '-A ufw-after-output ! -o lo -m conntrack --ctstate NEW .* -j LOG --log-prefix "\[VIKIX OUT\] " --log-uid' "$t/ufw/after.rules"
check "the rule isn't before COMMIT" test "$(grep -n -E 'vikix ledger <<<|^COMMIT' "$t/ufw/after.rules" | cut -d: -f2 | tr '\n' ' ')" = "# <<< vikix ledger <<< COMMIT "
check "ufw's own rule was lost" grep -q 'dport 137' "$t/ufw/after.rules"
check "the IPv6 file didn't get its rule" grep -q -- '-A ufw6-after-output ! -o lo' "$t/ufw/after6.rules"
check "the setting doesn't say on" grep -qx 'on=yes' "$HOME/.config/vikix/ledger"
vl on >/dev/null 2>&1
check "a second on doubled the rule" test "$(grep -c 'vikix ledger >>>' "$t/ufw/after.rules")" = 1
printf '*filter\nCOMMIT\n' > "$t/ufw/after6.rules"
if VIKIX_LEDGER_RULES_DIR="$t/ufw" vl on >/dev/null 2>&1; then echo "FAIL: on took a rules file without ufw's chain"; fail=1; fi
printf '*filter\n:ufw6-after-output - [0:0]\nCOMMIT\n' > "$t/ufw/after6.rules"; vl on >/dev/null 2>&1

# --- the watcher, on a made-up log -------------------------------------------------
# A process named claude with a child: the socket's owner, so the connection is an agent's.
printf '#!/bin/sh\nsleep 300 &\necho $! > "%s/child"\necho $$ >> "%s/pids"\necho $! >> "%s/pids"\nwait\n' "$t" "$t" "$t" > "$t/bin/claude"
chmod +x "$t/bin/claude"
"$t/bin/claude" & sleep 0.5
child=$(cat "$t/child")
# ss: the sockets by local port; 40000 (a DNS query) is already gone.
printf '#!/bin/sh\ncat <<S\ntcp ESTAB 0 0 192.168.10.151:50806 160.79.104.10:443 users:(("sleep",pid=%s,fd=17))\ntcp ESTAB 0 0 192.168.10.151:50807 10.0.0.5:22 users:(("bash",pid=%s,fd=3))\nS\n' "$child" "$$" > "$t/bin/ss"
chmod +x "$t/bin/ss"
export PATH="$t/bin:$PATH"
day=$(date +%Y-%m-%d)
utc() { date -u -d "@$(date -d "$day $1" +%s)" +%Y-%m-%dT%H:%M:%S; }   # a time here, as the log writes it (UTC)
u1=$(utc 09:12:00)
u2=$(utc 09:40:00)
{
  echo "$u1.12345 kern.info: [1.0] [VIKIX OUT] IN= OUT=wlp0 SRC=192.168.10.151 DST=160.79.104.10 LEN=60 PROTO=TCP SPT=50806 DPT=443 WINDOW=64240 SYN URGP=0 UID=1000 GID=1000"
  echo "$u1.22345 kern.warn: [1.1] [UFW BLOCK] IN=wlp0 OUT= SRC=1.2.3.4 DST=192.168.10.151 PROTO=TCP SPT=1 DPT=22"
  echo "$u2.32345 kern.info: [1.2] [VIKIX OUT] IN= OUT=wlp0 SRC=192.168.10.151 DST=160.79.104.10 LEN=60 PROTO=TCP SPT=50806 DPT=443 WINDOW=64240 SYN URGP=0 UID=1000 GID=1000"
  echo "$u2.42345 kern.info: [1.3] [VIKIX OUT] IN= OUT=wlp0 SRC=192.168.10.151 DST=192.168.10.1 LEN=70 PROTO=UDP SPT=40000 DPT=53 LEN=50 UID=1000 GID=1000"
  echo "$u2.52345 kern.info: [1.4] [VIKIX OUT] IN= OUT=wlp0 SRC=192.168.10.151 DST=10.0.0.5 LEN=60 PROTO=TCP SPT=50807 DPT=22 WINDOW=64240 SYN URGP=0 UID=1000 GID=1000"
  echo "not a log line at all"
} > "$t/kernel.log"
vl watch --log "$t/kernel.log" --once 2>"$t/watch.err" || { echo "FAIL: the watcher failed: $(cat "$t/watch.err")"; fail=1; }
recs=$(vr list ledger --kind connection --json)
count() { python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$1"; }
check "three connections weren't recorded ($(count "$recs"))" test "$(count "$recs")" = 3
field() { python3 -c 'import json,sys; rs=json.load(sys.stdin); r=[r for r in rs if r["data"]["dst"]==sys.argv[1]][0]; print(r["data"][sys.argv[2]])' "$1" "$2" <<<"$recs"; }
check "the agent's connection isn't counted twice" test "$(field 160.79.104.10 count)" = 2
check "its program isn't the socket's" test "$(field 160.79.104.10 program)" = sleep
check "it isn't known as claude's" test "$(field 160.79.104.10 agent)" = claude
check "the first time isn't 09:12: $(date -d "@$(field 160.79.104.10 first)" +%H:%M), from $u1" test "$(date -d "@$(field 160.79.104.10 first)" +%H:%M)" = 09:12
check "the last time isn't 09:40: $(date -d "@$(field 160.79.104.10 last)" +%H:%M)" test "$(date -d "@$(field 160.79.104.10 last)" +%H:%M)" = 09:40
check "the DNS query's program isn't ?" test "$(field 192.168.10.1 program)" = "?"
check "the DNS query lost its port" test "$(field 192.168.10.1 port) $(field 192.168.10.1 proto)" = "53 udp"
check "ssh to this network isn't marked private" test "$(field 10.0.0.5 private)" = True
check "bash's folder isn't recorded" test "$(field 10.0.0.5 folder)" = "$PWD"
vl watch --log "$t/kernel.log" --once 2>/dev/null
recs=$(vr list ledger --kind connection --json)
check "the same log again doubled the records" test "$(count "$recs")" = 3
check "or the count" test "$(field 160.79.104.10 count)" = 2

# --- the page ------------------------------------------------------------------------
page=$(vl "$day")
check "the page's head line is wrong: $(head -1 <<<"$page")" grep -q '^What left this laptop today: 4 connections from 3 programs, to 3 places\.' <<<"$page"
check "the agent's program isn't said to be claude's" grep -qE "^sleep  \(an agent's: claude" <<<"$page"
check "the agent's line is wrong: $(grep '160.79' <<<"$page")" grep -qE '^ +2  160\.79\.104\.10:443 tcp  09:12–09:40$' <<<"$page"
check "this network's isn't marked" grep -q '10.0.0.5 (this network):22 tcp' <<<"$page"
check "the gone program isn't explained" grep -q '^?  (gone before it could be named; uid 1000)' <<<"$page"
check "today and the date aren't the same page" test "$(vl today)" = "$page"
check "a program's days aren't listed" grep -q "^sleep: on 1 day, newest first" <<<"$(vl sleep)"
check "--json doesn't carry the connections" test "$(vl --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["connections"]), d["on"])')" = "3 True"
check "yesterday isn't empty" grep -q '^Nothing left this machine yesterday' <<<"$(vl yesterday)"
check "status doesn't count today" grep -q '^today: 4 connections from 3 programs' <<<"$(vl status || true)"

# --- off -------------------------------------------------------------------------------
vl off >/dev/null 2>&1 || { echo "FAIL: off failed"; fail=1; }
check "off left the rule in" bash -c '! grep -q "vikix ledger" "$1"' _ "$t/ufw/after.rules"
check "off left the IPv6 rule in" bash -c '! grep -q "vikix ledger" "$1"' _ "$t/ufw/after6.rules"
check "off lost ufw's own rule" grep -q 'dport 137' "$t/ufw/after.rules"
check "the setting still says on" grep -qx 'on=no' "$HOME/.config/vikix/ledger"
check "the records went with off" test "$(count "$(vr list ledger --kind connection --json)")" = 3
check "the page doesn't say the ledger is off now" grep -q 'The ledger is off now' <<<"$(vl "$day")"
check "a watcher that isn't on doesn't stop at once" timeout 5 python3 "$here/bin/vikix-ledger" watch
check "--help doesn't show the forms" grep -q 'vikix ledger on' <<<"$(vl --help)"

[ "$fail" = 0 ] && echo "ledger: the rule in and out of ufw's files, the watcher on a made-up log with the programs named, the records folded and replaced, the page by program, status"
exit "$fail"
