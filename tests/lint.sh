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
mapfile -t pythons < <(grep -d skip -lE '^#!.*python' bin/* lib/*; ls lib/agents/*.py)
python3 -c '
import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f).read(), f)
' "${pythons[@]}" || { echo "FAIL syntax: a Python script (above)"; fail=1; }
echo "python: ${#pythons[@]} script(s) checked"

# StumpWM's main thread never waits on a program (CLAUDE.md, "Loading, and
# threads"): a run-shell-command that collects its output is allowed in the
# layer only inside the helpers that run it from a thread of their own, and
# the two places tests/lib/waits.py names. Anything else goes through
# vikix-shell-then or vikix-later (commands.lisp).
if out=$(python3 -I tests/lib/waits.py config/stumpwm/*.lisp config/stumpwm/vikix/*.lisp 2>&1); then
  echo "waits: $out"
else
  echo "FAIL waits: the main thread would wait on a program:"; sed 's/^/  /' <<<"$out"; fail=1
fi

# Scripts that are run as ./name must carry the executable bit (0.10.0
# reached GitHub without it, and ./install-1.sh failed with "Permission denied").
for f in install.sh install-*.sh install/*.sh bin/* tests/*.sh installer/vikix-installer installer/vikix-hwreport installer/firstboot installer/build-image.sh; do
  [ -x "$f" ] || { echo "FAIL not executable: $f"; fail=1; }
done
echo "executable bits checked"

# One shellcheck for the laptop and CI, said aloud: 0.11. SC2218 fires with
# 0.10 and older but not 0.11, which left CI red and the laptop green
# (2026-10-18, plans/DESIGN-ci.md 2). The one on PATH when it is 0.11, else
# the pinned one through uvx, else PATH's with a word of warning.
sc_want=0.11
sc_version() { "$@" --version 2>/dev/null | sed -n 's/^version: //p' | head -1; }
if command -v shellcheck >/dev/null && [[ $(sc_version shellcheck) == "$sc_want".* ]]; then
  sc=(shellcheck)
elif command -v uvx >/dev/null; then
  sc=(uvx --from shellcheck-py==0.11.0.1 shellcheck)
elif command -v shellcheck >/dev/null; then
  sc=(shellcheck); echo "(shellcheck $(sc_version shellcheck) on PATH is not $sc_want, and no uvx brings it: its warnings may differ from CI's)"
else
  echo "FAIL no shellcheck (install it, or uv for uvx)"; exit 1
fi
echo "shellcheck $(sc_version "${sc[@]}"): ${sc[*]}"
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
# The runner and CI's wrapper drop the machine's keys and agent settings
# before any test (the line in tests/run.sh says why); one of them without
# the line would hand every test the shell's keys again.
hermetic='for v in $(compgen -e); do case $v in *_API_KEY|*_KEY|*_TOKEN|*_SECRET|CLAUDE_CODE_*|CLAUDECODE|OLLAMA_HOST|ANTHROPIC_BASE_URL) unset "$v" ;; esac; done'
missing=$(grep -LF -- "$hermetic" tests/run.sh tests/ci.sh || true)
if [ -n "$missing" ]; then
  echo "FAIL isolation: these should drop the machine's keys before a test (the line in tests/run.sh):"
  echo "$missing" | sed 's/^/  /'; fail=1
else
  echo "isolation: the runner and tests/ci.sh drop the machine's keys before a test"
fi

# CI's steps name tests that are there and in tests/run.sh's list (the Void
# ones, packages, dry-run and editors, are in it too): a test renamed or
# dropped would otherwise be a red step, or one running nothing, found at
# the next push (plans/DESIGN-ci.md 6).
in_run=$(grep -oE 'tests\+?=\([^)]*\)' tests/run.sh | tr ' ()' '\n\n\n' | sed 's/^tests+\?=//' | grep -v '^$' || true)
bad=""
for n in $(grep -oE 'ci\.sh [a-z-]+"?$' .github/workflows/test.yml | awk '{print $2}' | tr -d '"' | sort -u); do   # the run: lines, not the prose about tests/ci.sh
  [ -x "tests/$n.sh" ] || bad="$bad $n (no tests/$n.sh)"
  grep -qx -- "$n" <<<"$in_run" || bad="$bad $n (not in tests/run.sh's list)"
done
if [ -n "$bad" ]; then
  echo "FAIL ci: .github/workflows/test.yml names a test the runner doesn't have:$bad"; fail=1
else
  echo "ci: every test the workflow runs is in tests/ and in tests/run.sh's list"
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
