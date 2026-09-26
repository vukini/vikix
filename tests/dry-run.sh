#!/usr/bin/env bash
# tests/dry-run.sh — both install parts run start to end with --dry-run:
# every stage loads, and none stops with an error.
#
# Run on Void, as a normal user (preflight refuses root). Nothing on the
# machine changes; the output is kept in a temporary HOME. VIKIX_MIRROR
# skips the minute of mirror timing.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

out=$(HOME="$t" VIKIX_MIRROR=${VIKIX_MIRROR:-https://repo-default.voidlinux.org} \
      "$here/install.sh" --dry-run 2>&1) && status=0 || status=$?
if [ "$status" != 0 ] || grep -q '^xx ' <<<"$out"; then
  printf '%s\n' "$out" | tail -30
  echo "FAIL: the dry run stopped (exit $status)"
  exit 1
fi
echo "dry run: both parts ran through ($(grep -c 'would run' <<<"$out") commands printed, none run)"
