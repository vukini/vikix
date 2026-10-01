#!/usr/bin/env bash
# tests/windows.sh — vikix-windows, with stand-ins for libvirt and friends:
#
#   setup    refuses without KVM or with too little space, before changing
#            anything; opts in once (10-packages then installs the list, and
#            only then); downloads and checks the drivers, and deletes a
#            download whose checksum is wrong
#   create   refuses an ISO that isn't Windows; writes an answer file that
#            is valid XML, in the ISO's language, with the first-login script
#            in Windows line endings; keeps the password out of the output,
#            the process list (virt-install's arguments) and other users'
#            reach; asks virt-install for the TPM, Secure Boot, passt,
#            virtiofs, TRIM and a display with no network port
#   finish   once Windows says it's ready: the discs out, the answer disc
#            (and its password) deleted, a notification; not before
#   power    does nothing, and doesn't start libvirt, when Windows is off
#   remove   asks first; with --yes, removes the VM and its disk
#
# Nothing real runs: every program is a script in $t/bin that notes how
# it was called.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state" USER=tester
mkdir -p "$HOME" "$t/bin" "$VIKIX_STATE"
calls="$t/calls"
: > "$calls"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
lacks() { ! grep -qF -- "$1" <<<"$2"; }   # lacks TEXT IN
# For what starts in the background: the line turns up within 2 seconds.
eventually() { local _; for _ in $(seq 20); do grep -q -- "$1" "$2" && return 0; command sleep 0.1; done; return 1; }

stub() {   # stub NAME BODY — a program that logs its arguments, then runs BODY
  printf '#!/bin/bash\necho "%s $*" >> %q\n%s\n' "$1" "$calls" "${2:-}" > "$t/bin/$1"
  chmod +x "$t/bin/$1"
}
stub curl 'out=; while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done; echo "download" > "$out"'
stub notify-send
stub sleep
stub setsid
stub virt-viewer
stub qemu-img 'touch "${@: -2:1}"'
# virt-install: remember the arguments; the VM now exists.
stub virt-install "printf '%s\n' \"\$@\" > $t/virt-install.args; touch $t/defined; echo running > $t/vmstate"
# 7z: lang.ini (as a Windows ISO has it: CRLF, a blank first line) out of
# an ISO that has one. xorriso: a copy of the disc it makes.
stub 7z "[ \"\$1\" = e ] && [ \"\${3#-o}\" != \"\$3\" ] && { mkdir -p \"\${3#-o}\"; echo inf > \"\${3#-o}/vioscsi.inf\"; exit 0; }
case \$3 in *windows*) printf '\r\n[Available UI Languages]\r\nen-gb = 3\r\n\r\n[Fallback Languages]\r\nen-gb = en-us\r\n' ;; *) exit 2 ;; esac"
stub xorriso "
out=; src=; while [ \$# -gt 0 ]; do case \$1 in -o) out=\$2; shift ;; -*) ;; *) src=\$1 ;; esac; shift; done
rm -rf $t/disc; cp -r \"\$src\" $t/disc; echo iso > \"\$out\"
"
# virsh: the VM's state and guest agent from files in $t.
stub virsh "
while [ \"\${1:-}\" = -q ] || [ \"\${1:-}\" = -c ]; do [ \"\$1\" = -c ] && shift; shift; done
case \$1 in
  dominfo) [ -e $t/defined ] || exit 1; printf 'CPU(s):         2\nMax memory:     6291456 KiB\n' ;;
  domstate) [ -e $t/defined ] || exit 1; cat $t/vmstate ;;
  start) echo running > $t/vmstate ;;
  shutdown|destroy) echo 'shut off' > $t/vmstate ;;
  qemu-agent-command) [ -e $t/ready ] || exit 1; case \$3 in *guest-file-open*) echo '{\"return\": 5}' ;; *) echo '{\"return\": {}}' ;; esac ;;
  domblklist) printf 'file disk sda /x/windows.qcow2\nfile cdrom sdb /x/win.iso\nfile cdrom sdc /x/virtio.iso\nfile cdrom sdd /x/answers.iso\n' ;;
  undefine) rm -f $t/defined ;;
  dumpxml) if [ \"\$2\" = --inactive ] || [ ! -e $t/domxml-live ]; then cat $t/domxml 2>/dev/null; else cat $t/domxml-live; fi ;;
  version) [ ! -e $t/libvirt-down ] ;;
  net-define) touch $t/nets/default.xml ;;
  net-autostart) touch $t/nets/autostart/default.xml ;;
  net-start) mkdir -p $t/sysnet/virbr0 ;;
esac"
stub virt-xml "echo \"<source bridge='virbr0'/>\" > $t/domxml"
printf "<interface type='user'><backend type='passt'/></interface>" > "$t/domxml"   # a VM made before 0.41.0
stub pkill
stub pgrep "[ -e $t/qemu-running ]"
# sudo: never the real one in a test; it runs the command (on made-up paths).
stub sudo '"$@"'   # logs "sudo ...", then runs it
stub xbps-query 'exit 1'
export PATH="$t/bin:$PATH"

sum=$(echo download | sha256sum | cut -d' ' -f1)
export VIKIX_WINDOWS_VIRTIO_SHA256=$sum VIKIX_WINDOWS_WINFSP_SHA256=$sum VIKIX_KVM="$t/kvm"
# The system's side, in the made-up place: runit's folders and bridge.conf.
mkdir -p "$t/sv/libvirtd" "$t/sv/virtlogd" "$t/service" "$t/nets/autostart" "$t/sysnet"
export VIKIX_SV_DIR="$t/sv" VIKIX_SERVICE_DIR="$t/service" VIKIX_BRIDGE_CONF="$t/qemu/bridge.conf"
export VIKIX_LIBVIRT_NETS="$t/nets" VIKIX_SYS_NET="$t/sysnet"
touch "$t/kvm"
win() { bash "$here/bin/vikix-windows" "$@"; }
optional="$HOME/.config/vikix/features"   # your choices: the feature windows
images="$HOME/.local/share/libvirt/images"

# --- setup ---------------------------------------------------------------------
out=$(VIKIX_KVM="$t/none" win setup 2>&1) && { echo "FAIL: setup went ahead without /dev/kvm"; fail=1; }
check "without KVM it should point at the BIOS: $out" grep -q BIOS <<<"$out"
out=$(VIKIX_WINDOWS_MIN_GB=999999 win setup 2>&1) && { echo "FAIL: setup went ahead without the space"; fail=1; }
check "too little space should suggest --disk: $out" grep -q -- '--disk' <<<"$out"
check "a refused setup still opted in" test ! -e "$optional"

out=$(DRY_RUN=1 VIKIX_WINDOWS_MIN_GB=0 win setup 2>&1) || { echo "FAIL: setup failed:"; echo "$out" | tail -5; fail=1; }
check "setup didn't say it would record the feature windows" grep -q "would add windows to $optional" <<<"$out"
check "a dry run recorded the feature" test ! -e "$optional"
echo windows > "$optional"      # as the real setup records it
check "setup didn't install the list (libvirt, virtiofsd): $(grep xbps-install <<<"$out")" \
  grep -q 'would run: sudo xbps-install -y .*libvirt.*virtiofsd' <<<"$out"
check "setup still installs passt, the network that reached this machine's 127.0.0.1" lacks ' passt' "$(grep xbps-install <<<"$out")"
check "setup didn't download the drivers" test -s "$images/virtio-win-0.1.302.iso"
check "setup didn't download WinFsp" test -s "$images/winfsp-2.1.25156.msi"
check "setup didn't make ~/Windows" test -d "$HOME/Windows"
check "setup didn't switch on the system libvirt: $(grep -c 'ln -s' <<<"$out")" grep -q "would run: sudo ln -s $t/sv/libvirtd $t/service/" <<<"$out"
check "setup didn't let VMs of yours join virbr0 (bridge.conf)" grep -q "allow virbr0.*$t/qemu/bridge.conf" <<<"$out"
check "setup didn't start the default network" grep -q 'would run: sudo virsh -q -c qemu:///system net-start default' <<<"$out"
DRY_RUN=1 VIKIX_WINDOWS_MIN_GB=0 win setup >/dev/null 2>&1
check "a second setup named windows twice" test "$(grep -cx windows "$optional")" = 1

# Not chosen, 10-packages leaves the list alone.
mv "$optional" "$t/optional.saved"
out=$(DRY_RUN=1 bash "$here/install/10-packages.sh" 2>&1)
check "10-packages installed the windows list nobody chose" lacks virtiofsd "$out"
mv "$t/optional.saved" "$optional"
out=$(DRY_RUN=1 bash "$here/install/10-packages.sh" 2>&1)
check "10-packages left out the windows list that was chosen" grep -q 'would run: sudo xbps-install -y .*virtiofsd' <<<"$out"

# A download that isn't what it should be is deleted, and setup stops.
rm "$images/virtio-win-0.1.302.iso"
out=$(DRY_RUN=1 VIKIX_WINDOWS_MIN_GB=0 VIKIX_WINDOWS_VIRTIO_SHA256=0000 win setup 2>&1) &&
  { echo "FAIL: a download with the wrong checksum was accepted"; fail=1; }
check "a bad download was kept" test ! -e "$images/virtio-win-0.1.302.iso" -a ! -e "$images/virtio-win-0.1.302.iso.part"
DRY_RUN=1 VIKIX_WINDOWS_MIN_GB=0 win setup >/dev/null 2>&1

# --- create ------------------------------------------------------------------------
echo iso > "$t/not-this.iso"
out=$(echo 'pw' | win create "$t/not-this.iso" 2>&1) && { echo "FAIL: create took an ISO that isn't Windows"; fail=1; }
check "a non-Windows ISO should be named as such: $out" grep -q "doesn't look like a Windows" <<<"$out"

secret='S3cret p&ss<word>'
echo iso > "$t/windows11.iso"
out=$(printf '%s\n' "$secret" | win create "$t/windows11.iso" 2>&1) || { echo "FAIL: create failed:"; echo "$out" | tail -5; fail=1; }
xml="$t/disc/autounattend.xml"
check "no answer file on the disc" test -s "$xml"
check "the answer file isn't valid XML" python3 -c "import xml.etree.ElementTree as E; E.parse('$xml')"
check "the answer file isn't in the ISO's language (en-GB)" grep -q '<UILanguage>en-GB</UILanguage>' "$xml"
check "the answer file doesn't make the account $USER" grep -q "<Name>$USER</Name>" "$xml"
check "the password isn't escaped in the answer file" grep -q 'S3cret p&amp;ss&lt;word&gt;' "$xml"
check "the answer file doesn't skip the CPU check" grep -q BypassCPUCheck "$xml"
check "the answer file loads the disk driver itself (DriverPaths stops 25H2 setup; drvload leaves Windows without its disk)" \
  bash -c "! grep -qE 'DriverPaths|drvload' '$xml'"
check "the disk driver isn't in \$WinPEDriver\$ on the answer disc" test -s "$t/disc/\$WinPEDriver\$/vioscsi/vioscsi.inf"
check "the first-login script hasn't Windows line endings" grep -q $'\r$' "$t/disc/vikix-firstlogon.cmd"
check "WinFsp isn't on the answer disc" test -s "$t/disc/winfsp.msi"
check "the password showed in create's output" lacks S3cret "$out"
check "the password is in virt-install's arguments" bash -c "! grep -qF 'S3cret' '$t/virt-install.args'"
check "the answer disc can be read by others" test "$(stat -c %a "$images/windows-answers.iso")" = 600
args=$(cat "$t/virt-install.args")
for want in 'emulator,model=tpm-crb,version=2.0' 'secure-boot' 'bridge=virbr0,model=virtio' \
            'driver.type=virtiofs' 'discard=unmap' 'spice,listen=none' 'qemu:///session' \
            'source.type=memfd,access.mode=shared'; do
  check "virt-install wasn't asked for $want" grep -qF -- "$want" <<<"$args"
done
check "a new VM is on passt, which hands Windows this machine's 127.0.0.1" bash -c "! grep -q 'backend.type=passt' '$t/virt-install.args'"
check "nobody pressed a key for the Windows disc" grep -q 'virsh.*send-key windows KEY_DOWN' "$calls"
check "Enter was pressed, which clicks buttons in Windows setup" bash -c "! grep -q 'send-key.*KEY_ENTER' '$calls'"
check "the install isn't watched" grep -q 'setsid .*watch-install' "$calls"
out=$(echo pw | win create "$t/windows11.iso" 2>&1) && { echo "FAIL: create made a second VM"; fail=1; }
check "a second create should say how to start again: $out" grep -q 'vikix windows remove' <<<"$out"

# --- finishing the install ------------------------------------------------------------
# Opening Windows finishes the install too, once it's ready; not before.
: > "$calls"
out=$(win open 2>&1) || echo "open: $out"
check "the viewer didn't open" eventually 'setsid virt-viewer --connect qemu:///session --attach' "$calls"
check "the discs came out before Windows was ready" bash -c "! grep -q change-media '$calls'"
check "the answer disc went before Windows was ready" test -e "$images/windows-answers.iso"
touch "$t/ready"
win watch-install >/dev/null 2>&1
check "the discs weren't ejected: $(grep -c change-media "$calls")" test "$(grep -c 'change-media windows sd[bcd] --eject' "$calls")" = 3
check "the answer disc (with the password) is still there" test ! -e "$images/windows-answers.iso"
check "no notification that Windows is ready" grep -q 'notify-send .*Windows is ready' "$calls"

out=$(win status)
check "status should show memory and CPUs as '6 GB, 2 CPUs': $(grep memory <<<"$out")" grep -q 'memory, CPUs:  6 GB, 2 CPUs' <<<"$out"

# --- the private network ------------------------------------------------------------------
# libvirt that won't start: said plainly, the VM left as it is, and a failure
# (so setup stops); but the migration never fails the update.
printf "<interface type='user'><backend type='passt'/></interface>" > "$t/domxml"
touch "$t/libvirt-down"
: > "$calls"
out=$(win network 2>&1) && { echo "FAIL: network said all's well with libvirt not starting"; fail=1; }
check "a libvirt that won't start should be said plainly: $out" grep -q "libvirt service didn't start" <<<"$out"
check "the VM was moved with no network to move it to" bash -c "! grep -q virt-xml '$calls'"
mig=$(grep -l 'vikix-windows" network' "$here"/migrations/*.sh | head -1)
check "no migration moves existing VMs onto virbr0" test -n "$mig"
VIKIX_DIR="$here" bash "$mig" >/dev/null 2>&1 || { echo "FAIL: the migration failed the update when libvirt wouldn't start"; fail=1; }
rm "$t/libvirt-down"
out=$(win check 2>&1) && { echo "FAIL: vikix doctor's check passed a VM on passt"; fail=1; }
check "doctor should say a passt VM's programs can reach this machine: $out" grep -q 'the old one (passt)' <<<"$out"

# A VM on passt is moved; from nothing, the network is made.
: > "$calls"
out=$(win network 2>&1) || { echo "FAIL: network failed: $out"; fail=1; }
check "network didn't move a passt VM onto virbr0: $out" grep -q 'virt-xml .*--edit --network clearxml=yes,type=bridge,source=virbr0' "$calls"
check "network didn't define, autostart and start the default network" \
  test -e "$t/nets/default.xml" -a -e "$t/nets/autostart/default.xml" -a -e "$t/sysnet/virbr0"
check "network didn't let VMs of yours join virbr0" grep -qx 'allow virbr0' "$t/qemu/bridge.conf"
out=$(win status)
check "status should say the VM's network is private: $(grep network <<<"$out")" grep -q 'network: *private:' <<<"$out"
check "status still says isolated, which in libvirt means no internet" lacks 'isolated' "$out"
win check >/dev/null 2>&1 || { echo "FAIL: vikix doctor's check failed a VM on its private network"; fail=1; }

# Moved while running: until Windows restarts, it isn't safe yet, and says so.
printf "<interface type='user'><backend type='passt'/></interface>" > "$t/domxml-live"
out=$(win status)
check "status should say the running Windows is still on the old network: $(grep network <<<"$out")" grep -q "still on the old one now: restart it" <<<"$out"
: > "$calls"
win network >/dev/null 2>&1 || true
check "network should ask for a restart of a Windows still on the old network" grep -q 'notify-send .*Restart Windows once' "$calls"
rm "$t/domxml-live"

# All in place: nothing to change, and no password asked.
: > "$calls"
out=$(win network 2>&1)
check "with everything ready, network should say so: $out" grep -q 'nothing to change' <<<"$out"
check "with everything ready, network used sudo (a password prompt for nothing)" bash -c "! grep -q '^sudo' '$calls'"
check "network edited a VM already on virbr0" bash -c "! grep -q virt-xml '$calls'"
out=$(DRY_RUN=1 win network 2>&1)
check "a dry run with everything ready should say nothing to change: $out" grep -q 'nothing to change' <<<"$out"

# The migration: only where the Windows VM was chosen.
: > "$calls"
mv "$optional" "$t/optional.aside"
VIKIX_DIR="$here" bash "$mig" >/dev/null 2>&1
check "the migration touched the network where Windows wasn't chosen" bash -c "! grep -qE 'virt-xml|virsh' '$calls'"
mv "$t/optional.aside" "$optional"

# --- power, stop, remove ------------------------------------------------------------------
: > "$calls"
win power
check "power off called libvirt with Windows not running" bash -c "! grep -q '^virsh' '$calls'"
touch "$t/qemu-running"
win power >/dev/null
check "power off didn't shut a running Windows down" grep -q 'virsh.*shutdown windows' "$calls"
rm "$t/qemu-running"

out=$(win remove < /dev/null 2>&1) && { echo "FAIL: remove went ahead without asking"; fail=1; }
check "remove without a terminal should ask for --yes: $out" grep -q -- '--yes' <<<"$out"
check "remove without asking deleted the disk" test -e "$images/windows.qcow2"
win remove --yes >/dev/null
check "remove --yes didn't undefine the VM with its TPM and NVRAM" grep -q 'virsh.*undefine windows --nvram --tpm' "$calls"
check "remove --yes left the disk" test ! -e "$images/windows.qcow2"
check "remove deleted ~/Windows" test -d "$HOME/Windows"

[ "$fail" = 0 ] && echo "windows: setup, create, the end of the install, power and remove do what they should, and the password stays on the answer disc"
exit "$fail"
