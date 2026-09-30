#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["anthropic==1.9.0", "sqlite-vec==0.1.9"]
# ///
"""notes.py — what `note` (bin/vikix-notes) runs, with uv: ask a folder of
Markdown notes a question. ~/dev/ai/examples/ask-notes is the same idea
made small, to read and learn from; this is the one to use every day.

    index [FOLDER] [--skip A,B]   read the notes that changed into the index
    ask QUESTION [--local|--claude]
    find QUESTION                 the nearest notes, with no answer
    status

The folder and what to skip are the user's, in ~/.config/vikix/notes
(written by the first `note index FOLDER`). The index is Vikix's, in
~/.local/share/vikix/notes/index.db: passages of the notes and their
embeddings (all-minilm, on this laptop, through Ollama). Who answers
follows Super+i (~/.config/vikix/ai: use=local or use=claude, model=);
--local and --claude choose for one question. Locally nothing leaves the
laptop; with Claude, the passages found (never the whole folder) go to
Anthropic.
"""
import argparse
import json
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import NoReturn

import sqlite_vec

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "vikix"
CONF = CONFIG / "notes"
AI_CONF = CONFIG / "ai"
DB = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "vikix/notes/index.db"
HOST = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
BASE = HOST if HOST.startswith("http") else f"http://{HOST}"
CLAUDE_DEFAULT = "claude-sonnet-5"        # as Super+i's (bin/vikix-ask)
LOCAL_DEFAULT = "llama3.2:3b"
PASSAGE = 1000                            # characters: about what all-minilm reads at once
NEAREST = 6                               # passages given to the model for each question

SYSTEM = """You answer questions from the user's own notes, given below in <note> tags.
Use only what the notes say. After each fact, name the note it came from in brackets, like [Daily/2026-09-30.md].
If the notes don't answer the question, say so plainly rather than guessing."""

CONF_TEXT = """# ~/.config/vikix/notes — what `note index` reads. Yours to edit;
# `note index FOLDER --skip A,B` writes the first two lines too.
#
#   folder   the folder of Markdown notes (an Obsidian vault)
#   skip     folders to leave out, by name, commas between: never read,
#            so never sent anywhere (hidden ones, like .obsidian, always are)
#   embed    the embedding model (all-minilm: small and quick;
#            nomic-embed-text: finds better, slower). A change reads
#            every note again at the next `note index`.
folder={folder}
skip={skip}
embed=all-minilm
"""


def die(msg) -> NoReturn:
    sys.exit(f"note: {msg}")


def read_conf(path):
    out = {}
    try:
        for line in path.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return out


def set_conf(key, value):
    text = CONF.read_text()
    new, n = re.subn(rf"^[ \t]*{key}[ \t]*=.*$", f"{key}={value}", text, flags=re.M)
    CONF.write_text(new if n else text.rstrip("\n") + f"\n{key}={value}\n")


# --- Ollama -------------------------------------------------------------------

def ollama(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    try:
        return urllib.request.urlopen(urllib.request.Request(BASE + path, data=data), timeout=600)
    except urllib.error.HTTPError as e:
        if e.code == 404 and path == "/api/embed":
            die(f"the embedding model {body['model']} isn't here: ollama pull {body['model']}")
        die(f"Ollama said {e.code}: {e.read().decode(errors='replace').strip()}")
    except urllib.error.URLError:
        die("local AI isn't answering: vikix ai status (or vikix add local-ai)")


def embed(model, texts):
    with ollama("/api/embed", {"model": model, "input": texts}) as r:
        return json.load(r)["embeddings"]


# --- the index ------------------------------------------------------------------

def connect():
    DB.parent.mkdir(parents=True, exist_ok=True)
    DB.parent.chmod(0o700)                 # passages of your notes: yours alone
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
    ids = [r[0] for r in db.execute("SELECT id FROM passages WHERE path = ?", (path,))]
    db.executemany("DELETE FROM vectors WHERE rowid = ?", [(i,) for i in ids])
    db.execute("DELETE FROM passages WHERE path = ?", (path,))
    db.execute("DELETE FROM files WHERE path = ?", (path,))


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


def settings():
    """The folder, what to skip and the embedding model, from the user's file."""
    conf = read_conf(CONF)
    if not conf.get("folder"):
        die("no folder yet: note index ~/Notes (the first time; --skip Private,Admin leaves some out)")
    folder = Path(conf["folder"]).expanduser().resolve()
    skip = {s.strip() for s in conf.get("skip", "").split(",") if s.strip()}
    return folder, skip, conf.get("embed") or "all-minilm"


def cmd_index(folder_arg, skip_arg):
    if folder_arg:
        folder = Path(folder_arg).expanduser().resolve()
        if not folder.is_dir():
            die(f"no folder {folder_arg}")
        shown = str(folder).replace(str(HOME), "~", 1) if str(folder).startswith(str(HOME)) else str(folder)
        if not CONF.exists():
            CONF.parent.mkdir(parents=True, exist_ok=True)
            CONF.write_text(CONF_TEXT.format(folder=shown, skip=skip_arg or ""))
        else:
            set_conf("folder", shown)
            if skip_arg is not None:
                set_conf("skip", skip_arg)
    elif skip_arg is not None:
        if not CONF.exists():
            die("no folder yet: note index ~/Notes --skip " + skip_arg)
        set_conf("skip", skip_arg)
    folder, skip, model = settings()
    if not folder.is_dir():
        die(f"the folder in {CONF} isn't there: {folder}")

    db = connect()
    # Another folder or another model: start again (vectors from two models
    # can't be compared).
    if meta(db, "folder") not in (None, str(folder)) or meta(db, "model") not in (None, model):
        print(f"the index was for {meta(db, 'folder')} with {meta(db, 'model')}: starting again", file=sys.stderr)
        db.close()
        DB.unlink()
        db = connect()

    notes = {}
    for p in folder.rglob("*.md"):
        rel = p.relative_to(folder)
        # Hidden files and folders (.obsidian, .git, Emacs's .#note.md lock
        # links), and the folders skip names.
        if rel.name.startswith(".") or any(x.startswith(".") or x in skip for x in rel.parts[:-1]):
            continue
        try:
            if p.is_file():
                notes[str(rel)] = p.stat().st_mtime
        except OSError:
            continue
    known = dict(db.execute("SELECT path, mtime FROM files"))
    gone = known.keys() - notes.keys()
    for g in gone:
        forget(db, g)
    todo = [n for n, m in notes.items() if known.get(n) != m]
    if todo and len(todo) > 200:
        print(f"reading {len(todo)} notes: about {len(todo) * 0.3 / 60:.0f} minutes the first time", file=sys.stderr)

    start, done, count, batch = time.time(), 0, 0, []

    def store():
        nonlocal count
        vectors = embed(model, [f"{Path(p).stem} > {h}\n{t}" for p, h, t in batch])
        if meta(db, "dim") is None:
            db.execute(f"CREATE VIRTUAL TABLE vectors USING vec0(embedding float[{len(vectors[0])}] distance_metric=cosine)")
            db.executemany("INSERT INTO meta VALUES (?, ?)",
                           [("dim", str(len(vectors[0]))), ("model", model), ("folder", str(folder))])
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
        except OSError as e:
            print(f"  skipped {note}: {e.strerror}", file=sys.stderr)
            continue
        batch.extend((note, h, t) for h, t in passages(text))
        if len(batch) >= 32:
            store()
        db.execute("INSERT INTO files VALUES (?, ?)", (note, notes[note]))
        done += 1
        if done % 100 == 0:
            db.commit()                          # a stopped index keeps what it read
            print(f"  {done}/{len(todo)} notes, {time.time() - start:.0f}s", file=sys.stderr)
    if batch:
        store()
    db.execute("INSERT OR REPLACE INTO meta VALUES ('indexed', ?)", (str(int(time.time())),))
    db.commit()
    total = db.execute("SELECT count(*) FROM passages").fetchone()[0]
    print(f"{done} notes read, {len(gone)} gone, {len(notes) - len(todo)} unchanged: "
          f"{len(notes)} notes, {total} passages")


def nearest(question):
    if not DB.exists():
        die("no index yet: note index ~/Notes")
    db = connect()
    if meta(db, "dim") is None:
        die("the index is empty: note index (the folder has no .md notes?)")
    return db.execute("""
        SELECT passages.path, passages.heading, passages.text, vectors.distance
          FROM vectors JOIN passages ON passages.id = vectors.rowid
         WHERE vectors.embedding MATCH ? AND k = ?
         ORDER BY vectors.distance""",
        (sqlite_vec.serialize_float32(embed(meta(db, "model"), [question])[0]), NEAREST)).fetchall()


def show_sources(found, out):
    for p, h, _, distance in found:
        print(f"  {distance:.2f}  {p}" + (f"  › {h}" if h else ""), file=out)


def cmd_find(question):
    found = nearest(question)
    folder = read_conf(CONF).get("folder", "")
    print(f"Nearest in {folder}:" if folder else "Nearest:")
    show_sources(found, sys.stdout)


def who_answers(force):
    """('local', model) or ('claude', model): Super+i's choice unless forced."""
    ai = read_conf(AI_CONF)
    use = force or (ai.get("use") or "local").lower()
    model = ai.get("model", "")
    if use == "claude":
        return "claude", model if model.startswith("claude") else CLAUDE_DEFAULT
    if model and not model.startswith("claude"):
        return "local", model
    names = [m["name"] for m in json.load(ollama("/api/tags"))["models"]]
    chat = [n for n in names if "embed" not in n and "minilm" not in n]
    if not chat:
        die("no local model to answer with: vikix ai models (or note ask --claude)")
    return "local", LOCAL_DEFAULT if LOCAL_DEFAULT in chat else chat[0]


def cmd_ask(question, force):
    kind, model = who_answers(force)
    if kind == "claude" and not os.environ.get("ANTHROPIC_API_KEY"):
        die("Claude needs your key: vikix ai key set anthropic (then a new terminal), or note ask --local")
    found = nearest(question)
    notes = "\n\n".join(f'<note name="{p}" heading="{h}">\n{t}\n</note>' for p, h, t, _ in found)
    prompt = f"{notes}\n\nQuestion: {question}"
    where = "on this laptop" if kind == "local" else f"these {len(found)} passages went to Anthropic"
    print(f"({model}, {where})\n", file=sys.stderr)
    (ask_claude if kind == "claude" else ask_local)(model, prompt)
    print("\nFrom:", file=sys.stderr)
    show_sources(found, sys.stderr)


def ask_local(model, prompt):
    with ollama("/api/chat", {"model": model, "options": {"temperature": 0.2},
                              "messages": [{"role": "system", "content": SYSTEM},
                                           {"role": "user", "content": prompt}]}) as r:
        for line in r:
            print(json.loads(line).get("message", {}).get("content", ""), end="", flush=True)
    print()


def ask_claude(model, prompt):
    import anthropic
    extra = {}
    if model in ("claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"):
        # If the model's safety checks decline, the recommended model answers instead.
        extra = {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}
    try:
        with anthropic.Anthropic().beta.messages.stream(
            model=model, max_tokens=16000, system=SYSTEM,
            messages=[{"role": "user", "content": prompt}], **extra,
        ) as stream:
            for text in stream.text_stream:
                print(text, end="", flush=True)
            reply = stream.get_final_message()
    except anthropic.AuthenticationError:
        die("the key was refused: vikix ai key set anthropic")
    except anthropic.RateLimitError:
        die("too many requests just now (or no credit left): try again in a minute")
    except anthropic.APIStatusError as e:
        die(f"the API said {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        die("couldn't reach Anthropic: is the network up? (note ask --local works offline)")
    print()
    if reply.stop_reason == "refusal":
        print("(Claude declined to answer that.)", file=sys.stderr)


def cmd_status():
    conf = read_conf(CONF)
    print(f"folder:  {conf.get('folder') or '(none yet: note index ~/Notes)'}")
    print(f"skip:    {conf.get('skip') or '-'}")
    if not DB.exists():
        print("index:   none yet")
        return
    db = connect()
    notes = db.execute("SELECT count(*) FROM files").fetchone()[0]
    total = db.execute("SELECT count(*) FROM passages").fetchone()[0]
    when = meta(db, "indexed")
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(int(when))) if when else "not finished"
    print(f"index:   {notes} notes, {total} passages, {meta(db, 'model') or '-'}; last read {when}")
    print(f"         {DB} ({DB.stat().st_size / 1e6:.1f} MB)")
    kind, model = who_answers(None) if notes else ("-", "-")
    print(f"answers: {model} ({'on this laptop' if kind == 'local' else 'Claude: the passages found go to Anthropic'})")


def main():
    ap = argparse.ArgumentParser(prog="note")
    sub = ap.add_subparsers(dest="cmd", required=True)
    i = sub.add_parser("index")
    i.add_argument("folder", nargs="?")
    i.add_argument("--skip")
    for name in ("ask", "find"):
        a = sub.add_parser(name)
        a.add_argument("question", nargs="+")
        if name == "ask":
            g = a.add_mutually_exclusive_group()
            g.add_argument("--claude", action="store_const", const="claude", dest="force")
            g.add_argument("--local", action="store_const", const="local", dest="force")
    sub.add_parser("status")
    args = ap.parse_args()
    if args.cmd == "index":
        cmd_index(args.folder, args.skip)
    elif args.cmd == "ask":
        cmd_ask(" ".join(args.question), args.force)
    elif args.cmd == "find":
        cmd_find(" ".join(args.question))
    else:
        cmd_status()


if __name__ == "__main__":
    main()
