#!/usr/bin/env bash
# tests/notes.sh — `note` (bin/vikix-notes, lib/notes.py), against the
# made-up Claude and Ollama of tests/fake-ai.py, in a made-up home:
#   - before anything: ask and index say what to do first
#   - the first index writes ~/.config/vikix/notes (folder, skip, comments),
#     the index is in ~/.local/share/vikix/notes (700), and leaves out
#     hidden files and folders, Emacs's lock links and skipped folders
#   - index again, from anywhere: only what changed, and what's gone goes;
#     --skip alone changes the skips; another folder starts again
#   - find lists the nearest notes; ask gives the model the rule and the
#     nearest passages, and names them
#   - who answers follows ~/.config/vikix/ai (use=local, use=claude,
#     model=), and --local/--claude choose for one question; Claude without
#     a key says what to do
#   - two indexes at once: the second says so
#   - setup records the feature and fetches the embedding model when it
#     isn't there; uninstall keeps the index unless --index
#   - vikix notes reaches it, the note alias is in vikix.bash, and
#     features.list has the feature

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
command -v uv >/dev/null || { echo "(notes needs uv; skipped here)"; exit 0; }
t=$(mktemp -d)
fail=0
check() { local what=$1; shift; "$@" >/dev/null 2>&1 || { echo "FAIL: $what"; fail=1; }; }
has() { grep -qF -- "$1" <<<"$2"; }
lacks() { ! grep -qF -- "$1" <<<"$2"; }

log="$t/requests"; : > "$log"
python3 "$here/tests/fake-ai.py" "$log" > "$t/port" &
server=$!
trap 'kill $server 2>/dev/null; rm -rf "$t"' EXIT
for _ in $(seq 50); do [ -s "$t/port" ] && break; sleep 0.1; done
port=$(cat "$t/port")
[ -n "$port" ] || { echo "FAIL: the fake servers didn't start"; exit 1; }

# A made-up home; uv keeps its real cache, so the libraries aren't fetched again.
UV_CACHE_DIR=$(uv cache dir); export UV_CACHE_DIR
export HOME="$t/home"; mkdir -p "$HOME/bin"
unset XDG_CONFIG_HOME XDG_DATA_HOME ANTHROPIC_AUTH_TOKEN ANTHROPIC_PROFILE
export ANTHROPIC_BASE_URL="http://127.0.0.1:$port" OLLAMA_HOST="127.0.0.1:$port" ANTHROPIC_API_KEY=test-key-123
printf '#!/bin/sh\necho "ollama $*" >> %q\n' "$t/ollama-calls" > "$HOME/bin/ollama"; chmod +x "$HOME/bin/ollama"
export PATH="$HOME/bin:$PATH"
conf="$HOME/.config/vikix/notes"
data="$HOME/.local/share/vikix/notes"
note() { (cd "${where:-$HOME}" && timeout 300 bash "$here/bin/vikix-notes" "$@" 2>&1) || true; }
last() { tail -n 1 "$log"; }
given() { jq -r '.body.messages[-1].content // ""' <<<"$(last)"; }

v="$t/vault"; mkdir -p "$v/Daily" "$v/Private" "$v/.obsidian"
printf '# Services on Void\nrunit starts a service when its folder is linked into /var/service.\n' > "$v/void.md"
printf -- '---\ntags: [baking]\n---\n# Sourdough\n## The loaf\nBake the loaf at 240 for 45 minutes.\n' > "$v/sourdough.md"
printf '# Monday\nMet Sam about the garden fence.\n' > "$v/Daily/2026-09-28.md"
printf '# Bank\nThe PIN is secret.\n' > "$v/Private/bank.md"
printf '# App\nhidden settings\n' > "$v/.obsidian/app.md"
printf '# Draft\nhidden draft\n' > "$v/.draft.md"
ln -s "user@host.1:2" "$v/Daily/.#2026-09-28.md"          # Emacs's lock: a link to nowhere

# --- before anything ----------------------------------------------------------
out=$(note ask "anything")
check "ask with no index should say to index first: $out" has "note index" "$out"
out=$(note index)
check "index with no folder should say how: $out" has "no folder yet" "$out"
out=$(note)
check "note alone should show what it does: $out" has "note ask" "$out"

# --- the first index --------------------------------------------------------------
out=$(note index "$v" --skip Private)
check "the first index should read the three notes: $out" has "3 notes read" "$out"
check "the folder should be remembered" grep -qx "folder=$v" "$conf"
check "the skips should be remembered" grep -qx "skip=Private" "$conf"
check "the settings file should explain itself" grep -q "^#   skip" "$conf"
check "the index should be in ~/.local/share/vikix/notes" test -s "$data/index.db"
check "the index's folder should be yours alone: $(stat -c %a "$data")" test "$(stat -c %a "$data")" = 700
indexed=$(python3 -c 'import sqlite3,sys; [print(r[0]) for r in sqlite3.connect(sys.argv[1]).execute("select text from passages")]' "$data/index.db")
check "the private note shouldn't be in the index" lacks "PIN" "$indexed"
check "hidden notes shouldn't be in the index" lacks "hidden" "$indexed"

# --- again, from anywhere ------------------------------------------------------------
out=$(where=/ note index)
check "a second index from / should read nothing: $out" has "0 notes read" "$out"
printf 'Sam wants it painted green.\n' >> "$v/Daily/2026-09-28.md"; touch -d '+1 min' "$v/Daily/2026-09-28.md"
rm "$v/void.md"
out=$(note index)
check "a changed note should be read again, a deleted one go: $out" has "1 notes read, 1 gone" "$out"
out=$(note index --skip "")
check "--skip alone should change the skips: $(grep ^skip "$conf")" grep -qx "skip=" "$conf"
check "the note no longer skipped should be read: $out" has "1 notes read" "$out"
note index --skip Private >/dev/null

# --- find and ask ------------------------------------------------------------------------
out=$(note find "sourdough loaf bake")
check "find should list the nearest note first: $out" has "sourdough.md" "$(sed -n 2p <<<"$out")"
out=$(note ask "How long does the sourdough loaf bake?")
check "ask should print the local model's answer: $out" has "fake local answer" "$out"
check "ask should name its notes: $out" has "sourdough.md  › The loaf" "$out"
check "the local model should get the rule" has "Use only what the notes say" "$(jq -r '.body.messages[0].content' <<<"$(last)")"
check "the local model should get the passage" has "240 for 45 minutes" "$(given)"
check "the front matter shouldn't be in a passage" lacks "tags:" "$(given)"
check "with no choice, a model that writes text should answer: $(jq -r .body.model <<<"$(last)")" test "$(jq -r .body.model <<<"$(last)")" = fake-chat:1b

mkdir -p "$HOME/.config/vikix"; printf 'use=claude\nmodel=\n' > "$HOME/.config/vikix/ai"
out=$(note ask "How long does the loaf bake?")
check "use=claude should have Claude answer: $out" has "fake claude answer" "$out"
check "it should say the passages went to Anthropic: $out" has "went to Anthropic" "$out"
check "Claude should be Super+i's default, claude-sonnet-5" test "$(jq -r .body.model <<<"$(last)")" = claude-sonnet-5
check "Claude should get the rule as the system prompt" has "Use only what the notes say" "$(jq -r .body.system <<<"$(last)")"
check "claude-sonnet-5 shouldn't be sent fallbacks" test "$(jq -r '.body | has("fallbacks")' <<<"$(last)")" = false
out=$(note ask --local "How long does the loaf bake?")
check "--local should have the laptop answer, whatever ai says: $out" has "fake local answer" "$out"
printf 'use=claude\nmodel=claude-opus-5-5\n' > "$HOME/.config/vikix/ai"
note ask "loaf" >/dev/null
check "model= should choose the Claude model" test "$(jq -r .body.model <<<"$(last)")" = claude-opus-5-5
check "claude-opus-5-5 should be sent fallbacks with the beta" \
  test "$(jq -r '.body.fallbacks + " " + .beta' <<<"$(last)")" = "default server-side-fallback-2026-07-01"
out=$(ANTHROPIC_API_KEY='' note ask "loaf")
check "Claude without a key should say how to set one: $out" has "vikix ai key set anthropic" "$out"
printf 'use=local\nmodel=\n' > "$HOME/.config/vikix/ai"
out=$(note ask --claude "loaf")
check "--claude should have Claude answer, whatever ai says: $out" has "fake claude answer" "$out"

out=$(note status)
check "status should show the folder: $out" has "folder:  $v" "$out"
check "status should count the notes (void.md was deleted): $out" has "2 notes" "$out"

# --- another folder, and two at once ------------------------------------------------------
w="$t/other"; mkdir -p "$w"; printf '# Other\nsomething else\n' > "$w/o.md"
out=$(note index "$w")
check "another folder should start again: $out" has "starting again" "$out"
check "the new folder should be remembered, the skips kept" bash -c "grep -qx 'folder=$w' '$conf' && grep -qx 'skip=Private' '$conf'"
exec 8>"$data/.lock"; flock 8
out=$(note index)
check "a second index at once should say one is running: $out" has "already running" "$out"
exec 8>&-

# --- setup, uninstall, and the pieces around it ---------------------------------------------
: > "$t/ollama-calls"
out=$(timeout 300 bash "$here/bin/vikix-notes" setup 2>&1 || true)
check "setup should find the embedding model already there: $out" has "is here" "$out"
check "setup shouldn't pull a model that's there" test ! -s "$t/ollama-calls"
check "setup should record the feature" grep -qx notes "$HOME/.config/vikix/features"
out=$(OLLAMA_HOST=127.0.0.1:9 timeout 300 bash "$here/bin/vikix-notes" setup 2>&1 || true)
check "setup without the model should pull it: $(cat "$t/ollama-calls")" grep -qx "ollama pull all-minilm" "$t/ollama-calls"
out=$(bash "$here/bin/vikix-notes" uninstall 2>&1)
check "uninstall should keep the index: $out" test -s "$data/index.db"
check "uninstall should forget the feature" bash -c "! grep -qx notes '$HOME/.config/vikix/features'"
bash "$here/bin/vikix-notes" uninstall --index >/dev/null 2>&1
check "uninstall --index should remove the index" test ! -e "$data"

out=$(bash "$here/bin/vikix" notes help 2>&1 || true)
check "vikix notes should reach vikix-notes: $out" has "note ask" "$out"
check "vikix.bash should have the note alias" grep -q "^alias note='vikix-notes'" "$here/config/bash/vikix.bash"
check "features.list should have notes, needing local-ai" grep -qE '^notes +\| optional/notes +\| local-ai ' "$here/features.list"

[ "$fail" = 0 ] && echo "notes: index (first, again from anywhere, changes, skips, hidden and lock files, another folder, one at a time), find, ask (local, Claude, Super+i's choice, --local/--claude, no key), status, setup and uninstall"
exit "$fail"
