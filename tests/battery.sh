#!/usr/bin/env bash
# tests/battery.sh — the low-battery warner warns once at 15%, once more
# at 5%, and again only after the charger has been plugged in.
#
# It runs the real loop in bin/vikix-battery against a fake battery
# (VIKIX_POWER_SUPPLY). A fake `sleep` moves the battery to its next
# state instead of waiting a minute, and a fake `notify-send` writes the
# warnings down. Nothing is shown on screen.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/power/BAT0" "$t/bin"
touch "$t/warnings"

# The battery's states, one per minute: capacity and status.
cat > "$t/states" <<'EOF'
50 Discharging
14 Discharging
13 Discharging
5 Discharging
4 Discharging
4 Charging
40 Charging
14 Discharging
EOF

# notify-send's last two arguments are the title and the text.
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
while [ \$# -gt 2 ]; do shift; done
echo "\$1" >> "$t/warnings"
EOF

# sleep: the battery moves to its next state; after the last, the warner
# stops. With SIGPIPE, the one signal bash doesn't report as "Terminated".
cat > "$t/bin/sleep" <<EOF
#!/bin/sh
step=\$((\$(cat "$t/step") + 1))
state=\$(sed -n "\${step}p" "$t/states")
if [ -z "\$state" ]; then kill -PIPE "\$PPID"; exit 0; fi
echo "\$step" > "$t/step"
echo "\${state% *}" > "$t/power/BAT0/capacity"
echo "\${state#* }" > "$t/power/BAT0/status"
EOF
chmod +x "$t/bin/notify-send" "$t/bin/sleep"
echo 0 > "$t/step"
"$t/bin/sleep"          # the first state

PATH="$t/bin:$PATH" VIKIX_POWER_SUPPLY="$t/power" timeout 20 sh "$here/bin/vikix-battery" || true

expected="Battery at 14%
Battery at 5%
Battery at 14%"
if [ "$(cat "$t/warnings")" = "$expected" ]; then
  echo "battery: warns at 15% and 5%, once each, and again after charging"
else
  echo "FAIL: the warnings were:"
  sed 's/^/  /' "$t/warnings"
  echo "expected:"
  sed 's/^/  /' <<<"$expected"
  exit 1
fi
