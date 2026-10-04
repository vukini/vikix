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
#     ~/.local/share/vikix/guide/      the same guides as web pages, with diagrams
#
# Last, a snapshot of your files (config/yours.list), so from here on
# every change to them can be seen and undone: vikix changes, vikix undo.
#
# If you already have a StumpWM config, it becomes your user.lisp, so
# everything you had keeps working on top of Vikix's defaults.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/mimeapps.sh
. "$(dirname "$0")/../lib/mimeapps.sh"

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
# vk, a second name for vikix: less to type (vk upd, vk docs f runit, Tab).
link_managed "$VIKIX_DIR/bin/vikix" "$HOME/.local/bin/vk"
for app in "$C"/applications/*.desktop; do
  link_managed "$app" "$HOME/.local/share/applications/${app##*/}"
done
link_managed "$C/bash/vikix.bash"   "$HOME/.config/vikix/vikix.bash"
link_managed "$C/claude/skills/vikix" "$HOME/.claude/skills/vikix"
# Vikix's state folder (logs, the snapshot history, the debug reports) is
# yours alone: the session log carries the pages a browser had open.
run mkdir -p "$VIKIX_STATE"
run chmod 700 "$VIKIX_STATE"
# The same guide for the other agents (Codex, Gemini, Aider), as AGENTS.md:
# made from the skill, so it changes with it.
bash "$VIKIX_DIR/bin/vikix-agent" --write-guide
link_managed "$C/fontconfig/50-vikix-iosevka.conf" "$HOME/.config/fontconfig/conf.d/50-vikix-iosevka.conf"
# A newly plugged screen: autorandr runs the hooks in predetect.d before it
# looks for a saved layout; Vikix's lays out screens it has none for.
link_managed "$C/autorandr/predetect.d/vikix" "${XDG_CONFIG_HOME:-$HOME/.config}/autorandr/predetect.d/vikix"
# Vikix's part of Nyxt's config (the desktop's colours), where your
# config.lisp loads it from. Linked whether or not Nyxt is here: it's only
# read by Nyxt, and is then in place when Nyxt comes.
link_managed "$C/nyxt/vikix.lisp" "${XDG_DATA_HOME:-$HOME/.local/share}/vikix/nyxt/vikix.lisp"

# --- Your files -----------------------------------------------------------
copy_user "$C/stumpwm/user.lisp"          "$SD/user.lisp"
copy_user "$C/alacritty/alacritty.toml"   "$HOME/.config/alacritty/alacritty.toml"
copy_user "$C/picom/picom.conf"           "$HOME/.config/picom/picom.conf"
copy_user "$C/dunst/dunstrc"              "$HOME/.config/dunst/dunstrc"
copy_user "$C/rofi/config.rasi"           "$HOME/.config/rofi/config.rasi"
copy_user "$C/keyboard/keyboard"          "$HOME/.config/vikix/keyboard"
copy_user "$C/gammastep/config.ini"       "$HOME/.config/gammastep/config.ini"
copy_user "$C/xdg/mimeapps.list"          "$HOME/.config/mimeapps.list"
# Defaults the starter gained after yours was copied, once their program
# is here; never one you set (lib/mimeapps.sh).
fill_mime_defaults "$C/xdg/mimeapps.list" "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" "$VIKIX_STATE/mimeapps-offered"
copy_user "$C/x11/Xresources"             "$HOME/.Xresources"
copy_user "$C/backup/exclude"             "$HOME/.config/vikix/backup-exclude"
copy_user "$C/projects/projects"          "$HOME/.config/vikix/projects"
# Nyxt's config, once Nyxt is installed (the feature lisp-apps; its setup
# copies it too, as `vikix add` doesn't run this stage).
if command -v nyxt >/dev/null 2>&1; then
  copy_user "$C/nyxt/config.lisp"         "$HOME/.config/nyxt/config.lisp"
fi

# The theme's files for the terminals, rofi, dunst and the lock screen,
# written again from the saved theme, so a Vikix update reaches them.
"$VIKIX_DIR/bin/vikix" theme --refresh

# GTK 4 and libadwaita programs take the theme's colours from a file
# `vikix theme` writes; ~/.config/gtk-4.0/gtk.css (yours) imports it, first,
# as CSS wants. Anything of yours in it stays, below, and wins.
gtk4_css="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"
gtk4_import="@import url(\"file://${XDG_CONFIG_HOME:-$HOME/.config}/vikix/theme/gtk4.css\");  /* vikix theme's colours: keep this line first */"
if [ "$DRY_RUN" = 1 ]; then
  printf '   would import the theme into %s\n' "$gtk4_css"
elif ! grep -qF "vikix/theme/gtk4.css" "$gtk4_css" 2>/dev/null; then
  mkdir -p "$(dirname "$gtk4_css")"
  { printf '%s\n' "$gtk4_import"; cat "$gtk4_css" 2>/dev/null || true; } > "$gtk4_css.vikix-new"
  mv "$gtk4_css.vikix-new" "$gtk4_css"
fi
# Qt 6 programs, through qt6ct: the theme's palette, in Fusion's style.
# Yours once copied; qt6ct (its own window) changes it.
qt6ct_conf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
if [ "$DRY_RUN" = 1 ]; then
  printf '   would write %s once\n' "$qt6ct_conf"
elif [ ! -e "$qt6ct_conf" ]; then
  mkdir -p "$(dirname "$qt6ct_conf")"
  printf '[Appearance]\ncolor_scheme_path=%s\ncustom_palette=true\nstyle=Fusion\nicon_theme=Adwaita\nstandard_dialogs=default\n' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/vikix/theme/qt6ct-colors.conf" > "$qt6ct_conf"
fi

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

# --- The guides as an Info manual and in the browser --------------------------
# docs/ as ~/.local/share/info/vikix.info, for Emacs (C-h i) and `info vikix`,
# which find it through INFOPATH (set by vikix-session and vikix.bash), and
# as web pages in ~/.local/share/vikix/guide/ (Super+m → Vikix guide in the
# browser), which show the diagrams as pictures; Info shows their text
# version (docs/diagrams/NAME.txt). Both are written again only when the
# guides changed.
info_dir="$HOME/.local/share/info"
guide_dir="$HOME/.local/share/vikix/guide"
if ! command -v makeinfo >/dev/null || ! command -v install-info >/dev/null; then
  warn "makeinfo is missing (the texinfo package), so no Info manual or web pages of the guides"
elif [ "$DRY_RUN" = 1 ]; then
  printf '   would run: %s\n' "build $info_dir/vikix.info and $guide_dir/ from docs/ (lib/md2texi.py, makeinfo)"
else
  tmp=$(mktemp -d)
  if python3 "$VIKIX_DIR/lib/md2texi.py" "$VIKIX_DIR/docs" > "$tmp/vikix.texi" &&
     makeinfo --no-split -I "$VIKIX_DIR/docs" -o "$tmp/vikix.info" "$tmp/vikix.texi" 2>"$tmp/errors"; then
    mkdir -p "$info_dir"
    cmp -s "$tmp/vikix.info" "$info_dir/vikix.info" || cp "$tmp/vikix.info" "$info_dir/vikix.info"
    install-info --info-dir="$info_dir" "$info_dir/vikix.info" 2>/dev/null ||
      warn "couldn't add the Vikix manual to $info_dir/dir"
    # The web pages: the same build as vikix.dev/guide/ (lib/build-guide.sh).
    bash "$VIKIX_DIR/lib/build-guide.sh" "$guide_dir" 2>"$tmp/errors" ||
      warn "couldn't build the guide's web pages: $(head -3 "$tmp/errors")"
  else
    warn "couldn't build the Info manual of the guides: $(head -3 "$tmp/errors")"
  fi
  rm -rf "$tmp"
fi

# --- A man page for every vikix command -------------------------------------
# lib/man.py makes them from the scripts' own headers, what -h prints, so the
# two can't differ. man finds them through MANPATH (set by vikix-session and
# vikix.bash): Void's man is mandoc, which doesn't look beside ~/.local/bin
# by itself. makewhatis is mandoc's index, for `man -k vikix` and apropos,
# and what keeps man from saying its index is out of date.
man_dir="$HOME/.local/share/man"
if [ "$DRY_RUN" = 1 ]; then
  printf '   would run: %s\n' "write the vikix man pages into $man_dir/man1 (lib/man.py)"
else
  python3 "$VIKIX_DIR/lib/man.py" "$man_dir/man1" >/dev/null ||
    warn "not every vikix man page could be made (python3 $VIKIX_DIR/lib/man.py --check says why)"
  if command -v makewhatis >/dev/null; then makewhatis "$man_dir" 2>/dev/null || true; fi
fi

say "config in place"

# --- A snapshot of your files ---------------------------------------------
"$VIKIX_DIR/bin/vikix" snapshot "after installing or updating Vikix $(cat "$VIKIX_DIR/VERSION")"
