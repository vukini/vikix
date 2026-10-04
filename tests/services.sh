#!/usr/bin/env bash
# tests/services.sh — 20-services switches on what services.list names,
# has D-Bus reread its config once before the first new service (Void's
# dbus-daemon reads a new package's policy only at boot, so avahi ran but
# nothing could reach it), adds you to lpadmin once CUPS is there, and
# installs the polkit rule for the Printers app. Run again, it changes
# nothing.
#
# Against fake runit folders, a fake D-Bus socket and a fake polkit
# folder. Stand-ins for sudo, dbus-send, getent, id and usermod write
# down what would have run.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# Keep everything in the made-up home, even with XDG_* set (see run.sh).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

mkdir -p "$t/bin" "$t/sv/dbus" "$t/service" "$t/polkit" "$t/home"
ln -s "$t/sv/dbus" "$t/service/dbus"                        # already on
python3 -c "import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])" "$t/bus"
touch "$t/log"

# Each stand-in: a small script, with $t written in when it's made.
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
# sudo runs the command for real (every path is in $t) and writes it down.
stub sudo      "[ \"\$1\" = -n ] && shift; echo \"sudo \$*\" >> '$t/log'; exec \"\$@\""
stub dbus-send "echo \"dbus-send \$*\" >> '$t/log'"
# usermod adds the group to the group database ($t/groups). id -nG USER
# reads that; plain id -nG is this session's groups, fixed until the next
# login, so the user never looks added there.
echo "tester video" > "$t/groups"
stub usermod   "echo \"usermod \$*\" >> '$t/log'; echo \" \$2\" >> '$t/groups'"
# lpadmin exists once "cups is installed" ($t/cups).
stub getent    "[ \"\$1 \$2\" = 'group lpadmin' ] && [ -e '$t/cups' ] && { echo 'lpadmin:x:990:'; exit 0; }; exit 2"
stub id        "case \"\$1 \$#\" in '-un 1') echo tester ;; '-nG 1') echo 'tester video' ;; '-nG 2') tr -d '\\n' < '$t/groups'; echo ;; esac"

stage() {
  : > "$t/log"
  PATH="$t/bin:$PATH" HOME="$t/home" VIKIX_SV_DIR="$t/sv" VIKIX_SERVICE_DIR="$t/service" \
    VIKIX_DBUS_SOCKET="$t/bus" VIKIX_POLKIT_RULES="$t/polkit" \
    bash "$here/install/20-services.sh" >/dev/null 2>&1
}
rule="$t/polkit/50-vikix-printers.rules"

# --- part one: no cups yet, nothing new to start ------------------------------
stage
check "part one reloaded D-Bus with nothing new to start" test "$(grep -c "^sudo dbus-send.*ReloadConfig" "$t/log")" = 0
check "part one added a group that doesn't exist yet" test "$(grep -c 'usermod.*lpadmin' "$t/log")" = 0
check "part one installed the polkit rule without cups" test ! -e "$rule"

# --- part two: cups and avahi arrive ------------------------------------------
mkdir -p "$t/sv/cupsd" "$t/sv/avahi-daemon"
touch "$t/cups"
stage
check "cupsd isn't switched on" test -L "$t/service/cupsd"
check "avahi-daemon isn't switched on" test -L "$t/service/avahi-daemon"
check "a service whose package is missing was switched on" test ! -e "$t/service/ipp-usb"
check "D-Bus didn't reread its config exactly once" test "$(grep -c "^sudo dbus-send.*ReloadConfig" "$t/log")" = 1
first_ln=$(grep -n 'ln -s' "$t/log" | head -1 | cut -d: -f1)
reload=$(grep -n ReloadConfig "$t/log" | head -1 | cut -d: -f1)
check "D-Bus reread its config after the first new service, not before" test "${reload:-99}" -lt "${first_ln:-0}"
check "the user wasn't added to lpadmin" grep -q 'usermod -aG lpadmin tester' "$t/log"
check "the polkit rule isn't installed" cmp -s "$here/config/polkit/50-vikix-printers.rules" "$rule"

# --- earlyoom arrives: Vikix's settings first, then switched on -----------------
mkdir -p "$t/sv/earlyoom"
stub sv "echo \"sv \$*\" >> '$t/log'"
stage
check "earlyoom should get Vikix's settings" cmp -s "$here/config/earlyoom/conf" "$t/sv/earlyoom/conf"
check "and the script that says what it ended, executable" test -x "$t/sv/earlyoom/vikix-killed"
check "earlyoom should be switched on" test -L "$t/service/earlyoom"
set_ln=$(grep -n 'install.*earlyoom/conf' "$t/log" | head -1 | cut -d: -f1)
on_ln=$(grep -n 'ln -s.*earlyoom' "$t/log" | head -1 | cut -d: -f1)
check "its settings should be there before it starts" test "${set_ln:-99}" -lt "${on_ln:-0}"
check "not running yet, it shouldn't be restarted" test "$(grep -c 'sv restart' "$t/log")" = 0
echo "# changed by hand" >> "$t/sv/earlyoom/conf"
stage
check "settings changed while it runs: written again, and restarted" grep -q 'sv restart earlyoom' "$t/log"
# The run script expands OPTS unquoted: a space or a glob character inside a pattern would break it.
opts=$(sed -n 's/^OPTS="\(.*\)"$/\1/p' "$here/config/earlyoom/conf")
check "OPTS should be one line the run script can expand: $opts" test -n "$opts"
check "no glob characters in OPTS" bash -c '! grep -q "[][*?]" <<<"$1"' _ "$opts"
for name in Xorg stumpwm emacs alacritty; do
  check "$name should never be ended" grep -Eq -- "--ignore \^\([^ ]*\b$name\b" <<<"$opts"
done
check "an agent's session and a virtual machine only last" grep -Eq -- '--avoid \^\(claude\|firefox\|qemu-system-x86\|' <<<"$opts"
check "a test's programs first" grep -Eq -- '--prefer \^\(Xvfb\|' <<<"$opts"

# --- again: nothing to do -----------------------------------------------------
stage
check "a second run reloaded D-Bus" test "$(grep -c "^sudo dbus-send.*ReloadConfig" "$t/log")" = 0
check "a second run linked a service again" test "$(grep -c 'ln -s' "$t/log")" = 0
check "a second run in the same session added the user to lpadmin again" test "$(grep -c 'usermod' "$t/log")" = 0
check "a second run installed the polkit rule again" test "$(grep -c 'sudo install' "$t/log")" = 0

# --- no D-Bus running (a chroot, say): new services still go on ---------------
rm "$t/bus"
mkdir -p "$t/sv/ipp-usb"
stage
check "with no D-Bus, it still tried to reach it" test "$(grep -c "^sudo dbus-send.*ReloadConfig" "$t/log")" = 0
check "with no D-Bus, a new service wasn't switched on" test -L "$t/service/ipp-usb"

[ "$fail" = 0 ] && echo "services: switched on once, D-Bus reread first, lpadmin and the Printers app rule once cups is there"
exit "$fail"
