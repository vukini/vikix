#!/usr/bin/env bash
# tests/run.sh — run the tests that fit this machine.
#
#   tests/run.sh          the quick ones (about two minutes): lint, lisp (with
#                         sbcl), battery, home, services, backup (with
#                         restic), image, theme, theme-import, bar, rofi,
#                         wallpaper, examples, dev-ai, notes, drives, firmware, fingerprint, firewall, updates, notifications, idle, lock, lazarus, capture,
#                         nightlight, update, windows, ai, ai-local, llm, ai-keys, agents, debug, dictate, voice, lisp-apps, mcp, swank (with Quicklisp), webapp, features, nvim, emacs, welcome, menu (with sbcl), pkg, oneline, info (with makeinfo),
#                         and on Void also packages and dry-run
#   tests/run.sh --quick  the same without the slow ones that check only
#                         one corner: packages and dry-run (Void's mirror,
#                         over the network), examples (builds every
#                         language's examples) and lazarus. For changes that
#                         touch none of install/, packages/, features.list, dev/
#   tests/run.sh --all    those, plus editors (several minutes, network)
#
# Each test is its own script in tests/ and can be run alone. GitHub runs
# them too: .github/workflows/test.yml.

set -uo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# The tests make up a home folder, and Vikix follows the XDG variables
# where they are set; GitHub's runners set XDG_CONFIG_HOME, which would
# send a test's files into the runner's real config instead.
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
cd "$(dirname "$0")" || exit 1
mode=${1:-}
case $mode in ''|--quick|--all) ;; *) echo "usage: tests/run.sh [--quick|--all]" >&2; exit 2 ;; esac
tests=(lint)
if command -v sbcl >/dev/null; then tests+=(lisp); else echo "(lisp needs sbcl; skipped here)"; fi
tests+=(battery home services lisp-stage image theme theme-import bar rofi wallpaper examples dev-ai notes drives firmware fingerprint firewall updates notifications idle lock lazarus capture nightlight update windows ai ai-local llm ai-keys agents debug dictate voice lisp-apps hype mcp swank webapp features nvim emacs editor-theme welcome menu pkg oneline)
if command -v restic >/dev/null; then tests+=(backup); else echo "(backup needs restic; skipped here)"; fi
if command -v makeinfo >/dev/null; then tests+=(info); else echo "(info needs makeinfo; skipped here)"; fi
# --quick leaves these out (the run says so); the full run and GitHub keep them.
slow=(examples lazarus)
if [ "$mode" = --quick ]; then
  kept=()
  for t in "${tests[@]}"; do [[ " ${slow[*]} " == *" $t "* ]] || kept+=("$t"); done
  tests=("${kept[@]}")
  echo "(${slow[*]} packages dry-run left out: --quick)"
elif command -v xbps-query >/dev/null && [ "$(id -u)" -ne 0 ]; then
  tests+=(packages dry-run)
else
  echo "(packages and dry-run need Void and a normal user; skipped here)"
fi
[ "$mode" = --all ] && tests+=(editors)

failed=() took=()
for t in "${tests[@]}"; do
  echo "=== $t"
  start=$SECONDS
  ./"$t".sh || failed+=("$t")
  took+=("$((SECONDS - start)) $t")
done
echo
# The slow ones, so a run that takes long says why.
echo "slowest: $(printf '%s\n' "${took[@]}" | sort -rn | head -5 | awk '{printf "%s %ss  ", $2, $1}')"
if [ "${#failed[@]}" -eq 0 ]; then
  echo "all passed: ${tests[*]}"
else
  echo "FAILED: ${failed[*]}"
  exit 1
fi
