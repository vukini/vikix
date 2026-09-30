#!/usr/bin/env bash
# ask.sh: the same question from the shell. An AI API is one HTTP request:
# JSON in (the model, the question), JSON out (the answer, the tokens used).
#
#   ./ask.sh "Why is the sky blue?"
set -euo pipefail

model=${CLAUDE_MODEL:-claude-opus-5-5}
question=${*:-"In two sentences: what is an API?"}
[ -n "${ANTHROPIC_API_KEY:-}" ] ||
  { echo "No ANTHROPIC_API_KEY: run \`vikix ai key set anthropic\`, then open a new terminal." >&2; exit 1; }

# jq builds the JSON, so quotes or newlines in the question can't break it.
# fallbacks: if the model's safety checks decline, another model answers
# (the anthropic-beta header below turns that on).
body=$(jq -n --arg model "$model" --arg q "$question" \
  '{model: $model, max_tokens: 16000, fallbacks: "default",
    messages: [{role: "user", content: $q}]}')

# The key goes in through a file descriptor, not the command line, where
# any program on the machine could read it (ps).
response=$(curl -sS "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages" \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: server-side-fallback-2026-07-01" \
  -H @<(printf 'x-api-key: %s\n' "$ANTHROPIC_API_KEY") \
  -d "$body")

if [ "$(jq -r .type <<<"$response")" = error ]; then
  echo "The API said: $(jq -r .error.message <<<"$response")" >&2
  exit 1
fi
jq -r '.content[] | select(.type == "text") | .text' <<<"$response"
jq -r '"(\(.model): \(.usage.input_tokens) tokens in, \(.usage.output_tokens) out)"' <<<"$response" >&2
