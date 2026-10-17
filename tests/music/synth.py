"""Compile the shipped palette and render it offline; never open an audio device."""
import math
import os
import shutil
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import wave

root = Path(sys.argv[1])
sys.path.insert(0, str(root / 'lib/music'))
from launcher import message

quicklisp = Path.home() / 'quicklisp'
if not (quicklisp / 'setup.lisp').exists() or not shutil.which('scsynth'):
    print('SKIP: offline synthesis requires installed Quicklisp/cl-collider and SuperCollider')
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='music-synthesis-') as temp:
    folder = Path(temp)
    (folder / 'quicklisp').symlink_to(quicklisp)
    synth = folder / 'palette.scsyndef'
    env = dict(os.environ, HOME=str(folder), XDG_CACHE_HOME=str(folder / 'cache'),
               VIKIX_MUSIC_SYNTH=str(synth), DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
               ASDF_OUTPUT_TRANSLATIONS=f'(:output-translations (t "{folder}/fasl/") :ignore-inherited-configuration)')
    compile_result = subprocess.run(
        ['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--non-interactive',
         '--load', str(root / 'lib/music/synth.lisp')],
        env=env, capture_output=True, text=True, timeout=180)
    assert compile_result.returncode == 0, compile_result.stderr[-6000:]
    payload = synth.read_bytes()
    assert payload[:4] == b'SCgf' and struct.unpack('>H', payload[8:10])[0] == 6
    # Frozen 0.72.87 definition: byte-for-byte compatibility, not just similar peaks.
    legacy = folder / 'legacy.scsyndef'
    legacy_env = dict(env, VIKIX_MUSIC_SYNTH=str(legacy))
    result = subprocess.run(
        ['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--non-interactive',
         '--load', str(root / 'tests/music/legacy-sine.lisp')],
        env=legacy_env, capture_output=True, text=True, timeout=180)
    assert result.returncode == 0, result.stderr[-6000:]
    assert payload[10:].startswith(legacy.read_bytes()[10:]), 'released sine definition changed'
    def bundle(at, *messages):
        data = b'#bundle\0' + struct.pack('>Q', int(at * 2**32))
        for item in messages:
            data += struct.pack('>I', len(item)) + item
        return struct.pack('>I', len(data)) + data
    # Separate voices by a second to verify finite sound and node envelope cleanup.
    score = bundle(0, message('/d_recv', payload))
    sounds = ('tone', 'kick', 'snare', 'closed-hat', 'bass', 'bell')
    for i, sound in enumerate(sounds):
        score += bundle(i + .1, message('/s_new', 'vikix-' + sound, 100+i, 0, 0,
                                      'freq', 440.0, 'dur', .3, 'amp', .1))
    score += bundle(6, message('/c_set', 0, 0))
    source, output = folder / 'score.osc', folder / 'render.wav'
    source.write_bytes(score)
    result = subprocess.run(['scsynth', '-D', '0', '-R', '0', '-i', '0', '-o', '2',
                             '-N', str(source), '_', str(output), '48000', 'WAV', 'int16'],
                            env=env, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0 and 'FAILURE' not in result.stdout + result.stderr, result.stdout + result.stderr
    with wave.open(str(output)) as stream:
        assert stream.getnchannels() == 2 and stream.getsampwidth() == 2
        samples = struct.unpack('<' + 'h' * stream.getnframes() * 2, stream.readframes(stream.getnframes()))
    peaks = []
    for i, sound in enumerate(sounds):
        segment = samples[i*48000*2:(i+1)*48000*2]
        peak = max(abs(n) for n in segment) / 32768
        assert .005 < peak <= .1001, (sound, peak)
        assert all(n == 0 for n in segment[int(.6*48000)*2:]), (sound, 'voice outlived envelope')
        assert all(math.isfinite(n) for n in segment)
        peaks.append(round(peak, 5))
    print('music synthesis: six real compiled voices, offline peaks <= 0.1 and silent tails:', peaks)
