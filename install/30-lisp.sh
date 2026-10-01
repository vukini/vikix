#!/usr/bin/env bash
# 30-lisp — Quicklisp, the StumpWM executable, and the contrib modules.
#
# Void does not package StumpWM, so it is built here in three checkable steps:
#   1. install Quicklisp into ~/quicklisp (skipped if already there),
#      and clone clx-truetype (TrueType fonts for the bar) next to it
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
  # The lines (ql:add-to-init-file) writes, written here: it stops to ask
  # "Press Enter to continue" whenever it can reach the terminal, which
  # left a fresh install (bash vikix-install) waiting for a key.
  if [ "$DRY_RUN" = 1 ]; then
    printf '   would add Quicklisp to %s\n' "$HOME/.sbclrc"
  else
    cat >> "$HOME/.sbclrc" <<'LISP'

;;; The following lines added by ql:add-to-init-file:
#-quicklisp
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"
                                       (user-homedir-pathname))))
  (when (probe-file quicklisp-init)
    (load quicklisp-init)))
LISP
  fi
fi

# clx-truetype lets StumpWM draw TrueType fonts (the contrib module
# ttf-fonts needs it). It isn't in Quicklisp; local-projects is where
# Quicklisp looks for systems of your own.
TRUETYPE="$QL_DIR/local-projects/clx-truetype"
if [ -d "$TRUETYPE" ]; then
  say "clx-truetype already in $TRUETYPE"
else
  say "cloning clx-truetype"
  run git clone --depth 1 https://github.com/lihebi/clx-truetype.git "$TRUETYPE" ||
    warn "no clx-truetype: StumpWM keeps its bitmap font"
fi

# 2. StumpWM executable
if [ -x "$WM_BIN" ] && [ "${VIKIX_REBUILD_WM:-0}" != 1 ]; then
  say "StumpWM already built at $WM_BIN"
else
  say "building StumpWM into $WM_BIN (a few minutes the first time)"
  run mkdir -p "$(dirname "$WM_BIN")"
  # Built beside the old one, then moved over it: the running StumpWM is
  # that file, and Linux won't let a running program's file be written.
  # The move leaves it running from the old copy until the next login.
  run env VIKIX_WM_OUTPUT="$WM_BIN.new" \
      sbcl --non-interactive --load "$VIKIX_DIR/lib/build-stumpwm.lisp"
  run mv -f "$WM_BIN.new" "$WM_BIN"
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
