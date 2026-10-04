#!/usr/bin/env bash
# tests/publish.sh — vikix publish: books from Markdown, EPUB and PDF.
#
#   The test book (tests/publish/: two tables, a listing, Esperanto,
#   Arabic) becomes an EPUB with its tables as row cards, its code without
#   highlighting (readers lose the spaces between spans) and indented, the right-to-left paragraph kept,
#   mimetype first and stored; one epubcheck rejects is kept as .rejected,
#   never as the book; the PDF builds in the face publish.yml names with
#   Amiri for the Arabic, and one Typst warned about (a face that isn't
#   there) is .rejected too; check builds both and leaves out/ alone; the
#   spelling goes to each language's dictionary, code never, and check
#   refuses a misspelt word until it's fixed or kept in words.txt; the
#   e-ink fix is still the doc-to-epub skill's file when the skill is at
#   hand; vikix publish NAME finds a book in ~/src by its folder or its
#   publish.yml's name, and --send puts it on a Kindle, a Kobo, a BOOX
#   over MTP or adb, or --to a folder (stand-ins for gio and adb); setup
#   refuses an epubcheck or dictionary download whose checksum differs,
#   asks for no sudo when the packages are there, and links the make
#   targets; uninstall takes away only what setup made.
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
  # The spelling (tested below), with a stand-in hunspell and small dictionaries: which
  # words reach which dictionary is Vikix's part (code never; the marked
  # Esperanto and Arabic to their own), and so are the words skipped (a
  # digit in them, one letter), words.txt, --keep and check refusing.
  dicts="$t/dicts"; mkdir -p "$dicts"
  cat > "$t/bin/hunspell" <<'X'
#!/usr/bin/env python3
import os, re, sys
a = sys.argv[1:]
d = a[a.index("-d") + 1]
with open(os.environ["SPELL_CALLS"], "a") as log:
    log.write("hunspell " + os.path.basename(d) + "\n")
known = {w.strip().lower() for w in open(d + ".dic", encoding="utf-8") if w.strip()}
if "-p" in a:
    known |= {w.strip().lower() for w in open(a[a.index("-p") + 1], encoding="utf-8") if w.strip()}
for w in re.findall(r"\w[\w']*", sys.stdin.read()):
    if w.lower() not in known:
        print(w)
X
  chmod +x "$t/bin/hunspell"
  printf '%s\n' a and arabic create command esperanto languages meaning since tables the what word are around \
    book boxes collapses does draws e every face in inch indentation ink it kind letters listing lists must of \
    one part read reader results screen second shows six smaller statements survive table this to uses whose has \
    typo > "$dicts/en_GB.dic"
  printf '%s\n' kaj la legas legi libro libron manĝas pri ĉiuĵaŭde ĉokoladon ĝardeno ŝi > "$dicts/eo.dic"
  printf '%s\n' الكتاب على الطاولة وأنا أقرأ كل يوم > "$dicts/ar.dic"
  : > "$dicts/en_GB.aff"; : > "$dicts/eo.aff"; : > "$dicts/ar.aff"
  export VIKIX_DICTS="$dicts" SPELL_CALLS="$t/spell-calls"

  cd "$book"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" python3 "$build" epub 2>&1) || true
  epub="$book/out/small-test-book.epub"
  check "the EPUB is built: $out" test -f "$epub"
  check "and epubcheck was asked" grep -q "^epubcheck .*\.epub" "$calls"
  python3 - "$epub" <<'PY' || fail=1
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
first = z.infolist()[0]
assert first.filename == "mimetype" and first.compress_type == zipfile.ZIP_STORED, "mimetype isn't first and stored"
pages = "".join(z.read(n).decode() for n in z.namelist() if n.startswith("EPUB/text/"))
assert "<table" not in pages, "a table is left: e-ink readers collapse them"
assert pages.count('class="row-card"') == 5, f"row cards: {pages.count('class=\"row-card\"')}, not 5"
assert 'class="field-label">Since<' in pages, "the column's name isn't on its field"
assert 'dir="rtl"' in pages and "الكتاب" in pages, "the Arabic paragraph lost its direction"
assert "Ĉiuĵaŭde" in pages, "the Esperanto letters"
code = re.findall(r"<pre[^>]*><code[^>]*>(.*?)</code></pre>", pages, re.S)
assert code and all("<span" not in c for c in code), "code is highlighted: e-ink readers and FBReader lose its spaces"
assert "\n        if row:\n            return" in code[0], "the listing lost its indentation"
css = "".join(z.read(n).decode() for n in z.namelist() if n.endswith(".css"))
assert "pre code" in css and "pre-wrap" in css, "the stylesheet doesn't keep code's spaces"
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
    out=$(PATH="$t/bin:$PATH" VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" python3 "$build" check 2>&1) || true
    check "check builds both: $out" grep -q "^check: small-test-book builds" <<<"$out"
    check "and leaves out/ alone" test ! -e out
  fi

  : > "$SPELL_CALLS"
  out=$(PATH="$t/bin:$PATH" python3 "$build" spell 2>&1)
  check "a book spelt right passes: $out" grep -q "^spelling: every word is known" <<<"$out"
  check "its Esperanto and Arabic went to their own dictionaries: $(sort -u "$SPELL_CALLS" | tr '\n' ' ')" \
    test "$(sort -u "$SPELL_CALLS" | tr '\n' ' ')" = "hunspell ar hunspell en_GB hunspell eo "
  printf '\nThis has a typo: sentance, in FTS5 and part V.\n' >> chapters/01-tables.md
  out=$(PATH="$t/bin:$PATH" python3 "$build" spell 2>&1) && fail=1
  check "a misspelt word is named, with its chapter: $out" grep -qE "^  sentance +01-tables$" <<<"$out"
  check "and only it (no code, no FTS5, no V)" test "$(grep -c '^  ' <<<"$out")" = 1
  out=$(PATH="$t/bin:$PATH" VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" python3 "$build" check 2>&1) && fail=1
  check "check refuses a book with a misspelt word: $out" grep -q "the spelling above wants a look" <<<"$out"
  out=$(PATH="$t/bin:$PATH" python3 "$build" spell --keep 2>&1) || fail=1
  check "--keep puts the word in words.txt: $(cat words.txt 2>/dev/null)" grep -qx sentance words.txt
  out=$(PATH="$t/bin:$PATH" python3 "$build" spell 2>&1) || true
  check "and then it is known: $out" grep -q "^spelling: every word is known" <<<"$out"
  rm -f words.txt; sed -i '/sentance/d' chapters/01-tables.md

  # vikix publish NAME: by the folder's name, by publish.yml's, and not
  # one that isn't there.
  cd "$t"
  : > "$calls"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" bash "$here/bin/vikix-publish" small epub 2>&1) || true
  check "vikix publish NAME finds ~/src/*/NAME: $out" test -f "$book/out/small-test-book.epub"
  rm -rf "$book/out"
  out=$(VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" bash "$here/bin/vikix-publish" small-test-book epub 2>&1) || true
  check "and by the name in its publish.yml: $out" test -f "$book/out/small-test-book.epub"
  # --send: a Kindle mounted as a drive takes it in documents/, a Kobo at
  # the top; with no drive, an MTP reader (a BOOX) in its storage's Books,
  # then one adb device; nothing plugged in is said; --to names a folder.
  media="$t/media"; mkdir -p "$media/KINDLE/documents" "$media/KINDLE/system"
  sendit() { PATH="$t/bin:$PATH" VIKIX_MEDIA="$media" VIKIX_GIO="$t/bin/gio" VIKIX_ADB="$t/bin/adb" \
    VIKIX_EPUBCHECK="$t/bin/epubcheck-ok" bash "$here/bin/vikix-publish" small "$@" 2>&1; }
  printf '#!/bin/sh\nexit 0\n' > "$t/bin/gio"; printf '#!/bin/sh\necho "List of devices attached"\n' > "$t/bin/adb"
  chmod +x "$t/bin/gio" "$t/bin/adb"
  out=$(sendit --send) || true
  check "--send puts it on a Kindle, in documents/: $out" test -f "$media/KINDLE/documents/small-test-book.epub"
  check "after building just the EPUB" test ! -e "$book/out/small-test-book.pdf"
  rm -rf "$media/KINDLE"; mkdir -p "$media/KOBOeReader/.kobo"
  out=$(sendit --send) || true
  check "on a Kobo, at the top: $out" test -f "$media/KOBOeReader/small-test-book.epub"
  rm -rf "$media/KOBOeReader"
  cat > "$t/bin/gio" <<X
#!/bin/sh
echo "gio \$*" >> "$calls"
case "\$1 \$2" in
  "mount -li") echo "Volume(0): BOOX"; echo "  activation_root=mtp://Onyx_BOOX_123/" ;;
  "list mtp://Onyx_BOOX_123/") echo "Internal shared storage" ;;
esac
exit 0
X
  : > "$calls"
  out=$(sendit --send) || true
  check "a BOOX over MTP, into its Books folder: $out" grep -q "^gio copy -- .*small-test-book.epub mtp://Onyx_BOOX_123/Internal shared storage/Books/$" "$calls"
  printf '#!/bin/sh\nexit 0\n' > "$t/bin/gio"
  cat > "$t/bin/adb" <<X
#!/bin/sh
echo "adb \$*" >> "$calls"
[ "\$1" = devices ] && printf 'List of devices attached\nABC123\tdevice\n'
exit 0
X
  : > "$calls"
  out=$(sendit --send) || true
  check "one with USB debugging, over adb: $out" grep -q "^adb push .*small-test-book.epub /sdcard/Books/$" "$calls"
  printf '#!/bin/sh\necho "List of devices attached"\n' > "$t/bin/adb"
  out=$(sendit --send) && fail=1
  check "nothing plugged in is said: $out" grep -q "no reader found" <<<"$out"
  mkdir -p "$t/reader"
  out=$(sendit --to "$t/reader") || true
  check "--to puts it in that folder: $out" test -f "$t/reader/small-test-book.epub"
  rm -rf "$book/out"

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
mkdir -p "$HOME/.local/share/vikix/epubcheck"
: > "$HOME/.local/share/vikix/epubcheck/epubcheck.jar"
sed -n 's/^EPUBCHECK_VERSION=//p' "$here/bin/vikix-publish" > "$HOME/.local/share/vikix/epubcheck/.vikix-version"
out=$(PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl" bash "$here/bin/vikix-publish" setup 2>&1) && fail=1
check "so is a dictionary whose checksum differs: $out" grep -q "en_GB.aff isn't the one it should be" <<<"$out"
check "and no dictionary is installed" test ! -e "$HOME/.local/share/vikix/hunspell"
rm -rf "$HOME/.local/share/vikix/epubcheck"
check "and nothing is installed" test ! -e "$HOME/.local/share/vikix/epubcheck"
check "no sudo when the packages are there" test -z "$(grep '^sudo' "$calls" || true)"
# As if the right release were already there: setup links the targets.
mkdir -p "$HOME/.local/share/vikix/epubcheck"
: > "$HOME/.local/share/vikix/epubcheck/epubcheck.jar"
sed -n 's/^EPUBCHECK_VERSION=//p' "$here/bin/vikix-publish" > "$HOME/.local/share/vikix/epubcheck/.vikix-version"
mkdir -p "$HOME/.local/share/vikix/hunspell"
sed -n 's/^DICTS_COMMIT=//p' "$here/bin/vikix-publish" > "$HOME/.local/share/vikix/hunspell/.vikix-commit"
out=$(PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl" bash "$here/bin/vikix-publish" setup 2>&1) || true
check "setup links the make targets: $out" test -f "$HOME/.local/share/vikix/publish/publish.mk"
check "and records the feature" grep -qx publish "$HOME/.config/vikix/features"
check "make epub runs the build from a project's Makefile" grep -q 'python3 $(VIKIX_PUBLISH)/build $@' "$HOME/.local/share/vikix/publish/publish.mk"
mkdir -p "$HOME/src/books/mine"; echo "keep" > "$HOME/src/books/mine/book.md"
PATH="$t/bin:$PATH" bash "$here/bin/vikix-publish" uninstall >/dev/null 2>&1 || true
check "uninstall takes the link, epubcheck and the dictionaries" test ! -e "$HOME/.local/share/vikix/publish" -a ! -e "$HOME/.local/share/vikix/epubcheck" -a ! -e "$HOME/.local/share/vikix/hunspell"
check "and leaves your books" test -f "$HOME/src/books/mine/book.md" -a -f "$book/publish.yml"
check "and the feature" bash -c '! grep -qx publish "$1"' _ "$HOME/.config/vikix/features"

[ "$fail" = 0 ] && echo "publish: the test book as an EPUB with row cards for e-ink and its Arabic right to left, a PDF with Amiri, rejected ones kept apart, check leaving out/ alone, books found by name, epubcheck's checksum checked"
exit "$fail"
