#!/usr/bin/env bash
# tests/run.sh — run the tests that fit this machine.
#
#   tests/run.sh          the quick ones (about two minutes): lint, lisp (with
#                         sbcl), battery, home, services, backup (with
#                         restic), image, theme, bar, rofi,
#                         wallpaper, examples, dev-ai, notes, drives, firmware, fingerprint, updates, notifications, idle, capture,
#                         nightlight, update, windows, ai, ai-local, llm, ai-keys, agents, debug, dictate, voice, mcp, swank (with Quicklisp), webapp, features, nvim, emacs, welcome, menu (with sbcl), pkg, oneline, info (with makeinfo),
#                         and on Void also packages and dry-run
#   tests/run.sh --all    those, plus editors (several minutes, network)
#
# Each test is its own script in tests/ and can be run alone. GitHub runs
# them too: .github/workflows/test.yml.

set -uo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
# The tests make up a home folder, and Vikix follows the XDG variables
# where they are set; GitHub's runners set XDG_CONFIG_HOME, which would
# send a test's files into the runner's real config instead.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
cd "$(dirname "$0")" || exit 1
tests=(lint)
if command -v sbcl >/dev/null; then tests+=(lisp); else echo "(lisp needs sbcl; skipped here)"; fi
tests+=(battery home services image theme bar rofi wallpaper examples dev-ai notes drives firmware fingerprint updates notifications idle capture nightlight update windows ai ai-local llm ai-keys agents debug dictate voice mcp swank webapp features nvim emacs welcome menu pkg oneline)
if command -v restic >/dev/null; then tests+=(backup); else echo "(backup needs restic; skipped here)"; fi
if command -v makeinfo >/dev/null; then tests+=(info); else echo "(info needs makeinfo; skipped here)"; fi
if command -v xbps-query >/dev/null && [ "$(id -u)" -ne 0 ]; then
  tests+=(packages dry-run)
else
  echo "(packages and dry-run need Void and a normal user; skipped here)"
fi
[ "${1:-}" = --all ] && tests+=(editors)

failed=()
for t in "${tests[@]}"; do
  echo "=== $t"
  ./"$t".sh || failed+=("$t")
done
echo
if [ "${#failed[@]}" -eq 0 ]; then
  echo "all passed: ${tests[*]}"
else
  echo "FAILED: ${failed[*]}"
  exit 1
fi
