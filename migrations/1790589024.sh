#!/usr/bin/env bash
# Why: from 0.46.0 what Vikix installs beyond the base is a choice of
# features (vikix add, vikix remove), kept in ~/.config/vikix/features.
# A machine installed before had every package list, and the optional
# features it set up in ~/.config/vikix/optional. Write that down as its
# choices, so no update ever takes anything away from it: everything, the
# optional ones, and local AI and llm when they're set up. Only when there
# is no choices file yet, so safe to run twice. The old optional file is
# left where it is; nothing reads it once this one exists.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"
. "$VIKIX_DIR/lib/features.sh"

if [ -f "$FEATURES_FILE" ]; then
  say "your feature choices are already in $FEATURES_FILE"
  exit 0
fi
extra=()
[ -x "${VIKIX_OLLAMA_OPT:-$HOME/.local/opt/ollama}/bin/ollama" ] && extra+=(local-ai)
[ -x "$HOME/.local/bin/llm" ] && extra+=(llm)
record_features "${extra[@]}"       # starts with everything, and the old optional ones
say "your features: $(read_list "$FEATURES_FILE" | tr '\n' ' ')(vikix features lists them; vikix remove takes one away)"
