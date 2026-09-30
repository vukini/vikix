#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["anthropic==1.9.0", "sqlite-vec==0.1.9"]
# ///
"""notes.py: ask a folder of Markdown notes a question.

    uv run notes.py index ~/General --skip Admin     # once, then again after changes
    uv run notes.py ask "What did I note about runit?"
    uv run notes.py ask "..." --claude               # Claude writes the answer instead

index cuts each note into passages (at its headings), turns each into an
embedding with a model on this laptop, and keeps them in notes.db with
sqlite-vec. Run again, it only reads the notes that changed.

ask finds the passages nearest the question, and a model answers from
them alone, naming the notes it used. The local model by default:
nothing leaves the laptop. With --claude, those few passages (never the
whole folder) go to Anthropic.
"""
import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import sqlite_vec

HOST = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
BASE = HOST if HOST.startswith("http") else f"http://{HOST}"
EMBED_MODEL = os.environ.get("EMBED_MODEL", "all-minilm")
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5-5")
DB = os.environ.get("NOTES_DB", "notes.db")
PASSAGE = 1000          # characters: about what all-minilm reads at once
NEAREST = 6             # passages given to the model for each question

SYSTEM = """You answer questions from the user's own notes, given below in <note> tags.
Use only what the notes say. After each fact, name the note it came from in brackets, like [sourdough.md].
If the notes don't answer the question, say so plainly rather than guessing."""


# --- Ollama -------------------------------------------------------------------

def ollama(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    try:
        return urllib.request.urlopen(urllib.request.Request(BASE + path, data=data), timeout=600)
    except urllib.error.HTTPError as e:
        if e.code == 404 and path == "/api/embed":
            sys.exit(f"The model {EMBED_MODEL} isn't here yet: `ollama pull {EMBED_MODEL}` (or `make setup`).")
        sys.exit(f"Ollama said {e.code}: {e.read().decode(errors='replace').strip()}")
    except urllib.error.URLError:
        sys.exit("Ollama isn't answering: `vikix add local-ai`, or `vikix ai status`.")


def embed(texts):
    with ollama("/api/embed", {"model": EMBED_MODEL, "input": texts}) as r:
        return json.load(r)["embeddings"]


def chat_model():
    """OLLAMA_MODEL, or the first model here that writes text."""
    if os.environ.get("OLLAMA_MODEL"):
        return os.environ["OLLAMA_MODEL"]
    names = [m["name"] for m in json.load(ollama("/api/tags"))["models"]]
    chat = [n for n in names if "embed" not in n and "minilm" not in n]
    if not chat:
        sys.exit("No model to answer with: `vikix ai models` picks one (or use --claude).")
    return chat[0]


# --- the database ---------------------------------------------------------------

def connect():
    db = sqlite3.connect(DB)
    db.enable_load_extension(True)
    sqlite_vec.load(db)
    db.enable_load_extension(False)
    db.executescript("""
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, mtime REAL);
        CREATE TABLE IF NOT EXISTS passages (id INTEGER PRIMARY KEY, path TEXT, heading TEXT, text TEXT);
    """)
    return db


def meta(db, key):
    row = db.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return row and row[0]


def forget(db, path):
    """Drop a note's passages, their vectors and its row."""
    ids = [r[0] for r in db.execute("SELECT id FROM passages WHERE path = ?", (path,))]
    db.executemany("DELETE FROM vectors WHERE rowid = ?", [(i,) for i in ids])
    db.execute("DELETE FROM passages WHERE path = ?", (path,))
    db.execute("DELETE FROM files WHERE path = ?", (path,))


# --- cutting notes into passages -----------------------------------------------

def passages(text):
    """(heading, passage) pairs: a new passage at each heading, and when one
    grows past PASSAGE characters. YAML front matter is left out."""
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        end = next((i for i, l in enumerate(lines[1:], 1) if l.strip() == "---"), None)
        if end:
            lines = lines[end + 1:]
    heading, part, out = "", [], []

    def flush():
        body = "\n".join(part).strip()
        while body:
            cut = len(body) if len(body) <= PASSAGE else (body.rfind(" ", 0, PASSAGE) + 1 or PASSAGE)
            out.append((heading, body[:cut].strip()))
            body = body[cut:].strip()
        part.clear()

    for line in lines:
        if line.startswith("#") and line.lstrip("#").startswith(" "):
            flush()
            heading = line.lstrip("#").strip()
        else:
            part.append(line)
            if sum(len(p) for p in part) > PASSAGE:
                flush()
    flush()
    return out


# --- index --------------------------------------------------------------------------

def index(folder, skip):
    folder = Path(folder).expanduser().resolve()
    if not folder.is_dir():
        sys.exit(f"No folder {folder}")
    db = connect()
    # Another folder or another model means starting again: vectors from two
    # models can't be compared.
    if meta(db, "folder") not in (None, str(folder)) or meta(db, "model") not in (None, EMBED_MODEL):
        print(f"{DB} was for {meta(db, 'folder')} with {meta(db, 'model')}; starting again", file=sys.stderr)
        db.close()
        os.remove(DB)
        db = connect()

    notes = {}
    for p in folder.rglob("*.md"):
        rel = p.relative_to(folder)
        # Hidden files and folders (.obsidian, .git, and Emacs's .#note.md, a
        # link to nowhere while a note has unsaved changes), and --skip's.
        if rel.name.startswith(".") or any(part.startswith(".") or part in skip for part in rel.parts[:-1]):
            continue
        try:
            if p.is_file():
                notes[str(rel)] = p.stat().st_mtime
        except OSError:                          # gone since the folder was listed
            continue
    known = dict(db.execute("SELECT path, mtime FROM files"))
    for gone in known.keys() - notes.keys():
        forget(db, gone)
    todo = [n for n, m in notes.items() if known.get(n) != m]

    start, done, count = time.time(), 0, 0
    batch = []                                   # (path, heading, text)

    def store():
        nonlocal count
        # The note's name and heading go in with the text: a passage alone
        # often doesn't say what it's about.
        vectors = embed([f"{Path(p).stem} > {h}\n{t}" for p, h, t in batch])
        if meta(db, "dim") is None:
            db.execute(f"CREATE VIRTUAL TABLE vectors USING vec0(embedding float[{len(vectors[0])}] distance_metric=cosine)")
            db.executemany("INSERT INTO meta VALUES (?, ?)",
                           [("dim", str(len(vectors[0]))), ("model", EMBED_MODEL), ("folder", str(folder))])
        for (p, h, t), v in zip(batch, vectors):
            cur = db.execute("INSERT INTO passages (path, heading, text) VALUES (?, ?, ?)", (p, h, t))
            db.execute("INSERT INTO vectors (rowid, embedding) VALUES (?, ?)",
                       (cur.lastrowid, sqlite_vec.serialize_float32(v)))
        count += len(batch)
        batch.clear()

    for note in todo:
        if note in known:
            forget(db, note)
        try:
            text = (folder / note).read_text(errors="replace")
        except OSError as e:                     # gone, or unreadable: the next index tries again
            print(f"  skipped {note}: {e.strerror}", file=sys.stderr)
            continue
        batch.extend((note, h, t) for h, t in passages(text))
        if len(batch) >= 32:
            store()
        db.execute("INSERT INTO files VALUES (?, ?)", (note, notes[note]))
        done += 1
        if done % 100 == 0:
            db.commit()
            print(f"  {done}/{len(todo)} notes, {time.time() - start:.0f}s", file=sys.stderr)
    if batch:
        store()
    db.commit()
    total = db.execute("SELECT count(*) FROM passages").fetchone()[0]
    print(f"{len(todo)} notes read ({count} passages), {len(known.keys() - notes.keys())} gone, "
          f"{len(notes) - len(todo)} unchanged: {total} passages in {DB}")


# --- ask ----------------------------------------------------------------------------

def ask(question, claude):
    if not os.path.exists(DB):
        sys.exit(f"No {DB} yet: `uv run notes.py index FOLDER` (or `make index`) first.")
    db = connect()
    if meta(db, "dim") is None:
        sys.exit(f"{DB} has no notes in it: index a folder with some .md files.")
    found = db.execute("""
        SELECT passages.path, passages.heading, passages.text, vectors.distance
          FROM vectors JOIN passages ON passages.id = vectors.rowid
         WHERE vectors.embedding MATCH ? AND k = ?
         ORDER BY vectors.distance""",
        (sqlite_vec.serialize_float32(embed([question])[0]), NEAREST)).fetchall()

    notes = "\n\n".join(f'<note name="{p}" heading="{h}">\n{t}\n</note>' for p, h, t, _ in found)
    prompt = f"{notes}\n\nQuestion: {question}"
    if claude:
        answer_with_claude(prompt)
    else:
        answer_locally(prompt)

    print("\nFrom:", file=sys.stderr)
    for p, h, _, distance in found:
        print(f"  {distance:.3f}  {p}" + (f"  › {h}" if h else ""), file=sys.stderr)


def answer_locally(prompt):
    model = chat_model()
    print(f"({model}, on this laptop)\n", file=sys.stderr)
    with ollama("/api/chat", {"model": model, "options": {"temperature": 0.2},
                              "messages": [{"role": "system", "content": SYSTEM},
                                           {"role": "user", "content": prompt}]}) as r:
        for line in r:
            print(json.loads(line).get("message", {}).get("content", ""), end="", flush=True)
    print()


def answer_with_claude(prompt):
    import anthropic                          # only needed here
    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("No ANTHROPIC_API_KEY: run `vikix ai key set anthropic`, then open a new terminal.")
    print(f"({CLAUDE_MODEL}: these {NEAREST} passages go to Anthropic)\n", file=sys.stderr)
    extra = {}
    if CLAUDE_MODEL in ("claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"):
        # If the model's safety checks decline, the recommended model answers instead.
        extra = {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}
    try:
        with anthropic.Anthropic().beta.messages.stream(
            model=CLAUDE_MODEL, max_tokens=16000, system=SYSTEM,
            messages=[{"role": "user", "content": prompt}], **extra,
        ) as stream:
            for text in stream.text_stream:
                print(text, end="", flush=True)
            reply = stream.get_final_message()
    except anthropic.AuthenticationError:
        sys.exit("The key was refused: set it again with `vikix ai key set anthropic`.")
    except anthropic.APIStatusError as e:
        sys.exit(f"The API said {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        sys.exit("Couldn't reach Anthropic's API: is the network up?")
    print()
    if reply.stop_reason == "refusal":
        print("(Claude declined to answer that.)", file=sys.stderr)
    print(f"({reply.usage.input_tokens} tokens in, {reply.usage.output_tokens} out)", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description="Ask a folder of Markdown notes a question.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    i = sub.add_parser("index", help="read the notes (again: only what changed)")
    i.add_argument("folder")
    i.add_argument("--skip", default="", help="folders to leave out, by name: Admin,Readwise")
    a = sub.add_parser("ask", help="answer a question from the notes")
    a.add_argument("question", nargs="+")
    a.add_argument("--claude", action="store_true", help="Claude answers (the passages found go to Anthropic)")
    args = ap.parse_args()
    if args.cmd == "index":
        index(args.folder, {s.strip() for s in args.skip.split(",") if s.strip()})
    else:
        ask(" ".join(args.question), args.claude)


if __name__ == "__main__":
    main()
