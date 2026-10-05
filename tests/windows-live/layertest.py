#!/usr/bin/env python3
"""layertest.py — how FreeRDP's RemoteApp draws a Windows window, setting by
setting, read from X's pixels. Against the real Windows VM (running, with
`vikix windows apps setup` done): not part of tests/run.sh.

  python3 tests/windows-live/layertest.py

Copies layertest.ps1 into C:\\ProgramData\\vikix through the guest agent,
opens it over RemoteApp once per variant below, and prints how much of the
window is red (drawn) and its alpha. A small red window flashes up on the
screen in front for each, for a few seconds.

What it showed on 2026-10-05 (FreeRDP 3.30, Windows 11 Pro): opaque and 85%
(a window see-through as a whole) are drawn in every variant. What FreeRDP
can't draw is a per-pixel layered window (UpdateLayeredWindow), which is how
FACTS draws its message boxes: catch-layer.sh shows those arrive all alpha 0.

Lessons, each of which cost a run:
- Under /args-from:stdin each line is one argument, so /app:...,cmd:ARGS
  takes ARGS bare; quotes around all of them reach Windows literally (quotes
  around one path with spaces are right: that is how Windows reads it).
- PowerShell's -WindowStyle Hidden hides a script's first window, the form.
- StumpWM tiles the form, so find it by its name, not its size; and it closes
  itself after 7 seconds, so read it soon after it appears.
"""
import base64
import importlib.util
import struct
import subprocess
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("wa", HERE.parent.parent / "lib" / "windows-apps.py")
assert spec and spec.loader
wa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wa)

SHARP = ["/network:lan", "/bpp:32", "/gfx:progressive:on,AVC420:off,AVC444:off"]
VARIANTS = [
    ("now, opaque", SHARP, 1.0),
    ("now, 85%", SHARP, 0.85),
    ("-gfx, 85%", ["/network:lan", "/bpp:32", "-gfx"], 0.85),
    ("+aero, 85%", SHARP + ["+aero"], 0.85),
    ("bpp 24, 85%", ["/network:lan", "/bpp:24", "/gfx:progressive:on,AVC420:off,AVC444:off"], 0.85),
    ("-gfx +aero, 85%", ["/network:lan", "/bpp:32", "-gfx", "+aero"], 0.85),
]


def form_windows(pid):
    """The test form's X windows: FreeRDP's (by its process), named layertest."""
    ids = subprocess.run(["xdotool", "search", "--pid", str(pid)], capture_output=True, text=True).stdout.split()
    out = []
    for wid in ids:
        info = subprocess.run(["xwininfo", "-id", wid], capture_output=True, text=True).stdout
        name = subprocess.run(["xprop", "-id", wid, "WM_NAME"], capture_output=True, text=True).stdout
        if "IsViewable" in info and '"layertest"' in name:
            out.append((wid, info.split("Width:")[1].split()[0], info.split("Height:")[1].split()[0],
                        info.split("Depth:")[1].split()[0]))
    return out


def pixels(wid):
    """(red pixels, pixels looked at, the commonest alpha values), from xwd."""
    d = subprocess.run(["xwd", "-silent", "-id", wid], capture_output=True).stdout
    hs = struct.unpack(">I", d[0:4])[0]
    w = struct.unpack(">I", d[16:20])[0]
    h = struct.unpack(">I", d[20:24])[0]
    bpl = struct.unpack(">I", d[48:52])[0]
    off = hs + struct.unpack(">I", d[76:80])[0] * 12
    red = total = 0
    alphas = Counter()
    for y in range(0, h, 5):
        row = d[off + y * bpl: off + y * bpl + w * 4]
        for x in range(0, len(row) - 3, 20):
            b, g, r, a = row[x:x + 4]
            total += 1
            alphas[a] += 1
            red += r > 180 and g < 80 and b < 80
    return red, total, alphas.most_common(2)


def main():
    ps1 = base64.b64encode((HERE / "layertest.ps1").read_bytes()).decode()
    wa.up(for_rdp=False)
    wa.powershell("New-Item -ItemType Directory -Force C:\\ProgramData\\vikix | Out-Null; "
                  "[IO.File]::WriteAllBytes('C:\\ProgramData\\vikix\\layertest.ps1', "
                  f"[Convert]::FromBase64String('{ps1}'))")
    ip = wa.up(for_rdp=True)
    password = wa.SECRET.read_text().rstrip("\n")
    base = [f"/v:{ip}:{wa.RDP_PORT}", f"/u:{wa.USER}", f"/p:{password}", "/cert:tofu",
            "/log-level:ERROR", "/wm-class:vikix-win-layertest"]
    for name, extra, opacity in VARIANTS:
        args = base + extra + ["/app:program:powershell.exe,cmd:-NoProfile -ExecutionPolicy Bypass "
                               f"-File C:\\ProgramData\\vikix\\layertest.ps1 {opacity}"]
        p = subprocess.Popen(["xfreerdp3", "/args-from:stdin"], stdin=subprocess.PIPE,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        assert p.stdin
        p.stdin.write(("\n".join(args) + "\n").encode())
        p.stdin.close()
        found = []
        for _ in range(40):
            time.sleep(0.5)
            found = form_windows(p.pid)
            if found:
                break
        time.sleep(1.5)
        found = form_windows(p.pid)
        rows = [f"{w}x{h} depth {depth}: red {r}/{t}, alpha {a}"
                for wid, w, h, depth in found for r, t, a in [pixels(wid)]]
        print(f"{name:18} {'; '.join(rows) if rows else 'no window seen'}", flush=True)
        p.terminate()
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill()
        time.sleep(3)
    wa.powershell("Remove-Item C:\\ProgramData\\vikix\\layertest.ps1, C:\\Users\\Public\\vikix-layertest.log "
                  "-ErrorAction SilentlyContinue")


if __name__ == "__main__":
    main()
