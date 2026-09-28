#!/usr/bin/env bash
# tests/llm.sh — `vikix ai llm`: the llm command, pinned, with a sensible
# default model, and never over one you chose.
#
#   installs llm and its Ollama and Anthropic plugins with uv, at the pinned
#   versions; its default becomes llama3.2:3b when that's here (else your
#   first local model), else Claude with ANTHROPIC_API_KEY, else it says
#   what to do, and never suggests a plain llm (llm's own default is paid
#   OpenAI); the default it picked is picked again (a local model later
#   wins over Claude), a default of your own stays; --default sets one;
#   --refresh (vikix update) reinstalls only an llm that isn't the pin;
#   no uv, a plain message
#
# uv, llm and curl are stand-ins: nothing is downloaded or asked.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ANTHROPIC_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME/.local/bin" "$t/bin"
calls="$t/calls"; : > "$calls"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
ai() { bash "$here/bin/vikix-local-ai" "$@"; }

# uv "installs" a stand-in llm, which keeps its default model in a file.
cat > "$t/bin/uv" <<EOF
#!/bin/sh
echo "uv \$*" >> "$calls"
cat > "$HOME/.local/bin/llm" <<'LLM'
#!/bin/sh
d="\$HOME/.config/io.datasette.llm"; f="\$d/default_model.txt"
case "\$1 \$2" in
  "--version ") echo "llm, version \${LLM_VERSION:-0.36}" ;;
  "models default") if [ -n "\$3" ]; then mkdir -p "\$d"; echo "\$3" > "\$f"; else cat "\$f" 2>/dev/null || echo gpt-5.6-luna; fi ;;
esac
LLM
chmod +x "$HOME/.local/bin/llm"
EOF
# curl: Ollama answers with the models in \$t/tags (none when it's missing).
cat > "$t/bin/curl" <<EOF
#!/bin/sh
case "\$*" in
  *api/version*) [ -e "$t/tags" ] ;;
  *api/tags*) cat "$t/tags" ;;
esac
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_UV="$t/bin/uv"
default() { cat "$HOME/.config/io.datasette.llm/default_model.txt" 2>/dev/null || echo "(llm's own)"; }
unchosen() { rm -f "$HOME/.config/io.datasette.llm/default_model.txt"; }

# Nothing to use yet: it says what to do, and leaves the default alone.
out=$(ai llm 2>&1)
check "uv should install llm and both plugins, pinned: $(cat "$calls")" \
  grep -qE '^uv tool install .*llm==[0-9.]+ --with llm-ollama==[0-9.]+ --with llm-anthropic==[0-9.]+' "$calls"
check "with no model anywhere, it should say how to get one: $out" grep -q 'vikix ai models' <<<"$out"
check "with no model anywhere, the default changed to $(default)" test "$(default)" = "(llm's own)"
check "with no model anywhere, it should warn that plain llm goes to OpenAI: $out" grep -q 'OpenAI' <<<"$out"
check "with no model anywhere, it shouldn't suggest a plain llm (llm's own default is paid): $out" \
  test -z "$(grep 'Try:' <<<"$out")"

# A key, no local model: Claude.
ANTHROPIC_API_KEY=sk-ant-test ai llm >/dev/null 2>&1
check "with a key and no local model, the default should be Claude, is $(default)" test "$(default)" = claude-sonnet-5
# Without the key now (vikix update drops keys): what it picked stays.
out=$(ai llm 2>&1)
check "with nothing better, the default it picked should stay, is $(default)" test "$(default)" = claude-sonnet-5

# A local model downloaded later wins over the Claude it picked itself.
echo '{"models": [{"name": "qwen2.5-coder:3b"}, {"name": "llama3.2:3b"}]}' > "$t/tags"
out=$(ai llm 2>&1)
check "once there's a local model, the default Vikix picked (Claude) should become llama3.2:3b, is $(default)" \
  test "$(default)" = llama3.2:3b

# --default sets yours, and yours stays.
ai llm --default qwen2.5-coder:3b >/dev/null 2>&1
check "--default should set it, is $(default)" test "$(default)" = qwen2.5-coder:3b
out=$(ANTHROPIC_API_KEY=sk-ant-test ai llm 2>&1)
check "a default you chose (qwen2.5-coder:3b) was replaced by $(default)" test "$(default)" = qwen2.5-coder:3b
check "it should say your default stays: $out" grep -q 'stays qwen2.5-coder:3b (yours' <<<"$out"
# One set with llm itself is yours too.
echo claude-opus-5-5 > "$HOME/.config/io.datasette.llm/default_model.txt"
ai llm >/dev/null 2>&1
check "a default set with llm models default was replaced by $(default)" test "$(default)" = claude-opus-5-5

# From llm's own default: llama3.2:3b first, else the first local model.
unchosen
ai llm >/dev/null 2>&1
check "with local models, the default should be llama3.2:3b, is $(default)" test "$(default)" = llama3.2:3b
unchosen
echo '{"models": [{"name": "gemma3:1b"}]}' > "$t/tags"
ai llm >/dev/null 2>&1
check "with one other local model, the default should be it, is $(default)" test "$(default)" = gemma3:1b

# --refresh (vikix update): nothing when llm is the pinned version, a
# reinstall when it isn't, nothing when llm was never installed.
: > "$calls"
ai llm --refresh >/dev/null 2>&1
check "--refresh with the pinned llm shouldn't reinstall: $(cat "$calls")" test ! -s "$calls"
LLM_VERSION=0.1 ai llm --refresh >/dev/null 2>&1
check "--refresh with an older llm should reinstall it" grep -q '^uv tool install' "$calls"
: > "$calls"; mv "$HOME/.local/bin/llm" "$t/llm.away"
ai llm --refresh >/dev/null 2>&1
check "--refresh without llm shouldn't install it: $(cat "$calls")" test ! -s "$calls"
mv "$t/llm.away" "$HOME/.local/bin/llm"

# No uv: a plain message.
# (Named outright: a missing stand-in on PATH would find the real uv.)
out=$(VIKIX_UV="$t/no-such-uv" ai llm 2>&1) && { echo "FAIL: llm installed without uv"; fail=1; }
check "without uv it should say where uv comes from: $out" grep -q "uv installs llm, and it isn't here" <<<"$out"

[ "$fail" = 0 ] && echo "llm: installed pinned with its plugins; its default is local when it can be, Claude with a key, never plain OpenAI, and never over yours"
exit "$fail"
