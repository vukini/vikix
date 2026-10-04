#!/usr/bin/env bash
# tests/pixmaps.sh — redrawing a title bar leaves nothing behind in the X server.
#
# vikix-titlebar-draw makes a picture of the bar each time (a pixmap, set as
# the bar's background, then freed). The font renderer (clx-truetype) keeps
# two pictures and a pen for whatever text is drawn on, and never frees
# them; a picture keeps its pixmap alive, so each redraw left a bar's worth
# of memory in Xorg: with terminals changing their titles, a gigabyte an
# hour on a real desktop. vikix-free-drawn-pixmap frees them first.
#
# A real StumpWM on a hidden screen: 400 redraws must not grow the X server
# (Xvfb keeps pixmaps in its own memory, so its size says); then, with the
# fix taken away in that StumpWM, the same 400 must, or the check sees nothing.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM (see tests/lib/wm.sh).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup pixmaps
wm_start
win A
xserver=${pids[0]}
size() { awk '/^VmRSS:/ {print $2}' "/proc/$xserver/status"; }
redraw() { ask "(progn (dotimes (i $1) (vikix-titlebar-draw (current-window))) (xlib:display-finish-output *display*) (princ 'done))" >/dev/null; sleep 1; }
grew() { local before; before=$(size); redraw 400; echo $(( ($(size) - before) / 1024 )); }

check "the window should have a title bar" test "$(ask '(princ (if (gethash (current-window) *vikix-titlebar-windows*) 1 0))')" = 1
redraw 30   # what the first draws set up isn't a leak
with=$(grew)
check "400 redraws of a title bar shouldn't grow the X server: it grew $with MB" test "$with" -lt 10

# Only the TrueType renderer keeps pictures; with X's own fonts there's nothing to leak.
if [ "$(ask '(princ (if (typep (screen-font (current-screen)) (quote xlib:font)) 0 1))')" = 1 ]; then
  ask '(defun vikix-free-drawn-pixmap (pixmap) (xlib:free-pixmap pixmap))' >/dev/null
  without=$(grew)
  check "without the fix the same redraws should grow it (or this test sees nothing): it grew $without MB" test "$without" -ge 15
  note="; without the fix, $without MB"
else
  note=" (X's own fonts here: the renderer that leaked isn't in use)"
fi

wm_report pixmaps "400 redraws of a title bar grew the X server by $with MB$note"
exit "$fail"
