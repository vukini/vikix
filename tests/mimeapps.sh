#!/usr/bin/env bash
# tests/mimeapps.sh — the starter's default programs reach a mimeapps.list
# copied before them (lib/mimeapps.sh): only types you don't set, only once
# their program is installed, each offered once; in [Default Applications],
# in place, so a link stays a link; a dry run changes nothing.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_DIR="$here" VIKIX_APP_DIRS="$t/apps"
mkdir -p "$HOME/.config" "$t/apps" "$t/dotfiles"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
# shellcheck source=../lib/common.sh
. "$here/lib/common.sh"
# shellcheck source=../lib/mimeapps.sh
. "$here/lib/mimeapps.sh"

starter="$t/starter.list"
cat > "$starter" <<'LIST'
# a comment
[Default Applications]
application/pdf=zathura.desktop
application/msword=libreoffice-writer.desktop
audio/mpeg=mpv.desktop
video/webm=mpv.desktop

[Added Associations]
image/png=nsxiv.desktop
LIST
mine="$t/dotfiles/mimeapps.list"
cat > "$mine" <<'LIST'
[Default Applications]
application/pdf=evince.desktop
audio/mpeg=audacity.desktop

[Added Associations]
text/plain=emacs.desktop
LIST
ln -s "$mine" "$HOME/.config/mimeapps.list"
offered="$VIKIX_STATE/mimeapps-offered"
touch "$t/apps/libreoffice-writer.desktop"    # installed; mpv not yet
fill() { fill_mime_defaults "$starter" "$HOME/.config/mimeapps.list" "$offered" >/dev/null; }
defaults() { mime_defaults "$HOME/.config/mimeapps.list"; }

before=$(md5sum < "$mine")
DRY_RUN=1 fill
check "a dry run shouldn't change the file" test "$(md5sum < "$mine")" = "$before"
check "a dry run shouldn't record anything" test ! -e "$offered"

fill
check "a default you lack, for an installed program, should be added" grep -qx 'application/msword=libreoffice-writer.desktop' <(defaults)
check "your own default should stay" grep -qx 'application/pdf=evince.desktop' <(defaults)
check "a type you set should stay yours" grep -qx 'audio/mpeg=audacity.desktop' <(defaults)
check "a program not installed shouldn't be made a default" test -z "$(grep video/webm "$mine" || true)"
check "an added association shouldn't become a default" test -z "$(defaults | grep image/png || true)"
check "the link should stay a link" test -L "$HOME/.config/mimeapps.list"
check "the new line should be in [Default Applications], before the next section" \
  test "$(grep -n 'application/msword' "$mine" | cut -d: -f1)" -lt "$(grep -n 'Added Associations' "$mine" | cut -d: -f1)"
check "your other section should stay" grep -qx 'text/plain=emacs.desktop' "$mine"
check "the blank line before the next section should stay" grep -B1 -x '\[Added Associations\]' "$mine" | head -1 | grep -qx ''""

# Deleted by you: never offered again.
sed -i '/application\/msword/d' "$mine"
fill
check "a default you deleted should stay deleted" test -z "$(grep msword "$mine" || true)"

# mpv installed later: its defaults come then, once.
touch "$t/apps/mpv.desktop"
fill
check "a program installed later should get its defaults" grep -qx 'video/webm=mpv.desktop' <(defaults)
check "still never over yours" grep -qx 'audio/mpeg=audacity.desktop' <(defaults)
fill
check "a second run shouldn't add it twice" test "$(grep -c 'video/webm' "$mine")" = 1

# A file with no [Default Applications] gets one.
printf '[Added Associations]\ntext/plain=emacs.desktop\n' > "$mine"
: > "$offered"
fill
check "no section of defaults: one should be made" grep -qx '\[Default Applications\]' "$mine"
check "and the default put in it" grep -qx 'video/webm=mpv.desktop' <(defaults)

# The real starter: every default it names has a program some list installs or Vikix writes.
while IFS= read -r line; do
  app=${line#*=}; app=${app%%;*}
  case $app in vikix-*) continue ;; esac   # Vikix's own entries
  check "the starter's $app should be a real desktop entry name" grep -q '\.desktop$' <<<"$app"
done < <(mime_defaults "$here/config/xdg/mimeapps.list")

[ "$fail" = 0 ] && echo "mimeapps: the starter's defaults reach older files, only where you set none and the program is here, once each, in place"
exit "$fail"
