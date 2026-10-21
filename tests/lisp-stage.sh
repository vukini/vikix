#!/usr/bin/env bash
# tests/lisp-stage.sh — install/30-lisp never stops to ask for a key, and a
# rebuild keeps the old image, checks the new one, and notes the build.
#
# A fresh install (bash vikix-install, with the terminal as its input)
# stopped in 30-lisp at Quicklisp's "Press Enter to continue", which
# (ql:add-to-init-file) asks whenever it can reach a terminal. The stage
# now writes those lines into ~/.sbclrc itself: here it runs with
# Quicklisp, StumpWM, clx-truetype and the contrib modules already in
# place, an sbcl that fails if it's called, and a terminal-like input it
# must not read; it adds Quicklisp to ~/.sbclrc once, keeps what was there,
# and a dry run writes nothing. Then a rebuild (VIKIX_REBUILD_WM=1) with an
# sbcl that stands in for lib/build-stumpwm.lisp: the one before stays as
# stumpwm.prev, the new one is asked whether it starts (VIKIX_WM_CHECK) and
# thrown away when it doesn't, and the build is noted for vikix doctor.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
real_sbcl=$(command -v sbcl || true)   # before the stand-in goes first on PATH
export HOME="$t/home"
mkdir -p "$HOME/quicklisp/local-projects/clx-truetype" "$HOME/.local/bin" "$HOME/.stumpwm.d/modules/.git" "$t/bin"
: > "$HOME/quicklisp/setup.lisp"
printf '#!/bin/sh\n' > "$HOME/.local/bin/stumpwm"; chmod +x "$HOME/.local/bin/stumpwm"
# Anything that would need sbcl (or a key) fails here; git pull is a no-op.
printf '#!/bin/sh\necho "sbcl was called: $*" >&2; exit 1\n' > "$t/bin/sbcl"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/git"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
stage() { timeout 20 bash "$here/install/30-lisp.sh" < /dev/zero; }

printf ';; mine\n(setf *print-case* :downcase)\n' > "$HOME/.sbclrc"
DRY_RUN=1 stage > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run shouldn't change the .sbclrc" test "$(grep -c quicklisp "$HOME/.sbclrc" || true)" = 0
stage > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the stage should finish without sbcl or a key"; fail=1; }
check "the .sbclrc should load Quicklisp" grep -q '(merge-pathnames "quicklisp/setup.lisp"' "$HOME/.sbclrc"
check "your own lines in the .sbclrc should stay" grep -qx '(setf \*print-case\* :downcase)' "$HOME/.sbclrc"
stage > /dev/null 2>&1
check "a second run shouldn't add it twice" test "$(grep -c 'quicklisp/setup.lisp' "$HOME/.sbclrc")" = 1
if [ -n "$real_sbcl" ]; then
  check "the .sbclrc should still read as Lisp" "$real_sbcl" --noinform --no-sysinit --no-userinit --non-interactive \
    --eval "(with-open-file (in \"$HOME/.sbclrc\") (loop for f = (read in nil :eof) until (eq f :eof)))"
fi


# A rebuild. The stand-in sbcl writes VIKIX_WM_OUTPUT as its build would: an
# image that answers the check, or (BAD_IMAGE=1) one that doesn't start.
cat > "$t/bin/sbcl" <<'SH'
#!/bin/sh
case " $* " in *" --version "*) echo "SBCL 9.9.9.stub"; exit 0 ;; esac
[ -n "$VIKIX_WM_OUTPUT" ] || { echo "sbcl: no VIKIX_WM_OUTPUT" >&2; exit 1; }
echo "dist=$VIKIX_QL_DIST" > "$VIKIX_WM_OUTPUT.env"
if [ "${BAD_IMAGE:-0}" = 1 ]; then printf '#!/bin/sh\necho "core mismatch" >&2; exit 1\n' > "$VIKIX_WM_OUTPUT"
else printf '#!/bin/sh\n[ -n "$VIKIX_WM_CHECK" ] && { echo "stumpwm image ok"; exit 0; }\necho new\n' > "$VIKIX_WM_OUTPUT"; fi
chmod +x "$VIKIX_WM_OUTPUT"
SH
chmod +x "$t/bin/sbcl"
printf '#!/bin/sh\necho old\n' > "$HOME/.local/bin/stumpwm"
state="$HOME/.local/state/vikix"
VIKIX_REBUILD_WM=1 DRY_RUN=1 stage > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry rebuild should work"; fail=1; }
check "a dry rebuild should say it would keep the old image" grep -q 'mv -f .*stumpwm .*stumpwm.prev' "$t/out"
check "a dry rebuild should build nothing" test "$("$HOME/.local/bin/stumpwm")" = old
check "a dry rebuild should keep no previous image" test ! -e "$HOME/.local/bin/stumpwm.prev"
check "a dry rebuild should note no build" test ! -e "$state/stumpwm-built"
VIKIX_REBUILD_WM=1 stage > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a rebuild should work"; fail=1; }
check "the rebuild should give the build the pinned dist" grep -q "^dist=$(sed -n 's/^QL_DIST="\(.*\)"$/\1/p' "$here/install/30-lisp.sh")$" "$HOME/.local/bin/stumpwm.new.env"
check "the pin should be a dated Quicklisp release" grep -q '^QL_DIST="20[0-9][0-9]-[01][0-9]-[0-3][0-9]"$' "$here/install/30-lisp.sh"
check "the new image should be in place" test "$("$HOME/.local/bin/stumpwm")" = new
check "the one before should stay as stumpwm.prev" test "$("$HOME/.local/bin/stumpwm.prev")" = old
check "nothing should be left as stumpwm.new" test ! -e "$HOME/.local/bin/stumpwm.new"
check "the build should be noted" grep -q '^sbcl=SBCL 9.9.9.stub$' "$state/stumpwm-built"
check "the note should name the dist" grep -q '^quicklisp=20' "$state/stumpwm-built"
check "the note should say when" grep -q '^built=20' "$state/stumpwm-built"
# A build whose image doesn't start: thrown away, the desktop's image untouched.
if BAD_IMAGE=1 VIKIX_REBUILD_WM=1 stage > "$t/out" 2>&1; then echo "FAIL: a rebuild whose image doesn't start should fail"; fail=1; fi
check "the stage should say the new image doesn't start" grep -q "doesn't start" "$t/out"
check "an image that doesn't start should be thrown away" test ! -e "$HOME/.local/bin/stumpwm.new"
check "the desktop's image should stay as it was" test "$("$HOME/.local/bin/stumpwm")" = new
check "the previous image should stay as it was" test "$("$HOME/.local/bin/stumpwm.prev")" = old
# lib/build-stumpwm.lisp, what the stand-in stood for, has the pin and the
# check; it names Quicklisp's packages, so bare SBCL can't even read it,
# and the real build is minutes: not here.
check "the build script should move Quicklisp to the pin" grep -q 'VIKIX_QL_DIST' "$here/lib/build-stumpwm.lisp"
check "the build script should answer the check" grep -q 'VIKIX_WM_CHECK' "$here/lib/build-stumpwm.lisp"

[ "$fail" = 0 ] && echo "lisp-stage: 30-lisp adds Quicklisp to ~/.sbclrc once without a key; a rebuild keeps the old image, checks the new one and notes the build"
exit "$fail"
