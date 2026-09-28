#!/usr/bin/env bash
# tests/debug.sh — vikix debug and vikix diagnose.
#
#   the report has its sections and the logs' ends, is 600, and keeps out:
#   your stored keys (whatever their shape), key shapes, NAME=value secrets,
#   Bearer tokens, passwords in URLs, the backup password, your home path,
#   user and machine names; progress bars and colours are tidied; diagnose
#   hands the report to your agent with the question (Aider: --read)
#
# Nothing here is a real key. The agent is a stand-in.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$HOME/.local/bin" "$VIKIX_STATE/logs" "$HOME/.config/vikix/secrets"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
lacks() { ! grep -qF -- "$1" "$2"; }

# Secrets, of every kind, planted in the logs.
odd='zz-custom-secret-shape-7Hq2pL9x'          # no known shape: only its value gives it away
ant='sk-ant-api03-AAAAbbbbCCCCddddEEEEffff'
echo "$odd" > "$HOME/.config/vikix/secrets/SOMETHING_API_KEY"
echo "backup-pass-Wq81zz" > "$HOME/.config/vikix/backup-password"
chmod 700 "$HOME/.config/vikix/secrets"; chmod 600 "$HOME/.config/vikix/secrets/SOMETHING_API_KEY"
me=${USER:-$(id -un)}; host=$(hostname 2>/dev/null || cat /etc/hostname)
cat > "$VIKIX_STATE/session.log" <<EOF
starting: the key was $odd, oops
curl -H "Authorization: Bearer abcdefghijklmnop123456" https://api.example.com
export OPENAI_API_KEY=sk-proj-QQQQrrrrSSSSttttUUUUvvvv
GITHUB_TOKEN="plainvalue12345"
DB_PASSWORD: hunter2hunter2
pulling https://someone:pa55word@example.com/repo.git
restic said: backup-pass-Wq81zz
a leaked $ant here
logged in as $me on $host, home $HOME/work
$(printf '\e[31mred error\e[0m')
$(printf 'downloading  10%%\r downloading  50%%\r downloading 100%%')
the end of the session log
EOF
echo "the last install's log" > "$VIKIX_STATE/logs/install-20260101-000000.log"
echo "the last update's log" > "$VIKIX_STATE/logs/update-20260101-000000.log"

out="$t/report.txt"
bash "$here/bin/vikix" debug --out "$out" >/dev/null 2>&1 || { echo "FAIL: vikix debug failed"; fail=1; }
check "the report should be written" test -s "$out"
check "the report should be readable only by you, is $(stat -c %a "$out" 2>/dev/null)" test "$(stat -c %a "$out" 2>/dev/null)" = 600
for s in "## Vikix" "## System" "## vikix doctor" "## The session's log" "## The last install" "## The last update"; do
  check "the report should have '$s'" grep -qF -- "$s" "$out"
done
check "the report should have the session log's end" grep -qF 'the end of the session log' "$out"
check "the report should have the last install's log" grep -qF "the last install's log" "$out"
check "a stored key of no known shape got through" lacks "$odd" "$out"
check "an Anthropic-shaped key got through" lacks "$ant" "$out"
check "an OpenAI key in NAME=value got through" lacks 'sk-proj-QQQQ' "$out"
check "a token in NAME=\"value\" got through" lacks 'plainvalue12345' "$out"
check "a password in NAME: value got through" lacks 'hunter2hunter2' "$out"
check "a Bearer token got through" lacks 'abcdefghijklmnop123456' "$out"
check "a password in a URL got through" lacks 'pa55word' "$out"
check "the backup password got through" lacks 'backup-pass-Wq81zz' "$out"
check "the home path got through" lacks "$HOME" "$out"
check "the user name got through" test -z "$(grep -w -- "$me" "$out" || true)"
check "the machine name got through" test -z "$(grep -w -- "$host" "$out" || true)"
check "what's around a secret should stay: $(grep 'oops' "$out")" grep -qF 'starting: the key was [removed], oops' "$out"
check "the URL should stay, without its password" grep -qF 'https://[removed]@example.com/repo.git' "$out"
# shellcheck disable=SC2088  # the report's literal ~, not a path to expand
check "the home should read ~" grep -qF '~/work' "$out"
check "a progress bar should be its last state" grep -qx ' downloading 100%' "$out"
check "colours should go" test -z "$(grep -c $'\e' "$out" | grep -v '^0$' || true)"

# The default name, in your home.
( cd "$t" && bash "$here/bin/vikix" debug >/dev/null 2>&1 )
check "vikix debug should write ~/vikix-debug-<time>.txt" test -n "$(ls "$HOME"/vikix-debug-*.txt 2>/dev/null)"

# diagnose: your agent, with the question and the report.
cat > "$HOME/.local/bin/claude" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$t/claude.args"
EOF
cat > "$HOME/.local/bin/aider" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$t/aider.args"
EOF
chmod +x "$HOME/.local/bin/claude" "$HOME/.local/bin/aider"
bash "$here/bin/vikix" diagnose >/dev/null 2>&1 || true
check "diagnose should start the agent with the question: $(cat "$t/claude.args" 2>/dev/null)" grep -q "what's wrong and how to fix it" "$t/claude.args"
report=$(grep -o '~\?/[^ ]*vikix-debug-[0-9-]*\.txt\|/[^ ]*vikix-debug-[0-9-]*\.txt' "$t/claude.args" | head -1)
check "the question should name the report" test -n "$report"
ANTHROPIC_API_KEY=x bash "$here/bin/vikix" diagnose --use aider >/dev/null 2>&1 || true
check "aider should get the report to read: $(tr '\n' ' ' < "$t/aider.args" 2>/dev/null)" grep -qx -- '--read' "$t/aider.args"

[ "$fail" = 0 ] && echo "debug: one report, keys and names out, progress bars tidied; diagnose hands it to your agent"
exit "$fail"
