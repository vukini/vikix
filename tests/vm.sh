#!/usr/bin/env bash
# tests/vm.sh — vikix-vm, every VM libvirt has in a menu.
#
#   the list: yours first, then the system's, each with its state (a shut
#   off VM with a managed save shows as saved), memory in GB and CPUs; a
#   libvirt that doesn't answer is left out; status names the libvirt;
#   start, pause, resume, save, fresh, stop and off go to the right
#   libvirt and say what they did, as a notification when there is no
#   terminal; open starts a VM that is off and shows it with virt-viewer,
#   and Windows in yours goes through vikix windows; the menu offers what
#   fits the state, comes back to the list after an act, leaves after
#   open or Escape, and says so when there is no VM at all.
#
# virsh, virt-viewer, rofi, notify-send, setsid and vikix-windows are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home"
mkdir -p "$HOME" "$t/bin" "$t/vms/yours" "$t/vms/system"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
log="$t/log"

# virsh: each libvirt a folder of VMs, a VM a folder with its state (and a
# saved file for a managed save); the system's answers nothing while
# $t/no-system is there.
cat > "$t/bin/virsh" <<EOF
#!/bin/bash
echo "virsh \$*" >> "$log"
uri=
while [ "\${1:-}" = -q ] || [ "\${1:-}" = -c ]; do [ "\$1" = -c ] && { uri=\$2; shift; }; shift; done
case \$uri in qemu:///session) d="$t/vms/yours" ;; qemu:///system) d="$t/vms/system"; [ -e "$t/no-system" ] && { echo 'error: failed to connect' >&2; exit 1; } ;; *) exit 1 ;; esac
vm="\$d/\${2:-}"
case \$1 in
  list) ls "\$d" ;;
  dominfo|start|suspend|resume|managedsave|managedsave-remove|shutdown|destroy)
    [ -d "\$vm" ] || { echo "error: failed to get domain '\$2'" >&2; exit 1; } ;;
esac
case \$1 in
  dominfo) printf 'Name:           %s\nState:          %s\nCPU(s):         %s\nMax memory:     %s KiB\nManaged save:   %s\n' \\
             "\$2" "\$(cat "\$vm/state")" "\$(cat "\$vm/cpus")" "\$(cat "\$vm/mem")" "\$([ -e "\$vm/saved" ] && echo yes || echo no)" ;;
  start) [ -e "$t/refuse" ] && { echo 'error: Failed to start domain: no space' >&2; exit 1; }; echo running > "\$vm/state"; rm -f "\$vm/saved" ;;
  suspend) echo paused > "\$vm/state" ;;
  resume) echo running > "\$vm/state" ;;
  managedsave) echo 'shut off' > "\$vm/state"; touch "\$vm/saved" ;;
  managedsave-remove) rm -f "\$vm/saved" ;;
  shutdown) echo 'in shutdown' > "\$vm/state" ;;
  destroy) echo 'shut off' > "\$vm/state" ;;
esac
exit 0
EOF
# rofi: the lines offered are kept, one file a call; the answer is a line
# number from $t/answer, none closes it.
cat > "$t/bin/rofi" <<EOF
#!/bin/sh
echo "rofi \$*" >> "$log"
n=\$(ls "$t"/offered.* 2>/dev/null | wc -l)
cat > "$t/offered.\$n"
[ -s "$t/answer" ] || exit 1
head -1 "$t/answer"; sed -i 1d "$t/answer"
EOF
for p in notify-send virt-viewer; do printf '#!/bin/sh\necho "%s $*" >> %q\n' "$p" "$log" > "$t/bin/$p"; done
printf '#!/bin/sh\necho "setsid $*" >> %q\nexec "$@"\n' "$log" > "$t/bin/setsid"
printf '#!/bin/sh\necho "vikix-windows $*" >> %q\n' "$log" > "$t/bin/vikix-windows"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_VM_WINDOWS="$t/bin/vikix-windows"

vm_make() {   # vm_make WHOSE NAME STATE MEM_KIB CPUS [saved]
  mkdir -p "$t/vms/$1/$2"
  echo "$3" > "$t/vms/$1/$2/state"; echo "$4" > "$t/vms/$1/$2/mem"; echo "$5" > "$t/vms/$1/$2/cpus"
  [ "${6:-}" = saved ] && touch "$t/vms/$1/$2/saved" || true
}
state_of() { cat "$t/vms/$1/$2/state"; }
vm() { : > "$log"; rm -f "$t"/offered.*; bash "$here/bin/vikix-vm" "$@"; }
# As the menu runs it: no terminal on stdout, so what it says is a notification.
vm_menu() { : > "$log"; rm -f "$t"/offered.*; bash "$here/bin/vikix-vm" "$@" > "$t/out"; }

vm_make yours windows 'shut off' 6291456 2 saved
vm_make system void-vm 'shut off' 4194304 2
vm_make system builder running 1572864 4

# The list: yours first, saved shown as such, memory in GB.
out=$(vm list)
check "yours should come first, saved: $out" test "$(sed -n 1p <<<"$out")" = 'windows          saved     6 GB, 2 CPUs   yours'
check "the system's off VM: $out" grep -qx 'void-vm          off       4 GB, 2 CPUs   the system'"'"'s' <<<"$out"
check "a running one, 1.5 GB: $out" grep -qx 'builder          running   1.5 GB, 4 CPUs   the system'"'"'s' <<<"$out"
check "three VMs: $out" test "$(wc -l <<<"$out")" = 3
touch "$t/no-system"
out=$(vm list)
check "a libvirt that doesn't answer should be left out: $out" test "$(wc -l <<<"$out")" = 1
rm -f "$t/no-system"

# status: which libvirt, and the state.
out=$(vm status void-vm)
check "status should name the system's libvirt: $out" grep -q 'libvirt:       qemu:///system' <<<"$out"
check "status should say the state: $out" grep -q '^state:         off$' <<<"$out"
out=$(vm status nobody 2>&1) && check "an unknown VM should fail" false
check "an unknown VM should be said: $out" grep -q 'No VM called nobody' <<<"$out"

# The acts, each to the VM's own libvirt.
vm start void-vm >/dev/null
check "start should start the system's VM" grep -q 'virsh -q -c qemu:///system start void-vm' "$log"
check "it should be running" test "$(state_of system void-vm)" = running
vm pause void-vm >/dev/null
check "pause should suspend" test "$(state_of system void-vm)" = paused
vm resume void-vm >/dev/null
check "resume should resume" test "$(state_of system void-vm)" = running
out=$(vm save void-vm)
check "save should manage-save" test -e "$t/vms/system/void-vm/saved"
check "save should say where it stands: $out" grep -q 'void-vm is saved' <<<"$out"
check "list should show it saved" grep -q '^void-vm  *saved' <<<"$(vm list)"
vm fresh void-vm >/dev/null
check "fresh should throw the saved state away and start" bash -c "! test -e '$t/vms/system/void-vm/saved'"
check "fresh should start it" test "$(state_of system void-vm)" = running
vm stop void-vm >/dev/null
check "stop should ask it to shut down" grep -q 'virsh -q -c qemu:///system shutdown void-vm' "$log"
check "a VM shutting down shows as stopping" grep -q '^void-vm  *stopping' <<<"$(vm list)"
vm off void-vm >/dev/null
check "off should destroy" grep -q 'virsh -q -c qemu:///system destroy void-vm' "$log"
check "it should be off" test "$(state_of system void-vm)" = 'shut off'
touch "$t/refuse"
out=$(vm start void-vm 2>&1) && check "a refused start should fail" false
check "virsh's reason should be passed on: $out" grep -q "Couldn't start void-vm.*no space" <<<"$out"
rm -f "$t/refuse"

# open: started when off, then virt-viewer on its libvirt; Windows through vikix windows.
vm_make system void-vm 'shut off' 4194304 2
vm open void-vm >/dev/null
check "open should start an off VM first" grep -q 'virsh -q -c qemu:///system start void-vm' "$log"
check "then show it: $(cat "$log")" grep -q 'virt-viewer --connect qemu:///system --attach --auto-resize=always void-vm' "$log"
vm open windows >/dev/null
check "Windows should open as vikix windows does: $(cat "$log")" grep -q '^vikix-windows open' "$log"
check "and not through virt-viewer here" bash -c "! grep -q virt-viewer '$log'"

# The menu: the list, then what fits the one picked, then the list again.
printf '0\n0\n' > "$t/answer"       # windows (saved), then "Start, where it was saved"; then Escape
vm_menu
check "the first menu should be the list: $(cat "$t/offered.0")" grep -q '^windows  *saved' "$t/offered.0"
check "a saved VM's offers: $(cat "$t/offered.1")" test "$(tr '\n' '|' < "$t/offered.1")" = 'Start, where it was saved|Open its screen (starts it where it was)|Start afresh, the saved state thrown away|'
check "the pick should start it" test "$(state_of yours windows)" = running
check "the list should come back after an act" test -e "$t/offered.2"
check "showing the new state: $(cat "$t/offered.2")" grep -q '^windows  *running' "$t/offered.2"
check "Escape should leave" test ! -e "$t/offered.3"
printf '0\n' > "$t/answer"           # windows (running), then Escape at its offers
vm_menu
check "a running VM's offers: $(cat "$t/offered.1")" test "$(tr '\n' '|' < "$t/offered.1")" = 'Open its screen|Pause (keeps its memory, uses no processor)|Save and switch off (memory to disk; starts where it was)|Shut down|Switch off, as pulling the plug|'
check "Escape at the offers should go back to the list" test -e "$t/offered.2"
check "the line over the offers should say what it is: $(cat "$log")" grep -q 'mesg windows: running, 6 GB, 2 CPUs, yours' "$log"
printf '1\n1\n' > "$t/answer"        # builder (running), then Pause
vm_menu
check "an act from the menu should be a notification: $(cat "$log")" grep -q 'notify-send -a Vikix builder is paused' "$log"
check "and print nothing" test ! -s "$t/out"
vm_make system void-vm 'shut off' 4194304 2   # open above started it
touch "$t/refuse"
printf '2\n0\n' > "$t/answer"        # void-vm (off), then Start, refused
vm_menu
check "a refused act should be a notification: $(cat "$log")" grep -q "notify-send -a Vikix -u critical Couldn't start void-vm" "$log"
check "and the list should come back" test -e "$t/offered.2"
rm -f "$t/refuse"
printf '2\n1\n' > "$t/answer"        # void-vm (off), then "Open its screen (starts it)"
vm_menu
check "open from the menu should start and show: $(cat "$log")" grep -q 'virt-viewer --connect qemu:///system' "$log"
check "and leave the menu" test ! -e "$t/offered.2"
rm -rf "$t/vms/yours/"* "$t/vms/system/"*
vm_menu && check "no VM at all should fail" false
check "and be said: $(cat "$log")" grep -q 'No virtual machines' "$log"

# The dispatch, and the header its man page is made from.
check "vikix vm should hand over" grep -q 'exec "\$VIKIX_DIR/bin/vikix-vm"' "$here/bin/vikix"
check "the header should be in shape" python3 "$here/lib/man.py" --check "$here/bin/vikix-vm"
check "Super+m should have it, needing virsh" grep -q ':run "exec vikix-vm"' "$here/config/stumpwm/vikix/registry.lisp"

[ "$fail" = 0 ] && echo "vm: ok"
exit "$fail"
