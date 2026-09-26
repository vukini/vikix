#!/usr/bin/env bash
# Why: 0.16.3 opens images with vikix-image, which shows nsxiv with the
# rest of the image's folder; plain nsxiv shows only the one file. The
# starter mimeapps.list names it, but that file is copied once. And a
# mimeapps.list you had before Vikix may name no image viewer at all,
# which leaves Void's first match in charge (PikoPixel, a pixel editor,
# on one machine). So each image type is set to vikix-image where it has
# no default yet or still has plain nsxiv; any other choice is yours and
# is left alone.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

command -v xdg-mime >/dev/null || { warn "xdg-mime missing; skipping"; exit 0; }
# 40-config links the entry; vikix update runs it before the migrations.
app=vikix-image.desktop
[ -e "$HOME/.local/share/applications/$app" ] || { warn "$app isn't linked yet; skipping"; exit 0; }

mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
for t in image/png image/jpeg image/gif image/webp image/svg+xml \
         image/bmp image/tiff image/avif image/heic image/jxl; do
  current=$(sed -n "s|^$t=||p" "$mimeapps" 2>/dev/null | head -1)
  case "$current" in
    ""|nsxiv.desktop|nsxiv.desktop\;)
      say "$t: $app"
      run xdg-mime default "$app" "$t" ;;
  esac
done
