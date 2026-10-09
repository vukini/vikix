#!/usr/bin/env bash
# tests/lint.sh — every script parses (shell and Python), the ones run
# directly are executable, shellcheck finds nothing at warning level, and
# every vikix command's header is in the shape its man page is made from.
#
# Runs anywhere; no Void needed. shellcheck comes from PATH, or through
# uvx (uv's runner) when it isn't installed.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
cd "$(dirname "$0")/.."

mapfile -t scripts < <(grep -lE '^#!.*(ba)?sh' install.sh install-*.sh install/*.sh \
                         lib/common.sh migrations/*.sh bin/* tests/*.sh tests/lib/*.sh site/install \
                         installer/vikix-installer installer/vikix-hwreport installer/firstboot installer/build-image.sh)
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
for f in install.sh install-*.sh install/*.sh bin/* tests/*.sh installer/vikix-installer installer/vikix-hwreport installer/firstboot installer/build-image.sh; do
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

# Every bin/vikix* starts with a header in the standard shape (a title line,
# usage lines, prose): -h prints it and lib/man.py makes its man page from
# it, so one out of shape is a command without a page.
if python3 lib/man.py --check; then
  echo "headers: every vikix command's is in the shape its man page is made from"
else
  echo "FAIL headers: the scripts above (lib/man.py's own header describes the shape)"; fail=1
fi

# A test must never reach the live desktop's Swank (127.0.0.1:4004): it
# once sent test passwords there, and the running StumpWM's Swank stopped.
# So every test points vikix eval at a port nothing listens on.
missing=$(grep -L '^export VIKIX_SWANK_PORT=9 ' tests/*.sh | grep -v 'tests/lint.sh' || true)
if [ -n "$missing" ]; then
  echo "FAIL isolation: these tests could reach the live desktop's Swank; add export VIKIX_SWANK_PORT=9:"
  echo "$missing" | sed 's/^/  /'; fail=1
else
  echo "isolation: every test keeps off the live desktop's Swank"
fi
# Nor the live Emacs: emacsclient finds it by its socket, whatever HOME is,
# and 45-editors reloads Vikix's AI setup in a running Emacs.
missing=$(grep -L '^export EMACS_SOCKET_NAME=/nonexistent/' tests/*.sh || true)
if [ -n "$missing" ]; then
  echo "FAIL isolation: these tests could reach the live desktop's Emacs; add export EMACS_SOCKET_NAME=/nonexistent/emacs-server:"
  echo "$missing" | sed 's/^/  /'; fail=1
else
  echo "isolation: every test keeps off the live desktop's Emacs"
fi
# Nor the desktop session's own settings: from an agent's shell (Super+a)
# VIKIX_DIR and VIKIX_STATE point at the real ~/vikix and its state, and
# VIKIX_AGENT makes secrets.sh export nothing, so tests failed there and
# could have written to the real state.
missing=$(grep -L '^unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE ' tests/*.sh || true)
if [ -n "$missing" ]; then
  echo "FAIL isolation: these tests could see the desktop session's settings; add unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE:"
  echo "$missing" | sed 's/^/  /'; fail=1
else
  echo "isolation: every test starts without the desktop session's settings"
fi

# `vikix what`'s pages are public, and a user's books may not be: Vikix's
# pages point at its own guides, the manuals and its own files, never at a
# chapter (plans/DESIGN-what.md). The command's own check says which page does.
if out=$(python3 bin/vikix-what check --vikix 2>&1); then
  echo "what: $(tail -1 <<<"$out"); they name Vikix's guides, manuals and files only"
else
  echo "FAIL what: a page of config/what is wrong:"
  grep -v "isn't on this machine" <<<"$out" | sed 's/^/  /'; fail=1
fi

exit "$fail"
