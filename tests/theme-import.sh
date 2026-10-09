#!/usr/bin/env bash
# tests/theme-import.sh — `vikix theme import` turns an Omarchy theme repo
# into a Vikix theme: its colours in Vikix's names, its first wallpaper
# beside it, the name from the repo's, and nothing in the repo run.
#
# The repos are made here with git init; no network. No display, so the
# switch at the end repaints nothing.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME VIKIX_DIR
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
refused() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL: $1"; fail=1; fi; }
vikix() { HOME="$t/home" DISPLAY='' bash "$here/bin/vikix" theme "$@"; }
mine="$t/home/.config/vikix/themes"
val() { sed -n "s/^$2=\(#[0-9a-f]\{6\}\).*/\1/p" "$mine/$1.theme"; }

# repo DIR — DIR, with what's in it, as one commit.
repo() {
  git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -qm theme
}

# A 1x1 PNG, and a "JPEG" that is really text.
png() { printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\1\0\0\0\1\x08\x02\0\0\0\x90wS\xde\0\0\0\x0cIDATx\x9cc\xf8\x0f\0\0\x01\x01\0\x05\x18\xd8N\0\0\0\0IEND\xaeB`\x82' > "$1"; }

# --- A theme in Omarchy's names, with traps in it ------------------------------
r="$t/src/omarchy-fake-theme"
mkdir -p "$r/backgrounds" "$r/hypr"
cat > "$r/colors.toml" <<EOF
mode = "dark"
accent = "#89B4FA"
muted = "#585b70"
selection = "#333"               # short: widened to #333333
background = "#1e1e2e"
foreground = "#cdd6f4"
foreground = "#000000"           # a second one: the first wins
dark_foreground = "#a6adc8"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7cc"            # alpha: dropped
cyan = "#94e2d5"
bright_red = "#ff0000"
# no other bright colours: Omarchy makes them 20% lighter
black = "\$(touch $t/pwned-1)"
white = "#fff; touch $t/pwned-2"
bright_black = "#12345g"
evil = "#abcdef"
\`touch $t/pwned-3\` = "#abcdef"
green = "\$(touch $t/pwned-4)"

[extra]
background = "#ffffff"
EOF
echo 'touch pwned-5' > "$r/hypr/run.sh"
echo 'not a picture' > "$r/backgrounds/0-fake.jpg"
ln -s /etc/passwd "$r/backgrounds/00-link.jpg"   # sorts first; a link is never copied
png "$r/backgrounds/1-real.png"
png "$r/backgrounds/2-second.png"
mkdir -p "$r/.git-hooks"; printf '#!/bin/sh\ntouch %s/pwned-6\n' "$t" > "$r/.git-hooks/post-checkout"
chmod +x "$r/.git-hooks/post-checkout"
repo "$r"

out=$(cd "$t" && vikix import "$r" --no-switch 2>&1) || { echo "FAIL: the import failed: $out"; fail=1; }
check "the name isn't the repo's without omarchy- and -theme" test -f "$mine/fake.theme"
check "--no-switch switched" test ! -e "$t/home/.config/vikix/theme/current"
check "bg isn't background" test "$(val fake bg)" = '#1e1e2e'
check "fg isn't the first foreground" test "$(val fake fg)" = '#cdd6f4'
check "the accent isn't in lower case" test "$(val fake accent)" = '#89b4fa'
check "subtle isn't dark_foreground" test "$(val fake subtle)" = '#a6adc8'
check "dim isn't muted" test "$(val fake dim)" = '#585b70'
check "alert isn't red" test "$(val fake alert)" = '#f38ba8'
check "#rgb isn't widened" test "$(val fake sel)" = '#333333'
check "the alpha isn't dropped" test "$(val fake color5)" = '#f5c2e7'
check "black isn't the background" test "$(val fake color0)" = '#1e1e2e'
check "white isn't the foreground" test "$(val fake color7)" = '#cdd6f4'
check "bright black isn't muted" test "$(val fake color8)" = '#585b70'
check "bright red isn't the theme's" test "$(val fake color9)" = '#ff0000'
check "a missing bright green isn't 20% lighter" test "$(val fake color10)" = '#b8e9b4'
check "bright white isn't the foreground" test "$(val fake color15)" = '#cdd6f4'
check "a [table]'s background was taken" test -z "$(grep -F '#ffffff' "$mine/fake.theme" || true)"
check "an unknown key came through" test -z "$(grep -F '#abcdef' "$mine/fake.theme" || true)"
check "the header doesn't say where it came from" grep -q "^# From .*/omarchy-fake-theme, commit [0-9a-f]\{12\}" "$mine/fake.theme"
check "a bad colour wasn't mentioned" grep -q "bright_black isn't a colour" <<<"$out"
check "the wallpaper isn't the first real picture" cmp -s "$r/backgrounds/1-real.png" "$mine/fake.png"
check "a fake or linked picture was copied" test ! -e "$mine/fake.jpg"
check "something in the repo ran" test -z "$(compgen -G "$t/pwned*" || true)"
check "the theme can't be switched to" vikix fake >/dev/null
check "the switch didn't write it" grep -q '"#1e1e2e"' "$t/home/.config/vikix/theme/alacritty.toml"
[ "$fail" = 0 ] && echo "theme-import: an Omarchy theme's colours and wallpaper come over, and nothing in it runs"

# --- Names ---------------------------------------------------------------------
refused "an existing theme was replaced without --force" vikix import "$r" --no-switch
check "a refused import changed the theme" grep -q '^bg=#1e1e2e' "$mine/fake.theme"
sed -i 's/^background = "#1e1e2e"/background = "#101010"/' "$r/colors.toml"; repo "$r"
vikix import "$r" --force --no-switch >/dev/null 2>&1 || { echo "FAIL: --force didn't import"; fail=1; }
check "--force didn't replace it" test "$(val fake bg)" = '#101010'
check "--force didn't keep the old one aside" compgen -G "$mine/fake.theme.vikix-bak.*" >/dev/null
check "--force didn't keep the old picture aside" compgen -G "$mine/fake.png.vikix-bak.*" >/dev/null
check "a kept-aside theme is listed" test -z "$(vikix | grep -F vikix-bak || true)"
vikix import "$r" other-name --no-switch >/dev/null 2>&1 || { echo "FAIL: a given NAME wasn't used"; fail=1; }
check "a given NAME wasn't used" test -f "$mine/other-name.theme"
refused "a built-in theme's name was taken" vikix import "$r" void --force --no-switch
refused "a built-in theme's name was taken" vikix import "$r" vikix-light --no-switch
check "vikix-dark was shadowed" test ! -e "$mine/vikix-dark.theme"
out=$(vikix import "$r" 'x) (run-shell-command "touch pwned")' --no-switch 2>&1) && { echo "FAIL: a name like Lisp was taken"; fail=1; }
check "a name like Lisp isn't refused plainly: $out" grep -q "letters, digits" <<<"$out"
refused "import was taken as a theme's name" vikix import "$r" import --no-switch
[ "$fail" = 0 ] && echo "theme-import: names are checked, and nothing is replaced without --force"

# --- The older kind, and broken ones --------------------------------------------
# Themes from before the semantic names have only color0..color15.
r2="$t/src/omarchy-Ansi-theme"; mkdir -p "$r2"
{ echo 'accent = "#33b1ff"'; echo 'selection_background = "#41414d"'
  for i in $(seq 0 15); do printf 'color%d = "#%02x%02x%02x"\n' "$i" "$i" "$i" "$((i + 16))"; done; } > "$r2/colors.toml"
repo "$r2"
out=$(vikix import "$r2" 2>&1) || { echo "FAIL: an ANSI-only theme failed: $out"; fail=1; }
check "the name isn't in lower case" test -f "$mine/ansi.theme"
check "the switch didn't happen" test "$(cat "$t/home/.config/vikix/theme/current")" = ansi
check "bg isn't color0" test "$(val ansi bg)" = '#000010'
check "fg isn't color7" test "$(val ansi fg)" = '#070717'
check "red isn't color1" test "$(val ansi color1)" = '#010111'
check "bright cyan isn't color14" test "$(val ansi color14)" = '#0e0e1e'
check "bright white isn't color15" test "$(val ansi color15)" = '#0f0f1f'
check "sel isn't selection_background" test "$(val ansi sel)" = '#41414d'
check "no picture didn't say so" grep -q "no picture" <<<"$out"

mkdir -p "$t/src/nocolors"; echo hi > "$t/src/nocolors/README.md"; repo "$t/src/nocolors"
out=$(vikix import "$t/src/nocolors" --no-switch 2>&1) && { echo "FAIL: a repo without colors.toml was taken"; fail=1; }
check "no colors.toml isn't said: $out" grep -q "no colors.toml" <<<"$out"
mkdir -p "$t/src/nobg"; echo 'foreground = "#ffffff"' > "$t/src/nobg/colors.toml"; repo "$t/src/nobg"
out=$(vikix import "$t/src/nobg" --no-switch 2>&1) && { echo "FAIL: a theme without a background was taken"; fail=1; }
check "no background isn't said: $out" grep -q "no background" <<<"$out"
check "a failed import left a file" test ! -e "$mine/nobg.theme"
mkdir -p "$t/src/notgit"
out=$(vikix import "$t/src/notgit" --no-switch 2>&1) && { echo "FAIL: a folder that isn't a repo was taken"; fail=1; }
check "a failed clone isn't said: $out" grep -q "couldn't fetch" <<<"$out"
refused "an ext:: address was taken" vikix import "ext::sh -c touch% $t/pwned-ext"
refused "an http:// address was taken" vikix import "http://example.com/omarchy-x-theme"
refused "an option-like address was taken" vikix import "--upload-pack=touch"
check "an address ran something" test ! -e "$t/pwned-ext"
check "the help doesn't list import" sh -c "HOME='$t/home' bash '$here/bin/vikix' theme --help | grep -q 'theme import'"
check "vikix help doesn't list import" sh -c "HOME='$t/home' bash '$here/bin/vikix' help | grep -q 'theme import'"

# A dry run fetches and reads, and writes nothing.
out=$(HOME="$t/dry" DISPLAY='' DRY_RUN=1 bash "$here/bin/vikix" theme import "$r" 2>&1) || { echo "FAIL: the dry run failed: $out"; fail=1; }
check "the dry run wrote something" test ! -e "$t/dry/.config/vikix/themes/fake.theme"
check "the dry run didn't say what it would do" grep -q "would switch to fake" <<<"$out"
[ "$fail" = 0 ] && echo "theme-import: ANSI-only themes come over, and a broken repo or address is refused"
exit "$fail"
