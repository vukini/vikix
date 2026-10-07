#!/usr/bin/env bash
# tests/lisp-apps.sh — vikix lisp-apps: Nyxt, Lem and McCLIM's Listener.
#
#   setup fetches Lem at the pinned commit and refuses another, installs its
#   libraries with qlot, then builds the SDL2 window; builds the Listener
#   with Clouseau as one program; links lem and clim-listener into
#   ~/.local/bin and puts both in the launcher; records the feature; asks
#   for no sudo when the packages are there; a second setup builds nothing,
#   --rebuild builds again; a failed build says where its log is and links
#   nothing; status says what's built; uninstall removes only what setup
#   made and keeps the feature (Nyxt stays); a dry run changes nothing.
#
# git and sbcl are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$HOME/quicklisp" "$t/bin" "$VIKIX_STATE"
touch "$HOME/quicklisp/setup.lisp"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
la() { bash "$here/bin/vikix-lisp-apps" "$@"; }
pinned=$(sed -n 's/^LEM_COMMIT=\([0-9a-f]*\).*/\1/p' "$here/bin/vikix-lisp-apps")
echo "$pinned" > "$t/commit"
lem="$HOME/.local/opt/lem"; clim="$HOME/.local/opt/mcclim"
apps="$HOME/.local/share/applications"

# git: init makes .git; HEAD is whatever $t/commit says.
cat > "$t/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >> "$calls"
case "\$*" in
  *" init"*) mkdir -p "$lem/.git" ;;
  *rev-parse*) cat "$t/commit" ;;
esac
EOF
# sbcl: build-sdl2.lisp writes ./lem; save-lisp-and-die writes the file it
# names; $t/break-lem makes Lem's build fail.
cat > "$t/bin/sbcl" <<EOF
#!/bin/sh
echo "sbcl (in \$(pwd)) \$*" >> "$calls"
case "\$*" in
  *build-sdl2.lisp*) [ -e "$t/break-lem" ] && { echo "a compile error"; exit 1; }
    printf '#!/bin/sh\n' > lem; chmod +x lem ;;
  *save-lisp-and-die*) out=\$(printf '%s' "\$*" | sed -n 's/.*save-lisp-and-die "\([^"]*\)".*/\1/p')
    printf '#!/bin/sh\n' > "\$out"; chmod +x "\$out" ;;
esac
EOF
cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
exit 0
EOF
cat > "$t/bin/sudo" <<EOF
#!/bin/sh
echo "sudo \$*" >> "$calls"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_GIT="$t/bin/git" VIKIX_SBCL="$t/bin/sbcl"

# --- A dry run changes nothing ------------------------------------------------
DRY_RUN=1 la setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run should build nothing" test ! -e "$lem"
check "a dry run should call no sbcl: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
check "a dry run shouldn't record the feature" test ! -e "$HOME/.config/vikix/features"
check "a dry run should say it would build Lem" grep -q "would build Lem" "$t/out"

# --- Not the pinned commit: refused ---------------------------------------------
echo 0000000000000000000000000000000000000000 > "$t/commit"
if la setup > "$t/out" 2>&1; then echo "FAIL: another commit should be refused"; fail=1; fi
check "Lem should be fetched by its commit: $(grep fetch "$calls")" grep -q "fetch -q --depth 1 origin $pinned" "$calls"
check "another commit shouldn't be built: $(grep sbcl "$calls")" test -z "$(grep sbcl "$calls" || true)"
check "nothing should be linked after a refusal" test ! -e "$HOME/.local/bin/lem"
echo "$pinned" > "$t/commit"; : > "$calls"

# --- Setup ------------------------------------------------------------------------
la setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup should work"; fail=1; }
check "qlot should install Lem's libraries in Lem's folder" grep -q "sbcl (in $lem) .*(qlot:install)" "$calls"
check "the terminal library should be tried" grep -q "build-terminal.lisp" "$calls"
check "the build should load .qlot's libraries: $(grep build-sdl2 "$calls")" \
  grep -q -- "--load .qlot/setup.lisp --load scripts/build-sdl2.lisp" "$calls"
check "the build should get 4 GiB" grep -q -- "--dynamic-space-size 4GiB" "$calls"
check "Lem should record the commit it was built from" test "$(cat "$lem/.vikix-built" 2>/dev/null)" = "$pinned"
check "the Listener should load McCLIM, the Listener and Clouseau" grep -q ":mcclim :clim-listener :clouseau" "$calls"
check "the Listener should be one program" test -x "$clim/clim-listener"
check "no half-written Listener should be left" test ! -e "$clim/.clim-listener.new"
check "lem should be linked" test "$(readlink "$HOME/.local/bin/lem")" = "$lem/lem"
check "clim-listener should be linked" test "$(readlink "$HOME/.local/bin/clim-listener")" = "$clim/clim-listener"
check "Lem should be in the launcher" grep -q "^Exec=$HOME/.local/bin/lem %F" "$apps/vikix-lem.desktop"
check "the Listener should be in the launcher" grep -q "^Exec=$HOME/.local/bin/clim-listener" "$apps/vikix-clim-listener.desktop"
check "setup should record the feature" grep -qx lisp-apps "$HOME/.config/vikix/features"
check "setup shouldn't ask for sudo when the packages are there: $(grep sudo "$calls")" test -z "$(grep '^sudo' "$calls" || true)"
check "the build logs should be kept" test -e "$VIKIX_STATE/logs/lem-build.log" -a -e "$VIKIX_STATE/logs/clim-listener-build.log"

# --- Again: nothing to build; --rebuild builds ----------------------------------
: > "$calls"
la setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a second setup should work"; fail=1; }
check "a second setup should build nothing: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
la setup --rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: --rebuild should work"; fail=1; }
check "--rebuild should build Lem again" grep -q build-sdl2 "$calls"
check "--rebuild should build the Listener again" grep -q save-lisp-and-die "$calls"
if la setup --nonsense > /dev/null 2>&1; then echo "FAIL: an unknown option should be refused"; fail=1; fi

# --- Status ----------------------------------------------------------------------
la status > "$t/out" 2>&1
check "status should show Lem's commit: $(cat "$t/out")" grep -q "lem .*built, commit ${pinned:0:7}" "$t/out"
check "status should show the Listener built" grep -q "clim-listener  built" "$t/out"
echo other > "$lem/.vikix-built"
la status > "$t/out" 2>&1
check "status should say Lem is from another commit" grep -q "another commit" "$t/out"
echo "$pinned" > "$lem/.vikix-built"

# --- A failed build: its log is named ------------------------------------------
touch "$t/break-lem"
if la setup --rebuild > "$t/out" 2>&1; then echo "FAIL: a failed build should fail"; fail=1; fi
check "a failed build should name its log: $(cat "$t/out")" grep -q "lem-build.log" "$t/out"
check "a failed build should show its end" grep -q "a compile error" "$t/out"
rm -f "$t/break-lem"

# --- Uninstall: only what setup made --------------------------------------------
la setup > /dev/null 2>&1 || true
ln -sfn /usr/bin/true "$HOME/.local/bin/clim-listener"   # yours now, not setup's
la uninstall > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: uninstall should work"; fail=1; }
check "lem's link should be gone" test ! -e "$HOME/.local/bin/lem"
check "a clim-listener that isn't setup's should stay" test "$(readlink "$HOME/.local/bin/clim-listener")" = /usr/bin/true
check "Lem's folder should be gone" test ! -e "$lem"
check "the Listener's folder should be gone" test ! -e "$clim"
check "the launcher entries should be gone" test ! -e "$apps/vikix-lem.desktop" -a ! -e "$apps/vikix-clim-listener.desktop"
check "uninstall should keep the feature (Nyxt stays)" grep -qx lisp-apps "$HOME/.config/vikix/features"
check "Quicklisp should stay" test -e "$HOME/quicklisp/setup.lisp"

[ "$fail" = 0 ] && echo "lisp-apps: ok"
exit "$fail"
