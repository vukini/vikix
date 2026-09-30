#!/usr/bin/env bash
# tests/fingerprint.sh — vikix fingerprint puts its PAM block in the right
# place and takes it out again leaving the files exactly as they were,
# never twice, never without a backup; and changes nothing at all without
# a reader it can use, or without a finger enrolled.
#
# The PAM files are copies (Void's sudo and i3lock) in a made-up folder,
# written without sudo; fprintd-list, fprintd-enroll and lsusb are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
mkdir -p "$t/bin" "$t/pam" "$t/home"
log="$t/log"
printf '#%%PAM-1.0\nauth \t\tinclude \tsystem-auth\naccount \tinclude \tsystem-auth\nsession \tinclude \tsystem-auth\n' > "$t/sudo.orig"
printf '#\n# PAM configuration file for the i3lock screen locker.\n#\n\nauth include system-auth\n' > "$t/i3lock.orig"
reset_pam() { rm -f "$t/pam"/*; cp "$t/sudo.orig" "$t/pam/sudo"; cp "$t/i3lock.orig" "$t/pam/i3lock"; }

# fprintd-list's stand-in answers from $FP: none, reader, or enrolled.
cat > "$t/bin/fprintd-list" <<'EOF'
#!/bin/sh
case ${FP:-enrolled} in
  none)     echo "No devices available" ;;
  reader)   printf 'found 1 devices\nDevice at /net/reactivated/Fprint/Device/0\nUser %s has no fingers enrolled for Synaptics Sensors.\n' "$1" ;;
  enrolled) printf 'found 1 devices\nDevice at /net/reactivated/Fprint/Device/0\nFingerprints for user %s on Synaptics Sensors (press):\n - #0: right-index-finger\n' "$1" ;;
esac
EOF
printf '#!/bin/sh\necho "enroll $*" >> %s\n' "$log" > "$t/bin/fprintd-enroll"
printf '#!/bin/sh\necho "${LSUSB:-}"\n' > "$t/bin/lsusb"
chmod +x "$t/bin"/*
export PATH="$t/bin:$PATH" HOME="$t/home" USER=me VIKIX_PAM_DIR="$t/pam" VIKIX_PAM_SUDO=
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
fp() { : > "$log"; bash "$here/bin/vikix-fingerprint" "$@"; }

# --- on and off -------------------------------------------------------------------
reset_pam
fp on >/dev/null
check "sudo's block should come just before its first auth line" \
  test "$(sed -n 2p "$t/pam/sudo"; grep -n 'include' "$t/pam/sudo" | head -1 | cut -d: -f1)" = "$(printf '# >>> vikix fingerprint >>>\n8')"
check "the password should be tried first" grep -q 'success=done.*pam_unix.so' "$t/pam/sudo"
check "then the reader" grep -q 'sufficient.*pam_fprintd.so' "$t/pam/sudo"
check "the lock screen should get the block too" grep -qxF '# >>> vikix fingerprint >>>' "$t/pam/i3lock"
backups() { set -- "$t/pam"/*.vikix-bak.*; [ -e "$1" ] && echo $#; }
check "each file should be backed up first" test "$(backups)" = 2
fp on >/dev/null
check "on twice should still give one block" test "$(grep -c '>>> vikix fingerprint' "$t/pam/sudo")" = 1
fp off >/dev/null
check "off should leave sudo's file exactly as it was" cmp -s "$t/pam/sudo" "$t/sudo.orig"
check "off should leave i3lock's file exactly as it was" cmp -s "$t/pam/i3lock" "$t/i3lock.orig"

# --- nothing changes without a reader, or without a finger --------------------------
reset_pam
out=$(FP=none LSUSB='Bus 001 Device 009: ID 138a:0097 Validity Sensors, Inc.' fp on 2>&1 || true)
check "with no usable reader, on should change nothing" cmp -s "$t/pam/sudo" "$t/sudo.orig"
check "an unsupported Validity reader should be named" grep -q '138a:0097' <<<"$out"
check "and python-validity mentioned" grep -q 'python-validity' <<<"$out"
out=$(FP=reader fp on 2>&1 || true)
check "with no finger enrolled, on should change nothing" cmp -s "$t/pam/sudo" "$t/sudo.orig"
check "and say to enrol one" grep -q 'vikix fingerprint enrol' <<<"$out"

# --- a file without auth lines is never written --------------------------------------
reset_pam
printf '#%%PAM-1.0\naccount include system-auth\n' > "$t/pam/sudo"
cp "$t/pam/sudo" "$t/noauth"
fp on >/dev/null 2>&1 || true
check "a file with no auth line should be left alone" cmp -s "$t/pam/sudo" "$t/noauth"

# --- the first run enrols a finger ---------------------------------------------------
reset_pam
FP=reader fp >/dev/null 2>&1 || true
check "with a reader and no finger, the first run should enrol one" grep -qx 'enroll -f right-index-finger me' "$log"
FP=enrolled fp >/dev/null 2>&1
check "with a finger enrolled, it shouldn't enrol again" test ! -s "$log"

[ "$fail" = 0 ] && echo "fingerprint: the PAM block goes in and out cleanly; nothing changes without a reader and a finger"
exit "$fail"
