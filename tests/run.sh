#!/usr/bin/env bash
# tests/run.sh — run the tests that fit this machine.
#
#   tests/run.sh          the quick ones (about a minute): lint, lisp (with
#                         sbcl), battery, home, image, theme, updates,
#                         notifications, idle, capture, nightlight, update,
#                         and on Void also packages and dry-run
#   tests/run.sh --all    those, plus editors (several minutes, network)
#
# Each test is its own script in tests/ and can be run alone. GitHub runs
# them too: .github/workflows/test.yml.

set -uo pipefail
cd "$(dirname "$0")" || exit 1
tests=(lint)
if command -v sbcl >/dev/null; then tests+=(lisp); else echo "(lisp needs sbcl; skipped here)"; fi
tests+=(battery home image theme updates notifications idle capture nightlight update)
if command -v xbps-query >/dev/null && [ "$(id -u)" -ne 0 ]; then
  tests+=(packages dry-run)
else
  echo "(packages and dry-run need Void and a normal user; skipped here)"
fi
[ "${1:-}" = --all ] && tests+=(editors)

failed=()
for t in "${tests[@]}"; do
  echo "=== $t"
  ./"$t".sh || failed+=("$t")
done
echo
if [ "${#failed[@]}" -eq 0 ]; then
  echo "all passed: ${tests[*]}"
else
  echo "FAILED: ${failed[*]}"
  exit 1
fi
