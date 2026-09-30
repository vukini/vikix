#!/usr/bin/env bash
# docs/diagrams/render.sh [NAME ...] — draw each NAME.mmd as NAME.svg.
#
# For whoever writes the guides, on a machine with Node and Chromium; a
# Vikix install never runs it, since the SVGs are committed. Without
# names it draws every diagram whose SVG is missing or older than its
# source. Each SVG ends with the source's SHA-1, so tests/info.sh can
# tell when a .mmd changed and its picture wasn't drawn again.
#
# The colours are paper's (mermaid.json), on paper's background, so a
# diagram reads the same on GitHub, in the browser guide and in either
# theme. Chromium is the system's (puppeteer.json): nothing is downloaded
# but mermaid-cli itself, into npm's cache.

set -euo pipefail
cd "$(dirname "$0")"
MERMAID_CLI=@mermaid-js/mermaid-cli@11.17.0

command -v npx >/dev/null || { echo "render.sh: needs npx (nodejs)" >&2; exit 1; }
[ -x /usr/bin/chromium ] || { echo "render.sh: needs /usr/bin/chromium" >&2; exit 1; }

if [ $# -gt 0 ]; then
  names=("$@")
else
  names=()
  for src in *.mmd; do
    n=${src%.mmd}
    [ -s "$n.svg" ] && [ "$n.svg" -nt "$src" ] && continue
    names+=("$n")
  done
fi
[ ${#names[@]} -gt 0 ] || { echo "render.sh: every diagram is up to date"; exit 0; }

for n in "${names[@]}"; do
  [ -f "$n.mmd" ] || { echo "render.sh: no $n.mmd" >&2; exit 1; }
  PUPPETEER_SKIP_DOWNLOAD=1 npx -y "$MERMAID_CLI" -q -i "$n.mmd" -o "$n.svg" \
    -c mermaid.json -p puppeteer.json -b '#eff1f5'
  printf '\n<!-- source sha1 %s -->\n' "$(sha1sum < "$n.mmd" | cut -d' ' -f1)" >> "$n.svg"
  echo "drew $n.svg"
done
