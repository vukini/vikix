#!/usr/bin/env bash
# tests/updates.sh — vikix-updates counts the Void packages and Vikix
# commits that `vikix update` would bring, and says ? for what it can't
# check, instead of a wrong 0.
#
# A fake xbps-install stands in for the network; a checkout two commits
# behind a local "upstream" stands in for Vikix.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
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
# XDG_CONFIG_HOME: the channel file of this test's, never the real ~/.config.
counts() { PATH="$t/bin:$PATH" XDG_STATE_HOME="$t/state" XDG_CONFIG_HOME="$t/config" VIKIX_FWUPDMGR="$t/bin/fwupdmgr" \
             sh "$t/vikix/bin/vikix-updates" >/dev/null; cat "$t/state/vikix/updates"; }

fake_xbps 3
[ "$(counts)" = "3 2 0 -" ] || { echo "FAIL: 3 packages and 2 commits read as: $(counts)"; fail=1; }
fake_xbps 0
[ "$(counts)" = "0 2 0 -" ] || { echo "FAIL: no packages read as: $(counts)"; fail=1; }
fake_xbps fail
[ "$(counts)" = "? 2 0 -" ] || { echo "FAIL: a failed package check read as: $(counts)"; fail=1; }
fake_xbps 0; fake_fwupd 2
[ "$(counts)" = "0 2 2 -" ] || { echo "FAIL: 2 firmware updates read as: $(counts)"; fail=1; }
fake_fwupd 0
git -C "$t/vikix" remote set-url origin "$t/nowhere"
fake_xbps 1
[ "$(counts)" = "1 ? 0 -" ] || { echo "FAIL: an unreachable Vikix read as: $(counts)"; fail=1; }

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
# The channel: good (the default) counts to the good tag, main to the tip; a
# tag that moved is followed (a plain fetch wouldn't move it).
git -C "$t/vikix" remote set-url origin "$t/upstream"
fake_xbps 0
git -C "$t/upstream" tag -f good HEAD~1 >/dev/null
[ "$(counts)" = "0 1 0 -" ] || { echo "FAIL: on the good channel the count should stop at the good tag (1): $(counts)"; fail=1; }
git -C "$t/upstream" tag -f good HEAD >/dev/null
[ "$(counts)" = "0 2 0 -" ] || { echo "FAIL: a moved good tag wasn't followed: $(counts)"; fail=1; }
mkdir -p "$t/config/vikix"; echo main > "$t/config/vikix/channel"
git -C "$t/upstream" tag -f good HEAD~1 >/dev/null
# (on main the verdict is asked too; the remote isn't GitHub's, so ?)
[ "$(counts)" = "0 2 0 ?" ] || { echo "FAIL: on the main channel the count should reach the tip (2): $(counts)"; fail=1; }
rm "$t/config/vikix/channel"
git -C "$t/upstream" tag -d good >/dev/null
[ "$(counts)" = "0 2 0 -" ] || { echo "FAIL: with no good tag the count should reach the tip (2): $(counts)"; fail=1; }

spy_git "$t/spy" "$t/fetched-from"
git -C "$t/vikix" remote set-url origin git@github.com:vukini/vikix.git
PATH="$t/spy:$t/bin:$PATH" XDG_STATE_HOME="$t/state" sh "$t/vikix/bin/vikix-updates" >/dev/null
[ "$(sort -u "$t/fetched-from")" = https://github.com/vukini/vikix.git ] ||
  { echo "FAIL: with an SSH remote, vikix-updates fetches from: $(cat "$t/fetched-from")"; fail=1; }

[ "$fail" = 0 ] && echo "updates: packages and Vikix commits counted, to the good tag or main's tip by the channel; ? when a check fails; SSH remotes read over HTTPS"

# GitHub's verdict on the commit this machine runs, the fourth word: asked
# only on the main channel (on good, what runs has passed: -), from the
# public API through a stand-in curl that answers with what this test
# chooses; a failed verdict is told once per commit, through a stand-in
# notify-send. The remote is GitHub's by name, with the spy git from above
# standing in for the fetch (so GitHub itself is never reached).
git -C "$t/vikix" remote set-url origin git@github.com:vukini/vikix.git
sha=$(git -C "$t/vikix" rev-parse HEAD)
run_json() {  # run_json PATH STATUS CONCLUSION — one run of GitHub's answer
  printf '{"path": "%s", "name": "%s", "status": "%s", "conclusion": %s}' "$1" "$(basename "$1" .yml)" "$2" "$([ "$3" = null ] && echo null || echo "\"$3\"")"
}
fake_curl() {   # fake_curl down | RUN... — curl's answer: an error, or these runs
  if [ "$1" = down ]; then
    printf '#!/bin/sh\necho "$*" >> %s; exit 7\n' "$t/asked" > "$t/bin/curl"
  else
    { printf '#!/bin/sh\necho "$*" >> %s\ncat <<JSON\n{"total_count": %s, "workflow_runs": [' "$t/asked" "$#"
      sep=''; for r in "$@"; do printf '%s%s' "$sep" "$r"; sep=', '; done
      printf ']}\nJSON\n'; } > "$t/bin/curl"
  fi
  chmod +x "$t/bin/curl"
}
printf '#!/bin/sh\necho "$*" >> %s\n' "$t/notified" > "$t/bin/notify-send"; chmod +x "$t/bin/notify-send"
tests=$(cat <<'EOF'
.github/workflows/test.yml
EOF
)
pages=.github/workflows/pages.yml
counts4() { PATH="$t/spy:$t/bin:$PATH" XDG_STATE_HOME="$t/state" XDG_CONFIG_HOME="$t/config" VIKIX_FWUPDMGR="$t/bin/fwupdmgr" DISPLAY=:7 \
              sh "$t/vikix/bin/vikix-updates" >/dev/null; cat "$t/state/vikix/updates"; }
rm -f "$t/asked"
fake_curl "$(run_json "$tests" completed success)"
[ "$(counts4)" = "0 2 0 -" ] || { echo "FAIL: on the good channel the verdict isn't asked (-): $(counts4)"; fail=1; }
[ ! -e "$t/asked" ] || { echo "FAIL: on the good channel GitHub was asked: $(cat "$t/asked")"; fail=1; }
mkdir -p "$t/config/vikix"; echo main > "$t/config/vikix/channel"
[ "$(counts4)" = "0 2 0 ok" ] || { echo "FAIL: a passed run should read ok: $(counts4)"; fail=1; }
grep -q "repos/vukini/vikix/actions/runs?head_sha=$sha" "$t/asked" ||
  { echo "FAIL: GitHub should be asked about this remote's repository and this commit: $(cat "$t/asked")"; fail=1; }
fake_curl "$(run_json "$tests" completed failure)" "$(run_json "$pages" completed success)"
[ "$(counts4)" = "0 2 0 failed" ] || { echo "FAIL: a failed test run should read failed: $(counts4)"; fail=1; }
[ "$(grep -c . "$t/notified" 2>/dev/null)" = 1 ] && grep -q "tests failed on the commit this machine runs (${sha:0:7})" "$t/notified" ||
  { echo "FAIL: a failed verdict should be told once, naming the commit: $(cat "$t/notified" 2>/dev/null)"; fail=1; }
counts4 >/dev/null
[ "$(grep -c . "$t/notified")" = 1 ] || { echo "FAIL: the same failed commit was told again"; fail=1; }
fake_curl "$(run_json "$tests" in_progress null)" "$(run_json "$tests" completed failure)"
[ "$(counts4)" = "0 2 0 running" ] || { echo "FAIL: a run still going should read running: $(counts4)"; fail=1; }
fake_curl "$(run_json "$tests" in_progress null)" "$(run_json "$tests" completed success)"
[ "$(counts4)" = "0 2 0 ok" ] || { echo "FAIL: one passed run is ok whatever else runs: $(counts4)"; fail=1; }
fake_curl "$(run_json "$pages" completed failure)"
[ "$(counts4)" = "0 2 0 ?" ] || { echo "FAIL: another workflow's failure isn't the tests': $(counts4)"; fail=1; }
fake_curl "$(run_json "$tests" completed cancelled)"
[ "$(counts4)" = "0 2 0 ?" ] || { echo "FAIL: a cancelled run is no verdict: $(counts4)"; fail=1; }
fake_curl down
[ "$(counts4)" = "0 2 0 ?" ] || { echo "FAIL: with GitHub unreachable the verdict is ?: $(counts4)"; fail=1; }
printf '#!/bin/sh\necho "not json at all"\n' > "$t/bin/curl"
[ "$(counts4)" = "0 2 0 ?" ] || { echo "FAIL: an answer that isn't JSON is ?: $(counts4)"; fail=1; }
rm -f "$t/config/vikix/channel" "$t/bin/curl" "$t/bin/notify-send"
git -C "$t/vikix" remote set-url origin "$t/upstream"
[ "$fail" = 0 ] && echo "updates: GitHub's verdict on the commit this machine runs is the fourth word on the main channel (ok, failed, running, ?), - on good; a failed one is told once"

# The bar's words for the file (vikix-updates-text, commands.lisp): the
# fourth word puts "tests failed" in front; any other word adds nothing.
if command -v sbcl >/dev/null 2>&1; then
  awk '/^\(defun vikix-updates-text/{p=1} p{print} p&&/^$/{exit}' "$here/config/stumpwm/vikix/commands.lisp" > "$t/text.lisp"
  words() { sbcl --script /dev/stdin <<EOF
(load "$t/text.lisp") (princ (vikix-updates-text $1))
EOF
  }
  [ "$(words '3 0 0 "failed"')" = "tests failed  updates 3" ] || { echo "FAIL: the bar's words for 3 0 0 failed: $(words '3 0 0 "failed"')"; fail=1; }
  [ "$(words '0 0 0 "failed"')" = "tests failed" ] || { echo "FAIL: the bar's words for 0 0 0 failed: $(words '0 0 0 "failed"')"; fail=1; }
  [ "$(words '3 2 1 "ok"')" = "updates 3 + Vikix + firmware" ] || { echo "FAIL: the bar's words for 3 2 1 ok: $(words '3 2 1 "ok"')"; fail=1; }
  [ "$(words '0 1 0 "-"')" = "Vikix update" ] || { echo "FAIL: the bar's words for 0 1 0 -: $(words '0 1 0 "-"')"; fail=1; }
  [ "$(words '0 0 0 nil')" = "" ] || { echo "FAIL: the bar's words for nothing: $(words '0 0 0 nil')"; fail=1; }
  [ "$fail" = 0 ] && echo "updates: the bar says tests failed in front of the counts, and nothing for the other verdicts"
else
  echo "updates: no sbcl here, so the bar's words weren't tried"
fi
exit "$fail"
