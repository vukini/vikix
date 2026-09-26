#!/usr/bin/env bash
# Why: until 0.12.0 the line in ~/.bashrc that reads Vikix's aliases was
# added at the END of the file, so Vikix's aliases overrode any of your
# own that came before it (your `e` or `ls` lost to Vikix's). It now sits
# at the top, so yours win. Re-running 60-login moves it; nothing else in
# ~/.bashrc changes.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

bash "$VIKIX_DIR/install/60-login.sh"
