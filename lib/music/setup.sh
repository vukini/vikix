#!/usr/bin/env bash
# Features with setup commands install their own package lists.
set -euo pipefail
. "$(dirname "$0")/../common.sh"
VIKIX_LISTS=music bash "$VIKIX_DIR/install/10-packages.sh"
enable_service rtkit
