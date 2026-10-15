#!/usr/bin/env bash
# tests/scheduler.sh — the persistent task queue, eligibility and crash-safe starts.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # never the installed checkout or state
unset DISPLAY VIKIX_AGENT_SSH VIKIX_TASK_ORIGIN
export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent
export VIKIX_SCHEDULER=0
python3 "$(dirname "$0")/scheduler.py"
