#!/usr/bin/env bash
# Exercise translate-guides-to-epo.sh against an isolated Ollama stand-in.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's
here=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$here/translate-guides-to-epo.sh" <<'PY'
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

script = sys.argv[1]
requests = []
reply = {"response": "# Gvidilo\n\nSaluton, mondo!\n", "done": True, "done_reason": "stop"}
status = 200
fail_at = None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        assert self.path == "/api/generate"
        requests.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
        self.send_response(status)
        self.end_headers()
        body = {"error": "later chunk failed"} if len(requests) == fail_at else reply
        self.wfile.write(json.dumps(body).encode())


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever)
thread.start()
try:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        source, output = root / "docs", root / "eo"
        source.mkdir()
        original = '# Hello\n\nA "quote", a backslash \\ and ĉ.\n'
        (source / "first-hour.md").write_text(original)
        (source / "nested").mkdir()
        (source / "nested" / "space name.MD").write_text("Second guide\n")
        (source / "guide.css").write_text("ignored")
        (source / "private.md").symlink_to(root / "outside.md")
        (root / "outside.md").write_text("Do not read")
        base = [script, "--source", str(source), "--output", str(output),
                "--host", f"http://127.0.0.1:{server.server_port}",
                "--model", "test-model", "--timeout", "5"]

        def run(*extra, ok=True):
            result = subprocess.run(base + list(extra), capture_output=True, text=True, timeout=15)
            assert (result.returncode == 0) == ok, (result.stdout, result.stderr)
            return result

        run("--dry-run")
        assert not output.exists() and not requests
        run()
        assert len(requests) == 2
        assert requests[0]["model"] == "test-model"
        assert requests[0]["prompt"].endswith(original)
        assert requests[0]["stream"] is False
        assert (output / "first-hour.md").read_text() == reply["response"]
        assert (output / "nested" / "space name.MD").exists()
        run()
        assert len(requests) == 2, "existing files should be skipped"
        expected = "# Gvidilo\n\nSaluton, mondo!\n"
        for answer in (
            "<|channel|>analysis<|message|>Private reasoning."
            "<|end|><|start|>assistant<|channel|>final<|message|>" + expected,
            "<|channel|>final<|message|>" + expected + "<|fim_suffix|>",
            "<think>Private reasoning.</think>\n" + expected,
        ):
            reply = {"response": answer, "done": True}
            run("--overwrite")
            assert (output / "first-hour.md").read_text() == expected
        contaminated = "<|channel|>analysis<|message|>Unfinished reasoning"
        (output / "first-hour.md").write_text(contaminated)
        before = len(requests)
        result = run(ok=False)
        assert "--overwrite" in result.stderr and len(requests) == before
        assert (output / "first-hour.md").read_text() == contaminated
        reply = {"response": expected, "done": True}
        run("--overwrite")
        for reply in ({"error": "model missing"}, {}, [],
                      {"response": "", "done": True},
                      {"response": "<|channel|>analysis<|message|>Only reasoning", "done": True},
                      {"response": "<|channel|>final<|message|>", "done": True},
                      {"response": "<think>Only reasoning", "done": True},
                      {"response": "<think>Only reasoning</think>", "done": True},
                      {"response": "<|channel|>final<|message|>Bad<|start|>", "done": True},
                      {"response": "partial", "done": False},
                      {"response": "partial", "done": True, "done_reason": "length"}):
            result = run("--overwrite", ok=False)
            assert "Translation complete" not in result.stdout
            assert (output / "first-hour.md").read_text() == "# Gvidilo\n\nSaluton, mondo!\n"
        status = 500
        run("--overwrite", ok=False)
        status = 200
        assert not list(output.glob("tmp*"))
        # Large documents use multiple requests, with code fences kept whole.
        reply = {"response": "Peco\n", "done": True}
        long_source = root / "long"
        long_source.mkdir()
        code = "```sh\n" + "echo hi\n" * 800 + "```\n\n"
        (long_source / "long.md").write_text("A" * 7000 + "\n\n" + code + "B" * 7000 + "\n")
        before = len(requests)
        run("--source", str(long_source))
        assert len(requests) == before + 2
        assert all(code not in r["prompt"] for r in requests[before:])
        assert (output / "long.md").read_text() == "Peco\n\n" + code.rstrip() + "\n\nPeco\n"
        # Failure on a later chunk must preserve the whole existing file.
        fail_at = len(requests) + 2
        run("--source", str(long_source), "--overwrite", ok=False)
        assert (output / "long.md").read_text() == "Peco\n\n" + code.rstrip() + "\n\nPeco\n"
        fail_at = None
        (long_source / "long.md").write_text("X" * 12001)
        run("--source", str(long_source), "--overwrite", ok=False)
        assert (output / "long.md").read_text() == "Peco\n\n" + code.rstrip() + "\n\nPeco\n"
        run("--output", str(source), ok=False)
        run("--output", str(source / "eo"), ok=False)
        run("--timeout", "0", ok=False)
        run("--timeout", "nan", ok=False)
        empty = root / "empty"
        empty.mkdir()
        run("--source", str(empty), ok=False)
        run("--source", str(root / "missing"), ok=False)
    print("guide translation: file selection, JSON, final answers, output, resume and failures passed")
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
    assert not thread.is_alive()
PY
