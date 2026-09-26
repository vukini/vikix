#!/usr/bin/env bash
# 40-config — put the config files in place.
#
# Two kinds of file, handled two ways:
#
#   Vikix's own (symlinked into this checkout, refreshed by `vikix update`)
#     ~/.stumpwm.d/init.lisp     loads Vikix's layer, then your user.lisp
#     ~/.stumpwm.d/vikix/      keys, mode line, theme, commands, Swank
#     ~/.xinitrc                 starts the session
#     ~/.local/bin/vikix*      the vikix command and its helpers, all of bin/
#                                (but vikix-eval and vikix-session)
#     ~/.local/share/applications/vikix-*.desktop   JupyterLab in the launcher,
#                                and vikix-image, which opens images
#     ~/.config/vikix/vikix.bash   aliases and prompt (read by ~/.bashrc)
#     ~/.claude/skills/vikix     tells Claude Code how Vikix is put together
#     ~/.config/fontconfig/conf.d/50-vikix-iosevka.conf   monospace until Iosevka is installed
#
#   Yours (copied once as a starting point, never overwritten)
#     ~/.stumpwm.d/user.lisp     your StumpWM changes; loaded last, so they win
#     ~/.config/{alacritty,picom,dunst,rofi}/...
#     ~/.config/vikix/keyboard   layout and options (e.g. ctrl:swapcaps)
#     ~/.config/mimeapps.list      which program opens which kind of file
#     ~/.Xresources              text size (Xft.dpi) for high-resolution screens
#
# Last, a snapshot of your files (config/yours.list), so from here on
# every change to them can be seen and undone: vikix changes, vikix undo.
#
# If you already have a StumpWM config, it becomes your user.lisp, so
# everything you had keeps working on top of Vikix's defaults.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

C="$VIKIX_DIR/config"
SD="$HOME/.stumpwm.d"

# --- Keep an existing StumpWM config as user.lisp ------------------------
# StumpWM reads ~/.stumpwmrc first if it exists, so it has to move aside
# or Vikix's init.lisp would never load.
for old in "$HOME/.stumpwmrc" "$SD/init.lisp"; do
  # only a real file counts; a symlink is already Vikix's
  if [ ! -e "$old" ] || [ -L "$old" ]; then continue; fi
  if [ ! -e "$SD/user.lisp" ]; then
    say "keeping your $old as $SD/user.lisp"
    run mkdir -p "$SD"
    run mv "$old" "$SD/user.lisp"
  elif [ "$old" = "$HOME/.stumpwmrc" ]; then
    bak="$old.vikix-bak.$(timestamp)"
    warn "user.lisp already exists; moving $old to $bak"
    run mv "$old" "$bak"
  fi
done

# --- Vikix's own files --------------------------------------------------
link_managed "$C/stumpwm/init.lisp" "$SD/init.lisp"
link_managed "$C/stumpwm/vikix"   "$SD/vikix"
link_managed "$C/x11/xinitrc"       "$HOME/.xinitrc"
# Every command in bin/, so a new helper can't be forgotten here. Two stay
# out of PATH: vikix-eval is reached through `vikix eval`, and
# vikix-session is run by ~/.xinitrc from the checkout.
for cmd in "$VIKIX_DIR"/bin/vikix*; do
  case "${cmd##*/}" in vikix-eval|vikix-session) continue ;; esac
  link_managed "$cmd" "$HOME/.local/bin/${cmd##*/}"
done
for app in "$C"/applications/*.desktop; do
  link_managed "$app" "$HOME/.local/share/applications/${app##*/}"
done
link_managed "$C/bash/vikix.bash"   "$HOME/.config/vikix/vikix.bash"
link_managed "$C/claude/skills/vikix" "$HOME/.claude/skills/vikix"
link_managed "$C/fontconfig/50-vikix-iosevka.conf" "$HOME/.config/fontconfig/conf.d/50-vikix-iosevka.conf"

# --- Your files -----------------------------------------------------------
copy_user "$C/stumpwm/user.lisp"          "$SD/user.lisp"
copy_user "$C/alacritty/alacritty.toml"   "$HOME/.config/alacritty/alacritty.toml"
copy_user "$C/picom/picom.conf"           "$HOME/.config/picom/picom.conf"
copy_user "$C/dunst/dunstrc"              "$HOME/.config/dunst/dunstrc"
copy_user "$C/rofi/config.rasi"           "$HOME/.config/rofi/config.rasi"
copy_user "$C/keyboard/keyboard"          "$HOME/.config/vikix/keyboard"
copy_user "$C/xdg/mimeapps.list"          "$HOME/.config/mimeapps.list"
copy_user "$C/x11/Xresources"             "$HOME/.Xresources"

say "config in place"

# --- A snapshot of your files ---------------------------------------------
"$VIKIX_DIR/bin/vikix" snapshot "after installing or updating Vikix $(cat "$VIKIX_DIR/VERSION")"
