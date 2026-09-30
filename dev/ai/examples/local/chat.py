#!/usr/bin/env python3
"""chat.py: a question to a model on this laptop, through Ollama's API.
Nothing leaves the machine, and it needs no library: Ollama answers plain
HTTP on 127.0.0.1:11434, one line of JSON per piece of the answer.

    python3 chat.py "Why is the sky blue?"
    OLLAMA_MODEL=llama3.2:3b python3 chat.py "..."
"""
import json
import os
import sys
import urllib.error
import urllib.request

HOST = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
BASE = HOST if HOST.startswith("http") else f"http://{HOST}"


def call(path, body=None):
    """POST body (or GET, without one) to Ollama; the open response."""
    data = None if body is None else json.dumps(body).encode()
    try:
        return urllib.request.urlopen(urllib.request.Request(BASE + path, data=data), timeout=300)
    except urllib.error.HTTPError as e:
        sys.exit(f"Ollama said {e.code}: {e.read().decode(errors='replace').strip()}")
    except urllib.error.URLError:
        sys.exit("Ollama isn't answering: `vikix add local-ai`, or `vikix ai status`.")


def pick_model():
    """OLLAMA_MODEL, or the first model here that writes text (not an embedding one)."""
    if os.environ.get("OLLAMA_MODEL"):
        return os.environ["OLLAMA_MODEL"]
    names = [m["name"] for m in json.load(call("/api/tags"))["models"]]
    chat = [n for n in names if "embed" not in n and "minilm" not in n]
    if not chat:
        sys.exit("No model yet: `vikix ai models` picks one that fits this laptop.")
    return chat[0]


def main():
    question = " ".join(sys.argv[1:]) or "In two sentences: what is an API?"
    model = pick_model()
    reply = call("/api/chat", {"model": model, "messages": [{"role": "user", "content": question}]})
    for line in reply:                       # streamed: one JSON object a line
        piece = json.loads(line)
        print(piece.get("message", {}).get("content", ""), end="", flush=True)
        if piece.get("done"):
            secs = piece.get("eval_duration", 0) / 1e9
            rate = piece.get("eval_count", 0) / secs if secs else 0
            print(f"\n({model}: {piece.get('eval_count', 0)} tokens, {rate:.0f} a second)", file=sys.stderr)


if __name__ == "__main__":
    main()
