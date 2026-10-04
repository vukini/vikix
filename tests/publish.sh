#!/usr/bin/env bash
# tests/publish.sh — vikix publish: books from Markdown, EPUB and PDF.
#
#   The test book (tests/publish/: two tables, Esperanto, Arabic) becomes
#   an EPUB with its tables as row cards, the right-to-left paragraph kept,
#   mimetype first and stored; one epubcheck rejects is kept as .rejected,
#   never as the book; the PDF builds in the face publish.yml names with
#   Amiri for the Arabic, and one Typst warned about (a face that isn't
#   there) is .rejected too; check builds both and leaves out/ alone; the
#   e-ink fix is still the doc-to-epub skill's file when the skill is at
#   hand; vikix publish NAME finds a book in ~/src by its folder or its
#   publish.yml's name; setup refuses an epubcheck download whose checksum
#   differs, asks for no sudo when the packages are there, and links the
#   make targets; uninstall takes away only what setup made.
#
# epubcheck and curl are stand-ins (the real one is Java, a minute to
# start; the download is the network). The building needs pandoc, Typst
# and Python's bs4, lxml and yaml: without them that part is skipped.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
real_home=$HOME   # for the doc-to-epub skill, when it is synced here
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$t/bin" "$VIKIX_STATE" "$HOME/src/books"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
build="$here/lib/publish/build"

printf '#!/bin/sh\necho "epubcheck $*" >> %s\necho "No errors or warnings detected."\n' "$calls" > "$t/bin/epubcheck-ok"
printf '#!/bin/sh\necho "ERROR(RSC-005): a made-up error"\nexit 1\n' > "$t/bin/epubcheck-no"
chmod +x "$t/bin/"*

# The book, in a project folder of its own (as ~/src/living-series/NAME).
book="$HOME/src/books/small"
cp -r "$here/tests/publish" "$book"
# A face every machine with Typst has, so the test doesn't need Plex.
face=$(fc-list : family 2>/dev/null | grep -m1 -oE '^DejaVu Serif$|^Noto Serif$|^Liberation Serif$' || true)

if command -v pandoc >/dev/null && command -v typst >/dev/null && python3 -c 'import bs4, lxml, yaml' 2>/dev/null; then
  cd "$book"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" python3 "$build" epub 2>&1) || true
  epub="$book/out/small-test-book.epub"
  check "the EPUB is built: $out" test -f "$epub"
  check "and epubcheck was asked" grep -q "^epubcheck .*\.epub" "$calls"
  python3 - "$epub" <<'PY' || fail=1
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
first = z.infolist()[0]
assert first.filename == "mimetype" and first.compress_type == zipfile.ZIP_STORED, "mimetype isn't first and stored"
pages = "".join(z.read(n).decode() for n in z.namelist() if n.startswith("EPUB/text/"))
assert "<table" not in pages, "a table is left: e-ink readers collapse them"
assert pages.count('class="row-card"') == 5, f"row cards: {pages.count('class=\"row-card\"')}, not 5"
assert 'class="field-label">Since<' in pages, "the column's name isn't on its field"
assert 'dir="rtl"' in pages and "الكتاب" in pages, "the Arabic paragraph lost its direction"
assert "Ĉiuĵaŭde" in pages, "the Esperanto letters"
PY
  rm -f "$epub"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-no" python3 "$build" epub 2>&1) && fail=1
  check "one epubcheck rejects isn't the book: $out" test ! -e "$epub" -a -f "$epub.rejected"
  check "and it says why" grep -q "RSC-005" <<<"$out"
  rm -f "$epub.rejected"

  if [ -n "$face" ]; then
    printf 'mainfont: %s\n' "$face" >> publish.yml
    out=$(python3 "$build" pdf 2>&1) || true
    pdf="$book/out/small-test-book.pdf"
    check "the PDF is built: $out" test -f "$pdf"
    if fc-list : family | grep -qx Amiri && command -v pdffonts >/dev/null; then
      check "the Arabic is set in Amiri: $(pdffonts "$pdf" | awk 'NR>2{print $1}' | tr '\n' ' ')" grep -q Amiri <<<"$(pdffonts "$pdf")"
    fi
    sed -i 's/^mainfont: .*/mainfont: No Such Face Anywhere/' publish.yml
    rm -f "$pdf"
    out=$(python3 "$build" pdf 2>&1) && fail=1
    check "a PDF Typst warned about isn't the book: $out" test ! -e "$pdf" -a -f "$pdf.rejected"
    sed -i "s/^mainfont: .*/mainfont: $face/" publish.yml
    rm -rf out
    out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" python3 "$build" check 2>&1) || true
    check "check builds both: $out" grep -q "^check: small-test-book builds" <<<"$out"
    check "and leaves out/ alone" test ! -e out
  fi

  # vikix publish NAME: by the folder's name, by publish.yml's, and not
  # one that isn't there.
  cd "$t"
  : > "$calls"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" bash "$here/bin/vikix-publish" small epub 2>&1) || true
  check "vikix publish NAME finds ~/src/*/NAME: $out" test -f "$book/out/small-test-book.epub"
  rm -rf "$book/out"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" bash "$here/bin/vikix-publish" small-test-book epub 2>&1) || true
  check "and by the name in its publish.yml: $out" test -f "$book/out/small-test-book.epub"
  out=$(bash "$here/bin/vikix-publish" no-such-book 2>&1) && fail=1
  check "a book that isn't there is said: $out" grep -q "no book called no-such-book" <<<"$out"
else
  echo "(publish: no pandoc, Typst, or bs4/lxml/yaml: the building isn't tried)"
fi

# The e-ink fix is the doc-to-epub skill's: the same file, while it's at hand.
skill=$(find "$real_home"/.claude/skills -path '*doc-to-epub/scripts/fix_tables.py' 2>/dev/null | head -1 || true)
if [ -n "$skill" ]; then
  check "fix-tables.py is still the skill's ($skill)" cmp -s "$skill" "$here/lib/publish/fix-tables.py"
fi

# setup: the packages are there (no sudo); a download that isn't epubcheck
# is refused; the make targets linked. uninstall takes only what it made.
printf '#!/bin/sh\nexit 0\n' > "$t/bin/xbps-query"
printf '#!/bin/sh\necho "sudo $*" >> %s\n' "$calls" > "$t/bin/sudo"
printf '#!/bin/sh\nwhile [ $# -gt 1 ]; do [ "$1" = -o ] && { echo not-epubcheck > "$2"; exit 0; }; shift; done\n' > "$t/bin/curl"
chmod +x "$t/bin/"*
: > "$calls"
out=$(PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl" bash "$here/bin/vikix-publish" setup 2>&1) && fail=1
check "a download whose checksum differs is refused: $out" grep -q "checksum differs" <<<"$out"
check "and nothing is installed" test ! -e "$HOME/.local/share/vikix/epubcheck"
check "no sudo when the packages are there" test -z "$(grep '^sudo' "$calls" || true)"
# As if the right release were already there: setup links the targets.
mkdir -p "$HOME/.local/share/vikix/epubcheck"
: > "$HOME/.local/share/vikix/epubcheck/epubcheck.jar"
sed -n 's/^EPUBCHECK_VERSION=//p' "$here/bin/vikix-publish" > "$HOME/.local/share/vikix/epubcheck/.vikix-version"
out=$(PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl" bash "$here/bin/vikix-publish" setup 2>&1) || true
check "setup links the make targets: $out" test -f "$HOME/.local/share/vikix/publish/publish.mk"
check "and records the feature" grep -qx publish "$HOME/.config/vikix/features"
check "make epub runs the build from a project's Makefile" grep -q 'python3 $(VIKIX_PUBLISH)/build $@' "$HOME/.local/share/vikix/publish/publish.mk"
mkdir -p "$HOME/src/books/mine"; echo "keep" > "$HOME/src/books/mine/book.md"
PATH="$t/bin:$PATH" bash "$here/bin/vikix-publish" uninstall >/dev/null 2>&1 || true
check "uninstall takes the link and epubcheck" test ! -e "$HOME/.local/share/vikix/publish" -a ! -e "$HOME/.local/share/vikix/epubcheck"
check "and leaves your books" test -f "$HOME/src/books/mine/book.md" -a -f "$book/publish.yml"
check "and the feature" bash -c '! grep -qx publish "$1"' _ "$HOME/.config/vikix/features"

[ "$fail" = 0 ] && echo "publish: the test book as an EPUB with row cards for e-ink and its Arabic right to left, a PDF with Amiri, rejected ones kept apart, check leaving out/ alone, books found by name, epubcheck's checksum checked"
exit "$fail"
