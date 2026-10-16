"""Shared protocol, filesystem safety, real browser and disposable Cuis clients."""
import base64
import http.client
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import select
import socket
import struct
import subprocess
import sys
import tempfile
import time

root = Path(sys.argv[1])
sys.path.insert(0, str(root / 'lib/music'))
from cuis import prepare, quote


def until(test, seconds=15):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = test()
        if value:
            return value
        time.sleep(.1)
    raise AssertionError('condition timed out')


class Client:
    def __init__(self, info, token=None, origin=None):
        self.sock = socket.create_connection(('127.0.0.1', info['port']), timeout=5)
        self.stream = self.sock.makefile('rb')
        extra = f'Origin: {origin}\r\n' if origin else ''
        self.sock.sendall((f"GET /socket HTTP/1.1\r\nHost: 127.0.0.1:{info['port']}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n{extra}\r\n").encode())
        self.status = self.stream.readline()
        while self.stream.readline() not in (b'\r\n', b''):
            pass
        if b'101' in self.status:
            self.send(dict(token=info['token'] if token is None else token))
            self.state = self.receive()

    def send(self, data):
        body = json.dumps(data).encode()
        mask = os.urandom(4)
        size = bytes([128 + len(body)]) if len(body) < 126 else b'\xfe' + struct.pack('>H', len(body))
        self.sock.sendall(b'\x81' + size + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(body)))

    def receive(self):
        header = self.stream.read(2)
        if not header:
            return None
        assert header[0] == 129, header
        size = header[1]
        if size == 126:
            size = struct.unpack('>H', self.stream.read(2))[0]
        return json.loads(self.stream.read(size))

    def request(self, op, **fields):
        self.send(dict(op=op, **fields))
        self.state = self.receive()
        return self.state

    def close(self):
        self.stream.close()
        self.sock.close()


def end(child):
    if child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait(timeout=5)
    return child.returncode


with tempfile.TemporaryDirectory(prefix='music-views-test-') as temp:
    folder = Path(temp)
    home = folder / 'home'
    home.mkdir()
    runtime = folder / 'runtime'
    runtime.mkdir(mode=0o700)
    song = home / 'music/first-song/patterns.lisp'
    song.parent.mkdir(parents=True)
    original = "; keep my comment\n(tempo 120) ; the pace\n(defpattern melody '(a5 - c6 - e6 - c6 -))\n(defpattern bass '(a4 -))\n"
    song.write_text(original)
    synth = home / '.local/share/vikix/music/tone.scsyndef'
    synth.parent.mkdir(parents=True)
    synth.write_bytes(b'test synth')
    commands = folder / 'bin'
    commands.mkdir()
    (commands / 'sbcl').write_text('#!/bin/sh\necho $$ >> "$MUSIC_TEST/lisp.pids"\nexec ' + shlex.quote(shutil.which('sbcl')) + ' "$@"\n')
    (commands / 'pw-jack').write_text('#!/bin/sh\nexec "$@"\n')
    (commands / 'scsynth').write_text('#!/bin/sh\nexec python3 ' + shlex.quote(str(root / 'tests/music/check.py')) + ' --engine "$@"\n')
    (commands / 'notify-send').write_text('#!/bin/sh\nexit 0\n')
    for path in commands.iterdir():
        path.chmod(0o755)
    env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime), MUSIC_TEST=str(folder),
               PATH=str(commands) + ':' + os.environ['PATH'], DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
               PYTHONDONTWRITEBYTECODE='1')
    # Cuis's installed base is read-only; never use the musician's saved image.
    env['VIKIX_CUIS_OPT'] = os.environ.get('VIKIX_CUIS_OPT', str(Path.home() / '.local/opt/cuis'))
    endpoint = runtime / 'music-view/session.json'
    clients, children = [], []
    log = (folder / 'server.log').open('w+')
    service = subprocess.Popen([str(root / 'bin/vikix-music'), 'serve'], env=env, stdout=log, stderr=log, start_new_session=True)
    children.append(service)
    try:
        until(lambda: endpoint.exists() or service.poll() is not None)
        assert service.poll() is None, (folder / 'server.log').read_text()
        info = json.loads(endpoint.read_text())
        duplicate = subprocess.run([str(root / 'bin/vikix-music'), 'serve'], env=env, capture_output=True, timeout=10)
        assert duplicate.returncode and b'already running' in duplicate.stderr
        assert endpoint.exists()
        assert endpoint.stat().st_mode & 0o077 == 0
        # Exercise both public view launchers without touching the live desktop.
        opener = commands / 'open-browser'
        opener.write_text('#!/bin/sh\nprintf \'%s\\n\' "$1" > "$MUSIC_TEST/browser-url"\n')
        opener.chmod(0o755)
        opened = subprocess.run([str(root / 'bin/vikix-music'), 'web'], env=dict(env, BROWSER=str(opener)), capture_output=True, timeout=10)
        assert opened.returncode == 0, opened.stderr
        assert (folder / 'browser-url').read_text().strip() == f"http://127.0.0.1:{info['port']}/#{info['token']}"
        fake_base = folder / 'fake-cuis/base'
        for directory in ('CuisImage', 'Packages', 'CoreUpdates', 'TrueTypeFonts', 'CuisVM.app/Contents/Linux-x86_64'):
            (fake_base / directory).mkdir(parents=True)
        for name in ('Cuis7.7-7976.image', 'Cuis7.7-7976.changes'):
            (fake_base / 'CuisImage' / name).write_text('stand-in image')
        vm = fake_base / 'CuisVM.app/Contents/Linux-x86_64/squeak'
        vm.write_text('#!/bin/sh\nprintf \'%s\\n\' "$@" > "$MUSIC_TEST/cuis-argv"\nfor arg do last=$arg; done\ncp "$last" "$MUSIC_TEST/cuis-script"\n')
        vm.chmod(0o755)
        opened = subprocess.run([str(root / 'bin/vikix-music'), 'cuis'], env=dict(env, VIKIX_CUIS_OPT=str(fake_base.parent)), capture_output=True, timeout=10)
        assert opened.returncode == 0, opened.stderr
        args = (folder / 'cuis-argv').read_text().splitlines()
        assert args[0] == '-vm-sound-null' and args[1].endswith('/image/music.image'), args
        assert not Path(args[1]).parent.parent.exists(), 'disposable image was not cleaned'
        assert 'VikixMusic' in (folder / 'cuis-script').read_text()
        assert not (home / 'cuis').exists(), 'view launcher touched a saved image'
        a, b = Client(info), Client(info)
        clients += [a, b]
        padding = 'x' * (127 - len(json.dumps(dict(op='state', pad=''))))
        assert not a.request('state', pad=padding)['error']
        wrong = Client(info, token='wrong'); clients.append(wrong)
        assert wrong.state is None
        wrong.close(); clients.remove(wrong)
        hostile = Client(info, origin='http://example.invalid'); clients.append(hostile)
        assert b'403' in hostile.status
        hostile.close(); clients.remove(hostile)
        connection = http.client.HTTPConnection('127.0.0.1', info['port'], timeout=5)
        connection.request('GET', '/', headers={'Host': 'evil.invalid'})
        assert connection.getresponse().status == 403
        connection.close()
        revision = a.state['revision']
        state = a.request('note', revision=revision, pattern='melody', step=0, note='e6')
        assert not state['error'], state
        assert song.read_text() == original.replace("'(a5", "'(e6")
        assert (home / '.local/state/vikix/yours.git').exists()
        assert b.request('state')['revision'] == state['revision']
        conflict = b.request('note', revision=revision, pattern='melody', step=1, note='a5')
        assert 'song changed' in conflict['error'], conflict
        before = song.read_bytes()
        unsafe = a.request('note', revision=state['revision'], pattern='melody', step=0, note='#.(quit)')
        assert unsafe['error'] and song.read_bytes() == before
        # A failed snapshot must never become a silent, unrecorded file edit.
        (commands / 'git').write_text('#!/bin/sh\nexit 1\n')
        (commands / 'git').chmod(0o755)
        failed = a.request('tempo', revision=state['revision'], value=160)
        assert 'snapshot failed' in failed['error'] and song.read_bytes() == before, failed
        (commands / 'git').unlink()
        assert a.request('tempo', revision=state['revision'], value=160)['tempo'] == 160
        song.write_text(song.read_text().replace('160', '180'))
        assert a.request('state')['tempo'] == 180
        good = song.read_bytes()
        song.write_text('#.(quit)')
        assert a.request('state')['error']
        song.write_bytes(good)
        assert not a.request('state')['error']
        assert a.request('play', pattern='melody')['playing']
        until(lambda: (folder / 'events').exists())
        until(lambda: bool(a.request('state')['bars']))
        bar = a.state['bars'][-1]
        assert bar['steps'] == 8 and abs(bar['duration'] - 240/180) < .001, bar
        song.write_text(song.read_text().replace('(tempo 180)', '(tempo 120)'))
        until(lambda: any(abs(bar['duration'] - 2) < .001 for bar in a.request('state')['bars']))
        # Silent bars still carry position: telemetry must not depend on notes.
        silence = song.read_text().replace("'(e6 - c6 - e6 - c6 -)", "'(- - - - - - - -)")
        song.write_text(silence)
        previous_start = a.state['bars'][-1]['start']
        until(lambda: a.request('state')['bars'][-1]['start'] > previous_start)
        song.write_bytes(good)
        a.close(); clients.remove(a)
        b.close(); clients.remove(b)
        time.sleep(.3)
        c = Client(info); clients.append(c)
        assert c.state['playing'], c.state
        assert c.request('gain', value=.04)['gain'] == .04
        until(lambda: any(abs(json.loads(line).get('gain', 0) - .04) < .0001 for line in (folder / 'events').read_text().splitlines()))
        assert c.request('gain', value=1)['error']
        assert not c.request('stop')['playing']
        assert c.state['bars'] == []
        c.close(); clients.remove(c)
        print('music views: auth, origin, snapshots, preservation, conflicts, external edits, disconnect and transport passed', flush=True)

        # Compile and drive the actual Cuis model and window, in a separate image.
        base = Path(env['VIKIX_CUIS_OPT']) / 'base'
        if (base / 'CuisVM.app/Contents/Linux-x86_64/squeak').exists():
            cu = folder / 'cuis'
            cu.mkdir()
            old = os.environ.get('VIKIX_CUIS_OPT')
            os.environ['VIKIX_CUIS_OPT'] = env['VIKIX_CUIS_OPT']
            try:
                command = prepare(root, cu, endpoint)
            finally:
                if old is None:
                    os.environ.pop('VIKIX_CUIS_OPT', None)
                else:
                    os.environ['VIKIX_CUIS_OPT'] = old
            script = cu / 'open.st'
            script.write_text("""| window model deadline |
[ Feature require: 'Network-Kernel'. Feature require: 'JSON'.
Feature require: PACKAGE.
UISupervisor ui submorphs copy do: [ :m | (m isKindOf: SystemWindow) ifTrue: [ m delete ] ].
window := (Smalltalk at: #VikixMusic) openFrom: ENDPOINT.
model := window model.
deadline := Time millisecondClockValue + 10000.
[ model state isNil and: [ Time millisecondClockValue < deadline ] ] whileTrue: [ (Delay forMilliseconds: 100) wait ].
model state ifNil: [ Error signal: model problem ].
window step.
window tempo: -10.
(Delay forSeconds: 2) wait.
window step.
((model state at: 'tempo') = 170) ifFalse: [ Error signal: (model state printString) ].
window noteAt: 2.
(Delay forSeconds: 2) wait.
window step.
(((model state at: 'patterns') first at: 'notes') second = 'a5') ifFalse: [ Error signal: model state printString ].
window play.
(Delay forSeconds: 2) wait.
(model state at: 'playing') ifFalse: [ Error signal: 'Cuis play failed' ].
UISupervisor whenUIinSafeState: [ UISupervisor ui submorphs copy do: [ :m | (m isKindOf: TranscriptWindow) ifTrue: [ m delete ] ] ].
StdIOWriteStream stdout nextPutAll: 'MUSIC-CUIS-PASS'; newLine; flush.
] on: Error do: [ :ex | StdIOWriteStream stdout nextPutAll: 'MUSIC-CUIS-FAIL ', ex description; newLine; flush ].
[ (Delay forSeconds: 3) wait.
  UISupervisor whenUIinSafeState: [
    ((window statusText includesSubString: 'Playing') and: [ window statusText includesSubString: '175 BPM' ])
      ifTrue: [ StdIOWriteStream stdout nextPutAll: 'MUSIC-CUIS-REFRESH-PASS'; newLine; flush ]
      ifFalse: [ StdIOWriteStream stdout nextPutAll: 'MUSIC-CUIS-REFRESH-FAIL ', window statusText; newLine; flush ].
    window delete. Smalltalk quit ] ] fork.
""".replace('PACKAGE', quote(root / 'lib/music/VikixMusic.pck.st')).replace('ENDPOINT', quote(endpoint)))
            graphical = bool(shutil.which('Xvfb') and shutil.which('import'))
            cu_env = dict(env, SQUEAK_DISPLAY_PER_MONITOR_SCALE='1')
            if graphical:
                read_fd, write_fd = os.pipe()
                display_log = (folder / 'display.log').open('w')
                try:
                    display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x900x24', '-nolisten', 'tcp'],
                                               pass_fds=(write_fd,), stdout=display_log, stderr=display_log, start_new_session=True)
                    children.append(display)
                    os.close(write_fd); write_fd = None
                    assert select.select([read_fd], [], [], 10)[0], 'Xvfb did not start'
                    number = os.read(read_fd, 30).decode().strip()
                    assert number.isdigit(), number
                    cu_env['DISPLAY'] = ':' + number
                finally:
                    os.close(read_fd)
                    if write_fd is not None:
                        os.close(write_fd)
            else:
                command.insert(1, '-vm-display-null')
            cu_log = (folder / 'cuis.log').open('w')
            image = subprocess.Popen(command, cwd=cu, env=cu_env, stdout=cu_log, stderr=cu_log, start_new_session=True)
            children.append(image)
            until(lambda: 'MUSIC-CUIS-' in (folder / 'cuis.log').read_text() or image.poll() is not None, 30)
            output = (folder / 'cuis.log').read_text()
            assert 'MUSIC-CUIS-PASS' in output, output
            song.write_text(song.read_text().replace('(tempo 170)', '(tempo 175)'))
            artifacts = os.environ.get('MUSIC_VIEW_ARTIFACTS')
            if graphical and artifacts:
                time.sleep(1)
                dest = Path(artifacts); dest.mkdir(parents=True, exist_ok=True)
                subprocess.run(['import', '-window', 'root', str(dest / 'music-cuis.png')], env=cu_env, check=True, timeout=10)
            assert image.wait(timeout=10) == 0, (folder / 'cuis.log').read_text()
            assert 'MUSIC-CUIS-REFRESH-PASS' in (folder / 'cuis.log').read_text(), (folder / 'cuis.log').read_text()
            cu_log.close()
            if graphical:
                end(display)
                display_log.close()
            client = Client(info); clients.append(client)
            assert client.state['playing'], client.state
            client.request('stop')
            client.close(); clients.remove(client)
            print('music views: real Cuis grid, tempo, playback, automatic redraw and window closure passed', flush=True)
        else:
            print('SKIP: Cuis base unavailable', flush=True)

        connection = http.client.HTTPConnection('127.0.0.1', info['port'], timeout=5)
        connection.request('GET', '/')
        response = connection.getresponse()
        assert response.status == 200 and response.getheader('Content-Type') == 'text/html; charset=utf-8', (response.status, response.getheaders())
        assert b'Your next phrase.' in response.read()
        connection.close()
        # A real Chromium page: button events and websocket, no browser audio.
        try:
            import websocket
        except ImportError:
            websocket = None
        browser = shutil.which('chromium')
        if browser and websocket:
            profile = folder / 'browser'
            browser_log = (folder / 'browser.log').open('w')
            browser_env = dict(env)
            browser_env.pop('CHROME_FLAGS', None)
            child = subprocess.Popen([browser, '--headless', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
                                      '--disable-breakpad', '--disable-crash-reporter', '--no-first-run', '--no-proxy-server', '--remote-debugging-port=0', '--remote-allow-origins=http://localhost',
                                      f'--user-data-dir={profile}', 'about:blank'], env=browser_env, stdout=browser_log, stderr=browser_log, start_new_session=True)
            children.append(child)
            until(lambda: (profile / 'DevToolsActivePort').exists())
            port = int((profile / 'DevToolsActivePort').read_text().splitlines()[0])
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
            conn.request('GET', '/json/list')
            target = next(t for t in json.loads(conn.getresponse().read()) if t['type'] == 'page')
            conn.close()
            ws = websocket.create_connection(target['webSocketDebuggerUrl'], timeout=5, origin='http://localhost')
            sequence = 0
            def cdp(method, params):
                global sequence
                sequence += 1
                ws.send(json.dumps(dict(id=sequence, method=method, params=params)))
                while True:
                    reply = json.loads(ws.recv())
                    if reply.get('id') == sequence:
                        assert 'error' not in reply, reply
                        return reply.get('result', {})
            def js(expression):
                result = cdp('Runtime.evaluate', dict(expression=expression, returnByValue=True))
                assert 'exceptionDetails' not in result, result
                return result['result'].get('value')
            cdp('Emulation.setDeviceMetricsOverride', dict(width=1100, height=850, deviceScaleFactor=1, mobile=False))
            cdp('Page.enable', {})
            cdp('Runtime.enable', {})
            until(lambda: js('document.readyState') == 'complete')
            time.sleep(1)
            cdp('Page.stopLoading', {})
            cdp('Network.enable', {})
            navigation = cdp('Page.navigate', dict(url=f"http://127.0.0.1:{info['port']}/#{info['token']}"))
            assert not navigation.get('errorText'), navigation.get('errorText')
            try:
                until(lambda: js("document.querySelectorAll('.step').length") == 8)
            except AssertionError:
                print('browser state:', js("document.body.innerText"), flush=True)
                raise
            assert js('location.hash') == ''
            def subtitle():
                return js("document.querySelector('#subtitle').textContent")
            until(lambda: "(defpattern melody '(e6 a5 c6" in subtitle())
            js("document.querySelector('#pattern').value='bass'; document.querySelector('#pattern').dispatchEvent(new Event('change'))")
            assert "(defpattern bass '(a4 -))" in subtitle()
            js("document.querySelector('#pattern').value='melody'; document.querySelector('#pattern').dispatchEvent(new Event('change'))")
            until(lambda: js("typeof busy !== 'undefined' && !busy"))
            js("document.querySelector('#tempo').value=150; document.querySelector('#tempo').dispatchEvent(new Event('change'))")
            until(lambda: '(tempo 150)' in song.read_text())
            until(lambda: subtitle().startswith('(tempo 150)\n'))
            until(lambda: js('!busy'))
            js("document.querySelector('#play').click()")
            until(lambda: js("document.querySelector('#playing').textContent.startsWith('Playing')"))
            until(lambda: js("document.querySelectorAll('.step.current').length") == 1)
            first_step = js("document.querySelector('.step.current').getAttribute('aria-label')")
            until(lambda: js("document.querySelector('.step.current')?.getAttribute('aria-label')") not in (None, first_step))
            assert js("document.querySelector('#pads [aria-pressed=true]').textContent") == 'melody'
            js("document.querySelector('#pads button[data-pattern=bass]').click()")
            until(lambda: js("document.querySelector('#pads [aria-pressed=true]')?.textContent") == 'bass')
            until(lambda: js("document.querySelectorAll('.step.current').length") == 1)
            assert js("document.querySelectorAll('.step').length") == 2
            js("document.querySelector('#pads button[data-pattern=melody]').click()")
            until(lambda: js("document.querySelector('#pads [aria-pressed=true]')?.textContent") == 'melody')
            until(lambda: js('!busy'))
            js("document.querySelectorAll('.step')[3].click()")
            until(lambda: "'(e6 a5 c6 a5" in song.read_text())
            until(lambda: js("document.querySelectorAll('.step strong')[3].textContent") == 'A5')
            assert "'(e6 a5 c6 a5" in subtitle()
            song.write_text(song.read_text().replace("'(e6 a5", "'(b5 a5"))
            until(lambda: js("document.querySelectorAll('.step strong')[0].textContent") == 'B5')
            assert "'(b5 a5 c6 a5" in subtitle()
            good = song.read_text()
            last_subtitle = subtitle()
            song.write_text('#.(quit)')
            until(lambda: js('Boolean(state.error)'))
            assert subtitle() == last_subtitle
            song.write_text(good)
            until(lambda: js('!busy'))
            js("document.querySelector('#stop').click()")
            until(lambda: js("document.querySelector('#playing').textContent") == 'Stopped')
            until(lambda: js("document.querySelectorAll('.step.current').length") == 0)
            js("document.querySelector('#play').click()")
            until(lambda: js("document.querySelector('#playing').textContent.startsWith('Playing')"))
            artifacts = os.environ.get('MUSIC_VIEW_ARTIFACTS')
            if artifacts:
                until(lambda: js("document.querySelectorAll('.step.current').length") == 1)
                screenshot = cdp('Page.captureScreenshot', {'format': 'png'})
                dest = Path(artifacts); dest.mkdir(parents=True, exist_ok=True)
                (dest / 'music-web.png').write_bytes(base64.b64decode(screenshot['data']))
            js('ws.close()')
            until(lambda: js("document.querySelector('#playing').textContent") == 'Playback status unknown')
            until(lambda: js("document.querySelectorAll('.step.current').length") == 0)
            assert js("document.querySelectorAll('#pads [aria-pressed=true]').length") == 0
            ws.close()
            assert end(child) in (0, -15)
            browser_log.close()
            client = Client(info); clients.append(client)
            assert client.state['playing']
            client.request('stop')
            client.close(); clients.remove(client)
            print('music views: real browser grid, tempo, play and view closure passed', flush=True)
        else:
            print('SKIP: browser or websocket test driver unavailable', flush=True)
    finally:
        for client in clients:
            client.close()
        for child in reversed(children):
            end(child)
        log.close()
        if service.returncode:
            print((folder / 'server.log').read_text())
    assert not endpoint.exists()
    for name in ('engine.pids', 'lisp.pids'):
        for pid in (folder / name).read_text().splitlines():
            assert not Path('/proc', pid).exists(), f'owned music child {pid} still exists'
    print('music views: session shutdown removed endpoint and reaped player', flush=True)
