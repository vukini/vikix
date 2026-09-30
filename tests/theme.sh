#!/usr/bin/env bash
# tests/theme.sh — `vikix theme` writes every program's colours from one
# theme file, and the 0.17.0 migration hooks old starter configs up to it
# without touching what the user changed.
#
# All in a made-up home. No display, so nothing running is repainted.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
vikix() { HOME="$t/home" DISPLAY='' bash "$here/bin/vikix" theme "$@"; }
out="$t/home/.config/vikix/theme"

# --- vikix theme --------------------------------------------------------------
vikix paper >/dev/null
check "the choice isn't saved" test "$(cat "$out/current")" = paper
check "alacritty doesn't get paper's background" grep -q '"#eff1f5"' "$out/alacritty.toml"
check "alacritty's file isn't valid TOML" python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" "$out/alacritty.toml"
check "kitty doesn't get 16 colours" test "$(grep -c '^color[0-9]* #' "$out/kitty.conf")" = 16
check "the lock screen doesn't get the background" test "$(cat "$out/lock")" = eff1f5
check "dunst's drop-in is missing" grep -q '#eff1f5' "$t/home/.config/dunst/dunstrc.d/10-vikix-theme.conf"
check "alacritty's selection isn't the sel colour" grep -A1 '^\[colors.selection\]' "$out/alacritty.toml" | grep -q '"#ccd0da"'
check "rofi's selected row isn't sel" grep -q 'sel: #ccd0da' "$out/rofi.rasi"
check "dunst's bars don't get the accent" grep -q 'highlight = "#1c5bd6"' "$t/home/.config/dunst/dunstrc.d/10-vikix-theme.conf"
if command -v rofi >/dev/null; then
  check "rofi can't read its theme" sh -c "rofi -theme '$out/rofi.rasi' -dump-theme | grep -q 'accent:'"
fi

vikix --refresh >/dev/null
check "--refresh doesn't keep the saved theme" test "$(cat "$out/current")" = paper

if vikix nope >/dev/null 2>&1; then echo "FAIL: an unknown theme is accepted"; fail=1; fi
check "a failed switch changed the saved theme" test "$(cat "$out/current")" = paper

# Your own themes: a complete one works, an incomplete one changes nothing.
mkdir -p "$t/home/.config/vikix/themes"
sed 's/^bg=.*/bg=#123456   # mine/' "$here/themes/void.theme" > "$t/home/.config/vikix/themes/mine.theme"
vikix mine >/dev/null
check "your own theme isn't used" grep -q '"#123456"' "$out/alacritty.toml"
# A theme from before sel existed still works, with color0 behind selections.
grep -v '^sel=' "$here/themes/void.theme" | sed 's/^color0=.*/color0=#010203/' > "$t/home/.config/vikix/themes/older.theme"
vikix older >/dev/null
check "a theme without sel isn't accepted" test "$(cat "$out/current")" = older
check "a theme without sel doesn't fall back to color0" grep -q 'selection_background #010203' "$out/kitty.conf"
vikix mine >/dev/null
grep -v '^accent=' "$here/themes/void.theme" > "$t/home/.config/vikix/themes/half.theme"
if vikix half >/dev/null 2>&1; then echo "FAIL: a theme without an accent colour is accepted"; fail=1; fi
check "an incomplete theme changed the files" grep -q '"#123456"' "$out/alacritty.toml"
[ "$fail" = 0 ] && echo "theme: vikix theme writes every program's colours, and refuses a broken theme"

# --- the migration --------------------------------------------------------------
m=$(grep -l 'vikix/theme/alacritty.toml' "$here"/migrations/*.sh | head -1)
migrate() { HOME="$1" VIKIX_DIR="$here" bash "$m" >/dev/null 2>&1; }
toml() { python3 -c "import tomllib,sys; d=tomllib.load(open(sys.argv[1],'rb')); print(sorted(d), d.get('general'))" "$1"; }
imp="['~/.config/vikix/theme/alacritty.toml']"

# The old starters, one of them a link into a dotfiles folder.
h="$t/old"; mkdir -p "$h/dots" "$h/.config/alacritty" "$h/.config/rofi"
sed -n '/^# ~\/.config\/alacritty/,/^size/p' "$here/config/alacritty/alacritty.toml" | grep -v '^\[general\]\|^import' > "$h/dots/alacritty.toml"
cat >> "$h/dots/alacritty.toml" <<'EOF'

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.normal]
black   = "#45475a"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#bac2de"

[colors.bright]
black   = "#585b70"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#a6adc8"
EOF
ln -s "$h/dots/alacritty.toml" "$h/.config/alacritty/alacritty.toml"
printf 'configuration { modi: "drun"; }\n@theme "Arc-Dark"\n' > "$h/.config/rofi/config.rasi"
migrate "$h"
check "the old starter still has its colours, or no import" \
  test "$(toml "$h/dots/alacritty.toml")" = "['font', 'general'] {'import': $imp}"
check "the link to the dotfiles copy was replaced" test -L "$h/.config/alacritty/alacritty.toml"
check "rofi's starter still uses Arc-Dark" grep -qx '@theme "~/.config/vikix/theme/rofi.rasi"' "$h/.config/rofi/config.rasi"
before=$(cat "$h/dots/alacritty.toml" "$h/.config/rofi/config.rasi")
migrate "$h"
check "a second run changed the files" test "$before" = "$(cat "$h/dots/alacritty.toml" "$h/.config/rofi/config.rasi")"

# Your own colours, and a [general] table without an import.
h="$t/own"; mkdir -p "$h/.config/alacritty" "$h/.config/rofi"
printf '[general]\nlive_config_reload = true\n\n[colors.primary]\nbackground = "#000000"\n' > "$h/.config/alacritty/alacritty.toml"
printf '@theme "gruvbox-dark"\n' > "$h/.config/rofi/config.rasi"
migrate "$h"
check "your own colours were removed" grep -q '#000000' "$h/.config/alacritty/alacritty.toml"
check "the import didn't go into the [general] table there" \
  test "$(toml "$h/.config/alacritty/alacritty.toml")" = "['colors', 'general'] {'import': $imp, 'live_config_reload': True}"
check "your own rofi theme was replaced" grep -qx '@theme "gruvbox-dark"' "$h/.config/rofi/config.rasi"
# A theme's name goes to StumpWM as a Lisp keyword: a file named like Lisp
# is neither listed nor used.
mkdir -p "$t/home/.config/vikix/themes"
cp "$here/themes/void.theme" "$t/home/.config/vikix/themes/x) (run-shell-command \"touch pwned\") (list.theme"
out=$(vikix 2>&1)
check "a theme named like Lisp shouldn't be listed: $out" test -z "$(grep -F pwned <<<"$out" || true)"
out=$(vikix 'x) (run-shell-command "touch pwned") (list' 2>&1) && { echo "FAIL: a theme named like Lisp was used"; fail=1; }
check "a theme named like Lisp should be refused: $out" grep -q "letters, digits" <<<"$out"

[ "$fail" = 0 ] && echo "theme: the migration hooks old starters up, and leaves your own settings alone"
exit "$fail"
