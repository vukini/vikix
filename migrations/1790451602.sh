#!/usr/bin/env bash
# Why: from 0.17.0 a theme covers the terminal and rofi too, not only
# StumpWM: `vikix theme NAME` writes their colours into
# ~/.config/vikix/theme/, and the configs include those files. The starter
# configs this machine got earlier have the dark colours written into them
# instead. Those files are yours, so this changes them only where they are
# still exactly as Vikix gave them; anything you changed is left alone, and
# what to add by hand is printed. (dunst needs nothing: it reads the theme's
# drop-in in dunstrc.d by itself.)
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

# The files may be links (into a dotfiles repo, say): every edit writes
# through the link, never replaces it. sed -i alone would.
sed_i() { run sed --follow-symlinks -i "$@"; }

conf=${XDG_CONFIG_HOME:-$HOME/.config}
import_line='import = ["~/.config/vikix/theme/alacritty.toml"]'

# The theme's own files, in case 40-config hasn't written them yet.
run "$VIKIX_DIR/bin/vikix" theme --refresh

# --- alacritty ----------------------------------------------------------------
# The colour sections of the old starter, as Vikix wrote them.
old_colours='[colors.primary]
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
white   = "#a6adc8"'

# colour_sections FILE — the [colors...] tables in FILE, blank lines dropped.
colour_sections() {
  awk '/^\[/ { inside = ($0 ~ /^\[colors/) } inside && NF' "$1"
}

a="$conf/alacritty/alacritty.toml"
if [ ! -f "$a" ]; then
  say "no alacritty.toml; nothing to do for alacritty"
elif grep -qF 'vikix/theme/alacritty.toml' "$a"; then
  say "alacritty.toml already follows the theme"
else
  if [ -z "$(colour_sections "$a")" ]; then
    :
  elif [ "$(colour_sections "$a")" = "$(grep -v '^$' <<<"$old_colours")" ]; then
    say "alacritty.toml: removing the starter's colours; the theme gives them now"
    if [ "$DRY_RUN" != 1 ]; then
      kept=$(awk '/^\[/ { inside = ($0 ~ /^\[colors/) } !inside' "$a")
      printf '%s\n' "$kept" > "$a"          # through the link, if it is one
      sed_i 's/^# Colours match Vikix.s "void" theme\.$/# Colours come from Vikix'"'"'s theme (vikix theme NAME), through the import in [general]./' "$a"
    fi
  else
    warn "alacritty.toml sets colours of its own, which win over the theme;"
    warn "  to follow the theme, delete its [colors...] sections"
  fi

  if grep -q '^\[general\]' "$a"; then
    # A [general] table already: the import goes into it, unless it has one.
    if awk '/^\[/ { inside = ($0 == "[general]") } inside && /^import[[:space:]]*=/ { found = 1 } END { exit !found }' "$a"; then
      warn "alacritty.toml imports other files already; add to its import list:"
      warn '  "~/.config/vikix/theme/alacritty.toml"'
    else
      say "alacritty.toml: importing the theme"
      sed_i "/^\[general\]$/a $import_line" "$a"
    fi
  else
    # At the end, as a table of its own: at the top it would take in any
    # settings written before the first table.
    say "alacritty.toml: importing the theme"
    [ "$DRY_RUN" = 1 ] || printf '\n[general]\n%s\n' "$import_line" >> "$a"
  fi
fi

# --- rofi ---------------------------------------------------------------------
r="$conf/rofi/config.rasi"
if [ ! -f "$r" ]; then
  say "no rofi config.rasi; nothing to do for rofi"
elif grep -qF 'vikix/theme/rofi.rasi' "$r"; then
  say "rofi already follows the theme"
elif grep -qx '@theme "Arc-Dark"' "$r"; then
  say "rofi: the theme instead of Arc-Dark"
  sed_i 's|^@theme "Arc-Dark"$|@theme "~/.config/vikix/theme/rofi.rasi"|' "$r"
else
  warn "rofi's config.rasi picks its own theme; to follow Vikix's, make its @theme line:"
  warn '  @theme "~/.config/vikix/theme/rofi.rasi"'
fi
