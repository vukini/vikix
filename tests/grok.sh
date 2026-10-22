#!/usr/bin/env bash
# tests/grok.sh — public vikix grok dispatch, concurrent claims, durable review,
# retries, invalid inputs, and no execution or fetching of returned content;
# the install of Grok Bot from a made-up .deb (nothing of it run, nothing
# outside its folder, a failed one leaving no half, the queue outliving it).
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live Emacs
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's
here=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$here" <<'PY'
import concurrent.futures
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='vikix-grok-test-') as temp:
    work = Path(temp)
    store = work / 'queue'
    fakebin = work / 'bin'
    fakebin.mkdir()
    (fakebin / 'notify-send').write_text('#!/bin/sh\nexit 1\n')
    (fakebin / 'notify-send').chmod(0o700)
    env = {**os.environ, 'VIKIX_GROK_DIR': str(store),
           'PATH': str(fakebin) + ':' + os.environ['PATH'],
           'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent/grok-test-bus'}

    def run(*args, data=None, ok=True):
        p = subprocess.run(['bash', str(root / 'bin/vikix'), 'grok', *args],
                           input=data, text=True, capture_output=True, env=env, timeout=15)
        if ok is not None:
            assert (p.returncode == 0) == ok, (args, p.returncode, p.stdout, p.stderr)
        return p

    def new(title='Research', brief='Read the public release notes.'):
        return run('new', title, '--brief', '-', '--project', 'example', data=brief).stdout.strip()

    def task(task_id):
        return json.loads(run('show', task_id, '--json').stdout)

    assert json.loads(run('list', '--json').stdout) == []
    assert 'not probed' in run('status').stdout
    assert not store.exists(), 'read commands must not create a queue'
    assert 'vikix grok' in run('help').stdout
    assert 'LOCAL computer' in run('instructions').stdout

    first = new()
    assert task(first)['state'] == 'queued'
    assert stat.S_IMODE(store.stat().st_mode) == 0o700
    assert stat.S_IMODE((store / 'tasks.db').stat().st_mode) == 0o600
    prompt = run('prompt', first).stdout
    assert 'vikix grok claim ' + first in prompt
    assert 'vikix grok result ' + first in prompt
    assert 'Read the public release notes.' not in prompt, 'claim carries the selected brief'
    run('accept', first, ok=False)
    result = {'summary': 'Found two changes.', 'sources': ['https://example.com/notes'],
              'artifacts': [], 'questions': []}
    raw = json.dumps(result)
    run('result', first, '--file', '-', data=raw, ok=False)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(lambda _: run('claim', first, ok=None), range(2)))
    assert sorted(p.returncode for p in claims) == [0, 1], claims
    winner = json.loads(next(p.stdout for p in claims if p.returncode == 0))
    assert winner['brief'] == 'Read the public release notes.'
    assert task(first)['state'] == 'running'
    run('prompt', first, ok=False)

    bad_results = [[], {}, {'summary': 'missing fields'}, {**result, 'command': 'true'},
                   {**result, 'sources': ['file:///etc/passwd']},
                   {**result, 'artifacts': ['https://user:password@example.com/a']},
                   {**result, 'questions': 'not a list'},
                   {**result, 'summary': '\x1b]52;payload'},
                   {**result, 'sources': ['https://example.com/\nforged']},
                   {**result, 'summary': ''}]
    for bad in bad_results:
        run('result', first, '--file', '-', data=json.dumps(bad), ok=False)
        assert task(first)['state'] == 'running'
    run('result', first, '--file', '-', data='not JSON', ok=False)
    run('result', first, '--file', '-', data='x' * (1024 * 1024 + 1), ok=False)
    run('result', first, '--file', '-', data=raw)
    before = task(first)
    assert before['state'] == 'review'
    assert before['result'] == result
    run('result', first, '--file', '-', data=raw)
    assert task(first) == before, 'identical retries must not change history or timestamps'
    run('result', first, '--file', '-', data=json.dumps({**result, 'summary': 'Changed'}), ok=False)
    assert task(first) == before
    assert first in run('list', '--state', 'review').stdout
    run('accept', first)
    accepted = task(first)
    assert accepted['state'] == 'accepted'
    assert [s['state'] for s in accepted['history']] == ['queued', 'running', 'review', 'accepted']
    run('result', first, '--file', '-', data=raw)
    assert task(first) == accepted, 'a late identical retry must not reopen an accepted task'
    run('cancel', first, ok=False)
    run('claim', first, ok=False)

    failed = new('Blocked')
    run('claim', failed)
    run('fail', failed, 'Source is unavailable.')
    assert task(failed)['reason'] == 'Source is unavailable.'
    run('result', failed, '--file', '-', data=raw, ok=False)
    run('cancel', failed)
    assert task(failed)['reason'] == '', 'cancel clears a current failure reason'
    cancelled = new('Cancel before work')
    run('cancel', cancelled)
    run('claim', cancelled, ok=False)
    late = new('Cancel during work')
    run('claim', late)
    run('cancel', late)
    run('result', late, '--file', '-', data=raw, ok=False)

    marker = work / 'must-not-exist'
    malicious = f'$(touch {marker}) `touch {marker}`'
    inert = new(malicious, malicious)
    run('claim', inert)
    run('result', inert, '--file', '-', data=json.dumps({**result, 'summary': malicious}))
    run('show', inert)
    run('accept', inert)
    assert not marker.exists(), 'briefs and results must never be executed'
    assert task(inert)['result']['summary'] == malicious
    run('show', '../../outside', ok=False)
    run('show', 'g-' + '0' * 16, ok=False)
    run('new', 'bad\ntitle', '--brief', '-', data='brief', ok=False)
    run('new', 'Empty', '--brief', '-', data='', ok=False)
    source = work / 'brief.txt'
    source.write_text('A selected file only.')
    file_id = run('new', 'From file', '--brief', str(source)).stdout.strip()
    assert task(file_id)['brief'] == source.read_text()
    link = work / 'brief-link'
    link.symlink_to(source)
    run('new', 'From link', '--brief', str(link), ok=False)
    fifo = work / 'fifo'
    os.mkfifo(fifo)
    run('new', 'From FIFO', '--brief', str(fifo), ok=False)
    assert 'summary' not in json.loads(run('list', '--json').stdout)[0]

    # A redirected database must not be followed, even for read-only commands.
    elsewhere = work / 'elsewhere'
    elsewhere.mkdir()
    (elsewhere / 'tasks.db').symlink_to(store / 'tasks.db')
    env['VIKIX_GROK_DIR'] = str(elsewhere)
    run('list', ok=False)
    env['VIKIX_GROK_DIR'] = str(work / 'queue-link')
    (work / 'queue-link').symlink_to(store)
    run('list', ok=False)

    # --- Installing Grok Bot: a made-up .deb, a stand-in release list, a fake home.
    import tarfile

    def ar(members):   # (name, bytes) -> a Debian package's ar archive
        out = b'!<arch>\n'
        for name, data in members:
            out += f'{name + "/":<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode()
            out += data + (b'\n' if len(data) % 2 else b'')
        return out

    def tar_xz(entries):   # (name, data or None for a folder, mode[, linkname])
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode='w:xz') as tf:
            for name, data, mode, *link in entries:
                info = tarfile.TarInfo(name)
                info.mode = mode
                if link:
                    info.type = tarfile.SYMTYPE
                    info.linkname = link[0]
                elif data is None:
                    info.type = tarfile.DIRTYPE
                else:
                    info.size = len(data)
                tf.addfile(info, io.BytesIO(data) if data is not None and not link else None)
        return buf.getvalue()

    def deb(version, extra=()):
        app = './opt/Grok Bot/'
        entries = [('./', None, 0o755), ('./opt/', None, 0o755), (app, None, 0o755),
                   (app + 'grok-bot', f'#!/bin/sh\necho "grok-bot {version} $*"\n'.encode(), 0o755),
                   (app + 'chrome-sandbox', b'sandbox', 0o4755),
                   (app + 'resources/', None, 0o755), (app + 'resources/app.asar', b'asar', 0o644),
                   ('./usr/', None, 0o755), ('./usr/bin/', None, 0o755),
                   ('./usr/bin/grok-bot', None, 0o777, '/opt/Grok Bot/grok-bot'),
                   ('./usr/share/applications/grok-bot.desktop', b'[Desktop Entry]\nExec=/opt/Grok Bot/grok-bot\n', 0o644),
                   ('./usr/share/icons/hicolor/16x16/apps/grok-bot.png', b'PNG16', 0o644),
                   ('./usr/share/icons/hicolor/512x512/apps/grok-bot.png', b'PNG512', 0o644),
                   ('./usr/share/doc/grok-bot/changelog.gz', b'gz', 0o644),
                   ('./etc/apt/sources.list.d/grok-bot.sources', b'Types: deb\n', 0o644),
                   *extra]
        control = tar_xz([('./control', f'Package: grok-bot\nVersion: {version}\n'.encode(), 0o644)])
        return ar([('debian-binary', b'2.0\n'), ('control.tar.xz', control), ('data.tar.xz', tar_xz(entries))])

    home = work / 'home'
    home.mkdir()
    packages = work / 'packages'
    packages.mkdir()

    def publish(version, extra=(), raw=None):
        path = packages / f'grok-bot_{version}.deb'
        path.write_bytes(raw if raw is not None else deb(version, extra))
        manifest = packages / f'manifest-{version}.json'
        manifest.write_text(json.dumps({'version': version, 'debUrl': path.as_uri(), 'commitSha': 'c' * 40}))
        return manifest.as_uri()

    # PATH without the real ~/.local/bin: a Grok Bot installed on this machine must not show.
    env.update(HOME=str(home), VIKIX_GROK_DIR=str(store), PATH=f'{fakebin}:/usr/bin:/bin')
    for name in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'DRY_RUN'):
        env.pop(name, None)
    data = home / '.local/share'
    app = data / 'vikix/grok-bot'
    exe = home / '.local/bin/grok-bot'
    entry = data / 'applications/grok-bot.desktop'
    icon = data / 'icons/hicolor/16x16/apps/grok-bot.png'
    features = home / '.config/vikix/features'

    env['VIKIX_GROK_MANIFEST'] = 'file:///nonexistent/manifest.json'
    env['DRY_RUN'] = '1'
    assert 'would ask' in run('install').stdout, 'a dry run installs nothing and asks nothing'
    assert 'would remove' in run('uninstall').stdout
    assert not (home / '.local').exists()
    del env['DRY_RUN']
    assert 'not found on PATH' in run('status').stdout
    p = run('install', ok=False)
    assert "couldn't read" in p.stderr and not app.exists(), p.stderr

    env['VIKIX_GROK_MANIFEST'] = publish('0.75.0')
    out = run('install').stdout
    assert '0.75.0 is installed' in out, out
    assert exe.is_symlink() and os.readlink(exe) == str(app / 'app/grok-bot')
    hello = subprocess.run([str(exe), 'hello'], capture_output=True, text=True, timeout=10)
    assert hello.stdout == 'grok-bot 0.75.0 hello\n', hello
    assert not (app / 'app/chrome-sandbox').stat().st_mode & stat.S_ISUID, 'no SUID comes out of the package'
    assert not (home / 'etc').exists() and not list(app.rglob('*.sources')), 'the apt source is never unpacked'
    assert not (app / 'app/grok-bot.desktop').exists() and not list(app.rglob('changelog.gz'))
    assert entry.read_text().startswith('[Desktop Entry]') and f'Exec={exe} %U' in entry.read_text()
    assert stat.S_IMODE(entry.stat().st_mode) == 0o644 and stat.S_IMODE(app.stat().st_mode) == 0o755, 'plain files, not the queue\'s 600'
    assert icon.read_bytes() == b'PNG16' and (data / 'icons/hicolor/512x512/apps/grok-bot.png').exists()
    release = json.loads((app / 'release.json').read_text())
    assert release['version'] == '0.75.0' and release['commit'] == 'c' * 40 and len(release['sha512']) == 128
    assert 'grok-bot' in features.read_text().split(), features.read_text()
    env['PATH'] = f"{exe.parent}:{env['PATH']}"
    assert 'Grok Bot 0.75.0' in run('status').stdout, run('status').stdout
    assert 'installed already' in run('install').stdout
    assert 'is installed:' in run('install', '--force').stdout

    env['VIKIX_GROK_MANIFEST'] = publish('0.76.0')
    assert '0.76.0 is installed' in run('install').stdout
    assert subprocess.run([str(exe)], capture_output=True, text=True, timeout=10).stdout == 'grok-bot 0.76.0 \n'
    assert not (data / 'vikix/grok-bot.old').exists() and not (data / 'vikix/grok-bot.new').exists()

    # A package that reaches outside its folder, or lies about itself, installs nothing and leaves 0.76.0.
    for bad in (publish('0.77.0', [('./opt/Grok Bot/' + '../' * 12 + 'escape', b'x', 0o644)]),
                publish('0.77.1', [('./opt/Grok Bot/passwd', None, 0o777, '/etc/passwd')]),
                publish('0.77.2', raw=b'<html>not a package</html>'),
                publish('0.77.3', raw=ar([('debian-binary', b'2.0\n'), ('control.tar.xz', b'')])),
                publish('0.77.4', raw=deb('0.77.4').replace(b'2.0\n', b'3.0\n', 1))):
        env['VIKIX_GROK_MANIFEST'] = bad
        p = run('install', ok=False)
        assert json.loads((app / 'release.json').read_text())['version'] == '0.76.0', p.stderr
        assert not (data / 'vikix/grok-bot.new').exists(), 'a failed install leaves no half'
        assert not (home / 'escape').exists() and not (data / 'escape').exists()
    broken = packages / 'manifest-bad.json'
    broken.write_text(json.dumps({'version': 'latest', 'debUrl': 'file:///x'}))
    env['VIKIX_GROK_MANIFEST'] = broken.as_uri()
    assert 'known shape' in run('install', ok=False).stderr
    broken.write_text(json.dumps({'version': '0.78.0', 'debUrl': 'http://example.com/grok.deb'}))
    assert 'only https' in run('install', ok=False).stderr

    # Something else at ~/.local/bin/grok-bot is moved aside, never deleted.
    env['VIKIX_GROK_MANIFEST'] = publish('0.79.0')
    run('uninstall')
    assert not exe.exists() and not app.exists() and not entry.exists() and not icon.exists()
    assert 'grok-bot' not in features.read_text().split()
    queue = home / '.local/share/vikix/grok'
    queue.mkdir(parents=True)
    (queue / 'tasks.db').write_text('keep')
    exe.parent.mkdir(parents=True, exist_ok=True)
    exe.write_text('#!/bin/sh\necho mine\n')
    assert 'moved to' in run('install').stdout
    aside = [p for p in exe.parent.iterdir() if p.name.startswith('grok-bot.vikix-bak.')]
    assert len(aside) == 1 and aside[0].read_text() == '#!/bin/sh\necho mine\n'
    run('uninstall')
    assert (queue / 'tasks.db').read_text() == 'keep', 'the queue outlives the program'
    assert aside[0].exists()
    assert 'is gone' in run('uninstall').stdout, 'uninstalling twice is fine'


print('grok: CLI handoff, atomic claims, review, retries, cancellation, bounded inputs, inert results, and the install from a package (nothing of it run, nothing outside its folder, the queue kept) passed')
PY
