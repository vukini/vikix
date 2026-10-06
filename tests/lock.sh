#!/usr/bin/env bash
# tests/lock.sh — vikix-lock: one locker, and notifications wait while locked.
#
#   --locker runs i3lock in the foreground with the theme's colour, pauses
#   dunst while it runs and resumes it after; Do not disturb (already
#   paused) stays paused; i3lock's failure is the locker's; with xss-lock
#   running, plain vikix-lock asks it to lock; without, it locks by itself,
#   pausing too; a bad colour falls back to void's; when the monitor comes
#   back on from DPMS while locked, Escape clears the key that woke it;
#   the lock screen's window is raised again every half second while it is
#   up, so a window that opens meanwhile doesn't stay in front of it;
#   with i3lock-color (its usage names the manpage) the lock screen gets
#   the wallpaper (a picture; not the plain PPM of a theme without one),
#   the clock and the ring in the theme's colours; with plain i3lock, the
#   theme's colour alone.
#
# i3lock, vikix-wallpaper, dunstctl, pgrep, xset and xdotool are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home"
mkdir -p "$HOME/.config/vikix/theme" "$t/bin"
echo 282828 > "$HOME/.config/vikix/theme/lock"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"

# i3lock: notes whether dunst was paused while it ran; $t/i3lock-fails fails
# it; with $t/dark, the monitor goes off while it runs, then a key wakes it.
cat > "$t/bin/i3lock" <<END
#!/bin/sh
# --help: i3lock-color's usage names the manpage, with $t/color.
[ "\$1" = --help ] && { [ -e "$t/color" ] && echo "Please see the manpage for a full list of arguments." >&2; exit 1; }
echo "i3lock \$* paused=\$(cat "$t/paused")" >> "$calls"
[ -e "$t/i3lock-fails" ] && exit 1
if [ -e "$t/dark" ]; then
  sleep 0.3; echo Off > "$t/monitor"; sleep 0.3; echo On > "$t/monitor"; sleep 0.4
fi
exit 0
END
echo On > "$t/monitor"
# xdotool: finds the lock screen's window (4242), and notes what it's asked.
cat > "$t/bin/xdotool" <<END
#!/bin/sh
echo "xdotool \$*" >> "$calls"
[ "\$1" = search ] && echo 4242
exit 0
END
# vikix-wallpaper which: the picture showing, from $t/wallpaper.
cat > "$t/bin/vikix-wallpaper" <<END
#!/bin/sh
[ "\$1" = which ] && cat "$t/wallpaper"
END
cat > "$t/bin/dunstctl" <<END
#!/bin/sh
case "\$1" in
  is-paused) cat "$t/paused" ;;
  set-paused) echo "\$2" > "$t/paused"; echo "dunstctl set-paused \$2" >> "$calls" ;;
esac
END
cat > "$t/bin/pgrep" <<END
#!/bin/sh
[ -e "$t/xss-lock" ]
END
cat > "$t/bin/xset" <<END
#!/bin/sh
[ "\$1" = q ] && { printf '  DPMS is Enabled\\n  Monitor is %s\\n' "\$(cat "$t/monitor")"; exit 0; }
echo "xset \$*" >> "$calls"
END
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
lock() { sh "$here/bin/vikix-lock" "$@"; }

: > "$calls"; echo false > "$t/paused"
lock --locker || { echo "FAIL: the locker should succeed"; fail=1; }
check "i3lock should run in the foreground, the theme's colour, dunst paused: $(cat "$calls")" \
  grep -qx "i3lock -n -c 282828 paused=true" "$calls"
check "notifications should come back after unlocking" test "$(cat "$t/paused")" = false
check "no Escape when the screen never went dark: $(cat "$calls")" test -z "$(grep 'xdotool key' "$calls" || true)"

: > "$calls"; echo false > "$t/paused"; touch "$t/dark"
lock --locker
check "the key that wakes the dark screen should be cleared: $(cat "$calls")" \
  test "$(grep -c "xdotool key Escape" "$calls")" = 1
rm -f "$t/dark"
# Locked for a second: its window is found once and raised again and again,
# so nothing that opens meanwhile stays in front of it.
check "the lock screen should be found by its class: $(grep search "$calls")" grep -qx "xdotool search --class i3lock" "$calls"
check "and found once, not at every turn" test "$(grep -c 'xdotool search' "$calls")" = 1
check "it should be raised again while locked: $(grep -c 'windowraise 4242' "$calls") times" test "$(grep -c 'xdotool windowraise 4242' "$calls")" -ge 1
sleep 0.2
seen=$(grep -c xdotool "$calls")
sleep 0.8
check "nothing should be left watching after unlocking" test "$(grep -c xdotool "$calls")" = "$seen"

: > "$calls"; echo true > "$t/paused"
lock --locker
check "Do not disturb should stay on: $(cat "$calls")" test "$(cat "$t/paused")" = true
check "it shouldn't touch dunst when already paused" test -z "$(grep dunstctl "$calls" || true)"

: > "$calls"; echo false > "$t/paused"; touch "$t/i3lock-fails"
if lock --locker; then echo "FAIL: i3lock's failure should be the locker's"; fail=1; fi
check "notifications should come back after a failed lock" test "$(cat "$t/paused")" = false
rm -f "$t/i3lock-fails"

: > "$calls"; touch "$t/xss-lock"
lock
check "with xss-lock, it should ask xss-lock: $(cat "$calls")" grep -qx "xset s activate" "$calls"
check "with xss-lock, no second i3lock" test -z "$(grep i3lock "$calls" || true)"
rm -f "$t/xss-lock"

: > "$calls"; echo false > "$t/paused"
lock; sleep 0.3
check "without xss-lock, it should lock by itself, paused: $(cat "$calls")" grep -qx "i3lock -n -c 282828 paused=true" "$calls"
check "and resume after" test "$(cat "$t/paused")" = false

: > "$calls"; echo 'not a colour' > "$HOME/.config/vikix/theme/lock"
lock --locker
check "a bad colour should fall back to void's" grep -q "i3lock -n -c 1e1e2e" "$calls"

# i3lock-color: the wallpaper, the clock and the theme's colours.
echo 282828 > "$HOME/.config/vikix/theme/lock"
printf 'bg=#282828\nfg=#ebdbb2\nsubtle=#a89984\naccent=#fabd2f\nalert=#fb4934\n' > "$HOME/.config/vikix/theme/palette"
touch "$t/color" "$t/wall.png"; echo "$t/wall.png" > "$t/wallpaper"
: > "$calls"; echo false > "$t/paused"
lock --locker
check "i3lock-color should get the wallpaper, filled: $(cat "$calls")" grep -q -- "-i $t/wall.png -F " "$calls"
check "and the clock" grep -q -- "--force-clock" "$calls"
check "and the theme's colours: the ring in the accent, the time in the foreground, wrong in the alert colour" \
  grep -q -- "--ring-color=fabd2fff .*--time-color=ebdbb2ff\|--time-color=ebdbb2ff .*--ring-color=fabd2fff" "$calls"
check "wrong in the alert colour" grep -q -- "--ringwrong-color=fb4934ff" "$calls"
check "in the foreground (-n), on the theme's background" grep -q -- "i3lock -n -c 282828ff " "$calls"
check "dunst paused meanwhile" grep -q "paused=true" "$calls"

# A theme without a picture: vikix-wallpaper makes a plain PPM, which
# i3lock can't show; the colour alone then.
: > "$calls"; echo "$t/plain-282828.ppm" > "$t/wallpaper"; touch "$t/plain-282828.ppm"
lock --locker
check "a plain PPM wallpaper shouldn't be passed to i3lock: $(cat "$calls")" test -z "$(grep -- ' -i ' "$calls" || true)"
check "the clock still" grep -q -- "--force-clock" "$calls"

# A palette the theme never wrote: the lock colour as background, white on it.
: > "$calls"; rm -f "$HOME/.config/vikix/theme/palette"
lock --locker
check "without a palette, the lock colour and white: $(cat "$calls")" grep -q -- "i3lock -n -c 282828ff .*--time-color=ffffffff" "$calls"
rm -f "$t/color"

[ "$fail" = 0 ] && echo "lock: the locker, one lock, notifications paused while locked, i3lock-color's look"
exit "$fail"
