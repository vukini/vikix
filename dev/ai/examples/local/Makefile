# make         check both programs (nothing to build)
# make run     ask the local model from Python; QUESTION="..." to ask your own
# make run-sh  the same from the shell, with curl and jq
# make clean   remove Python's cache

QUESTION ?= In two sentences: what is an API?

build:
	python3 -m py_compile chat.py
	bash -n chat.sh

run:
	python3 chat.py "$(QUESTION)"

run-sh:
	./chat.sh "$(QUESTION)"

clean:
	rm -rf __pycache__

.PHONY: build run run-sh clean
