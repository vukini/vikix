#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["sqlite-vec==0.1.9"]
# ///
"""embed.py: sentences turned into numbers, kept in SQLite, and the
nearest ones found for a question.

An embedding model reads a text and gives back a list of numbers (384
of them for all-minilm): texts that mean similar things get lists that
point the same way, even with no word in common. sqlite-vec keeps them
in a table and finds the nearest.

    uv run embed.py "something to eat"
"""
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request

import sqlite_vec

HOST = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
BASE = HOST if HOST.startswith("http") else f"http://{HOST}"
MODEL = os.environ.get("EMBED_MODEL", "all-minilm")

SENTENCES = [
    "The cat slept all afternoon in a patch of sun.",
    "My dog barks at the postman every morning.",
    "Fresh bread is best eaten while still warm.",
    "She made a pot of lentil soup for dinner.",
    "The train to Lisbon was delayed by an hour.",
    "We cycled along the river to the next village.",
    "Rust checks at compile time that memory is used safely.",
    "A linked list keeps a pointer to the next node.",
    "The stock market fell sharply on Monday.",
    "Interest rates stayed the same this quarter.",
]


def embed(texts):
    """The embeddings of texts, one list of numbers each, from Ollama."""
    body = json.dumps({"model": MODEL, "input": texts}).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(f"{BASE}/api/embed", data=body), timeout=300) as r:
            return json.load(r)["embeddings"]
    except urllib.error.HTTPError as e:
        if e.code == 404:
            sys.exit(f"The model {MODEL} isn't here yet: `ollama pull {MODEL}` (or `make setup`).")
        sys.exit(f"Ollama said {e.code}: {e.read().decode(errors='replace').strip()}")
    except urllib.error.URLError:
        sys.exit("Ollama isn't answering: `vikix add local-ai`, or `vikix ai status`.")


def main():
    question = " ".join(sys.argv[1:]) or "something to eat"
    vectors = embed(SENTENCES + [question])
    *vectors, asked = vectors
    print(f"{MODEL}: {len(asked)} numbers for each sentence; the first few of the question's:")
    print("  " + ", ".join(f"{x:.3f}" for x in asked[:6]) + ", ...\n")

    db = sqlite3.connect(":memory:")
    db.enable_load_extension(True)
    sqlite_vec.load(db)
    db.enable_load_extension(False)
    # A vec0 table holds the vectors; cosine distance compares only their
    # direction: 0 is the same meaning, 2 the opposite.
    db.execute(f"CREATE VIRTUAL TABLE sentences USING vec0(embedding float[{len(asked)}] distance_metric=cosine)")
    for i, v in enumerate(vectors):
        db.execute("INSERT INTO sentences(rowid, embedding) VALUES (?, ?)", (i, sqlite_vec.serialize_float32(v)))

    nearest = db.execute(
        "SELECT rowid, distance FROM sentences WHERE embedding MATCH ? AND k = 3 ORDER BY distance",
        (sqlite_vec.serialize_float32(asked),),
    ).fetchall()
    print(f"Nearest to “{question}”:")
    for rowid, distance in nearest:
        print(f"  {distance:.3f}  {SENTENCES[rowid]}")


if __name__ == "__main__":
    main()
