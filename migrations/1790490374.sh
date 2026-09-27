#!/usr/bin/env bash
# Why: from 0.25.0 Vikix sets the wallpaper itself, at login and on a theme
# change: the theme's picture, unless you chose one. On a machine that
# already had its own way (feh's ~/.fehbg, nitrogen, or a wallpaper command
# in user.lisp, such as a script that rotates pictures), that would cover
# your picture with the theme's. So where one of those is found, this tells
# Vikix to leave the wallpaper alone (vikix-wallpaper off). `vikix-wallpaper
# theme`, or picking one with Super+m, Wallpaper, hands it back to Vikix.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

conf=${XDG_CONFIG_HOME:-$HOME/.config}
if [ -e "$conf/vikix/wallpaper" ] || [ -L "$conf/vikix/wallpaper" ] || [ -e "$conf/vikix/wallpaper-off" ]; then
  say "the wallpaper is already set up in Vikix; nothing to do"
elif [ -e "$HOME/.fehbg" ] || [ -d "$conf/nitrogen" ] ||
     grep -qiE 'wallpaper|feh|nitrogen|xwallpaper|hsetroot' "$HOME/.stumpwm.d/user.lisp" 2>/dev/null; then
  say "you set the wallpaper your own way; Vikix will leave it alone"
  say "  (vikix-wallpaper theme, or Super+m then Wallpaper, gives it to Vikix)"
  run "$VIKIX_DIR/bin/vikix-wallpaper" off
else
  say "no wallpaper of your own found; Vikix's follows the theme"
fi
