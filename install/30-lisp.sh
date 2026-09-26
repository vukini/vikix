#!/usr/bin/env bash
# 30-lisp — Quicklisp, the StumpWM executable, and the contrib modules.
#
# Void does not package StumpWM, so it is built here in three checkable steps:
#   1. install Quicklisp into ~/quicklisp (skipped if already there)
#   2. build ~/.local/bin/stumpwm from Quicklisp with Swank inside
#      (skipped if it exists; `VIKIX_REBUILD_WM=1` forces a rebuild)
#   3. clone stumpwm-contrib into ~/.stumpwm.d/modules (battery etc.)

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

QL_DIR="$HOME/quicklisp"
WM_BIN="$HOME/.local/bin/stumpwm"
MODULES="$HOME/.stumpwm.d/modules"

# 1. Quicklisp
if [ -f "$QL_DIR/setup.lisp" ]; then
  say "Quicklisp already installed"
else
  say "installing Quicklisp"
  tmp=$(mktemp -d)
  run curl -fsSL -o "$tmp/quicklisp.lisp" https://beta.quicklisp.org/quicklisp.lisp
  run sbcl --non-interactive --load "$tmp/quicklisp.lisp" \
           --eval '(quicklisp-quickstart:install)'
  rm -rf "$tmp"
fi
# Make ql:quickload available in your own `sbcl` too, not only in the build.
if grep -qs quicklisp "$HOME/.sbclrc"; then
  # shellcheck disable=SC2088  # a message: the ~ is for reading, not expanding
  say "~/.sbclrc already loads Quicklisp"
else
  say "adding Quicklisp to ~/.sbclrc"
  run sbcl --non-interactive --load "$QL_DIR/setup.lisp" --eval '(ql:add-to-init-file)'
fi

# 2. StumpWM executable
if [ -x "$WM_BIN" ] && [ "${VIKIX_REBUILD_WM:-0}" != 1 ]; then
  say "StumpWM already built at $WM_BIN"
else
  say "building StumpWM into $WM_BIN (a few minutes the first time)"
  run mkdir -p "$(dirname "$WM_BIN")"
  run env VIKIX_WM_OUTPUT="$WM_BIN" \
      sbcl --non-interactive --load "$VIKIX_DIR/lib/build-stumpwm.lisp"
fi

# 3. contrib modules
if [ -d "$MODULES/.git" ]; then
  say "stumpwm-contrib already cloned; pulling"
  run git -C "$MODULES" pull --ff-only || warn "could not update $MODULES"
elif [ -e "$MODULES" ]; then
  say "$MODULES exists and is not a git clone; leaving it alone"
else
  say "cloning stumpwm-contrib"
  run git clone --depth 1 https://github.com/stumpwm/stumpwm-contrib.git "$MODULES"
fi
