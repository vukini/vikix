#!/usr/bin/env bash
# tests/bitwarden.sh — vikix bitwarden, with stand-ins for rbw and rofi-rbw:
#
#   pick     says how to set it up when there's no account yet, and opens
#            nothing; asks for the master password first when the vault is
#            locked, and opens nothing when that's cancelled; opens the
#            picker when unlocked
#   setup    records the feature; saves the email (asked, or given), the
#            password box, an hour's lock, and with --eu the EU server;
#            signs in and syncs; writes the picker's settings once and then
#            leaves them alone; on a refused sign-in, says how to register
#   uninstall  forgets the vault's copy here, stops the agent, forgets the
#            feature, and keeps the picker's settings (yours)
#
# Nothing real runs: rbw and rofi-rbw are scripts that note how they were
# called.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME" "$VIKIX_STATE" "$t/bin" "$t/rbw"
log="$t/log"; : > "$log"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; sed 's/^/  /' "$log"; fail=1; }; }
has() { grep -q -- "$1" "$log"; }

stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
# rbw: its settings in $t/rbw, one file each; "unlocked" when $t/rbw/open
# exists; unlock opens it unless $t/rbw/cancel; login fails when
# $t/rbw/refuse.
stub rbw "echo \"rbw \$*\" >> $log
case \"\$1 \$2\" in
  'config show') [ -e $t/rbw/email ] || exit 1; printf '{\"email\": \"%s\", \"base_url\": \"%s\"}\n' \"\$(cat $t/rbw/email)\" \"\$(cat $t/rbw/base_url 2>/dev/null)\" ;;
  'config set') echo \"\$4\" > $t/rbw/\$3 ;;
  'unlocked '*) [ -e $t/rbw/open ]; exit \$? ;;
  'unlock '*) [ -e $t/rbw/cancel ] && exit 1; touch $t/rbw/open ;;
  'login '*) [ -e $t/rbw/refuse ] && exit 1; touch $t/rbw/open ;;
esac
exit 0"
stub rofi-rbw "echo rofi-rbw >> $log"
stub notify-send "echo \"notify \$*\" >> $log"
stub xbps-query "exit 0"     # every package is there
export PATH="$t/bin:$PATH"
bw() { : > "$log"; bash "$here/bin/vikix-bitwarden" "$@" < /dev/null; }
rc="$HOME/.config/rofi-rbw.rc"
features="$HOME/.config/vikix/features"

bw pick >/dev/null 2>&1 || true
check "pick with no account should say how to set it up" has "notify -a Vikix Bitwarden isn't set up"
check "pick with no account should open nothing" bash -c "! grep -q rofi-rbw $log"

export VIKIX_BITWARDEN_EMAIL=me@example.org
bw setup --eu >/dev/null 2>&1
check "setup should save the email" grep -qx me@example.org "$t/rbw/email"
check "setup should use the password box" grep -qx pinentry-gtk-2 "$t/rbw/pinentry"
check "setup should lock after an hour" grep -qx 3600 "$t/rbw/lock_timeout"
check "--eu should use the EU server" grep -qx https://vault.bitwarden.eu "$t/rbw/base_url"
check "setup should sign in, then sync" bash -c "grep -n 'rbw login' $log | grep -q . && grep -q 'rbw sync' $log"
check "setup should record the feature" grep -qx bitwarden "$features"
check "setup should write the picker's settings" grep -q "^clear-after = 45" "$rc"
echo "# mine" >> "$rc"
bw setup >/dev/null 2>&1
check "a second setup should leave your picker settings" grep -qx "# mine" "$rc"
check "a second setup shouldn't ask the email again" bash -c "! grep -q 'config set email' $log"

rm -f "$t/rbw/open"; touch "$t/rbw/cancel"
bw pick >/dev/null 2>&1 || true
check "a locked vault should ask for the master password" has "rbw unlock"
check "a cancelled master password should open nothing" bash -c "! grep -q rofi-rbw $log"
rm -f "$t/rbw/cancel"
bw pick >/dev/null 2>&1 || true
check "unlocked, pick should open the picker" has "rofi-rbw"

touch "$t/rbw/refuse"; rm -f "$t/rbw/open"
out=$(bw setup 2>&1) && { echo "FAIL: a refused sign-in should fail"; fail=1; }
grep -q "rbw register" <<< "$out" || { echo "FAIL: a refused sign-in should say how to register"; fail=1; }
rm -f "$t/rbw/refuse"

bw uninstall >/dev/null 2>&1
check "uninstall should forget the vault's copy here" has "rbw purge"
check "uninstall should stop the agent" has "rbw stop-agent"
check "uninstall should forget the feature" bash -c "! grep -qx bitwarden $features"
check "uninstall should keep your picker settings" test -e "$rc"

[ "$fail" = 0 ] && echo "bitwarden: pick, setup (once, the EU server, a refused sign-in), unlock first, uninstall"
exit "$fail"
