#!/usr/bin/env bash
# tests/changed-map.sh — tests/changed.sh places a change to bin/vikix by the
# part of the file it touches, in a made-up repository holding a copy of the
# real bin/vikix and tests with the real names:
#
#   - nothing changed maps to nothing; a header line to lint, man and vk
#   - one arm of main's case maps to that command's own test (tray) → tray),
#     a deleted line of the arm too, or to the tests naming the script the
#     arm hands over to (screens) → the test that runs vikix-screens)
#   - an arm with neither, run by hand in a test, maps to that test: the
#     version and help arms to vk, layout to layouts, snapshot to home,
#     migrate to update
#   - the update's and try's functions map to update and try; the vikix_*
#     functions to vk
#   - another function, main's own lines, the top level, a new arm with no
#     test, and an arm no test runs (rebuild-wm) all mean all: wider, never
#     narrower
#   - two parts in one change map to both; a committed change is seen as an
#     uncommitted one is; a changed test is added to what bin/vikix gives
#   - README.md alone maps to agents, the one test that reads it, not to the
#     tests that make up README.md files of their own
#   - a plan, a What page, bin/vikix-agent, lib/publish/ and a migration map
#     to the tests their rules name, never to all; a script with a test of
#     its own name maps to it; one with no test and no name is still all
#   - a test's name put into tests/run.sh's list maps to that test, one put
#     into a line of the map to it and changed-map; a comment in either to
#     nothing of its own; a name that is no test, a name taken out or any
#     other line to all
#
# Each case edits the copy and puts it back; nothing of Vikix's runs.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

repo=$t/repo
mkdir -p "$repo/tests" "$repo/bin"
cp "$here/tests/changed.sh" "$repo/tests/"
cp "$here/bin/vikix" "$repo/bin/vikix"
# Made-up tests: a test maps by its name, or by naming a script.
for n in lint man vk tray update try wifi capture layouts home; do
  printf '#!/usr/bin/env bash\n# tests/%s.sh\n' "$n" >"$repo/tests/$n.sh"
done
echo 'bash "$here/bin/vikix-screens" extend' >>"$repo/tests/capture.sh"
# update makes up a README.md of its own, as the real one does; agents reads the repository's.
echo 'echo hi >"$t/machine/README.md"' >>"$repo/tests/update.sh"
echo '# Vikix' >"$repo/README.md"
g() { git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
g init -q
g add bin tests README.md
g commit -q -m 'as it is'

vikix=$repo/bin/vikix
map()   { (cd "$repo" && tests/changed.sh "${1:-HEAD}" | tr '\n' ' ' | sed 's/ $//'); }
reset() { g checkout -q -- bin tests README.md; }
# edit "WHAT" EXPECTED SED-SCRIPT...: the copy edited so, maps to EXPECTED
edit() {
  local what=$1 want=$2; shift 2
  for s in "$@"; do sed -i "$s" "$vikix"; done
  [ -n "$(g status --porcelain)" ] || { echo "FAIL: $what: the edit changed nothing"; fail=1; }
  local got; got=$(map)
  check "$what maps to '$want', not '$got'" test "$got" = "$want"
  reset
}

check "nothing changed maps to nothing: '$(map)'" test -z "$(map)"
edit "a header line" "lint man vk" '2s/$/ (edited)/'
edit "the tray arm" "lint tray vk" 's/(run-commands \\"vikix-tray-\$1\\")/(run-commands \\"vikix-tray-$1\\") /'
edit "a line deleted from the tray arm" "lint tray vk" '/echo "  (the applets it starts/d'
edit "the wifi arm, its own test by name" "lint vk wifi" 's|^    wifi)        shift; exec|    wifi)        shift;  exec|'
edit "the screens arm, through the test naming vikix-screens" "capture lint vk" 's|^    screens)     shift; exec|    screens)     shift;  exec|'
edit "cmd_update" "lint try update" 's/^cmd_update() {$/cmd_update() {\n  :/'
edit "try_back" "lint try update" 's/^try_back() {$/try_back() {\n  :/'
edit "vikix_expand, the short forms" "lint vk" 's/^vikix_expand() {.*$/&\n  :/'
edit "cmd_doctor, a function with no test of its own" all 's/^cmd_doctor() {$/cmd_doctor() {\n  :/'
edit "the version arm, which vk runs by hand" "lint vk" 's#^    version|-v|--version) cat#    version|-v|--version)  cat#'
edit "the help arm, the same" "lint vk" 's#^    help|-h|--help) sed#    help|-h|--help)  sed#'
edit "the layout arm, run by layouts" "layouts lint vk" 's|^    layout)      shift; cmd_layout|    layout)      shift;  cmd_layout|'
edit "a line inside the snapshot arm, run by home" "home lint vk" 's|history_help; exit 0 ;; esac|history_help; exit 0 ;;  esac|'
edit "the migrate arm, as cmd_migrate" "lint update vk" 's|^    migrate)     cmd_migrate ;;|    migrate)     cmd_migrate  ;;|'
edit "the rebuild-wm arm, which no test runs" all 's|^    rebuild-wm)  VIKIX_REBUILD_WM=1|    rebuild-wm)   VIKIX_REBUILD_WM=1|'
edit "a new arm with no test" all 's|^  case ${1:-help} in$|  case ${1:-help} in\n    foo) echo hi ;;|'
edit "main's own line" all 's|^main() {$|main()  {|'
edit "the top level" all 's|^set -euo pipefail$|set -euo pipefail\n:|'
edit "the tray arm and a header line together" "lint man tray vk" \
  's/(run-commands \\"vikix-tray-\$1\\")/(run-commands \\"vikix-tray-$1\\") /' '2s/$/ (edited)/'

# A committed change is seen against the commit before it.
sed -i 's/(run-commands \\"vikix-tray-\$1\\")/(run-commands \\"vikix-tray-$1\\") /' "$vikix"
g commit -q -m 'the tray arm' -- bin/vikix
check "a committed tray edit maps to 'lint tray vk': '$(map HEAD~1)'" test "$(map HEAD~1)" = "lint tray vk"
check "and nothing against its own commit: '$(map)'" test -z "$(map)"

# Another changed file adds its tests to bin/vikix's.
sed -i 's/^cmd_update() {$/cmd_update() {\n  :/' "$vikix"
echo '# more' >>"$repo/tests/wifi.sh"
check "cmd_update and tests/wifi.sh: '$(map)'" test "$(map)" = "lint try update wifi"
reset

# README.md is read by agents alone; the tests naming it make up their own.
echo 'more' >>"$repo/README.md"
check "README.md alone maps to 'agents': '$(map)'" test "$(map)" = agents
reset

# The runner and the map themselves: a new test's name in their lists costs
# that test (a new test's name is in both, and once cost the quick set twice).
cat >"$repo/tests/run.sh" <<'RUN'
#!/usr/bin/env bash
# tests/run.sh — the runner: lint, man and vk.
tests=(lint)
tests+=(man vk)
echo "${tests[@]}"
RUN
g add tests/run.sh; g commit -q -m 'the runner' -- tests/run.sh
sed -i 's/^tests+=(man vk)$/tests+=(man tray vk)/' "$repo/tests/run.sh"
check "a test's name put in run.sh's list maps to it: '$(map)'" test "$(map)" = "lint tray"
reset
sed -i '2s/$/ (edited)/' "$repo/tests/run.sh"
check "a comment in run.sh maps to nothing of its own: '$(map)'" test "$(map)" = lint
reset
sed -i 's/^tests+=(man vk)$/tests+=(man nosuch vk)/' "$repo/tests/run.sh"
check "a word that is no test in run.sh's list maps to all: '$(map)'" test "$(map)" = all
reset
sed -i 's/^tests+=(man vk)$/tests+=(man)/' "$repo/tests/run.sh"
check "a name taken out of run.sh's list maps to all: '$(map)'" test "$(map)" = all
reset
sed -i 's/^tests=(lint)$/tests=(lint)\n:/' "$repo/tests/run.sh"
check "another line of run.sh maps to all: '$(map)'" test "$(map)" = all
reset
sed -i 's|^    bin/vikix-agent) add house agents ai codex ;;$|    bin/vikix-agent) add house agents ai codex tray ;;|' "$repo/tests/changed.sh"
check "a test's name put in a line of the map maps to it and changed-map: '$(map)'" test "$(map)" = "changed-map lint tray"
reset
sed -i 's|^    bin/vikix-agent) add house agents ai codex ;;$|    bin/vikix-agents) add house agents ai codex ;;|' "$repo/tests/changed.sh"
check "a changed word in a line of the map maps to all: '$(map)'" test "$(map)" = all
reset

# Files whose tests a rule names, which the name rule would have made all:
# a plan, a What page, bin/vikix-agent, lib/publish/, a migration; a script
# with a test of its own name; one with none is still all.
mkdir -p "$repo/lib/publish" "$repo/config/plans" "$repo/config/what" "$repo/migrations"
echo 'x = 1' >"$repo/lib/plan.py"; echo 'a = 1' >"$repo/config/plans/one.toml"; echo 'A page.' >"$repo/config/what/field.md"
printf '#!/usr/bin/env bash\n' >"$repo/bin/vikix-agent"; echo '-- spell' >"$repo/lib/publish/spell.lua"
printf '#!/usr/bin/env bash\n' >"$repo/migrations/1.sh"
printf '#!/usr/bin/env bash\n' >"$repo/bin/vikix-lazarus"; printf '#!/usr/bin/env bash\n# tests/lazarus.sh\n' >"$repo/tests/lazarus.sh"
printf '#!/usr/bin/env bash\n' >"$repo/bin/vikix-nobody"
echo '# the migrations run stubbed' >>"$repo/tests/update.sh"
g add bin lib config migrations tests; g commit -q -m 'more files'
own() {   # own FILE EXPECTED — a line added to FILE maps to EXPECTED
  echo '# more' >>"$repo/$1"
  local got; got=$(map)
  check "$1 maps to '$2', not '$got'" test "$got" = "$2"
  g checkout -q -- "$1"
}
own lib/plan.py "codex lint office-ui plan"
own config/plans/one.toml "codex office-ui plan"
own config/what/field.md what
own bin/vikix-agent "agents ai codex house lint man"
own lib/publish/spell.lua "lint publish"
own migrations/1.sh "lint update"
own bin/vikix-lazarus "lazarus lint man"
own bin/vikix-nobody all

# The office's front and a part of it (lib/agents/) map to the office's tests,
# never to all: fifteen tests name the front, none names a part's file.
mkdir -p "$repo/lib/agents"
printf '#!/usr/bin/env bash\n' >"$repo/bin/vikix-agents"; echo 'x = 1' >"$repo/lib/agents/turns.py"
for n in office titles house handoff office-ui mcp tester plan door nyxt codex; do
  printf '#!/usr/bin/env bash\n# tests/%s.sh: bin/vikix-agents\n' "$n" >"$repo/tests/$n.sh"
done
for n in agents ai day debug dictate records; do printf '#!/usr/bin/env bash\n# bin/vikix-agents\n' >"$repo/tests/$n.sh"; done
g add bin lib tests; g commit -q -m 'the office'
echo '# more' >>"$repo/lib/agents/turns.py"; echo '# more' >>"$repo/bin/vikix-agents"
check "the office's front and a part map to the office's tests: '$(map)'" \
  test "$(map)" = "codex door handoff house lint man mcp nyxt office office-ui plan tester titles"
g checkout -q -- bin lib tests

# rescue runs alone (holding every run on the machine back), so a layer file
# doesn't bring it: rescue.lisp and the loader do. And a Lisp file most tests
# name (registry.lisp) maps to them, never to all.
mkdir -p "$repo/config/stumpwm/vikix"
echo ';; day' >"$repo/config/stumpwm/vikix/day.lisp"; echo ';; rescue' >"$repo/config/stumpwm/vikix/rescue.lisp"; echo ';; registry' >"$repo/config/stumpwm/vikix/registry.lisp"
for n in lisp menu rules rescue registry a b c d e f g h i j k l m n; do printf '#!/usr/bin/env bash\n# tests/%s.sh: registry.lisp\n' "$n" >"$repo/tests/$n.sh"; done
g add config tests; g commit -q -m 'the layer'
echo ';; more' >>"$repo/config/stumpwm/vikix/day.lisp"
check "a layer file maps to the Lisp tests, without rescue: '$(map)'" bash -c '[[ " $1 " == *" lisp "* && " $1 " != *" rescue "* && " $1 " != *" all "* ]]' _ "$(map)"
reset; g checkout -q -- config
echo ';; more' >>"$repo/config/stumpwm/vikix/rescue.lisp"
check "rescue.lisp brings rescue: '$(map)'" bash -c '[[ " $1 " == *" rescue "* ]]' _ "$(map)"
g checkout -q -- config
echo ';; more' >>"$repo/config/stumpwm/vikix/registry.lisp"
check "a Lisp file more than twelve tests name maps to them, not to all: '$(map)'" bash -c '[[ " $1 " != *" all "* && " $1 " == *" n "* && " $1 " == *" registry "* ]]' _ "$(map)"
g checkout -q -- config

[ "$fail" = 0 ] && echo "changed-map: a change to bin/vikix maps to its part's tests (header, an arm, update's and try's functions, the short forms), anything else to all"
exit "$fail"
