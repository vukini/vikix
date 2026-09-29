#!/usr/bin/env python3
"""nvim-lock.py — Neovim's lazy-lock.json, Vikix's plugins apart from yours.

  nvim-lock.py untouched SAVED LOCK   exit 0 when every plugin in SAVED (the
                                      lock Vikix last left) that LOCK has is
                                      still at SAVED's commit
  nvim-lock.py merge NEW SAVED LOCK   NEW (the lock Vikix tested now), plus
                                      LOCK's plugins that neither NEW nor
                                      SAVED names (the ones you added), in
                                      lazy.nvim's own layout

Lazy rewrites the lock whenever a plugin is added or removed, not only on
:Lazy update, so the file as a whole says little: only the versions of
Vikix's plugins decide whether the lock is still Vikix's.
"""
import json
import sys


def load(path):
    with open(path) as f:
        return json.load(f)


def untouched(saved, lock):
    return all(lock[name] == entry for name, entry in saved.items() if name in lock)


def merge(new, saved, lock):
    out = dict(new)
    for name, entry in lock.items():
        if name not in new and name not in saved:
            out[name] = entry
    return out


def dump(lock):
    # As lazy.nvim writes it: sorted, one plugin a line.
    lines = ['  %s: { "branch": %s, "commit": %s }' % (
        json.dumps(name), json.dumps(entry.get("branch", "")), json.dumps(entry.get("commit", "")))
        for name, entry in sorted(lock.items())]
    return "{\n" + ",\n".join(lines) + "\n}\n"


def main(argv):
    if len(argv) == 3 and argv[0] == "untouched":
        return 0 if untouched(load(argv[1]), load(argv[2])) else 1
    if len(argv) == 4 and argv[0] == "merge":
        sys.stdout.write(dump(merge(load(argv[1]), load(argv[2]), load(argv[3]))))
        return 0
    sys.stderr.write(__doc__ or "")
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, AttributeError) as e:
        sys.stderr.write("nvim-lock.py: %s\n" % e)
        sys.exit(2)
