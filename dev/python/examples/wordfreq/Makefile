# make        check the syntax (Python has nothing to build: it compiles as it runs)
# make run    run wordfreq.py on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove Python's cache

PYTHON ?= python3

build:
	$(PYTHON) -m py_compile wordfreq.py

run:
	$(PYTHON) wordfreq.py text.txt

check:
	$(PYTHON) wordfreq.py text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -rf __pycache__

.PHONY: build run check clean
