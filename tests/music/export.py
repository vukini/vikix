"""Public send launcher: independent SMF decoding, real NRT audio and owned failures."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import wave

root = Path(sys.argv[1])
quicklisp = Path.home() / 'quicklisp'


def parse_midi(path):
    data = path.read_bytes()
    assert data[:4] == b'MThd'
    size, fmt, tracks, ppq = struct.unpack('>IHHH', data[4:14])
    assert (size, fmt, tracks) == (6, 0, 1)
    assert data[14:18] == b'MTrk'
    assert struct.unpack('>I', data[18:22])[0] == len(data) - 22
    pos, ticks, tempo = 22, 0, None
    notes, active = [], {}
    def variable():
        nonlocal pos
        value = 0
        while True:
            byte = data[pos]
            pos += 1
            value = value * 128 + (byte & 127)
            if byte < 128:
                return value
    while pos < len(data):
        ticks += variable()
        status = data[pos]
        pos += 1
        if status == 255:
            kind = data[pos]
            pos += 1
            length = variable()
            payload = data[pos:pos+length]
            pos += length
            if kind == 81:
                tempo = int.from_bytes(payload, 'big')
            if kind == 47:
                assert pos == len(data) and not active
                return tempo, notes, ticks * tempo / (ppq * 1000000)
        else:
            pitch, velocity = data[pos:pos+2]
            pos += 2
            key = status & 15, pitch
            seconds = ticks * tempo / (ppq * 1000000)
            if status & 240 == 144:
                assert key not in active
                active[key] = (seconds, velocity)
            else:
                assert status & 240 == 128
                start, velocity = active.pop(key)
                notes.append((key[0], pitch, start, seconds - start, velocity))
    raise AssertionError('missing end-of-track')


with tempfile.TemporaryDirectory(prefix='music-export-') as temp:
    folder = Path(temp)
    home = folder / 'home'
    home.mkdir()
    song = home / 'music/a song; literal/patterns.lisp'
    song.parent.mkdir(parents=True)
    original = """(tempo 120)
(defpattern tune '(c4 d4 - g4) :sound 'bell :gain .5 :swing .5)
(defprogression verse '((I 2) - vi) :key 'f :sound 'bass :gain .6)
(defpattern drums '(x - x -) :sound 'kick)
(defpattern silent '(- -))
(defpattern muted '(a4 a4) :gain 0)
(bank 1 tune 8 tune 32 verse)
"""
    song.write_text(original)
    env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(home / '.local/share'),
               XDG_RUNTIME_DIR=str(folder / 'runtime'), PYTHONDONTWRITEBYTECODE='1',
               DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
    def run(*args, ok=True, environment=None):
        child = subprocess.Popen([str(root / 'bin/vikix'), 'music', 'send', str(song), *args],
                                 env=environment or env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True, start_new_session=True)
        try:
            out, err = child.communicate(timeout=90)
            assert (child.returncode == 0) == ok, (out, err)
            return Path(out.strip()) if ok else None
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                finally:
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    child.wait(timeout=5)
    batch = run('--format', 'midi', '--repeat', '2')
    manifest = json.loads((batch / 'export.json').read_text())
    assert len(manifest['patterns']) == 5, 'bank duplicates must not duplicate exports'
    decoded = {entry['name']: parse_midi(batch / entry['midi']) for entry in manifest['patterns']}
    tempo, notes, duration = decoded['TUNE']
    assert tempo == 500000 and duration == 4.05, (tempo, duration)
    expected = [(60, 0), (62, .75), (67, 1.75), (60, 2), (62, 2.75), (67, 3.75)]
    for event, (pitch, at) in zip(notes, expected):
        channel, actual, start, length, velocity = event
        assert channel == 0 and actual == pitch and abs(start-at) < 1e-8
        assert abs(length-.3) < 1e-8 and velocity == 64
    assert len(notes) == len(expected)
    tempo, notes, duration = decoded['VERSE']
    assert duration == 16 and len(notes) == 18
    for bar, pitches in ((0, (53, 57, 60)), (1, (53, 57, 60)), (3, (62, 65, 69)),
                         (4, (53, 57, 60)), (5, (53, 57, 60)), (7, (62, 65, 69))):
        group = [n for n in notes if n[2] == bar * 2]
        assert sorted(n[1] for n in group) == list(pitches)
        assert all(abs(n[3]-.3) < 1e-8 and n[4] == 25 for n in group)
    assert all(n[0] == 9 and n[1] == 36 for n in decoded['DRUMS'][1])
    assert decoded['SILENT'][1:] == ([], 4) and decoded['MUTED'][1:] == ([], 4)
    # Fractional score tempo, extreme pitches, X and colliding safe filename spellings.
    song.write_text("(tempo 123.5) (defpattern a.b '(c0 b8 x)) (defpattern a+b '(x))")
    other = run('--format', 'midi')
    files = list(other.glob('*.mid'))
    assert len(files) == 2 and files[0].name != files[1].name
    row = next(p for p in files if p.name.startswith('01-'))
    tempo, notes, duration = parse_midi(row)
    assert tempo == round(60000000/123.5) and [n[1] for n in notes] == [12, 119, 57]
    assert abs(duration - 240/123.5) < .0001
    song.write_text(original)
    render_dir = song.parent / 'render'
    def saved():
        return {str(p.relative_to(render_dir)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in render_dir.rglob('*') if p.is_file()}
    before = saved()
    for args in (('--repeat', '0'), ('--repeat', '17'), ('--pattern', 'missing')):
        run(*args, ok=False)
    song.write_text('#.(error bad)')
    run('--format', 'midi', ok=False)
    song.write_text("(tempo 60) (defprogression long '(" + ' '.join(['(I 16)'] * 8) + '))')
    run('--repeat', '16', '--format', 'midi', ok=False)
    song.write_text(original)
    assert saved() == before
    palette = home / '.local/share/vikix/music/palette-v1.scsyndef'
    palette.parent.mkdir(parents=True)
    palette.write_bytes(b'fake palette for failure tests')
    commands = folder / 'bin'
    commands.mkdir()
    stub = commands / 'scsynth'
    stub.write_text('#!/usr/bin/env python3\nimport sys\nprint("FAILURE injected")\nsys.exit(0)\n')
    stub.chmod(0o755)
    stub_env = dict(env, PATH=str(commands) + ':' + env['PATH'])
    run(environment=stub_env, ok=False)
    assert saved() == before and not list(render_dir.glob('.send-*'))
    # Interrupt during either score reading or NRT rendering, reaping that child.
    marker = folder / 'child.pid'
    slow = '#!/usr/bin/env python3\nimport os,time,pathlib\n' + f'pathlib.Path({str(marker)!r}).write_text(str(os.getpid()))\ntime.sleep(60)\n'
    for executable in ('scsynth', 'sbcl'):
        target = commands / executable
        target.write_text(slow)
        target.chmod(0o755)
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            marker.unlink(missing_ok=True)
            child = subprocess.Popen([str(root / 'bin/vikix'), 'music', 'send', str(song)],
                                     env=stub_env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     start_new_session=True)
            try:
                deadline = time.monotonic() + 10
                while not marker.exists() and time.monotonic() < deadline:
                    time.sleep(.02)
                assert marker.exists()
                pid = int(marker.read_text())
                child.send_signal(sig)
                child.wait(timeout=8)
                assert child.returncode != 0 and not Path('/proc', str(pid)).exists()
                assert saved() == before and not list(render_dir.glob('.send-*'))
            finally:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait(timeout=5)
        target.unlink()
    if not (quicklisp / 'setup.lisp').exists() or not shutil.which('scsynth'):
        print('SKIP: real export WAV requires installed Quicklisp/cl-collider and SuperCollider')
    else:
        (home / 'quicklisp').symlink_to(quicklisp)
        compile_env = dict(env, VIKIX_MUSIC_SYNTH=str(palette),
                           ASDF_OUTPUT_TRANSLATIONS=f'(:output-translations (t "{folder}/fasl/") :ignore-inherited-configuration)')
        result = subprocess.run(['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--non-interactive',
                                 '--load', str(root / 'lib/music/synth.lisp')],
                                env=compile_env, capture_output=True, timeout=180)
        assert result.returncode == 0, result.stderr[-4000:]
        # A live public player owns a stub TCP engine; send uses the real NRT engine.
        real_engine = shutil.which('scsynth')
        stub.write_text('#!/usr/bin/env python3\nimport os,sys\n' +
                        f'command = [{real_engine!r}] if "-N" in sys.argv else [sys.executable, {str(root / "tests/music/check.py")!r}, "--engine"]\n' +
                        'os.execv(command[0], command + sys.argv[1:])\n')
        stub.chmod(0o755)
        jack = commands / 'pw-jack'
        jack.write_text('#!/bin/sh\nexec "$@"\n')
        jack.chmod(0o755)
        live_env = dict(stub_env, MUSIC_TEST=str(folder))
        player = subprocess.Popen([str(root / 'bin/vikix'), 'music', 'play', str(song)],
                                  env=live_env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  start_new_session=True)
        try:
            deadline = time.monotonic() + 15
            while not (folder / 'events').exists() and time.monotonic() < deadline:
                time.sleep(.05)
            assert (folder / 'events').exists()
            engine_pid = int((folder / 'engine.pid').read_text())
            batch = run(environment=live_env)
            assert player.poll() is None and Path('/proc', str(engine_pid)).exists()
            previous_events = (folder / 'events').stat().st_size
            deadline = time.monotonic() + 5
            while (folder / 'events').stat().st_size == previous_events and time.monotonic() < deadline:
                time.sleep(.05)
            assert (folder / 'events').stat().st_size > previous_events
        finally:
            player.terminate()
            try:
                player.wait(timeout=8)
            finally:
                try:
                    os.killpg(player.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                player.wait(timeout=5)
        assert not Path('/proc', str(engine_pid)).exists()
        manifest = json.loads((batch / 'export.json').read_text())
        for entry in manifest['patterns']:
            with wave.open(str(batch / entry['wav'])) as stream:
                assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) == (2, 2, 48000)
                expected_duration = 2.053 + 128/48000 if entry['name'] == 'TUNE' else (8 if entry['name'] == 'VERSE' else 2)
                assert abs(stream.getnframes() / 48000 - expected_duration) < 1/48000
                samples = struct.unpack('<' + 'h' * stream.getnframes() * 2, stream.readframes(stream.getnframes()))
                peak = max(map(abs, samples))
                assert (peak > 100) == (entry['name'] not in ('SILENT', 'MUTED')), (entry, peak)
        again = run('--pattern', 'tune', '--format', 'wav')
        assert again != batch and len(list(again.glob('*.wav'))) == 1 and not list(again.glob('*.mid'))
        assert all(saved()[key] == value for key, value in before.items())
        before_failure = saved()
        counter = folder / 'renders'
        stub.write_text('#!/usr/bin/env python3\nimport os,sys,pathlib\n' +
                        f'p = pathlib.Path({str(counter)!r})\n' +
                        'n = int(p.read_text()) if p.exists() else 0\np.write_text(str(n+1))\n' +
                        'if n: print("FAILURE injected after first render"); sys.exit(1)\n' +
                        f'os.execv({real_engine!r}, [{real_engine!r}] + sys.argv[1:])\n')
        run(environment=stub_env, ok=False)
        assert counter.read_text() == '2'
        assert saved() == before_failure and not list(render_dir.glob('.send-*'))
        print('music export: real offline stereo 48 kHz PCM16, duration, audible and silent fixtures passed')
    assert song.read_text() == original
    print('music export: independent MIDI notes/tempo/duration, repeats, failure and signal cleanup passed')
