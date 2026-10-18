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
check "Vikix brought up to GitHub's main" has 'git -C ~/vikix pull --ff-only -q origin main' "$out"
check "root locked"                     has 'passwd -l root' "$out"
check "the password never printed"      lacks 'vikix-test' "$out"

out=$(VI_LOG="$t/log" VI_EXTRA_CMDLINE="console=ttyS0,115200" bash "$here/installer/vikix-installer" --dry-run --answers "$t/answers" 2>&1) || fail=1
check "a serial console gets a login prompt" has 'runsvdir/default/agetty-ttyS0' "$out"
check "and is on the kernel's line"          has 'console=ttyS0,115200' "$out"

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

# --- the questions, answered by a stand-in dialog ------------------------------------
# 2026-10-18, the first real boot (the Z13): choosing anything but the base ended
# the installer silently at the feature question, because ask_all's last line was
# `[ ... = base ] && VI_WITH=""`, which returns 1 under set -e. The answers file
# skips the questions, so only a run through them catches that.
mkdir -p "$t/qbin"
cat > "$t/qbin/dialog" <<'EOF'
#!/usr/bin/env bash
# dialog's answer goes to stderr; the installer swaps the streams to capture it.
title= kind= text=
while [ $# -gt 0 ]; do
  case $1 in
    --title) title=$2; shift ;;
    --menu|--inputbox|--passwordbox|--yesno|--msgbox) kind=$1; text=$2; shift ;;
  esac
  shift
done
case $kind in
  --menu) case $title in
            Disk) echo /dev/sda ;; "Time zone") echo UTC ;; Keyboard) echo us ;;
            Vikix) echo "${DIALOG_WITH:-essentials}" ;; *) echo "?" ;;
          esac >&2 ;;
  --inputbox) case $text in
            *login*) echo tester ;; *"Your name"*) echo "Test Person" ;;
            *"name for this computer"*) echo box ;; *erase*) echo erase ;; *) echo "?" ;;
          esac >&2 ;;
  --passwordbox) echo vikix-test >&2 ;;
esac
exit 0
EOF
printf '#!/bin/sh\ncase "$*" in *NAME,SIZE*) echo "sda 20G sata Fake" ;; *SIZE*) echo 20G ;; *MODEL*) echo Fake ;; esac\n' > "$t/qbin/lsblk"
printf '#!/bin/sh\nexit 0\n' > "$t/qbin/curl"
printf '#!/bin/sh\nexit 0\n' > "$t/qbin/clear"
printf '#!/bin/sh\nexit 1\n' > "$t/qbin/findmnt"
chmod +x "$t/qbin"/*
questions() {   # questions WITH: the dry run through the questions, choosing WITH
  DIALOG_WITH=$1 VI_LOG="$t/log" PATH="$t/qbin:$PATH" TERM=dumb \
    bash "$here/installer/vikix-installer" --dry-run </dev/null 2>&1
}
out=$(questions essentials) || { fail=1; echo "the questions with essentials ended early: $(printf '%s' "$out" | tail -n 3)"; }
check "questions: essentials reaches the install" has 'sgdisk -n1:0:+1G' "$out"
check "questions: essentials in the marker"       has 'VIKIX_WITH=essentials' "$out"
check "questions: the disk chosen"                has 'mkfs.vfat -F32 -n EFI /dev/sda1' "$out"
check "questions: the user"                       has 'useradd' "$out"
check "questions: the password never printed"     lacks 'vikix-test' "$out"
out=$(questions base) || { fail=1; echo "the questions with base ended early"; }
check "questions: base means no features"         has 'VIKIX_WITH=$' "$out"

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
