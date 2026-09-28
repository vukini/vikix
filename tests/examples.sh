#!/usr/bin/env bash
# tests/examples.sh — every example in dev/*/examples/ builds and runs with its
# Makefile, every wordfreq prints exactly expected.txt, and every language
# folder has its README and tools.list in the right shape.
#
# Each example is copied to a made-up folder first, so nothing is built in
# the checkout. A language whose compiler isn't installed is skipped, and
# said so. The Lazarus window (pascal/clicker) is skipped too: it needs a
# display, and lazbuild would write into your own ~/.lazarus.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
fail=0 built=0 skipped=()

# The commands each language's examples need (all of them, if several).
declare -A needs=([c]=cc [rust]=cargo [go]=go [pascal]=fpc [python]=python3
                  [zig]=zig [haskell]=cabal [ocaml]=dune [java]=gradle [julia]=julia
                  [lisp]=sbcl [scheme]=scheme [racket]=raco [picolisp]=pil [forth]=gforth
                  [javascript]=node [ruby]=ruby [lua]=lua5.4 [sql]=sqlite3
                  [wasm]="wasmtime wat2wasm zig")
# pil is built into ~/.local/bin (65-languages), which a test's PATH may lack.
export PATH="$HOME/.local/bin:$PATH"
# The Java examples share one Gradle daemon (much faster than one each),
# stopped when the test ends, so none is left running.
trap 'rm -rf "$t"; command -v gradle >/dev/null && gradle --quiet --stop >/dev/null 2>&1 || true' EXIT

for dir in "$here"/dev/*/examples/*/; do
  dir=${dir%/}
  name=${dir##*/}
  lang=${dir%/examples/*}; lang=${lang##*/}
  tool=${needs[$lang]:-}
  if [ -z "$tool" ]; then
    echo "FAIL: dev/$lang/examples has no entry in tests/examples.sh"; fail=1; continue
  fi
  missing=
  for cmd in $tool; do command -v "$cmd" >/dev/null || missing=1; done
  if [ -n "$missing" ]; then
    skipped+=("$lang/$name"); continue
  fi
  [ "$lang/$name" = pascal/clicker ] && { skipped+=("$lang/$name"); continue; }

  for f in Makefile README.md; do
    [ -f "$dir/$f" ] || { echo "FAIL: dev/$lang/examples/$name has no $f"; fail=1; }
  done
  cp -r "$dir" "$t/$lang-$name"
  (
    cd "$t/$lang-$name"
    make -s >/dev/null 2>&1 || { echo "FAIL: $lang/$name doesn't build"; exit 1; }
    if [ "$name" = wordfreq ]; then
      make -s check >/dev/null 2>&1 || { echo "FAIL: $lang/$name doesn't print expected.txt"; exit 1; }
      cmp -s expected.txt "$here/dev/c/examples/wordfreq/expected.txt" ||
        { echo "FAIL: $lang/$name has its own expected.txt"; exit 1; }
    else
      timeout 60 make -s run >/dev/null 2>&1 || { echo "FAIL: $lang/$name doesn't run"; exit 1; }
    fi
    make -s clean >/dev/null 2>&1 || { echo "FAIL: make clean fails in $lang/$name"; exit 1; }
  ) || fail=1
  built=$((built + 1))
done

# Each language folder: a README with one place for the tools table, a
# tools.list of "command | version | what" lines, and a name 67-dev knows
# (otherwise nothing of it would ever reach ~/dev).
for d in "$here"/dev/*/; do
  d=${d%/}; lang=${d##*/}
  grep -q "langs+=($lang)" "$here/install/67-dev.sh" ||
    { echo "FAIL: dev/$lang isn't a language install/67-dev.sh knows"; fail=1; }
  [ "$(grep -cx '<!-- tools -->' "$d/README.md" 2>/dev/null)" = 1 ] ||
    { echo "FAIL: dev/$lang/README.md needs exactly one <!-- tools --> line"; fail=1; }
  if [ -f "$d/tools.list" ]; then
    bad=$(grep -v '^#' "$d/tools.list" | grep -v '^ *$' | awk -F'|' 'NF != 3' || true)
    [ -z "$bad" ] || { echo "FAIL: dev/$lang/tools.list lines need 3 fields: $bad"; fail=1; }
  else
    echo "FAIL: dev/$lang has no tools.list"; fail=1
  fi
done

[ "${#skipped[@]}" -gt 0 ] && echo "(skipped, no compiler or needs a display: ${skipped[*]})"
[ "$fail" = 0 ] && echo "examples: $built built and run with make; every wordfreq prints expected.txt; every language has its README and tools"
exit "$fail"
