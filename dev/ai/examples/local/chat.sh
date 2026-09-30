#!/usr/bin/env bash
# chat.sh: the same from the shell, the whole answer at once ("stream": false).
#
#   ./chat.sh "Why is the sky blue?"
set -euo pipefail

host=${OLLAMA_HOST:-127.0.0.1:11434}
case $host in http*) ;; *) host=http://$host ;; esac
question=${*:-"In two sentences: what is an API?"}
# The first model that writes text: embedding models only make numbers.
model=${OLLAMA_MODEL:-$(curl -fsS "$host/api/tags" |
  jq -r '[.models[].name | select(test("embed|minilm") | not)][0] // empty')} ||
  { echo "Ollama isn't answering: \`vikix add local-ai\`, or \`vikix ai status\`." >&2; exit 1; }
[ -n "$model" ] || { echo "No model yet: \`vikix ai models\` picks one." >&2; exit 1; }

jq -n --arg m "$model" --arg q "$question" \
  '{model: $m, stream: false, messages: [{role: "user", content: $q}]}' |
  curl -fsS "$host/api/chat" -d @- | jq -r .message.content
