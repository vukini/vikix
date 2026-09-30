#!/usr/bin/env bash
# Why: from 0.71.0 the PATH block in ~/.bash_profile also names ~/.cargo/bin
# and ~/go/bin, so programs from `cargo install` and `go install` are
# found. 60-login writes that block, and vikix update doesn't re-run it.
# Re-running the stage replaces its blocks in place, so this is safe twice.
set -euo pipefail
bash "$VIKIX_DIR/install/60-login.sh"
