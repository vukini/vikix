#!/usr/bin/env bash
# rtkit is enabled only when the music feature is added.
set -euo pipefail
. "$(dirname "$0")/../common.sh"
enable_service rtkit
