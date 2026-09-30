#!/usr/bin/env bash
# tests/dev-ai.sh — the examples in dev/ai/examples/ run end to end, against
# a made-up Claude API and a made-up Ollama on 127.0.0.1, so nothing is sent
# anywhere and nothing is paid:
#   - claude: ask.py streams, ask.sh doesn't; both send the key (never on
#     curl's command line), the model, fallbacks "default" with its beta
#     header (and no fallbacks for a model without them); no key or a
#     refused key says what to do
#   - local: chat.py and chat.sh pick a model that writes text, not the
#     embedding one; Ollama not answering says so
#   - embeddings: the sentence nearest the question comes first; a model
#     not pulled says `ollama pull`
#   - ask-notes: index reads the notes, skips hidden folders and --skip ones,
#     reads only what changed, starts again for another folder; ask gives
#     the model the nearest notes and the rule, locally or with --claude
#
# The fake's embeddings count words, so the nearest note is the one that
# shares the question's words: the search is real, the meaning isn't.
# The examples fetch their libraries with uv (network, the first time).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
command -v uv >/dev/null || { echo "(dev-ai needs uv; skipped here)"; exit 0; }
command -v jq >/dev/null || { echo "(dev-ai needs jq; skipped here)"; exit 0; }
t=$(mktemp -d)
fail=0
check() { local what=$1; shift; "$@" >/dev/null 2>&1 || { echo "FAIL: $what"; fail=1; }; }
has() { grep -qF -- "$1" <<<"$2"; }
lacks() { ! grep -qF -- "$1" <<<"$2"; }

# --- the fake servers -------------------------------------------------------
cat > "$t/fake.py" <<'EOF'
import hashlib, json, re, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = sys.argv[1]
DIM = 64
STOP = {"a", "an", "the", "to", "in", "on", "of", "i", "do", "how", "is", "it", "and", "for", "at", "by", "what"}

def embed(text):
    v = [0.0] * DIM
    for w in re.findall(r"[a-z]+", text.lower()):
        if w not in STOP:
            v[int(hashlib.md5(w.encode()).hexdigest(), 16) % DIM] += 1
    n = sum(x * x for x in v) ** 0.5 or 1
    return [x / n for x in v]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, body, kind="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code); self.send_header("content-type", kind)
        self.send_header("content-length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        if self.path == "/api/tags":
            return self.send(200, {"models": [{"name": "all-minilm:latest"}, {"name": "fake-chat:1b"}]})
        self.send(404, {"error": "no"})
    def do_POST(self):
        self.path = self.path.split("?")[0]        # the SDK's beta calls add ?beta=true
        body = json.loads(self.rfile.read(int(self.headers["content-length"])))
        with open(LOG, "a") as f:
            f.write(json.dumps({"path": self.path, "key": self.headers.get("x-api-key"),
                                "beta": self.headers.get("anthropic-beta"), "body": body}) + "\n")
        if self.path == "/api/embed":
            if body["model"] == "missing-model":
                return self.send(404, {"error": f"model \"{body['model']}\" not found, try pulling it first"})
            return self.send(200, {"embeddings": [embed(x) for x in body["input"]]})
        if self.path == "/api/chat":
            if body.get("stream") is False:
                return self.send(200, {"message": {"content": "fake local answer"}, "done": True})
            lines = [{"message": {"content": "fake local "}},
                     {"message": {"content": "answer"}, "done": True, "eval_count": 2, "eval_duration": 1e9}]
            return self.send(200, "".join(json.dumps(l) + "\n" for l in lines).encode(), "application/x-ndjson")
        if self.path == "/v1/messages":
            if self.headers.get("x-api-key") != "test-key-123":
                return self.send(401, {"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}})
            usage = {"input_tokens": 5, "output_tokens": 3}
            if not body.get("stream"):
                return self.send(200, {"id": "msg_1", "type": "message", "role": "assistant", "model": body["model"],
                                       "content": [{"type": "text", "text": "fake claude answer"}],
                                       "stop_reason": "end_turn", "stop_sequence": None, "usage": usage})
            events = [
                ("message_start", {"type": "message_start", "message": {"id": "msg_1", "type": "message", "role": "assistant",
                    "model": body["model"], "content": [], "stop_reason": None, "stop_sequence": None,
                    "usage": {"input_tokens": 5, "output_tokens": 1}}}),
                ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}),
                ("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "fake claude answer"}}),
                ("content_block_stop", {"type": "content_block_stop", "index": 0}),
                ("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence": None}, "usage": {"output_tokens": 3}}),
                ("message_stop", {"type": "message_stop"}),
            ]
            return self.send(200, "".join(f"event: {e}\ndata: {json.dumps(d)}\n\n" for e, d in events).encode(), "text/event-stream")
        self.send(404, {"error": "no"})

s = ThreadingHTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
EOF
log="$t/requests"
: > "$log"
python3 "$t/fake.py" "$log" > "$t/port" &
server=$!
trap 'kill $server 2>/dev/null; rm -rf "$t"' EXIT
for _ in $(seq 50); do [ -s "$t/port" ] && break; sleep 0.1; done
port=$(cat "$t/port")
[ -n "$port" ] || { echo "FAIL: the fake servers didn't start"; exit 1; }

# Every example talks to the fakes: never the real Claude, never the real Ollama.
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_PROFILE CLAUDE_MODEL OLLAMA_MODEL EMBED_MODEL NOTES_DB
export ANTHROPIC_BASE_URL="http://127.0.0.1:$port" OLLAMA_HOST="127.0.0.1:$port" ANTHROPIC_API_KEY=test-key-123
cp -r "$here/dev/ai/examples" "$t/ex"
last() { tail -n 1 "$log"; }                  # the last request the fakes saw
run() { (cd "$t/ex/$1" && shift && timeout 300 "$@" 2>&1) || true; }

# --- claude ---------------------------------------------------------------------
out=$(run claude make -s run QUESTION="Why is the sky blue?")
check "ask.py should print Claude's answer: $out" has "fake claude answer" "$out"
check "ask.py should print the tokens used: $out" has "5 tokens in, 3 out" "$out"
req=$(last)
check "ask.py should send the key" test "$(jq -r .key <<<"$req")" = test-key-123
check "ask.py should ask claude-opus-5-5: $(jq -c .body.model <<<"$req")" test "$(jq -r .body.model <<<"$req")" = claude-opus-5-5
check "ask.py should stream" test "$(jq -r .body.stream <<<"$req")" = true
check "ask.py should send the question" test "$(jq -r '.body.messages[0].content' <<<"$req")" = "Why is the sky blue?"
check "ask.py should ask for fallbacks \"default\": $req" test "$(jq -r .body.fallbacks <<<"$req")" = default
check "ask.py should send the fallbacks beta: $(jq -r .beta <<<"$req")" has server-side-fallback-2026-07-01 "$(jq -r .beta <<<"$req")"
out=$(cd "$t/ex/claude" && echo "some piped text" | timeout 300 uv run -q ask.py "Summarise this" 2>&1 || true)
check "ask.py should put piped text after the question: $(last)" has "some piped text" "$(jq -r '.body.messages[0].content' <<<"$(last)")"
out=$(CLAUDE_MODEL=claude-haiku-4-5 run claude make -s run)
check "a model without fallbacks shouldn't be sent them: $(last)" test "$(jq -r '.body | has("fallbacks")' <<<"$(last)")" = false

out=$(run claude ./ask.sh 'Say "hi"')
check "ask.sh should print Claude's answer: $out" has "fake claude answer" "$out"
req=$(last)
check "ask.sh should send the key" test "$(jq -r .key <<<"$req")" = test-key-123
check "ask.sh should send quotes in the question as they are" test "$(jq -r '.body.messages[0].content' <<<"$req")" = 'Say "hi"'
check "ask.sh should ask for fallbacks with the beta" test "$(jq -r '.body.fallbacks + " " + .beta' <<<"$req")" = "default server-side-fallback-2026-07-01"
check "ask.sh should keep the key off curl's command line" bash -c "! grep -n 'x-api-key: \$ANTHROPIC_API_KEY\"' '$here/dev/ai/examples/claude/ask.sh'"

out=$(ANTHROPIC_API_KEY='' run claude make -s run)
check "ask.py without a key should say how to set one: $out" has "vikix ai key set anthropic" "$out"
out=$(ANTHROPIC_API_KEY='' run claude make -s run-sh)
check "ask.sh without a key should say how to set one: $out" has "vikix ai key set anthropic" "$out"
out=$(ANTHROPIC_API_KEY=wrong run claude make -s run)
check "ask.py with a refused key should say so: $out" has "The key was refused" "$out"
out=$(ANTHROPIC_API_KEY=wrong run claude make -s run-sh)
check "ask.sh with a refused key should pass on the API's message: $out" has "invalid x-api-key" "$out"

# --- local ----------------------------------------------------------------------
out=$(run local make -s run QUESTION="Why is the sky blue?")
check "chat.py should print the local answer: $out" has "fake local answer" "$out"
check "chat.py should pick the model that writes text: $(last)" test "$(jq -r .body.model <<<"$(last)")" = fake-chat:1b
out=$(run local make -s run-sh)
check "chat.sh should print the local answer: $out" has "fake local answer" "$out"
check "chat.sh should pick the model that writes text" test "$(jq -r .body.model <<<"$(last)")" = fake-chat:1b
out=$(OLLAMA_HOST=127.0.0.1:9 run local make -s run)
check "chat.py with no Ollama should say so: $out" has "Ollama isn't answering" "$out"
out=$(OLLAMA_HOST=127.0.0.1:9 run local make -s run-sh)
check "chat.sh with no Ollama should say so: $out" has "Ollama isn't answering" "$out"

# --- embeddings -----------------------------------------------------------------------
out=$(run embeddings make -s run QUESTION="warm fresh bread")
first=$(grep -A1 '^Nearest' <<<"$out" | tail -n 1)
check "the bread sentence should be nearest warm fresh bread: $out" has "Fresh bread" "$first"
check "embed.py should use all-minilm" test "$(jq -r .body.model <<<"$(last)")" = all-minilm
out=$(run embeddings make -s run EMBED_MODEL=missing-model)
check "a model not pulled should say ollama pull: $out" has "ollama pull missing-model" "$out"

# --- ask-notes -------------------------------------------------------------------------
out=$(run ask-notes make -s ask)
check "ask before index should say to index first: $out" has "index" "$out"
out=$(run ask-notes make -s run)
check "index should read the four sample notes: $out" has "4 notes read" "$out"
check "the answer should come from the local model: $out" has "fake local answer" "$out"
check "the services note should be nearest a question about services: $out" \
  has "void-services.md" "$(grep -A1 '^From:' <<<"$out" | tail -n 1)"
req=$(last)
check "the local model should get the rule" has "Use only what the notes say" "$(jq -r '.body.messages[0].content' <<<"$req")"
check "the local model should get the nearest note" has "sudo ln -s /etc/sv/sshd" "$(jq -r '.body.messages[1].content' <<<"$req")"
check "six passages should be given" test "$(jq -r '.body.messages[1].content' <<<"$req" | grep -c '^<note ')" = 6
out=$(run ask-notes make -s index)
check "a second index should read nothing: $out" has "0 notes read" "$out"
out=$(run ask-notes make -s ask CLAUDE=1 QUESTION="How long does the loaf bake?")
check "--claude should print Claude's answer: $out" has "fake claude answer" "$out"
check "--claude should say the passages go to Anthropic: $out" has "go to Anthropic" "$out"
req=$(last)
check "Claude should get the rule as the system prompt" has "Use only what the notes say" "$(jq -r .body.system <<<"$req")"
check "Claude should get the loaf passage" has "240" "$(jq -r '.body.messages[0].content' <<<"$req")"

# Another folder: hidden and skipped folders stay out, and a change is read again.
v="$t/vault"; mkdir -p "$v/Admin" "$v/.obsidian" "$v/Work"
printf '# Bank\nThe account number is secret.\n' > "$v/Admin/bank.md"
printf '# Settings\nhidden\n' > "$v/.obsidian/app.md"
printf -- '---\ntags: [x]\n---\n# Meetings\nThe budget meeting is on Tuesday.\n' > "$v/Work/meetings.md"
# What Emacs leaves while a note has unsaved changes: a link to nowhere.
ln -s "user@host.1234:1700000000" "$v/Work/.#meetings.md"
printf '# Hidden\nhidden\n' > "$v/Work/.hidden.md"
out=$(run ask-notes make -s index NOTES="$v" SKIP=Admin)
check "another folder should start again: $out" has "starting again" "$out"
check "only the one note should be read (not Admin, .obsidian, an Emacs lock or a hidden note): $out" has "1 notes read" "$out"
out=$(run ask-notes make -s ask QUESTION="When is the budget meeting?")
check "the front matter shouldn't be in a passage" lacks "tags:" "$(jq -r '.body.messages[1].content' <<<"$(last)")"
check "the skipped folder shouldn't be in the answer's notes" lacks "account number" "$(jq -r '.body.messages[1].content' <<<"$(last)")"
echo "The budget meeting moved to Friday." >> "$v/Work/meetings.md"; touch -d '+1 min' "$v/Work/meetings.md"
out=$(run ask-notes make -s index NOTES="$v" SKIP=Admin)
check "a changed note should be read again: $out" has "1 notes read" "$out"
out=$(run ask-notes make -s ask QUESTION="When is the budget meeting?")
check "the changed note's new text should be found" has "Friday" "$(jq -r '.body.messages[1].content' <<<"$(last)")"
out=$(run ask-notes make -s clean)
check "make clean should remove notes.db" test ! -e "$t/ex/ask-notes/notes.db"

[ "$fail" = 0 ] && echo "dev-ai: claude (Python and shell), local, embeddings and ask-notes run against made-up servers: keys, models, fallbacks, streaming, the nearest notes, skips and changes, and every error says what to do"
exit "$fail"
