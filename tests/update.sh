#!/usr/bin/env bash
# tests/update.sh — `vikix update` runs the NEW version's steps after it
# pulls, and logs both halves of the run to one file.
#
# The pull replaces bin/vikix while it runs; 0.13.0's new stage was
# skipped because bash went on with the old copy. This builds a fake
# upstream with a newer bin/vikix whose update only prints a marker, and
# updates a clone of the current tree from it. Nothing is installed.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
git_q() { git -c user.name=test -c user.email=test@example.org "$@"; }

# upstream: this working tree (committed or not), then a "newer release"
mkdir "$t/upstream"
( cd "$here" && git ls-files -z | xargs -0 cp --parents -t "$t/upstream" )
( cd "$t/upstream" && git init -q && git_q add -A && git_q commit -qm current )
git clone -q "$t/upstream" "$t/machine"
sed -i 's/^  say "updating Void"$/  say "NEW VERSION STEPS"; exit 0/' "$t/upstream/bin/vikix"
grep -q 'NEW VERSION STEPS' "$t/upstream/bin/vikix" || { echo "FAIL: test setup (no 'updating Void' line)"; exit 1; }
( cd "$t/upstream" && git_q commit -qam newer )

out=$(HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_SUDO_KEPT=1 bash "$t/machine/bin/vikix" update 2>&1)
fail=0
grep -q 'NEW VERSION STEPS' <<<"$out" || { echo "FAIL: the old version's steps ran after the pull"; fail=1; }
log=$(ls "$t"/state/logs/update-*.log 2>/dev/null | head -1)
if [ -z "$log" ]; then
  echo "FAIL: no update log in \$VIKIX_STATE/logs"; fail=1
else
  grep -q 'pulling Vikix' "$log" && grep -q 'NEW VERSION STEPS' "$log" ||
    { echo "FAIL: the log is missing one half of the run"; fail=1; }
fi
[ "$fail" = 0 ] && echo "update: restarts into the new version, and logs the whole run"
exit "$fail"
