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
#     ~/.local/share/applications/*.desktop   JupyterLab in the launcher,
#                                vikix-image, which opens images, and
#                                Lazarus (the docked IDE, vikix-lazarus)
#     ~/.config/vikix/vikix.bash   aliases and prompt (read by ~/.bashrc)
#     ~/.claude/skills/vikix     tells Claude Code how Vikix is put together
#     ~/.config/fontconfig/conf.d/50-vikix-iosevka.conf   monospace until Iosevka is installed
#
#   Yours (copied once as a starting point, never overwritten)
#     ~/.stumpwm.d/user.lisp     your StumpWM changes; loaded last, so they win
#     ~/.config/{alacritty,picom,dunst,rofi}/...
#     ~/.config/vikix/keyboard   layout and options (e.g. ctrl:swapcaps)
#     ~/.config/gammastep/config.ini   night light times and colours
#     ~/.config/mimeapps.list      which program opens which kind of file
#     ~/.Xresources              text size (Xft.dpi) for high-resolution screens
#     ~/.config/vikix/backup-exclude   what vikix backup leaves out
#
#   Made from the checkout (again when it changes)
#     ~/.local/share/info/vikix.info   the guides in docs/, as an Info manual
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
copy_user "$C/gammastep/config.ini"       "$HOME/.config/gammastep/config.ini"
copy_user "$C/xdg/mimeapps.list"          "$HOME/.config/mimeapps.list"
copy_user "$C/x11/Xresources"             "$HOME/.Xresources"
copy_user "$C/backup/exclude"             "$HOME/.config/vikix/backup-exclude"

# The theme's files for the terminals, rofi, dunst and the lock screen,
# written again from the saved theme, so a Vikix update reaches them.
"$VIKIX_DIR/bin/vikix" theme --refresh

# --- Swank's password ---------------------------------------------------------
# Swank, in StumpWM on 127.0.0.1:4004, runs any Lisp it's sent, as you, and
# 127.0.0.1 isn't only yours: the Windows VM reaches it through passt's
# gateway address. With ~/.slime-secret, Swank lets in only a client that
# sends it first: Emacs's SLIME and vikix eval both do, by themselves.
# Made once, random, only yours to read; one you have already is kept.
secret="$HOME/.slime-secret"
if [ "$DRY_RUN" = 1 ]; then
  [ -s "$secret" ] || printf '   would run: %s\n' "make $secret (random, 600)"
elif [ ! -s "$secret" ]; then
  ( umask 077; od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$secret"; echo >> "$secret" )
  say "made $secret: Swank now asks for it (Emacs and vikix eval send it by themselves)"
fi
[ "$DRY_RUN" = 1 ] || [ ! -e "$secret" ] || chmod 600 "$secret"

# --- The guides as an Info manual -------------------------------------------
# docs/ as ~/.local/share/info/vikix.info, for Emacs (C-h i) and `info vikix`,
# which find it through INFOPATH (set by vikix-session and vikix.bash).
# Written again only when the guides changed.
info_dir="$HOME/.local/share/info"
if ! command -v makeinfo >/dev/null || ! command -v install-info >/dev/null; then
  warn "makeinfo is missing (the texinfo package), so no Info manual of the guides"
elif [ "$DRY_RUN" = 1 ]; then
  printf '   would run: %s\n' "build $info_dir/vikix.info from docs/ (lib/md2texi.py, makeinfo)"
else
  tmp=$(mktemp -d)
  if python3 "$VIKIX_DIR/lib/md2texi.py" "$VIKIX_DIR/docs" > "$tmp/vikix.texi" &&
     makeinfo --no-split -o "$tmp/vikix.info" "$tmp/vikix.texi" 2>"$tmp/errors"; then
    mkdir -p "$info_dir"
    cmp -s "$tmp/vikix.info" "$info_dir/vikix.info" || cp "$tmp/vikix.info" "$info_dir/vikix.info"
    install-info --info-dir="$info_dir" "$info_dir/vikix.info" 2>/dev/null ||
      warn "couldn't add the Vikix manual to $info_dir/dir"
  else
    warn "couldn't build the Info manual of the guides: $(head -3 "$tmp/errors")"
  fi
  rm -rf "$tmp"
fi

say "config in place"

# --- A snapshot of your files ---------------------------------------------
"$VIKIX_DIR/bin/vikix" snapshot "after installing or updating Vikix $(cat "$VIKIX_DIR/VERSION")"
