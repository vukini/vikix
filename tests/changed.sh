#!/usr/bin/env bash
# tests/changed.sh [REF] — the tests for what changed since REF (default
# origin/main), uncommitted and new files included: one name a line, or
# "all" when the change reaches too far to pick. tests/run.sh --changed
# runs them.
#
# A file maps to the tests that name it (a test that runs bin/vikix-esploro
# says so), plus a few rules for what names can't tell: a test script maps
# to itself, StumpWM's files to the Lisp tests, docs/ to the manual's. A
# file no test names, or one most of them name (bin/vikix), means all: a
# guess that leaves a test out would pass a change that breaks it.
set -uo pipefail
# It runs nothing of Vikix's, but lint holds every script here to the tests' rules.
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's
cd "$(dirname "$0")/.." || exit 1
ref=${1:-origin/main}
git rev-parse -q --verify "$ref^{commit}" >/dev/null || { echo all; exit 0; }

mapfile -t files < <({ git diff --name-only "$ref"; git ls-files --others --exclude-standard; } | sort -u)
out=()
add() { out+=("$@"); }
all=0
for f in "${files[@]}"; do
  case $f in
    # Words, plans and designs: nothing runs them.
    TODO*.md|IDEAS.md|bugs.md|DESIGN-*.md|APP-IDEAS.md|TUTORIALS.md|ai-desktop.md|CLAUDE.md|NYXT-GUIDE.md|VERSION|.gitignore) continue ;;
    tests/run.sh|tests/changed.sh) all=1 ;;
    .claude/release) add release ;;
    tests/*.sh) add "$(basename "$f" .sh)" ;;
    tests/*) all=1 ;;
    docs/*|lib/md2texi.py|lib/build-guide.sh) add info docs-open ;;
    # The agents' guide is made from the skill.
    config/claude/*) add agents ;;
    site/*) add lint ;;
    # What the full run's slow tests cover: the quick set can't vouch for it.
    install/*|packages/*|features.list|bundles.list|dev/*) all=1 ;;
    *)
      mapfile -t hits < <(grep -lF -- "$(basename "$f")" tests/*.sh | xargs -r -n1 basename | sed 's/\.sh$//' | grep -vx 'run\|changed')
      if [ "${#hits[@]}" -eq 0 ] || [ "${#hits[@]}" -gt 12 ]; then all=1; else add "${hits[@]}"; fi ;;
  esac
  case $f in
    config/stumpwm/*) add lisp errors menu rules viri main drawer keys registry why gather focus rescue reload resume palette used events ;;
  esac
  case $f in
    # A command's man page is made from its header (lib/man.py).
    bin/vikix*|lib/man.py|docs/commands.md) add man ;;
  esac
  case $f in
    # The skill's list of keys is made from these (lib/skill-keys.sh).
    config/stumpwm/vikix/why.lisp|bin/vikix-why|bin/vikix-notifications) add why mcp notifications used ;;
    config/stumpwm/vikix/used.lisp|bin/vikix-used) add used why palette ;;
    config/stumpwm/vikix/registry.lisp|lib/registry.sh) add agents registry menu mcp webapp plugin project screens esploro memory docs-open welcome ;;
    config/stumpwm/vikix/keys.lisp|config/stumpwm/vikix/help.lisp|bin/vikix-plugin|README.md|lib/skill-keys.sh) add agents ;;
  esac
  case $f in
    bin/*|lib/*|tests/*|migrations/*|install/*|*.sh) add lint ;;
  esac
done
if [ "$all" = 1 ]; then echo all; exit 0; fi
[ "${#out[@]}" -gt 0 ] && printf '%s\n' "${out[@]}" | sort -u
exit 0
