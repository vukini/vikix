# embeddings

Ten sentences turned into numbers by an embedding model, kept in SQLite
with sqlite-vec, and the three nearest to a question found: by meaning,
not by words. "something to eat" finds the bread and the soup, though
neither says eat.

    vikix add local-ai        # once: Ollama
    make setup                # once: the embedding model, all-minilm (46 MB)
    make run
    make run QUESTION="pets"
    make run QUESTION="What did we have for supper?"

This is how search by meaning works, and the first half of answering
from your own documents (`../ask-notes` does the rest). It runs on the
laptop: a thousand notes take about five minutes on an X1 Carbon.

all-minilm is small and quick, and weakest on a single word ("money"
finds nothing much): a few words, or a question, work better.
`EMBED_MODEL=nomic-embed-text make run` (274 MB, after `ollama pull
nomic-embed-text`) is a bigger model that tells meanings apart better.

Try: add your own sentences to `SENTENCES`; ask something in French.
Docs: https://alexgarcia.xyz/sqlite-vec/python.html
