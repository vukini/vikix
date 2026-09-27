# make        check the syntax (Python has nothing to build: it compiles as it runs)
# make run    run hello.py
# make clean  remove Python's cache

PYTHON ?= python3

build:
	$(PYTHON) -m py_compile hello.py

run:
	$(PYTHON) hello.py 

clean:
	rm -rf __pycache__

.PHONY: build run clean
