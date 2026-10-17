"""Real public Music launcher, SBCL, SC and recorder on a private PipeWire graph."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

root = Path(sys.argv[1])
sys.path.insert(0, str(root/'lib/music'))
from launcher import end
quicklisp = Path.home()/'quicklisp'
if not (quicklisp/'setup.lisp').exists() or not all(shutil.which(n) for n in ('pipewire', 'scsynth', 'pw-record')):
    print('SKIP: capture routing needs PipeWire, SuperCollider and Quicklisp')
    raise SystemExit(0)


def until(check, seconds=15):
    deadline = time.monotonic()+seconds
    while time.monotonic() < deadline:
        value = check()
        if value:
            return value
        time.sleep(.1)
    raise AssertionError('private routing condition timed out')


with tempfile.TemporaryDirectory(prefix='music-private-audio-') as temp:
    folder = Path(temp)
    (folder/'quicklisp').symlink_to(quicklisp)
    synth = folder/'.local/share/vikix/music/palette-v1.scsyndef'
    synth.parent.mkdir(parents=True)
    env = dict(os.environ, HOME=temp, XDG_RUNTIME_DIR=temp, PIPEWIRE_RUNTIME_DIR=temp,
               PIPEWIRE_REMOTE='pipewire-0', JACK_DEFAULT_SERVER='default',
               XDG_CONFIG_HOME=str(folder/'config'), XDG_CACHE_HOME=str(folder/'cache'),
               VIKIX_MUSIC_SYNTH=str(synth), DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
               ASDF_OUTPUT_TRANSLATIONS=f'(:output-translations (t "{folder}/fasl/") :ignore-inherited-configuration)')
    for key in ('PIPEWIRE_PROPS', 'SC_JACK_DEFAULT_OUTPUTS', 'SC_JACK_DEFAULT_INPUTS'):
        env.pop(key, None)
    result = subprocess.run(['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--non-interactive',
                             '--load', str(root/'lib/music/synth.lisp')], env=env,
                            capture_output=True, text=True, timeout=180)
    assert result.returncode == 0, result.stderr[-2000:]
    song = folder/'music/fixture/patterns.lisp'
    song.parent.mkdir(parents=True)
    song.write_text("(tempo 200)\n(defpattern test '(a4 a4 a4 a4))\n")
    children = []
    def command(*args):
        result = subprocess.run([str(root/'bin/vikix'), 'music', 'control', *args], env=env,
                                capture_output=True, text=True, timeout=25)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout) if result.stdout.startswith('{') else result.stdout
    def graph():
        return json.loads(subprocess.check_output(['pw-dump'], env=env, timeout=3))
    with (folder/'log').open('w') as log:
        try:
            children.append(subprocess.Popen(['pipewire'], env=env, stdout=log, stderr=log))
            until(lambda: (folder/'pipewire-0').exists())
            children.append(subprocess.Popen([str(root/'bin/vikix'), 'music', 'serve', str(song)], env=env, stdout=log, stderr=log))
            until(lambda: (folder/'music-view/session.json').exists())
            command('play')
            until(lambda: any(x.get('info', {}).get('props', {}).get('node.name', '').startswith('vikix-music-') for x in graph()))
            command('record')
            assert command('state')['recording']['take']['source'] == 'engine'
            time.sleep(.6)
            command('record-stop')
            take = command('inbox')['captures'][0]
            audio = folder/'music/inbox'/take['id']/'audio.pcm'
            assert take['bytes'] > 0 and any(audio.read_bytes()), 'real engine capture was silent'
            command('stop')
            end(children.pop())
            assert not any(x.get('info', {}).get('props', {}).get('node.name', '').startswith(('vikix-record-', 'vikix-music-')) for x in graph()), 'owned audio node survived'
        finally:
            for child in reversed(children):
                end(child)
            assert all(child.poll() is not None for child in children)
print('music capture routing: public launcher, real SBCL/SC, nonzero private PipeWire audio and cleanup passed; no desktop listening')
