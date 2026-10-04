#!/usr/bin/env bash
# tests/screens.sh — vikix-screens, against made-up xrandr and autorandr
# (no screen is plugged in a test): a new screen is laid out right of the
# laptop's at the largest size it shows at 50 Hz or more (a 4K screen on
# HDMI 1.4: 2560x1440 at 60, not 4K at 30), saved for next time, and said
# in a notification; screens with a saved layout are autorandr's, left
# alone; an unplug leaves the laptop's alone, without a notification;
# mirror takes the largest size every screen has; external and laptop
# turn the other off; called inside autorandr (its own hook), it does
# nothing; autorandr's hook and Super+Ctrl+p are in place.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config"
mkdir -p "$HOME/.local/state/vikix" "$t/bin"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# The laptop's screen, and a Samsung M80C on HDMI 1.4 (4K only at 30 Hz).
cat > "$t/plugged" <<'X'
Screen 0: minimum 8 x 8, current 1920 x 1080, maximum 32767 x 32767
eDP1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 310mm x 170mm
   1920x1080     60.05*+  59.93    48.03
   1680x1050     59.88
HDMI1 connected (normal left inverted right x axis y axis)
   3840x2160     30.00 +  25.00    24.00
   2560x1440     59.95
   1920x1080     60.00    50.00    59.94
   1280x720      60.00
DP1 disconnected (normal left inverted right x axis y axis)
X
# Unplugged: HDMI1 still on, its screen gone.
cat > "$t/unplugged" <<'X'
Screen 0: minimum 8 x 8, current 4480 x 1440, maximum 32767 x 32767
eDP1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 310mm x 170mm
   1920x1080     60.05*+
HDMI1 disconnected 2560x1440+1920+0 (normal left inverted right x axis y axis) 0mm x 0mm
DP1 disconnected (normal left inverted right x axis y axis)
X
cp "$t/plugged" "$t/now"
cat > "$t/bin/xrandr" <<SH
#!/bin/sh
if [ "\$1" = --query ]; then cat "$t/now"; else echo "\$*" >> "$t/xrandr-calls"; fi
SH
cat > "$t/bin/autorandr" <<SH
#!/bin/sh
case "\$1" in
  --fingerprint) awk '/ connected/ {print \$1, "edid-" \$1}' "$t/now" ;;
  --save) mkdir -p "$XDG_CONFIG_HOME/autorandr/\$2"; awk '/ connected/ {print \$1, "edid-" \$1}' "$t/now" > "$XDG_CONFIG_HOME/autorandr/\$2/setup" ;;
esac
SH
printf '#!/bin/sh\necho "$*" >> %s/notes\n' "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
sc() { python3 "$here/bin/vikix-screens" "$@"; }

# A new screen: extended right, at its best fast mode, saved, said.
sc auto
call=$(tail -1 "$t/xrandr-calls")
check "the laptop's screen at 0,0, primary: $call" grep -q -- '--output eDP1 --mode 1920x1080 --rate 60.05 --pos 0x0 --rotate normal --primary' <<<"$call"
check "the new one right of it, 2560x1440 at 60, not 4K at 30: $call" grep -q -- '--output HDMI1 --mode 2560x1440 --rate 59.95 --pos 1920x0' <<<"$call"
check "a screen not plugged in is off: $call" grep -q -- '--output DP1 --off' <<<"$call"
saved=$(ls "$XDG_CONFIG_HOME/autorandr")
check "the layout should be saved for these screens: $saved" grep -q '^auto-' <<<"$saved"
check "and said: $(cat "$t/notes" 2>/dev/null)" grep -q 'A screen: lit up' "$t/notes"

# The same screens again: a saved layout, autorandr's to put back.
: > "$t/xrandr-calls"
sc auto
check "with a saved layout, it should leave them to autorandr" test ! -s "$t/xrandr-calls"

# Inside autorandr (its own hook, called again by autorandr): nothing.
rm -rf "$XDG_CONFIG_HOME/autorandr"/auto-*
VIKIX_SCREENS_INSIDE=1 sc predetect
check "inside autorandr it should do nothing" test ! -s "$t/xrandr-calls"

# Unplugged: the laptop's alone, HDMI1 off, no notification.
cp "$t/unplugged" "$t/now"; : > "$t/notes"
sc auto
call=$(tail -1 "$t/xrandr-calls")
check "unplugged, the gone screen should be off: $call" grep -q -- '--output HDMI1 --off' <<<"$call"
check "and the laptop's on" grep -q -- '--output eDP1 --mode 1920x1080' <<<"$call"
check "no notification for the laptop alone" test ! -s "$t/notes"

# The menu's choices, plugged in.
cp "$t/plugged" "$t/now"
sc mirror >/dev/null
call=$(tail -1 "$t/xrandr-calls")
check "mirror: the largest size both have, both at 0,0: $call" bash -c 'grep -q -- "--output eDP1 --mode 1920x1080 --rate 60.05 --pos 0x0" <<<"$1" && grep -q -- "--output HDMI1 --mode 1920x1080 --rate 60.00 --pos 0x0" <<<"$1"' _ "$call"
sc external >/dev/null
call=$(tail -1 "$t/xrandr-calls")
check "external: the laptop's off, the other at 0,0, primary: $call" bash -c 'grep -q -- "--output eDP1 --off" <<<"$1" && grep -q -- "--output HDMI1 --mode 2560x1440 --rate 59.95 --pos 0x0 --rotate normal --primary" <<<"$1"' _ "$call"
sc laptop >/dev/null
call=$(tail -1 "$t/xrandr-calls")
check "laptop: the other off: $call" grep -q -- '--output HDMI1 --off' <<<"$call"

# In place: autorandr's hook, Super+Ctrl+p and the display key.
check "the hook should run vikix-screens predetect" grep -q 'vikix-screens" predetect' "$here/config/autorandr/predetect.d/vikix"
check "the hook should be executable" test -x "$here/config/autorandr/predetect.d/vikix"
check "40-config should link the hook" grep -q 'autorandr/predetect.d/vikix' "$here/install/40-config.sh"
check "Super+Ctrl+p should be the screens menu" grep -q ':run "vikix-screens-pick" :key "s-C-p"' "$here/config/stumpwm/vikix/registry.lisp"
check "and the laptop's display key" grep -q ':run "vikix-screens-pick" :key "XF86Display"' "$here/config/stumpwm/vikix/registry.lisp"

[ "$fail" = 0 ] && echo "screens: a new screen extended at its best fast mode and saved, a saved one left to autorandr, unplugged back to the laptop, mirror, one only, the hook and the keys"
exit "$fail"
