"""Public capture controls with isolated audio fixtures, and durable failure tests."""
import errno
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch


def fixture(name):
    folder = Path(os.environ['CAPTURE_TEST'])
    def node(number, name, cls=''):
        return dict(id=number, type='PipeWire:Interface:Node', info=dict(props={'node.name': name, 'media.class': cls}))
    def port(number, node_id, direction):
        return dict(id=number, type='PipeWire:Interface:Port', info=dict(props={'node.id': node_id, 'port.direction': direction}))
    if name == 'pw-dump':
        items = []
        if not (folder / 'no-mic').exists():
            items += [node(10, 'fixture-mic', 'Audio/Source'), port(11, 10, 'out')]
        if (folder / 'engine-name').exists():
            items += [node(20, (folder / 'engine-name').read_text()), port(21, 20, 'out'), port(22, 20, 'out')]
        if (folder / 'recorder-name').exists():
            items += [node(30, (folder / 'recorder-name').read_text()), port(31, 30, 'in'), port(32, 30, 'in')]
        print(json.dumps(items))
    elif name == 'pw-record':
        (folder / 'recorder-name').write_text(sys.argv[sys.argv.index('--properties')+1].split()[0].split('=')[1])
        with (folder / 'audio-pids').open('a') as out:
            out.write(str(os.getpid())+'\n')
        with (folder / 'guard-pids').open('a') as out:
            out.write(str(os.getppid())+'\n')
        if (folder / 'recorder-fail').exists():
            return 1
        while True:
            os.write(1, b'\x01\x00\x02\x00'*1024)
            time.sleep(.01)
    elif name == 'pw-link':
        with (folder / 'links').open('a') as out:
            out.write(' '.join(sys.argv[3:])+'\n')
    elif name == 'pw-play':
        with (folder / 'audio-pids').open('a') as out:
            out.write(str(os.getpid())+'\n')
        time.sleep(.2)
    return 0


if sys.argv[1] == '--fixture':
    raise SystemExit(fixture(sys.argv[2]))
root = Path(sys.argv[1])
sys.path.insert(0, str(root / 'lib/music'))
from capture import Captures, sources
from launcher import end


def until(check, seconds=10):
    deadline = time.monotonic()+seconds
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(.05)
    raise AssertionError('capture condition timed out')


with tempfile.TemporaryDirectory(prefix='music-capture-') as temp:
    folder = Path(temp)
    home = folder / 'home'
    home.mkdir()
    commands = folder / 'bin'
    commands.mkdir()
    for name in ('pw-record', 'pw-play', 'pw-dump', 'pw-link'):
        path = commands / name
        path.write_text('#!/bin/sh\nexec python3 ' + shlex.quote(__file__) + ' --fixture ' + name + ' "$@"\n')
        path.chmod(0o755)
    for name, text in {
        'pw-jack': '#!/bin/sh\nexec "$@"\n',
        'scsynth': '#!/bin/sh\npython3 -c \'import os,sys,pathlib; pathlib.Path(os.environ["CAPTURE_TEST"],"engine-name").write_text(sys.argv[sys.argv.index("-H")+1])\' "$@"\nexec python3 ' + shlex.quote(str(root / 'tests/music/check.py')) + ' --engine "$@"\n',
    }.items():
        path = commands / name
        path.write_text(text)
        path.chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(folder), CAPTURE_TEST=temp,
               MUSIC_TEST=temp, PATH=str(commands)+os.pathsep+os.environ['PATH'],
               DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
    song = home / 'music/test/patterns.lisp'
    song.parent.mkdir(parents=True)
    song.write_text("(tempo 120)\n(defpattern tone '(a4 - c5 -))\n")
    synth = home / '.local/share/vikix/music/palette-v1.scsyndef'
    synth.parent.mkdir(parents=True)
    synth.write_bytes(b'fixture')
    def control(*args, ok=True):
        result = subprocess.run([str(root/'bin/vikix'), 'music', 'control', *args],
            env=env, capture_output=True, text=True, timeout=25)
        assert (result.returncode == 0) == ok, (args, result.stdout, result.stderr)
        return json.loads(result.stdout) if result.stdout.startswith('{') else result.stdout
    log = (folder/'session.log').open('w')
    child = None
    try:
        child = subprocess.Popen([str(root/'bin/vikix'), 'music', 'serve', str(song)], env=env, stdout=log, stderr=log)
        until(lambda: (folder/'music-view/session.json').exists())
        assert not (folder/'audio-pids').exists(), 'opening Music started a microphone'
        control('record', ok=False)
        (folder/'no-mic').touch()
        control('record', '--source', 'microphone', ok=False)
        assert not (folder/'audio-pids').exists()
        (folder/'no-mic').unlink()
        control('play')
        until(lambda: (folder/'engine-name').exists())
        for source, expected in [('engine', ['21 31', '22 32']), ('microphone', ['11 31', '11 32']),
                                 ('mixed', ['21 31', '22 32', '11 31', '11 32'])]:
            (folder/'links').write_text('')
            control('record', '--source', source)
            state = control('state')['recording']
            assert state['active'] and state['take']['source'] == source
            assert control('bar').strip() == 'REC · '+source
            assert control('record-state').startswith('Recording '+source)
            control('record', ok=False)
            assert (folder/'links').read_text().splitlines() == expected
            time.sleep(.1)
            control('record-stop')
            control('record-stop')
            assert not control('state')['recording']['active']
        takes = control('inbox')['captures']
        assert len(takes) == 3 and all(t['bytes'] > 0 and t['status'] == 'stopped' for t in takes)
        name = takes[0]['id']
        original = (home/'music/inbox'/name/'audio.pcm').read_bytes()
        control('preview', '--take', name)
        until(lambda: not control('state')['recording']['preview'])
        control('loop', '--take', name)
        time.sleep(.4)
        assert control('state')['recording']['preview']
        control('preview-stop')
        control('file', '--take', name, '--song', 'destination')
        control('file', '--take', name, '--song', 'destination')
        filed = list((home/'music/destination/captures').glob('*/*/audio.pcm'))
        assert len(filed) == 2 and all(p.read_bytes() == original for p in filed)
        assert (home/'music/inbox'/name/'audio.pcm').read_bytes() == original
        control('file', '--take', name, '--song', '../escape', ok=False)
        control('preview', '--take', '../escape', ok=False)
        (folder/'recorder-fail').touch()
        control('record', '--source', 'microphone', ok=False)
        (folder/'recorder-fail').unlink()
        control('record', '--source', 'microphone')
        (folder/'no-mic').touch()
        until(lambda: not control('state')['recording']['active'])
        assert 'disappeared' in control('state')['recording']['error']
        (folder/'no-mic').unlink()
        control('record', '--source', 'microphone')
        child.terminate()
        assert child.wait(timeout=15) == 0
        child = None
        # A session interrupted while recording has preserved its take and reaped audio.
        assert list((home/'music/inbox').glob('*/*/*/audio.pcm'))
        for pid in (folder/'audio-pids').read_text().splitlines():
            assert not Path('/proc', pid).exists(), f'audio child {pid} survived'
        for pid in (folder/'engine.pids').read_text().splitlines():
            assert not Path('/proc', pid).exists(), f'engine {pid} survived'
        # Abrupt session death must still release the mic; prewritten metadata
        # and raw audio remain usable without a final stop marker.
        child = subprocess.Popen([str(root/'bin/vikix'), 'music', 'serve', str(song)], env=env, stdout=log, stderr=log)
        until(lambda: (folder/'music-view/session.json').exists())
        control('record', '--source', 'microphone')
        latest = control('state')['recording']['take']['id']
        time.sleep(.1)
        child.kill()
        child.wait(timeout=3)
        child = None
        until(lambda: all(not Path('/proc', pid).exists() for pid in (folder/'audio-pids').read_text().splitlines()))
        partial = home/'music/inbox'/latest
        assert (partial/'audio.pcm').stat().st_size > 0
        assert (partial/'take.json').exists() and not (partial/'stopped.json').exists()

    finally:
        end(child)
        log.close()
    # Write failure after some bytes: keep those bytes and reap the source.
    with patch.dict(os.environ, env):
        captures = Captures(song)
        real_fsync = os.fsync
        calls = [0]
        def full(fd):
            calls[0] += 1
            if calls[0] > 1:
                raise OSError(errno.ENOSPC, 'fixture disk full')
            return real_fsync(fd)
        try:
            with patch('capture.os.fsync', full):
                try:
                    captures.start('microphone', '')
                except ValueError:
                    pass
                until(lambda: not captures.state()['active'])
            assert 'partial audio preserved' in captures.error
            audio = home/'music/inbox'/captures.active['id']/'audio.pcm'
            assert audio.stat().st_size > 0
            assert not (audio.parent/'stopped.json').exists() or captures.listing()[-1]['status'] != 'stopped'
        finally:
            captures.stop()
        for pid in (folder/'audio-pids').read_text().splitlines():
            assert not Path('/proc', pid).exists()
        # Failed filing retains the original and a distinct incomplete target.
        before = audio.read_bytes()
        with patch('capture.shutil.copyfileobj', side_effect=OSError(errno.ENOSPC, 'fixture copy full')):
            try:
                captures.file(captures.active['id'], 'disk-full')
                raise AssertionError('copy should fail')
            except OSError:
                pass
        assert audio.read_bytes() == before
        assert not list((home/'music/disk-full').glob('**/filed.json'))
        copied = Path(captures.file(captures.active['id'], 'disk-full'))
        assert (copied/'filed.json').exists() and (copied/'audio.pcm').read_bytes() == before
print('music capture: public sources, controls, failures, preserved takes, filing, loops and cleanup passed')
