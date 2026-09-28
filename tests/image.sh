#!/usr/bin/env bash
# tests/image.sh — vikix-image opens nsxiv on the image's whole folder, in
# name order, at the image asked for; anything else goes to nsxiv as is.
#
# A fake nsxiv prints what it was given, so nothing opens on screen.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/pics & more"
cat > "$t/bin/nsxiv" <<'FAKE'
#!/bin/sh
echo "args: $*"
case " $* " in *" -i "*) sed 's|.*/|file: |' ;; esac
FAKE
chmod +x "$t/bin/nsxiv"
for f in b.png a.JPG c10.gif c9.webp notes.txt "with space.jpeg"; do touch "$t/pics & more/$f"; done
open() { PATH="$t/bin:$PATH" sh "$here/bin/vikix-image" "$@" </dev/null; }
fail=0

got=$(open "$t/pics & more/c9.webp")
want="args: -a -n 3 -i
file: a.JPG
file: b.png
file: c9.webp
file: c10.gif
file: with space.jpeg"
[ "$got" = "$want" ] || { echo "FAIL: one image didn't open with its folder:"; echo "$got" | sed 's/^/  /'; fail=1; }

got=$(open "$t/pics & more/notes.txt")
[ "$got" = "args: -a -- $t/pics & more/notes.txt" ] ||
  { echo "FAIL: a file that isn't an image wasn't passed on as it is: $got"; fail=1; }

got=$(open "$t/pics & more/a.JPG" "$t/pics & more/b.png")
[ "$got" = "args: -a -- $t/pics & more/a.JPG $t/pics & more/b.png" ] ||
  { echo "FAIL: two files weren't opened as just those two: $got"; fail=1; }

[ "$fail" = 0 ] && echo "image: one image opens with its folder, at its place; others go to nsxiv as they are"
exit "$fail"
