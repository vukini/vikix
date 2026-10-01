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
#   --uninstall takes the program, keeps your settings, and the guide link,
#   forgets the feature, leaves a link that isn't Vikix's; installers run
#   whole (downloaded first), without keys, and not at all in a dry run;
#   agents get neither the SSH agent nor other secrets, and VIKIX_AGENT
#   (so their shells don't read the keys back); OpenCode asks before
#   commands unless your config says; --model needs --local; a small local
#   model isn't sent the guide; Gemini's GEMINI.md imports the guide;
#   --exec (for editors) keeps stdout the agent's alone, drops the keys and
#   takes the snapshot the same way, starts yours without a name, and never
#   asks, even at a terminal; --which says which agent is yours; --acp
#   starts each as an ACP agent (gemini --acp, codex through its adapter,
#   pinned and installed with it on Node 22+, pointed at your codex), and
#   refuses aider, --local, and an adapter that isn't there
#
# curl, npm, uv, node and the agents are stand-ins: nothing is downloaded.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME CODEX_HOME GEMINI_CLI_HOME VIKIX_AGENT_API_KEY
unset VIKIX_AGENT_SSH
# Your own keys, if the shell running this has them: a check that failed
# would print them, and they'd change what a check sees.
for v in $(compgen -e); do case $v in *_API_KEY|*_KEY|*_TOKEN|*_SECRET) unset "$v" ;; esac; done
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
{ echo "ran \$0 \$*"; env | grep -E '_API_KEY|_TOKEN|_PASSWORD|SSH_AUTH_SOCK|VIKIX_AGENT=|OLLAMA_API_BASE|OPENCODE_CONFIG_CONTENT|CLAUDE_CODE_EXECUTABLE|CODEX_PATH' | sort; } > "$t/started"
EOF
  chmod +x "$1"
}
# curl: the installers put a stand-in agent where the real one goes; the
# Ollama API has the models in $t/tags.
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
out=/dev/stdout
prev=; for a in "\$@"; do [ "\$prev" = -o ] && out=\$a; prev=\$a; done
{ case "\$*" in *install*) env | grep -q 'API_KEY' && echo 'echo "installer saw a key" >> "$calls"' ;; esac
case "\$*" in
  *claude.ai/install.sh*)  echo 'echo "install claude \$*" >> "$calls"; mkdir -p "$HOME/.local/bin"; cp "$t/agent" "$HOME/.local/bin/claude"' ;;
  *opencode.ai/install*)   echo 'echo "install opencode \$*" >> "$calls"; mkdir -p "$HOME/.opencode/bin"; cp "$t/agent" "$HOME/.opencode/bin/opencode"' ;;
  *codex/install.sh*)      echo 'echo "install codex CODEX_NON_INTERACTIVE=\$CODEX_NON_INTERACTIVE" >> "$calls"; mkdir -p "$HOME/.codex/packages/standalone"; cp "$t/agent" "$HOME/.codex/packages/standalone/codex"; ln -sfn "$HOME/.codex/packages/standalone/codex" "$HOME/.local/bin/codex"' ;;
  *aider.chat/install.sh*) echo 'echo "install aider UV_NO_MODIFY_PATH=\$UV_NO_MODIFY_PATH" >> "$calls"; cp "$t/agent" "$HOME/.local/bin/aider"' ;;
  *api/tags*) cat "$t/tags" 2>/dev/null ;;
esac; } > "\$out"
EOF
cat > "$t/bin/npm" <<EOF
#!/bin/sh
echo "npm \$*" >> "$calls"
case "\$*" in
  install*codex-acp*)  cp "$t/agent" "$HOME/.local/bin/codex-acp"
                       v=\${*##*@}; mkdir -p "$HOME/.local/lib/node_modules/@agentclientprotocol/codex-acp"
                       printf '{\\n  "version": "%s",\\n}\\n' "\$v" > "$HOME/.local/lib/node_modules/@agentclientprotocol/codex-acp/package.json" ;;
  install*claude-agent-acp*) cp "$t/agent" "$HOME/.local/bin/claude-agent-acp" ;;
  install*) cp "$t/agent" "$HOME/.local/bin/gemini" ;;
  uninstall*codex-acp*) rm -f "$HOME/.local/bin/codex-acp" ;;
  uninstall*) rm -f "$HOME/.local/bin/gemini" ;;
esac
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

# A dry run installs nothing.
DRY_RUN=1 agent --install opencode >/dev/null 2>&1
check "a dry run shouldn't run an installer: $(cat "$calls")" test ! -s "$calls"

# Install each; each the way its project says, without your keys.
for a in opencode codex aider; do ANTHROPIC_API_KEY=sk-ant-x agent --install "$a" >/dev/null 2>&1 || { echo "FAIL: --install $a"; fail=1; }; done
check "an installer saw an API key" test -z "$(grep 'installer saw a key' "$calls" || true)"
check "installers should be downloaded to a file, then run: $(grep '^curl' "$calls" | head -1)" grep -q '^curl -fsSL https://opencode.ai/install -o ' "$calls"
check "opencode's installer should be told not to edit .bashrc: $(grep 'install opencode' "$calls")" grep -q 'install opencode --no-modify-path' "$calls"
check "opencode should be linked into ~/.local/bin" test -L "$HOME/.local/bin/opencode"
check "codex's installer should run without questions: $(grep 'install codex' "$calls")" grep -q 'install codex CODEX_NON_INTERACTIVE=1' "$calls"
check "aider should install with uv on Python 3.12: $(grep '^uv' "$calls")" grep -q '^uv tool install --force --python python3.12 --with pip aider-chat@latest' "$calls"
check "codex should find the guide in ~/.codex/AGENTS.md" test "$(readlink "$HOME/.codex/AGENTS.md")" = "$guide"
check "codex's ACP adapter (for editors) should come with it, pinned, without its own codex: $(grep '^npm' "$calls")" \
  grep -q "^npm install -g --prefix $HOME/.local --omit=optional --os=none --no-fund --no-audit @agentclientprotocol/codex-acp@[0-9]" "$calls"
check "only claude and codex need an adapter: $(grep '^npm' "$calls")" test "$(grep -c '^npm' "$calls")" = 1
check "installed agents should be recorded as features: $(cat "$HOME/.config/vikix/features" 2>/dev/null)" \
  grep -qx codex "$HOME/.config/vikix/features"
# Gemini: only with Node 20 or newer; a GEMINI.md of yours is kept.
NODE_MAJOR=18 agent --install gemini >/dev/null 2>&1 && { echo "FAIL: gemini installed on Node 18"; fail=1; }
check "gemini on Node 18 shouldn't run npm" test -z "$(grep '^npm.*gemini' "$calls" || true)"
mkdir -p "$HOME/.gemini"; echo "my own rules" > "$HOME/.gemini/GEMINI.md"
out=$(agent --install gemini 2>&1) || true
check "gemini should install into ~/.local with npm: $(grep '^npm' "$calls")" grep -q "^npm install -g --prefix $HOME/.local @google/gemini-cli" "$calls"
check "your GEMINI.md should be kept" grep -qx 'my own rules' "$HOME/.gemini/GEMINI.md"
check "it should say how to add the guide to your GEMINI.md: $out" grep -q "@$guide" <<<"$out"
rm "$HOME/.gemini/GEMINI.md"; ln -s "$guide" "$HOME/.gemini/GEMINI.md"     # as 0.49.0 made it
agent --use gemini --version >/dev/null 2>&1 || true
check "GEMINI.md should become a file importing the guide (not a link Gemini's memory would write into): $(ls -l "$HOME/.gemini/GEMINI.md")" \
  test ! -L "$HOME/.gemini/GEMINI.md" -a "$(cat "$HOME/.gemini/GEMINI.md" 2>/dev/null)" = "@$guide"
check "the guide should be intact" grep -q 'This machine runs' "$guide"
echo "my own rules" > "$HOME/.gemini/GEMINI.md"

# Starting: the default (claude, installed on the spot here), a snapshot first, no keys.
fake_agent "$HOME/.local/bin/claude"
ANTHROPIC_API_KEY=sk-ant-x OPENAI_API_KEY=sk-x GITHUB_TOKEN=gh-x DB_PASSWORD=pw SSH_AUTH_SOCK=/tmp/agent.sock agent --print hello >/dev/null 2>&1 || true
check "the default should be claude, with its arguments: $(cat "$t/started" 2>/dev/null)" grep -q "^ran $HOME/.local/bin/claude --print hello" "$t/started"
check "claude shouldn't get API keys or passwords: $(cat "$t/started" 2>/dev/null)" test -z "$(grep -E 'API_KEY|TOKEN|PASSWORD' "$t/started" || true)"
check "claude shouldn't get the SSH agent (it could push as you)" test -z "$(grep SSH_AUTH_SOCK "$t/started" || true)"
check "the agent should know it's one (VIKIX_AGENT), so its shells don't read the keys back" grep -qx 'VIKIX_AGENT=claude' "$t/started"
SSH_AUTH_SOCK=/tmp/agent.sock VIKIX_AGENT_SSH=1 agent >/dev/null 2>&1 || true
check "VIKIX_AGENT_SSH=1 should keep the SSH agent" grep -q 'SSH_AUTH_SOCK=/tmp/agent.sock' "$t/started"
# In an agent's shell, secrets.sh exports nothing.
mkdir -p "$HOME/.config/vikix/secrets"; chmod 700 "$HOME/.config/vikix/secrets"
echo sk-ant-y > "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"; chmod 600 "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
got=$(VIKIX_AGENT=claude sh -c ". '$here/lib/secrets.sh'; echo \${ANTHROPIC_API_KEY:-none}")
check "an agent's shell read the keys back" test "$got" = none
got=$(sh -c ". '$here/lib/secrets.sh'; echo \${ANTHROPIC_API_KEY:-none}")
check "outside an agent, secrets.sh should still export the keys" test "$got" = sk-ant-y
rm -rf "$HOME/.config/vikix/secrets"
check "a snapshot should come first" test -n "$(git --git-dir="$VIKIX_STATE/yours.git" log --oneline -1 --grep='before an agent session' 2>/dev/null)"
# With no files of yours to record, the snapshot fails: the agent starts all the same.
rm -f "$t/started"
( export HOME="$t/empty" VIKIX_STATE="$t/empty-state"; mkdir -p "$HOME/.local/bin"; cp "$t/agent" "$HOME/.local/bin/claude"
  bash "$here/bin/vikix-agent" >/dev/null 2>&1 || true )
check "a failed snapshot kept the agent from starting" test -e "$t/started"
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
check "opencode should ask before commands and edits: $(cat "$t/started")" grep -q '"permission": {"bash": "ask", "edit": "ask", "webfetch": "ask"}' "$t/started"
mkdir -p "$HOME/.config/opencode"; echo '{"permission": {"bash": "allow"}}' > "$HOME/.config/opencode/opencode.json"
agent --use opencode >/dev/null 2>&1 || true
check "your own opencode permissions should be left alone: $(cat "$t/started")" test -z "$(grep '"ask"' "$t/started" || true)"
rm -rf "$HOME/.config/opencode"
# A small local model isn't sent the guide (most of what it would read).
ANTHROPIC_API_KEY=sk-ant-x agent --use aider --local >/dev/null 2>&1 || true
check "aider --local on a 3b model shouldn't get the guide: $(head -1 "$t/started")" test -z "$(grep -- '--read' "$t/started" || true)"
rm -f "$t/started"
agent --use aider --model llama3.2:3b >/dev/null 2>&1 && { echo "FAIL: --model without --local started"; fail=1; }
check "--model without --local shouldn't start anything" test ! -e "$t/started"
out=$(agent --use gemini --local </dev/null 2>&1) || true
check "gemini --local should be refused first, not offered an install: $out" grep -q 'gemini has no local models' <<<"$out"
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
check "codex should be taken out of your features: $(cat "$HOME/.config/vikix/features")" test -z "$(grep -x codex "$HOME/.config/vikix/features" || true)"
ln -s /usr/bin/true "$HOME/.local/bin/codex"      # a codex link of your own
agent --uninstall codex >/dev/null 2>&1
check "a codex link that isn't Vikix's should stay" test -L "$HOME/.local/bin/codex"
rm "$HOME/.local/bin/codex"
agent --uninstall gemini >/dev/null 2>&1
check "your GEMINI.md should stay after gemini goes" grep -qx 'my own rules' "$HOME/.gemini/GEMINI.md"

# Unknown names.
agent --use vscode >/dev/null 2>&1 && { echo "FAIL: an unknown agent started"; fail=1; }

# --exec, for editors: stdout is the agent's alone (ACP talks over it).
printf '#!/bin/sh\n{ echo "ran $0 $*"; env | grep -E "_API_KEY|_TOKEN|SSH_AUTH_SOCK|VIKIX_AGENT=" | sort; } > "%s"\necho ACP-HELLO\n' "$t/started" > "$HOME/.local/bin/gemini"
chmod +x "$HOME/.local/bin/gemini"
rm -f "$t/started"
out=$(ANTHROPIC_API_KEY=sk-ant-x GITHUB_TOKEN=gh-x SSH_AUTH_SOCK=/tmp/agent.sock agent --exec gemini --experimental-acp 2>"$t/err") || true
check "--exec: stdout should be the agent's alone, got: $out" test "$out" = ACP-HELLO
check "--exec: Vikix's words should go to stderr: $(cat "$t/err")" grep -qE 'snapshot|haven.t changed' "$t/err"
check "--exec: the agent should get its arguments: $(cat "$t/started" 2>/dev/null)" grep -q "^ran $HOME/.local/bin/gemini --experimental-acp$" "$t/started"
check "--exec: no keys or tokens: $(cat "$t/started" 2>/dev/null)" test -z "$(grep -E 'API_KEY|TOKEN' "$t/started" || true)"
check "--exec: no SSH agent" test -z "$(grep SSH_AUTH_SOCK "$t/started" || true)"
check "--exec: VIKIX_AGENT set, as for --use" grep -qx 'VIKIX_AGENT=gemini' "$t/started"
agent --default gemini >/dev/null 2>&1
check "--which should say yours, one word: $(agent --which 2>&1)" test "$(agent --which 2>&1)" = gemini
rm -f "$t/started"
out=$(agent --exec --experimental-acp 2>/dev/null) || true
check "--exec without a name should start yours: $(cat "$t/started" 2>/dev/null)" grep -q "^ran $HOME/.local/bin/gemini --experimental-acp$" "$t/started"
rm -f "$t/started"
out=$(agent --acp gemeni </dev/null 2>&1) && { echo "FAIL: --acp with a misspelt name succeeded"; fail=1; }
check "--acp with a misspelt name should say so: $out" grep -q "no agent called 'gemeni'" <<<"$out"
check "and start nothing, not yours with the typo: $(cat "$t/started" 2>/dev/null)" test ! -e "$t/started"
agent --default claude >/dev/null 2>&1
# --acp: each agent as an ACP agent, with the same start.
rm -f "$t/started"
out=$(ANTHROPIC_API_KEY=sk-ant-x agent --acp gemini 2>"$t/err") || true
check "--acp gemini: stdout the agent's alone, got: $out" test "$out" = ACP-HELLO
check "--acp gemini: its own ACP mode: $(cat "$t/started" 2>/dev/null)" grep -q "^ran $HOME/.local/bin/gemini --acp$" "$t/started"
check "--acp: no keys: $(cat "$t/started" 2>/dev/null)" test -z "$(grep -E 'API_KEY|TOKEN' "$t/started" || true)"
agent --install codex >/dev/null 2>&1
: > "$calls"
out=$(agent --install codex 2>&1) || true
check "--install of one you have shouldn't run its installer again: $(cat "$calls")" test ! -s "$calls"
check "... and should say it's there: $out" grep -q 'already installed' <<<"$out"
rm "$HOME/.local/bin/codex-acp"
agent --install codex >/dev/null 2>&1 || true
check "--install of one you have should add a missing adapter: $(cat "$calls")" grep -q 'codex-acp@' "$calls"
check "... and only that" test -z "$(grep 'install codex' "$calls" || true)"
rm -f "$t/started"
agent --acp codex >/dev/null 2>&1 || true
check "--acp codex: the adapter, pointed at your codex: $(cat "$t/started" 2>/dev/null)" \
  grep -q "^ran $HOME/.local/bin/codex-acp *$" "$t/started"
check "--acp codex: CODEX_PATH is yours" grep -qx "CODEX_PATH=$HOME/.local/bin/codex" "$t/started"
out=$(agent --acp claude 2>&1 >/dev/null) && { echo "FAIL: --acp claude started without its adapter"; fail=1; }
check "--acp claude without its adapter should say how to get it: $out" grep -q 'vikix agent --install claude' <<<"$out"
out=$(agent --acp aider 2>&1 >/dev/null) && { echo "FAIL: --acp aider started"; fail=1; }
check "--acp aider should say it has no ACP: $out" grep -q "doesn't speak ACP" <<<"$out"
out=$(agent --acp opencode --local 2>&1 >/dev/null) && { echo "FAIL: --acp --local started"; fail=1; }
agent --uninstall codex >/dev/null 2>&1
check "--uninstall codex should take its adapter too" test ! -e "$HOME/.local/bin/codex-acp"
: > "$calls"
out=$(NODE_MAJOR=20 agent --install codex 2>&1) || { echo "FAIL: codex didn't install on Node 20: $out"; fail=1; }
check "on Node 20, codex installs without the adapter, and says so: $out" grep -q 'Node 22' <<<"$out"
check "on Node 20, no npm: $(grep '^npm' "$calls" || true)" test -z "$(grep '^npm' "$calls" || true)"
agent --uninstall codex >/dev/null 2>&1

# Not installed: an error, never a question, even at a terminal.
out=$(HOME="$t/nothing" script -qec "bash '$here/bin/vikix-agent' --exec codex" /dev/null </dev/null 2>&1) && { echo "FAIL: --exec started an agent that isn't installed"; fail=1; }
check "--exec: not installed should say how to install it: $out" grep -q 'vikix agent --install codex' <<<"$out"
check "--exec should never ask: $out" test -z "$(grep 'Install it now' <<<"$out" || true)"

[ "$fail" = 0 ] && echo "agents: five agents, one guide, a snapshot first, no keys unless needed, local where they can"
exit "$fail"
