#!/usr/bin/env bash
# 05-mirror — download packages from the fastest Void mirror.
#
# Void's default mirror can be slow far from Europe, and the install
# downloads 1–2 GB. So before anything is installed, this stage downloads
# a large package from each mirror in mirrors.list for a few seconds, and
# points xbps at the one that delivered the most. (A large package, not
# the small package index: a CDN serves the index from its cache in no
# time, which says nothing about how fast the packages come.)
#
#   VIKIX_MIRROR=URL   use this mirror; no timing
#
# A mirror already chosen in /etc/xbps.d (by you, or by an earlier run)
# is left alone unless VIKIX_MIRROR is set. To time them again:
#   sudo rm /etc/xbps.d/*-repository-*.conf; ./install.sh --only 05-mirror
#
# It takes about a minute: six seconds per mirror.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

if [ -n "${VIKIX_MIRROR:-}" ]; then
  say "using VIKIX_MIRROR: $VIKIX_MIRROR"
  use_mirror "$VIKIX_MIRROR"
  exit 0
fi

if [ -n "$(current_mirror)" ]; then
  say "xbps already uses $(current_mirror); leaving it (set VIKIX_MIRROR to change it)"
  exit 0
fi

# The probe: linux-firmware-nvidia, 100+ MB, never finishes in the time
# given. Its current file name comes from a fresh package index.
run sudo xbps-install -S
pkgver=$(xbps-query -R -p pkgver linux-firmware-nvidia 2>/dev/null || true)
[ -n "$pkgver" ] || die "can't find linux-firmware-nvidia in the package index; set VIKIX_MIRROR instead"
probe=$pkgver.$(xbps-uhelper arch).xbps
secs=6
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "timing the mirrors in mirrors.list ($secs seconds each)"
best="" best_kbs=0
while IFS= read -r url; do
  rm -f "$tmp/probe" "$tmp/probe.part"
  timeout "$secs" xbps-fetch -o "$tmp/probe" "$url/current/$probe" >/dev/null 2>&1 || true
  bytes=$(stat -c %s "$tmp/probe.part" "$tmp/probe" 2>/dev/null | head -1 || true)
  kbs=$(( ${bytes:-0} / secs / 1024 ))
  if [ "$kbs" -eq 0 ]; then
    printf '   %11s  %s\n' "no answer" "$url"
    continue
  fi
  printf '   %6d KB/s  %s\n' "$kbs" "$url"
  if [ "$kbs" -gt "$best_kbs" ]; then best=$url best_kbs=$kbs; fi
done < <(read_list "$VIKIX_DIR/mirrors.list")

[ -n "$best" ] || die "no mirror answered; is the network up?"

if [ "$best" = https://repo-default.voidlinux.org ]; then
  say "the default mirror is the fastest here; nothing to change"
  exit 0
fi

say "fastest: $best"
use_mirror "$best"
