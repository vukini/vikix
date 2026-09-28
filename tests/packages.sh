#!/usr/bin/env bash
# tests/packages.sh — every name in packages/*.list (and optional/) is a package in the
# Void repositories (a typo would only be skipped with a warning at install).
#
# Needs xbps and a synced repository index (xbps-install -S). The nonfree
# packages (intel-ucode) count only once repos.list's void-repo-nonfree
# is installed, so they are reported but don't fail the test without it.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
cd "$(dirname "$0")/.."
. lib/common.sh

command -v xbps-query >/dev/null || { echo "FAIL: needs xbps (run on Void)"; exit 1; }
nonfree=0
[ -e /usr/share/xbps.d/10-repository-nonfree.conf ] && nonfree=1

# One query for the whole repository (a query per package reloads the
# index each time: 163 of them took almost two minutes).
declare -A avail
while read -r pkgver; do
  avail[${pkgver%-*}]=1
done < <(xbps-query -Rs '' | awk '{print $2}')

fail=0 n=0
for list in packages/*.list packages/optional/*.list; do
  while IFS= read -r pkg; do
    n=$((n + 1))
    [ -n "${avail[$pkg]:-}" ] && continue
    if [ "$pkg" = intel-ucode ] && [ "$nonfree" = 0 ]; then
      echo "note: $pkg is in the nonfree repository, not enabled here"
      continue
    fi
    echo "FAIL $list: no package called '$pkg'"
    fail=1
  done < <(read_list "$list")
done
echo "packages: $n names checked"
exit "$fail"
