# make         check the program (nothing to build)
# make setup   fetch the embedding model once (all-minilm, 46 MB)
# make run     the three sentences nearest a question; QUESTION="..." for yours
# make clean   remove Python's cache

QUESTION ?= something to eat
EMBED_MODEL ?= all-minilm

build:
	python3 -m py_compile embed.py

setup:
	ollama pull $(EMBED_MODEL)

run:
	EMBED_MODEL=$(EMBED_MODEL) uv run embed.py "$(QUESTION)"

clean:
	rm -rf __pycache__

.PHONY: build setup run clean
