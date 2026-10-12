#!/usr/bin/env bash
# tests/battery.sh — critical sleep through the real watcher, with fake
# battery readings, notifications, sleep and loginctl. No live power actions.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# Drive the public watcher with stand-in commands; never contact elogind.
python3 - "$here" <<'PYTEST'
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

watcher = str(Path(sys.argv[1]) / "bin/vikix-battery")
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    bindir = root / "bin"
    bindir.mkdir()
    stub = r"""#!/usr/bin/env python3
import json, os, signal
from pathlib import Path
r = Path(os.environ['BAT_TEST'])
name = Path(__file__).name
states = json.loads((r / 'states').read_text())
i = int((r / 'step').read_text())
s = states[i]
if name == 'sleep':
    with (r / 'sleeps').open('a') as f: f.write(os.sys.argv[1] + '\n')
    i += 1
    if i == len(states):
        os.kill(os.getppid(), signal.SIGTERM)
    else:
        (r / 'step').write_text(str(i))
        s = states[i]
        for field in ('capacity', 'status'):
            (r / 'power/BAT0' / field).write_text(str(s.get(field, '')))
        (r / 'power/usb-c/online').write_text(str(s.get('online', 0)))
elif name == 'notify-send':
    with (r / 'warnings').open('a') as f: f.write(os.sys.argv[-2] + '\n')
    if s.get('plug_on_notify'):
        (r / 'power/usb-c/online').write_text('1')
    raise SystemExit(s.get('notify_fail', 0))
elif name == 'loginctl':
    assert os.sys.argv[1:] == ['suspend']
    with (r / 'requests').open('a') as f: f.write('suspend\n')
    raise SystemExit(s.get('fail', 0))
"""
    for name in ('sleep', 'notify-send', 'loginctl'):
        p = bindir / name
        p.write_text(stub)
        p.chmod(0o755)

    def state(level, status='Discharging', **kw):
        return dict(capacity=level, status=status, **kw)

    def run(label, states, requests, sleeps, warnings=None, once=False, **settings):
        import json
        r = root / label
        (r / 'power/BAT0').mkdir(parents=True)
        (r / 'power/usb-c').mkdir()
        (r / 'states').write_text(json.dumps(states))
        (r / 'step').write_text('0')
        for field in ('capacity', 'status'):
            (r / 'power/BAT0' / field).write_text(str(states[0][field]))
        (r / 'power/usb-c/online').write_text(str(states[0].get('online', 0)))
        env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'],
                   BAT_TEST=str(r), VIKIX_POWER_SUPPLY=str(r / 'power'),
                   VIKIX_BATTERY_LOW='15', VIKIX_BATTERY_CRITICAL='5')
        env.update(settings)
        # Kill the entire test-owned process group on failure or timeout.
        proc = subprocess.Popen(['sh', watcher] + (['--once'] if once else []),
                                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, start_new_session=True)
        try:
            out, err = proc.communicate(timeout=10)
        finally:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=5)
        assert proc.returncode == (0 if once else -signal.SIGTERM), (label, proc.returncode, err)
        def lines(name):
            p = r / name
            return p.read_text().splitlines() if p.exists() else []
        assert len(lines('requests')) == requests, (label, lines('requests'), err)
        assert lines('sleeps') == list(map(str, sleeps)), (label, lines('sleeps'))
        if warnings is not None:
            assert lines('warnings') == warnings, (label, lines('warnings'))
        if once:
            assert '5% (Discharging)' in out, out
        print('battery:', label)

    run('discharge-and-recharge', [state(50), state(14), state(13), state(5),
        state(4), state(4, 'Charging'), state(40, 'Charging'), state(14)],
        2, [60, 15, 15, 120, 120, 60, 60, 15],
        ['Battery at 14%', 'Battery at 5%', 'Battery at 14%'])
    run('charger-online', [state(3, online=1), state(3, 'Full'), state(3, 'Unknown')],
        0, [60, 60, 60], [])
    run('charger-arrives-during-notification', [state(5, plug_on_notify=True)], 0, [15])
    run('suspend-failure-retries', [state(5, fail=1), state(4)], 2, [60, 120],
        ['Battery at 5%', 'Battery sleep failed'])
    run('notification-failure-still-sleeps', [state(5, notify_fail=1)], 1, [120])
    run('invalid-readings', [state(''), state('oops'), state(101)], 0, [60, 60, 60], [])
    run('diagnostic-never-sleeps', [state(5)], 0, [], once=True)
    run('custom-levels', [state(20), state(10)], 1, [15, 120],
        VIKIX_BATTERY_LOW='25', VIKIX_BATTERY_CRITICAL='10')
PYTEST
