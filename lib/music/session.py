"""Prototype views share one authenticated session; the Lisp child owns time."""
import base64
import fcntl
import hashlib
import http.server
import json
import multiprocessing
import os
from pathlib import Path
import re
import secrets
import signal
import struct
import subprocess
import tempfile
import threading
import time
from types import SimpleNamespace
import webbrowser

from launcher import lisp, perform


class Song:
    """A deliberately small editor: replace note, tempo and bank tokens without reformatting the score."""
    def __init__(self, root, path):
        self.root = root
        supplied = Path(path).absolute()
        if any(p.is_symlink() for p in (supplied, supplied.parent, supplied.parent.parent)):
            raise ValueError("view editing needs a regular song file, not a symlink")
        self.path = supplied.resolve(strict=True)
        folder = (Path.home() / "music").resolve()
        if self.path.parent.parent != folder or self.path.name != "patterns.lisp":
            raise ValueError("views edit ~/music/SONG/patterns.lisp, where snapshot history covers it")
        self.digest = None
        self.refresh()

    def parse(self, text):
        # Lisp remains the authority. This tokenizer keeps offsets, including
        # comments, so changing a cell never reformats the musician's file.
        tokens = [(m.group(), m.start(), m.end()) for m in
                  re.finditer(r";[^\n]*|[^\s()';]+|[()']", text) if not m.group().startswith(';')]
        i, patterns, tempo = 0, [], None
        bank, bank_span = {}, None
        def take(want=None):
            nonlocal i
            if i >= len(tokens):
                raise ValueError("incomplete pattern")
            token = tokens[i]
            i += 1
            if want is not None and token[0].lower() != want:
                raise ValueError("view supports plain tempo and quoted note-list forms")
            return token
        while i < len(tokens):
            start = take('(')
            kind = take()[0].lower()
            if kind == 'tempo':
                tempo = take()
                if not tempo[0].isdigit():
                    raise ValueError("prototype tempo must be a whole number")
                take(')')
            elif kind == 'bank':
                if bank_span is not None:
                    raise ValueError("only one bank form is allowed")
                while i < len(tokens) and tokens[i][0] != ')':
                    slot, name = take(), take()
                    if not slot[0].isdigit() or not 1 <= int(slot[0]) <= 32:
                        raise ValueError("bank pad must be an integer from 1 to 32")
                    number = int(slot[0])
                    if number in bank:
                        raise ValueError(f"duplicate bank pad {number}")
                    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*', name[0]):
                        raise ValueError("bank needs pairs of pad number and pattern name")
                    bank[number] = (slot, name)
                end = take(')')
                bank_span = ('', start[1], end[1])
            elif kind == 'defpattern':
                name = take()[0]
                if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*', name):
                    raise ValueError("prototype pattern names use letters, digits and dashes")
                take("'")
                take('(')
                notes = []
                while i < len(tokens) and tokens[i][0] != ')':
                    note = take()
                    if not re.fullmatch(r'(?i)(?:[a-g][sb]?[0-8]|x|-)', note[0]):
                        raise ValueError("unsupported note in view")
                    notes.append(note)
                take(')')
                take(')')
                patterns.append((name, notes))
            else:
                raise ValueError("unsupported form in view")
        names = {name.lower(): name for name, _ in patterns}
        for slot, (_, name) in bank.items():
            if name[0].lower() not in names:
                raise ValueError(f"unknown bank pattern {name[0]} for pad {slot}")
        return patterns, tempo, bank, bank_span

    def validate(self, data):
        if len(data) > 65536:
            raise ValueError("pattern file exceeds 64 KiB")
        text = data.decode('utf-8')
        patterns, tempo, bank, bank_span = self.parse(text)
        with tempfile.NamedTemporaryFile(suffix='.lisp') as test:
            test.write(data)
            test.flush()
            result = subprocess.run(lisp(self.root, 'check', test.name), capture_output=True, timeout=10)
        if result.returncode:
            raise ValueError("invalid pattern data; keeping the last good pattern")
        return text, patterns, tempo, bank, bank_span

    def read(self):
        if any(p.is_symlink() for p in (self.path, self.path.parent, self.path.parent.parent)):
            raise ValueError('song became a symlink; editing stopped')
        with self.path.open('rb') as stream:
            data = stream.read(65537)
        if len(data) > 65536:
            raise ValueError('pattern file exceeds 64 KiB')
        return data

    def refresh(self):
        data = self.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest != self.digest:
            text, patterns, tempo, bank, bank_span = self.validate(data)
            self.text, self.patterns, self.tempo = text, patterns, tempo
            self.bank, self.bank_span = bank, bank_span
            self.digest = digest
        return self

    def pads(self):
        if self.bank_span is None:
            return {i: name for i, (name, _) in enumerate(self.patterns, 1)}
        names = {name.lower(): name for name, _ in self.patterns}
        return {slot: names[name[0].lower()] for slot, (_, name) in sorted(self.bank.items())}

    def state(self):
        return dict(revision=self.digest, song=self.path.parent.name,
                    bank=self.bank_span is not None,
                    pads=[dict(slot=slot, pattern=name) for slot, name in self.pads().items()],
                    tempo=int(self.tempo[0]) if self.tempo else 120,
                    patterns=[dict(name=n, notes=[t[0].lower() for t in notes]) for n, notes in self.patterns])

    def edit(self, command):
        self.refresh()
        if command.get('revision') != self.digest:
            raise ValueError("song changed; review the refreshed grid and try again")
        if command['op'] == 'assign':
            slot, name = command.get('slot'), command.get('pattern')
            if type(slot) is not int or not 1 <= slot <= 32:
                raise ValueError("bank pad must be an integer from 1 to 32")
            if name is not None and name not in [n for n, _ in self.patterns]:
                raise ValueError("unknown bank pattern")
            if self.bank_span is None:
                pads = self.pads()
                if name is None:
                    pads.pop(slot, None)
                else:
                    pads[slot] = name
                span = ('', len(self.text), len(self.text))
                replacement = '\n(bank' + ''.join(f' {n} {p}' for n, p in sorted(pads.items())) + ')\n'
            elif slot in self.bank:
                number, reference = self.bank[slot]
                span = reference
                replacement = name or ''
                if name is None:
                    # Remove only the two tokens, keeping comments between them.
                    span = ('', number[1], reference[2])
                    replacement = self.text[number[2]:reference[1]]
            else:
                span = ('', self.bank_span[2], self.bank_span[2])
                replacement = f' {slot} {name}' if name is not None else ''
        elif command['op'] == 'tempo':
            value = command.get('value')
            if type(value) is not int or not 60 <= value <= 200:
                raise ValueError("tempo must be 60 to 200")
            span = self.tempo or ('', 0, 0)
            replacement = str(value) if self.tempo else f'(tempo {value})\n'
        else:
            pattern, step, note = command.get('pattern'), command.get('step'), command.get('note')
            notes = next((ns for n, ns in self.patterns if n == pattern), None)
            if notes is None or type(step) is not int or not 0 <= step < len(notes):
                raise ValueError("unknown pattern or step")
            if not isinstance(note, str) or not re.fullmatch(r'(?i)(?:[a-g][sb]?[0-8]|x|-)', note):
                raise ValueError("use c4, cs4, eb4, x or -")
            span, replacement = notes[step], note.lower()
        changed = (self.text[:span[1]] + replacement + self.text[span[2]:]).encode()
        self.validate(changed)
        before = self.read()
        if hashlib.sha256(before).hexdigest() != self.digest:
            raise ValueError("song changed during edit; try again")
        result = subprocess.run([str(self.root / 'bin/vikix'), 'snapshot', 'before: music grid edit'],
                                capture_output=True, timeout=30)
        if result.returncode:
            raise ValueError("snapshot failed; song left unchanged")
        # Atomic replacement prevents the clock reading a half-written form.
        # External editors do not take our lock: recheck after the snapshot.
        with tempfile.NamedTemporaryFile(dir=self.path.parent, prefix='.music-', delete=False) as out:
            temporary = Path(out.name)
            try:
                os.fchmod(out.fileno(), self.path.stat().st_mode & 0o777)
                out.write(changed)
                out.flush()
                os.fsync(out.fileno())
                if self.read() != before:
                    raise ValueError("song changed during snapshot; try again")
                os.replace(temporary, self.path)
            finally:
                temporary.unlink(missing_ok=True)
        self.refresh()


def player(root, path, pattern, control, position):
    try:
        raise SystemExit(perform(root, SimpleNamespace(command='play', file=path, pattern=pattern, bars=None), control, position))
    except KeyboardInterrupt:
        raise SystemExit(0)


class Session:
    def __init__(self, root, path):
        self.song = Song(root, path)
        self.root = root
        self.lock = threading.Lock()
        self.worker = self.control = None
        self.position = None
        self.gain = 0.08
        self.pattern = self.song.patterns[0][0]
        self.closing = False

    def stop(self):
        if self.worker:
            if self.worker.is_alive():
                self.worker.terminate()
            self.worker.join(timeout=12)
            if self.worker.is_alive():
                raise RuntimeError('player did not stop')
            self.worker.close()
            self.worker = None
            self.control.close()
            self.control = None
        self.position = None

    def request(self, command):
        with self.lock:
            error = ''
            try:
                if self.closing:
                    raise ValueError('music session is closing')
                if not isinstance(command, dict):
                    raise ValueError('expected an object')
                op = command.get('op')
                if op in ('note', 'tempo', 'assign'):
                    self.song.edit(command)
                elif op == 'play':
                    self.song.refresh()
                    name = command.get('pattern', self.pattern)
                    if 'slot' in command:
                        if command.get('revision') != self.song.digest:
                            raise ValueError('song changed; review the refreshed pads and try again')
                        slot = command['slot']
                        if type(slot) is not int or slot not in self.song.pads():
                            raise ValueError('unassigned bank pad')
                        name = self.song.pads()[slot]
                    if name not in [n for n, _ in self.song.patterns]:
                        raise ValueError('unknown pattern')
                    if not self.worker or not self.worker.is_alive() or name != self.pattern:
                        self.stop()
                        self.pattern = name
                        # Spawn, never fork a process with HTTP threads and locks.
                        ctx = multiprocessing.get_context('spawn')
                        receive, self.control = ctx.Pipe(duplex=False)
                        self.position = ctx.Array('d', 6)
                        self.worker = ctx.Process(target=player, args=(self.root, str(self.song.path), name, receive, self.position))
                        self.worker.start()
                        receive.close()
                        self.control.send(self.gain)
                elif op == 'stop':
                    self.stop()
                elif op == 'gain':
                    value = command.get('value')
                    if type(value) not in (int, float) or not 0 <= value <= 0.1:
                        raise ValueError('gain must be 0 to 0.1')
                    self.gain = value
                    if self.worker and self.worker.is_alive():
                        self.control.send(value)
                elif op != 'state':
                    raise ValueError('unknown music operation')
                self.song.refresh()
            except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as exc:
                error = str(exc) if not isinstance(exc, subprocess.SubprocessError) else 'validation or snapshot timed out'
            state = self.song.state()
            playing = bool(self.worker and self.worker.is_alive())
            if self.worker and not playing and self.worker.exitcode:
                error = error or 'player exited; check the session terminal'
            state.update(playing=playing, pattern=self.pattern, gain=self.gain, error=error)
            bars = []
            if playing and self.position is not None:
                with self.position.get_lock():
                    values = self.position[:]
                bars = [dict(start=values[i], duration=values[i+1], steps=int(values[i+2]))
                        for i in (0, 3) if values[i+1] > 0]
            state.update(bars=bars, now=time.time())
            return state


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False
    def __init__(self, session):
        self.session = session
        self.token = secrets.token_hex(24)
        self.clients = threading.BoundedSemaphore(8)
        super().__init__(('127.0.0.1', 0), Handler)

    def process_request(self, request, address):
        if not self.clients.acquire(blocking=False):
            request.close()
            return
        super().process_request(request, address)

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.clients.release()


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *args):
        pass  # Never log tokens, URLs or song contents.

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def do_GET(self):
        origin = f'http://127.0.0.1:{self.server.server_port}'
        if self.headers.get('Host') != origin[7:] or self.headers.get('Origin', origin) != origin:
            self.send_error(403)
            return
        if self.path == '/socket':
            if (self.headers.get('Upgrade', '').lower() != 'websocket' or
                    self.headers.get('Sec-WebSocket-Version') != '13'):
                self.send_error(400)
                return
            key = self.headers.get('Sec-WebSocket-Key', '')
            try:
                if len(base64.b64decode(key, validate=True)) != 16:
                    raise ValueError()
            except ValueError:
                self.send_error(400)
                return
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', base64.b64encode(hashlib.sha1(
                (key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode())
            self.end_headers()
            self.close_connection = True
            try:
                first = json.loads(self.frame())
                token = first.get('token') if isinstance(first, dict) else None
                if not isinstance(token, str) or not secrets.compare_digest(token.encode(), self.server.token.encode()):
                    return
                self.reply(self.server.session.request({'op': 'state'}))
                while True:
                    self.reply(self.server.session.request(json.loads(self.frame())))
            except (EOFError, OSError, ValueError, UnicodeError, RecursionError):
                return
        else:
            assets = {'/': ('view.html', 'text/html'), '/view.js': ('view.js', 'text/javascript'), '/view.css': ('view.css', 'text/css')}
            if self.path not in assets:
                self.send_error(404)
                return
            name, mime = assets[self.path]
            data = (self.server.session.root / 'lib/music' / name).read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mime + '; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Security-Policy', "default-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'")
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(data)

    def exact(self, count):
        data = self.rfile.read(count)
        if len(data) != count:
            raise EOFError()
        return data

    def frame(self):
        first, second = self.exact(2)
        if first == 0x88:
            raise EOFError()
        if first != 0x81 or not second & 128:
            raise ValueError('only masked, complete text messages')
        count = second & 127
        if count == 127:
            raise ValueError('message too large')
        if count == 126:
            count = struct.unpack('>H', self.exact(2))[0]
        if count > 4096:
            raise ValueError('message too large')
        mask = self.exact(4)
        return bytes(n ^ mask[i % 4] for i, n in enumerate(self.exact(count))).decode('utf-8')

    def reply(self, value):
        data = json.dumps(value, ensure_ascii=True, separators=(',', ':')).encode()
        self.wfile.write(b'\x81' + (bytes([len(data)]) if len(data) < 126 else b'\x7e' + struct.pack('>H', len(data))) + data)
        self.wfile.flush()


def location():
    folder = Path(os.environ.get('XDG_RUNTIME_DIR', str(Path.home() / '.local/state/vikix'))) / 'music-view'
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    if folder.is_symlink() or folder.stat().st_uid != os.getuid() or folder.stat().st_mode & 0o077:
        raise ValueError('music session directory must be private (0700)')
    return folder


def main(root, args):
    folder = location()
    endpoint = folder / 'session.json'
    if args.command != 'serve':
        try:
            info = json.loads(endpoint.read_text())
        except FileNotFoundError:
            raise ValueError('start vikix music serve first') from None
        if args.command == 'web':
            if not webbrowser.open(f"http://127.0.0.1:{info['port']}/#{info['token']}"):
                raise ValueError('no browser opened; configure your default browser')
            return 0
        from cuis import launch
        return launch(root, endpoint)
    with (folder / 'lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('a music view session is already running') from None
        session = Session(root, args.file)
        server = Server(session)
        def interrupt(signum, frame):
            raise KeyboardInterrupt
        previous = {sig: signal.signal(sig, interrupt) for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        try:
            fd, name = tempfile.mkstemp(dir=folder, prefix='session-')
            try:
                with os.fdopen(fd, 'w') as out:
                    json.dump(dict(port=server.server_port, token=server.token), out)
                os.replace(name, endpoint)
            finally:
                Path(name).unlink(missing_ok=True)
            print('Music session ready. Run vikix music web or vikix music cuis. Ctrl+C ends the session.', flush=True)
            try:
                server.serve_forever(poll_interval=0.2)
            except KeyboardInterrupt:
                pass
        finally:
            for sig in previous:
                signal.signal(sig, signal.SIG_IGN)
            try:
                server.server_close()
                with session.lock:
                    session.closing = True
                    session.stop()
                endpoint.unlink(missing_ok=True)
            finally:
                for sig, handler in previous.items():
                    signal.signal(sig, handler)
    return 0
