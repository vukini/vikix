#!/usr/bin/env bash
# lib/build-guide.sh — the guides in docs/ as web pages.
#
#   lib/build-guide.sh OUT [--site]
#
# docs/ goes through lib/md2texi.py and makeinfo --html: one page a
# chapter, index.html first, styled by docs/guide.css, with the diagrams.
# 40-config writes them to ~/.local/share/vikix/guide/ (Super+m → Vikix
# guide in the browser); the website's workflow (.github/workflows/
# pages.yml) writes them to site/guide/, as vikix.dev/guide/, with --site:
# a bar on each page that leads back to the site. Same words either way:
# docs/ is the source.
#
# OUT is replaced only when the build worked. Needs python3 and makeinfo
# (texinfo).

set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:?usage: lib/build-guide.sh OUT [--site]}
site=${2:-}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 "$here/lib/md2texi.py" "$here/docs" > "$tmp/vikix.texi"
# NODE_FILES=0: no extra page a node, so index.html is the start.
makeinfo --html --split=chapter -c NODE_FILES=0 --css-ref=guide.css \
  -I "$here/docs" -o "$tmp/guide" "$tmp/vikix.texi"
cp "$here/docs/guide.css" "$tmp/guide/"
mkdir -p "$tmp/guide/diagrams"
cp "$here"/docs/diagrams/*.svg "$tmp/guide/diagrams/" 2>/dev/null || true

if [ "$site" = --site ]; then
  # The bar goes right after <body ...>, on every page.
  bar='<header class="site-bar"><a class="site-home" href="../">vikix<span>.</span></a><a href="./">Guide</a><a href="../#install">Install</a><a href="https://github.com/vukini/vikix">Source</a></header>'
  for f in "$tmp"/guide/*.html; do
    BAR=$bar perl -0pi -e 's/(<body[^>]*>)/$1\n$ENV{BAR}/' "$f"
    grep -q 'class="site-bar"' "$f" || { echo "no <body> in $f" >&2; exit 1; }
  done
fi

# Only now, with every page made: the old guide stays if anything failed.
if [ -d "$out" ] && diff -rq "$tmp/guide" "$out" >/dev/null 2>&1; then exit 0; fi
mkdir -p "$(dirname "$out")"
rm -rf "$out"
mv "$tmp/guide" "$out"
