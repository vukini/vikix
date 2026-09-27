#!/usr/bin/env bash
# Why: from 0.23.0 StumpWM draws the bar, menus and messages in Iosevka
# instead of the X bitmap font 9x15. That needs clx-truetype inside the
# StumpWM executable, and machines installed earlier built theirs without
# it. This clones clx-truetype and builds StumpWM again (a few minutes).
# The running StumpWM carries on from the old copy; the new one, and the
# new font, come with the next login. Until then the bar keeps 9x15.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

wm="$HOME/.local/bin/stumpwm"
# The package's name is in the image once it has been built in.
if [ -x "$wm" ] && grep -aqF CLX-TRUETYPE "$wm"; then
  say "StumpWM already has clx-truetype"
else
  say "building StumpWM again, with clx-truetype (a few minutes)"
  VIKIX_REBUILD_WM=1 bash "$VIKIX_DIR/install/30-lisp.sh"
  say "the bar's new font comes with your next login"
fi
