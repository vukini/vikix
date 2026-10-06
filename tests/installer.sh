#!/usr/bin/env bash
# tests/installer.sh — the stick's installer, the parts that need no machine:
#
#   - vikix-installer --dry-run with an answers file reads to the end and
#     names the steps that matter: the two partitions, LUKS2 with the fast
#     NVMe settings, /boot on the EFI partition, the crypt module before the
#     kernel arrives, NetworkManager on, the firstboot block and marker
#   - without encryption there is no LUKS, crypttab or rd.luks
#   - it refuses to run for real as a user
#   - installer/firstboot runs install.sh with the features from the
#     marker; on success it removes its block (and only it) and the marker
#     and restarts; on failure both stay
#   - the stick's login script starts the installer on tty1 only
#
# The whole thing on a machine (boot, install, encrypted first start) is
# done by hand in QEMU: docs/install-stick.md, "How it was tested".

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

# --- vikix-installer, dry run ----------------------------------------------------
cp "$here/installer/answers.example" "$t/answers"
sed -i 's|^VI_DISK=.*|VI_DISK=/dev/nvme0n1|' "$t/answers"
out=$(VI_LOG="$t/log" bash "$here/installer/vikix-installer" --dry-run --answers "$t/answers" 2>&1) \
  || { echo "FAIL: the dry run stopped:"; echo "$out" | tail -n 5; fail=1; }
check "two partitions, EFI then root"   has 'sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8309' "$out"
check "nvme partitions are p1, p2"      has 'mkfs.vfat -F32 -n EFI /dev/nvme0n1p1' "$out"
check "LUKS2"                           has 'cryptsetup luksFormat --type luks2' "$out"
check "no extra queues on NVMe"         has 'perf-no_read_workqueue --perf-no_write_workqueue --persistent' "$out"
check "ext4 on the opened device"       has 'mkfs.ext4 -F -L vikix /dev/mapper/cryptroot' "$out"
check "/boot is the EFI partition"      has 'mount /dev/nvme0n1p1 /mnt/vikix/boot' "$out"
check "crypttab"                        has 'cryptroot UUID=' "$out"
check "crypt module for dracut"         has 'add_dracutmodules+=" crypt "' "$out"
crypt_at=$(grep -n 'add_dracutmodules' <<<"$out" | head -n1 | cut -d: -f1)
pkgs_at=$(grep -n 'xbps-install -Sy' <<<"$out" | head -n1 | cut -d: -f1)
check "dracut set up before the kernel" test "${crypt_at:-999}" -lt "${pkgs_at:-0}"
check "NetworkManager on"               has 'ln -sf /etc/sv/NetworkManager' "$out"
check "GRUB, and its fallback path"     has 'grub-install --target=x86_64-efi --efi-directory=/boot --removable' "$out"
check "the firstboot block"             has '# >>> vikix firstboot >>>' "$out"
check "the marker"                      has 'state/vikix/firstboot' "$out"
check "root locked"                     has 'passwd -l root' "$out"
check "the password never printed"      lacks 'vikix-test' "$out"

sed -i 's|^VI_ENCRYPT=.*|VI_ENCRYPT=no|' "$t/answers"
out=$(VI_LOG="$t/log" bash "$here/installer/vikix-installer" --dry-run --answers "$t/answers" 2>&1) || fail=1
check "unencrypted: no LUKS"            lacks 'cryptsetup luksFormat' "$out"
check "unencrypted: no crypttab"        lacks 'crypttab' "$out"
check "unencrypted: root type 8304"     has '-t2:8304' "$out"
check "unencrypted: ext4 on the partition" has 'mkfs.ext4 -F -L vikix /dev/nvme0n1p2' "$out"

if [ "$(id -u)" -ne 0 ]; then
  out=$(bash "$here/installer/vikix-installer" --answers "$t/answers" 2>&1) && fail=1
  check "refuses to run for real as a user" has 'run it as root' "$out"
fi

# --- firstboot ------------------------------------------------------------------
mkdir -p "$t/home/vikix" "$t/home/.local/state/vikix" "$t/bin"
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$t/calls" > "$t/bin/sudo"
chmod +x "$t/bin/sudo"
fake_install() {   # fake_install EXIT
  printf '#!/bin/sh\necho "install.sh $*" >> %q\nexit %s\n' "$t/calls" "$1" > "$t/home/vikix/install.sh"
  chmod +x "$t/home/vikix/install.sh"
}
profile() {
  printf '%s\n' '# >>> vikix firstboot >>>' 'firstboot line' '# <<< vikix firstboot <<<' \
                'export KEEP=1' '# >>> vikix login >>>' 'login line' '# <<< vikix login <<<' > "$t/home/.bash_profile"
}
marker=$t/home/.local/state/vikix/firstboot

fake_install 1; profile; echo 'VIKIX_WITH=essentials' > "$marker"; : > "$t/calls"
HOME="$t/home" PATH="$t/bin:$PATH" bash "$here/installer/firstboot" </dev/null >/dev/null 2>&1 || true
calls=$(cat "$t/calls")
check "firstboot: features from the marker" has 'install.sh --with essentials' "$calls"
check "firstboot: a failure keeps the marker" test -e "$marker"
check "firstboot: a failure keeps the block"  grep -q 'firstboot line' "$t/home/.bash_profile"
check "firstboot: no restart after a failure" lacks 'sudo reboot' "$calls"

fake_install 0; profile; echo 'VIKIX_WITH=' > "$marker"; : > "$t/calls"
HOME="$t/home" PATH="$t/bin:$PATH" bash "$here/installer/firstboot" </dev/null >/dev/null 2>&1 || true
calls=$(cat "$t/calls")
check "firstboot: the base, no --with"        has 'install.sh $' "$calls"
check "firstboot: success removes the marker" test ! -e "$marker"
check "firstboot: success removes its block"  test "$(grep -c firstboot "$t/home/.bash_profile")" = 0
check "firstboot: other blocks stay"          grep -q 'login line' "$t/home/.bash_profile"
check "firstboot: the rest of the file stays" grep -q 'export KEEP=1' "$t/home/.bash_profile"
check "firstboot: restarts"                   has 'sudo reboot' "$calls"

: > "$t/calls"
HOME="$t/home" PATH="$t/bin:$PATH" bash "$here/installer/firstboot" </dev/null >/dev/null 2>&1
check "firstboot: nothing without the marker" test ! -s "$t/calls"

# --- the stick's login script --------------------------------------------------------
live=$here/installer/live/etc/profile.d/vikix-live.sh
check "the stick starts the installer on tty1" grep -q 'tty)" = /dev/tty1 ] && \[ ! -e /run/vikix-installer-started' "$live"
check "the stick starts it once"               grep -q 'touch /run/vikix-installer-started' "$live"

[ "$fail" = 0 ] && echo "installer: ok"
exit "$fail"
