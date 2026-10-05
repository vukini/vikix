#!/usr/bin/env bash
# tests/wallpaper.sh — vikix-wallpaper cycles through the pictures unless
# you choose otherwise (every one once before any comes again, a new one
# next), shows the theme's when you ask, keeps your choice
# across theme changes, gives a theme without a picture a plain background
# in its own colour, and its picker sets what was picked.
#
# feh, rofi and everything vikix theme reaches for are stand-ins, in a
# made-up home; nothing is drawn, and the desktop running the tests is
# never touched.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
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
export PATH="$t/bin:$PATH" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.local/state" DISPLAY=:7
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
wp() { : > "$log"; sh "$here/bin/vikix-wallpaper" "$@"; }
use_theme() { echo "$1" > "$H/.config/vikix/theme/current"; }

touch "$H/wallpapers/b2.jpg" "$H/wallpapers/b10.jpg" "$H/Pictures/Wallpapers/mine.png"

# --- cycling, the default ---------------------------------------------------------
use_theme void
first=$(wp which)
case $first in
  "$H/wallpapers/"*|"$H/Pictures/Wallpapers/"*) ;;
  *) echo "FAIL: with nothing chosen it should cycle your pictures, not show $first"; fail=1 ;;
esac
check "cycling should keep the picture until it's time" test "$(wp which)" = "$first"
wp next
check "next should show a new picture" grep -q "bg-fill" "$log"
check "next should never repeat the one showing" test "$(wp which)" != "$first"
wp cycle 5
check "cycle MINUTES should be kept" test "$(cat "$H/.config/vikix/wallpaper-minutes")" = 5
if wp cycle 0 2>/dev/null; then echo "FAIL: 0 minutes should be refused"; fail=1; fi
if wp cycle soon 2>/dev/null; then echo "FAIL: minutes that aren't a number should be refused"; fail=1; fi
for _ in 1 2 3 4 5 6; do
  case $(wp next; wp which) in "$here/themes/"*) echo "FAIL: cycling shouldn't show the themes' own"; fail=1 ;; esac
done
# A round: every picture once before any comes again, a new one next, one
# that has gone never.
state="$H/.local/state/vikix"
touch "$H/wallpapers/c1.jpg" "$H/wallpapers/c2.jpg" "$H/wallpapers/c3.jpg"
rm -f "$state"/wallpaper-now "$state"/wallpaper-queue "$state"/wallpaper-shown
round=$(for _ in 1 2 3 4 5 6; do wp next; wp which; done)
check "a round should show every picture once" test "$(echo "$round" | sort -u | wc -l)" = 6
again=$(for _ in 1 2 3 4 5 6; do wp next; wp which; done)
check "the next round should show every picture once more" test "$(echo "$again" | sort -u | wc -l)" = 6
check "a new round shouldn't start with the one showing" \
  test "$(echo "$round" | tail -n 1)" != "$(echo "$again" | head -n 1)"
wp next
touch "$H/wallpapers/new.jpg"
wp next
check "a picture you add should be the next one" test "$(wp which)" = "$H/wallpapers/new.jpg"
left=$(head -n 1 "$state/wallpaper-queue"); mv "$left" "$left.away"
rest=$(for _ in 1 2 3 4 5 6 7 8; do wp next; wp which; done)
check "a picture that has gone shouldn't be shown" test -z "$(echo "$rest" | grep -xF "$left")"
mv "$left.away" "$left"
wp next
check "a picture that is back should be the next one" test "$(wp which)" = "$left"
rm -f "$H/wallpapers"/c?.jpg "$H/wallpapers/new.jpg"
check "with pictures gone it should go on with the rest" test -f "$(wp next; wp which)"
gone=$(wp which); mv "$gone" "$gone.away"
check "a picture that's gone should give way to another" test -f "$(wp which)"
mv "$gone.away" "$gone"
# Nothing to cycle: the theme's picture.
mkdir -p "$t/away"; mv "$H/wallpapers"/* "$H/Pictures/Wallpapers"/* "$t/away/"
rm -f "$H/.local/state/vikix/wallpaper-now"
check "with nothing to cycle it should show the theme's" test "$(wp which)" = "$here/themes/void.jpg"
mv "$t/away/b2.jpg" "$t/away/b10.jpg" "$H/wallpapers/"; mv "$t/away/mine.png" "$H/Pictures/Wallpapers/"
# The watcher: one at a time.
mkdir -p "$H/.local/state/vikix"
exec 8>"$H/.local/state/vikix/wallpaper.lock"; flock -n 8
check "a second watcher should leave at once" timeout 5 sh "$here/bin/vikix-wallpaper" --watch
exec 8>&-

# --- following the theme ------------------------------------------------------
wp theme
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
check "the picker should start with the theme's own" grep -qa '^Theme: void' "$t/offered"
check "the picker should sort b2 before b10" \
  test "$(grep -an '^b2' "$t/offered" | cut -d: -f1)" -lt "$(grep -an '^b10' "$t/offered" | cut -d: -f1)"
check "each entry should carry its picture as the icon" grep -qa "mine.icon.$H/Pictures/Wallpapers/mine.png" "$t/offered"
# The answer is a line number, 0 being the theme's own.
check "the picker's second entry should be Cycle" test "$(sed -n 2p "$t/offered" | cut -d: -f1)" = Cycle
n=$(grep -an '^b10' "$t/offered" | cut -d: -f1)
ROFI_ANSWER=$((n - 1)) wp pick 2>/dev/null || true
check "the picked line should become the wallpaper" test "$(wp which)" = "$H/wallpapers/b10.jpg"
ROFI_ANSWER=0 wp pick
check "picking the theme's own should drop the choice" test "$(wp which)" = "$here/themes/void.jpg"
ROFI_ANSWER=1 wp pick
case $(wp which) in "$here/themes/"*) echo "FAIL: picking Cycle should cycle"; fail=1 ;; esac
check "picking Cycle should end following the theme" test ! -e "$H/.config/vikix/wallpaper-theme"
wp theme

# --- off: your own tool sets it -------------------------------------------------------
wp off
wp
check "off should leave the wallpaper alone" test ! -s "$log"
wp "$H/wallpapers/b2.jpg"
check "choosing a picture should end off" grep -q "bg-fill $H/wallpapers/b2.jpg" "$log"
wp off
wp theme
check "theme should end off too" grep -q "bg-fill $here/themes/void.jpg" "$log"
ROFI_ANSWER='' wp pick
check "the picker should end with the off entry" test "$(tail -n 1 "$t/offered")" = "My own tool"
ROFI_ANSWER=$(($(wc -l < "$t/offered") - 1)) wp pick
check "picking the last entry should turn off" test -e "$H/.config/vikix/wallpaper-off"
wp theme

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
: > "$log"
bash "$here/bin/vikix" theme --refresh >/dev/null 2>&1 || true
check "vikix update's --refresh shouldn't touch the wallpaper" test -z "$(grep feh "$log")"

# --- the migration: machines with a wallpaper of their own -----------------------------
m=$(grep -l 'vikix-wallpaper off' "$here"/migrations/*.sh | head -1)
migrate() {   # migrate CASE — a fresh made-up home set up as CASE; off or follows?
  local h="$t/m-$1"; mkdir -p "$h/.stumpwm.d" "$h/.config/vikix"
  case $1 in
    fehbg)    touch "$h/.fehbg" ;;
    userlisp) echo '(run-shell-command "~/bin/wallpaper-rotate &")' > "$h/.stumpwm.d/user.lisp" ;;
    chosen)   touch "$h/.fehbg"; ln -s /gone.jpg "$h/.config/vikix/wallpaper" ;;
  esac
  HOME="$h" XDG_CONFIG_HOME="$h/.config" VIKIX_DIR="$here" bash "$m" >/dev/null
  [ -e "$h/.config/vikix/wallpaper-off" ] && echo off || echo follows
}
check "a ~/.fehbg should turn Vikix's wallpaper off" test "$(migrate fehbg)" = off
check "a wallpaper command in user.lisp should turn it off" test "$(migrate userlisp)" = off
check "with nothing of your own it should follow the theme" test "$(migrate none)" = follows
check "a picture chosen in Vikix should be kept" test "$(migrate chosen)" = follows

# --- the feature wallpapers: Vid's collection, a clone of its own ----------------------
# A local repository stands in for GitHub's.
src="$t/src"; git init -q -b main "$src"
cp "$here/themes/void.jpg" "$src/first.jpg"
git -C "$src" add first.jpg; git -C "$src" -c user.name=t -c user.email=t@t commit -qm first
export VIKIX_WALLPAPERS_REPO="file://$src" XDG_DATA_HOME="$H/.local/share"
coll="$H/.local/share/vikix/wallpapers"
wps() { bash "$here/bin/vikix-wallpapers" "$@"; }
wps setup >/dev/null 2>&1
check "setup should clone the collection" test -f "$coll/first.jpg"
check "setup should record the feature" grep -qx wallpapers "$H/.config/vikix/features"
ROFI_ANSWER='' wp pick
check "the picker should list the collection" grep -qa "first.icon.$coll/first.jpg" "$t/offered"
cp "$here/themes/paper.jpg" "$src/second.jpg"
git -C "$src" add second.jpg; git -C "$src" -c user.name=t -c user.email=t@t commit -qm second
wps update >/dev/null 2>&1
check "update should bring the new picture" test -f "$coll/second.jpg"
wp "$coll/second.jpg"
wps uninstall >/dev/null 2>&1
check "uninstall should delete the clone" test ! -e "$coll"
check "uninstall should forget the feature" test -z "$(grep -x wallpapers "$H/.config/vikix/features")"
check "a chosen picture from the collection should give way" test ! -L "$H/.config/vikix/wallpaper"
# ~/wallpapers already a clone of the same repository (Vid's working copy):
# linked to, listed once, never pulled into, never deleted.
rm -rf "$H/wallpapers"; git clone -q "file://$src" "$H/wallpapers"
wps setup >/dev/null 2>&1
check "your own clone should be linked, not cloned again" test "$(readlink "$coll")" = "$H/wallpapers"
ROFI_ANSWER='' wp pick
check "your own clone should be listed once" test "$(grep -ac '^first' "$t/offered")" = 1
wps uninstall >/dev/null 2>&1
check "uninstall should leave your own clone" test -f "$H/wallpapers/first.jpg"

[ "$fail" = 0 ] && echo "wallpaper: cycles until you choose a picture, the theme's or off, every picture once a round and a new one next; update leaves it; the migration spots your own; the collection clones, pulls, lists and goes"
exit "$fail"
