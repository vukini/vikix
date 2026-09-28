#!/usr/bin/env bash
# install-2.sh — before 0.47, part 2 of the install: editors, languages,
# LibreOffice, printing. Those are features now, and this adds all of them
# (vikix add everything). The sound and laptop pieces are in the base,
# which install.sh installs.
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
[ "${1:-}" = --dry-run ] && { export DRY_RUN=1; shift; }
echo ":: part two is now: vikix add everything (vikix features shows what else there is)"
exec bash "$dir/bin/vikix-features" add everything "$@"
