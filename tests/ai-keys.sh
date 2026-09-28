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
#   a key; any typed language; use=Local; a misspelt action is said
#
# xclip, rofi, notify-send, curl, llm and the terminal are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
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
# rofi answers from $t/rofi, one line per call, and logs its prompts.
cat > "$t/bin/rofi" <<EOF
#!/bin/sh
cat > /dev/null
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
cat > "$t/llm.in"
[ -e "$t/llm.fail" ] && { echo "Error: No key found - add one using 'llm keys set anthropic'" >&2; exit 1; }
cat "$t/answer"
EOF
# The terminal says whether Super+i's lock is free while it's open.
cat > "$t/term" <<EOF
#!/bin/sh
echo "\$*" > "$t/term.args"
if flock -n "$t/run/vikix-ask.lock" true; then echo free; else echo held; fi > "$t/term.lock"
EOF
chmod +x "$t/bin/"* "$t/llm" "$t/term"
export PATH="$t/bin:$PATH" VIKIX_LLM="$t/llm" VIKIX_TERMINAL="$t/term"

# One try: selection, rofi answers, llm's answer; then ask.
try() {   # try ARGS... (with $t/rofi and $t/answer ready)
  rm -f "$t/rofi.log" "$t/notes" "$t/copied" "$t/llm.args" "$t/llm.in" "$t/term.args"
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
bash "$here/bin/vikix-ai" use claude >/dev/null 2>&1 && { echo "FAIL: vikix ai use claude worked without a key"; fail=1; }
check "use claude without a key changed the file: $(grep '^use' "$conf")" grep -qx 'use=Local' "$conf"
ANTHROPIC_API_KEY=sk-ant-test bash "$here/bin/vikix-ai" use claude >/dev/null 2>&1
check "vikix ai use claude should write use=claude: $(grep '^use' "$conf")" grep -qx 'use=claude' "$conf"
check "switching should keep the rest of the file" grep -q '^languages=English' "$conf"
printf 'Use the local model instead (free; the text stays here)\n' > "$t/rofi"
ANTHROPIC_API_KEY=sk-ant-test try
check "the menu's switch should write use=local: $(grep '^use' "$conf")" grep -qx 'use=local' "$conf"
check "the switch shouldn't ask llm" test ! -e "$t/llm.args"
: > "$t/rofi"

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

[ "$fail" = 0 ] && echo "ai-keys: Super+i works on the selection with the model you chose, local first, never Claude by itself"
exit "$fail"
