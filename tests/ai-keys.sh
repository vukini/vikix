#!/usr/bin/env bash
# tests/ai-keys.sh — vikix-ask, AI on the selected text (Super+i).
#
#   the first use writes ~/.config/vikix/ai (use=local); the model comes
#   from it: llama3.2:3b first, else your first local model, the one named
#   there, or Claude with use=claude and a key, and never Claude by itself
#   when local has none; the menu's choice leads to its action;
#   Proofread/Rewrite/Translate put the tidied answer on the clipboard;
#   Ask sends the question with the selection, a short answer is a
#   notification, a long one a terminal; no selection, a plain message;
#   llm's failure is said; the selection falls back to the clipboard;
#   Proofread says what it changed; the answer's terminal doesn't keep the
#   lock; vikix ai use (and the menu) switch local/claude, Claude only with
#   a key; any typed language; use=Local; a misspelt action is said;
#   use=codex (lib/codex-ask.sh) only with Codex there and signed in, asked
#   with every tool off, read-only, in an empty folder, nothing kept, and
#   never through llm; the selection reaches it as data; its failure is
#   said in one line, without the text; effort= reaches Codex when set,
#   and one that isn't a word is refused
#
# xclip, rofi, notify-send, curl, llm, codex and the terminal are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ANTHROPIC_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME/.local/bin" "$t/bin" "$t/run" "$t/sel"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
conf="$HOME/.config/vikix/ai"

# xclip: -o prints $t/sel/primary or clipboard; writing keeps the clipboard.
cat > "$t/bin/xclip" <<EOF
#!/bin/sh
case "\$*" in
  *-o*primary*) cat "$t/sel/primary" 2>/dev/null ;;
  *-o*clipboard*) cat "$t/sel/clipboard" 2>/dev/null ;;
  *clipboard*) cat > "$t/copied" ;;
esac
EOF
# rofi answers from $t/rofi, one line per call, and logs its prompts
# (and, in $t/rofi.menu, the lines it was given).
cat > "$t/bin/rofi" <<EOF
#!/bin/sh
cat >> "$t/rofi.menu"
echo "\$*" >> "$t/rofi.log"
n=\$(wc -l < "$t/rofi.log")
line=\$(sed -n "\${n}p" "$t/rofi")
[ -n "\$line" ] || exit 1
echo "\$line"
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
echo "\$*" >> "$t/notes"
case "\$*" in *-p*) echo 7 ;; esac
EOF
cat > "$t/bin/curl" <<EOF
#!/bin/sh
case "\$*" in
  *api/version*) [ -e "$t/tags" ] ;;
  *api/tags*) cat "$t/tags" 2>/dev/null ;;
esac
EOF
# llm: logs its arguments and what came on stdin, answers from $t/answer.
cat > "$t/llm" <<EOF
#!/bin/sh
echo "\$*" > "$t/llm.args"
echo "\${OPENAI_API_KEY:-}" > "$t/llm.key"
[ "\$1" = logs ] && { cat "$t/llm.logs"; exit 0; }
cat > "$t/llm.in"
[ -e "$t/llm.fail" ] && { echo "Error: No key found - add one using 'llm keys set anthropic'" >&2; exit 1; }
cat "$t/answer"
EOF
# codex: signed in while $t/codex.signed-in is there; exec logs its arguments,
# its folder and stdin, and writes $t/answer where -o says.
cat > "$t/codex" <<EOF
#!/bin/sh
if [ "\$1 \$2" = "login status" ]; then [ -e "$t/codex.signed-in" ]; exit; fi
for a; do printf '[%s] ' "\$a"; done > "$t/codex.args"
cat > "$t/codex.in"
prev=; for a; do
  [ "\$prev" = -o ] && out=\$a
  [ "\$prev" = -C ] && ls -A "\$a" > "$t/codex.folder"
  prev=\$a
done
echo "user: the whole exchange, teh cat sat" >&2
if [ -e "$t/codex.fail" ]; then cat "$t/codex.fail" >&2; exit 1; fi
cat "$t/answer" > "\$out"
EOF
# The terminal says whether Super+i's lock is free while it's open.
cat > "$t/term" <<EOF
#!/bin/sh
echo "\$*" > "$t/term.args"
if flock -n "$t/run/vikix-ask.lock" true; then echo free; else echo held; fi > "$t/term.lock"
EOF
chmod +x "$t/bin/"* "$t/llm" "$t/term" "$t/codex"
export PATH="$t/bin:$PATH" VIKIX_LLM="$t/llm" VIKIX_TERMINAL="$t/term"
# No Codex until the Codex part: never the machine's own.
export VIKIX_CODEX="$t/no-codex"

# One try: selection, rofi answers, llm's answer; then ask.
try() {   # try ARGS... (with $t/rofi and $t/answer ready)
  rm -f "$t/rofi.log" "$t/rofi.menu" "$t/notes" "$t/copied" "$t/llm.args" "$t/llm.in" "$t/term.args" "$t/codex.args" "$t/codex.in"
  bash "$here/bin/vikix-ask" "$@" >/dev/null 2>&1 || true
}
select_text() { printf '%s' "$1" > "$t/sel/primary"; }
notes() { cat "$t/notes" 2>/dev/null; }

# Not set up: says what to do, and asks llm nothing.
select_text "teh cat sat"
printf 'Proofread\n' > "$t/rofi"; echo "The cat sat." > "$t/answer"
try
check "the first use should write $conf with use=local" grep -qx 'use=local' "$conf"
check "without Ollama it should say local AI isn't running: $(notes)" grep -q "Local AI isn't running" <<<"$(notes)"
check "without a model it shouldn't ask anything" test ! -e "$t/llm.args"
echo '{"models": []}' > "$t/tags"
try
check "without a local model it should say so, not use Claude: $(notes)" grep -q 'No local model yet' <<<"$(notes)"

# Proofread, from the menu: the local model, the tidied answer copied.
echo '{"models": [{"name": "gemma3:1b"}, {"name": "llama3.2:3b"}]}' > "$t/tags"
printf 'Here is the corrected text:\n\n"The cat sat."\n' > "$t/answer"
try
check "the menu should name the model and where the text goes: $(cat "$t/rofi.log")" \
  grep -q 'AI (llama3.2:3b, on this laptop)' "$t/rofi.log"
check "proofread should use llama3.2:3b: $(cat "$t/llm.args" 2>/dev/null)" grep -q -- '-m llama3.2:3b -s Correct the spelling' "$t/llm.args"
check "proofread should send the selection: $(cat "$t/llm.in" 2>/dev/null)" grep -qx 'teh cat sat' "$t/llm.in"
check "proofread should copy the answer alone, is: $(cat "$t/copied" 2>/dev/null)" test "$(cat "$t/copied" 2>/dev/null)" = "The cat sat."
check "proofread should say it's on the clipboard: $(notes)" grep -q 'Proofread, on the clipboard' <<<"$(notes)"
check "proofread should say what changed: $(notes)" grep -q '2 changes: teh → The; sat → sat.' <<<"$(notes)"
check "the result should replace the working notification: $(notes)" grep -q -- '-r 7 Proofread' <<<"$(notes)"
check "the working notification should show the text: $(notes)" grep -q 'on this laptop “teh cat sat”' <<<"$(tr '\n' ' ' < "$t/notes")"
echo "teh cat sat" > "$t/answer"
try
check "proofread with no change should say so: $(notes)" grep -q 'Proofread: nothing to correct' <<<"$(notes)"
printf 'Proofread\n' > "$t/rofi"; printf 'The cat sat.' > "$t/answer"

# Translate: the language picked, in the prompt; the model named in the file.
sed -i 's/^model=$/model=gemma3:1b/' "$conf"
printf 'Translate\nEsperanto\n' > "$t/rofi"; echo "La kato sidis." > "$t/answer"
try
check "translate should ask into Esperanto with gemma3:1b: $(cat "$t/llm.args" 2>/dev/null)" \
  grep -q -- '-m gemma3:1b -s Translate the text into Esperanto' "$t/llm.args"
check "translate should offer your languages: $(cat "$t/rofi.log")" grep -q 'Translate into' "$t/rofi.log"
check "translate should copy it" test "$(cat "$t/copied" 2>/dev/null)" = "La kato sidis."
printf 'Translate\nPortuguês\n' > "$t/rofi"
try
check "a typed language with an accent should work: $(cat "$t/llm.args" 2>/dev/null)" grep -q 'into Português' "$t/llm.args"
sed -i 's/^model=.*/model=qwen9:9b/' "$conf"
try
check "a model you don't have should be said: $(notes)" grep -q "You don't have the model qwen9:9b" <<<"$(notes)"
sed -i 's/^model=.*/model=$(touch pwned)/' "$conf"
try
check "a model name with shell in it should be refused: $(notes)" grep -q 'looks wrong' <<<"$(notes)"
check "a model name with shell in it ran" test ! -e pwned
sed -i 's/^model=.*/model=/' "$conf"

# translate_model=: Translate's own model; the rest keep model=.
printf 'translate_model=gemma3:1b\n' >> "$conf"
printf 'Translate\nFrench\n' > "$t/rofi"; echo "Le chat." > "$t/answer"
try
check "translate should ask translate_model's gemma3:1b: $(cat "$t/llm.args" 2>/dev/null)" \
  grep -q -- '-m gemma3:1b -s Translate the text into French' "$t/llm.args"
check "the working note should name Translate's model: $(notes)" grep -q 'gemma3:1b, on this laptop' <<<"$(notes)"
printf 'Proofread\n' > "$t/rofi"; printf 'The cat sat.' > "$t/answer"
try
check "proofread should stay on model= (llama3.2:3b): $(cat "$t/llm.args" 2>/dev/null)" grep -q -- '-m llama3.2:3b' "$t/llm.args"
check "which should give model=: $(bash "$here/bin/vikix-ask" which)" \
  test "$(bash "$here/bin/vikix-ask" which | cut -f1)" = llama3.2:3b
check "which translate should give translate_model=: $(bash "$here/bin/vikix-ask" which translate)" \
  test "$(bash "$here/bin/vikix-ask" which translate | cut -f1)" = gemma3:1b
sed -i 's/^translate_model=.*/translate_model=qwen9:9b/' "$conf"
printf 'Translate\nFrench\n' > "$t/rofi"
try
check "a translate_model you don't have should be said, naming its line: $(notes)" \
  grep -q "You don't have the model qwen9:9b.*translate_model= in" <<<"$(notes)"
sed -i 's/^translate_model=.*/translate_model=$(touch pwned2)/' "$conf"
try
check "a translate_model with shell in it should be refused: $(notes)" grep -q 'translate_model= in .* looks wrong' <<<"$(notes)"
check "a translate_model with shell in it ran" test ! -e pwned2
sed -i '/^translate_model=/d' "$conf"

# Ask: the question with the selection; short answer as a notification,
# a long one in a terminal.
printf 'Ask about it\nwhat animal?\n' > "$t/rofi"; echo "A cat." > "$t/answer"
try
check "ask should pass the question: $(cat "$t/llm.args" 2>/dev/null)" grep -q -- 'what animal?$' "$t/llm.args"
check "ask should send the selection: $(cat "$t/llm.in" 2>/dev/null)" grep -qx 'teh cat sat' "$t/llm.in"
check "a short answer should be a notification: $(notes)" grep -q 'AI: what animal? A cat.' <<<"$(notes)"
check "a short answer shouldn't open a terminal" test ! -e "$t/term.args"
check "ask shouldn't touch the clipboard" test ! -e "$t/copied"
seq 1 40 | sed 's/^/line /' > "$t/answer"
printf 'Explain\n' > "$t/rofi"
try
check "a long answer should open a terminal: $(cat "$t/term.args" 2>/dev/null)" grep -q -- '-e less' "$t/term.args"
check "the terminal's file should hold the answer" grep -q 'line 40' "$t/run/vikix-ask-answer.txt"
check "the answer's terminal kept Super+i's lock: $(cat "$t/term.lock" 2>/dev/null)" grep -qx free "$t/term.lock"

# Straight to an action (for your own keys); nothing selected; the clipboard.
: > "$t/rofi"; rm -f "$t/sel/primary"; echo "x" > "$t/answer"
try rewrite
check "with nothing selected it should say so: $(notes)" grep -q 'Select some text first' <<<"$(notes)"
check "with nothing selected it shouldn't ask llm" test ! -e "$t/llm.args"
printf 'from the clipboard' > "$t/sel/clipboard"
try rewrite
check "rewrite should skip the menu and use the clipboard: $(cat "$t/llm.in" 2>/dev/null)" grep -qx 'from the clipboard' "$t/llm.in"
check "a named action shouldn't open the menu" test ! -e "$t/rofi.log"
try proofraed
check "a misspelt action should be said: $(notes)" grep -q "doesn't know" <<<"$(notes)"
check "a misspelt action shouldn't ask llm" test ! -e "$t/llm.args"
sed -i 's/^use=.*/use=Local/' "$conf"
try rewrite
check "use=Local should count as local: $(cat "$t/llm.args" 2>/dev/null) $(notes)" grep -q -- '-m llama3.2:3b' "$t/llm.args"

# Switching: vikix ai use claude needs a key; the menu switches back.
check "vikix ai use alone should say which, one word: $(bash "$here/bin/vikix-ai" use 2>&1)" test "$(bash "$here/bin/vikix-ai" use 2>&1)" = local
bash "$here/bin/vikix-ai" use claude >/dev/null 2>&1 && { echo "FAIL: vikix ai use claude worked without a key"; fail=1; }
check "use claude without a key changed the file: $(grep '^use' "$conf")" grep -qx 'use=Local' "$conf"
ANTHROPIC_API_KEY=sk-ant-test bash "$here/bin/vikix-ai" use claude >/dev/null 2>&1
check "vikix ai use claude should write use=claude: $(grep '^use' "$conf")" grep -qx 'use=claude' "$conf"
check "vikix ai use alone should now say claude: $(bash "$here/bin/vikix-ai" use 2>&1)" test "$(bash "$here/bin/vikix-ai" use 2>&1)" = claude
check "switching should keep the rest of the file" grep -q '^languages=English' "$conf"
printf 'Use the local model instead (free; the text stays here)\n' > "$t/rofi"
ANTHROPIC_API_KEY=sk-ant-test try
check "the menu's switch should write use=local: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"
check "the switch shouldn't ask llm" test ! -e "$t/llm.args"
: > "$t/rofi"

# The cloud: use=cloud needs the key, by its name; the question goes to
# llm's vikix-cloud entry, the key in llm's environment and nowhere on the
# line; the entry names the service and the model, OpenRouter's unless
# said; other entries in llm's file stay; a wrong address is refused.
export LLM_USER_PATH="$t/llm-user"
mkdir -p "$LLM_USER_PATH"
printf -- '- model_id: mine\n  model_name: m\n  api_base: https://x/v1\n' > "$LLM_USER_PATH/extra-openai-models.yaml"
sed -i 's/^use=.*/use=cloud/' "$conf"
try rewrite
check "the cloud without a key should say how to set one: $(notes)" grep -q 'vikix ai key set openrouter' <<<"$(notes)"
check "the cloud without a key shouldn't ask llm" test ! -e "$t/llm.args"
OPENROUTER_API_KEY=sk-or-test try rewrite
check "use=cloud should ask llm's vikix-cloud: $(cat "$t/llm.args" 2>/dev/null)" grep -q -- '-m vikix-cloud' "$t/llm.args"
check "the key should reach llm as OPENAI_API_KEY: $(cat "$t/llm.key" 2>/dev/null)" test "$(cat "$t/llm.key" 2>/dev/null)" = sk-or-test
check "and nowhere on llm's line" bash -c '! grep -q sk-or-test "$1"' _ "$t/llm.args"
check "the working note should say the model and where: $(notes)" grep -q 'openai/gpt-4o-mini, sent to openrouter.ai' <<<"$(notes)"
check "llm's entry should name OpenRouter and the model" bash -c 'grep -q "api_base: https://openrouter.ai/api/v1" "$1" && grep -q "model_name: openai/gpt-4o-mini" "$1"' _ "$LLM_USER_PATH/extra-openai-models.yaml"
check "and keep the entry that was there" grep -q 'model_id: mine' "$LLM_USER_PATH/extra-openai-models.yaml"
check "vikix ai use alone should say cloud: $(bash "$here/bin/vikix-ai" use 2>&1)" test "$(bash "$here/bin/vikix-ai" use 2>&1)" = cloud
# A local model in model= (the usual case: it was chosen for use=local) must
# not go to the service, which doesn't know it: the cloud's line is cloud_model=.
sed -i 's/^model=.*/model=gpt-oss:120b/' "$conf"
OPENROUTER_API_KEY=sk-or-test try rewrite
check "model= (the local model's) should not reach the service: $(notes)" grep -q 'openai/gpt-4o-mini, sent to openrouter.ai' <<<"$(notes)"
check "llm's entry neither" bash -c '! grep -q "gpt-oss" "$1" && grep -q "model_name: openai/gpt-4o-mini" "$1"' _ "$LLM_USER_PATH/extra-openai-models.yaml"
sed -i -e 's/^cloud_url=.*/cloud_url=https:\/\/api.groq.com\/openai\/v1/' -e 's/^cloud_key=.*/cloud_key=groq/' -e 's/^cloud_model=.*/cloud_model=llama-3.3-70b/' "$conf"
OPENROUTER_API_KEY=sk-or-test try rewrite
check "another service's key should be asked for by its name: $(notes)" grep -q 'vikix ai key set groq' <<<"$(notes)"
GROQ_API_KEY=gsk-test try rewrite
check "another service: its key, its model, its name: $(cat "$t/llm.key" 2>/dev/null) $(notes)" bash -c '[ "$(cat "$1")" = gsk-test ] && grep -q "llama-3.3-70b, sent to api.groq.com" <<<"$2"' _ "$t/llm.key" "$(notes)"
check "llm's entry should follow" bash -c 'grep -q "api_base: https://api.groq.com/openai/v1" "$1" && grep -q "model_name: llama-3.3-70b" "$1" && [ "$(grep -c model_id: "$1")" = 2 ]' _ "$LLM_USER_PATH/extra-openai-models.yaml"
sed -i 's/^cloud_url=.*/cloud_url=http:\/\/example.org\/v1/' "$conf"
GROQ_API_KEY=gsk-test try rewrite
check "a plain http address elsewhere should be refused: $(notes)" grep -q "isn't an address" <<<"$(notes)"
check "and not asked" test ! -e "$t/llm.args"
sed -i -e 's/^cloud_url=.*/cloud_url=/' -e 's/^cloud_key=.*/cloud_key=/' -e 's/^cloud_model=.*/cloud_model=/' -e 's/^model=.*/model=/' -e 's/^use=.*/use=local/' "$conf"
bash "$here/bin/vikix-ai" use cloud >/dev/null 2>&1 && { echo "FAIL: vikix ai use cloud worked without a key"; fail=1; }
check "use cloud without a key changed the file: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"
OPENROUTER_API_KEY=sk-or-test bash "$here/bin/vikix-ai" use cloud >/dev/null 2>&1
check "vikix ai use cloud should write use=cloud: $(grep '^use' "$conf")" grep -qx 'use=cloud' "$conf"
printf 'Use the local model instead (free; the text stays here)\n' > "$t/rofi"
OPENROUTER_API_KEY=sk-or-test try
check "the menu's switch back should write use=local: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"
: > "$t/rofi"; OPENROUTER_API_KEY=sk-or-test try
check "the menu should offer the cloud when its key is there: $(cat "$t/rofi.menu" 2>/dev/null)" grep -q 'Use the cloud service instead (paid; the text goes to openrouter.ai)' "$t/rofi.menu"
try
check "and not without the key" bash -c '! grep -q "cloud service" "$1"' _ "$t/rofi.menu"
unset LLM_USER_PATH

# Claude: only with use=claude, and a key; llm's error is said, with the fix.
sed -i 's/^use=.*/use=claude/' "$conf"
try rewrite
check "Claude without a key should say how to set one: $(notes)" grep -q 'vikix ai key set anthropic' <<<"$(notes)"
check "Claude without a key shouldn't ask llm" test ! -e "$t/llm.args"
ANTHROPIC_API_KEY=sk-ant-test try rewrite
check "use=claude should use claude-sonnet-5: $(cat "$t/llm.args" 2>/dev/null)" grep -q -- '-m claude-sonnet-5' "$t/llm.args"
touch "$t/llm.fail"
ANTHROPIC_API_KEY=sk-ant-test try rewrite
check "llm's key error should point to vikix ai key: $(notes)" grep -q "didn't answer.*vikix ai key set anthropic" <<<"$(notes)"
rm -f "$t/llm.fail"

# Codex: only when it is there and signed in.
sed -i 's/^use=.*/use=local/' "$conf"
bash "$here/bin/vikix-ai" use codex >/dev/null 2>&1 && { echo "FAIL: vikix ai use codex worked without Codex"; fail=1; }
check "use codex without Codex changed the file: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"
printf 'Proofread\n' > "$t/rofi"
try
check "without Codex the menu shouldn't offer it: $(cat "$t/rofi.menu")" test -z "$(grep 'Use Codex' "$t/rofi.menu" || true)"
export VIKIX_CODEX="$t/codex"
out=$(bash "$here/bin/vikix-ai" use codex 2>&1) && { echo "FAIL: vikix ai use codex worked without a sign-in"; fail=1; }
check "use codex without a sign-in should say codex login: $out" grep -q 'codex login' <<<"$out"
touch "$t/codex.signed-in"
try
check "with Codex signed in the menu should offer it: $(cat "$t/rofi.menu")" grep -q '^Use Codex instead (the text goes to OpenAI)$' "$t/rofi.menu"
out=$(bash "$here/bin/vikix-ai" use codex 2>&1) || { echo "FAIL: vikix ai use codex failed: $out"; fail=1; }
check "vikix ai use codex should write use=codex: $(grep '^use' "$conf")" grep -qx 'use=codex' "$conf"
check "use codex should say where the text goes, and what stays local: $out" grep -q 'goes to OpenAI.*stay on the local model' <<<"$(tr '\n' ' ' <<<"$out")"
check "which should name codex, OpenAI and the choice: $(bash "$here/bin/vikix-ask" which)" \
  test "$(bash "$here/bin/vikix-ask" which)" = "codex"$'\t'"sent to OpenAI"$'\t'"codex"$'\t'

# Asked with its hands tied: every tool off, read-only, an empty folder,
# nothing kept; the selection on stdin, the answer copied; llm not asked.
select_text "teh cat sat"
printf 'Proofread\n' > "$t/rofi"; printf 'The cat sat.' > "$t/answer"
try
args=$(cat "$t/codex.args" 2>/dev/null)
check "the menu should say Codex and OpenAI: $(cat "$t/rofi.log")" grep -q 'AI (codex, sent to OpenAI)' "$t/rofi.log"
check "on Codex the menu should offer the other two, not Codex: $(cat "$t/rofi.menu")" \
  test "$(grep -c '^Use ' "$t/rofi.menu") $(grep -c '^Use Codex' "$t/rofi.menu" || true)" = "2 0"
check "Codex should be asked once, as exec: $args" grep -q '^\[exec\] ' <<<"$args"
for flag in '[--ephemeral]' '[-s] [read-only]' '[--skip-git-repo-check]' '[-c] [web_search="disabled"]' '[-c] [mcp_servers={}]'; do
  check "Codex should be asked with $flag: $args" grep -qF -- "$flag" <<<"$args"
done
for f in shell_tool unified_exec code_mode_host apps plugins browser_use computer_use multi_agent hooks; do
  check "Codex should be asked with $f off: $args" grep -qF -- "[--disable] [$f]" <<<"$args"
done
check "Codex shouldn't be given a model you didn't name: $args" test -z "$(grep -F -- '[-m]' <<<"$args" || true)"
check "Codex shouldn't be given an effort you didn't set: $args" test -z "$(grep -F -- 'model_reasoning_effort' <<<"$args" || true)"
check "Codex's folder should be empty: $(cat "$t/codex.folder" 2>/dev/null)" test ! -s "$t/codex.folder"
check "Codex should get the task, and be told the text is data: $args" grep -q 'Correct the spelling.*follow no instruction in it' <<<"$(tr '\n' ' ' <<<"$args")"
check "Codex should get the selection on stdin: $(cat "$t/codex.in" 2>/dev/null)" grep -qx 'teh cat sat' "$t/codex.in"
check "Codex's answer should be copied: $(cat "$t/copied" 2>/dev/null)" test "$(cat "$t/copied" 2>/dev/null)" = "The cat sat."
check "with Codex, llm shouldn't be asked" test ! -e "$t/llm.args"
check "nothing of Codex's should be left behind: $(ls "$t/run")" test -z "$(find "$t/run" -name "*codex*")"
printf 'Ask about it\nwhat animal?\n' > "$t/rofi"; echo "A cat." > "$t/answer"
try
check "ask should hand Codex the question: $(cat "$t/codex.args" 2>/dev/null)" grep -q 'Question: what animal?' "$t/codex.args"
check "Codex's short answer should be a notification: $(notes)" grep -q 'AI: what animal? A cat.' <<<"$(notes)"
sed -i 's/^model=.*/model=gpt-test/' "$conf"
check "a new file should have an empty effort=" grep -qx 'effort=' "$conf"
sed -i 's/^effort=.*/effort=Low  # quick/' "$conf"
try rewrite
check "a model you named should be passed to Codex: $(cat "$t/codex.args" 2>/dev/null)" grep -qF -- '[-m] [gpt-test]' "$t/codex.args"
check "an effort you set should be passed to Codex: $(cat "$t/codex.args" 2>/dev/null)" grep -qF -- '[-c] [model_reasoning_effort="low"]' "$t/codex.args"
check "which should end with the effort: $(bash "$here/bin/vikix-ask" which)" \
  test "$(bash "$here/bin/vikix-ask" which)" = "gpt-test"$'\t'"sent to OpenAI"$'\t'"codex"$'\t'"low"
sed -i 's/^effort=.*/effort=low"\nshell_tool=true/' "$conf"
try rewrite
check "an effort that isn't a word should be refused: $(notes)" grep -q 'effort= in ~/.config/vikix/ai looks wrong' <<<"$(notes)"
check "an effort that isn't a word shouldn't reach Codex" test ! -e "$t/codex.args"
sed -i -e 's/^model=.*/model=/' -e 's/^effort=.*/effort=/' "$conf"

# Its failure: the reason in a line, never the exchange (it holds the text).
printf 'ERROR: Reconnecting... 5/5\nERROR: {"type":"error","status":400,"error":{"type":"invalid_request_error","message":"The model is not supported."}}\n' > "$t/codex.fail"
try rewrite
check "Codex's error should be said: $(notes)" grep -q "didn't answer.*The model is not supported" <<<"$(notes)"
check "Codex's error shouldn't show the exchange: $(notes)" test -z "$(grep 'whole exchange' <<<"$(notes)" || true)"
echo 'Error: Unknown feature flag: shell_tool' > "$t/codex.fail"
try rewrite
check "a switch Codex doesn't know should stop it, and say so: $(notes)" grep -q 'Unknown feature flag: shell_tool.*vikix update' <<<"$(notes)"
check "a failed Codex shouldn't copy anything" test ! -e "$t/copied"
rm -f "$t/codex.fail" "$t/codex.signed-in"
try rewrite
check "signed out, Super+i should say codex login: $(notes)" grep -q "isn't signed in.*codex login" <<<"$(tr '\n' ' ' < "$t/notes")"
check "signed out, Codex shouldn't be asked" test ! -e "$t/codex.args"
printf 'Use the local model instead (free; the text stays here)\n' > "$t/rofi"; touch "$t/codex.signed-in"
try
check "the menu should switch back from Codex: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"

# vikix ai log: the last questions and answers from llm's log (the stand-in
# serves $t/llm.logs), newest first, times local, the cloud entry named;
# a word searches; nothing kept is said; no llm is said.
cat > "$t/llm.logs" <<'EOF'
[{"id": "a", "model": "llama3.2:3b", "duration_ms": "2400", "datetime_utc": "2026-10-21T04:00:00+00:00",
  "prompt": "teh cat sat\nwhat animal?", "response": "A cat."},
 {"id": "b", "model": "vikix-cloud", "duration_ms": "900", "datetime_utc": "2026-10-21T05:30:00+00:00",
  "prompt": "a makefile please", "response": "CC=gcc\nall: main"}]
EOF
out=$(TZ=Asia/Dubai bash "$here/bin/vikix-ai" log 2>&1)
check "log should ask llm for the last ten as JSON: $(cat "$t/llm.args")" test "$(cat "$t/llm.args")" = "logs list -n 10 --json"
check "newest first, the cloud named, the time local (+04): $out" test "$(head -1 <<<"$out")" = "Wed 21 Oct 09:30  the cloud service, 1 s"
check "the question quoted, the answer below: $out" bash -c 'grep -qx "> a makefile please" <<<"$1" && grep -qx "all: main" <<<"$1"' _ "$out"
check "the older one after, on its model: $out" bash -c 'tail -5 <<<"$1" | grep -q "^Wed 21 Oct 08:00  llama3.2:3b, 2 s" && grep -qx "> what animal?" <<<"$1"' _ "$out"
bash "$here/bin/vikix-ai" log 3 cat sat >/dev/null 2>&1
check "a number and words: the number is the count, the words the search: $(cat "$t/llm.args")" test "$(cat "$t/llm.args")" = "logs list -n 3 --json -q cat sat"
echo '[]' > "$t/llm.logs"
check "nothing kept should be said: $(bash "$here/bin/vikix-ai" log 2>&1)" grep -q 'nothing asked yet' <<<"$(bash "$here/bin/vikix-ai" log 2>&1)"
check "nothing with the word neither" grep -q "nothing asked with 'loaf' yet" <<<"$(bash "$here/bin/vikix-ai" log loaf 2>&1)"
check "without llm it should say vikix ai llm: $(VIKIX_LLM=/nonexistent bash "$here/bin/vikix-ai" log 2>&1)" grep -q 'vikix ai llm' <<<"$(VIKIX_LLM=/nonexistent bash "$here/bin/vikix-ai" log 2>&1)"

[ "$fail" = 0 ] && echo "ai-keys: Super+i works on the selection with the model you chose, local first, never Claude by itself, Codex with its tools off; vikix ai log shows what was asked"
exit "$fail"
