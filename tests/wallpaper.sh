#!/usr/bin/env bash
# tests/wallpaper.sh — vikix-wallpaper shows the theme's picture until you
# choose one, keeps your choice across theme changes, gives a theme without
# a picture a plain background in its own colour, and its picker sets what
# was picked.
#
# feh, rofi and everything vikix theme reaches for are stand-ins, in a
# made-up home; nothing is drawn, and the desktop running the tests is
# never touched.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
H="$t/home"
mkdir -p "$t/bin" "$H/.config/vikix/themes" "$H/.config/vikix/theme" "$H/wallpapers" "$H/Pictures/Wallpapers"
log="$t/log"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
stub feh "echo \"feh \$*\" >> $log"
# rofi: keep what it was offered; answer with $ROFI_ANSWER, or cancel.
stub rofi "cat > $t/offered; [ -n \"\${ROFI_ANSWER:-}\" ] || exit 1; echo \"\$ROFI_ANSWER\""
export PATH="$t/bin:$PATH" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" DISPLAY=:7
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
wp() { : > "$log"; sh "$here/bin/vikix-wallpaper" "$@"; }
use_theme() { echo "$1" > "$H/.config/vikix/theme/current"; }

touch "$H/wallpapers/b2.jpg" "$H/wallpapers/b10.jpg" "$H/Pictures/Wallpapers/mine.png"

# --- following the theme ------------------------------------------------------
use_theme void
check "void should show its own picture" test "$(wp which)" = "$here/themes/void.jpg"
wp
check "feh isn't asked to show it" grep -qx "feh --no-fehbg --bg-fill $here/themes/void.jpg" "$log"
use_theme paper
check "paper should show its own picture" test "$(wp which)" = "$here/themes/paper.jpg"

# Your theme: a picture beside it wins; without one, a plain background.
sed 's/^bg=.*/bg=#123456/' "$here/themes/void.theme" > "$H/.config/vikix/themes/mine.theme"
use_theme mine
plain=$(wp which)
check "a theme without a picture should get a plain one" test -f "$plain"
check "the plain picture should be the theme's background colour" \
  test "$(tr -s '\n' ' ' < "$plain")" = "P3 1 1 255 18 52 86 "
touch "$H/.config/vikix/themes/mine.jpg"
check "a picture beside your theme should be used" test "$(wp which)" = "$H/.config/vikix/themes/mine.jpg"

# --- your choice ------------------------------------------------------------------
wp "$H/wallpapers/b2.jpg"
check "a chosen picture isn't shown" grep -q "bg-fill $H/wallpapers/b2.jpg" "$log"
use_theme void
check "a chosen picture should stay when the theme changes" test "$(wp which)" = "$H/wallpapers/b2.jpg"
if wp "$H/nope.jpg" 2>/dev/null; then echo "FAIL: a missing file should be refused"; fail=1; fi
check "a refused file shouldn't change the choice" test "$(wp which)" = "$H/wallpapers/b2.jpg"
wp theme
check "theme should go back to the theme's picture" test "$(wp which)" = "$here/themes/void.jpg"

# --- the picker ----------------------------------------------------------------------
ROFI_ANSWER='' wp pick
check "cancelling the picker shouldn't change anything" test "$(wp which)" = "$here/themes/void.jpg"
check "the picker should start with the theme's own" grep -qa '^Follow the theme (void)' "$t/offered"
check "the picker should sort b2 before b10" \
  test "$(grep -an '^b2' "$t/offered" | cut -d: -f1)" -lt "$(grep -an '^b10' "$t/offered" | cut -d: -f1)"
check "each entry should carry its picture as the icon" grep -qa "mine.icon.$H/Pictures/Wallpapers/mine.png" "$t/offered"
# The answer is a line number, 0 being "Follow the theme".
n=$(grep -an '^b10' "$t/offered" | cut -d: -f1)
ROFI_ANSWER=$((n - 1)) wp pick 2>/dev/null || true
check "the picked line should become the wallpaper" test "$(wp which)" = "$H/wallpapers/b10.jpg"
ROFI_ANSWER=0 wp pick
check "picking Follow the theme should drop the choice" test "$(wp which)" = "$here/themes/void.jpg"

# --- vikix theme changes it -----------------------------------------------------------
# With a display set, vikix theme also repaints StumpWM (python3 runs
# vikix-eval, which reaches the real one over Swank), reloads dunst and
# signals kitty. Stand-ins for all three, or this would restyle the desktop
# the tests run on.
stub python3  "echo \"python3 \$*\" >> $log"
stub dunstctl "echo \"dunstctl \$*\" >> $log"
stub pkill    "echo \"pkill \$*\" >> $log"
: > "$log"
bash "$here/bin/vikix" theme paper >/dev/null 2>&1 || true
check "the stand-in didn't get the repaint" grep -q 'python3 .*vikix-apply-theme :paper' "$log"
check "vikix theme should show the new theme's picture" grep -q "bg-fill $here/themes/paper.jpg" "$log"

[ "$fail" = 0 ] && echo "wallpaper: follows the theme until you choose; the picker sets what was picked"
exit "$fail"
