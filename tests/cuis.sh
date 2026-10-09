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
#   exit 2, an agent's expression is held (exit 3).
#
#   With the real release at hand (~/.local/opt/cuis of the user running the
#   test, or VIKIX_CUIS_REAL_BASE): the image is built from it in the test's
#   home, started headless with the door on a free port, and vikix eval
#   --cuis gets 7 for 3 + 4, an error for 1/0, a value of several lines, is
#   refused with the wrong password and served again with the right one.
#   Without it that part is skipped, and says so.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY VIKIX_CUIS_PORT VIKIX_CUIS_OPT
here=$(cd "$(dirname "$0")/.." && pwd)
real_base=${VIKIX_CUIS_REAL_BASE:-$HOME/.local/opt/cuis/base}
t=$(mktemp -d)
vm_pid=
cleanup() {
  if [ -n "$vm_pid" ] && kill -0 "$vm_pid" 2>/dev/null; then kill "$vm_pid" 2>/dev/null || true; wait "$vm_pid" 2>/dev/null || true; fi
  rm -rf "$t"
}
trap cleanup EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
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
check "status should name the image and its packages" grep -q "built with Vikix's packages: VikixServer" "$t/out"
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

# --- vikix eval --cuis without Cuis, and from an agent -----------------------------------
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
if VIKIX_CUIS_PORT=$port ev --cuis '3 + 4' > "$t/out" 2>&1; then echo "FAIL: nothing listening should be exit 2"; fail=1; fi
check "nothing listening should say so" grep -q "nothing is listening on 127.0.0.1:$port" "$t/out"
if ev --cuis > "$t/out" 2>&1 < /dev/null; then echo "FAIL: no Smalltalk should be refused"; fail=1; fi
check "no Smalltalk should say so" grep -q "no Smalltalk to run" "$t/out"
# An agent above the shell: its expression is held, nothing is sent.
mkdir -p "$t/proc/4242"
printf 'claude\0--resume\0' > "$t/proc/4242/cmdline"
echo "4242 (claude) S 1 4242 4242 0 -1" > "$t/proc/4242/stat"
status=0
VIKIX_PROC="$t/proc" VIKIX_EVAL_PARENT=4242 VIKIX_CUIS_PORT=$port python3 "$here/bin/vikix-eval" --cuis '3 + 4' > "$t/out" 2>&1 || status=$?
check "an agent's Smalltalk should be held (exit 3, was $status)" test "$status" = 3
check "an agent should be told why" grep -q "an agent's Smalltalk (claude 4242)" "$t/out"

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
  cu rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the real image should build"; fail=1; }
  check "the real build should load the door" grep -q "VikixServer" "$t/out"
  check "the real image should be there" test -s "$cuis/vikix.image"
  port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  ( umask 077; echo "the-real-secret" > "$HOME/.slime-secret" )
  cu run --headless --port "$port" > "$t/vm.log" 2>&1 &
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
  ev --cuis 'Smalltalk quit' > /dev/null 2>&1 || true
  for _ in $(seq 1 50); do kill -0 "$vm_pid" 2>/dev/null || break; sleep 0.2; done
  check "Smalltalk quit through the door should end the image" bash -c "! kill -0 $vm_pid 2>/dev/null"
  wait "$vm_pid" 2>/dev/null || true
  vm_pid=
else
  echo "note: the real Cuis release isn't at $real_base: the door wasn't tried against a real image"
fi

exit "$fail"
