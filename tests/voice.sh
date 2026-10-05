#!/usr/bin/env bash
# tests/voice.sh — vikix voice: talk to the AI, and it talks back.
#
#   setup installs the pinned Piper with uv and downloads the voice,
#   refusing a wrong checksum (keeping nothing), writes the choices and
#   records the feature, and a second setup does nothing; say streams
#   Piper into the player at the voice's rate, and quiet stops it; speak=no
#   stays silent; ask asks Super+i's model with a spoken-style system
#   prompt, speaks and shows the answer, carries the conversation on, and
#   starts afresh after the idle minutes or `new`; a failed answer says why
#   and speaks nothing; with use=codex it asks Codex (lib/codex-ask.sh),
#   tools off, each question on its own, and not llm; agent starts Claude Code in its own terminal with a
#   Stop hook for this session only, and agent-said speaks its reply (from
#   the hook's field or the transcript), without code or Markdown, and
#   exits 0 on junk; dictate toggle ask/agent sends what was said here,
#   and quiets the voice before listening; voices switches; uninstall
#   keeps the voices unless asked
#
# uv, Piper, the player, curl, llm, the terminal, xdotool, xclip and
# notify-send are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY ANTHROPIC_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/bin/" 2>/dev/null || true; rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME/.local/bin" "$t/bin" "$t/run" "$VIKIX_STATE"; chmod 700 "$t/run"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
v() { bash "$here/bin/vikix-voice" "$@"; }

# uv: "installs" a piper that writes what it's given to $t/spoken, slowly
# (so quiet has something to stop), and lists it as the pinned version.
cat > "$t/bin/uv" <<EOF
#!/bin/sh
echo "uv \$*" >> "$calls"
case "\$*" in
  "tool install"*)
    cat > "$HOME/.local/bin/piper" <<'P'
#!/bin/sh
echo "piper \$*" >> "$calls"
cat >> "$t/spoken"
sleep "\${VIKIX_TEST_SPEAK_FOR:-0}"
P
    chmod +x "$HOME/.local/bin/piper" ;;
  "tool list"*) [ -x "$HOME/.local/bin/piper" ] && echo "piper-tts v$(sed -n 's/^PIPER_PIN=piper-tts==//p' "$here/bin/vikix-voice")" ;;
  "tool uninstall"*) rm -f "$HOME/.local/bin/piper" ;;
esac
EOF
# curl: every download is the same bytes; a voice's config has its rate.
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
prev=; for a; do [ "\$prev" = -o ] && out=\$a; prev=\$a; done
printf 'voice bytes' > "\$out"
EOF
cat > "$t/bin/pw-play" <<EOF
#!/bin/sh
echo "pw-play \$*" >> "$calls"
cat > /dev/null
EOF
# llm: answers from $t/answer (or fails with $t/llm-error), logs its args,
# and says which conversation it made.
cat > "$t/bin/llm" <<EOF
#!/bin/sh
case "\$1" in
  logs) echo '[{"conversation_id": "conv-new"}]'; exit 0 ;;
esac
echo "llm \$*" >> "$calls"
if [ -s "$t/llm-error" ]; then cat "$t/llm-error" >&2; exit 1; fi
cat "$t/answer"
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
echo "\$*" >> "$t/notes"
case "\$*" in *-p*) echo 5 ;; esac
EOF
cat > "$t/bin/term" <<EOF
#!/bin/sh
for a; do printf '[%s] ' "\$a"; done > "$t/term-args"
EOF
cat > "$t/bin/xdotool" <<EOF
#!/bin/sh
echo "xdotool \$*" >> "$calls"
EOF
cat > "$t/bin/xclip" <<EOF
#!/bin/sh
cat > "$t/clipboard"
EOF
# vikix-ask which: a stand-in for Super+i's model.
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_UV="$t/bin/uv" VIKIX_CURL="$t/bin/curl" VIKIX_LLM="$t/bin/llm" VIKIX_TERMINAL="$t/bin/term"
VIKIX_TEST_SHA=$(printf 'voice bytes' | sha256sum | cut -d' ' -f1)
export VIKIX_TEST_SHA
notes() { cat "$t/notes" 2>/dev/null; }
spoken() { cat "$t/spoken" 2>/dev/null; }
# A spoken answer is in the background: wait for it to finish.
settle() { for _ in $(seq 50); do [ -e "$t/run/vikix-voice.speaking" ] || break; sleep 0.1; done; }
mkdir -p "$HOME/.config/io.datasette.llm"
# Super+i's model, as vikix-ask which gives it (llm itself is a stand-in).
cat > "$t/ask-conf" <<'EOF'
use=local
model=llama3.2:3b
EOF
mkdir -p "$HOME/.config/vikix"; cp "$t/ask-conf" "$HOME/.config/vikix/ai"
cat > "$t/bin/curl-ollama" <<'EOF'
#!/bin/sh
echo '{"models":[{"name":"llama3.2:3b"}]}'
EOF
chmod +x "$t/bin/curl-ollama"

# Before setup: status says so, and say tells you how.
out=$(v status 2>&1)
check "status before setup should be clean: $out" test "$out" = "not set up (vikix voice setup)"
v say "hello" >/dev/null 2>&1 || true
check "say before setup should say how: $(notes)" grep -q 'vikix add voice' <<<"$(notes)"

# Setup refuses a voice with the wrong checksum, and keeps nothing.
: > "$calls"
VIKIX_TEST_SHA=0000 v setup >/dev/null 2>&1 && { echo "FAIL: setup took a voice with the wrong checksum"; fail=1; }
kept=$(find "$HOME/.local/share/vikix/piper" -type f 2>/dev/null || true)
check "a voice with the wrong checksum shouldn't be kept: $kept" test -z "$kept"
check "setup should install the pinned Piper with uv: $(grep '^uv tool install' "$calls")" grep -q 'uv tool install --quiet --force piper-tts==[0-9.]*$' "$calls"
: > "$calls"
v setup >/dev/null 2>&1 || { echo "FAIL: setup failed"; fail=1; }
check "setup should fetch the voice from a pinned commit: $(grep -m1 curl "$calls")" grep -q 'piper-voices/resolve/[0-9a-f]\{40\}/en/en_US/lessac/medium/en_US-lessac-medium.onnx$' "$calls"
check "setup should fetch the voice's config" grep -q 'en_US-lessac-medium.onnx.json' "$calls"
check "setup should write the choices" grep -qx 'voice=lessac' "$HOME/.config/vikix/voice"
check "setup should record the feature" grep -qx voice "$HOME/.config/vikix/features"
: > "$calls"
v setup >/dev/null 2>&1
check "a second setup shouldn't install or download again: $(cat "$calls")" test -z "$(grep -E 'tool install|curl' "$calls" || true)"
check "status after setup: $(v status)" test "$(v status)" = "ready (lessac)"
# The voice's config, with its rate, as Piper's are.
echo '{"audio": {"sample_rate": 16000}}' > "$HOME/.local/share/vikix/piper/en_US-lessac-medium.onnx.json"

# say: Piper streams into the player, at the voice's rate.
: > "$calls"; rm -f "$t/spoken"
v say "Hello there."; settle
check "say should speak the text: [$(spoken)]" test "$(spoken)" = "Hello there."
check "Piper should stream raw audio: $(grep '^piper' "$calls")" grep -q -- '--output-raw' "$calls"
check "the player should play at the voice's rate: $(grep pw-play "$calls")" grep -q -- 'pw-play --rate 16000 --channels 1 --format s16 -' "$calls"
check "the speaking file should be gone when it's done" test ! -e "$t/run/vikix-voice.speaking"

# quiet stops it, and a new say stops the last.
rm -f "$t/spoken"
VIKIX_TEST_SPEAK_FOR=30 v say "A long answer."
sleep 0.3
check "while speaking, the file should name its group" test -s "$t/run/vikix-voice.speaking"
pg=$(cat "$t/run/vikix-voice.speaking" 2>/dev/null || echo 0)
v quiet
sleep 0.3
check "quiet should stop Piper and the player" test -z "$(pgrep -g "$pg" 2>/dev/null || true)"
check "quiet should drop the speaking file" test ! -e "$t/run/vikix-voice.speaking"

# speak=no: nothing said.
sed -i 's/^speak=.*/speak=no/' "$HOME/.config/vikix/voice"
rm -f "$t/spoken"; v say "Silent."; settle
check "speak=no shouldn't speak" test -z "$(spoken)"
check "status should say shown only: $(v status)" grep -q 'speak=no' <<<"$(v status)"
sed -i 's/^speak=.*/speak=yes/' "$HOME/.config/vikix/voice"

# ask: Super+i's model, a spoken-style prompt, answer spoken and shown.
# vikix-ask asks Ollama which models there are: its curl is a stand-in too.
ask_env() { VIKIX_CURL="$t/bin/curl-ollama" PATH="$t/askbin:$PATH" "$@"; }
mkdir -p "$t/askbin"; cp "$t/bin/curl-ollama" "$t/askbin/curl"; chmod +x "$t/askbin/curl"
echo 'Paris is the **capital** of France. See `man paris` or [this](https://example.org).' > "$t/answer"
: > "$calls"; : > "$t/notes"; rm -f "$t/spoken"
ask_env v ask "What is the capital of France?" >/dev/null 2>&1; settle
check "ask should use Super+i's model: $(grep '^llm' "$calls")" grep -q '^llm -m llama3.2:3b' "$calls"
check "ask should tell the model its answer is spoken" grep -q 'read aloud' "$calls"
check "ask should send the question" grep -q 'What is the capital of France?$' "$calls"
check "the first question shouldn't continue a conversation" test -z "$(grep -- '--cid' "$calls" || true)"
check "the answer should be spoken without Markdown or links: [$(spoken)]" \
  test "$(spoken)" = "Paris is the capital of France. See man paris or this."
check "the answer should be shown: $(notes)" grep -q 'Paris is the \*\*capital\*\*' <<<"$(notes)"
check "the conversation should be kept" grep -q '^conv-new ' "$VIKIX_STATE/voice-chat"

# A follow-up carries on; after the idle minutes, or new, it starts afresh.
: > "$calls"
ask_env v ask "And its population?" >/dev/null 2>&1; settle
check "a follow-up should continue the conversation: $(grep '^llm' "$calls")" grep -q -- '--cid conv-new' "$calls"
echo "conv-new $(( $(date +%s) - 3600 ))" > "$VIKIX_STATE/voice-chat"
: > "$calls"
ask_env v ask "Something else" >/dev/null 2>&1; settle
check "after an idle hour it should start afresh" test -z "$(grep -- '--cid' "$calls" || true)"
v new >/dev/null 2>&1
check "new should forget the conversation" test ! -e "$VIKIX_STATE/voice-chat"

# A failed answer: said, nothing spoken.
echo 'Error: No key found' > "$t/llm-error"; : > "$t/notes"; rm -f "$t/spoken"
ask_env v ask "Anything?" >/dev/null 2>&1 || true; settle
check "a failed answer should say why: $(notes)" grep -q 'vikix ai key set anthropic' <<<"$(notes)"
check "a failed answer shouldn't be spoken" test -z "$(spoken)"
rm -f "$t/llm-error"

# Super+i on Codex: the voice key asks Codex too, its tools off, and keeps
# no conversation; llm isn't asked.
cat > "$t/codex" <<EOF
#!/bin/sh
[ "\$1 \$2" = "login status" ] && exit 0
for a; do printf '[%s] ' "\$a"; done > "$t/codex.args"
prev=; for a; do [ "\$prev" = -o ] && out=\$a; prev=\$a; done
echo "Lyon is a city." > "\$out"
EOF
chmod +x "$t/codex"
printf 'use=codex\nmodel=\neffort=low\n' > "$HOME/.config/vikix/ai"
: > "$calls"; : > "$t/notes"; rm -f "$t/spoken" "$VIKIX_STATE/voice-chat"
VIKIX_CODEX="$t/codex" v ask "What is Lyon?" >/dev/null 2>&1; settle
check "with use=codex, ask should ask Codex: $(cat "$t/codex.args" 2>/dev/null)" grep -q 'read aloud.*Question: What is Lyon?' <<<"$(tr '\n' ' ' < "$t/codex.args")"
check "the voice key should ask Codex with its tools off" grep -qF -- '[--disable] [shell_tool]' "$t/codex.args"
check "the voice key should pass your effort on: $(cat "$t/codex.args" 2>/dev/null)" grep -qF -- '[-c] [model_reasoning_effort="low"]' "$t/codex.args"
check "with use=codex, llm shouldn't be asked: $(grep '^llm' "$calls" || true)" test -z "$(grep '^llm' "$calls" || true)"
check "Codex's answer should be spoken: [$(spoken)]" test "$(spoken)" = "Lyon is a city."
check "Codex's answer should say where it went: $(notes)" grep -q 'codex, sent to OpenAI' <<<"$(tr '\n' ' ' < "$t/notes")"
check "Codex shouldn't leave a conversation to carry on" test ! -e "$VIKIX_STATE/voice-chat"
cp "$t/ask-conf" "$HOME/.config/vikix/ai"

# The agent: Claude Code in its own terminal, with a hook for this session only.
v agent "open my downloads" >/dev/null 2>&1; sleep 0.3
args=$(cat "$t/term-args" 2>/dev/null)
check "agent should start in a terminal it can find again: $args" grep -q '\[--class\] \[vikix-voice-agent\]' <<<"$args"
check "agent should ask it what was said: $args" grep -q '\[agent\] \[--ask\] \[open my downloads\] \[--\] \[--settings\]' <<<"$args"
check "the hook should be Stop, running agent-said: $args" grep -q '"Stop".*vikix-voice agent-said' <<<"$args"
check "the hook shouldn't touch your Claude settings" test ! -e "$HOME/.claude/settings.json"

# agent-said: the reply, spoken without code; junk is ignored, quietly.
rm -f "$t/spoken"
printf '%s' '{"hook_event_name":"Stop","last_assistant_message":"Done. Here it is:\n```\nls ~/Downloads\n```\nAll good."}' | v agent-said; settle
check "agent-said should speak the reply without its code: [$(spoken)]" grep -q '^Done. Here it is: (the code is on the screen) All good.$' <<<"$(spoken)"
cat > "$t/transcript" <<'EOF'
{"type":"user","message":{"content":"list my downloads"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"a b"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"You have two files."}]}}
EOF
rm -f "$t/spoken"
printf '{"transcript_path":"%s"}' "$t/transcript" | v agent-said; settle
check "agent-said should find the reply in the transcript: [$(spoken)]" test "$(spoken)" = "You have two files."
echo '{broken' | v agent-said; rc=$?
check "agent-said should exit 0 on junk, is $rc" test "$rc" = 0

# dictate toggle ask: what was said goes to the AI, after quieting the voice.
cat > "$t/bin/pw-record" <<EOF
#!/bin/sh
for a; do last=\$a; done
printf 'RIFF' > "\$last"
trap 'exit 0' INT TERM
while :; do sleep 0.1; done
EOF
chmod +x "$t/bin/pw-record"
mkdir -p "$HOME/.local/share/vikix/whisper"
printf 'x' > "$HOME/.local/share/vikix/whisper/ggml-base.en.bin"
printf 'x' > "$HOME/.local/share/vikix/whisper/ggml-silero-v6.2.0.bin"
cat > "$t/bin/whisper" <<EOF
#!/bin/sh
echo "Is it raining?"
EOF
chmod +x "$t/bin/whisper"
press() { rm -f "$t/run/vikix-dictation.last"; VIKIX_WHISPER="$t/bin/whisper" bash "$here/bin/vikix-dictate" toggle "$@" >/dev/null 2>&1; }
VIKIX_TEST_SPEAK_FOR=30 v say "Still talking."; sleep 0.3
: > "$calls"; : > "$t/notes"
ask_env press ask
check "listening for the AI should quiet the voice" test ! -e "$t/run/vikix-voice.speaking"
check "it should say it listens for the AI: $(notes)" grep -q 'Listening, for the AI' <<<"$(notes)"
sleep 0.8
echo 'Not today.' > "$t/answer"; rm -f "$t/spoken"
ask_env press; settle
check "what was said should go to the AI: $(grep '^llm' "$calls")" grep -q 'Is it raining?$' "$calls"
check "and its answer be spoken: [$(spoken)]" test "$(spoken)" = "Not today."
check "nothing should be typed" test -z "$(grep 'xdotool type' "$calls" || true)"
: > "$calls"; rm -f "$t/term-args"
press agent; sleep 0.8; press; sleep 0.3
check "toggle agent should send it to the agent: $(cat "$t/term-args" 2>/dev/null)" grep -q '\[--ask\] \[Is it raining?\]' "$t/term-args"
out=$(bash "$here/bin/vikix-dictate" toggle nonsense 2>&1) && { echo "FAIL: toggle took an unknown target"; fail=1; }

# Voices, and uninstall.
: > "$calls"
v voices alan >/dev/null 2>&1; settle
check "voices alan should download it" grep -q 'en_GB-alan-medium.onnx' "$calls"
check "voices alan should be the choice" grep -qx 'voice=alan' "$HOME/.config/vikix/voice"
v uninstall >/dev/null 2>&1
check "uninstall should remove Piper" test ! -e "$HOME/.local/bin/piper"
check "uninstall should keep the voices" test -s "$HOME/.local/share/vikix/piper/en_GB-alan-medium.onnx"
check "uninstall should forget the feature" test -z "$(grep -x voice "$HOME/.config/vikix/features" || true)"
v uninstall --voices >/dev/null 2>&1
check "uninstall --voices should remove them" test ! -e "$HOME/.local/share/vikix/piper"

[ "$fail" = 0 ] && echo "voice: pinned and checked, speaks and stops, asks with a conversation, the agent with a hook of its own, from dictation, voices, uninstall"
exit "$fail"
