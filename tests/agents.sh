#!/usr/bin/env bash
# tests/agents.sh — vikix agent: any agent, one guide, the same snapshot.
#
#   the guide is the skill without its header, and changes with it; it's
#   linked where Codex and Gemini look, never over a file of yours; Aider
#   is given it with --read; each agent installs with its own installer
#   (OpenCode told not to edit .bashrc, Aider on Python 3.12, Gemini only
#   with Node 20+) and is recorded as a feature; --default is what Super+a
#   starts; a snapshot comes first; API keys are dropped (Aider keeps the
#   model companies', VIKIX_AGENT_API_KEY=1 keeps all); --local starts
#   opencode, codex and aider on an Ollama model, and refuses the others;
#   --uninstall takes the program, keeps your settings, and the guide link
#
# curl, npm, uv, node and the agents are stand-ins: nothing is downloaded.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME CODEX_HOME GEMINI_CLI_HOME VIKIX_AGENT_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME/.local/bin" "$t/bin"
git -C "$HOME" init -q 2>/dev/null || true; rm -rf "$HOME/.git"   # (the snapshot repo is its own)
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
agent() { bash "$here/bin/vikix-agent" "$@"; }
guide="$HOME/.local/share/vikix/AGENTS.md"

# An agent stand-in: it writes down how it was started (args, keys, env).
fake_agent() {   # fake_agent PATH
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
#!/bin/sh
{ echo "ran \$0 \$*"; env | grep -E '_API_KEY|_TOKEN|OLLAMA_API_BASE|OPENCODE_CONFIG_CONTENT' | sort; } > "$t/started"
EOF
  chmod +x "$1"
}
# curl: the installers put a stand-in agent where the real one goes; the
# Ollama API has the models in $t/tags.
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
case "\$*" in
  *claude.ai/install.sh*)  echo 'echo "install claude \$*" >> "$calls"; mkdir -p "$HOME/.local/bin"; cp "$t/agent" "$HOME/.local/bin/claude"' ;;
  *opencode.ai/install*)   echo 'echo "install opencode \$*" >> "$calls"; mkdir -p "$HOME/.opencode/bin"; cp "$t/agent" "$HOME/.opencode/bin/opencode"' ;;
  *codex/install.sh*)      echo 'echo "install codex CODEX_NON_INTERACTIVE=\$CODEX_NON_INTERACTIVE" >> "$calls"; mkdir -p "$HOME/.codex/packages/standalone"; cp "$t/agent" "$HOME/.codex/packages/standalone/codex"; ln -sfn "$HOME/.codex/packages/standalone/codex" "$HOME/.local/bin/codex"' ;;
  *aider.chat/install.sh*) echo 'echo "install aider UV_NO_MODIFY_PATH=\$UV_NO_MODIFY_PATH" >> "$calls"; cp "$t/agent" "$HOME/.local/bin/aider"' ;;
  *api/tags*) cat "$t/tags" 2>/dev/null ;;
esac
EOF
cat > "$t/bin/npm" <<EOF
#!/bin/sh
echo "npm \$*" >> "$calls"
case "\$*" in install*) cp "$t/agent" "$HOME/.local/bin/gemini" ;; uninstall*) rm -f "$HOME/.local/bin/gemini" ;; esac
EOF
cat > "$t/bin/uv" <<EOF
#!/bin/sh
echo "uv \$*" >> "$calls"
case "\$*" in "tool install"*) cp "$t/agent" "$HOME/.local/bin/aider" ;; "tool uninstall"*) rm -f "$HOME/.local/bin/aider" ;; esac
EOF
cat > "$t/bin/node" <<EOF
#!/bin/sh
case "\$*" in --version) echo "v\${NODE_MAJOR:-22}.1.0" ;; *) echo "\${NODE_MAJOR:-22}" ;; esac
EOF
chmod +x "$t/bin/"*
fake_agent "$t/agent"
export PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl" VIKIX_NPM="$t/bin/npm" VIKIX_UV="$t/bin/uv"

# The guide: the skill without its header.
agent --write-guide
check "the guide should be written" test -s "$guide"
check "the guide shouldn't keep the skill's header" test -z "$(grep -m1 '^name: vikix' "$guide" || true)"
check "the guide should have the skill's text" grep -q 'This machine runs \*\*Vikix\*\*' "$guide"
check "the guide should call itself a guide, not a skill" grep -q 'this guide' "$guide"

# Install each; each the way its project says.
for a in opencode codex aider; do agent --install "$a" >/dev/null 2>&1 || { echo "FAIL: --install $a"; fail=1; }; done
check "opencode's installer should be told not to edit .bashrc: $(grep 'install opencode' "$calls")" grep -q 'install opencode --no-modify-path' "$calls"
check "opencode should be linked into ~/.local/bin" test -L "$HOME/.local/bin/opencode"
check "codex's installer should run without questions: $(grep 'install codex' "$calls")" grep -q 'install codex CODEX_NON_INTERACTIVE=1' "$calls"
check "aider should install with uv on Python 3.12: $(grep '^uv' "$calls")" grep -q '^uv tool install --force --python python3.12 --with pip aider-chat@latest' "$calls"
check "codex should find the guide in ~/.codex/AGENTS.md" test "$(readlink "$HOME/.codex/AGENTS.md")" = "$guide"
check "installed agents should be recorded as features: $(cat "$HOME/.config/vikix/features" 2>/dev/null)" \
  grep -qx codex "$HOME/.config/vikix/features"
# Gemini: only with Node 20 or newer; a GEMINI.md of yours is kept.
NODE_MAJOR=18 agent --install gemini >/dev/null 2>&1 && { echo "FAIL: gemini installed on Node 18"; fail=1; }
check "gemini on Node 18 shouldn't run npm" test -z "$(grep '^npm' "$calls" || true)"
mkdir -p "$HOME/.gemini"; echo "my own rules" > "$HOME/.gemini/GEMINI.md"
out=$(agent --install gemini 2>&1) || true
check "gemini should install into ~/.local with npm: $(grep '^npm' "$calls")" grep -q "^npm install -g --prefix $HOME/.local @google/gemini-cli" "$calls"
check "your GEMINI.md should be kept" grep -qx 'my own rules' "$HOME/.gemini/GEMINI.md"
check "it should say how to add the guide to your GEMINI.md: $out" grep -q "@$guide" <<<"$out"

# Starting: the default (claude, installed on the spot here), a snapshot first, no keys.
fake_agent "$HOME/.local/bin/claude"
ANTHROPIC_API_KEY=sk-ant-x OPENAI_API_KEY=sk-x GITHUB_TOKEN=gh-x agent --print hello >/dev/null 2>&1 || true
check "the default should be claude, with its arguments: $(cat "$t/started" 2>/dev/null)" grep -q "^ran $HOME/.local/bin/claude --print hello" "$t/started"
check "claude shouldn't get API keys: $(cat "$t/started" 2>/dev/null)" test -z "$(grep -E 'API_KEY|TOKEN' "$t/started" || true)"
check "a snapshot should come first" test -n "$(git --git-dir="$VIKIX_STATE/yours.git" log --oneline -1 --grep='before an agent session (claude)' 2>/dev/null)"
ANTHROPIC_API_KEY=sk-ant-x VIKIX_AGENT_API_KEY=1 agent >/dev/null 2>&1 || true
check "VIKIX_AGENT_API_KEY=1 should keep the keys: $(cat "$t/started")" grep -q 'ANTHROPIC_API_KEY=sk-ant-x' "$t/started"

# Aider keeps the model companies' keys, and reads the guide.
ANTHROPIC_API_KEY=sk-ant-x GITHUB_TOKEN=gh-x agent --use aider >/dev/null 2>&1 || true
check "aider should be given the guide: $(head -1 "$t/started")" grep -q -- "--read $guide" "$t/started"
check "aider should keep ANTHROPIC_API_KEY" grep -q 'ANTHROPIC_API_KEY=sk-ant-x' "$t/started"
check "aider shouldn't get GITHUB_TOKEN" test -z "$(grep GITHUB_TOKEN "$t/started" || true)"

# --default: what Super+a starts.
agent --default codex >/dev/null
agent >/dev/null 2>&1 || true
check "--default codex should make vikix agent start codex: $(head -1 "$t/started")" grep -q "^ran $HOME/.local/bin/codex" "$t/started"
check "--list should mark codex: $(agent --list | grep codex)" grep -q '^\* codex' <<<"$(agent --list)"

# --local: on an Ollama model, the best coder there; not for claude or gemini.
echo '{"models": [{"name": "llama3.2:3b"}, {"name": "qwen2.5-coder:3b"}]}' > "$t/tags"
ANTHROPIC_API_KEY=sk-ant-x agent --use aider --local >/dev/null 2>&1 || true
check "aider --local should use ollama_chat/qwen2.5-coder:3b: $(cat "$t/started")" grep -q -- '--model ollama_chat/qwen2.5-coder:3b' "$t/started"
check "aider --local should be told where Ollama is" grep -q 'OLLAMA_API_BASE=http://127.0.0.1:11434' "$t/started"
check "aider --local shouldn't get keys" test -z "$(grep API_KEY "$t/started" || true)"
agent --local --model llama3.2:3b >/dev/null 2>&1 || true
check "codex --local --model should use --oss with it: $(head -1 "$t/started")" grep -q -- '--oss --local-provider ollama -m llama3.2:3b' "$t/started"
agent --use opencode --local >/dev/null 2>&1 || true
check "opencode --local should get an Ollama provider: $(cat "$t/started")" \
  grep -q 'OPENCODE_CONFIG_CONTENT=.*"model": "ollama/qwen2.5-coder:3b".*"baseURL": "http://127.0.0.1:11434/v1"' "$t/started"
rm -f "$t/started"
agent --use claude --local >/dev/null 2>&1 && { echo "FAIL: claude --local started"; fail=1; }
check "claude --local shouldn't start anything" test ! -e "$t/started"
agent --use aider --local --model mistral:7b >/dev/null 2>&1 && { echo "FAIL: a model you don't have started"; fail=1; }

# --uninstall: the program goes, your settings and your GEMINI.md stay; the
# default goes back to claude.
echo "x" > "$HOME/.codex/config.toml"
agent --uninstall codex >/dev/null 2>&1
check "codex should be gone" test ! -e "$HOME/.local/bin/codex"
check "codex's settings should stay" test -f "$HOME/.codex/config.toml"
check "codex's guide link should go" test ! -e "$HOME/.codex/AGENTS.md"
check "the default should go back to claude: $(agent --list | grep '^\*')" grep -q '^\* claude' <<<"$(agent --list)"
agent --uninstall gemini >/dev/null 2>&1
check "your GEMINI.md should stay after gemini goes" grep -qx 'my own rules' "$HOME/.gemini/GEMINI.md"

# Unknown names.
agent --use vscode >/dev/null 2>&1 && { echo "FAIL: an unknown agent started"; fail=1; }

[ "$fail" = 0 ] && echo "agents: five agents, one guide, a snapshot first, no keys unless needed, local where they can"
exit "$fail"
