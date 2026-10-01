#!/usr/bin/env bash
# tests/capture.sh — vikix-screenshot takes what it was asked for (an area,
# the focused window, the monitor under the pointer) and puts it where it
# was asked (clipboard or file); vikix-record starts ffmpeg on the right
# part of the screen, stops it with TERM, and cleans up after it;
# "text" puts an area's text (tesseract, on the picture made 3x bigger) on
# the clipboard without the blank lines around it, and "colour" the
# colour xcolor picked, with a swatch in the notification. Cancelled, or
# nothing found, the clipboard is left alone.
#
# Stand-ins write down what they were asked instead of touching the screen:
# maim, slop, xdotool, xrandr, xclip, notify-send, ffmpeg, tesseract,
# xcolor and vikix.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/bin/ffmpeg" 2>/dev/null || true; rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/home"
log="$t/log"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
stub maim        "echo \"maim \$*\" >> $log; for a; do f=\$a; done; echo png > \"\$f\""
stub slop        "echo 301x201+10+20"
stub xclip       "echo \"xclip \$*\" >> $log; cat > $t/clip"
stub notify-send "echo \"notify \$*\" >> $log"
stub xdg-user-dir "echo $t/home/\$1"
ln -s "$here/bin/vikix-screenshot" "$t/bin/"   # vikix-record asks it for the area
stub vikix       "echo \"vikix \$*\" >> $log"
stub xdotool     'case $1 in
  getactivewindow) echo 4242 ;;
  getmouselocation) echo X=2000; echo Y=100 ;;
esac'
# Two monitors side by side; the pointer (2000,100) is on the second.
stub xrandr      'echo "Monitors: 2"
echo " 0: +*eDP-1 1920/344x1080/194+0+0  eDP-1"
echo " 1: +HDMI-1 2560/600x1440/340+1920+0  HDMI-1"'
# ffmpeg: note the arguments. Recording (x11grab), wait to be stopped and
# write the file then; anything else (a bigger picture, a swatch) at once.
stub ffmpeg      "echo \"ffmpeg \$*\" >> $log; for a; do f=\$a; done
case \"\$*\" in *x11grab*) ;; *) echo png > \"\$f\"; exit 0 ;; esac
trap 'echo video > \"\$f\"; exit 0' TERM
while :; do sleep 0.1; done"
# tesseract: what \$OCR says, the way tesseract prints it (blank lines
# around it, trailing spaces, a form feed at the end).
stub tesseract-ocr "echo \"tesseract \$*\" >> $log; printf '%b' \"\$OCR\""   # Void's name for it
stub xcolor      "echo xcolor >> $log; [ -n \"\$PICK\" ] || exit 1; echo \"\$PICK\""
export PATH="$t/bin:$PATH" HOME="$t/home" XDG_STATE_HOME="$t/state" DISPLAY=:7
export VIKIX_SHOT_SETTLE=0   # no waiting for picom's fade in a test
shot() { : > "$log"; sh "$here/bin/vikix-screenshot" "$@"; }
fail=0
has() { grep -q -- "$1" "$log" || { echo "FAIL: $2"; sed 's/^/  /' "$log"; fail=1; }; }

shot clip
has "^maim -g 301x201+10+20 " "a plain 'clip' should still drag out an area (slop, then maim)"
has "^xclip -selection clipboard -t image/png" "an area should go to the clipboard"
shot window clip
has "^maim -i 4242 " "window should take the focused window"
has "^notify -a Vikix -t 2000 Screenshot copied" "a window to the clipboard should say so"
shot screen file
has "^maim -g 2560x1440+1920+0 " "screen should take the monitor under the pointer"
shot area file; shot window file
[ "$(ls "$t/home/PICTURES/Screenshots/" | wc -l)" = 3 ] ||
  { echo "FAIL: three shots to a file didn't make three files in Screenshots"; fail=1; }
: > "$log"
sh "$here/bin/vikix-screenshot" nonsense 2>/dev/null && { echo "FAIL: a wrong word was accepted"; fail=1; }

rec() { sh "$here/bin/vikix-record" "$@"; }
pidfile="$t/state/vikix/recording"
waitfor() { for _ in $(seq 50); do eval "$1" && return 0; sleep 0.1; done; return 1; }

# A file left by a crash doesn't count as recording.
mkdir -p "$t/state/vikix"; echo 999999 > "$pidfile"
rec status >/dev/null && { echo "FAIL: a stale file counted as recording"; fail=1; }

: > "$log"
rec toggle area
waitfor 'grep -q "^ffmpeg" "$log" && rec status >/dev/null' ||
  { echo "FAIL: toggle didn't start recording"; fail=1; }
# 301x201 is odd; the encoder wants 300x200.
has "-video_size 300x200 -i :7+10,20 " "ffmpeg should record the chosen area, with even sides"
has "^vikix eval (vikix-record-refresh)" "the bar should hear that recording started"
rec area 2>/dev/null && { echo "FAIL: a second recording started over the first"; fail=1; }
rec toggle
waitfor '[ ! -e "$pidfile" ] && grep -q "^notify -a Vikix Recording saved" "$log"' ||
  { echo "FAIL: toggle didn't stop and save the recording"; sed 's/^/  /' "$log"; fail=1; }
ls "$t/home/VIDEOS/Recordings/"*.mp4 >/dev/null 2>&1 ||
  { echo "FAIL: the video didn't land in Recordings"; fail=1; }
rec stop 2>/dev/null && { echo "FAIL: stop said yes with nothing recording"; fail=1; }

# --- text from an area (OCR) ------------------------------------------------------
rm -f "$t/clip"
OCR='\n\nHello  world  \n\nsecond line\n\n\f\n' shot text
has "^maim -g 301x201+10+20 " "text should drag out an area (slop, then maim)"
has "^ffmpeg .*scale=iw\*3:ih\*3" "text should make the picture 3 times bigger before reading it"
has "^tesseract .* stdout -l eng --psm 6" "text should read it with tesseract, in English, as one block"
[ "$(cat "$t/clip" 2>/dev/null)" = "$(printf 'Hello  world\n\nsecond line')" ] ||
  { echo "FAIL: the clipboard should have the text without the blank lines around it:"; cat -A "$t/clip" 2>/dev/null | sed 's/^/  /'; fail=1; }
has "^notify -a Vikix -t 4000 Text copied Hello  world (and 2 more lines)" "text should say what it copied"
rm -f "$t/clip"
OCR='\n  \n\f\n' shot text
has "No text found" "an area with no text should say so"
[ ! -e "$t/clip" ] || { echo "FAIL: no text found, yet the clipboard was changed"; fail=1; }
stub slop "exit 1"                                  # Escape while choosing
shot text
grep -q '^tesseract' "$log" && { echo "FAIL: a cancelled area was still read"; fail=1; }
[ ! -e "$t/clip" ] || { echo "FAIL: a cancelled area changed the clipboard"; fail=1; }

# --- pick a colour ------------------------------------------------------------------
PICK='#1a2B3c' shot colour
[ "$(cat "$t/clip" 2>/dev/null)" = '#1a2B3c' ] || { echo "FAIL: the colour's hex should be on the clipboard, got: $(cat "$t/clip" 2>/dev/null)"; fail=1; }
has "^ffmpeg .*color=c=0x1a2B3c" "colour should make a swatch of it"
has "^notify -a Vikix -t 4000 -i .*Colour #1a2B3c copied" "colour should say what it copied, with the swatch"
rm -f "$t/clip"
PICK='' shot colour                                   # Escape
[ ! -e "$t/clip" ] || { echo "FAIL: a cancelled pick changed the clipboard"; fail=1; }
PICK='not a colour' shot colour
[ ! -e "$t/clip" ] || { echo "FAIL: something that isn't #rrggbb went to the clipboard"; fail=1; }

# --- picom's fade -------------------------------------------------------------------
# With picom running, the picture waits for slop's window to fade out
# first (a picom that blurs behind it would blur the picture); without, no wait.
stub slop  "echo 301x201+10+20"
stub maim  "echo \"maim \$*\" >> $log; for a; do f=\$a; done; echo png > \"\$f\""
stub sleep "echo \"sleep \$*\" >> $log"
stub pgrep "[ \"\$2\" = picom ]"
VIKIX_SHOT_SETTLE='' shot clip
[ "$(grep -E '^(sleep|maim)' "$log" | cut -d' ' -f1-2 | tr '\n' ' ')" = "sleep 0.5 maim -g " ] ||
  { echo "FAIL: with picom running, the area should wait 0.5 s for slop's fade, then be taken:"; sed 's/^/  /' "$log"; fail=1; }
stub pgrep "exit 1"
VIKIX_SHOT_SETTLE='' shot clip
grep -q '^sleep' "$log" && { echo "FAIL: without picom, the area shouldn't wait"; fail=1; }

[ "$fail" = 0 ] && echo "capture: area, window and screen shots go where asked; recording starts, stops and saves; text and colour go to the clipboard"
exit "$fail"
