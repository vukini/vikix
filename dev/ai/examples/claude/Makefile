# make         check both programs (nothing to build: Python and bash run as they are)
# make run     ask Claude from Python; QUESTION="..." to ask your own
# make run-sh  the same from the shell, with curl and jq
# make clean   remove Python's cache

QUESTION ?= In two sentences: what is an API?

build:
	python3 -m py_compile ask.py
	bash -n ask.sh

run:
	uv run ask.py "$(QUESTION)" </dev/null

run-sh:
	./ask.sh "$(QUESTION)"

clean:
	rm -rf __pycache__

.PHONY: build run run-sh clean
