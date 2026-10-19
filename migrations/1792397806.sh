#!/usr/bin/env bash
# Why: from 0.72.102, 55-hardware installs udev's keys file,
# config/udev/90-vikix-keys.hwdb (the ROG Flow Z13's F6, a plain F6 on
# Linux, made Print so the screenshot keys work there). vikix update
# doesn't re-run that stage, so machines already installed get it here.
# The stage checks first: a machine that has the file does nothing, and
# one without that keyboard compiles a line that never matches.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

bash "$VIKIX_DIR/install/55-hardware.sh"
