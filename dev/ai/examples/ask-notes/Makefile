# make         check the program (nothing to build)
# make setup   fetch the embedding model once (all-minilm, 46 MB)
# make index   read the notes into notes.db; NOTES=~/folder for yours, SKIP=Admin,Private to leave some out
# make ask     answer QUESTION from them, on this laptop; CLAUDE=1 for Claude
# make run     index, then ask (the sample notes, and a question about them)
# make clean   remove notes.db and Python's cache

NOTES ?= sample-notes
SKIP ?=
QUESTION ?= How do I switch on a service in Void?
EMBED_MODEL ?= all-minilm
export EMBED_MODEL

build:
	python3 -m py_compile notes.py

setup:
	ollama pull $(EMBED_MODEL)

index:
	uv run notes.py index "$(NOTES)" --skip "$(SKIP)"

ask:
	uv run notes.py ask "$(QUESTION)" $(if $(CLAUDE),--claude)

run: index ask

clean:
	rm -rf __pycache__ notes.db

.PHONY: build setup index ask run clean
