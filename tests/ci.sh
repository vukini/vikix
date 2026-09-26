#!/usr/bin/env bash
# tests/ci.sh TEST [ARGS] — run tests/TEST.sh the way the GitHub workflow
# does: output as usual, and when it fails, its last lines also become an
# error annotation on the run.
#
# Annotations are public; job logs need a signed-in GitHub account. So a
# failure can be read from the run page, or from the API without a token:
#   https://api.github.com/repos/vukini/vikix/check-runs/<job id>/annotations

set -uo pipefail
cd "$(dirname "$0")" || exit 1
name=$1; shift
out=$(mktemp)
trap 'rm -f "$out"' EXIT

./"$name".sh "$@" 2>&1 | tee "$out"
status=${PIPESTATUS[0]}

if [ "$status" != 0 ] && [ "${GITHUB_ACTIONS:-}" = true ]; then
  # One annotation; its lines joined with %0A, which GitHub shows as newlines.
  msg=$(tail -40 "$out" | sed -e 's/%/%25/g' -e 's/\r//g' | awk '{printf "%s%%0A", $0}')
  echo "::error title=tests/$name.sh failed (exit $status)::$msg"
fi
exit "$status"
