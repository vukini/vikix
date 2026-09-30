#!/usr/bin/env python3
"""tests/fake-ai.py — a made-up Claude API and Ollama on one port, for the
tests of the AI examples and `note` (tests/dev-ai.sh, tests/notes.sh).
Prints its port, then logs each POST (path, key, beta header, body) to
the file named first, one JSON line each. Its embeddings count words
(hashed into 64 numbers), so text sharing words is nearest.

    python3 tests/fake-ai.py LOG > PORT_FILE &
"""
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
