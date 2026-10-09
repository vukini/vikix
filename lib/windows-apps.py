#!/usr/bin/env python3
"""windows-apps.py — Windows programs in windows of their own (vikix windows
app, apps). bin/vikix-windows runs it; its header has the usage.

RDP's RemoteApp sends one program's windows instead of Windows' desktop, and
FreeRDP draws each as an ordinary X window, which StumpWM tiles. Inside the
VM, everything is done through the QEMU guest agent the first-login script
installed: no network service of Windows' is trusted with it.
"""
import base64
import getpass
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import NoReturn

URI = os.environ.get("VIKIX_WINDOWS_URI", "qemu:///session")
NAME = "windows"
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "vikix"
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local" / "share")
STATE = Path(os.environ.get("VIKIX_STATE") or HOME / ".local" / "state" / "vikix")
SECRET = CONFIG / "secrets" / "windows-password"
APPS = STATE / "windows-apps.json"
DESKTOP = DATA / "applications"
RDP_PORT = int(os.environ.get("VIKIX_RDP_PORT", "3389"))
USER = os.environ.get("VIKIX_WINDOWS_USER") or os.environ.get("USER", "")
# The folders Windows sees, each a drive letter: ~/Windows was always Z:.
SHARES = [(HOME / "Windows", "vikix-shared", "Z:"), (HOME / "Documents", "vikix-documents", "Y:")]
WAIT = int(os.environ.get("VIKIX_WINDOWS_WAIT", "240"))   # seconds for Windows to be up
VIKIX_DIR = Path(__file__).resolve().parent.parent


def say(msg):
    print(f":: {msg}")


def die(msg) -> NoReturn:
    sys.exit(f"xx {msg}")


def notify(title, body=""):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Vikix", title, body])


def virsh(*args, check=True):
    r = subprocess.run(["virsh", "-q", "-c", URI, *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        die(f"virsh {args[0]}: {(r.stderr or r.stdout).strip()}")
    return r


def agent(command, arguments=None, check=True):
    """One guest-agent command, its "return"."""
    msg = {"execute": command}
    if arguments is not None:
        msg["arguments"] = arguments
    r = virsh("qemu-agent-command", NAME, json.dumps(msg), check=check)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)["return"]
    except (ValueError, KeyError):
        return None


def guest_run(path, args, timeout=60):
    """A program in Windows, as SYSTEM: (exit code, output)."""
    started = agent("guest-exec", {"path": path, "arg": args, "capture-output": True})
    if not started:
        die("Windows' guest agent didn't run it (is the VM up? vikix windows status)")
    pid = started["pid"]
    for _ in range(timeout * 4):
        st = agent("guest-exec-status", {"pid": pid})
        if st and st.get("exited"):
            out = base64.b64decode(st.get("out-data", "")).decode(errors="replace")
            err = base64.b64decode(st.get("err-data", "")).decode(errors="replace")
            return st.get("exitcode", 1), out + err
        time.sleep(0.25)
    die(f"{path} in Windows didn't finish in {timeout} s")


def powershell(script, timeout=60):
    return guest_run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], timeout)


def state():
    return virsh("domstate", NAME, check=False).stdout.strip() or "not made"


def address():
    """The VM's address on the private bridge, from the guest agent."""
    for iface in agent("guest-network-get-interfaces", check=False) or []:
        for a in iface.get("ip-addresses", []):
            ip = a.get("ip-address", "")
            # Not Windows' loopback, nor a link-local address it gives
            # itself without DHCP.
            if a.get("ip-address-type") == "ipv4" and ip != "127.0.0.1" and not ip.startswith("169.254."):
                return ip
    return None


def port_open(ip, port):
    try:
        with socket.create_connection((ip, port), timeout=1):
            return True
    except OSError:
        return False


def up(for_rdp=True):
    """The VM running, its agent answering, and (for an app) RDP listening:
    its address. Started first when it's off."""
    if state() == "not made":
        die("no Windows VM yet: vikix windows create ISO")
    if state() != "running":
        say("starting Windows")
        notify("Starting Windows", "The program opens when Windows is ready (a minute or so).")
        virsh("start", NAME)
    deadline = time.time() + WAIT
    while time.time() < deadline:
        if agent("guest-ping", {}, check=False) is not None:
            ip = address()
            if ip and (not for_rdp or port_open(ip, RDP_PORT)):
                return ip
        time.sleep(1)
    die("Windows isn't ready yet" + (" (Remote Desktop doesn't answer: vikix windows apps setup)" if for_rdp else ""))


# --- setup ---------------------------------------------------------------------

def store_password():
    if SECRET.exists():
        return
    if not sys.stdin.isatty():
        die("run it in a terminal: it asks for your Windows account's password once")
    p1 = getpass.getpass(f"Password of your Windows account ({USER}): ")
    p2 = getpass.getpass("Again: ")
    if p1 != p2 or not p1:
        die("the two passwords differ" if p1 != p2 else "no password")
    SECRET.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(SECRET.parent, 0o700)
    fd = os.open(SECRET, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(p1)
    say(f"the password is kept in {SECRET} (yours alone; vikix windows apps forget deletes it)")


# Remote Desktop on, programs allowed by name (RemoteApp on a client
# Windows), sign-in checked before a session starts (NLA), and the firewall's
# Remote Desktop group on. The VM is on the private bridge: only this
# machine reaches 3389.
ENABLE_RDP = r"""
$ts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty -Path $ts -Name fDenyTSConnections -Value 0
Set-ItemProperty -Path "$ts\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1
$allow = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList'
New-Item -Path $allow -Force | Out-Null
Set-ItemProperty -Path $allow -Name fDisabledAllowList -Value 1
Set-ItemProperty -Path $allow -Name fAllowUnlistedRemotePrograms -Value 1
Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752'
'rdp on'
"""

# Each shared folder as its drive letter: the virtio-fs service once per
# folder, by its tag (with two, one service alone would take either).
SHARE_SERVICE = r"""
$svc = 'HKLM:\SYSTEM\CurrentControlSet\Services'
# The program's whole path, spaces and all ("C:\Program Files\..."): from
# the service's own line when it names one, else wherever the guest tools put it.
$line = (Get-ItemProperty "$svc\VirtioFsSvc" -ErrorAction SilentlyContinue).ImagePath
$exe = if ($line -match '^"([^"]+\.exe)"') { $Matches[1] } elseif ($line -match '^(\S+\.exe)') { $Matches[1] } else { $null }
if (-not $exe -or -not (Test-Path $exe)) {
  $exe = Get-ChildItem 'C:\Program Files', 'C:\Program Files (x86)' -Recurse -Filter virtiofs.exe -ErrorAction SilentlyContinue |
         Select-Object -First 1 -ExpandProperty FullName
}
if (-not $exe) { 'no virtiofs.exe'; exit 1 }
# Written to the registry, not through sc.exe, whose quoting PowerShell mangles.
Set-ItemProperty "$svc\VirtioFsSvc" -Name ImagePath -Value ('"' + $exe + '" -t vikix-shared -m Z:')
if (-not (Get-Service VikixDocuments -ErrorAction SilentlyContinue)) {
  New-Service -Name VikixDocuments -DisplayName 'Vikix: Documents as Y:' -StartupType Automatic `
    -DependsOn 'WinFsp.Launcher', 'VirtioFsDrv' -BinaryPathName ('"' + $exe + '" -t vikix-documents -m Y:') | Out-Null
} else {
  Set-ItemProperty "$svc\VikixDocuments" -Name ImagePath -Value ('"' + $exe + '" -t vikix-documents -m Y:')
}
'shares set'
"""


def add_documents_share():
    """~/Documents as a second virtio-fs folder, in the VM's saved definition
    (it shows at the next start)."""
    xml = virsh("dumpxml", "--inactive", NAME).stdout
    if "vikix-documents" in xml:
        return False
    docs = SHARES[1][0]
    docs.mkdir(exist_ok=True)
    fs = (f"<filesystem type='mount' accessmode='passthrough'><driver type='virtiofs'/>"
          f"<source dir='{docs}'/><target dir='vikix-documents'/></filesystem>")
    xml = xml.replace("</devices>", fs + "</devices>", 1)
    tmp = STATE / "windows-define.xml"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    tmp.write_text(xml)
    virsh("define", str(tmp))
    tmp.unlink()
    return True


def cmd_setup():
    if not shutil.which("xfreerdp3"):
        say("installing FreeRDP")
        r = subprocess.run(["bash", str(VIKIX_DIR / "install" / "10-packages.sh")],
                           env=dict(os.environ, VIKIX_LISTS="windows"))
        if r.returncode != 0 or not shutil.which("xfreerdp3"):
            die("couldn't install FreeRDP (freerdp)")
    store_password()
    up(for_rdp=False)
    code, out = powershell(ENABLE_RDP)
    if code != 0 or "rdp on" not in out:
        die(f"Remote Desktop wasn't switched on in Windows: {out.strip()[-300:]}")
    say("Remote Desktop and RemoteApp are on in Windows (reachable from this machine only)")
    code, out = powershell(SHARE_SERVICE)
    if code != 0 or "shares set" not in out:
        die(f"the shared folders' drives weren't set: {out.strip()[-300:]}")
    if add_documents_share():
        say("~/Documents is drive Y: in Windows from its next start (vikix windows stop, then use it again)")
    cmd_apps(quiet=True)
    say("ready: vikix windows apps (what Windows has), vikix windows apps add NAME, vikix windows app NAME")


# --- what Windows has --------------------------------------------------------------

LIST_APPS = r"""
$sh = New-Object -ComObject WScript.Shell
$wi = New-Object -ComObject WindowsInstaller.Installer
# An installer's "advertised" shortcut points at its icon in
# C:\Windows\Installer; Windows Installer knows the real program.
function Resolve-Advertised($lnk) {
  try {
    $st = $wi.GetType().InvokeMember('ShortcutTarget', 'GetProperty', $null, $wi, @($lnk))
    $prod = $st.GetType().InvokeMember('StringData', 'GetProperty', $null, $st, 1)
    $comp = $st.GetType().InvokeMember('StringData', 'GetProperty', $null, $st, 3)
    if ($prod -and $comp) { return $wi.GetType().InvokeMember('ComponentPath', 'GetProperty', $null, $wi, @($prod, $comp)) }
  } catch {}
  return $null
}
$dirs = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs") +
        (Get-ChildItem C:\Users -Directory | ForEach-Object { "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" })
$seen = @{}
$out = foreach ($d in $dirs) {
  if (Test-Path $d) {
    Get-ChildItem $d -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
      $t = $sh.CreateShortcut($_.FullName).TargetPath
      if (-not $t -or $t -like '*\Installer\*') { $r = Resolve-Advertised $_.FullName; if ($r) { $t = $r } }
      if ($t -like '*.exe' -and -not $seen[$t]) { $seen[$t] = 1; [pscustomobject]@{ name = $_.BaseName; path = $t } }
    }
  }
}
$out | ConvertTo-Json -Compress
"""


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def cmd_apps(quiet=False):
    up(for_rdp=False)
    code, out = powershell(LIST_APPS, timeout=120)
    try:
        found = json.loads(out.strip() or "[]")
    except ValueError:
        die(f"Windows' Start menu wasn't read: {out.strip()[-300:]}")
    if isinstance(found, dict):
        found = [found]
    apps = sorted(({"name": a["name"], "path": a["path"], "id": slug(a["name"])} for a in found),
                  key=lambda a: a["name"].lower())
    APPS.parent.mkdir(parents=True, exist_ok=True)
    APPS.write_text(json.dumps(apps, indent=1))
    if not quiet:
        for a in apps:
            print(f"{a['id']:<28} {a['name']}  ({a['path']})")
        print("\nvikix windows apps add NAME puts one in the launcher; vikix windows app NAME opens it.")


def known_apps():
    try:
        return json.loads(APPS.read_text())
    except (OSError, ValueError):
        return []


def find_app(name):
    """An app by its id, its name, its .exe, or a Windows path given whole."""
    if re.match(r"^[A-Za-z]:\\", name):
        return {"name": Path(name.replace("\\", "/")).stem, "path": name, "id": slug(Path(name.replace("\\", "/")).stem)}
    want = name.lower()
    apps = known_apps()
    for a in apps:
        exe = a["path"].replace("\\", "/").rsplit("/", 1)[-1].lower()
        if want in (a["id"], a["name"].lower(), exe, exe.removesuffix(".exe")):
            return a
    starts = [a for a in apps if a["id"].startswith(slug(name))]
    if len(starts) == 1:
        return starts[0]
    if len(starts) > 1:
        die(f"{name} could be: {', '.join(a['id'] for a in starts)}")
    die(f"Windows has no {name} that Vikix knows of (vikix windows apps reads its Start menu)")


def cmd_add(name):
    a = find_app(name)
    DESKTOP.mkdir(parents=True, exist_ok=True)
    f = DESKTOP / f"vikix-win-{a['id']}.desktop"
    f.write_text("[Desktop Entry]\n"
                 "# Written by vikix windows apps add: a Windows program in a window of its own.\n"
                 f"Name={a['name']}\n"
                 f"Comment={a['name']}, from the Windows VM\n"
                 f"Exec=vikix windows app {a['id']} %f\n"
                 "Type=Application\nCategories=Office;\n"
                 f"StartupWMClass=vikix-win-{a['id']}\n")
    say(f"{a['name']} is in the launcher ({f})")


def cmd_remove_app(name):
    a = find_app(name)
    f = DESKTOP / f"vikix-win-{a['id']}.desktop"
    if f.exists() and "vikix windows apps add" in f.read_text(errors="replace"):
        f.unlink()
        say(f"{a['name']} is out of the launcher")


def windows_path(path):
    """A file of yours as Windows sees it, through a shared folder's drive."""
    p = Path(path).expanduser().resolve()
    for folder, _, drive in SHARES:
        try:
            rel = p.relative_to(folder.resolve())
        except ValueError:
            continue
        return drive + "\\" + str(rel).replace("/", "\\") if str(rel) != "." else drive + "\\"
    die(f"Windows can't see {path}: only ~/Windows (Z:) and ~/Documents (Y:) are shared with it")


def cmd_app(name, file=None):
    if not shutil.which("xfreerdp3"):
        die("no FreeRDP: vikix windows apps setup")
    if not SECRET.exists():
        die("no password kept for Windows: vikix windows apps setup")
    a = find_app(name)
    target = windows_path(file) if file else None
    ip = up(for_rdp=True)
    program = f"program:{a['path']}" + (f',cmd:"{target}"' if target else "")
    password = SECRET.read_text().rstrip("\n")
    # Every argument on FreeRDP's input, one a line (/args-from:stdin), the
    # password with them: never on a command line (ps shows those) nor in
    # the environment. (/from-stdin read only the password, and only from a
    # terminal: started from the launcher there is none.)
    args = [f"/v:{ip}:{RDP_PORT}", f"/u:{USER}", f"/p:{password}", f"/app:{program}",
            "/cert:tofu", "+clipboard", "/sound", f"/wm-class:vikix-win-{a['id']}", "/log-level:ERROR",
            # Sharp text: the VM is on this machine, so a fast local link,
            # full colour, and no H.264 (lossy video, which blurs text); the
            # progressive codec sharpens to the exact picture once it's still.
            "/network:lan", "/bpp:32", "/gfx:progressive:on,AVC420:off,AVC444:off",
            # The screen as the desktop leaves it free (_NET_WORKAREA, which
            # modeline.lisp sets): Windows sees it start below the bar, so a
            # maximized program's own title bar isn't under ours.
            "/workarea"]
    log = STATE / "logs" / "windows-app.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    with open(log, "a") as out:
        out.write(f"--- {time.strftime('%F %T')} {a['name']}\n")
        out.flush()
        p = subprocess.Popen(["xfreerdp3", "/args-from:stdin"], stdin=subprocess.PIPE,
                             stdout=out, stderr=out, start_new_session=True)
        assert p.stdin is not None
        p.stdin.write(("\n".join(args) + "\n").encode())
        p.stdin.close()
    # A wrong password or a refused program ends it within seconds: say so.
    try:
        rc = p.wait(timeout=float(os.environ.get("VIKIX_WINDOWS_APP_GRACE", "5")))
    except subprocess.TimeoutExpired:
        return 0
    if rc != 0:
        tail = log.read_text(errors="replace").strip().splitlines()[-3:]
        notify(f"{a['name']} didn't open", "\n".join(tail))
        die(f"{a['name']} didn't open ({log}): " + " / ".join(tail))
    return 0


def cmd_forget(everything=False):
    if SECRET.exists():
        SECRET.unlink()
    if not everything:
        say("the Windows password is forgotten; vikix windows apps setup asks for it again")
        return 0
    # --all: the launcher entries this wrote (never one of yours) and the list
    # of programs go too. vikix windows remove calls this, so nothing of the
    # programs outlives the VM.
    gone = 0
    for f in sorted(DESKTOP.glob("vikix-win-*.desktop")):
        if "vikix windows apps add" in f.read_text(errors="replace"):
            f.unlink()
            gone += 1
    if APPS.exists():
        APPS.unlink()
    say(f"the Windows password, the list of programs and {gone} launcher entr{'y' if gone == 1 else 'ies'} are forgotten")
    return 0


def main(argv):
    if not argv:
        die("vikix windows app NAME [FILE] | apps [setup|add NAME|remove NAME|forget]")
    if argv[0] == "app":
        if len(argv) < 2:
            die("vikix windows app NAME [FILE]")
        return cmd_app(argv[1], argv[2] if len(argv) > 2 else None)
    sub = argv[1] if len(argv) > 1 else ""
    if sub == "":
        return cmd_apps()
    if sub == "setup":
        return cmd_setup()
    if sub in ("add", "remove") and len(argv) > 2:
        return cmd_add(argv[2]) if sub == "add" else cmd_remove_app(argv[2])
    if sub == "forget":
        return cmd_forget(everything="--all" in argv[2:])
    die("vikix windows apps [setup|add NAME|remove NAME|forget [--all]]")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
