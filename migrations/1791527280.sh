#!/usr/bin/env bash
# Why: from 0.72.4 every built-in theme's name says whether it is light or
# dark: void is vikix-dark, paper vikix-light, and contrast, gruvbox, nord
# and tokyo-night each got -dark. `vikix theme` still takes the old names,
# but the saved choice (~/.config/vikix/theme/current) and a wallpaper
# chosen from a theme's own picture (the link ~/.config/vikix/wallpaper)
# name files that are gone; this renames both. Hype's copies of the themes
# were written again under the new names by 40-config's refresh; the folders
# with the old names are removed. An old name stays when a theme of yours
# has it.
# theme-names-light-dark
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

config="${XDG_CONFIG_HOME:-$HOME/.config}/vikix"
new_name() {
  case $1 in
    void) echo vikix-dark ;; paper) echo vikix-light ;; contrast) echo contrast-dark ;;
    gruvbox) echo gruvbox-dark ;; nord) echo nord-dark ;; tokyo-night) echo tokyo-night-dark ;;
    *) echo "$1" ;;
  esac
}

# The saved choice.
current="$config/theme/current"
if [ -f "$current" ]; then
  old=$(head -1 "$current" | tr -d '[:space:]')
  new=$(new_name "$old")
  if [ "$new" != "$old" ] && [ ! -f "$config/themes/$old.theme" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then
      printf '   would rename the saved theme %s to %s\n' "$old" "$new"
    else
      printf '%s\n' "$new" > "$current"
      say "theme: $old is called $new now"
    fi
  fi
fi

# A wallpaper chosen from a theme's own picture.
choice="$config/wallpaper"
if [ -L "$choice" ]; then
  target=$(readlink "$choice")
  case $target in
    "$VIKIX_DIR"/themes/*.jpg|*/vikix/themes/*.jpg)
      base=$(basename "$target" .jpg)
      new=$(new_name "$base")
      if [ "$new" != "$base" ] && [ ! -e "$target" ] && [ -f "$(dirname "$target")/$new.jpg" ]; then
        run ln -sfn "$(dirname "$target")/$new.jpg" "$choice"
      fi ;;
  esac
fi

# Hype's copies under the old names (vikix theme writes them anew).
hype="${XDG_DATA_HOME:-$HOME/.local/share}/vikix/omarchy/themes"
for old in void paper contrast gruvbox nord tokyo-night; do
  d="$hype/$old"
  [ -d "$d" ] || continue
  [ -f "$config/themes/$old.theme" ] && continue
  grep -qF 'Written by `vikix theme`' "$d/colors.toml" 2>/dev/null || continue
  run rm -rf "$d"
done
