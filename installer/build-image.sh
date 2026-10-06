#!/usr/bin/env bash
# installer/build-image.sh — make Vikix's installer stick: an ISO to write to USB.
#
#   sudo installer/build-image.sh            vikix-VERSION-DATE-x86_64.iso here
#   sudo installer/build-image.sh -o FILE    somewhere else
#
# The image is Void's own live system, built by Void's own tool
# (void-mklive, at the commit pinned below), with:
#   - today's kernel and firmware from Void's repository (the official
#     image is from 2025-02 with kernel 6.12, too old for new laptops'
#     Wi-Fi, sound and graphics)
#   - NetworkManager for Wi-Fi, cryptsetup, the disk tools, a big console font
#   - this checkout of Vikix, in /usr/share/vikix, git history included
#   - vikix-installer, which starts by itself on the first screen, and
#     vikix-hwreport
#
# Needs root (it mounts and chroots), the xbps tools on PATH (on a
# non-Void machine, the static ones: repo-default.voidlinux.org/static/),
# git, and void-mklive's own tools (xorriso, mksquashfs, mkfs.vfat).
# About 15 minutes and 4 GB of space the first time; packages are cached
# in ~/.cache/vikix/mklive after that.
#
# Write it with: sudo dd if=FILE of=/dev/sdX bs=4M status=progress oflag=sync
# (docs/install-stick.md).

set -euo pipefail

MKLIVE_REPO=https://github.com/void-linux/void-mklive
MKLIVE_COMMIT=3aa194bdea9c83de0b5d78fb889a88f000a44fab   # 2026-09; moved on by hand, after a test boot
REPO=${VIKIX_IMAGE_REPO:-https://repo-default.voidlinux.org/current}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
top=$(cd "$here/.." && pwd)
version=$(cat "$top/VERSION")
out="$PWD/vikix-$version-$(date +%Y%m%d)-x86_64.iso"
while [ $# -gt 0 ]; do
  case $1 in
    -o) out=$(realpath -m "${2:?-o needs a file}"); shift ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

die() { echo "xx $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run it with sudo (it mounts and chroots)"
for t in xbps-install git xorriso mksquashfs mkfs.vfat; do
  command -v "$t" >/dev/null || die "$t is missing"
done

# The cache in the home of whoever ran sudo, not root's.
owner_home=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
cache=${owner_home:-$HOME}/.cache/vikix/mklive
mkdir -p "$cache"
if [ ! -d "$cache/void-mklive/.git" ]; then
  git clone -q "$MKLIVE_REPO" "$cache/void-mklive"
fi
git -C "$cache/void-mklive" fetch -q origin "$MKLIVE_COMMIT" 2>/dev/null || true
git -C "$cache/void-mklive" checkout -q "$MKLIVE_COMMIT"

# What goes onto the stick, besides Void: laid out as it will be there.
inc=$(mktemp -d)
trap 'rm -rf "$inc"' EXIT
cp -a "$here/live/." "$inc/"
install -Dm755 "$here/vikix-installer" "$inc/usr/local/bin/vikix-installer"
install -Dm755 "$here/vikix-hwreport"  "$inc/usr/local/bin/vikix-hwreport"
# A clone, not a copy: committed files only (no worktree leftovers or
# secrets), with history, its origin pointed at GitHub so the installed
# copy pulls from there.
git clone -q --no-hardlinks "$top" "$inc/usr/share/vikix"
git -C "$inc/usr/share/vikix" remote set-url origin https://github.com/vukini/vikix.git

packages="NetworkManager cryptsetup dialog gptfdisk dosfstools e2fsprogs
  linux-firmware sof-firmware terminus-font pciutils usbutils dmidecode
  curl git less nano rsync"

cd "$cache/void-mklive"
./mklive.sh \
  -r "$REPO" -r "$REPO/nonfree" \
  -c "$cache/xbps-cache" \
  -p "$(printf '%s' "$packages" | tr -s ' \n' ' ')" \
  -S "dbus NetworkManager" \
  -C "live.autologin" \
  -T "Vikix $version" \
  -I "$inc" \
  -o "$out"

echo ":: $out"
sha256sum "$out" | tee "$out.sha256"
