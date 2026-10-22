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
# the dispatch; an arm with neither, but a test that runs the command by
# hand, to that one (version) and help) → vk, layout) → layouts, snapshot)
# → home, migrate) → update, as cmd_migrate); the update's and try's
# functions to update and try; the vikix_* functions (the short forms,
# completion) to vk. Any other line (another function, the top level, an
# arm no test runs: doctor), rebuild-wm)) means all, and a hunk across two
# of these maps to both: wider, never narrower.
# A file whose tests are named in a rule of its own (a plan, a What page,
# bin/vikix-agent, lib/publish/, a migration) is kept from the name rule, or
# that rule made all first and the rule of its own never counted. A command's
# own test counts for its script (bin/vikix-lazarus: lazarus), as for its arm.
# tests/run.sh and tests/changed.sh themselves are read the same way
# (list_names): a hunk that only puts test names into a list (a new test's
# name in run.sh's list and in a line of the map here) maps to those tests,
# a hunk of comments to nothing, and any other change to all, since it may
# change how every test runs or is picked. Before, a new test cost the whole
# quick set twice over, its name being in both files (2026-10-14).
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
list_names() {   # list_names FILE — the test names FILE's hunks add to its lists, one a line; "all" when a hunk does more
  # A hunk is harmless when every line of it is a comment, and a list
  # change when it replaces one line by the same line with test names put
  # in (words split at blanks, brackets and commas; each new word is a test
  # in tests/). Anything else (a new line, a changed word, a name that is no
  # test) means all. Names are checked against the files, so a misspelt one
  # fails to all rather than to nothing.
  local tests t
  tests=" "; for t in tests/*.sh; do t=${t#tests/}; tests="$tests${t%.sh} "; done
  git diff -U0 "$ref" -- "$1" | awk -v tests="$tests" '
    function judge(   i, j, k, n, m, o, nw, ow, extra) {
      if (!nminus && !nplus) return
      for (i = 1; i <= nminus; i++) if (minus[i] !~ /^[ \t]*#/) break
      for (j = 1; j <= nplus; j++) if (plus[j] !~ /^[ \t]*#/) break
      if (i > nminus && j > nplus) { nminus = nplus = 0; return }   # comments only
      if (nminus != 1 || nplus != 1) { print "all"; exit }
      n = split(minus[1], ow, /[ \t(),]+/); m = split(plus[1], nw, /[ \t(),]+/)
      k = 1
      for (j = 1; j <= m; j++) {
        if (k <= n && nw[j] == ow[k]) { k++; continue }
        if (nw[j] == "" || index(tests, " " nw[j] " ") == 0) { print "all"; exit }
        print nw[j]
      }
      if (k <= n) { print "all"; exit }   # a word of the old line is gone
      nminus = nplus = 0
    }
    /^(diff|index|---|\+\+\+) / { next }
    /^@@ / { judge(); next }
    /^-/ { minus[++nminus] = substr($0, 2); next }
    /^\+/ { plus[++nplus] = substr($0, 2); next }
    END { judge() }'
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
          # Never an unset scripts[arm] inside index(): gawk 5.4.1 (Void,
          # 2026-10-22) makes the element it creates there the number 0, and
          # the arm came out as "wifi0 vikix-wifi", which no test is: all.
          have = (arm in scripts) ? scripts[arm] : ""
          if (s != "vikix-eval" && index(" " have " ", " " s " ") == 0) scripts[arm] = have " " s
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
    TODO*.md|IDEAS.md|ARCHIVE.md|bugs.md|plans/*|NYXT-GUIDE.md|VERSION|.gitignore) continue ;;
    CLAUDE.md) add codex ;;   # Codex is given it whole, under a cap the launcher sets
    tests/office-ui*|lib/office.py|config/emacs/vikix-office.el) add office-ui codex ;;
    tests/network*|bin/vikix-network|config/emacs/vikix-network.el) add network ;;
    bin/vikix-node) add nodes man ;;
    tests/run.sh|tests/changed.sh)
      # A new test's name put in the list or the map costs that test alone
      # (and the map's own test); anything else here means all.
      mapfile -t hits < <(list_names "$f")
      if [[ " ${hits[*]} " == *" all "* ]]; then all=1; else add "${hits[@]}"; fi
      [ "$f" = tests/changed.sh ] && add changed-map ;;
    .claude/release) add release ;;
    lib/music/*|config/music/*|bin/vikix-music|tests/music/*) add music ;;
    tests/*.sh) add "$(basename "$f" .sh)" ;;
    tests/lib/fake-swank.py) add cuis ;;   # the stand-in Swank the Cuis test drives the image against
    tests/lib/own_home.py) add office-ui tasks scheduler ;;   # the test home the office's Python tests claim
    tests/decisions.py) add tasks ;;   # run by tests/tasks.sh
    tests/scheduler.py) add scheduler ;;
    tests/*) all=1 ;;
    docs/*|lib/md2texi.py|lib/build-guide.sh) add info docs-open docs ;;   # the catalogue (vikix docs) reads the guides too
    # The agents' guide is made from the skill.
    config/claude/*) add agents ;;
    site/*) add lint ;;
    cuis/*) add cuis ;;   # Vikix's Smalltalk
    # The office's front and its parts: their tests are named below (fifteen
    # tests name bin/vikix-agents, and none names a part by its file, which
    # the name rule would both make all).
    bin/vikix-agents|lib/agents/*) ;;
    # The same for the plans and the What pages, whose tests are named below:
    # no test names a plan file or a page, and the rules below were dead
    # for them, the name rule having made all first (31 of 53 tester runs
    # had fallen to the whole set by 2026-10-14).
    lib/plan.py|config/plans/*|config/what/*) ;;
    # Twenty tests name bin/vikix-agent (those naming bin/vikix-agents among
    # them): they, never all.
    bin/vikix-agent) mapfile -t hits < <(naming vikix-agent); add "${hits[@]}" ;;
    # The one test of the pipeline takes the folder whole; "build" is a word
    # most tests have, and nobody names spell.lua.
    lib/publish/*) add publish ;;
    # A migration's name is nobody's: the tests that run them stubbed (update,
    # try) or read one (features), and lint for the script.
    migrations/*) mapfile -t hits < <(naming migrations); add "${hits[@]}" ;;
    # A command's own test counts for its script (bin/vikix-lazarus →
    # lazarus) as it does for its arm of bin/vikix, with the tests naming it.
    bin/vikix-*)
      mapfile -t hits < <(naming "$(basename "$f")")
      [ -e "tests/${f#bin/vikix-}.sh" ] && hits+=("${f#bin/vikix-}")
      if [ "${#hits[@]}" -eq 0 ] || [ "${#hits[@]}" -gt 12 ]; then all=1; else add "${hits[@]}"; fi ;;
    # Only agents reads the repository's README.md (its table of keys, through
    # lib/skill-keys.sh --check); the name rule would add the tests that make up
    # README.md files of their own (update, try, docs, examples, what ...).
    README.md) add agents ;;
    # What the full run's slow tests cover: the quick set can't vouch for it.
    # A stage of install/ maps to the tests naming it (40-config: home,
    # update, man, info ...; one no test names is all, as named says);
    # 10-packages, the lists and the features stay all, being what gets
    # installed. Six lines in 40-config once cost the whole set (2026-10-16).
    packages/*|features.list|bundles.list|dev/*|install/10-packages.sh) all=1 ;;
    install/*.sh) named "$(basename "$f" .sh)" ;;
    install/*) all=1 ;;
    bin/vikix)
      while read -r kind name scripts; do
        case "$kind $name" in
          header\ *) add lint man vk ;;
          fn\ cmd_update|fn\ cmd_migrate|fn\ set_aside_local_changes|fn\ pull_failed|fn\ upgrade_user_tools|fn\ update_help|fn\ cmd_try|fn\ try_*) add update try ;;
          fn\ vikix_*) add vk ;;
          # Arms that hand to no script and have no test of their own, but
          # are run by hand in one: a change to the version arm once cost the
          # whole suite (2026-10-09).
          arm\ version*|arm\ help*) add vk ;;      # vk vers, vk upd --help
          arm\ migrate) add update vk ;;           # as cmd_migrate, which it calls
          arm\ layout) add layouts vk ;;           # vikix layout save, NAME, list
          arm\ snapshot*) add home vk ;;           # snapshot, undo, undo again, --help
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
    # A layer file most tests name (registry.lisp: seventeen) has its tests
    # in the rules below; the name rule's "too many means all" cost the
    # quick set for one Help entry (2026-10-11).
    config/stumpwm/*) mapfile -t hits < <(naming "$(basename "$f")"); [ "${#hits[@]}" -eq 0 ] || add "${hits[@]}" ;;
    *) named "$(basename "$f")" ;;
  esac
  case $f in
    # rescue (and times, soak) run alone, holding every other run on the
    # machine back, so they come only when the change reaches them: what
    # rescue.lisp, errors.lisp and the loader do (below), never a layer file.
    config/stumpwm/*) add lisp errors menu rules viri main drawer keys registry maps why what gather workspaces refile office focus reload resume palette used events focus-time ;;
  esac
  case $f in
    config/stumpwm/vikix/rescue.lisp|config/stumpwm/vikix/errors.lisp|config/stumpwm/init.lisp|bin/vikix-rescue|bin/vikix-lock) add rescue ;;
  esac
  case $f in
    # A command's man page is made from its header (lib/man.py).
    bin/vikix-*|lib/man.py|docs/commands.md) add man ;;
  esac
  case $f in
    # The skill's list of keys is made from these (lib/skill-keys.sh).
    config/stumpwm/vikix/why.lisp|bin/vikix-why|bin/vikix-notifications) add why mcp notifications used ;;
    config/stumpwm/vikix/agents.lisp|bin/vikix-agents|lib/agents/*|config/claude/office.json) add office titles house handoff office-ui mcp tester plan door nyxt codex tasks reconnect ;;
    lib/plan.py|config/plans/*) add plan office-ui codex ;;
    lib/handoff.py) add office titles house handoff office-ui mcp release plan codex tasks ;;
    lib/scheduler.py|tests/scheduler*) add scheduler tasks handoff office-ui ;;
    lib/tasks.py|migrations/1791912562.sh) add tasks handoff house office-ui mcp release plan codex ;;
    bin/vikix-agent) add house agents ai codex ;;
    config/codex/*) add handoff codex ;;
    config/stumpwm/vikix/what.lisp|bin/vikix-what|config/what/*) add what ;;
    bin/vikix-docs) add docs what mcp ;;
    config/stumpwm/vikix/used.lisp|bin/vikix-used) add used why palette ;;
    config/stumpwm/vikix/door.lisp|bin/vikix-door|config/stumpwm/vikix/swank.lisp|bin/vikix-eval|bin/vikix-mcp|config/stumpwm/vikix/socket.lisp|tests/lib/wm.sh) add door socket swank mcp propose cuis ;;
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
