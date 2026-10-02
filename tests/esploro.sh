#!/usr/bin/env bash
# tests/esploro.sh — vikix esploro: Vid's file explorer in Common Lisp.
#
#   setup fetches Esploro at the pinned commit and refuses another, builds
#   it with build.lisp in its folder as one program, links esploro into
#   ~/.local/bin and puts it in the launcher; records the feature; asks for
#   no sudo when the packages are there; a second setup builds nothing,
#   --rebuild builds again; a failed build says where its log is and links
#   nothing; status says what's built; uninstall removes only what setup
#   made and forgets the feature; a dry run changes nothing. The key and
#   the Apps menu name the command and the program.
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
es() { bash "$here/bin/vikix-esploro" "$@"; }
pinned=$(sed -n 's/^ESPLORO_COMMIT=\([0-9a-f]*\).*/\1/p' "$here/bin/vikix-esploro")
echo "$pinned" > "$t/commit"
opt="$HOME/.local/opt/esploro"
apps="$HOME/.local/share/applications"

# git: init makes .git; HEAD is whatever $t/commit says.
cat > "$t/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >> "$calls"
case "\$*" in
  *" init"*) mkdir -p "$opt/.git" ;;
  *rev-parse*) cat "$t/commit" ;;
esac
EOF
# sbcl: build.lisp writes ./esploro.new; $t/break makes the build fail.
cat > "$t/bin/sbcl" <<EOF
#!/bin/sh
echo "sbcl (in \$(pwd)) \$*" >> "$calls"
case "\$*" in
  *build.lisp*) [ -e "$t/break" ] && { echo "a compile error"; exit 1; }
    printf '#!/bin/sh\n' > esploro.new; chmod +x esploro.new ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$t/bin/xbps-query"
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$calls" > "$t/bin/sudo"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_GIT="$t/bin/git" VIKIX_SBCL="$t/bin/sbcl"

# --- A dry run changes nothing ------------------------------------------------
DRY_RUN=1 es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run should build nothing" test ! -e "$opt"
check "a dry run should call no sbcl: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
check "a dry run shouldn't record the feature" test ! -e "$HOME/.config/vikix/features"
check "a dry run should say it would build Esploro" grep -q "would build Esploro" "$t/out"

# --- Not the pinned commit: refused ---------------------------------------------
echo 0000000000000000000000000000000000000000 > "$t/commit"
if es setup > "$t/out" 2>&1; then echo "FAIL: another commit should be refused"; fail=1; fi
check "Esploro should be fetched by its commit: $(grep fetch "$calls")" grep -q "fetch -q --depth 1 origin $pinned" "$calls"
check "another commit shouldn't be built" test -z "$(grep sbcl "$calls" || true)"
check "nothing should be linked after a refusal" test ! -e "$HOME/.local/bin/esploro"
echo "$pinned" > "$t/commit"; : > "$calls"

# --- Setup ------------------------------------------------------------------------
es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup should work"; fail=1; }
check "the build should run build.lisp in Esploro's folder, with Quicklisp: $(grep sbcl "$calls")" \
  grep -q "sbcl (in $opt) .*--load $HOME/quicklisp/setup.lisp --load build.lisp" "$calls"
check "the program should be in place" test -x "$opt/esploro"
check "no half-written program should be left" test ! -e "$opt/esploro.new"
check "Esploro should record the commit it was built from" test "$(cat "$opt/.vikix-built" 2>/dev/null)" = "$pinned"
check "esploro should be linked" test "$(readlink "$HOME/.local/bin/esploro")" = "$opt/esploro"
check "Esploro should be in the launcher" grep -q "^Exec=$HOME/.local/bin/esploro %F" "$apps/vikix-esploro.desktop"
check "the launcher should know its window" grep -q "^StartupWMClass=Esploro" "$apps/vikix-esploro.desktop"
check "setup should record the feature" grep -qx esploro "$HOME/.config/vikix/features"
check "setup shouldn't ask for sudo when the packages are there: $(grep sudo "$calls")" test -z "$(grep '^sudo' "$calls" || true)"
check "setup should say the build is quiet and how long" grep -q "a minute or two, quietly" "$t/out"
check "the build log should be kept" test -e "$VIKIX_STATE/logs/esploro-build.log"

# --- Again: nothing to build; --rebuild builds ----------------------------------
: > "$calls"
es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a second setup should work"; fail=1; }
check "a second setup should build nothing: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
es setup --rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: --rebuild should work"; fail=1; }
check "--rebuild should build again" grep -q build.lisp "$calls"
if es setup --nonsense > /dev/null 2>&1; then echo "FAIL: an unknown option should be refused"; fail=1; fi

# --- Status ----------------------------------------------------------------------
es status > "$t/out" 2>&1
check "status should show the commit: $(cat "$t/out")" grep -q "built, commit ${pinned:0:7}" "$t/out"
echo other > "$opt/.vikix-built"
es status > "$t/out" 2>&1
check "status should say it's from another commit" grep -q "another commit" "$t/out"
echo "$pinned" > "$opt/.vikix-built"

# --- A failed build: its log is named ------------------------------------------
touch "$t/break"
if es setup --rebuild > "$t/out" 2>&1; then echo "FAIL: a failed build should fail"; fail=1; fi
check "a failed build should name its log: $(cat "$t/out")" grep -q "esploro-build.log" "$t/out"
check "a failed build should show its end" grep -q "a compile error" "$t/out"
rm -f "$t/break"

# --- Uninstall: only what setup made --------------------------------------------
es setup > /dev/null 2>&1 || true
es uninstall > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: uninstall should work"; fail=1; }
check "esploro's link should be gone" test ! -e "$HOME/.local/bin/esploro"
check "Esploro's folder should be gone" test ! -e "$opt"
check "the launcher entry should be gone" test ! -e "$apps/vikix-esploro.desktop"
check "uninstall should forget the feature" test -z "$(grep -x esploro "$HOME/.config/vikix/features" || true)"
# Your own esploro (make install in your clone) is never touched.
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' > "$HOME/.local/bin/esploro"
es uninstall > /dev/null 2>&1 || true
check "an esploro that isn't setup's should stay" test -f "$HOME/.local/bin/esploro" -a ! -L "$HOME/.local/bin/esploro"

# --- The key and the menu -------------------------------------------------------
check "Super+Alt+e should run vikix-esploro" grep -q '("s-M-e" *"vikix-esploro"' "$here/config/stumpwm/vikix/keys.lisp"
check "vikix-esploro should go to Esploro's window by its class" \
  grep -q "run-or-raise \"esploro\" '(:class \"Esploro\")" "$here/config/stumpwm/vikix/commands.lisp"
check "the Apps menu should offer Esploro once it's here" \
  grep -q '(run-shell-command "esploro") "~/.local/bin/esploro")' "$here/config/stumpwm/vikix/commands.lisp"
check "vikix update should build a moved pin" grep -q 'is_chosen esploro' "$here/bin/vikix"

[ "$fail" = 0 ] && echo "esploro: fetched at its pin, built in its folder, linked and in the launcher, quiet builds explained, only what setup made goes, Super+Alt+e"
exit "$fail"
