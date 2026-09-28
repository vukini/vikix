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
#
# Needs makeinfo (the texinfo package).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# --- the manual from the real guides ------------------------------------------
python3 "$here/lib/md2texi.py" "$here/docs" > "$t/vikix.texi"
makeinfo --no-split -o "$t/vikix.info" "$t/vikix.texi" 2> "$t/errors" ||
  { echo "FAIL: makeinfo failed:"; sed 's/^/  /' "$t/errors"; exit 1; }
[ -s "$t/errors" ] && { echo "FAIL: makeinfo warned:"; sed 's/^/  /' "$t/errors" | head -20; fail=1; }

# One node per page (Top is docs/README.md) and per heading of the others.
headings=$(for f in "$here"/docs/*.md; do
  [ "${f##*/}" = README.md ] && continue
  awk '/^```/ { code = !code } !code && /^#{1,3} /' "$f"
done | wc -l)
nodes=$(grep -c '^@node ' "$t/vikix.texi")
check "$nodes nodes for $headings headings and Top" test "$nodes" = $((headings + 1))
check "Markdown links left in the manual" bash -c "! grep -n '](' '$t/vikix.texi'"
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

# --- installed by 40-config ------------------------------------------------------
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME"
bash "$here/install/40-config.sh" >/dev/null 2>"$t/stage-errors" || { echo "FAIL: 40-config failed:"; cat "$t/stage-errors"; exit 1; }
info="$HOME/.local/share/info"
check "40-config didn't install vikix.info" test -s "$info/vikix.info"
check "vikix.info isn't in the info dir" grep -q '(vikix)' "$info/dir"
first=$(sha1sum "$info/vikix.info" "$info/dir"; stat -c %Y "$info/vikix.info")
sleep 1
bash "$here/install/40-config.sh" >/dev/null 2>&1
second=$(sha1sum "$info/vikix.info" "$info/dir"; stat -c %Y "$info/vikix.info")
check "a second 40-config wrote the manual again" test "$first" = "$second"
check "the dir lists Vikix twice" test "$(grep -c '(vikix)' "$info/dir")" = 1

# vikix.bash puts it on INFOPATH, keeping the system's manuals (the empty entry).
got=$(HOME="$HOME" INFOPATH='' bash --norc -ic ". '$here/config/bash/vikix.bash' 2>/dev/null; . '$here/config/bash/vikix.bash' 2>/dev/null; echo \"\$INFOPATH\"" 2>/dev/null)
check "INFOPATH after vikix.bash, twice, is '$got'" test "$got" = "$info:"

# --- Emacs reads it ---------------------------------------------------------------
if command -v emacs >/dev/null; then
  got=$(INFOPATH="$info:" emacs -Q --batch --eval '(progn (info "vikix") (search-forward "Where everything is") (Info-follow-nearest-node) (princ Info-current-node))' 2>/dev/null)
  check "Emacs didn't open the manual and follow a link (got '$got')" test "$got" = "Where everything is"
fi

[ "$fail" = 0 ] && echo "info: the guides make a clean Info manual, 40-config installs it, and Emacs reads it"
exit "$fail"
