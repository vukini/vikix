"""life.py — Conway's Game of Life, with generators.

A generator is a function that `yield`s its results one at a time and
pauses in between, so it can describe an endless series: here, every
generation of the board, forever. The caller takes only as many as it
wants (itertools.islice).

The board is a set of (row, column) cells that are alive. Each step a cell
lives on with 2 or 3 live neighbours, and a dead one comes alive with 3.
"""
import itertools
import time
from collections import Counter

GLIDER = {(0, 1), (1, 2), (2, 0), (2, 1), (2, 2)}
ROWS, COLS = 10, 20


def generations(cells):
    """Every generation after CELLS, one at a time, without end."""
    while True:
        yield cells
        # How many live neighbours each cell has, counted from the live ones.
        near = Counter((r + dr, c + dc)
                       for r, c in cells
                       for dr in (-1, 0, 1) for dc in (-1, 0, 1)
                       if (dr, dc) != (0, 0))
        cells = {cell for cell, n in near.items()
                 if n == 3 or (n == 2 and cell in cells)}


def show(n, cells):
    print(f"generation {n}")
    for r in range(ROWS):
        print("".join("#" if (r, c) in cells else "." for c in range(COLS)))
    print()


if __name__ == "__main__":
    for n, cells in enumerate(itertools.islice(generations(GLIDER), 5)):
        show(n, cells)
        time.sleep(0.2)
