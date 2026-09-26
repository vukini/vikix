#!/usr/bin/env bash
# Why: 0.13.2 adds Foliate (EPUB) and LibreOffice, and config/xdg/mimeapps.list
# opens e-books and office files with them. That file is copied once, so
# machines installed earlier don't get the new lines. This sets each type
# only where you have no default yet; a choice you made is left alone.
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

command -v xdg-mime >/dev/null || { warn "xdg-mime missing; skipping"; exit 0; }

# Your choices are the lines in ~/.config/mimeapps.list. (Not `xdg-mime
# query default`: that also answers with any installed program that claims
# the type, e.g. zathura for EPUB, which nobody chose.)
mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"

set_default() {   # set_default APP.desktop TYPE...
  local app=$1 t; shift
  [ -e "/usr/share/applications/$app" ] || return 0     # not installed (yet)
  for t in "$@"; do
    if ! grep -q "^$t=" "$mimeapps" 2>/dev/null; then
      say "$t: $app"
      run xdg-mime default "$app" "$t"
    fi
  done
}

set_default com.github.johnfactotum.Foliate.desktop \
  application/epub+zip application/x-mobipocket-ebook application/x-fictionbook+xml
set_default libreoffice-writer.desktop \
  application/vnd.oasis.opendocument.text application/msword application/rtf \
  application/vnd.openxmlformats-officedocument.wordprocessingml.document
set_default libreoffice-calc.desktop \
  application/vnd.oasis.opendocument.spreadsheet application/vnd.ms-excel \
  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
set_default libreoffice-impress.desktop \
  application/vnd.oasis.opendocument.presentation application/vnd.ms-powerpoint \
  application/vnd.openxmlformats-officedocument.presentationml.presentation
