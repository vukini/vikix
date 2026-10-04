#!/usr/bin/env bash
# tests/run.sh — run the tests that fit this machine.
#
#   tests/run.sh          the quick ones (about two minutes): lint, lisp (with
#                         sbcl), battery, memory, home, services, backup (with
#                         restic), image, theme, theme-import, bar, rofi,
#                         wallpaper, examples, dev-ai, notes, project, drives, firmware, fingerprint, firewall, updates, notifications, idle, lock, lazarus, capture,
#                         mimeapps, nightlight, update, windows, ai, ai-local, llm, ai-keys, agents, debug, dictate, voice, lisp-apps, esploro, mcp, swank (with Quicklisp), errors (with Quicklisp's StumpWM), webapp, features, nvim, emacs, welcome, menu (with sbcl), docs-open, nyxt (with sbcl), pkg, oneline, man, day, info (with makeinfo),
#                         and on Void also packages and dry-run
#   tests/run.sh --quick  the same without the slow ones that check only
#                         one corner: packages and dry-run (Void's mirror,
#                         over the network), examples (builds every
#                         language's examples) and lazarus. For changes that
#                         touch none of install/, packages/, features.list, dev/
#   tests/run.sh --all    those, plus editors (several minutes, network)
#   tests/run.sh --changed [REF]
#                         only the tests for what changed since REF (default:
#                         origin/main), uncommitted changes included; see
#                         tests/changed.sh for how files map to tests
#   tests/run.sh NAME...  just those tests (lint, lisp, ...), side by side
#
# Each test is its own script in tests/ and can be run alone. They run side
# by side, as many at once as the machine has cores (VIKIX_TEST_JOBS sets
# it; 1 is one after another), each one's output printed whole when it
# ends, so a failure reads as it would alone. A test must therefore keep
# to its own temporary folder, display and ports. GitHub runs them too:
# .github/workflows/test.yml.

set -uo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# The tests make up a home folder, and Vikix follows the XDG variables
# where they are set; GitHub's runners set XDG_CONFIG_HOME, which would
# send a test's files into the runner's real config instead.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
cd "$(dirname "$0")" || exit 1
mode=${1:-}
case $mode in
  ''|--quick|--all|--changed) ;;
  -*) echo "usage: tests/run.sh [--quick|--all|--changed [REF]|NAME...]" >&2; exit 2 ;;
  *) mode=--names ;;
esac
tests=(lint)
if command -v sbcl >/dev/null; then tests+=(lisp); else echo "(lisp needs sbcl; skipped here)"; fi
tests+=(battery memory home services lisp-stage image theme theme-import bar rofi wallpaper mimeapps examples dev-ai notes project drives firmware fingerprint firewall updates notifications idle lock lazarus capture nightlight update windows ai ai-local llm ai-keys agents debug dictate voice lisp-apps esploro hype publish learn mcp swank errors bitwarden plugin records obsidian docs-check screens docs vk webapp features nvim emacs editor-theme welcome menu docs-open nyxt pkg oneline man day viri main drawer layouts rules keys tray focus times soak)
if command -v restic >/dev/null; then tests+=(backup); else echo "(backup needs restic; skipped here)"; fi
if command -v makeinfo >/dev/null; then tests+=(info); else echo "(info needs makeinfo; skipped here)"; fi
# --quick leaves these out (the run says so); the full run and GitHub keep them.
slow=(examples lazarus)
if [ "$mode" = --quick ] || [ "$mode" = --changed ]; then
  kept=()
  for t in "${tests[@]}"; do [[ " ${slow[*]} " == *" $t "* ]] || kept+=("$t"); done
  tests=("${kept[@]}")
  echo "(${slow[*]} packages dry-run left out: --quick)"
elif command -v xbps-query >/dev/null && [ "$(id -u)" -ne 0 ]; then
  tests+=(packages dry-run)
else
  echo "(packages and dry-run need Void and a normal user; skipped here)"
fi
[ "$mode" = --all ] && tests+=(editors)

if [ "$mode" = --names ]; then
  tests=()
  for t in "$@"; do
    [ -x "./$t.sh" ] || { echo "no test $t (tests/$t.sh)" >&2; exit 2; }
    tests+=("$t")
  done
elif [ "$mode" = --changed ]; then
  # From the quick set, those the changes reach.
  mapfile -t wanted < <(./changed.sh "${2:-origin/main}")
  if [ "${wanted[*]}" = all ]; then wanted=("${tests[@]}"); echo "(the changes reach too far to pick: the quick set)"; fi
  kept=()
  for t in "${tests[@]}"; do [[ " ${wanted[*]} " == *" $t "* ]] && kept+=("$t"); done
  tests=("${kept[@]}")
  if [ "${#tests[@]}" -eq 0 ]; then echo "nothing changed that a test covers"; exit 0; fi
  echo "(for what changed: ${tests[*]})"
fi

# The long ones start first, so the run isn't left waiting on one at the end.
first=(emacs mcp learn ai-local errors lint swank dev-ai dictate features editors packages dry-run examples lazarus)
ordered=()
for t in "${first[@]}"; do [[ " ${tests[*]} " == *" $t "* ]] && ordered+=("$t"); done
for t in "${tests[@]}"; do [[ " ${first[*]} " == *" $t "* ]] || ordered+=("$t"); done

jobs=${VIKIX_TEST_JOBS:-$(nproc 2>/dev/null || echo 2)}
[ "$jobs" -ge 1 ] 2>/dev/null || jobs=1
logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT
failed=() took=() shown=()

run_one() {
  local start=$SECONDS code=0
  ./"$1".sh > "$logs/$1.out" 2>&1 || code=$?
  echo "$code $((SECONDS - start))" > "$logs/$1.done.tmp"
  mv "$logs/$1.done.tmp" "$logs/$1.done"
}

# Prints each test that has ended and isn't printed yet, whole.
show_ended() {
  local t code secs
  for t in "${ordered[@]}"; do
    [[ " ${shown[*]} " == *" $t "* ]] && continue
    [ -e "$logs/$t.done" ] || continue
    read -r code secs < "$logs/$t.done"
    echo "=== $t (${secs}s)"
    cat "$logs/$t.out"
    [ "$code" = 0 ] || failed+=("$t")
    took+=("$secs $t")
    shown+=("$t")
  done
}

# Tests that can't share the machine with others (a fixed real port or
# display) run after the rest, one at a time: times and soak, whose measures
# others running beside it would slow.
alone=(times soak)
for t in "${ordered[@]}"; do
  [[ " ${alone[*]} " == *" $t "* ]] && continue
  while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do
    wait -n 2>/dev/null || true
    show_ended
  done
  run_one "$t" &
done
wait
show_ended
for t in "${ordered[@]}"; do
  [[ " ${alone[*]} " == *" $t "* ]] || continue
  run_one "$t"
  show_ended
done
echo
# The slow ones, so a run that takes long says why.
echo "slowest: $(printf '%s\n' "${took[@]}" | sort -rn | head -5 | awk '{printf "%s %ss  ", $2, $1}')"
if [ "${#failed[@]}" -eq 0 ]; then
  echo "all passed: ${tests[*]}"
else
  echo "FAILED: ${failed[*]}"
  exit 1
fi
