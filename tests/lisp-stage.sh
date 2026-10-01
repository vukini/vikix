#!/usr/bin/env bash
# tests/lisp-stage.sh — install/30-lisp never stops to ask for a key.
#
# A fresh install (bash vikix-install, with the terminal as its input)
# stopped in 30-lisp at Quicklisp's "Press Enter to continue", which
# (ql:add-to-init-file) asks whenever it can reach a terminal. The stage
# now writes those lines into ~/.sbclrc itself: here it runs with
# Quicklisp, StumpWM, clx-truetype and the contrib modules already in
# place, an sbcl that fails if it's called, and a terminal-like input it
# must not read; it adds Quicklisp to ~/.sbclrc once, keeps what was there,
# and a dry run writes nothing.

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

[ "$fail" = 0 ] && echo "lisp-stage: 30-lisp adds Quicklisp to ~/.sbclrc once, without stopping for a key"
exit "$fail"
