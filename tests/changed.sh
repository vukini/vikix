#!/usr/bin/env bash
# tests/changed.sh [REF] — the tests for what changed since REF (default
# origin/main), uncommitted and new files included: one name a line, or
# "all" when the change reaches too far to pick. tests/run.sh --changed
# runs them.
#
# A file maps to the tests that name it (a test that runs bin/vikix-esploro
# says so), plus a few rules for what names can't tell: a test script maps
# to itself, StumpWM's files to the Lisp tests, docs/ to the manual's. A
# file no test names, or one most of them name, means all: a guess that
# leaves a test out would pass a change that breaks it.
#
# bin/vikix is named by nearly every test, so its hunks are placed by where
# they land in the file instead (vikix_hunks): the header, which the man
# pages, vk's word lists and lint read, maps to lint, man and vk; one arm
# of main's case to that command's own test and the tests naming the
# script it hands over to (tray) → tray; wifi) → wifi), with vk, which runs
# the dispatch; the update's and try's functions to update and try; the
# vikix_* functions (the short forms, completion) to vk. Any other line
# (another function, the top level, an arm with no test) means all, and a
# hunk across two of these maps to both: wider, never narrower.
# tests/changed-map.sh checks this on a copy of bin/vikix.
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
naming() {   # naming WORD — the tests naming WORD, one a line
  # changed-map names scripts only to make up a repository.
  grep -lF -- "$1" tests/*.sh | xargs -r -n1 basename | sed 's/\.sh$//' | grep -vx 'run\|changed\|changed-map'
}
named() {   # named WORD — the tests naming WORD, or all when none does, or too many
  mapfile -t hits < <(naming "$1")
  if [ "${#hits[@]}" -eq 0 ] || [ "${#hits[@]}" -gt 12 ]; then all=1; else add "${hits[@]}"; fi
}
vikix_hunks() {   # the parts of bin/vikix the diff touches: one a line, a part once a hunk
  # The file first, each line given its part; then the diff's hunk headers,
  # whose new-side lines (a deletion's two neighbours) name the parts. A part
  # is "header", "top" (the lines in no function), "fn NAME", "main" (main's
  # own lines) or "arm WORDS SCRIPTS..." (one arm of main's case, with the
  # bin/vikix-* scripts it hands over to; vikix-eval is how an arm reaches
  # the desktop, not what it is about).
  git diff -U0 "$ref" -- bin/vikix | awk '
    FNR == NR {
      n = NR
      if (!code && $0 ~ /^#/) { part[NR] = "header"; next }
      code = 1
      if ($0 ~ /^main\(\) *\{/) { fn = "main"; part[NR] = "main"; next }
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/) {
        name = $0; sub(/\(\).*/, "", name)
        part[NR] = "fn " name
        if ($0 !~ /\}[ \t]*$/) fn = name   # a one-line function ends on its line
        next
      }
      if ($0 ~ /^\}/) { part[NR] = (fn == "") ? "top" : (fn == "main" ? "main" : "fn " fn); fn = ""; arm = ""; next }
      if (fn == "main") {
        if (match($0, /^    [^ )][^)]*\)/)) arm = substr($0, 5, RLENGTH - 5)
        if (arm == "") { part[NR] = "main"; next }
        part[NR] = "arm " arm
        line = $0
        while (match(line, /bin\/vikix-[a-z][a-z-]*/)) {
          s = substr(line, RSTART + 4, RLENGTH - 4); line = substr(line, RSTART + RLENGTH)
          if (s != "vikix-eval" && index(" " scripts[arm] " ", " " s " ") == 0) scripts[arm] = scripts[arm] " " s
        }
        next
      }
      part[NR] = (fn == "") ? "top" : "fn " fn
      next
    }
    /^@@ / {
      split($3, new, ","); from = substr(new[1], 2) + 0; count = (2 in new) ? new[2] + 0 : 1   # numbers, or i > n compares text
      to = from + count - 1
      if (count == 0) { to = from + 1 }   # a deletion: the lines either side
      delete seen
      for (i = from; i <= to; i++) {
        p = (i < 1) ? "top" : (i > n ? "top" : part[i])
        if (p in seen) continue
        seen[p] = 1
        if (p ~ /^arm /) print p scripts[substr(p, 5)]; else print p
      }
    }' bin/vikix -
}
for f in "${files[@]}"; do
  case $f in
    # Words, plans and designs: nothing runs them.
    TODO*.md|IDEAS.md|bugs.md|DESIGN-*.md|APP-IDEAS.md|TUTORIALS.md|ai-desktop.md|CLAUDE.md|NYXT-GUIDE.md|VERSION|.gitignore) continue ;;
    tests/office-ui*|lib/office.py|config/emacs/vikix-office.el) add office-ui ;;
    tests/run.sh|tests/changed.sh) all=1 ;;
    .claude/release) add release ;;
    tests/*.sh) add "$(basename "$f" .sh)" ;;
    tests/*) all=1 ;;
    docs/*|lib/md2texi.py|lib/build-guide.sh) add info docs-open ;;
    # The agents' guide is made from the skill.
    config/claude/*) add agents ;;
    site/*) add lint ;;
    # Only agents reads the repository's README.md (its table of keys, through
    # lib/skill-keys.sh --check); the name rule would add the tests that make up
    # README.md files of their own (update, try, docs, examples, what ...).
    README.md) add agents ;;
    # What the full run's slow tests cover: the quick set can't vouch for it.
    install/*|packages/*|features.list|bundles.list|dev/*) all=1 ;;
    bin/vikix)
      while read -r kind name scripts; do
        case "$kind $name" in
          header\ *) add lint man vk ;;
          fn\ cmd_update|fn\ cmd_migrate|fn\ set_aside_local_changes|fn\ pull_failed|fn\ upgrade_user_tools|fn\ update_help|fn\ cmd_try|fn\ try_*) add update try ;;
          fn\ vikix_*) add vk ;;
          arm\ *)
            # The command's own test, and the tests naming the script it hands
            # over to; neither means all, and so does a script most tests name.
            hits=()
            IFS='|' read -ra words <<<"$name"
            for w in "${words[@]}"; do [ -e "tests/$w.sh" ] && hits+=("$w"); done
            for w in $scripts; do
              mapfile -t more < <(naming "$w")
              [ "${#more[@]}" -gt 12 ] && all=1
              hits+=("${more[@]}")
            done
            if [ "${#hits[@]}" -gt 0 ]; then add "${hits[@]}"; else all=1; fi
            add vk ;;
          *) all=1 ;;
        esac
      done < <(vikix_hunks) ;;
    *) named "$(basename "$f")" ;;
  esac
  case $f in
    config/stumpwm/*) add lisp errors menu rules viri main drawer keys registry maps why what gather workspaces office focus rescue reload resume palette used events focus-time ;;
  esac
  case $f in
    # A command's man page is made from its header (lib/man.py).
    bin/vikix-*|lib/man.py|docs/commands.md) add man ;;
  esac
  case $f in
    # The skill's list of keys is made from these (lib/skill-keys.sh).
    config/stumpwm/vikix/why.lisp|bin/vikix-why|bin/vikix-notifications) add why mcp notifications used ;;
    config/stumpwm/vikix/agents.lisp|bin/vikix-agents|config/claude/office.json) add office titles house handoff office-ui mcp tester ;;
    lib/handoff.py) add office titles house handoff office-ui mcp release ;;
    bin/vikix-agent) add house agents ai ;;
    config/stumpwm/vikix/what.lisp|bin/vikix-what|config/what/*) add what ;;
    bin/vikix-docs) add docs what mcp ;;
    config/stumpwm/vikix/used.lisp|bin/vikix-used) add used why palette ;;
    config/stumpwm/vikix/door.lisp|bin/vikix-door|config/stumpwm/vikix/swank.lisp|bin/vikix-eval|bin/vikix-mcp|config/stumpwm/vikix/socket.lisp|tests/lib/wm.sh) add door socket swank mcp propose ;;
    config/stumpwm/vikix/registry.lisp|lib/registry.sh) add agents registry menu mcp webapp plugin project screens esploro memory docs-open welcome ;;
    config/stumpwm/vikix/keys.lisp|config/stumpwm/vikix/help.lisp|bin/vikix-plugin|lib/skill-keys.sh) add agents ;;
  esac
  case $f in
    bin/*|lib/*|tests/*|migrations/*|install/*|*.sh) add lint ;;
  esac
done
if [ "$all" = 1 ]; then echo all; exit 0; fi
[ "${#out[@]}" -gt 0 ] && printf '%s\n' "${out[@]}" | sort -u
exit 0
