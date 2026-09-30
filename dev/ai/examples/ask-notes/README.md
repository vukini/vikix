# ask-notes

Ask a folder of Markdown notes a question, and get an answer from them,
with the notes it came from. It works on four sample notes here, and on
an Obsidian vault just the same.

    vikix add local-ai          # once: Ollama, and a model (vikix ai models)
    make setup                  # once: the embedding model (46 MB)
    make run                    # the sample notes: "How do I switch on a service in Void?"
    make ask QUESTION="How long does the loaf bake?"

Your own notes:

    make index NOTES=~/General SKIP=Admin,Readwise     # first time: about 5 minutes a thousand notes
    make ask QUESTION="What did I write about runit?"
    make index NOTES=~/General SKIP=Admin,Readwise     # later: only the notes that changed

How it works, in `notes.py`:

1. **index** cuts each note into passages at its headings, turns each
   passage into an embedding (`../embeddings`) and keeps it in `notes.db`
   with sqlite-vec. Hidden folders (`.obsidian`, `.git`) are left out, and
   so are the ones `SKIP` names.
2. **ask** turns the question into an embedding too, takes the six
   passages nearest it, and gives them to a model with the question and
   one rule: answer from these notes only, and name them.

**Private by default.** The local model answers, and nothing leaves the
laptop. `make ask CLAUDE=1` has Claude answer instead, which is much
better at it: then those six passages, never the whole folder, go to
Anthropic. Leave out folders you'd never send (`SKIP=Admin`) when you
index.

A small local model sometimes mixes things up or ignores the rule; the
list of notes it prints lets you check.

Try: `NEAREST` in `notes.py` gives the model more or fewer passages;
`EMBED_MODEL=nomic-embed-text` finds better ones (then index again,
from scratch: vectors from two models can't be mixed).
