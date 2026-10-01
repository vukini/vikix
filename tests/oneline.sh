#!/usr/bin/env bash
# tests/oneline.sh — the one-line install, site/install, piped into bash as
# `curl -fsSL https://vikix.dev/install | bash -s -- ARGS` would:
#
#   - on glibc Void as a user, it clones Vikix and runs install.sh with ARGS
#   - it refuses another system, musl, and root, before changing anything
#   - without git, it installs git first (through sudo)
#   - a clone already there is updated, not cloned again; a folder there
#     that isn't one is left alone
#   - a download cut off halfway runs nothing
#
# The clone comes from a made-up repository whose install.sh only says
# what it got; sudo, id and xbps-uhelper are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
lacks() { ! grep -q -- "$1" <<<"$2"; }
git_q() { git -c user.name=test -c user.email=test@example.org "$@"; }

# The made-up Vikix: its install.sh says what it got.
mkdir -p "$t/repo" "$t/bin" "$t/home"
printf '#!/bin/sh\necho "INSTALL.SH GOT: $*"\n' > "$t/repo/install.sh"; chmod +x "$t/repo/install.sh"
( cd "$t/repo" && git init -q && git_q add -A && git_q commit -qm vikix )
printf 'ID=void\n' > "$t/void"; printf 'ID=debian\n' > "$t/debian"
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$t/calls" > "$t/bin/sudo"
printf '#!/bin/sh\necho x86_64\n' > "$t/bin/xbps-uhelper"
chmod +x "$t/bin/"*
export HOME="$t/home" VIKIX_REPO="file://$t/repo" VIKIX_OS_RELEASE="$t/void" VIKIX_NO_TTY=1 PATH="$t/bin:$PATH"
dir="$HOME/vikix"
oneline() { bash -s -- "$@" < "$here/site/install" 2>&1; }

# --- glibc Void, a user --------------------------------------------------------
out=$(oneline --with essentials) || { echo "FAIL: the one-line install failed: $out"; fail=1; }
check "it should clone Vikix into ~/vikix" test -d "$dir/.git"
check "install.sh should get the arguments after --: $out" has 'INSTALL.SH GOT: --with essentials' "$out"
out=$(oneline) || true
check "a second run should update the clone: $out" has 'already a clone; updating it' "$out"

# --- refusals, before anything changes --------------------------------------------------
rm -rf "$dir"
out=$(VIKIX_OS_RELEASE="$t/debian" oneline) && { echo "FAIL: it went ahead on Debian"; fail=1; }
check "another system should be named: $out" has "this isn't Void Linux" "$out"
printf '#!/bin/sh\necho x86_64-musl\n' > "$t/bin/xbps-uhelper"
out=$(oneline) && { echo "FAIL: it went ahead on musl"; fail=1; }
check "musl should be refused: $out" has 'musl' "$out"
printf '#!/bin/sh\necho x86_64\n' > "$t/bin/xbps-uhelper"
printf '#!/bin/sh\n[ "$1" = -u ] && echo 0 || exec /usr/bin/id "$@"\n' > "$t/bin/id"; chmod +x "$t/bin/id"
out=$(oneline) && { echo "FAIL: it went ahead as root"; fail=1; }
check "root should be refused: $out" has 'not root' "$out"
rm "$t/bin/id"
check "a refusal cloned anyway" test ! -e "$dir"
mkdir -p "$dir"; echo mine > "$dir/notes"
out=$(oneline) && { echo "FAIL: it went ahead over a folder that isn't a clone"; fail=1; }
check "a folder that isn't a clone should be left: $out" has "isn't a clone of Vikix" "$out"
check "the folder that isn't a clone was changed" test "$(cat "$dir/notes")" = mine
rm -rf "$dir"

# --- no git: installed first ---------------------------------------------------------------
# A PATH without git, whose sudo "installs" it by linking the real one in.
real_git=$(command -v git)
mkdir -p "$t/nogit"
for c in bash sh grep cat id printf env sed; do ln -sf "$(command -v "$c")" "$t/nogit/$c"; done
cp "$t/bin/xbps-uhelper" "$t/nogit/"
printf '#!/bin/sh\necho "sudo $*" >> %q\ncase "$*" in *git*) %q -sf %q %q; %q -sf %q %q ;; esac\n' "$t/calls" "$(command -v ln)" "$real_git" "$t/nogit/git" "$(command -v ln)" "$(command -v git-upload-pack)" "$t/nogit/git-upload-pack" > "$t/nogit/sudo"
chmod +x "$t/nogit/sudo"
: > "$t/calls"
out=$(PATH="$t/nogit" oneline) || true
check "without git it should install git first: $(cat "$t/calls")" grep -q 'sudo xbps-install -Sy git' "$t/calls"
check "after installing git it should clone: $out" test -d "$dir/.git"
rm -rf "$dir"

# --- a download cut off halfway ------------------------------------------------------------
out=$(head -c "$(( $(wc -c < "$here/site/install") - 30 ))" "$here/site/install" | bash 2>&1) || true
check "a cut-off download ran something: $out" test ! -e "$dir"
check "a cut-off download printed a step: $out" lacks '^::' "$out"

[ "$fail" = 0 ] && echo "oneline: clones and runs install.sh with the arguments, refuses other systems, musl and root first, installs git, updates a clone, and a cut-off download runs nothing"
exit "$fail"
