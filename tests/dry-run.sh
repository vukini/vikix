#!/usr/bin/env bash
# tests/dry-run.sh — the install runs start to end with --dry-run: every
# stage loads, and none stops with an error.
#
#   - ./install.sh alone is the base: no editor, no language, and the
#     choices file it would write names no feature
#   - --with essentials adds those features after the base, with the
#     editors' and languages' stages, but never the offline docs
#   - an unknown name in --with stops the install before any stage
#   - install-2.sh, from before 0.47, adds everything
#
# Run on Void, as a normal user (preflight refuses root). Nothing on the
# machine changes; the output is kept in a temporary HOME. VIKIX_MIRROR
# skips the minute of mirror timing.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
lacks() { ! grep -q -- "$1" <<<"$2"; }
export VIKIX_MIRROR=${VIKIX_MIRROR:-https://repo-default.voidlinux.org}

# dry NAME COMMAND... — run it in a fresh home; stop the test if it stops.
dry() {
  local name=$1 status; shift
  rm -rf "${t:?}/home"; mkdir -p "$t/home"
  out=$(HOME="$t/home" "$@" 2>&1) && status=0 || status=$?
  if [ "$status" != 0 ] || grep -q '^xx ' <<<"$out"; then
    printf '%s\n' "$out" | tail -30
    echo "FAIL: the dry run of $name stopped (exit $status)"
    exit 1
  fi
}

dry "the base" "$here/install.sh" --dry-run
echo "dry run: the base ran through ($(grep -c 'would run' <<<"$out") commands printed, none run)"
check "the base should write a choices file with no feature" has 'would write .*/vikix/features: the base alone' "$out"
check "the base ran the editors' stage" lacks 'stage 45-editors' "$out"
check "the base ran the languages' stage" lacks 'stage 65-languages' "$out"
check "the base should run the sound and laptop stages" has 'stage 55-hardware' "$out"
check "the base should end by suggesting vikix add" has 'vikix add essentials' "$out"

dry "--with essentials" "$here/install.sh" --dry-run --with essentials
check "--with essentials should add its features: $(grep 'adding:' <<<"$out" | head -1)" has 'adding: emacs devtools c python lisp' "$out"
check "--with essentials should clone the Emacs config" has 'would run: git clone .*emacs-void' "$out"
check "--with essentials cloned Neovim's, which it doesn't have" lacks 'nvim-void-linux' "$out"
check "--with essentials should run the languages' stages" has 'stage 67-dev' "$out"
check "the finish should name what was added" has 'Added: essentials' "$out"
# The docs are a few GB from slow sites: the installer (and so `vikix update`,
# which runs the same stage) must leave them to `vikix docs`.
if grep -E 'would run: curl' <<<"$out" | grep -qE 'docs-html|HyperSpec|lua\.org|ziglang|sqlite-doc|kapeli'; then
  grep -E 'would run: curl' <<<"$out" | grep -E 'docs-html|HyperSpec|lua\.org|ziglang|sqlite-doc|kapeli' | head -3
  echo "FAIL: the install downloads the offline docs (only vikix docs should)"
  fail=1
fi

rm -rf "${t:?}/home"; mkdir -p "$t/home"
out=$(HOME="$t/home" "$here/install.sh" --dry-run --with essentials,nosuchthing 2>&1) &&
  { echo "FAIL: --with an unknown name went ahead"; fail=1; }
check "an unknown name should be named: $out" has "no feature or bundle called 'nosuchthing'" "$out"
check "an unknown name still ran a stage" lacks 'stage 00-preflight' "$out"

dry "install-2.sh" "$here/install-2.sh" --dry-run
check "install-2.sh should say part two is vikix add everything" has 'part two is now: vikix add everything' "$out"
check "install-2.sh should add LibreOffice with the rest" has 'adding: .*office' "$out"

[ "$fail" = 0 ] && echo "dry run: --with adds features after the base, an unknown one stops it first, install-2.sh adds everything, and the offline docs are left to vikix docs"
exit "$fail"
