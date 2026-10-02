#!/usr/bin/env bash
# tests/drives.sh — vikix-drives finds the mounted drives (a space in a name
# too), ejects the one picked and says when it's safe, starts a backup when
# the backup drive is plugged in and one is due (and only then), and gives
# udiskie Vikix's settings unless you have your own.
#
# Everything that would touch the desktop is a stand-in: rofi, udiskie,
# udiskie-umount, notify-send, pgrep, and python3 (the bar's nudge goes
# through vikix-eval to the running StumpWM). The backup is a stand-in too.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
mkdir -p "$t/bin" "$t/home/.config/vikix" "$t/home/.local/state/vikix"
log="$t/log"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }
stub notify-send    "echo \"notify \$*\" >> $log"
stub udiskie-umount "echo \"umount \$*\" >> $log; [ -z \"\${UMOUNT_FAILS:-}\" ]"
stub rofi           "cat > $t/offered; [ -n \"\${ROFI_ANSWER:-}\" ] || exit 1; echo \"\$ROFI_ANSWER\""
stub python3        "echo \"eval \$*\" >> $log"
stub pgrep          "exit 1"
stub udiskie        "echo \"udiskie \$*\" >> $log"
stub backup         "echo \"backup \$*\" >> $log"
cat > "$t/mounts" <<'EOF'
/dev/sda1 /run/media/me/VIKIX\040TEST vfat rw 0 0
/dev/sdb1 /run/media/me/BACKUPS ext4 rw 0 0
/dev/vda1 / ext4 rw 0 0
/dev/vda2 /home/me/elsewhere ext4 rw 0 0
EOF
export PATH="$t/bin:$PATH" HOME="$t/home" VIKIX_MOUNTS="$t/mounts" VIKIX_MEDIA=/run/media/me \
       VIKIX_DRIVES_BACKUP="$t/bin/backup"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
drives() { : > "$log"; bash "$here/bin/vikix-drives" "$@"; }

# --- which drives -------------------------------------------------------------
check "the drives should be the two under /run/media, space decoded" \
  test "$(drives list)" = "$(printf '/run/media/me/VIKIX TEST\n/run/media/me/BACKUPS')"
check "the bar should say usb with a drive mounted" test "$(drives bar)" = usb
check "the bar should say nothing with none" test -z "$(VIKIX_MOUNTS=/dev/null drives bar)"

# --- eject -----------------------------------------------------------------------
ROFI_ANSWER=0 drives eject
check "the picker should offer the drives by name" test "$(cat "$t/offered")" = "$(printf 'VIKIX TEST\nBACKUPS')"
check "the drive picked should be unmounted and powered off" grep -qx 'umount --detach /run/media/me/VIKIX TEST' "$log"
check "it should say when it's safe to pull out" grep -q 'notify.*Safe to remove VIKIX TEST' "$log"
ROFI_ANSWER=1 UMOUNT_FAILS=1 drives eject
check "a drive in use should say so, not that it's safe" grep -q 'notify .*-u critical BACKUPS is still in use' "$log"
check "a drive in use shouldn't be called safe" test -z "$(grep 'Safe to remove' "$log" || true)"
ROFI_ANSWER='' drives eject
check "closing the picker should eject nothing" test -z "$(grep umount "$log" || true)"
VIKIX_MOUNTS=/dev/null drives eject
check "with no drive it should say there's none" grep -q 'notify .*No drive to eject' "$log"

# --- plug in to back up ----------------------------------------------------------
settings="$t/home/.config/vikix/backup" last="$t/home/.local/state/vikix/backup"
plug() {   # the backup starts detached, hence the pause
  drives event device_mounted "$1" || { echo "FAIL: udiskie's event hook failed for $1"; fail=1; }
  sleep 0.3
}
echo "REPO=/run/media/me/BACKUPS/vikix" > "$settings"
rm -f "$last"
plug /run/media/me/BACKUPS
check "the backup drive, never backed up: the backup should start" grep -qx 'backup now --notify' "$log"
echo "$(( $(date +%s) - 9 * 86400 )) 7" > "$last"
plug /run/media/me/BACKUPS
check "the last backup 9 days old, due after 7: it should start" grep -qx 'backup now --notify' "$log"
echo "$(( $(date +%s) - 2 * 86400 )) 7" > "$last"
plug /run/media/me/BACKUPS
check "a backup 2 days old isn't due: nothing should start" test -z "$(grep backup "$log" || true)"
rm -f "$last"
plug "/run/media/me/VIKIX TEST"
check "another drive shouldn't start the backup" test -z "$(grep backup "$log" || true)"
rm -f "$settings"
plug /run/media/me/BACKUPS
check "with no backup set up, nothing should start" test -z "$(grep backup "$log" || true)"
check "a mount should ask the bar to look now" grep -q 'eval .*(vikix-usb-refresh)' "$log"

# --- udiskie's settings ---------------------------------------------------------
drives start
check "udiskie should get Vikix's settings" grep -q "udiskie --config $here/config/udiskie/config.yml --automount" "$log"
check "udiskie should open drives with xdg-open (the folder default) and the rofi prompt" grep -q -- '--file-manager xdg-open --password-prompt vikix-drives password' "$log"
mkdir -p "$t/home/.config/udiskie"; : > "$t/home/.config/udiskie/config.yml"
drives start
check "your own udiskie config should be used instead" test -z "$(grep -- '--config' "$log" || true)"

[ "$fail" = 0 ] && echo "drives: listed, ejected safely, backed up on plug-in only when due; udiskie gets Vikix's settings"
exit "$fail"
