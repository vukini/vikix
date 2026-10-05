#!/usr/bin/env bash
# tests/winapps.sh — vikix windows app/apps: Windows programs in windows of
# their own, over RDP's RemoteApp.
#
#   setup keeps the password (600, a name secrets.sh never exports) and
#   asks for it in a terminal only; switches Remote Desktop and RemoteApp
#   on through the guest agent (the registry keys, NLA, the firewall group)
#   and the shares' drives (Z: and Y:, each by its tag); adds ~/Documents
#   to the VM's saved definition once. apps reads the Start menu; add
#   writes a launcher entry, remove takes only its own away. app starts a
#   VM that's off, waits for RDP, runs xfreerdp3 with the password on
#   stdin and never in its arguments, turns a file in ~/Windows or
#   ~/Documents into its drive's path and refuses one elsewhere, and says
#   so when FreeRDP gives up at once (a wrong password).
#
# virsh is a stand-in that plays libvirt and Windows' guest agent; xfreerdp3
# one that records what it was given; RDP's port a listener here.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
listener=
trap '[ -n "$listener" ] && kill "$listener" 2>/dev/null; rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

export HOME="$t/home" USER=vid VIKIX_WINDOWS_WAIT=10 VIKIX_WINDOWS_APP_GRACE=2
mkdir -p "$HOME/Windows/sub" "$HOME/Documents" "$t/bin" "$t/vm"
echo running > "$t/vm/state"
echo '<domain><devices><disk/></devices></domain>' > "$t/vm/xml"

# RDP's port, here: a listener for the "is Remote Desktop up" check.
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.2",0)); print(s.getsockname()[1])')
python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.2", int(sys.argv[1]))); s.listen()
while True:
    c, _ = s.accept(); c.close()' "$port" &
listener=$!
export VIKIX_RDP_PORT=$port

cat > "$t/bin/virsh" <<'X'
#!/usr/bin/env python3
import base64, json, os, sys
vm = os.environ["VM"]
a = [x for x in sys.argv[1:] if x not in ("-q",)]
if a[0] == "-c": a = a[2:]
log = open(f"{vm}/calls", "a")
cmd = a[0]
if cmd == "domstate": print(open(f"{vm}/state").read().strip()); sys.exit(0)
if cmd == "start": log.write("start\n"); open(f"{vm}/state", "w").write("running"); sys.exit(0)
if cmd == "dumpxml": print(open(f"{vm}/xml").read()); sys.exit(0)
if cmd == "define": log.write("define\n"); open(f"{vm}/xml", "w").write(open(a[1]).read()); sys.exit(0)
if cmd == "qemu-agent-command":
    if open(f"{vm}/state").read().strip() != "running": sys.exit(1)
    msg = json.loads(a[2]); ex = msg["execute"]; args = msg.get("arguments", {})
    def ret(v): print(json.dumps({"return": v})); sys.exit(0)
    if ex == "guest-ping": ret({})
    if ex == "guest-network-get-interfaces":
        ret([{"name": "lo", "ip-addresses": [{"ip-address-type": "ipv4", "ip-address": "127.0.0.1"}]},
             {"name": "Ethernet", "ip-addresses": [{"ip-address-type": "ipv4", "ip-address": "127.0.0.2"}]}])
    if ex == "guest-exec":
        script = " ".join(args.get("arg", []))
        log.write("exec " + args["path"] + "\n")
        open(f"{vm}/scripts", "a").write(script + "\n=====\n")
        out = ""
        if "fAllowUnlistedRemotePrograms" in script: out = "rdp on"
        elif "VikixDocuments" in script: out = "shares set"
        elif "WScript.Shell" in script:
            out = json.dumps([{"name": "FACTS", "path": "C:\\Program Files (x86)\\FACTS\\facts.exe"},
                              {"name": "Notepad", "path": "C:\\Windows\\System32\\notepad.exe"}])
        open(f"{vm}/out", "w").write(out)
        ret({"pid": 7})
    if ex == "guest-exec-status":
        ret({"exited": True, "exitcode": 0, "out-data": base64.b64encode(open(f"{vm}/out").read().encode()).decode()})
sys.exit(1)
X
cat > "$t/bin/xfreerdp3" <<X
#!/bin/sh
printf '%s\n' "\$@" > "$t/rdp-argv"
cat > "$t/rdp-args"   # /args-from:stdin: the arguments, one a line
[ -e "$t/rdp-refuse" ] && { echo "ERRCONNECT_LOGON_FAILURE"; exit 131; }
sleep 30
X
printf '#!/bin/sh\necho "notify $*" >> %s/notified\n' "$t" > "$t/bin/notify-send"
chmod +x "$t/bin/"*
export VM="$t/vm" PATH="$t/bin:$PATH"
# The address the stand-in gives is 127.0.0.2: RDP's check connects there.
w() { python3 "$here/lib/windows-apps.py" "$@"; }

# setup: not in a terminal, it won't ask.
out=$(w apps setup < /dev/null 2>&1) && fail=1
check "setup asks for the password only in a terminal: $out" grep -q "run it in a terminal" <<<"$out"
# The password kept as if asked (the terminal part is getpass's).
mkdir -p "$HOME/.config/vikix/secrets"; printf 'hunter2' > "$HOME/.config/vikix/secrets/windows-password"
chmod 600 "$HOME/.config/vikix/secrets/windows-password"
out=$(w apps setup < /dev/null 2>&1) || true
check "setup switches Remote Desktop and RemoteApp on: $out" grep -q "Remote Desktop and RemoteApp are on" <<<"$out"
check "through the guest agent, as PowerShell" grep -q "^exec powershell.exe$" "$t/vm/calls"
for k in fDenyTSConnections UserAuthentication fAllowUnlistedRemotePrograms "@FirewallAPI.dll,-28752"; do
  check "the setting $k is sent" grep -qF -- "$k" "$t/vm/scripts"
done
check "each share's drive by its tag: Z: and Y:" bash -c 'grep -q "vikix-shared -m Z:" "$1" && grep -q "vikix-documents -m Y:" "$1"' _ "$t/vm/scripts"
check "Documents added to the VM's definition" grep -q "<target dir='vikix-documents'/>" "$t/vm/xml"
check "the password's name is never exported (secrets.sh takes only ..._KEY, _TOKEN, _SECRET)" \
  bash -c '. "$1/lib/secrets.sh"; vikix_export_secrets; ! env | grep -q hunter2' _ "$here"
w apps setup < /dev/null >/dev/null 2>&1 || true
check "and only once" test "$(grep -c '^define$' "$t/vm/calls")" = 1
check "setup read what Windows has" grep -q '"FACTS"' "$HOME/.local/state/vikix/windows-apps.json"
check "an installer's advertised shortcut is asked of Windows Installer, not taken as its icon" grep -q "ShortcutTarget" "$t/vm/scripts"

out=$(w apps 2>&1)
check "apps lists the Start menu's programs: $out" grep -q "^facts .*FACTS" <<<"$out"
w apps add facts >/dev/null
desk="$HOME/.local/share/applications/vikix-win-facts.desktop"
check "add puts it in the launcher" grep -qx "Exec=vikix windows app facts %f" "$desk"
check "with a class of its own, for rules" grep -qx "StartupWMClass=vikix-win-facts" "$desk"

# app: VM off, started; RDP waited for; the password on stdin only.
echo "shut off" > "$t/vm/state"; : > "$t/vm/calls"
out=$(w app facts "$HOME/Documents/report.xlsx" 2>&1) || true
check "a VM that's off is started first: $out" grep -q "^start$" "$t/vm/calls"
check "FreeRDP runs RemoteApp for the program" grep -qxF '/app:program:C:\Program Files (x86)\FACTS\facts.exe,cmd:"Y:\report.xlsx"' "$t/rdp-args"
check "at the VM's address and RDP's port" grep -qx "/v:127.0.0.2:$port" "$t/rdp-args"
check "as you" grep -qx "/u:vid" "$t/rdp-args"
check "with the window's class for rules" grep -qx "/wm-class:vikix-win-facts" "$t/rdp-args"
check "sharp text: no H.264, which blurs it" grep -qx "/gfx:progressive:on,AVC420:off,AVC444:off" "$t/rdp-args"
check "picom's starter blurs nothing behind a Windows program's windows" grep -qF "\"class_g ^= 'vikix-win-'\"" "$here/config/picom/picom.conf"
check "FreeRDP's own arguments are only /args-from:stdin" test "$(cat "$t/rdp-argv")" = "/args-from:stdin"
check "the password with the rest, on its input" grep -qx "/p:hunter2" "$t/rdp-args"
check "never on its command line" bash -c '! grep -q hunter2 "$1"' _ "$t/rdp-argv"
pkill -f "$t/bin/xfreerdp3" 2>/dev/null || true
out=$(w app facts "$HOME/Windows/sub/a.txt" 2>&1) || true
check "a file in ~/Windows is on Z:" grep -qF 'cmd:"Z:\sub\a.txt"' "$t/rdp-args"
pkill -f "$t/bin/xfreerdp3" 2>/dev/null || true
out=$(w app facts "$t/elsewhere.txt" 2>&1) && fail=1
check "a file Windows can't see is refused: $out" grep -q "Windows can't see" <<<"$out"
touch "$t/rdp-refuse"
out=$(w app facts 2>&1) && fail=1
check "FreeRDP giving up at once is said: $out" grep -q "didn't open" <<<"$out"
check "and shown" grep -q "FACTS didn't open" "$t/notified"
rm "$t/rdp-refuse"
out=$(w app nosuch 2>&1) && fail=1
check "a program Windows doesn't have is said: $out" grep -q "Windows has no nosuch" <<<"$out"

# remove takes its own entry only; forget deletes the password.
echo "[Desktop Entry]" > "$HOME/.local/share/applications/vikix-win-notepad.desktop"
w apps remove notepad >/dev/null 2>&1 || true
check "remove leaves an entry it didn't write" test -f "$HOME/.local/share/applications/vikix-win-notepad.desktop"
w apps remove facts >/dev/null 2>&1 || true
check "and takes its own" test ! -e "$desk"
w apps forget >/dev/null
check "forget deletes the password" test ! -e "$HOME/.config/vikix/secrets/windows-password"
out=$(w app facts 2>&1) && fail=1
check "without it, app says to run setup: $out" grep -q "vikix windows apps setup" <<<"$out"

[ "$fail" = 0 ] && echo "winapps: setup (the password kept and never exported, RemoteApp on through the guest agent, Z: and Y: by tag, ~/Documents shared once), the Start menu read, launcher entries, app starting the VM and passing its arguments, the password with them, on FreeRDP's input only, files by their drive, refusals said"
exit "$fail"
