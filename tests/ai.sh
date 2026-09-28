#!/usr/bin/env bash
# tests/ai.sh — `vikix ai key`: a key is kept safely and never shown.
#
#   set      keeps the key (trimmed) in ~/.config/vikix/secrets/NAME, the
#            folder 700 and the file 600, and never prints it; names map
#            (anthropic -> ANTHROPIC_API_KEY); a bad name or no key is refused
#   list     shows names, never values; remove forgets one
#   export   lib/secrets.sh exports the keys in sh and bash, skipping files
#            that can't be a variable's name; vikix.bash does it for shells;
#            vikix-session loads them with its log's trace off, so the keys
#            never reach session.log
#   check    finds a key in your files (the file and line, never the key),
#            and in the history of your files, and is quiet once the key is
#            moved and the history started again; vikix doctor runs it
#
# All in a made-up home; the snapshot history is the real one (bin/vikix).

set -euo pipefail
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
lacks() { ! grep -qF -- "$1" <<<"$2"; }
ai() { bash "$here/bin/vikix-ai" "$@"; }
secrets="$HOME/.config/vikix/secrets"
key='sk-ant-api03-TESTKEYabcdefghijklmnopqrstuvwxyz0123'

# --- set, list, remove -----------------------------------------------------------
out=$(printf '  %s \n' "$key" | ai key set anthropic 2>&1)
check "set didn't keep ANTHROPIC_API_KEY" test -f "$secrets/ANTHROPIC_API_KEY"
check "the key wasn't kept exactly (trimmed)" test "$(cat "$secrets/ANTHROPIC_API_KEY")" = "$key"
check "the key file should be 600, is $(stat -c %a "$secrets/ANTHROPIC_API_KEY")" test "$(stat -c %a "$secrets/ANTHROPIC_API_KEY")" = 600
check "the secrets folder should be 700, is $(stat -c %a "$secrets")" test "$(stat -c %a "$secrets")" = 700
check "set printed the key" lacks "$key" "$out"
check "set should warn that Claude Code would bill the key" grep -q 'bills the key' <<<"$out"
out=$(printf 'abc123def456\n' | ai key set open-router 2>&1)
check "open-router should become OPEN_ROUTER_API_KEY" test -f "$secrets/OPEN_ROUTER_API_KEY"
out=$(printf 'nope\n' | ai key set anthropic 2>&1)
check "a key without sk-ant- should be kept, with a warning: $out" grep -q "doesn't start with sk-ant-" <<<"$out"
printf '%s' "$key" | ai key set anthropic >/dev/null 2>&1
ai key set 'bad name' </dev/null >/dev/null 2>&1 && { echo "FAIL: a name with a space was accepted"; fail=1; }
printf '\n' | ai key set openai >/dev/null 2>&1 && { echo "FAIL: an empty key was accepted"; fail=1; }
check "a refused key still left a file" test ! -e "$secrets/OPENAI_API_KEY"

out=$(ai key list)
check "list doesn't name ANTHROPIC_API_KEY" grep -q '^ANTHROPIC_API_KEY ' <<<"$out"
check "list showed a key's value" lacks "$key" "$out"
ai key remove open-router >/dev/null
check "remove didn't forget OPEN_ROUTER_API_KEY" test ! -e "$secrets/OPEN_ROUTER_API_KEY"

# --- export ------------------------------------------------------------------------------
printf 'x' > "$secrets/not-a-variable"
got=$(sh -c ". '$here/lib/secrets.sh'; printf '%s' \"\$ANTHROPIC_API_KEY\"")
check "lib/secrets.sh didn't export the key in sh" test "$got" = "$key"
got=$(bash --norc -ic ". '$here/config/bash/vikix.bash' 2>/dev/null; printf '%s' \"\$ANTHROPIC_API_KEY\"" 2>/dev/null)
check "vikix.bash didn't export the key in a shell" test "$got" = "$key"
rm "$secrets/not-a-variable"
# In vikix-session, the trace (set -x, into session.log) is off where the
# keys load: every line from `set +x` to the source of secrets.sh, and it's on again after.
check "vikix-session loads the keys with its trace on, which would log them" \
  awk '/set \+x/ { off = 1 } /secrets\.sh"$/ && /^\. / { if (!off) bad = 1; seen = 1 } /^set -x/ && seen { off = 0 }
       END { exit (bad || !seen) }' "$here/bin/vikix-session"

# --- check -----------------------------------------------------------------------------------
vikix() { bash "$here/bin/vikix" "$@" >/dev/null 2>&1; }
printf 'alias ll="ls -l"\nexport ANTHROPIC_API_KEY=%s\n' "$key" > "$HOME/.bashrc"
# Not keys: sk- inside a word, and a file the snapshots leave out.
mkdir -p "$HOME/.stumpwm.d/modules/disk"
printf '(defun disk-get-usage-of-mounted-filesystems ())\n' > "$HOME/.stumpwm.d/user.lisp"
printf 'sk-ant-api03-%s\n' 'NOTINASNAPSHOTabcdefghijk' > "$HOME/.stumpwm.d/modules/disk/disk.lisp"
vikix snapshot "with a key in .bashrc"
out=$(ai key check 2>&1) && { echo "FAIL: check passed with a key in .bashrc"; fail=1; }
check "check should say where the key is: $out" grep -q 'in ~/.bashrc, line 2' <<<"$out"
check "disk-get-usage-... isn't a key: $out" lacks 'user.lisp' "$out"
check "a file the snapshots leave out (~/.stumpwm.d/modules) was searched: $out" lacks 'modules' "$out"
check "check should find it in the history too" grep -q 'in the history of your files' <<<"$out"
check "check printed the key" lacks "$key" "$out"
check "check printed part of the key" lacks 'TESTKEY' "$out"

# Moved: the file is clean, the history still isn't.
printf 'alias ll="ls -l"\nexport ANTHROPIC_API_KEY="$(cat ~/.config/vikix/secrets/ANTHROPIC_API_KEY)"\n' > "$HOME/.bashrc"
vikix snapshot "key moved"
out=$(ai key check 2>&1) && { echo "FAIL: check passed with the key still in the history"; fail=1; }
check "a line reading the key from secrets shouldn't count as a key: $out" lacks 'in ~/.bashrc' "$out"
check "the history should still be named" grep -q 'in the history' <<<"$out"
# Started again, as check says: all clear.
mv "$VIKIX_STATE/yours.git" "$VIKIX_STATE/yours.git.with-key"
vikix snapshot "a fresh start"
out=$(ai key check 2>&1) || { echo "FAIL: check still complains after the fix it gave:"; echo "$out" | sed 's/^/  /'; fail=1; }

chmod 644 "$secrets/ANTHROPIC_API_KEY"
out=$(ai key check 2>&1) && { echo "FAIL: a key others can read went unnoticed"; fail=1; }
check "check should say others can read the keys" grep -q 'others can read' <<<"$out"
chmod 600 "$secrets/ANTHROPIC_API_KEY"

printf 'export OPENAI_API_KEY=sk-proj-%s\n' 'abcdefghijklmnopqrstuvwxyz' >> "$HOME/.bashrc"
out=$(bash "$here/bin/vikix" doctor 2>&1) || true
check "vikix doctor doesn't look for keys in your files" grep -q 'looks like an API key, in ~/.bashrc' <<<"$out"

[ "$fail" = 0 ] && echo "ai: keys are kept 600 in a 700 folder, exported, never shown or logged, and found where they shouldn't be"
exit "$fail"
