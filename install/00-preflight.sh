#!/usr/bin/env bash
# 00-preflight — check this machine can take Vikix before touching it.
#
# Stops (or, in a dry run, only warns) if:
#   - this is not Void Linux
#   - it is running as root (run as your own user; sudo is used where needed)
#   - sudo or xbps-install is missing
#   - the C library is musl (browsers and Electron apps expect glibc)
# and notes any StumpWM config you already have, which 40-config keeps.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

problem() { if [ "$DRY_RUN" = 1 ]; then warn "$*"; else die "$*"; fi; }

# shellcheck disable=SC1091
id=$( . /etc/os-release 2>/dev/null && echo "${ID:-}" )
[ "$id" = void ] || problem "this is not Void Linux (os-release ID='$id')"

[ "$(id -u)" -ne 0 ] || problem "run as your normal user, not root"

command -v sudo >/dev/null         || problem "sudo is not installed"
command -v xbps-install >/dev/null || problem "xbps-install not found"

if command -v xbps-uhelper >/dev/null && xbps-uhelper arch | grep -q musl; then
  problem "this is a musl install; Vikix expects glibc"
fi

for old in "$HOME/.stumpwmrc" "$HOME/.stumpwm.d/init.lisp"; do
  if [ -e "$old" ] && [ ! -L "$old" ]; then
    say "found your StumpWM config at $old — 40-config will keep it as ~/.stumpwm.d/user.lisp"
  fi
done

say "preflight ok"
