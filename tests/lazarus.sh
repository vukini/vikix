#!/usr/bin/env bash
# tests/lazarus.sh — 65-languages builds the docked Lazarus IDE once.
#
#   With Void's Lazarus there it builds with the widget set found and the
#   docking packages; a built IDE newer than Void's is left alone; a failed
#   build warns once and is remembered, so the next run doesn't try again;
#   a new Lazarus from Void, or VIKIX_REBUILD_LANGS=1, tries again; a build
#   that works forgets the failure.
#
# lazbuild is a stand-in; Void's Lazarus is a made-up folder.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$HOME/.config/vikix" "$t/bin" "$VIKIX_STATE"
echo pascal > "$HOME/.config/vikix/features"   # not lisp: no PicoLisp build
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"

laz="$t/lazarus"
mkdir -p "$laz/lcl/units/x86_64-linux/qt5"
printf 'void' > "$laz/lazarus"; touch -d '2026-01-01' "$laz/lazarus"

# lazbuild: builds ~/.lazarus/bin/lazarus unless $t/break is there.
cat > "$t/bin/lazbuild" <<END
#!/bin/sh
case "\$1" in --version) echo 4.4; exit 0 ;; esac
echo "lazbuild \$*" >> "$calls"
[ -e "$t/break" ] && { echo "Error: a compile error"; exit 1; }
mkdir -p "$HOME/.lazarus/bin"; printf x > "$HOME/.lazarus/bin/lazarus"; chmod +x "$HOME/.lazarus/bin/lazarus"
END
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_LAZARUS_DIR="$laz"
stage() { bash "$here/install/65-languages.sh" > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the stage should carry on"; fail=1; }; }
builds() { grep -c '^lazbuild' "$calls" || true; }

# A failed build: warned once, remembered.
touch "$t/break"
stage
check "it should build with Qt5 and the docking packages: $(cat "$calls")" \
  grep -q -- "--ws=qt5 --add-package $laz/components/anchordocking/design/anchordockingdsgn.lpk" "$calls"
check "a failed build should warn: $(cat "$t/out")" grep -q "didn't build" "$t/out"
check "a failed build should be remembered" test -s "$VIKIX_STATE/lazarus-build-failed"
stage
check "the same failure shouldn't be tried again: $(builds) builds" test "$(builds)" = 1
check "it should say why it isn't trying" grep -q "didn't build last time" "$t/out"
check "and not warn again" test -z "$(grep '!!' "$t/out" || true)"

# Asked to: tried again.
VIKIX_REBUILD_LANGS=1 stage
check "VIKIX_REBUILD_LANGS=1 should try again" test "$(builds)" = 2

# Void's Lazarus changes: tried again, and this time it builds.
rm -f "$t/break"
touch -d '2026-02-01' "$laz/lazarus"
stage
check "a new Lazarus should be tried: $(builds) builds" test "$(builds)" = 3
check "the IDE should be built" test -x "$HOME/.lazarus/bin/lazarus"
check "a build that works should forget the failure" test ! -e "$VIKIX_STATE/lazarus-build-failed"

# Built and newer than Void's: left alone.
stage
check "a built IDE shouldn't be rebuilt: $(builds) builds" test "$(builds)" = 3
check "it should say it's built" grep -q "already built" "$t/out"

[ "$fail" = 0 ] && echo "lazarus: builds once, remembers a failure, tries again when Lazarus changes"
exit "$fail"
