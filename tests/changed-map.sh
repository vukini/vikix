#!/usr/bin/env bash
# tests/changed-map.sh — tests/changed.sh places a change to bin/vikix by the
# part of the file it touches, in a made-up repository holding a copy of the
# real bin/vikix and tests with the real names:
#
#   - nothing changed maps to nothing; a header line to lint, man and vk
#   - one arm of main's case maps to that command's own test (tray) → tray),
#     a deleted line of the arm too, or to the tests naming the script the
#     arm hands over to (screens) → the test that runs vikix-screens)
#   - the update's and try's functions map to update and try; the vikix_*
#     functions to vk
#   - another function, main's own lines, the top level, a new arm with no
#     test, and an arm with none all mean all: wider, never narrower
#   - two parts in one change map to both; a committed change is seen as an
#     uncommitted one is; a changed test is added to what bin/vikix gives
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
for n in lint man vk tray update try wifi capture; do
  printf '#!/usr/bin/env bash\n# tests/%s.sh\n' "$n" >"$repo/tests/$n.sh"
done
echo 'bash "$here/bin/vikix-screens" extend' >>"$repo/tests/capture.sh"
g() { git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
g init -q
g add bin tests
g commit -q -m 'as it is'

vikix=$repo/bin/vikix
map()   { (cd "$repo" && tests/changed.sh "${1:-HEAD}" | tr '\n' ' ' | sed 's/ $//'); }
reset() { g checkout -q -- bin tests; }
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
edit "the version arm, which no test is named for" all 's|^    version)     cat|    version)      cat|'
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

[ "$fail" = 0 ] && echo "changed-map: a change to bin/vikix maps to its part's tests (header, an arm, update's and try's functions, the short forms), anything else to all"
exit "$fail"
