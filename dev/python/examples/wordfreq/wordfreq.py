"""wordfreq.py — the ten most common words in a text file.

A word is a run of letters, compared in lower case. collections.Counter
does the counting; sorted() with a key puts the most common first.

    python3 wordfreq.py text.txt
"""
import re
import sys
from collections import Counter

if len(sys.argv) != 2:
    sys.exit("usage: wordfreq.py FILE")

with open(sys.argv[1]) as f:
    words = re.findall(r"[a-z]+", f.read().lower())

counts = Counter(words)
# The higher count first (hence the minus); the same count in alphabetical order.
for word, count in sorted(counts.items(), key=lambda wc: (-wc[1], wc[0]))[:10]:
    print(f"{count:4d} {word}")
