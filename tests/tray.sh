#!/usr/bin/env bash
# tests/tray.sh — the tray (vikix tray on), in a real StumpWM on a hidden
# screen: on at the start when switched on, an icon (a GTK status icon)
# embedded in it, the bar leaving it room; still there, once, after a
# reload; the bar's network field stepping aside only while the network
# applet's icon is in the tray (Bluetooth's, with no icon there, stays);
# an applet that has stopped started again, once; the tray taken down with
# a bar that is hidden and put into the new one when it shows, its icon
# back; a tray left behind in a bar that is gone found by the bar's round
# and made anew; vikix-tray-off and the toggle switch it and say so in the
# settings file, an applets line naming none staying empty; where the bar
# is said in _NET_WORKAREA, and vikix-bar (Super+Ctrl+h) hides and shows it.
# Needs Xvfb, Vikix's StumpWM, StumpWM's contrib modules (stumptray) and
# Quicklisp's xembed, and python3's GTK 3 for the icon; skipped without.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
wm=${VIKIX_TEST_STUMPWM:-$HOME/.local/bin/stumpwm}
modules=$HOME/.stumpwm.d/modules
for need in Xvfb xdpyinfo; do command -v "$need" >/dev/null || { echo "tray: needs $need; skipped"; exit 0; }; done
[ -x "$wm" ] || { echo "tray: needs Vikix's StumpWM; skipped"; exit 0; }
[ -f "$modules/modeline/stumptray/stumptray.asd" ] || { echo "tray: needs StumpWM's contrib modules; skipped"; exit 0; }
ls -d "$HOME"/quicklisp/dists/*/software/*xembed* >/dev/null 2>&1 || { echo "tray: needs Quicklisp's xembed; skipped"; exit 0; }
python3 -c 'import gi; gi.require_version("Gtk", "3.0")' 2>/dev/null || { echo "tray: needs python3's GTK 3; skipped"; exit 0; }

t=$(mktemp -d); pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
n=$(( 100 + RANDOM % 400 ))
while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
pids+=($!)
home="$t/home"
mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix"
cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
ln -s "$modules" "$home/.stumpwm.d/modules"
ln -s "$HOME/quicklisp" "$home/quicklisp"
sed -i "s/(defparameter \*vikix-swank-port\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
echo "tray-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
touch "$home/.local/state/vikix/welcome"
# On, and no applets: the test's icon is its own, and no applet of the
# desktop's is started on the hidden screen.
printf 'on\napplets =\n' > "$home/.config/vikix/tray"
# Stand-ins for the two applets and for asking whether they run: the real
# pgrep sees the whole machine, the real desktop's applets too, and a real
# nm-applet has no place on a hidden screen. An applet "runs" while its
# name is in $t/running; started, it says so and puts its name there.
mkdir -p "$t/path"
real_pgrep=$(command -v pgrep)
cat > "$t/path/pgrep" <<END
#!/bin/sh
case "\$1 \$2" in "-x nm-applet"|"-x blueman-applet") grep -qx "\$2" "$t/running" 2>/dev/null; exit \$? ;; esac
exec "$real_pgrep" "\$@"
END
real_pkill=$(command -v pkill)
cat > "$t/path/pkill" <<END
#!/bin/sh
case "\$1 \$2" in "-x nm-applet"|"-x blueman-applet") sed -i "/^\$2\\\$/d" "$t/running" 2>/dev/null; echo "\$2" >> "$t/ended"; exit 0 ;; esac
exec "$real_pkill" "\$@"
END
for applet in nm-applet blueman-applet; do
  printf '#!/bin/sh\necho %s >> "%s/started"\necho %s >> "%s/running"\n' "$applet" "$t" "$applet" "$t" > "$t/path/$applet"
done
chmod +x "$t/path/"*
printf 'nm-applet\nblueman-applet\n' > "$t/running"; : > "$t/started"; : > "$t/ended"
for _ in $(seq 1 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
PATH="$t/path:$PATH" HOME=$home VIKIX_SWANK_PORT=$port "$wm" >"$t/wm.log" 2>&1 &
pids+=($!)
ask() { HOME=$home VIKIX_SWANK_PORT=$port timeout 30 python3 "$here/bin/vikix-eval" "$1" 2>&1 | grep -v '^=> ' || true; }
for _ in $(seq 1 120); do [ "$(ask '(princ 1)')" = 1 ] && break; sleep 0.5; done
[ "$(ask '(princ 1)')" = 1 ] || { echo "FAIL: the test StumpWM didn't start: $(tail -5 "$t/wm.log")"; exit 1; }

state() { ask '(princ (if (vikix-tray-object) :on :off))'; }
check "the tray should be on at the start, as the settings say: $(state)" test "$(state)" = ON
# The test's icon calls itself the network applet's, as its window's class.
python3 - <<'PY' &
import gi, warnings; warnings.simplefilter("ignore")
gi.require_version("Gtk", "3.0"); gi.require_version("Gdk", "3.0"); from gi.repository import Gtk, Gdk, GLib
GLib.set_prgname("nm-applet"); Gdk.set_program_class("Nm-applet")
icon = Gtk.StatusIcon.new_from_icon_name("network-wireless")   # kept, or it goes
GLib.timeout_add(300000, Gtk.main_quit); Gtk.main()
PY
icon_pid=$!
pids+=("$icon_pid")
icons=0
for _ in $(seq 1 40); do
  icons=$(ask '(let ((tr (vikix-tray-object))) (princ (+ (length (funcall (find-symbol "TRAY-VICONS" :stumptray) tr)) (length (funcall (find-symbol "TRAY-HICONS" :stumptray) tr)))))')
  [ "$icons" = 1 ] && break; sleep 0.25
done
check "the icon should be in the tray: $icons" test "$icons" = 1
room=$(ask '(princ (length (vikix-mode-line-tray nil)))')
check "the bar should leave the tray room: $room spaces" test "$room" -gt 2
# The network's and Bluetooth's own fields step aside while their applets
# are in the tray (set here: the test starts none on the hidden screen).
fields='(progn (setf *vikix-net* "wifi Home" *vikix-bt* "bt") (format t "[~a][~a]" (vikix-mode-line-net nil) (vikix-mode-line-bt nil)))'
check "without applets, the bar should show the network and Bluetooth: $(ask "$fields")" bash -c '[[ $1 == *"wifi Home"*"bt"* ]]' _ "$(ask "$fields")"
plain() { ask "$fields" | sed 's/\^[^)]*)//g; s/  *\]/]/g'; }   # the fields without the bar's own markup
ask '(setf *vikix-tray-applets* (list "nm-applet" "blueman-applet"))' >/dev/null
ask '(vikix-tray-note-icons)' >/dev/null
check "the icon in the tray is known by its class: $(ask '(prin1 *vikix-tray-icons*)')" test "$(ask '(prin1 *vikix-tray-icons*)')" = '("Nm-applet")'
check "the network's field steps aside for its icon; Bluetooth's applet has none there, so the bar still says it: $(plain)" test "$(plain)" = "[][bt]"
# An applet that stops takes its icon with it: the bar's own field comes
# back, and the applet is started again, but not twice in five minutes.
missing() { ask '(progn (vikix-tray-refresh) (princ *vikix-tray-missing*))'; }
ask '(setf (gethash "nm-applet" *vikix-tray-restarted*) (- (get-universal-time) 301))' >/dev/null   # it has been up a while
echo blueman-applet > "$t/running"
check "the network applet has stopped: the bar's rounds find it gone: $(missing)" grep -q 'nm-applet' "$t/started"
check "it is started again, once: $(tr '\n' ' ' < "$t/started")" test "$(grep -c nm-applet "$t/started")" = 1
echo blueman-applet > "$t/running"
ask '(vikix-tray-refresh)' >/dev/null
check "and it isn't started a second time within five minutes: $(tr '\n' ' ' < "$t/started")" test "$(grep -c nm-applet "$t/started")" = 1
check "the bar's own thread makes this round" test "$(ask "(princ (and (member 'vikix-tray-refresh *vikix-bar-refreshers*) t))")" = T
ask '(run-commands "vikix-reload")' >/dev/null; sleep 1
check "a reload should keep the tray: $(state)" test "$(state)" = ON
check "and not add its handler twice" test "$(ask '(princ (length *event-processing-hook*))')" = 1
ask '(run-commands "vikix-tray-off")' >/dev/null
check "vikix-tray-off should take it away" test "$(state)" = OFF
check "and bring the bar's own network field back: $(ask "$fields")" bash -c '[[ $1 == *"wifi Home"* ]]' _ "$(ask "$fields")"
check "and say so in the settings" grep -qx off "$home/.config/vikix/tray"
check "an applets line naming none should stay empty" grep -qx 'applets = ' "$home/.config/vikix/tray"
ask '(run-commands "vikix-tray")' >/dev/null
check "the toggle should put it back" test "$(state)" = ON
check "and say so in the settings" grep -qx on "$home/.config/vikix/tray"
# Where the bar is, said as other desktops say it (_NET_WORKAREA: FreeRDP
# reads it for Windows programs), and the bar switched off and on.
area() { xprop -root _NET_WORKAREA 2>/dev/null | sed -n 's/.*= \([0-9]*\), \([0-9]*\), \([0-9]*\), \([0-9]*\).*/\1 \2 \3 \4/p'; }
bar=$(ask '(princ (mode-line-height (head-mode-line (current-head))))')
check "_NET_WORKAREA starts below the bar: $(area)" test "$(area)" = "0 $bar 1280 $((800 - bar))"
ask '(run-commands "vikix-bar")' >/dev/null
check "vikix-bar hides the bar, and the whole screen is free: $(area)" test "$(area)" = "0 0 1280 800"
check "the tray is taken down with its bar: $(state)" test "$(state)" = OFF
ask '(run-commands "vikix-bar")' >/dev/null
check "and shows it again: $(area)" test "$(area)" = "0 $bar 1280 $((800 - bar))"
# The tray follows the bar: in the new one a second after it shows, its
# window there, the icon docked again.
sound() { ask '(princ (list (and (vikix-tray-object) t) (vikix-tray-stale-p) (and (ignore-errors (xlib:drawable-width (funcall (find-symbol "TRAY-WIN" :stumptray) (vikix-tray-object)))) t) (length (funcall (find-symbol "TRAY-VICONS" :stumptray) (vikix-tray-object)))))'; }
for _ in $(seq 1 40); do [ "$(sound)" = "(T NIL T 1)" ] && break; sleep 0.25; done
check "shown again, the bar has the tray in it, with its icon (there, not left behind, its window alive, icons): $(sound)" test "$(sound)" = "(T NIL T 1)"
# The icon gone (its program ended): the field is back.
ask '(setf *vikix-tray-applets* (list "nm-applet"))' >/dev/null
ask '(vikix-tray-note-icons)' >/dev/null
check "with the icon there the network's field steps aside: $(ask "$fields")" bash -c '[[ $1 == "[]["* ]]' _ "$(ask "$fields")"
kill "$icon_pid" 2>/dev/null || true
for _ in $(seq 1 40); do [ "$(ask '(progn (vikix-tray-note-icons) (prin1 *vikix-tray-icons*))')" = NIL ] && break; sleep 0.25; done
check "the icon's program ended: the bar says the network itself again: $(ask "$fields" | cut -c1-40)" bash -c '[[ $1 == *"wifi Home"* ]]' _ "$(ask "$fields")"
# What happened on a real desktop: the bar made anew with nobody telling
# the tray. Its icons go with the old bar's window. The bar's own round
# finds the tray left behind, makes it anew, and starts its applets again.
printf 'nm-applet\n' > "$t/running"; : > "$t/started"; : > "$t/ended"
ask "(progn (remove-hook *destroy-mode-line-hook* 'vikix-tray-bar-gone) (remove-hook *new-mode-line-hook* 'vikix-tray-bar-new) (run-commands \"vikix-bar\" \"vikix-bar\") (add-hook *destroy-mode-line-hook* 'vikix-tray-bar-gone) (add-hook *new-mode-line-hook* 'vikix-tray-bar-new))" >/dev/null
check "a bar rebuilt behind the tray's back leaves it behind: $(ask '(princ (vikix-tray-stale-p))')" test "$(ask '(princ (vikix-tray-stale-p))')" = T
check "and then no icon is taken to be there, so the bar says the network itself: $(ask '(progn (vikix-tray-note-icons) (prin1 *vikix-tray-icons*))')" test "$(ask '(prin1 *vikix-tray-icons*)')" = NIL
printf 'on\napplets = nm-applet\n' > "$home/.config/vikix/tray"   # the tray's own applet now (a stand-in: see above)
ask '(vikix-tray-refresh)' >/dev/null
for _ in $(seq 1 40); do [ "$(sound | cut -c1-9)" = "(T NIL T " ] && grep -q nm-applet "$t/started" && break; sleep 0.25; done
check "the bar's round makes the tray anew (there, not left behind, its window alive): $(sound)" test "$(sound | cut -c1-9)" = "(T NIL T "
check "and its applet, whose icon went with the old bar, is ended and started again: ended $(tr '\n' ' ' < "$t/ended"), started $(tr '\n' ' ' < "$t/started")" \
  test "$(cat "$t/ended") $(cat "$t/started")" = "nm-applet nm-applet"
check "with one handler for its events, not two: $(ask '(princ (length *event-processing-hook*))')" test "$(ask '(princ (length *event-processing-hook*))')" = 1
check "the tray is put up by the bar's hooks, once each" test "$(ask "(princ (list (count 'vikix-tray-bar-gone *destroy-mode-line-hook*) (count 'vikix-tray-bar-new *new-mode-line-hook*)))")" = "(1 1)"
check "Super+Ctrl+h is the bar's key" grep -q '(s-C-h vikix-bar ' <<<"$(ask '(princ (assoc "s-C-h" *vikix-bindings* :test (quote string=)))')"
check "StumpWM should still answer" test "$(ask '(princ 1)')" = 1

[ "$fail" = 0 ] && echo "tray: on from the settings, an icon in it with room in the bar, the network's field aside only for its icon, an applet that stops started again once, the tray following a bar hidden and shown, one left behind made anew, through a reload, off and on, remembered"
exit "$fail"
