#!/usr/bin/env bash
# Music: real Lisp reader/clock and public launcher, isolated sound engine.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # never the session settings
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
python3 "$here/tests/music/check.py" "$here"
