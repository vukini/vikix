#!/usr/bin/env python3
"""tests/lib/waits.py — StumpWM's main thread never waits on a program.

  python3 -I tests/lib/waits.py FILE.lisp...

Reads each Lisp file of the layer (no Lisp needed: a small walk over
parentheses, strings and comments) and finds every run-shell-command whose
last argument is t: one that waits for the program and collects its output.
In StumpWM everything happens in one thread, so such a call holds every
key and the bar for as long as the program takes (and 30 s when something
is stuck). It is allowed only inside the functions named in ALLOWED, each
with its reason; anything else should run the program through
vikix-shell-then or vikix-later (commands.lisp) and go on in a callback.
Prints the places that aren't allowed, FILE:LINE in FUNCTION, and exits 1;
with none, one line saying how many are allowed, and exits 0.
"""
import re
import sys

ALLOWED = {
    # The helpers: they run the program from a thread of their own.
    "vikix-shell-line": "the bar's rounds and vikix-later's thunks call it, in their thread",
    "vikix-shell-then": "runs it in a thread of vikix-later's",
    # Two places that wait, each for a reason.
    "vikix-set-font": "at a load, 3 ms once bin/vikix-font has made the file (seconds at the very first login)",
    "vikix-snapshot-file": "the errors menu: git on the snapshots' own repository, milliseconds",
}


def calls(src):
    """(line, function, form) for each run-shell-command in SRC that waits."""
    found = []
    i, n, depth, top = 0, len(src), 0, None
    while i < n:
        c = src[i]
        if c == ";":
            while i < n and src[i] != "\n":
                i += 1
        elif c == '"':
            i = string_end(src, i)
        elif c == "#" and i + 1 < n and src[i + 1] == "\\":
            i += 3
        elif c == "#" and i + 1 < n and src[i + 1] == "|":
            j = src.find("|#", i)
            i = j + 2 if j >= 0 else n
        elif c == "(":
            depth += 1
            m = re.match(r"\((?:defun|defcommand|defmacro|defvar|defparameter)\s+([^\s()]+)", src[i:])
            if m and depth == 1:
                top = m.group(1)
            if src.startswith("(run-shell-command", i):
                j = form_end(src, i)
                form = src[i:j + 1]
                if re.search(r"\s+t\s*\)$", form):
                    found.append((src.count("\n", 0, i) + 1, top, form))
            i += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                top = None
            i += 1
        else:
            i += 1
    return found


def string_end(src, i):
    """The index after the string starting at I."""
    i += 1
    while i < len(src) and src[i] != '"':
        if src[i] == "\\":
            i += 1
        i += 1
    return i + 1


def form_end(src, i):
    """The index of the parenthesis closing the form starting at I."""
    d = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == '"':
            i = string_end(src, i)
            continue
        if c == ";":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "#" and i + 1 < n and src[i + 1] == "\\":
            i += 3
            continue
        if c == "(":
            d += 1
        elif c == ")":
            d -= 1
            if d == 0:
                return i
        i += 1
    return n - 1


def main(files):
    bad, allowed = [], 0
    for path in files:
        for line, function, form in calls(open(path, encoding="utf-8").read()):
            if function in ALLOWED:
                allowed += 1
            else:
                bad.append(f"{path}:{line}: in {function or 'a top-level form'}: {form.splitlines()[0][:80]}")
    if bad:
        print("\n".join(bad))
        print("use vikix-shell-then or vikix-later (commands.lisp): the program in a thread, the rest in a callback")
        return 1
    print(f"{allowed} run-shell-command wait(s), each in a function allowed to ({', '.join(sorted(ALLOWED))})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
