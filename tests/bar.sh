#!/usr/bin/env bash
# tests/bar.sh — what the bar shows and draws with: vikix-net labels the
# link (and hides a strong signal), and vikix-font gives StumpWM one font
# file, Iosevka when it can be had, a stand-in until then.
#
# nmcli and the fonts are stand-ins in a made-up folder; nothing real is
# asked or written.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# --- vikix-net ------------------------------------------------------------------
mkdir -p "$t/bin"
# net SIGNAL [TYPE:STATE] — what vikix-net prints with this Wi-Fi signal
# (none: no Wi-Fi) and this wired state.
net() {
  cat > "$t/bin/nmcli" <<EOF
#!/bin/sh
case "\$*" in
  *"device wifi"*) echo "no:90:Neighbour"; [ "$1" = none ] || echo 'yes:$1:Cafe\\:Two' ;;
  *) echo "${2:-wifi:connected}" ;;
esac
EOF
  chmod +x "$t/bin/nmcli"
  PATH="$t/bin:$PATH" sh "$here/bin/vikix-net"
}
check "a strong signal should show only the name" test "$(net 80)" = "wifi Cafe:Two"
check "60% counts as strong" test "$(net 60)" = "wifi Cafe:Two"
check "a weak signal should show its strength" test "$(net 42)" = "wifi Cafe:Two 42%"
check "a cable should say wired" test "$(net none ethernet:connected)" = wired
check "nothing should say offline" test "$(net none ethernet:unavailable)" = offline
[ "$fail" = 0 ] && echo "bar: vikix-net labels Wi-Fi, and shows the signal only when it is weak"

# --- vikix-font -----------------------------------------------------------------
font() {
  VIKIX_FONT_DIR="$t/fonts" VIKIX_FONT_TTC="$t/Iosevka.ttc" \
    VIKIX_FONT_STANDIN="$t/Standin.ttf" sh "$here/bin/vikix-font" "$@"
}
echo standin > "$t/Standin.ttf"
out=$(font)
check "without Iosevka it should print wm.ttf" test "$out" = "$t/fonts/wm.ttf"
check "without Iosevka wm.ttf should link to the stand-in" test "$(readlink "$t/fonts/wm.ttf")" = "$t/Standin.ttf"
rm "$t/Standin.ttf"
if font >/dev/null 2>&1; then echo "FAIL: with no font at all vikix-font should fail"; fail=1; fi

# The real extraction, when this machine has Iosevka and fontTools.
if [ -r /usr/share/fonts/TTF/Iosevka.ttc ] && python3 -c 'import fontTools' 2>/dev/null; then
  ln -sfn /usr/share/fonts/TTF/Iosevka.ttc "$t/Iosevka.ttc"
  font >/dev/null
  check "wm.ttf should be a file of its own, not a link" test -f "$t/fonts/wm.ttf" -a ! -L "$t/fonts/wm.ttf"
  check "wm.ttf should be Iosevka Regular" python3 -c '
import sys; from fontTools.ttLib import TTFont
n = TTFont(sys.argv[1])["name"]
sys.exit(not (n.getDebugName(1) == "Iosevka" and n.getDebugName(2) == "Regular"))' "$t/fonts/wm.ttf"
  touch -d '2000-01-01 00:00 UTC' "$t/fonts/wm.ttf"
  font >/dev/null
  check "an existing wm.ttf should be kept, not made again" test "$(stat -c %Y "$t/fonts/wm.ttf")" = 946684800
  font --force >/dev/null
  check "--force should make wm.ttf again" test "$(stat -c %Y "$t/fonts/wm.ttf")" != 946684800
else
  echo "(no Iosevka or fontTools here: the extraction itself is skipped)"
fi
[ "$fail" = 0 ] && echo "bar: vikix-font gives StumpWM Iosevka, or a stand-in until it is installed"
exit "$fail"
