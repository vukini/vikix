#!/usr/bin/env bash
# tests/notifications.sh — vikix-notifications lists dunst's history
# newest first, and the one picked is the one shown again.
#
# A fake dunstctl holds two notifications; a fake rofi picks line 2.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin"

cat > "$t/bin/dunstctl" <<FAKE
#!/bin/sh
case "\$1" in
  history) cat <<'JSON'
{"type": "aa{sv}", "data": [[
 {"id": {"type": "i", "data": 7}, "timestamp": {"type": "x", "data": 1000000},
  "appname": {"type": "s", "data": "Mail"}, "summary": {"type": "s", "data": "Older"},
  "body": {"type": "s", "data": "first\\nline"}},
 {"id": {"type": "i", "data": 9}, "timestamp": {"type": "x", "data": 2000000},
  "appname": {"type": "s", "data": "Vikix"}, "summary": {"type": "s", "data": "Newer"},
  "body": {"type": "s", "data": ""}}
]]}
JSON
  ;;
  history-pop) echo "\$2" > "$t/popped" ;;
esac
FAKE
cat > "$t/bin/rofi" <<FAKE
#!/bin/sh
cat > "$t/shown"
echo 1          # -format i: the second line, counted from 0
FAKE
chmod +x "$t/bin/dunstctl" "$t/bin/rofi"

PATH="$t/bin:$PATH" sh "$here/bin/vikix-notifications"
fail=0
first=$(sed -n 1p "$t/shown")
case $first in *"Vikix: Newer") ;; *) echo "FAIL: the newest isn't first: $first"; fail=1 ;; esac
case $(sed -n 2p "$t/shown") in *"Mail: Older — first line") ;; *) echo "FAIL: the body isn't on one line: $(sed -n 2p "$t/shown")"; fail=1 ;; esac
[ "$(cat "$t/popped" 2>/dev/null)" = 7 ] || { echo "FAIL: picking line 2 showed id $(cat "$t/popped" 2>/dev/null), not 7"; fail=1; }
[ "$fail" = 0 ] && echo "notifications: history listed newest first; the one picked is shown again"
exit "$fail"
