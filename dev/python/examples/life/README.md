# life (Python)

What Python is known for: saying a lot in a few clear lines. Conway's
Game of Life: the board is a set, the neighbours a Counter, and every
generation comes from a generator that never ends; the caller takes five.

    make run

Try: take 40 generations instead of 5 and watch the glider cross the
board (it walks off the edge: make the board wrap round); start from
your own pattern; run it in JupyterLab (`jlab`) and draw the board with
matplotlib.
Docs: the tutorial's "Generators" section in `~/dev/python/docs/`; `pydoc itertools.islice`.
