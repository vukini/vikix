#!/usr/bin/env bash
# tests/rollback.sh — vikix rollback, in a made-up home with a made-up
# checkout and stand-ins for xbps and sudo: keep records Vikix's commit and
# version, the package set and the StumpWM binary (once per binary: the
# next record links the same one); keep packages copies the files of the
# packages an update is about to change from the cache, and names the ones
# that aren't there; the two newest records stay; restore puts the checkout
# at the commit, runs 40-config, copies the binary back, indexes the kept
# files and reinstalls them with -f, says the missing ones, and does
# nothing twice; vikix update --back is the same; forget drops them; the
# status lines say what is kept.

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

export HOME="$t/home"
mkdir -p "$HOME/.local/bin" "$t/bin" "$t/cache" "$t/checkout/install"
export PATH="$t/bin:$PATH" VIKIX_ROLLBACK_CHECKOUT="$t/checkout" VIKIX_ROLLBACK_CACHE="$t/cache" VIKIX_ROLLBACK_SUDO=""
vr() { bash "$here/bin/vikix-rollback" "$@"; }
records="$HOME/.local/state/vikix/rollback"

# A checkout with two commits: the record is made at the first.
git -C "$t/checkout" init -q
printf '0.72.100\n' > "$t/checkout/VERSION"
printf '#!/bin/sh\necho relinked >> "%s/config-ran"\n' "$t" > "$t/checkout/install/40-config.sh"
git -C "$t/checkout" -c user.name=t -c user.email=t@t add -A && git -C "$t/checkout" -c user.name=t -c user.email=t@t commit -q -m one
old=$(git -C "$t/checkout" rev-parse HEAD)
# Stand-ins: xbps-query lists and tells versions, xbps-install -Sun says
# what would change, the rest writes down what it was asked.
cat > "$t/bin/xbps-query" <<'X'
#!/bin/sh
case "$*" in
  -l) printf 'ii firefox-130.0_1  a browser\nii sbcl-2.4.0_1  a lisp\nii zlib-1.3_1  a library\n' ;;
  "-p pkgver firefox") echo firefox-130.0_1 ;;
  "-p pkgver sbcl") echo sbcl-2.4.0_1 ;;
  "-p pkgver zlib") echo zlib-1.3_1 ;;
  "-p pkgver newpkg") exit 2 ;;
esac
X
cat > "$t/bin/xbps-install" <<X
#!/bin/sh
case "\$*" in
  -Sun) printf 'firefox-131.0_1 update x86_64 https://m 1 2\nsbcl-2.4.1_1 update x86_64 https://m 1 2\nnewpkg-1_1 install x86_64 https://m 1 2\nzlib-1.3_1 configure x86_64\n' ;;
  *) echo "xbps-install \$*" >> "$t/asked" ;;
esac
X
printf '#!/bin/sh\necho "xbps-rindex $*" >> "%s/asked"\n' "$t" > "$t/bin/xbps-rindex"
printf '#!/bin/sh\ncase "$1" in arch) echo x86_64 ;; getpkgname) echo "${2%%-*}" ;; esac\n' > "$t/bin/xbps-uhelper"
chmod +x "$t/bin/"*
printf 'binary one\n' > "$HOME/.local/bin/stumpwm"
printf 'firefox as it was\n' > "$t/cache/firefox-130.0_1.x86_64.xbps"
printf 'sig\n' > "$t/cache/firefox-130.0_1.x86_64.xbps.sig2"
# sbcl's file isn't in the cache.

# --- keep -------------------------------------------------------------------------
check "status before anything doesn't say so" grep -q 'nothing kept yet' <<<"$(vr)"
out=$(vr keep 2>&1)
rec=$(ls "$records" | sort | tail -1)
check "keep didn't say what it kept: $out" grep -q "kept the system as it is: Vikix 0.72.100 at ${old:0:7}, the StumpWM binary" <<<"$out"
check "the commit isn't recorded" test "$(cat "$records/$rec/commit")" = "$old"
check "the package set isn't recorded" grep -q '^ii sbcl-2.4.0_1' "$records/$rec/packages"
check "the StumpWM binary isn't kept" test "$(cat "$records/$rec/stumpwm")" = "binary one"
out=$(vr keep packages 2>&1)
check "keep packages didn't count 2 of 3 (the new package isn't one to go back to): $out" grep -q 'kept 1 of the 2 packages about to change' <<<"$out"
check "firefox's file wasn't copied" test "$(cat "$records/$rec/pkgs/firefox-130.0_1.x86_64.xbps")" = "firefox as it was"
check "its signature wasn't" test -f "$records/$rec/pkgs/firefox-130.0_1.x86_64.xbps.sig2"
check "the changes don't say which is kept and which isn't" test "$(cat "$records/$rec/changes")" = "$(printf 'firefox-130.0_1 update kept\nsbcl-2.4.0_1 update not-in-cache')"
check "status doesn't list the record" grep -q "^  $rec  Vikix 0.72.100 at ${old:0:7}  2 packages changed (1 kept), the StumpWM binary" <<<"$(vr)"
check "status doesn't say / takes no snapshot here" grep -q 'no snapshot of /' <<<"$(vr)"

# --- the next records: the binary once, the two newest kept ----------------------------
sleep 1.1
vr keep >/dev/null 2>&1
rec2=$(ls "$records" | sort | tail -1)
check "the same binary isn't shared with the record before" test "$(stat -c %i "$records/$rec/stumpwm")" = "$(stat -c %i "$records/$rec2/stumpwm")"
printf 'binary two\n' > "$HOME/.local/bin/stumpwm"
sleep 1.1
vr keep >/dev/null 2>&1
check "more than two records are kept" test "$(ls "$records" | wc -l)" = 2
check "the oldest wasn't the one dropped" test ! -d "$records/$rec"
rec3=$(ls "$records" | sort | tail -1)
check "a changed binary isn't kept anew" test "$(cat "$records/$rec3/stumpwm")" = "binary two"

# --- restore --------------------------------------------------------------------------
# The checkout moves on, as an update would; the record to restore is rec2
# (binary one, at the first commit), given by its ID.
printf '0.72.101\n' > "$t/checkout/VERSION"
git -C "$t/checkout" -c user.name=t -c user.email=t@t commit -q -am two
cp "$records/$rec2/.." /dev/null 2>/dev/null || true
mkdir -p "$records/$rec2/pkgs"; printf 'firefox-130.0_1 update kept\nsbcl-2.4.0_1 update not-in-cache\n' > "$records/$rec2/changes"
printf 'firefox as it was\n' > "$records/$rec2/pkgs/firefox-130.0_1.x86_64.xbps"
out=$(vr restore "$rec2" 2>&1)
check "restore didn't put the checkout at the commit: $out" test "$(git -C "$t/checkout" rev-parse HEAD)" = "$old"
check "restore didn't say it is off main" grep -q 'off main: the next vikix update goes forward again' <<<"$out"
check "40-config wasn't run" test "$(cat "$t/config-ran" 2>/dev/null)" = relinked
check "the StumpWM binary isn't back" test "$(cat "$HOME/.local/bin/stumpwm")" = "binary one"
check "the kept packages weren't indexed" grep -q "^xbps-rindex -a $records/$rec2/pkgs/firefox-130.0_1.x86_64.xbps" "$t/asked"
check "firefox wasn't reinstalled from the record with -f" grep -q "^xbps-install -y -f --repository=$records/$rec2/pkgs firefox-130.0_1$" "$t/asked"
check "the package not in the cache isn't named as staying new" grep -q '1 packages had no file in xbps.s cache.*sbcl-2.4.0_1' <<<"$out"
check "restore doesn't end with the log-out line" grep -q 'log out and in' <<<"$out"
out=$(vr restore "$rec2" 2>&1)
check "a second restore moved the checkout again" bash -c '! grep -q "off main" <<<"$1"' _ "$out"
check "or copied the binary again" grep -q "the StumpWM binary is the record's already" <<<"$out"
if vr restore nonsense >/dev/null 2>&1; then echo "FAIL: a record that isn't there restored something"; fail=1; fi

# --- vikix update --back, forget, help ------------------------------------------------
check "--help doesn't show the forms" grep -q 'vikix rollback restore \[ID\]' <<<"$(vr --help)"
check "vikix update --back isn't the restore" grep -q -- '--back) exec "$VIKIX_DIR/bin/vikix-rollback" restore' "$here/bin/vikix"
check "vikix update doesn't keep a record before it pulls" grep -q 'vikix-rollback" keep ||' "$here/bin/vikix"
check "or the packages before it updates Void" grep -q 'vikix-rollback" keep packages ||' "$here/bin/vikix"
vr forget >/dev/null
check "forget left records" test ! -d "$records"

[ "$fail" = 0 ] && echo "rollback: a record of the commit, the packages and the StumpWM binary; the packages about to change kept from the cache; the two newest records; a restore of the checkout, the links, the binary and the packages, the missing ones named"
exit "$fail"
