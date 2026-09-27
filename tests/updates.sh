#!/usr/bin/env bash
# tests/updates.sh — vikix-updates counts the Void packages and Vikix
# commits that `vikix update` would bring, and says ? for what it can't
# check, instead of a wrong 0.
#
# A fake xbps-install stands in for the network; a checkout two commits
# behind a local "upstream" stands in for Vikix.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
git_q() { git -c user.name=test -c user.email=test@example.org "$@"; }
fail=0

mkdir -p "$t/upstream" "$t/bin"
( cd "$t/upstream" && git init -q && for i in 1 2 3; do git_q commit -q --allow-empty -m "c$i"; done )
git clone -q "$t/upstream" "$t/vikix"
git -C "$t/vikix" reset -q --hard HEAD~2
mkdir -p "$t/vikix/bin" && cp "$here/bin/vikix-updates" "$t/vikix/bin/"

fake_xbps() {   # fake_xbps LINES|fail
  if [ "$1" = fail ]; then
    printf '#!/bin/sh\nexit 1\n' > "$t/bin/xbps-install"
  else
    printf '#!/bin/sh\nfor i in $(seq %s); do echo "pkg-$i update x86_64"; done\n' "$1" > "$t/bin/xbps-install"
  fi
  chmod +x "$t/bin/xbps-install"
}
counts() { PATH="$t/bin:$PATH" XDG_STATE_HOME="$t/state" sh "$t/vikix/bin/vikix-updates" >/dev/null; cat "$t/state/vikix/updates"; }

fake_xbps 3
[ "$(counts)" = "3 2" ] || { echo "FAIL: 3 packages and 2 commits read as: $(counts)"; fail=1; }
fake_xbps 0
[ "$(counts)" = "0 2" ] || { echo "FAIL: no packages read as: $(counts)"; fail=1; }
fake_xbps fail
[ "$(counts)" = "? 2" ] || { echo "FAIL: a failed package check read as: $(counts)"; fail=1; }
git -C "$t/vikix" remote set-url origin "$t/nowhere"
fake_xbps 1
[ "$(counts)" = "1 ?" ] || { echo "FAIL: an unreachable Vikix read as: $(counts)"; fail=1; }

[ "$fail" = 0 ] && echo "updates: packages and Vikix commits counted; ? when a check fails"
exit "$fail"
