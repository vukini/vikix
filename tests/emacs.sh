#!/usr/bin/env bash
# tests/emacs.sh — Emacs's AI setup (config/emacs/vikix-ai.el), without the network.
#
#   45-editors links Vikix's part for Emacs (and not for Neovim alone);
#   vikix-ai.el loads clean in a bare Emacs; and, when gptel is here, gptel's
#   default follows ~/.config/vikix/ai (local: llama3.2:3b or your first
#   model, or model=; claude: claude-sonnet-5, or model=), a change reaches a
#   running Emacs but a pick of yours stays until then, and C-c g says what's
#   missing (the key, Ollama, a model) instead of asking for a key.
#
# curl is a stand-in answering as Ollama would ($HOME/ollama: the JSON, or
# absent for "not running"). gptel comes from VIKIX_TEST_GPTEL, or the
# emacs-void packages in ~/.emacs.d; the real chat with its packages is
# tests/editors.sh's (--all, network).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME VIKIX_EMACS_REPO VIKIX_STATE ANTHROPIC_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
gptel=${VIKIX_TEST_GPTEL:-$(find "$HOME/.emacs.d/elpa" -maxdepth 1 -type d -name 'gptel-[0-9]*' 2>/dev/null | sort | tail -1)}
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }

if ! command -v emacs >/dev/null; then
  echo "(emacs needs Emacs; skipped here)"
  exit 0
fi

mkdir -p "$t/bin"
for c in typescript-language-server pyright-langserver bash-language-server; do printf '#!/bin/sh\n' > "$t/bin/$c"; done
cat > "$t/bin/curl" <<'EOF'
#!/bin/sh
[ -f "$HOME/ollama" ] || exit 7
cat "$HOME/ollama"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
export GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# --- 45-editors: the link ---------------------------------------------------
git init -q "$t/emacs-void"
git -C "$t/emacs-void" commit -q --allow-empty -m init
export VIKIX_EMACS_REPO="$t/emacs-void"
export HOME="$t/emacs-home"
mkdir -p "$HOME/.config/vikix"
echo emacs > "$HOME/.config/vikix/features"
out=$(bash "$here/install/45-editors.sh" 2>&1)
check "Vikix's part for Emacs should be a link into the checkout: $out" \
  test "$(readlink "$HOME/.local/share/vikix/emacs")" = "$here/config/emacs"
check "the config should be cloned" test -d "$HOME/.emacs.d/.git"
export HOME="$t/nvim-home"
mkdir -p "$HOME/.config/vikix"
echo neovim > "$HOME/.config/vikix/features"
bash "$here/install/45-editors.sh" >/dev/null 2>&1 || true
check "Neovim alone shouldn't bring Emacs's part" test ! -e "$HOME/.local/share/vikix/emacs"

# --- vikix-ai.el ------------------------------------------------------------
export HOME="$t/home"
mkdir -p "$HOME/.config/vikix/secrets"
out=$(emacs -Q --batch -l "$here/config/emacs/vikix-ai.el" 2>&1)
check "vikix-ai.el should load clean without gptel: $out" test -z "$out"

if [ -z "$gptel" ]; then
  echo "(gptel isn't here: set VIKIX_TEST_GPTEL to its folder; the rest skipped)"
  [ "$fail" = 0 ] && echo "emacs: Vikix's part is linked and loads"
  exit "$fail"
fi

ai() { printf '%b' "$1" > "$HOME/.config/vikix/ai"; }
models() { printf '{"models":[%s]}' "$1" > "$HOME/ollama"; }
# el FORMS — run in an Emacs with gptel and vikix-ai.el; prints what they message.
el() {
  emacs -Q --batch -L "$gptel" -l "$here/config/emacs/vikix-ai.el" \
    --eval "(progn (defun say (&rest a) (princ (concat (apply #'format a) \"\\n\"))) $1)" 2>&1 || true
}
# The default C-c g would start on, or what it says instead.
chat='(condition-case e (progn (vikix-ai--check (vikix-ai-sync)) (say "%s on %s" gptel-model (gptel-backend-name gptel-backend))) (user-error (say "stopped: %s" (cadr e))))'

ai 'use=local\nmodel=\n'; models '{"name":"qwen3:4b"},{"name":"llama3.2:3b"}'
out=$(el "$chat")
check "local should be llama3.2:3b when you have it: $out" has '^llama3.2:3b on Local' "$out"
models '{"name":"qwen3:4b"},{"name":"gemma3:1b"}'
out=$(el "$chat")
check "else your first local model: $out" has '^qwen3:4b on Local' "$out"
ai 'use=local\nmodel=gemma3:1b  # mine\n'
out=$(el "$chat")
check "model= should win (its comment dropped): $out" has '^gemma3:1b on Local' "$out"
ai 'use=local\nmodel=llama3.1:8b\n'
out=$(el "$chat")
check "a model you don't have should be said: $out" has "stopped: You don’t have the model llama3.1:8b" "$out"
models ''
ai 'use=local\n'
out=$(el "$chat")
check "no local model should be said: $out" has 'stopped: No local model yet' "$out"
rm "$HOME/ollama"
out=$(el "$chat")
check "Ollama not running should be said: $out" has "stopped: Local AI isn’t running: in a terminal, vikix ai setup" "$out"

ai 'use=claude\n'
out=$(el "$chat")
check "Claude with no key should say how to set one: $out" has 'stopped: Claude needs your Anthropic key: in a terminal, vikix ai key set anthropic' "$out"
echo 'sk-test' > "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
out=$(el "$chat (say \"key %s\" (gptel--get-api-key))")
check "a key set since login should be used: $out" has '^key sk-test' "$out"
check "Claude should be claude-sonnet-5, as Super+i's: $out" has '^claude-sonnet-5 on Claude' "$out"
rm "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
out=$(ANTHROPIC_API_KEY=sk-env el "$chat (say \"key %s\" (gptel--get-api-key))")
check "the session's key should do: $out" has '^key sk-env' "$out"
ai 'use=claude\nmodel=claude-opus-5\n'
out=$(ANTHROPIC_API_KEY=sk-env el "$chat (say \"first %s, images %S\" (car (gptel-backend-models vikix-ai-claude)) (get (quote claude-opus-5) :capabilities))")
check "Claude's model= should be first in the menu, with what gptel knows of Sonnet: $out" has '^first claude-opus-5, images (media' "$out"
check "and be the default: $out" has '^claude-opus-5 on Claude' "$out"

# In one Emacs: a pick of yours stays, until the file changes.
models '{"name":"llama3.2:3b"}'
out=$(ANTHROPIC_API_KEY=sk-env el "(progn $chat
  (setq-default gptel-backend vikix-ai-local gptel-model 'llama3.2:3b)
  (vikix-ai-sync) (say \"kept %s\" gptel-model)
  (with-temp-file (expand-file-name \"ai\" vikix-ai-config) (insert \"use=local\n\"))
  $chat)")
check "a model you picked should stay while the file is the same: $out" has '^kept llama3.2:3b' "$out"
check "and a change to the file should reach a running Emacs: $out" has '^llama3.2:3b on Local' "$out"

# gptel's own C-c g: stopped before it asks for a buffer or a key.
ai 'use=claude\n'
out=$(el '(condition-case e (progn (require (quote gptel)) (call-interactively (quote gptel))) (user-error (say "stopped: %s" (cadr e))))' </dev/null)
check "gptel itself should stop with Vikix's words, not ask for a key: $out" has 'stopped: Claude needs your Anthropic key' "$out"

[ "$fail" = 0 ] && echo "emacs: Vikix's part is linked, and gptel follows vikix ai use"
exit "$fail"
