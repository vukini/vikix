#!/usr/bin/env bash
# tests/network.sh — bin/vikix-network and config/emacs/vikix-network.el;
# fixture networks and scanners, plus the public launcher on a hidden display.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # never the live session settings
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_RUNTIME_DIR="$t/run" XDG_CONFIG_HOME="$t/config"
export XDG_CACHE_HOME="$t/cache" XDG_STATE_HOME="$t/state" XDG_DATA_HOME="$t/data"
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent/network-test
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
unset DISPLAY
if command -v emacs >/dev/null; then
  timeout --kill-after=5s 45s emacs -Q --batch -l "$here/tests/network.el" -f ert-run-tests-batch-and-exit
else
  echo 'SKIP: Network Office Lisp tests need Emacs'
fi
timeout --kill-after=5s 180s python3 "$here/tests/network.py"
