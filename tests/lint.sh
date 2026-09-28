#!/usr/bin/env bash
# tests/lint.sh — every script parses (shell and Python), the ones run
# directly are executable, and shellcheck finds nothing at warning level.
#
# Runs anywhere; no Void needed. shellcheck comes from PATH, or through
# uvx (uv's runner) when it isn't installed.

set -euo pipefail
cd "$(dirname "$0")/.."

mapfile -t scripts < <(grep -lE '^#!.*(ba)?sh' install.sh install-*.sh install/*.sh \
                         lib/common.sh migrations/*.sh bin/* tests/*.sh)
fail=0

for f in "${scripts[@]}"; do
  bash -n "$f" || { echo "FAIL syntax: $f"; fail=1; }
done
echo "syntax: ${#scripts[@]} scripts checked"

# The Python ones (vikix eval, lib/*.py): parsed, not run, and nothing written to disk.
mapfile -t pythons < <(grep -lE '^#!.*python' bin/* lib/*)
python3 -c '
import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f).read(), f)
' "${pythons[@]}" || { echo "FAIL syntax: a Python script (above)"; fail=1; }
echo "python: ${#pythons[@]} script(s) checked"

# Scripts that are run as ./name must carry the executable bit (0.10.0
# reached GitHub without it, and ./install-1.sh failed with "Permission denied").
for f in install.sh install-*.sh install/*.sh bin/* tests/*.sh; do
  [ -x "$f" ] || { echo "FAIL not executable: $f"; fail=1; }
done
echo "executable bits checked"

if command -v shellcheck >/dev/null; then
  sc=(shellcheck)
elif command -v uvx >/dev/null; then
  sc=(uvx --from shellcheck-py shellcheck)
else
  echo "FAIL no shellcheck (install it, or uv for uvx)"; exit 1
fi
if "${sc[@]}" -x -S warning "${scripts[@]}"; then
  echo "shellcheck: no warnings"
else
  fail=1
fi

exit "$fail"
