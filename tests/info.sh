#!/usr/bin/env bash
# tests/info.sh — the guides in docs/ make a clean Info manual:
#
#   - lib/md2texi.py and makeinfo turn them into vikix.info with no error
#     or warning, a node for every page and heading, and no Markdown left
#   - a link to a heading that isn't there, or a page the table doesn't
#     list, stops the build instead of making a broken manual
#   - 40-config, in a made-up home, installs it where INFOPATH points and
#     lists it in that folder's dir, and a second run changes nothing
#   - with Emacs here, its Info reader opens it and follows a link
#   - every diagram has its source, its picture drawn from that source
#     (the SHA-1 render.sh writes) and its text version, and is used
#   - makeinfo --html makes the web pages with no warning, and 40-config
#     installs them with the diagrams they show, once
#
# Needs makeinfo (the texinfo package).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# --- the manual from the real guides ------------------------------------------
python3 "$here/lib/md2texi.py" "$here/docs" > "$t/vikix.texi"
makeinfo --no-split -I "$here/docs" -o "$t/vikix.info" "$t/vikix.texi" 2> "$t/errors" ||
  { echo "FAIL: makeinfo failed:"; sed 's/^/  /' "$t/errors"; exit 1; }
[ -s "$t/errors" ] && { echo "FAIL: makeinfo warned:"; sed 's/^/  /' "$t/errors" | head -20; fail=1; }

# One node per page (Top is docs/README.md) and per heading of the others.
headings=$(for f in "$here"/docs/*.md; do
  [ "${f##*/}" = README.md ] && continue
  awk '/^```/ { code = !code } !code && /^#{1,3} /' "$f"
done | wc -l)
nodes=$(grep -c '^@node ' "$t/vikix.texi")
check "$nodes nodes for $headings headings and Top" test "$nodes" = $((headings + 1))
# Outside code: a code block may hold "[~a](~a)" (a Lisp format string).
check "Markdown links left in the manual" bash -c "! awk '/^@example/ { code = 1 } /^@end example/ { code = 0 } !code && /\\]\\(/' '$t/vikix.texi' | grep -q ."
check "Markdown bold left in the manual" bash -c "! grep -n '\*\*' '$t/vikix.texi' | grep -v '^[0-9]*:     '"

# --- broken guides stop the build ---------------------------------------------
cp -r "$here/docs" "$t/docs"
cp "$here/VERSION" "$t/VERSION"
echo 'See [nowhere](map.md#no-such-heading).' >> "$t/docs/fixing.md"
check "a link to a missing heading was let through" \
  bash -c "! python3 '$here/lib/md2texi.py' '$t/docs' >/dev/null 2>&1"
rm -rf "$t/docs"; cp -r "$here/docs" "$t/docs"
printf '# Stray\n\nNot in the table.\n' > "$t/docs/stray.md"
check "a page the table doesn't list was let through" \
  bash -c "! python3 '$here/lib/md2texi.py' '$t/docs' >/dev/null 2>&1"
rm -rf "$t/docs"; cp -r "$here/docs" "$t/docs"
printf '\n![Nothing](diagrams/no-such-diagram.svg)\n' >> "$t/docs/fixing.md"
check "a diagram with no files was let through" \
  bash -c "! python3 '$here/lib/md2texi.py' '$t/docs' >/dev/null 2>&1"
rm -rf "$t/docs"; cp -r "$here/docs" "$t/docs"
printf '\n![Nothing](shots/no-such-shot.png)\n' >> "$t/docs/fixing.md"
check "a screenshot that isn't there was let through" \
  bash -c "! python3 '$here/lib/md2texi.py' '$t/docs' >/dev/null 2>&1"
rm -rf "$t/docs"

# --- the diagrams -------------------------------------------------------------
# NAME.mmd is drawn as NAME.svg by docs/diagrams/render.sh, which ends the
# SVG with the source's SHA-1; NAME.txt is what Info shows instead.
for src in "$here"/docs/diagrams/*.mmd; do
  [ -e "$src" ] || continue
  n=$(basename "$src" .mmd)
  sum=$(sha1sum < "$src" | cut -d' ' -f1)
  check "docs/diagrams/$n.svg is missing or older than $n.mmd (run docs/diagrams/render.sh $n)" \
    grep -q "source sha1 $sum" "$here/docs/diagrams/$n.svg"
  check "docs/diagrams/$n.txt (the text version, for Info) is missing" test -s "$here/docs/diagrams/$n.txt"
  check "docs/diagrams/$n is used by no guide" grep -q "](diagrams/$n.svg)" "$here"/docs/*.md
done
for f in "$here"/docs/diagrams/*.svg "$here"/docs/diagrams/*.txt; do
  [ -e "$f" ] || continue
  n=$(basename "${f%.*}")
  check "docs/diagrams/${f##*/} has no $n.mmd" test -f "$here/docs/diagrams/$n.mmd"
done

# --- the web pages ------------------------------------------------------------
makeinfo --html --split=chapter -c NODE_FILES=0 --css-ref=guide.css -I "$here/docs" \
  -o "$t/html" "$t/vikix.texi" 2> "$t/errors" || { echo "FAIL: makeinfo --html failed:"; sed 's/^/  /' "$t/errors"; exit 1; }
[ -s "$t/errors" ] && { echo "FAIL: makeinfo --html warned:"; sed 's/^/  /' "$t/errors" | head -20; fail=1; }

# --- installed by 40-config ------------------------------------------------------
export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_DIR="$here"   # this checkout, not the installed ~/vikix
mkdir -p "$HOME"
bash "$here/install/40-config.sh" >/dev/null 2>"$t/stage-errors" || { echo "FAIL: 40-config failed:"; cat "$t/stage-errors"; exit 1; }
info="$HOME/.local/share/info"
check "40-config didn't install vikix.info" test -s "$info/vikix.info"
check "vikix.info isn't in the info dir" grep -q '(vikix)' "$info/dir"
first=$(sha1sum "$info/vikix.info" "$info/dir"; stat -c %Y "$info/vikix.info")
first_guide=$(stat -c %Y "$HOME/.local/share/vikix/guide/index.html" 2>/dev/null || true)
sleep 1
bash "$here/install/40-config.sh" >/dev/null 2>&1
second=$(sha1sum "$info/vikix.info" "$info/dir"; stat -c %Y "$info/vikix.info")
check "a second 40-config wrote the manual again" test "$first" = "$second"
check "the dir lists Vikix twice" test "$(grep -c '(vikix)' "$info/dir")" = 1
guide="$HOME/.local/share/vikix/guide"
check "40-config didn't install the web pages" test -s "$guide/index.html"
check "the web pages have no stylesheet" test -s "$guide/guide.css"
for img in $(grep -oh '<img [^>]*src="[^"]*"' "$guide"/*.html | sed 's/.*src="//; s/"$//' | sort -u); do
  check "the web pages show $img, which isn't there" test -s "$guide/$img"
done
check "a second 40-config wrote the web pages again" test "$first_guide" = "$(stat -c %Y "$guide/index.html")"

# vikix.bash puts it on INFOPATH, keeping the system's manuals (the empty entry).
got=$(HOME="$HOME" INFOPATH='' bash --norc -ic ". '$here/config/bash/vikix.bash' 2>/dev/null; . '$here/config/bash/vikix.bash' 2>/dev/null; echo \"\$INFOPATH\"" 2>/dev/null)
check "INFOPATH after vikix.bash, twice, is '$got'" test "$got" = "$info:"

# --- vikix.dev/guide/: the same pages, with a bar back to the site -----------------
# lib/build-guide.sh, as the website's workflow runs it (pages.yml).
bash "$here/lib/build-guide.sh" "$t/site-guide" --site
for f in "$t"/site-guide/*.html; do
  check "$(basename "$f") on the site should have the bar back to vikix.dev" grep -q 'class="site-bar"' "$f"
done
check "the machine's pages shouldn't have the site's bar" bash -c "! grep -lq 'site-bar' '$guide'/*.html"
check "the site's guide should have the diagrams" test -f "$t/site-guide/diagrams/vikix-eval.svg"
# Every screenshot a guide shows is in docs/shots/ and goes with the pages.
for f in $(grep -oh 'shots/[a-z0-9-]*\.png' "$here"/docs/*.md | sort -u); do
  check "the guides show $f, which should be in the pages" test -f "$t/site-guide/$f"
  check "the web pages should show $f" grep -q "src=\"$f\"" "$t"/site-guide/*.html
done
for f in index.html gallery.html; do
  check "site/$f should link to the guide" grep -q 'href="guide/"' "$here/site/$f"
done
for f in $(grep -oh 'href="guide/[A-Za-z0-9-]*\.html' "$here"/site/*.html | sed 's/href="guide\///' | sort -u); do
  check "the site links to guide/$f, which the guide should have" test -f "$t/site-guide/$f"
done
check "the website's workflow should build the guide" grep -q 'lib/build-guide.sh site/guide --site' "$here/.github/workflows/pages.yml"
# A failed build leaves the old pages: md2texi can't read a missing docs/.
mkdir -p "$t/fake/lib" "$t/fake/docs"; cp "$here/lib/build-guide.sh" "$here/lib/md2texi.py" "$t/fake/lib/"
echo old > "$t/kept"; mkdir -p "$t/old-guide"; cp "$t/kept" "$t/old-guide/index.html"
bash "$t/fake/lib/build-guide.sh" "$t/old-guide" >/dev/null 2>&1 && { echo "FAIL: a guide built from no guides"; fail=1; }
check "a failed build should leave the old pages" cmp -s "$t/kept" "$t/old-guide/index.html"

# --- Emacs reads it ---------------------------------------------------------------
if command -v emacs >/dev/null; then
  got=$(INFOPATH="$info:" emacs -Q --batch --eval '(progn (info "vikix") (search-forward "Where everything is") (Info-follow-nearest-node) (princ Info-current-node))' 2>/dev/null)
  check "Emacs didn't open the manual and follow a link (got '$got')" test "$got" = "Where everything is"
fi

[ "$fail" = 0 ] && echo "info: the guides make a clean Info manual and web pages, the diagrams are drawn from their sources, 40-config installs both, vikix.dev/guide/ is the same pages with a bar back to the site, and Emacs reads the manual"
exit "$fail"
