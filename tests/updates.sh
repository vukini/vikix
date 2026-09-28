#!/usr/bin/env bash
# tests/updates.sh — vikix-updates counts the Void packages and Vikix
# commits that `vikix update` would bring, and says ? for what it can't
# check, instead of a wrong 0.
#
# A fake xbps-install stands in for the network; a checkout two commits
# behind a local "upstream" stands in for Vikix.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
git_q() { git -c user.name=test -c user.email=test@example.org "$@"; }
fail=0

mkdir -p "$t/upstream" "$t/bin"
( cd "$t/upstream" && git init -q && for i in 1 2 3; do git_q commit -q --allow-empty -m "c$i"; done )
git clone -q "$t/upstream" "$t/vikix"
git -C "$t/vikix" reset -q --hard HEAD~2
mkdir -p "$t/vikix/bin" "$t/vikix/lib" && cp "$here/bin/vikix-updates" "$here/bin/vikix-firmware" "$t/vikix/bin/"
cp "$here/lib/common.sh" "$t/vikix/lib/"

# fwupd's stand-in: N devices with a firmware update (never the real one).
fake_fwupd() {   # fake_fwupd N
  cat > "$t/bin/fwupdmgr" <<EOF
#!/bin/sh
case "\$*" in *get-updates*) python3 -c 'import json; print(json.dumps({"Devices": [{}] * $1}))' ;; esac
EOF
  chmod +x "$t/bin/fwupdmgr"
}
fake_fwupd 0

fake_xbps() {   # fake_xbps LINES|fail
  if [ "$1" = fail ]; then
    printf '#!/bin/sh\nexit 1\n' > "$t/bin/xbps-install"
  else
    printf '#!/bin/sh\nfor i in $(seq %s); do echo "pkg-$i update x86_64"; done\n' "$1" > "$t/bin/xbps-install"
  fi
  chmod +x "$t/bin/xbps-install"
}
# VIKIX_FWUPDMGR: the stand-in outright, never a real fwupdmgr on PATH.
counts() { PATH="$t/bin:$PATH" XDG_STATE_HOME="$t/state" VIKIX_FWUPDMGR="$t/bin/fwupdmgr" \
             sh "$t/vikix/bin/vikix-updates" >/dev/null; cat "$t/state/vikix/updates"; }

fake_xbps 3
[ "$(counts)" = "3 2 0" ] || { echo "FAIL: 3 packages and 2 commits read as: $(counts)"; fail=1; }
fake_xbps 0
[ "$(counts)" = "0 2 0" ] || { echo "FAIL: no packages read as: $(counts)"; fail=1; }
fake_xbps fail
[ "$(counts)" = "? 2 0" ] || { echo "FAIL: a failed package check read as: $(counts)"; fail=1; }
fake_xbps 0; fake_fwupd 2
[ "$(counts)" = "0 2 2" ] || { echo "FAIL: 2 firmware updates read as: $(counts)"; fail=1; }
fake_fwupd 0
git -C "$t/vikix" remote set-url origin "$t/nowhere"
fake_xbps 1
[ "$(counts)" = "1 ? 0" ] || { echo "FAIL: an unreachable Vikix read as: $(counts)"; fail=1; }

# An SSH remote is fetched over HTTPS: the check has no terminal, so a
# key with a passphrase would otherwise always give ?.
# spy_git DIR LOG — a git that, asked to pull or fetch, writes to LOG the
# URL the real git would use with the same options, and stops there (no
# network); anything else goes to the real git.
spy_git() {
  local real; real=$(command -v git)
  mkdir -p "$1"
  cat > "$1/git" <<SPY
#!/usr/bin/env bash
opts=()
while [ "\$#" -gt 0 ]; do
  case \$1 in
    -C|-c) opts+=("\$1" "\$2"); shift 2 ;;
    pull|fetch) "$real" "\${opts[@]}" ls-remote --get-url origin >> "$2"; exit 0 ;;
    *) break ;;
  esac
done
exec "$real" "\${opts[@]}" "\$@"
SPY
  chmod +x "$1/git"
}
spy_git "$t/spy" "$t/fetched-from"
git -C "$t/vikix" remote set-url origin git@github.com:vukini/vikix.git
PATH="$t/spy:$t/bin:$PATH" XDG_STATE_HOME="$t/state" sh "$t/vikix/bin/vikix-updates" >/dev/null
[ "$(cat "$t/fetched-from")" = https://github.com/vukini/vikix.git ] ||
  { echo "FAIL: with an SSH remote, vikix-updates fetches from: $(cat "$t/fetched-from")"; fail=1; }

[ "$fail" = 0 ] && echo "updates: packages and Vikix commits counted; ? when a check fails; SSH remotes read over HTTPS"
exit "$fail"
