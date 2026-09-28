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
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
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
check "set should say vikix agent leaves the key out of Claude Code" grep -q 'starts Claude Code without it' <<<"$out"
check "set should show a fingerprint, sk-a…0123 (50 characters): $out" grep -qF 'sk-a…0123 (50 characters)' <<<"$out"
check "a first set should say kept: $out" grep -q 'kept ANTHROPIC_API_KEY' <<<"$out"
out=$(printf '%s\n' "$key" | ai key set anthropic 2>&1)
check "setting it again should say replaced: $out" grep -q 'replaced ANTHROPIC_API_KEY' <<<"$out"
out=$(printf 'sk-or-v1-abcdefghijklmnopqrstuvwxyz\n' | ai key set open-router 2>&1)
check "open-router should become OPENROUTER_API_KEY, the name tools read" test -f "$secrets/OPENROUTER_API_KEY"
out=$(printf 'nope\n' | ai key set anthropic 2>&1)
check "a key without sk-ant- should be kept, with a warning: $out" grep -q "start with sk-ant-, and this one doesn't" <<<"$out"
check "a 4-character key should be called short: $out" grep -q 'only 4 characters' <<<"$out"
printf '%s' "$key" | ai key set anthropic >/dev/null 2>&1
out=$(printf '%s' "$key" | ai key set openai 2>&1) || true
check "an Anthropic key under openai should be pointed out: $out" grep -q 'looks like an Anthropic key' <<<"$out"
ai key remove openai >/dev/null 2>&1 || true

# Names that aren't keys' names are refused, and nothing is kept.
for bad in PATH LD_PRELOAD ANTHROPIC_BASE_URL HOME; do
  printf 'x%.0s' {1..30} | ai key set "$bad" >/dev/null 2>&1 && { echo "FAIL: $bad was accepted as a key's name"; fail=1; }
  check "$bad was kept in secrets" test ! -e "$secrets/$bad"
done
out=$(printf 'x\n' | ai key set antropic 2>&1) && { echo "FAIL: the typo antropic was kept"; fail=1; }
check "antropic should get 'did you mean anthropic': $out" grep -q 'did you mean anthropic' <<<"$out"
out=$(ai key set "$key" </dev/null 2>&1) && { echo "FAIL: a key given as the name was accepted"; fail=1; }
check "a key given as the name should be refused, with shell-history advice: $out" grep -q 'shell history' <<<"$out"
check "a key given as the name was printed back" lacks "$key" "$out"
check "a key given as the name was kept as a file" bash -c "! ls '$secrets' | grep -q TESTKEY"
out=$(ai key set anthropic "$key" </dev/null 2>&1) && { echo "FAIL: a key given after the name was accepted"; fail=1; }
check "a key after the name should be refused: $out" grep -q 'shell history' <<<"$out"
out=$(printf 'hf_abcdefghijklmnopqrstuvwxyz\n' | ai key set huggingface 2>&1)
check "huggingface should become HF_TOKEN" test -f "$secrets/HF_TOKEN"
ai key set 'bad name' </dev/null >/dev/null 2>&1 && { echo "FAIL: a name with a space was accepted"; fail=1; }
printf '\n' | ai key set openai >/dev/null 2>&1 && { echo "FAIL: an empty key was accepted"; fail=1; }
check "a refused key still left a file" test ! -e "$secrets/OPENAI_API_KEY"

printf 'x' > "$secrets/PATH"      # dropped in by something else
out=$(ai key list)
check "list doesn't name ANTHROPIC_API_KEY" grep -q '^ANTHROPIC_API_KEY ' <<<"$out"
check "list should show the fingerprint" grep -qF 'sk-a…0123' <<<"$out"
check "list showed a key's value" lacks "$key" "$out"
check "list should call PATH in there ignored: $out" grep -q '^PATH .*ignored' <<<"$out"
ai key remove open-router >/dev/null
check "remove didn't forget OPENROUTER_API_KEY" test ! -e "$secrets/OPENROUTER_API_KEY"
out=$(ai key remove 2>&1) || true
check "remove with no name should say how, not show a set example: $out" grep -q 'vikix ai key remove NAME' <<<"$out"

# --- export ------------------------------------------------------------------------------
printf 'x' > "$secrets/not-a-variable"
printf '/tmp/evil' > "$secrets/LD_PRELOAD"
printf 'https://evil.example' > "$secrets/ANTHROPIC_BASE_URL"
ln -s /etc/hostname "$secrets/LINKED_API_KEY"
got=$(sh -c ". '$here/lib/secrets.sh'; printf '%s' \"\$ANTHROPIC_API_KEY\"")
check "lib/secrets.sh didn't export the key in sh" test "$got" = "$key"
got=$(sh -c ". '$here/lib/secrets.sh'; printf '%s|%s|%s|%s' \"\$PATH\" \"\${LD_PRELOAD-}\" \"\${ANTHROPIC_BASE_URL-}\" \"\${LINKED_API_KEY-}\"")
check "lib/secrets.sh exported something that isn't a key (PATH, LD_PRELOAD, a base URL, a link): $got" \
  test "$got" = "$PATH|||"
rm "$secrets/PATH" "$secrets/LD_PRELOAD" "$secrets/ANTHROPIC_BASE_URL" "$secrets/LINKED_API_KEY"
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
out=$(ai key check 2>&1) && { echo "FAIL: check was quiet with the old history, key and all, still set aside"; fail=1; }
check "check should point at the old history set aside: $out" grep -q 'yours.git.with-key, the old history' <<<"$out"
rm -rf "$VIKIX_STATE/yours.git.with-key"
out=$(ai key check 2>&1) || { echo "FAIL: check still complains after the fix it gave:"; echo "$out" | sed 's/^/  /'; fail=1; }

chmod 644 "$secrets/ANTHROPIC_API_KEY"
out=$(ai key check 2>&1) && { echo "FAIL: a key others can read went unnoticed"; fail=1; }
check "check should say others can read the keys" grep -q 'others can read' <<<"$out"
chmod 600 "$secrets/ANTHROPIC_API_KEY"

printf 'export OPENAI_API_KEY=sk-proj-%s\n' 'abcdefghijklmnopqrstuvwxyz' >> "$HOME/.bashrc"
out=$(bash "$here/bin/vikix" doctor 2>&1) || true
check "vikix doctor doesn't look for keys in your files" grep -q 'looks like an API key, in ~/.bashrc' <<<"$out"

# --- check: more places, more shapes ---------------------------------------------------
printf 'alias ll="ls -l"\n' > "$HOME/.bashrc"
vikix snapshot "clean again"
mv "$VIKIX_STATE/yours.git" "$VIKIX_STATE/yours.git.old"; vikix snapshot "clean history"; rm -rf "$VIKIX_STATE/yours.git.old"
# ~/.profile isn't in yours.list, but a shell reads it: keys end up there too.
printf 'export PERPLEXITY_API_KEY="pplx-%s"\n' 'abcdefghijklmnopqrstuvwxyz0123' > "$HOME/.profile"
out=$(ai key check 2>&1) && { echo "FAIL: check missed a key in ~/.profile"; fail=1; }
check "check should find the key in ~/.profile: $out" grep -q 'in ~/.profile, line 1' <<<"$out"
check "check should give the exact command, vikix ai key set PERPLEXITY_API_KEY: $out" grep -q 'vikix ai key set PERPLEXITY_API_KEY' <<<"$out"
check "check printed the Perplexity key" lacks 'abcdefghijklmnop' "$out"
rm "$HOME/.profile"
for shape in "ghp_$(printf 'a%.0s' {1..36})" "hf_$(printf 'b%.0s' {1..34})" "AIza$(printf 'c%.0s' {1..35})" \
             "xai-$(printf 'd%.0s' {1..40})" "HF_TOKEN=$(printf 'e%.0s' {1..30})"; do
  printf '(setf *x* "%s")\n' "$shape" > "$HOME/.stumpwm.d/user.lisp"
  out=$(ai key check 2>&1) && { echo "FAIL: check missed a key shaped ${shape:0:6}…"; fail=1; }
done
printf '(defun disk-get-usage-of-mounted-filesystems ())\n' > "$HOME/.stumpwm.d/user.lisp"
# A dotfile that links into a git repository: that repository has the key too.
mkdir -p "$t/dotfiles"; git -C "$t/dotfiles" init -q
printf 'export OPENAI_API_KEY=sk-proj-%s\n' 'abcdefghijklmnopqrstuvwxyz' > "$t/dotfiles/zshrc"
ln -s "$t/dotfiles/zshrc" "$HOME/.zshrc"
out=$(ai key check 2>&1) || true
check "check should say ~/.zshrc links into a git repository: $out" grep -q "in the git repository $t/dotfiles" <<<"$out"
rm "$HOME/.zshrc"
# Something in the secrets folder that Vikix didn't put there.
printf 'x' > "$secrets/ANTHROPIC_BASE_URL"
out=$(ai key check 2>&1) && { echo "FAIL: check passed with ANTHROPIC_BASE_URL dropped into secrets"; fail=1; }
check "check should name what doesn't belong in secrets: $out" grep -q 'ANTHROPIC_BASE_URL isn.t a key Vikix set' <<<"$out"
rm "$secrets/ANTHROPIC_BASE_URL"
out=$(ai key check 2>&1) || { echo "FAIL: check complained with everything clean:"; echo "$out" | sed 's/^/  /'; fail=1; }

# --- the agent and updates don't get the keys ---------------------------------------------
mkdir -p "$t/bin"
printf '#!/bin/sh\necho "claude sees: ${ANTHROPIC_API_KEY:-nothing}"\n' > "$t/bin/claude"; chmod +x "$t/bin/claude"
out=$(ANTHROPIC_API_KEY="$key" PATH="$t/bin:$PATH" bash "$here/bin/vikix" agent 2>&1)
check "vikix agent gave Claude Code the API key: $out" grep -q 'claude sees: nothing' <<<"$out"
out=$(ANTHROPIC_API_KEY="$key" VIKIX_AGENT_API_KEY=1 PATH="$t/bin:$PATH" bash "$here/bin/vikix" agent 2>&1)
check "VIKIX_AGENT_API_KEY=1 should give Claude Code the key" grep -qF "claude sees: $key" <<<"$out"
got=$(ANTHROPIC_API_KEY=a HF_TOKEN=b AWS_SECRET=c KEEP_ME=d bash -c ". '$here/lib/common.sh'; drop_keys; printf '%s|%s|%s|%s' \"\${ANTHROPIC_API_KEY-}\" \"\${HF_TOKEN-}\" \"\${AWS_SECRET-}\" \"\$KEEP_ME\"")
check "drop_keys (vikix update, the installer) should leave only KEEP_ME: $got" test "$got" = "|||d"
check "vikix update doesn't drop the keys first" bash -c "sed -n '/^cmd_update()/,/^}/p' '$here/bin/vikix' | grep -q '^  drop_keys'"
check "the installer doesn't drop the keys" grep -q '^drop_keys' "$here/install.sh"

[ "$fail" = 0 ] && echo "ai: keys are kept 600 in a 700 folder, exported, never shown or logged, and found where they shouldn't be"
exit "$fail"
