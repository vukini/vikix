#!/usr/bin/env bash
# tests/capture.sh — vikix-screenshot takes what it was asked for (an area,
# the focused window, the monitor under the pointer) and puts it where it
# was asked (clipboard or file); vikix-record starts ffmpeg on the right
# part of the screen, stops it with TERM, and cleans up after it.
#
# Stand-ins write down what they were asked instead of touching the screen:
# maim, slop, xdotool, xrandr, xclip, notify-send, ffmpeg and vikix.

set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/bin/ffmpeg" 2>/dev/null || true; rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/home"
log="$t/log"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
stub maim        "echo \"maim \$*\" >> $log; for a; do f=\$a; done; echo png > \"\$f\""
stub slop        "echo 301x201+10+20"
stub xclip       "echo \"xclip \$*\" >> $log"
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
# ffmpeg: note the arguments, then wait to be stopped; write the file then.
stub ffmpeg      "echo \"ffmpeg \$*\" >> $log; for a; do f=\$a; done
trap 'echo video > \"\$f\"; exit 0' TERM
while :; do sleep 0.1; done"
export PATH="$t/bin:$PATH" HOME="$t/home" XDG_STATE_HOME="$t/state" DISPLAY=:7
shot() { : > "$log"; sh "$here/bin/vikix-screenshot" "$@"; }
fail=0
has() { grep -q -- "$1" "$log" || { echo "FAIL: $2"; sed 's/^/  /' "$log"; fail=1; }; }

shot clip
has "^maim -s " "a plain 'clip' should still drag out an area"
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

[ "$fail" = 0 ] && echo "capture: area, window and screen shots go where asked; recording starts, stops and saves"
exit "$fail"
