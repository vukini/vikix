#!/usr/bin/env bash
# Translate docs/*.md into Esperanto using the local Ollama server.
# Run with --help for source, output, model and timeout options.
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
exec python3 - "$here" "$@" <<'PY'
import argparse
import json
import math
import os
import re
from pathlib import Path
import sys
import tempfile
import urllib.error
import urllib.request


def chunks(text, limit=12000):
    """Split at blank lines outside fenced code; never silently truncate a block."""
    blocks, block, fence, size = [], [], None, 0
    for line in text.splitlines(keepends=True):
        if fence is None and block and size + len(line) > limit:
            blocks.append("".join(block))
            block, size = [], 0
        match = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line.rstrip("\r\n"))
        if match:
            marker, rest = match.groups()
            if fence is None:
                if block:
                    blocks.append("".join(block))
                    block, size = [], 0
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence) and not rest.strip():
                fence = None
        block.append(line)
        size += len(line)
        if fence is None and (not line.strip() or match):
            blocks.append("".join(block))
            block, size = [], 0
    if block:
        blocks.append("".join(block))
    parts, current = [], ""
    for block in blocks:
        if re.match(r"^ {0,3}(`{3,}|~{3,})", block):
            if current.strip():
                parts.append(current)
                current = ""
            parts.append(block)
            continue
        if len(block) > limit:
            raise ValueError("a prose line exceeds 12000 characters; split it before translating")
        if current and len(current) + len(block) > limit:
            parts.append(current)
            current = ""
        current += block
    if current.strip():
        parts.append(current)
    if not parts:
        raise ValueError("source document is empty")
    return parts


def final_answer(text):
    """Accept plain Ollama text or the final channel of a raw Harmony reply."""
    if not isinstance(text, str):
        raise ValueError("Ollama returned no translation")
    if "<|channel|>" in text:
        marker = "<|channel|>final<|message|>"
        if marker not in text:
            raise ValueError("Ollama returned reasoning without a final answer")
        text = text.rsplit(marker, 1)[1]
        text = re.sub(r"(?:<\|(?:fim_suffix|end|im_end)\|>\s*)+$", "", text)
        if re.search(r"<\|(?:channel|message|start|end|fim_suffix|im_end)\|>", text):
            raise ValueError("Ollama returned malformed final-answer markers")
    # Some local models expose reasoning as a leading think block instead.
    if text.lstrip().startswith("<think>"):
        if "</think>" not in text:
            raise ValueError("Ollama returned unfinished reasoning")
        text = text.split("</think>", 1)[1].lstrip()
    if not text.strip():
        raise ValueError("Ollama returned an empty final answer")
    return text


def main():
    repo = Path(sys.argv.pop(1))
    parser = argparse.ArgumentParser(description=__doc__ or
        "Translate Vikix Markdown guides into Esperanto with Ollama.")
    parser.add_argument("--source", type=Path, default=repo / "docs")
    parser.add_argument("--output", type=Path, default=Path.home() / "vikix-guides-eo")
    parser.add_argument("--model", default=os.environ.get("OLLAMA_MODEL", "translategemma:27b"))
    parser.add_argument("--host", default="http://127.0.0.1:11434")
    parser.add_argument("--timeout", type=float, default=1800,
                        help="HTTP timeout in seconds (default: 1800)")
    parser.add_argument("--overwrite", action="store_true",
                        help="replace existing translations (otherwise skip them)")
    parser.add_argument("--dry-run", action="store_true",
                        help="list files without contacting Ollama or writing anything")
    args = parser.parse_args()
    source, output = args.source.expanduser().resolve(), args.output.expanduser().resolve()
    if not source.is_dir():
        parser.error(f"source directory does not exist: {source}")
    if output == source or source in output.parents or output in source.parents:
        parser.error("source and output directories must be separate, without nesting")
    if not args.model.strip():
        parser.error("model must not be empty")
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("timeout must be a positive finite number")
    files = sorted(p for p in source.rglob("*")
                   if p.suffix.lower() == ".md" and p.is_file()
                   and not p.is_symlink() and source in p.resolve().parents)
    if not files:
        parser.error(f"no Markdown guides found in {source}")
    translated = skipped = 0
    # Ignore proxy settings: these requests are intended for the local server.
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for src in files:
        dst = output / src.relative_to(source)
        if dst.exists() and not args.overwrite:
            existing = dst.read_text(encoding="utf-8")
            if "<|channel|>" in existing or existing.lstrip().startswith("<think>"):
                raise ValueError(f"existing translation contains model reasoning: {dst}; "
                                 "rerun with --overwrite to replace it")
            print(f"Skipping existing: {dst}", flush=True)
            skipped += 1
            continue
        if output not in dst.resolve().parents:
            raise ValueError(f"destination escapes output directory: {dst}")
        print(f"{'Would translate' if args.dry_run else 'Translating'}: {src} → {dst}", flush=True)
        parts = chunks(src.read_text(encoding="utf-8"))
        print(f"  {len(parts)} chunk(s)", flush=True)
        if args.dry_run:
            continue
        translations = []
        for index, part in enumerate(parts, 1):
            print(f"  Chunk {index}/{len(parts)}", flush=True)
            if re.match(r"^ {0,3}(`{3,}|~{3,})", part):
                translations.append(part)
                continue
            prompt = ("Translate the following document into Esperanto. Preserve Markdown "
                      "structure, code blocks, commands, paths, URLs and link targets unchanged. "
                      "Translate prose, headings and link labels. Output only the translated "
                      "document, without commentary or an enclosing code fence.\n\n---\n"
                      + part)
            if args.model.split(":", 1)[0].rsplit("/", 1)[-1] == "translategemma":
                # Language names/codes and two blank lines follow Ollama's prompt guide:
                # https://ollama.com/library/translategemma
                prompt = ("You are a professional English (en) to Esperanto (eo) translator. "
                          "Render the source faithfully in natural Esperanto. Keep Markdown "
                          "structure, inline code, commands, paths, URLs and link destinations "
                          "unchanged; translate headings and link labels. Return the translated "
                          "text alone.\nTranslate this English text into Esperanto:\n\n\n" + part)
            payload = json.dumps({"model": args.model, "prompt": prompt, "stream": False,
                                  "options": {"num_ctx": 32768}}).encode("utf-8")
            request = urllib.request.Request(args.host.rstrip("/") + "/api/generate",
                                             data=payload, headers={"Content-Type": "application/json"})
            try:
                with client.open(request, timeout=args.timeout) as response:
                    data = json.load(response)
            except urllib.error.HTTPError as exc:
                raise ValueError(f"Ollama returned HTTP {exc.code} for {src.name}; "
                                 "check the server and that the requested model is installed") from exc
            if not isinstance(data, dict):
                raise ValueError(f"invalid Ollama response for {src.name}")
            if data.get("error"):
                raise ValueError(f"Ollama error: {data['error']}")
            text = data.get("response")
            if not isinstance(text, str) or not text.strip():
                raise ValueError(f"Ollama returned no translation for {src.name}")
            if data.get("done") is not True or data.get("done_reason") == "length":
                raise ValueError(f"Ollama did not finish {src.name}; the document may need splitting")
            translations.append(final_answer(text))
        text = "\n\n".join(t.rstrip("\r\n") for t in translations) + "\n"
        dst.parent.mkdir(parents=True, exist_ok=True)
        temp = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="",
                                             dir=dst.parent, delete=False) as handle:
                temp = Path(handle.name)
                handle.write(text)
            temp.replace(dst)
        finally:
            if temp is not None:
                temp.unlink(missing_ok=True)
        translated += 1
    if args.dry_run:
        print(f"Dry run complete: {len(files)} guide(s), {skipped} existing file(s) skipped.")
    else:
        print(f"Translation complete: {translated} translated, {skipped} skipped. Output: {output}")


try:
    main()
except (OSError, ValueError, urllib.error.URLError) as exc:
    print(f"Translation failed: {exc}", file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("Translation interrupted.", file=sys.stderr)
    sys.exit(130)
PY
