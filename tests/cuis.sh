#!/usr/bin/env bash
# tests/cuis.sh — vikix cuis: Cuis Smalltalk as a Vikix program, and its door.
#
#   With a made-up release (a zip in the tag's shape, a VM that is a script):
#   a dry run changes nothing; setup refuses a download whose checksum is
#   wrong, unpacks only the Linux parts, writes the pin, lays ~/cuis out
#   (links to the release's Packages, CoreUpdates, TrueTypeFonts and the
#   sources, NewPackages, Vikix's packages), builds the image with no window
#   (-vm-display-null, -u, the build script requiring cuis/VikixServer.pck.st),
#   writes the cuis command and the launcher's entry and records the feature;
#   a second setup downloads and builds nothing; a changed stamp builds again;
#   run passes -ud ~/cuis and the door (-d VikixServer startOn: PORT secret:
#   ~/.slime-secret), none without the secret or with --port 0, and
#   -vm-display-null with --headless; status and doctor say what's there;
#   uninstall removes the release, the command, the entry and the links, and
#   keeps ~/cuis and the feature. vikix eval --cuis: nothing listening is
#   exit 2, for an agent's expression too (it goes with the door line).
#
#   vikix theme writes the theme as a class for Cuis (cuis.st: VikixTheme's
#   colours, shout's syntax colours, the font's name); run gives the image
#   the file and a test's Swank port; status --json says what is there;
#   desktop refuses while Cuis isn't running; a test's shell without a
#   VIKIX_CUIS_PORT of its own reaches no door (never the live image's).
#
#   With the real release at hand (~/.local/opt/cuis of the user running the
#   test, or VIKIX_CUIS_REAL_BASE): the image is built from it in the test's
#   home (the Vikix font read in when the user has one), started headless
#   with the door on a free port and the theme file, and vikix eval --cuis
#   gets 7 for 3 + 4, an error for 1/0, a value of several lines, is refused
#   with the wrong password and served again with the right one; the image
#   starts in VikixTheme as written, follows vikix theme through the door
#   (vikix-light, then vikix-dark), says so in status --json and the doctor;
#   VikixDesktop, opened by vikix cuis desktop, reads a stand-in Swank
#   (tests/lib/fake-swank.py) once a second, draws the bar's fields, the
#   workspaces and windows, follows a change, and says when nothing
#   answers; it acts: a box dropped on another column sends StumpWM's own
#   move-window-to-group through VikixSwank and the move shows at the next
#   poll, a click on a box focuses its window, a click on a column goes
#   there, and the status line says what was done. The walker: an agent's
#   expression (or anyone's with --door) runs when it only reads, is
#   refused when it names OSProcess, a file class, Socket, Compiler,
#   Smalltalk or thisContext, held when it defines, waits or sends what
#   isn't on the lists, with exit 3 and a notification; an undeclared name
#   or a syntax error is an error; the held ones are listed, run or
#   dropped in the image; a name in ~/.config/vikix/door passes. vikix docs
#   opens a class in a Browser in the image through the door. Then, with
#   Xvfb, xdotool, alacritty and Vikix's StumpWM at hand, the move against
#   a real StumpWM on a hidden screen: a window moved from the image is on
#   the other workspace, and Super+2 shows it there.
#   Without the release that part is skipped, and says so.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY VIKIX_CUIS_PORT VIKIX_CUIS_OPT
here=$(cd "$(dirname "$0")/.." && pwd)
real_base=${VIKIX_CUIS_REAL_BASE:-$HOME/.local/opt/cuis/base}
real_fonts=${VIKIX_FONT_DIR:-$HOME/.local/share/vikix/fonts}   # the user's Vikix font, read only
t=$(mktemp -d)
vm_pid=
swank_pid=
cleanup() {
  # The VM is a child of the squeak wrapper script: ended by its parent, so
  # a test that stops early leaves no image running in the background.
  if [ -n "$vm_pid" ] && kill -0 "$vm_pid" 2>/dev/null; then pkill -P "$vm_pid" 2>/dev/null || true; kill "$vm_pid" 2>/dev/null || true; wait "$vm_pid" 2>/dev/null || true; fi
  if [ -n "$swank_pid" ] && kill -0 "$swank_pid" 2>/dev/null; then kill "$swank_pid" 2>/dev/null || true; wait "$swank_pid" 2>/dev/null || true; fi
  rm -rf "$t"
}
trap cleanup EXIT
real_home=$HOME   # the user's own StumpWM and Quicklisp, for the hidden-screen part
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
unset VIKIX_FONT_DIR
mkdir -p "$HOME" "$t/bin" "$VIKIX_STATE"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
cu() { bash "$here/bin/vikix-cuis" "$@"; }
ev() { VIKIX_EVAL_PARENT=1 python3 "$here/bin/vikix-eval" "$@"; }   # pid 1 above: the user's own, never an agent's
tag=$(sed -n "s/^CUIS_TAG='\(.*\)'$/\1/p" "$here/bin/vikix-cuis")
folder=$(sed -n "s/^CUIS_FOLDER='\(.*\)'.*$/\1/p" "$here/bin/vikix-cuis")
image=$(sed -n 's/^CUIS_IMAGE=\([^ ]*\).*$/\1/p' "$here/bin/vikix-cuis")
sources=$(sed -n 's/^CUIS_SOURCES=\([^ ]*\).*$/\1/p' "$here/bin/vikix-cuis")
opt="$HOME/.local/opt/cuis"; base="$opt/base"; cuis="$HOME/cuis"
apps="$HOME/.local/share/applications"
check "the pin should be read from the script" test -n "$tag" -a -n "$folder" -a -n "$image" -a -n "$sources"

# --- A made-up release: the tag's shape, a VM that is a script -----------------------
mk="$t/release/$folder"
mkdir -p "$mk/CuisVM.app/Contents/Linux-x86_64/lib/squeak/7.0-test-64bit" "$mk/CuisVM.app/Contents/MacOS" \
         "$mk/CuisVM.app/Contents/Windows-x86_64" "$mk/CuisImage/32BitsImage" "$mk/Packages/System" "$mk/CoreUpdates" "$mk/TrueTypeFonts"
# The VM: records its arguments; a build (-s) prints what the real one prints
# and touches the image, as a save does; -version says what the doctor looks for.
cat > "$mk/CuisVM.app/Contents/Linux-x86_64/squeak" <<EOF
#!/bin/sh
echo "squeak \$*" >> "$calls"
case "\$*" in
  *-version*) echo "7.0-test [Production Spur 64-bit x86_64 VM]" ;;
  *" -s "*) script=\$(printf '%s\n' "\$*" | sed 's/.* -s //'); img=\$(printf '%s\n' "\$*" | sed 's/.* \([^ ]*\.image\) .*/\1/')
    cp "\$script" "$t/last-build.st"
    grep -q VikixServer.pck.st "\$script" || { echo "VIKIX-ERROR no VikixServer in the script"; exit 0; }
    [ -e "$t/break-build" ] && { echo "an error"; exit 1; }
    echo "built by the test" >> "\$img"; echo "loaded: #('Network-Kernel' 'VikixServer')" ;;
esac
EOF
printf '#!/bin/sh\n' > "$mk/CuisVM.app/Contents/Linux-x86_64/lib/squeak/7.0-test-64bit/squeak"
chmod +x "$mk/CuisVM.app/Contents/Linux-x86_64/squeak" "$mk/CuisVM.app/Contents/Linux-x86_64/lib/squeak/7.0-test-64bit/squeak"
echo "mac vm" > "$mk/CuisVM.app/Contents/MacOS/Squeak"
echo "windows vm" > "$mk/CuisVM.app/Contents/Windows-x86_64/Squeak.exe"
echo "the base image" > "$mk/CuisImage/$image.image"
echo "the changes" > "$mk/CuisImage/$image.changes"
echo "32 bits" > "$mk/CuisImage/32BitsImage/$image.image"
echo "sources" > "$mk/CuisImage/$sources"
echo "unicode" > "$mk/CuisImage/UnicodeData.txt"
echo "a package" > "$mk/Packages/System/Network-Kernel.pck.st"
echo "an update" > "$mk/CoreUpdates/7977-test.cs.st"
( cd "$t/release" && zip -q -r "$t/cuis.zip" "$folder" )
sha=$(sha256sum "$t/cuis.zip" | cut -d' ' -f1)
# curl: copies the made-up release to where -o says.
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
out=\$(printf '%s\n' "\$*" | sed 's/.* -o \([^ ]*\) .*/\1/')
cp "$t/cuis.zip" "\$out"
EOF
# pactl: no sound server in the test (the launcher asks).
printf '#!/bin/sh\nexit 1\n' > "$t/bin/pactl"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_CURL="$t/bin/curl"

# --- A dry run changes nothing ------------------------------------------------------
DRY_RUN=1 VIKIX_CUIS_SHA256=$sha cu setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run should download nothing" test ! -e "$opt"
check "a dry run should build nothing" test ! -e "$cuis/vikix.image"
check "a dry run should call nothing: $(cat "$calls")" test ! -s "$calls"
check "a dry run shouldn't record the feature" test ! -e "$HOME/.config/vikix/features"
check "a dry run should say what it would do" grep -q "would download Cuis" "$t/out"

# --- A download that isn't what it should be is refused -------------------------------
if VIKIX_CUIS_SHA256=0000000000000000000000000000000000000000000000000000000000000000 cu setup > "$t/out" 2>&1; then
  echo "FAIL: a wrong checksum should refuse the download"; fail=1
fi
check "a wrong checksum should say so" grep -q "checksum doesn't match" "$t/out"
check "a wrong checksum should install nothing" test ! -e "$opt"
check "a wrong checksum should keep no download" test ! -e "$HOME/.cache/vikix/cuis-7.8.zip.part"

# --- setup: the release, the image, the command ---------------------------------------
: > "$calls"
VIKIX_CUIS_SHA256=$sha cu setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup should work"; fail=1; }
check "the release should be in base" test -x "$base/CuisVM.app/Contents/Linux-x86_64/squeak"
check "the pin should be written" test "$(cat "$opt/.vikix-pin")" = "$tag"
check "the other platforms' VMs should be left out" test ! -e "$base/CuisVM.app/Contents/MacOS" -a ! -e "$base/CuisVM.app/Contents/Windows-x86_64"
check "the 32-bit image should be left out" test ! -e "$base/CuisImage/32BitsImage"
check "the packages should be there" test -f "$base/Packages/System/Network-Kernel.pck.st"
check "the download should be gone once unpacked" test ! -e "$HOME/.cache/vikix/cuis-7.8.zip"
check "the cuis folder should link the release's Packages" test "$(readlink "$cuis/Packages")" = "$base/Packages"
check "the cuis folder should link CoreUpdates and TrueTypeFonts" test "$(readlink "$cuis/CoreUpdates")" = "$base/CoreUpdates" -a "$(readlink "$cuis/TrueTypeFonts")" = "$base/TrueTypeFonts"
check "the sources should be beside the image" test "$(readlink "$cuis/$sources")" = "$base/CuisImage/$sources"
check "Vikix's packages should be linked in" test "$(readlink "$cuis/Vikix")" = "$here/cuis"
check "NewPackages, yours, should be made" test -d "$cuis/NewPackages"
check "the image should be built" test -f "$cuis/vikix.image" -a -f "$cuis/vikix.changes"
check "the image should be the build's, not the base copied" grep -q "built by the test" "$cuis/vikix.image"
check "the build folder should be gone" test ! -e "$cuis/.build"
check "the stamp should be written" test -s "$cuis/.vikix-built"
build=$(grep ' -s ' "$calls" | head -n 1)
check "the build should draw nothing: $build" grep -q -- '-vm-display-null' <<<"$build"
check "the build should apply the core updates: $build" grep -q -- ' -u ' <<<"$build"
check "the build should keep Cuis's files in ~/cuis: $build" grep -q -- "-ud $cuis " <<<"$build"
check "the build's log should be kept" grep -q "loaded:" "$VIKIX_STATE/logs/cuis-build.log"
check "setup should say what was loaded" grep -q "VikixServer" "$t/out"
check "the cuis command should be written" test -x "$HOME/.local/bin/cuis"
check "the cuis command should run vikix cuis run" grep -q "vikix cuis run" "$HOME/.local/bin/cuis"
check "the launcher's entry should be written" test -f "$apps/vikix-cuis.desktop"
check "the entry should run the command" grep -q "Exec=$HOME/.local/bin/cuis" "$apps/vikix-cuis.desktop"
check "setup should record the feature" grep -qx cuis "$HOME/.config/vikix/features"
check "setup should ask for no sudo" test -z "$(grep sudo "$calls" || true)"

# --- A second setup downloads and builds nothing --------------------------------------
: > "$calls"
VIKIX_CUIS_SHA256=$sha cu setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a second setup should work"; fail=1; }
check "a second setup should download nothing: $(cat "$calls")" test -z "$(grep curl "$calls" || true)"
check "a second setup should build nothing: $(cat "$calls")" test -z "$(grep ' -s ' "$calls" || true)"
check "a second setup should say the image is built" grep -q "built with Vikix's packages" "$t/out"

# --- Vikix's packages changed: the image is built again ---------------------------------
echo stale > "$cuis/.vikix-built"
: > "$calls"
VIKIX_CUIS_SHA256=$sha cu setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup after a change should work"; fail=1; }
check "a changed stamp should build again" grep -q ' -s ' "$calls"
check "the stamp should be fresh again" test "$(cat "$cuis/.vikix-built")" != stale
# A build that fails leaves the image that was there.
echo "the old image" > "$cuis/vikix.image"
touch "$t/break-build"
if cu rebuild > "$t/out" 2>&1; then echo "FAIL: a failed build should say so"; fail=1; fi
check "a failed build should say where the log is" grep -q "cuis-build.log" "$t/out"
check "a failed build should leave the image that was there" test "$(cat "$cuis/vikix.image")" = "the old image"
check "a failed build should leave no build folder" test ! -e "$cuis/.build"
rm -f "$t/break-build"
cu rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: rebuild should work"; fail=1; }
check "rebuild should build" grep -q "built by the test" "$cuis/vikix.image"

# --- run: the image, Cuis's files in ~/cuis, the door ----------------------------------
: > "$calls"
cu run > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: run should work"; fail=1; }
launch=$(tail -n 1 "$calls")
check "run should open your image: $launch" grep -q -- "$cuis/vikix.image" <<<"$launch"
check "run should keep Cuis's files in ~/cuis: $launch" grep -q -- "-ud $cuis" <<<"$launch"
check "run should not apply updates: $launch" test -z "$(grep -- ' -u ' <<<"$launch" || true)"
check "without ~/.slime-secret there should be no door: $launch" test -z "$(grep VikixServer <<<"$launch" || true)"
check "run should draw (no -vm-display-null): $launch" test -z "$(grep -- '-vm-display-null' <<<"$launch" || true)"
( umask 077; echo "a-secret-for-the-test" > "$HOME/.slime-secret" )
: > "$calls"
cu run --headless -s quit.st > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: run --headless should work"; fail=1; }
launch=$(tail -n 1 "$calls")
check "with the secret the door should open: $launch" grep -q -- "-d VikixServer startOn: 4005 secret: '$HOME/.slime-secret'" <<<"$launch"
check "and the image get your names file for the walker: $launch" grep -q -- "-d VikixServer userNamesPath: '$HOME/.config/vikix/door'" <<<"$launch"
check "--headless should draw nothing: $launch" grep -q -- '-vm-display-null' <<<"$launch"
check "the script should be passed on: $launch" grep -q -- '-s quit.st' <<<"$launch"
: > "$calls"
VIKIX_CUIS_PORT=4100 cu run > /dev/null 2>&1
check "VIKIX_CUIS_PORT should name the door's port" grep -q "startOn: 4100 " "$calls"
: > "$calls"
cu run --port 4200 > /dev/null 2>&1
check "--port should name the door's port" grep -q "startOn: 4200 " "$calls"
: > "$calls"
cu run --port 0 > /dev/null 2>&1
check "--port 0 should open no door: $(cat "$calls")" test -z "$(grep VikixServer "$calls" || true)"
if cu run --port x > "$t/out" 2>&1; then echo "FAIL: a port that isn't a number should be refused"; fail=1; fi

# --- status and doctor ----------------------------------------------------------------
cu status > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: status should work"; fail=1; }
check "status should name the release" grep -q "Cuis 7.8 at Vikix's pin" "$t/out"
check "status should name the image and its packages" grep -q "built with Vikix's packages: VikixDesktop VikixLessons VikixServer VikixTheme" "$t/out"
check "status should say Cuis isn't running" grep -q "running   no" "$t/out"
cu doctor > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the doctor should pass"; fail=1; }
check "the doctor should see the VM run" grep -q "the Cuis VM runs" "$t/out"
check "the doctor should see the image" grep -q "your image is built" "$t/out"
check "the doctor should see the command" grep -q "cuis is the command" "$t/out"
check "the doctor should say the door opens with Cuis" grep -q "the door opens with it" "$t/out"
echo stale > "$cuis/.vikix-built"
if cu doctor > "$t/out" 2>&1; then echo "FAIL: the doctor should fail on an image built before the packages changed"; fail=1; fi
check "the doctor should ask for a rebuild" grep -q "vikix cuis rebuild" "$t/out"
cu rebuild > /dev/null 2>&1

# --- The theme as a class for Cuis, the file given at launch, status --json, desktop ----
theme_st="$HOME/.config/vikix/theme/cuis.st"
DISPLAY='' bash "$here/bin/vikix-theme" vikix-light > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: vikix theme should work"; fail=1; }
check "vikix theme should write the theme as a class for Cuis" test -f "$theme_st"
check "the class should get the background" grep -q -A1 '^background$' "$theme_st"
check "the background should be vikix-light's" grep -q "fromHexString: '#eff1f5'" "$theme_st"
check "every colour should be a method of VikixTheme" test "$(grep -c "^!VikixTheme methodsFor: 'colors'!" "$theme_st")" -ge 20
check "the syntax colours should be there" grep -q "#comment -> '#636679'" "$theme_st"
check "the font's name should be there (the stand-in's, with no Iosevka in this home)" grep -q -A1 '^fontFamilyName$' "$theme_st"
check "the selection colour should be the window colour" grep -q -A1 '^defaultWindowColor$' "$theme_st"
check "nothing in the file should run as a doIt but the heading" test "$(grep -c '^!' "$theme_st")" = "$(grep -c "^!VikixTheme methodsFor:" "$theme_st")"
: > "$calls"
cu run > /dev/null 2>&1
launch=$(tail -n 1 "$calls")
check "run should give the image the theme file: $launch" grep -q -- "-d VikixTheme loadFrom: '$theme_st'" <<<"$launch"
check "run should give the image a test's Swank port: $launch" grep -q -- "-d VikixSwank port: 9" <<<"$launch"
: > "$calls"
cu rebuild > /dev/null 2>&1
check "the build should read the Vikix font into the image" grep -q "loadFont: '$HOME/.local/share/vikix/fonts'" "$t/last-build.st"
check "the build should give the image the theme as written" grep -q "loadFrom: '$theme_st'" "$t/last-build.st"
check "the door should load first, since the others require it: $(grep -n 'Feature require' "$t/last-build.st" | head -n 1)" bash -c "grep 'Feature require' '$t/last-build.st' | head -n 1 | grep -q VikixServer.pck.st"
cu status --json > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: status --json should work"; fail=1; }
check "status --json should be JSON saying what is there: $(head -c 200 "$t/out")" python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d["installed"] and d["built"] and not d["running"] and d["door"] is None
assert d["packages"] == ["VikixDesktop", "VikixLessons", "VikixServer", "VikixTheme"], d["packages"]
assert d["theme_file"].endswith("/cuis.st") and d["image_state"] is None
' "$t/out"
if cu desktop > "$t/out" 2>&1; then echo "FAIL: desktop while Cuis isn't running should be refused"; fail=1; fi
check "desktop should say Cuis isn't running" grep -q "Cuis isn't running" "$t/out"
if cu lessons > "$t/out" 2>&1; then echo "FAIL: lessons while Cuis isn't running should be refused"; fail=1; fi
check "lessons should say Cuis isn't running" grep -q "Cuis isn't running" "$t/out"

# --- vikix eval --cuis without Cuis, and from an agent -----------------------------------
# A test's shell (VIKIX_SWANK_PORT=9) that names no Cuis port of its own
# reaches no door: never the live image's.
if ev --cuis '3 + 4' > "$t/out" 2>&1; then echo "FAIL: a test without a Cuis port of its own should reach no door"; fail=1; fi
check "a test without VIKIX_CUIS_PORT should be told why" grep -q "names a test's desktop (9)" "$t/out"
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
if VIKIX_CUIS_PORT=$port ev --cuis '3 + 4' > "$t/out" 2>&1; then echo "FAIL: nothing listening should be exit 2"; fail=1; fi
check "nothing listening should say so" grep -q "nothing is listening on 127.0.0.1:$port" "$t/out"
if ev --cuis > "$t/out" 2>&1 < /dev/null; then echo "FAIL: no Smalltalk should be refused"; fail=1; fi
check "no Smalltalk should say so" grep -q "no Smalltalk to run" "$t/out"
# An agent above the shell: its expression goes with the door line, so with
# nothing listening it is exit 2 like anyone's (the walker is the image's).
mkdir -p "$t/proc/4242"
printf 'claude\0--resume\0' > "$t/proc/4242/cmdline"
echo "4242 (claude) S 1 4242 4242 0 -1" > "$t/proc/4242/stat"
status=0
VIKIX_PROC="$t/proc" VIKIX_EVAL_PARENT=4242 VIKIX_CUIS_PORT=$port python3 "$here/bin/vikix-eval" --cuis '3 + 4' > "$t/out" 2>&1 || status=$?
check "an agent's Smalltalk with nothing listening should be exit 2 (was $status)" test "$status" = 2
agent_ev() { VIKIX_PROC="$t/proc" VIKIX_EVAL_PARENT=4242 python3 "$here/bin/vikix-eval" "$@"; }   # claude 4242 above the shell

# --- uninstall: the release, the command and the entry go; ~/cuis stays -------------------
echo "mine" > "$cuis/NewPackages/Mine.pck.st"
cu uninstall > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: uninstall should work"; fail=1; }
check "the release should be gone" test ! -e "$opt"
check "the command should be gone" test ! -e "$HOME/.local/bin/cuis"
check "the entry should be gone" test ! -e "$apps/vikix-cuis.desktop"
check "the links into the release should be gone" test ! -L "$cuis/Packages" -a ! -L "$cuis/Vikix" -a ! -L "$cuis/$sources"
check "your packages should stay" test -f "$cuis/NewPackages/Mine.pck.st"
check "your image should stay" test -f "$cuis/vikix.image"
check "uninstall should keep the feature (vikix remove cuis takes it)" grep -qx cuis "$HOME/.config/vikix/features"
printf '#!/bin/sh\n' > "$HOME/.local/bin/cuis"; chmod +x "$HOME/.local/bin/cuis"
cu uninstall > /dev/null 2>&1 || true
check "a cuis command of your own should stay" test -e "$HOME/.local/bin/cuis"
rm -f "$HOME/.local/bin/cuis"
DRY_RUN=1 cu setup > "$t/out" 2>&1 || true
check "a dry run after uninstall should install nothing" test ! -e "$opt"

# --- The real release, when it is at hand: the image, the door, vikix eval --cuis -----------
if [ -x "$real_base/CuisVM.app/Contents/Linux-x86_64/squeak" ] && [ -f "$real_base/CuisImage/$image.image" ]; then
  export VIKIX_CUIS_OPT="$t/real-opt"
  mkdir -p "$VIKIX_CUIS_OPT"
  ln -s "$real_base" "$VIKIX_CUIS_OPT/base"
  echo "$tag" > "$VIKIX_CUIS_OPT/.vikix-pin"
  rm -rf "$cuis"
  export PATH="${PATH#"$t/bin:"}"   # the real VM, not the script
  rm -f "$theme_st"
  if [ -f "$real_fonts/wm.ttf" ]; then export VIKIX_FONT_DIR="$real_fonts"; fi
  cu rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the real image should build"; fail=1; }
  check "the real build should load the door, the theme, the desktop and the lessons" grep -q "'VikixDesktop' 'VikixLessons' 'VikixServer' 'VikixTheme'" "$t/out"
  check "the real image should be there" test -s "$cuis/vikix.image"
  if [ -f "$real_fonts/wm.ttf" ]; then
    check "the real build should read the Vikix font in: $(grep '^font:' "$VIKIX_STATE/logs/cuis-build.log")" grep -q "^font: #('" "$VIKIX_STATE/logs/cuis-build.log"
  else
    echo "note: no Vikix font at $real_fonts: the image was built without it"
  fi
  port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  swank_port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  ( umask 077; echo "the-real-secret" > "$HOME/.slime-secret" )
  # The theme written before the image starts: it is read at launch.
  DISPLAY='' VIKIX_CUIS_PORT=$port bash "$here/bin/vikix-theme" vikix-light > /dev/null 2>&1 || { echo "FAIL: vikix theme with no Cuis running should still work"; fail=1; }
  # A stand-in for StumpWM's Swank, for VikixDesktop.
  cat > "$t/desktop.json" <<'EOF'
{"workspaces":[{"name":"main","number":1,"current":true,"kind":"tiles","strip":null,"windows":[{"number":0,"title":"Vikix — Firefox","class":"firefox","focused":true},{"number":1,"title":"~ : bash","class":"Alacritty","focused":false}]},{"name":"notes","number":2,"current":false,"kind":"strip","strip":{"columns":[]},"windows":[{"number":2,"title":"notes.org","class":"Emacs","focused":false}]}],"screens":[{"number":0,"x":0,"y":0,"width":1920,"height":1080}],"bar":[{"field":"battery","shows":"84%"},{"field":"clock","shows":"Fri 10 Oct 19:30"}]}
EOF
  : > "$t/swank.log"
  python3 "$here/tests/lib/fake-swank.py" "$swank_port" the-real-secret "$t/desktop.json" "$t/swank.log" &
  swank_pid=$!
  VIKIX_SWANK_PORT=$swank_port cu run --headless --port "$port" > "$t/vm.log" 2>&1 &
  vm_pid=$!
  for _ in $(seq 1 50); do
    python3 -c "import socket,sys; s=socket.socket(); s.settimeout(0.2); sys.exit(0 if s.connect_ex(('127.0.0.1', $port)) == 0 else 1)" 2>/dev/null && break
    sleep 0.2
  done
  export VIKIX_CUIS_PORT=$port
  status=0; ev --cuis '3 + 4' > "$t/out" 2>&1 || status=$?
  check "3 + 4 should be 7 (exit $status): $(cat "$t/out")" test "$status" = 0 -a "$(cat "$t/out")" = "=> 7"
  status=0; ev --cuis '1 / 0' > "$t/out" 2>&1 || status=$?
  check "1 / 0 should be an error (exit $status): $(cat "$t/out")" test "$status" = 1
  check "the error should be named" grep -q "^error: ZeroDivide" "$t/out"
  ev --cuis "'a' , 'é'" > "$t/out" 2>&1 || true
  check "a value with a letter past ASCII should come as UTF-8: $(cat "$t/out")" test "$(cat "$t/out")" = "=> 'aé'"
  printf "| s |\ns := 'one'.\ns , String newLineString , '.two'" | ev --cuis > "$t/out" 2>&1 || true
  check "lines in, lines out, a dot kept: $(cat "$t/out")" test "$(cat "$t/out")" = "=> 'one
.two'"
  check "the doctor should see the door answer" bash -c "cu() { bash '$here/bin/vikix-cuis' \"\$@\"; }; cu doctor 2>&1 | grep -q 'the door answers on 127.0.0.1:$port'"
  # The image reads the secret file at each client; a client with another
  # home sends another secret.
  mkdir -p "$t/other"
  ( umask 077; echo "not-the-secret" > "$t/other/.slime-secret" )
  if HOME="$t/other" ev --cuis '3 + 4' > "$t/out" 2>&1; then echo "FAIL: the wrong password should be refused"; fail=1; fi
  check "the wrong password should be said" grep -q "password" "$t/out"
  ev --cuis '6 * 7' > "$t/out" 2>&1 || true
  check "the right password should be served after a wrong one: $(cat "$t/out")" test "$(cat "$t/out")" = "=> 42"

  # The theme: read at launch, then followed through the door.
  check "the image should start in VikixTheme, read from the file at launch: $(ev --cuis 'Theme current class name' 2>&1)" test "$(ev --cuis 'Theme current class name' 2>&1)" = "=> #VikixTheme"
  check "the background should be vikix-light's: $(ev --cuis 'Theme current background printString' 2>&1)" grep -q "r: 0.937 g: 0.945 b: 0.961" <<<"$(ev --cuis 'Theme current background printString' 2>&1)"
  if [ -f "$real_fonts/wm.ttf" ]; then
    check "the font should be the Vikix font: $(ev --cuis 'FontFamily defaultFamilyName' 2>&1)" test "$(ev --cuis 'FontFamily defaultFamilyName' 2>&1)" = "=> '$("$here/bin/vikix-font" --family)'"
  fi
  DISPLAY='' VIKIX_CUIS_PORT=$port bash "$here/bin/vikix-theme" vikix-dark > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: vikix theme vikix-dark should work"; fail=1; }
  check "the running image should follow vikix theme vikix-dark: $(ev --cuis 'Theme current background printString' 2>&1)" grep -q "r: 0.118 g: 0.118 b: 0.18" <<<"$(ev --cuis 'Theme current background printString' 2>&1)"
  check "VikixTheme's package should stay clean after the file-in" test "$(ev --cuis "(CodePackage named: 'VikixTheme' createIfAbsent: false registerIfNew: false) hasUnsavedChanges" 2>&1)" = "=> false"
  check "the doctor should see the theme is Vikix's" bash -c "cu() { bash '$here/bin/vikix-cuis' \"\$@\"; }; cu doctor 2>&1 | grep -q \"the image's theme is Vikix's\""
  cu status --json > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: status --json with the image running should work"; fail=1; }
  check "status --json should say what the image shows: $(head -c 300 "$t/out")" python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d["running"] and d["door"] == int(sys.argv[2]), (d["running"], d["door"])
st = d["image_state"]
assert st["theme"] == "VikixTheme" and "VikixDesktop" in st["packages"] and st["door"] == sys.argv[2], st
assert isinstance(st["windows"], list) and st["font"], st
' "$t/out" "$port"

  # The desktop as objects, against the stand-in Swank.
  cu desktop > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: vikix cuis desktop should open the window"; fail=1; }
  check "desktop should say it opened" grep -q "open in Cuis" "$t/out"
  for _ in $(seq 1 40); do grep -q "workspace 2 notes" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
  check "the workspaces should be drawn, the one in view said: $summary" grep -q "workspace 1 main here tiles" <<<"$summary"
  check "the windows should be drawn under their workspace, the focused one said: $summary" grep -q "window 0 firefox: Vikix — Firefox focused" <<<"$summary"
  check "a strip should be said: $summary" grep -q "workspace 2 notes strip" <<<"$summary"
  check "the window should say where it reads from: $summary" grep -q "StumpWM on 127.0.0.1:$swank_port, read every second" <<<"$summary"
  check "the bar's fields should be along the top: $summary" grep -q "bar battery 84%  ·  clock Fri 10 Oct 19:30" <<<"$summary"
  check "status --json should list the desktop window" bash -c "cu() { bash '$here/bin/vikix-cuis' \"\$@\"; }; cu status --json | grep -q '\"class\": \"VikixDesktopWindow\"'"
  # The desktop changes: the morphs follow, kept by number (a halo on one stays).
  sed -i 's/"notes.org"/"todo.org"/; s/"focused":true/"focused":false/; s/"~ : bash","class":"Alacritty","focused":false/"~ : bash","class":"Alacritty","focused":true/' "$t/desktop.json"
  for _ in $(seq 1 40); do grep -q "todo.org" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
  check "a changed title and focus should follow: $summary" grep -q "window 1 Alacritty: ~ : bash focused" <<<"$summary"
  check "the same morph should be kept for a window: $(ev --cuis 'VikixDesktop window summary' 2>&1 | head -c 100)" test "$(ev --cuis '(VikixDesktop window allMorphsDo: [ :m | ]; yourself) class name' 2>&1)" = "=> #VikixDesktopWindow"
  python3 - "$t/desktop.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1])); d["workspaces"] = d["workspaces"][:1]; json.dump(d, open(sys.argv[1], "w"))
EOF
  for _ in $(seq 1 40); do grep -q "workspace 2" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" || break; sleep 0.25; done
  check "a workspace gone should be taken down: $(ev --cuis 'VikixDesktop summary' 2>&1)" test -z "$(grep 'workspace 2' <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" || true)"
  check "the image should have asked once a second, with the password: $(wc -l < "$t/swank.log")" test "$(wc -l < "$t/swank.log")" -ge 3
  check "every ask should be the one function, through vikix-eval-for-agent" test -z "$(grep -v 'vikix-eval-for-agent.*vikix-desktop-json' "$t/swank.log" || true)"

  # The desktop acts, each through VikixSwank as the reads go, and shows at
  # the next poll: a box dropped on another column moves the real window
  # (the stand-in moves it in desktop.json as StumpWM would), a click on a
  # box focuses its window, a click on a column goes there; the status line
  # says what was done; a drop on the box's own column sends nothing.
  python3 - "$t/desktop.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["workspaces"].append({"name": "notes", "number": 2, "current": False, "kind": "tiles", "strip": None,
                        "windows": [{"number": 2, "title": "notes.org", "class": "Emacs", "focused": False}]})
json.dump(d, open(sys.argv[1], "w"))
EOF
  for _ in $(seq 1 40); do grep -q "workspace 2" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  ev --cuis '(VikixDesktop window workspaceNumbered: 2) acceptDroppingMorph: (VikixDesktop window windowNumbered: 1 on: 1) event: nil' > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a drop on a column should be taken"; fail=1; }
  for _ in $(seq 1 40); do grep -q "moved window 1 to notes" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
  check "the status line should say what was done: $summary" grep -q "moved window 1 to notes" <<<"$summary"
  check "the moved window should show under the other workspace at the next poll, not before: $summary" python3 -c '
import sys
lines = sys.argv[1].splitlines()
two = lines.index(next(l for l in lines if l.startswith("workspace 2")))
assert any("window 1 Alacritty" in l for l in lines[two:]), "not under workspace 2"
assert not any("window 1 Alacritty" in l for l in lines[:two]), "still under workspace 1"
' "$summary"
  check "the move should be StumpWM's own move-window-to-group, through vikix-eval-for-agent, naming both workspaces and the number" grep -q 'vikix-eval-for-agent.*main.*notes.*move-window-to-group' "$t/swank.log"
  check "a move should wait for the poll: the swank log has a read of the desktop after the move" bash -c "grep -n 'move-window-to-group\|vikix-desktop-json' '$t/swank.log' | grep -A1 move-window | tail -1 | grep -q vikix-desktop-json"
  ev --cuis '(VikixDesktop window windowNumbered: 2 on: 2) click: nil localPosition: nil' > /dev/null 2>&1 || { echo "FAIL: a click on a box should be taken"; fail=1; }
  for _ in $(seq 1 40); do grep -q "window 2 Emacs: notes.org focused" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
  check "a click on a box should give its window the focus, its workspace in view: $summary" bash -c "grep -q 'window 2 Emacs: notes.org focused' <<<\"\$1\" && grep -q 'workspace 2 notes here' <<<\"\$1\" && grep -q 'window 2 on notes has the focus' <<<\"\$1\"" _ "$summary"
  check "the focus should be StumpWM's own focus-all" grep -q 'vikix-eval-for-agent.*switch-to-group g) (focus-all w)' "$t/swank.log"
  ev --cuis '(VikixDesktop window workspaceNumbered: 1) click: nil localPosition: nil' > /dev/null 2>&1 || { echo "FAIL: a click on a column should be taken"; fail=1; }
  for _ in $(seq 1 40); do grep -q "workspace 1 main here" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
  check "a click on a column should go to that workspace: $summary" bash -c "grep -q 'workspace 1 main here' <<<\"\$1\" && grep -q 'on workspace main' <<<\"\$1\"" _ "$summary"
  acts=$(grep -c 'move-window-to-group\|focus-all\|switch-to-group' "$t/swank.log")
  ev --cuis '(VikixDesktop window workspaceNumbered: 1) acceptDroppingMorph: (VikixDesktop window windowNumbered: 0 on: 1) event: nil' > /dev/null 2>&1 || true
  sleep 1
  check "a drop on the box's own column should send nothing ($acts acts before, $(grep -c 'move-window-to-group\|focus-all\|switch-to-group' "$t/swank.log") after)" test "$(grep -c 'move-window-to-group\|focus-all\|switch-to-group' "$t/swank.log")" = "$acts"
  check "the boxes should still be drawn as the desktop says after the drops: $(ev --cuis 'VikixDesktop summary' 2>&1)" grep -q 'window 0 firefox' <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)"

  # The walker: an agent's expression through the door. A read runs; what
  # reaches a program, a file, a socket, the compiler or the system is
  # refused; what defines, waits or isn't on the lists is held; each held one
  # is exit 3 with a notification, kept in the image, listed, run or dropped
  # there; an undeclared name or a syntax error is an error, not a hold.
  mkdir -p "$t/nbin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$@" > %s/notified\n' "$t" > "$t/nbin/notify-send"; chmod +x "$t/nbin/notify-send"
  export PATH="$t/nbin:$PATH"
  status=0; agent_ev --cuis '3 + 4' > "$t/out" 2>&1 || status=$?
  check "an agent's read should run (exit $status): $(cat "$t/out")" test "$status" = 0 -a "$(cat "$t/out")" = "=> 7"
  status=0; agent_ev --cuis 'VikixDesktop summary' > "$t/out" 2>&1 || status=$?
  check "an agent may read the desktop window (exit $status): $(head -c 100 "$t/out")" test "$status" = 0
  rm -f "$t/notified"
  status=0; agent_ev --cuis 'Smalltalk quit' > "$t/out" 2>&1 || status=$?
  check "Smalltalk quit from an agent should be held (exit $status): $(cat "$t/out")" test "$status" = 3
  check "and said why: $(cat "$t/out")" grep -q "it names Smalltalk, which reaches the system" "$t/out"
  check "and not run: the image should live on" kill -0 "$vm_pid"
  check "and the desktop told: $(cat "$t/notified" 2>/dev/null)" grep -q "claude 4242 sent Smalltalk the door held" "$t/notified"
  walk() { local status=0; agent_ev --cuis "$1" > "$t/out" 2>&1 || status=$?; echo "$status $(head -1 "$t/out")"; }
  check "OSProcess should be refused by name, though the image has no such class: $(walk "OSProcess command: 'ls'")" grep -q "^3 .*it names OSProcess, which runs a program" <<<"$(walk "OSProcess command: 'ls'")"
  check "a file should be refused: $(walk "'/etc/passwd' asFileEntry fileContents")" grep -q "^3 .*which touches a file" <<<"$(walk "'/etc/passwd' asFileEntry fileContents")"
  check "a file class too: $(walk "FileEntry withAbsolutePathName: '/x'")" grep -q "^3 .*it names FileEntry, which touches a file" <<<"$(walk "FileEntry withAbsolutePathName: '/x'")"
  check "a socket should be refused: $(walk "Socket newTCP")" grep -q "^3 .*it names Socket, which reaches the system" <<<"$(walk "Socket newTCP")"
  check "the compiler should be refused: $(walk "Compiler evaluate: '1'")" grep -q "^3 .*Compiler, which runs Smalltalk the door can't see" <<<"$(walk "Compiler evaluate: '1'")"
  check "perform: should be refused: $(walk "3 perform: #quit")" grep -q "^3 .*it sends perform:, which runs Smalltalk" <<<"$(walk "3 perform: #quit")"
  check "thisContext should be refused: $(walk "thisContext sender")" grep -q "^3 .*it names thisContext, which reaches the system" <<<"$(walk "thisContext sender")"
  check "VikixSwank eval: should be refused (Lisp past the Lisp door): $(walk "VikixSwank eval: '(quit)'")" grep -q "^3 .*it sends eval:, which runs Smalltalk" <<<"$(walk "VikixSwank eval: '(quit)'")"
  check "defining a class should be held: $(walk "Object subclass: #Foo instanceVariableNames: '' classVariableNames: '' poolDictionaries: '' category: 'x'")" grep -q "^3 .*which defines or changes code" <<<"$(walk "Object subclass: #Foo instanceVariableNames: '' classVariableNames: '' poolDictionaries: '' category: 'x'")"
  check "compiling a method should be held: $(walk "Object compile: 'foo ^ 1'")" grep -q "^3 .*it sends compile:, which defines or changes code" <<<"$(walk "Object compile: 'foo ^ 1'")"
  check "a wait should be held: $(walk "(Delay forSeconds: 1) wait")" grep -q "^3 .*which waits, holding the image" <<<"$(walk "(Delay forSeconds: 1) wait")"
  check "setting a global should be held: $(walk "Transcript := 3")" grep -q "^3 .*it sets Transcript, which is a global" <<<"$(walk "Transcript := 3")"
  check "a message off the lists should be held: $(walk "Object frobnicate")" grep -q "^3 .*it sends frobnicate, which isn't on the door's list" <<<"$(walk "Object frobnicate")"
  check "an undeclared name should be an error, not a hold: $(walk "zork + 1")" grep -q "^1 error: nothing declares zork" <<<"$(walk "zork + 1")"
  check "a syntax error should be an error: $(walk "3 +")" grep -q "^1 error: " <<<"$(walk "3 +")"
  check "a temporary of its own may be set: $(walk "| a | a := 3. a * 2")" grep -q "^0 => 6" <<<"$(walk "| a | a := 3. a * 2")"
  check "a block and a cascade are walked through: $(walk "Transcript show: 'x'; newLine. #(1 2) collect: [ :x | x * 2 ]")" grep -q "^0 => #(2 4)" <<<"$(walk "Transcript show: 'x'; newLine. #(1 2) collect: [ :x | x * 2 ]")"
  check "the acts of VikixDesktop may be sent: $(walk "VikixDesktop window model switchTo: 'main'")" grep -q "^0 " <<<"$(walk "VikixDesktop window model switchTo: 'main'")"
  held=$(ev --cuis 'VikixServer held' 2>&1)
  check "the held ones should be listed, with who, when and why: $(head -3 <<<"$held")" bash -c "grep -q 'claude 4242  [0-9][0-9]:[0-9][0-9]' <<<\"\$1\" && grep -q 'Smalltalk quit' <<<\"\$1\" && grep -q 'it names Smalltalk, which reaches the system' <<<\"\$1\"" _ "$held"
  check "the same text again should take the old one's place, and ten at most be kept: $(ev --cuis 'VikixServer heldCount' 2>&1)" test "$(ev --cuis 'VikixServer heldCount' 2>&1)" = "=> 10"
  n=$(sed -n "s/^=> '\([0-9]*\)  claude 4242.*/\1/p" <<<"$held" | head -1)
  check "state should count them for status --json: $(ev --cuis 'VikixServer state' 2>&1 | grep held)" grep -q "held	10" <<<"$(ev --cuis 'VikixServer state' 2>&1)"
  check "status --json should say how many the door holds" bash -c "cu() { bash '$here/bin/vikix-cuis' \"\$@\"; }; cu status --json | grep -q '\"held\": \"10\"'"
  walk "| a | a := 3. a frobnicate" > /dev/null
  check "the door full should say so, and not keep the eleventh: $(head -1 "$t/out")" grep -q "holds ten expressions already" "$t/out"
  check "dropping one should forget it ($n): $(ev --cuis "VikixServer dropHeld: $n" 2>&1)" test "$(ev --cuis 'VikixServer heldCount' 2>&1)" = "=> 9"
  walk "(Delay forMilliseconds: 1) wait" > /dev/null   # room for one again: kept
  wait_n=$(ev --cuis 'VikixServer held' 2>&1 | grep -B1 'forMilliseconds' | grep -o '[0-9]*  claude' | head -1 | cut -d' ' -f1 || true)
  check "with room again the next one should be kept ($wait_n)" test -n "$wait_n" -a "$(ev --cuis 'VikixServer heldCount' 2>&1)" = "=> 10"
  ran=$(ev --cuis "VikixServer runHeld: $wait_n" 2>&1)
  check "running a held one as yourself should run it and forget it (held $wait_n): $ran" grep -q "=> 'a Delay" <<<"$ran"
  check "and it should be gone" test "$(ev --cuis 'VikixServer heldCount' 2>&1)" = "=> 9"
  check "running one that isn't there should say so" grep -q "holds no expression 999" <<<"$(ev --cuis 'VikixServer runHeld: 999' 2>&1)"
  mkdir -p "$HOME/.config/vikix"; echo "frobnicate   # a name of my own" > "$HOME/.config/vikix/door"
  ev --cuis "VikixServer userNamesPath: '$HOME/.config/vikix/door'" > /dev/null 2>&1
  check "a name in your file should pass the walker (then fail as itself): $(walk "Object frobnicate")" grep -q "^1 error: MessageNotUnderstood" <<<"$(walk "Object frobnicate")"
  check "anyone's expression with --door is walked too: $(ev --cuis --door 'Smalltalk quit' 2>&1 | head -1)" grep -q "the door held it" <<<"$(ev --cuis --door 'Smalltalk quit' 2>&1)"
  check "the image should live on through all of it" kill -0 "$vm_pid"

  # The lessons: opened by vikix cuis lessons at the first not done; the
  # code tried in the image as a Workspace would (a class defined is really
  # there, under a change set of the lessons' own, so no dialog), the lesson
  # ticked when its check is met, a wrong answer, a slip of the keys, text
  # that isn't Smalltalk and an error each said; done stays done in the
  # image; reset starts over.
  cu lessons > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: vikix cuis lessons should open the window"; fail=1; }
  check "lessons should say they opened" grep -q "open in Cuis" "$t/out"
  lesson() { ev --cuis "VikixLessons window model $1" 2>&1; }
  check "the lessons should be listed, none done, the first on: $(ev --cuis 'VikixLessons summary' 2>&1 | head -2)" grep -q "^=> '\[ \] 1 Numbers  <- here" <<<"$(ev --cuis 'VikixLessons summary' 2>&1)"
  check "a wrong answer should be said, with the hint offered: $(lesson "try: '3 + 5'")" grep -q "answered 8, which isn..t it yet" <<<"$(lesson "try: '3 + 5'")"
  check "a slip of the keys should be said as one: $(lesson "try: 'zork + 1'")" grep -q "know the name zork" <<<"$(lesson "try: 'zork + 1'")"
  check "text that isn't Smalltalk should be said as such: $(lesson "try: '3 +'")" grep -q "Smalltalk the image can read" <<<"$(lesson "try: '3 +'")"
  check "an error should be said: $(lesson "try: '1 / 0'")" grep -q "stopped with an error: ZeroDivide" <<<"$(lesson "try: '1 / 0'")"
  check "the hint: $(lesson "hint; result")" grep -q "Hint: Just the three characters" <<<"$(lesson "hint; result")"
  check "the right answer should tick the lesson and offer Next: $(lesson "try: '3 + 4'")" grep -q "Done! Next takes you to lesson 2" <<<"$(lesson "try: '3 + 4'")"
  check "the list should show the tick, the lesson still on: $(ev --cuis 'VikixLessons summary' 2>&1 | head -2)" grep -q "^=> '\[x\] 1 Numbers  <- here" <<<"$(ev --cuis 'VikixLessons summary' 2>&1)"
  lesson "next; try: '''hello'' reversed'" > /dev/null
  lesson "next; try: '#(1 2 3) collect: [ :n | n * 2 ]'" > /dev/null
  check "a class defined in a lesson is really in the image: $(lesson "index: 5; try: 'Object subclass: #Dog instanceVariableNames: '''' classVariableNames: '''' poolDictionaries: '''' category: ''Lessons'''")" test "$(ev --cuis '(Smalltalk includesKey: #Dog) printString' 2>&1)" = "=> 'true'"
  check "a method taught in a lesson answers: $(lesson "next; try: 'Dog compile: ''bark ^ ''''Woof!'''''''")" test "$(ev --cuis 'Dog new bark' 2>&1)" = "=> 'Woof!'"
  check "the last lesson opens the desktop as objects: $(lesson "index: 8; try: 'VikixDesktop open'")" grep -q "That was the last lesson" <<<"$(lesson "result")"
  check "done should be kept in the image: $(ev --cuis 'VikixLessons done asSortedCollection asArray' 2>&1)" test "$(ev --cuis 'VikixLessons done asSortedCollection asArray' 2>&1)" = "=> #(1 2 3 5 6 8)"
  check "a lesson's window is a window in status --json" bash -c "cu() { bash '$here/bin/vikix-cuis' \"\$@\"; }; cu status --json | grep -q '\"class\": \"VikixLessonsWindow\"'"
  ev --cuis 'VikixLessons reset' > /dev/null 2>&1
  check "reset should undo them all: $(ev --cuis 'VikixLessons done size' 2>&1)" test "$(ev --cuis 'VikixLessons done size' 2>&1)" = "=> 0"
  check "the image should still live" kill -0 "$vm_pid"

  # The docs adapter through the door: a class opened as a Browser in the image.
  VIKIX_DOCS_SOURCES="" VIKIX_DIR="$here" VIKIX_DOCS_CUIS="$HOME/cuis" python3 "$here/bin/vikix-docs" index --quiet
  VIKIX_DOCS_SOURCES="" VIKIX_DIR="$here" VIKIX_DOCS_CUIS="$HOME/cuis" python3 "$here/bin/vikix-docs" open "cuis:$here/cuis/VikixDesktop.pck.st#VikixSwank" > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: vikix docs open of a class should work with the image running"; fail=1; }
  check "a hit opened should be a Browser on the class in the image: $(ev --cuis 'VikixServer state' 2>&1 | grep window)" grep -q "window	BrowserWindow	.*VikixSwank" <<<"$(ev --cuis 'VikixServer state' 2>&1)"
  kill "$swank_pid" 2>/dev/null || true; wait "$swank_pid" 2>/dev/null || true; swank_pid=
  for _ in $(seq 1 40); do grep -q "nothing answers" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
  check "with Swank gone the window should say so and keep what it had: $(ev --cuis 'VikixDesktop summary' 2>&1)" grep -q "nothing answers on 127.0.0.1:$swank_port" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)"
  check "the image should have met no error (no debugger open): $(ev --cuis '(UISupervisor ui submorphs collect: [ :m | m class name ]) asArray' 2>&1)" test -z "$(grep -i 'debug' <<<"$(ev --cuis '(UISupervisor ui submorphs collect: [ :m | m class name ]) asArray' 2>&1)" || true)"

  # The move against a real StumpWM on a hidden screen: the image's VikixSwank
  # is pointed at it (the secret is the one the Cuis door reads), a window is
  # moved from the image, and StumpWM has it on the other workspace, where
  # Super+2 shows it. In a subshell: wm_setup ends it with a note when the
  # tools aren't there, and its cleanup is its own.
  (
    export VIKIX_TEST_STUMPWM="${VIKIX_TEST_STUMPWM:-$real_home/.local/bin/stumpwm}"
    # shellcheck source=lib/wm.sh
    . "$here/tests/lib/wm.sh"
    # shellcheck disable=SC2034  # wm_setup reads it
    wm_ql="$real_home/quicklisp"
    wm_setup cuis
    # shellcheck disable=SC2154  # wm_setup sets home
    echo "the-real-secret" > "$home/.slime-secret"
    wm_start
    win one; win two
    ev --cuis "VikixSwank port: $port" > /dev/null 2>&1
    for _ in $(seq 1 40); do grep -q "viritest: one" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
    summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
    check "the image should read the real StumpWM: $summary" grep -q "viritest: one" <<<"$summary"
    from=$(awk '/^workspace 1 /{print $3}' <<<"$summary"); to=$(awk '/^workspace 2 /{print $3}' <<<"$summary")
    number=$(sed -n 's/^  window \([0-9]*\) viritest: one.*/\1/p' <<<"$summary" | head -1)
    check "the workspaces and the window should be named ($from, $to, $number)" test -n "$from" -a -n "$to" -a -n "$number"
    ev --cuis "VikixDesktop window model moveWindow: $number from: '$from' to: '$to'" > /dev/null 2>&1
    for _ in $(seq 1 40); do grep -q "moved window $number to $to" <<<"$(ev --cuis 'VikixDesktop summary' 2>&1)" && break; sleep 0.25; done
    where=$(ask "(princ (group-name (window-group (find \"one\" (screen-windows (current-screen)) :key (function window-title) :test (function equal)))))")
    check "the real window should be on the other workspace: $where" test "$where" = "$to"
    # Pressed until the workspace changes: a key sent to a busy hidden screen is
    # sometimes lost (twice at a load of 6 on 2026-10-11, refusing a release each time).
    for _ in $(seq 1 8); do key super+2; test "$(ask '(princ (group-name (current-group)))')" = "$to" && break; done
    check "Super+2 should show it there: $(ask '(princ (group-name (current-group)))')" test "$(ask "(princ (if (find \"one\" (group-windows (current-group)) :key (function window-title) :test (function equal)) 1 0))")" = 1
    summary=$(ev --cuis 'VikixDesktop summary' 2>&1)
    check "and the image should show it there at the next poll: $summary" python3 -c '
import sys
lines = sys.argv[1].splitlines()
two = lines.index(next(l for l in lines if l.startswith("workspace 2")))
assert any("viritest: one" in l for l in lines[two:]), "not under workspace 2"
' "$summary"
    wm_report cuis "the move against a real StumpWM on a hidden screen"
    exit "$fail"
  ) || fail=1
  ev --cuis 'Smalltalk quit' > /dev/null 2>&1 || true
  for _ in $(seq 1 50); do kill -0 "$vm_pid" 2>/dev/null || break; sleep 0.2; done
  check "Smalltalk quit through the door should end the image" bash -c "! kill -0 $vm_pid 2>/dev/null"
  wait "$vm_pid" 2>/dev/null || true
  vm_pid=
else
  echo "note: the real Cuis release isn't at $real_base: the door wasn't tried against a real image"
fi

exit "$fail"
