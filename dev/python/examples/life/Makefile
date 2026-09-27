# make        check the syntax (Python has nothing to build: it compiles as it runs)
# make run    run life.py: the first five generations of a glider
# make clean  remove Python's cache

PYTHON ?= python3

build:
	$(PYTHON) -m py_compile life.py

run:
	$(PYTHON) life.py

clean:
	rm -rf __pycache__

.PHONY: build run clean
