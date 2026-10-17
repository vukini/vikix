"""Explicit PipeWire capture. Raw PCM remains usable without a final header."""
import datetime
import json
import os
from pathlib import Path
import re
import select
import shutil
import sys
import subprocess
import threading
import time
import uuid

from launcher import end

FORMAT = ['--raw', '--rate', '48000', '--channels', '2', '--format', 's16']


def owned(command, **kwargs):
    # A separate guard watches the session process, not the short-lived HTTP
    # thread that launched it. It also reaps audio after an abrupt session exit.
    return subprocess.Popen([sys.executable, __file__, '--owned', str(os.getpid()), *command], **kwargs)


def graph():
    return json.loads(subprocess.run(['pw-dump'], check=True, capture_output=True,
                                     text=True, timeout=2).stdout)


def ports(items, node, direction):
    found = [x for x in items if x.get('type', '').endswith(':Port')
             and str(x.get('info', {}).get('props', {}).get('node.id')) == str(node)
             and x['info']['props'].get('port.direction') == direction]
    return [str(x['id']) for x in sorted(found, key=lambda x: int(x['info']['props'].get('port.id', x['id'])))]


def sources(items, source, engine, device):
    nodes = [(x['id'], x.get('info', {}).get('props', {})) for x in items
             if x.get('type', '').endswith(':Node')]
    result = []
    if source in ('engine', 'mixed'):
        found = [n for n, p in nodes if p.get('node.name') == engine]
        if len(found) != 1:
            raise ValueError('Music engine unavailable; play a pattern before recording')
        result.append(ports(items, found[0], 'out'))
    if source in ('microphone', 'mixed'):
        found = [n for n, p in nodes if p.get('media.class') == 'Audio/Source'
                 and (not device or p.get('node.name') == device)]
        if len(found) != 1:
            raise ValueError('microphone unavailable or ambiguous; choose its PipeWire node name with --device')
        result.append(ports(items, found[0], 'out'))
    if any(len(p) not in (1, 2) for p in result):
        raise ValueError('capture requires mono or stereo source ports')
    return result


def reserve(parent):
    parent.mkdir(parents=True, exist_ok=True)
    for number in range(1, 1000000):
        path = parent / f'take-{number:04d}'
        try:
            path.mkdir(mode=0o700)
            return path
        except FileExistsError:
            continue
    raise ValueError('take numbers exhausted')


class Captures:
    def __init__(self, song):
        self.song = song
        self.inbox = Path.home() / 'music/inbox'
        self.child = self.thread = None
        self.preview = self.preview_thread = None
        self.preview_stop = threading.Event()
        self.stop_event = threading.Event()
        self.active = None
        self.error = ''

    def state(self):
        return dict(active=bool(self.thread and self.thread.is_alive()),
                    take=self.active, error=self.error,
                    preview=bool(self.preview_thread and self.preview_thread.is_alive()))

    def start(self, source, engine, device=''):
        if source not in ('engine', 'microphone', 'mixed'):
            raise ValueError('source must be engine, microphone or mixed')
        if self.thread and self.thread.is_alive():
            raise ValueError('already recording; stop the current take first')
        self.stop_preview()
        routes = sources(graph(), source, engine, device)
        song = self.song.parent.name
        if not re.fullmatch(r'[\w-]+', song) or song == 'inbox':
            raise ValueError('song folder must contain only letters, digits, underscores or dashes')
        parent = self.inbox / song / datetime.date.today().isoformat()
        if parent.resolve() != parent:
            raise ValueError('symlink inbox refused')
        folder = reserve(parent)
        info = dict(source=source, device=device, format='s16le', rate=48000, channels=2,
                    status='interrupted', started=datetime.datetime.now().isoformat())
        with (folder / 'take.json').open('x') as out:
            json.dump(info, out)
            out.flush()
            os.fsync(out.fileno())
        self.error = ''
        self.active = dict(id=str(folder.relative_to(self.inbox)), source=source)
        self.stop_event.clear()
        name = 'vikix-record-' + uuid.uuid4().hex
        output = (folder / 'audio.pcm').open('xb', buffering=0)
        try:
            self.child = owned(['pw-record', *FORMAT, '--target', '0',
                '--properties', f'node.name={name} node.autoconnect=false adapter.auto-port-config={{ mode=dsp position=preserve }}', '-'],
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            self.thread = threading.Thread(target=self.write, args=(output, folder, routes), daemon=True)
            self.thread.start()
            deadline = time.monotonic() + 3
            inputs = []
            while time.monotonic() < deadline and self.thread.is_alive():
                items = graph()
                nodes = [x['id'] for x in items if x.get('type', '').endswith(':Node')
                         and x.get('info', {}).get('props', {}).get('node.name') == name]
                if nodes:
                    inputs = ports(items, nodes[0], 'in')
                    if len(inputs) == 2:
                        break
                time.sleep(.05)
            if len(inputs) != 2:
                raise ValueError('recorder did not expose stereo inputs')
            for route in routes:
                for index, target in enumerate(inputs):
                    subprocess.run(['pw-link', route[min(index, len(route)-1)], target],
                                   check=True, timeout=2, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if not self.thread.is_alive():
                raise ValueError(self.error or 'recorder exited before capture started')
        except BaseException:
            self.error = self.error or 'recording start interrupted or failed; partial audio preserved'
            self.stop()
            output.close()
            raise

    def write(self, output, folder, routes):
        next_check = time.monotonic() + 1
        try:
            with output:
                while True:
                    if self.stop_event.is_set():
                        end(self.child)
                    if time.monotonic() >= next_check and not self.stop_event.is_set():
                        available = {str(x['id']) for x in graph()}
                        if any(port not in available for route in routes for port in route):
                            raise OSError('recording source disappeared')
                        next_check = time.monotonic() + 1
                    if not select.select([self.child.stdout], [], [], .1)[0]:
                        continue
                    chunk = os.read(self.child.stdout.fileno(), 16384)
                    if not chunk:
                        break
                    view = memoryview(chunk)
                    while view:
                        count = output.write(view)
                        if not count:
                            raise OSError('audio write made no progress')
                        view = view[count:]
                    os.fsync(output.fileno())
            if not self.stop_event.is_set():
                self.error = 'recorder exited; partial audio preserved'
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            self.error = f'{exc}; partial audio preserved at {folder}'
        finally:
            end(self.child)
            self.child.stdout.close()
            try:
                with (folder / 'stopped.json').open('x') as out:
                    json.dump(dict(status='partial' if self.error else 'stopped', error=self.error), out)
                    out.flush()
                    os.fsync(out.fileno())
            except OSError:
                pass  # take.json already identifies this as interrupted.

    def stop(self):
        self.stop_event.set()
        if self.child and self.child.poll() is None:
            self.child.terminate()
        if self.thread:
            self.thread.join(timeout=8)
            if self.thread.is_alive():
                self.child.kill()
                self.thread.join(timeout=3)
            if self.thread.is_alive():
                raise RuntimeError('recorder cleanup still pending')
        end(self.child)
        self.child = self.thread = None

    def take(self, name):
        if not isinstance(name, str) or not re.fullmatch(r'[\w-]+/\d{4}-\d{2}-\d{2}/take-\d{4,6}', name):
            raise ValueError('invalid capture id')
        path = self.inbox / name
        if path.resolve() != path or not path.is_dir():
            raise ValueError('capture not found or symlink refused')
        if self.state()['active'] and name == self.active['id']:
            raise ValueError('stop recording before using this take')
        return path

    def listing(self):
        result = []
        for path in sorted(self.inbox.glob('*/*/take-*/audio.pcm')):
            if path.is_symlink() or path.parent.resolve() != path.parent:
                continue
            try:
                def metadata(name):
                    item = path.parent / name
                    if item.is_symlink() or item.stat().st_size > 8192:
                        raise ValueError('invalid capture metadata')
                    data = json.loads(item.read_text())
                    if not isinstance(data, dict):
                        raise ValueError('invalid capture metadata')
                    return data
                info = metadata('take.json')
                try:
                    status = metadata('stopped.json').get('status', 'interrupted')
                except FileNotFoundError:
                    status = 'interrupted'
            except (OSError, ValueError):
                info, status = {}, 'interrupted'
            if self.state()['active'] and self.active['id'] == str(path.parent.relative_to(self.inbox)):
                status = 'recording'
            result.append(dict(source=info.get('source', 'unknown'), status=status, id=str(path.parent.relative_to(self.inbox)), bytes=path.stat().st_size,
                               seconds=round(path.stat().st_size / 192000, 2)))
        return result

    def stop_preview(self):
        self.preview_stop.set()
        if self.preview_thread:
            self.preview_thread.join(timeout=8)
            if self.preview_thread.is_alive():
                raise RuntimeError('preview cleanup still pending')
        self.preview_thread = None

    def listen(self, name, loop=False):
        path = self.take(name) / 'audio.pcm'
        if path.is_symlink() or path.stat().st_size < 4:
            raise ValueError('capture has no complete audio frames')
        self.stop_preview()
        self.preview_stop.clear()
        def run():
            try:
                while not self.preview_stop.is_set():
                    self.preview = owned(['pw-play', *FORMAT, str(path)],
                        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    while self.preview.poll() is None and not self.preview_stop.wait(.05):
                        pass
                    end(self.preview)
                    if self.preview.returncode and not self.preview_stop.is_set():
                        self.error = 'capture preview failed; original audio preserved'
                        break
                    if not loop:
                        break
            except OSError as exc:
                self.error = str(exc)
            finally:
                end(self.preview)
        self.preview_thread = threading.Thread(target=run, daemon=True)
        self.preview_thread.start()

    def file(self, name, song):
        source = self.take(name)
        if not isinstance(song, str) or not re.fullmatch(r'[\w-]+', song) or song == 'inbox':
            raise ValueError('invalid destination song name')
        parent = Path.home() / 'music' / song / 'captures' / source.parent.name
        if parent.resolve() != parent:
            raise ValueError('symlink destination refused')
        target = reserve(parent)
        for item in source.iterdir():
            if item.is_symlink() or not item.is_file():
                raise ValueError('unexpected capture entry; originals preserved')
            with item.open('rb') as src, (target / item.name).open('xb') as dst:
                shutil.copyfileobj(src, dst)
                dst.flush()
                os.fsync(dst.fileno())
        with (target / 'filed.json').open('x') as out:
            json.dump(dict(source=name, complete=True), out)
            out.flush()
            os.fsync(out.fileno())
        return str(target)


if __name__ == '__main__':
    import signal
    if len(sys.argv) < 5 or sys.argv[1] != '--owned':
        raise SystemExit(2)
    parent = int(sys.argv[2])
    parent_fd = os.pidfd_open(parent)
    stopping = False
    def stop_guard(signum, frame):
        global stopping
        stopping = True
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, stop_guard)
    child = None
    try:
        if os.getppid() != parent or select.select([parent_fd], [], [], 0)[0]:
            raise SystemExit(1)
        child = subprocess.Popen(sys.argv[3:])
        while child.poll() is None and not stopping:
            if select.select([parent_fd], [], [], .05)[0]:
                break
    finally:
        if child and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=1)
            except subprocess.TimeoutExpired:
                child.kill()
        if child:
            child.wait(timeout=1)
        os.close(parent_fd)
    raise SystemExit(child.returncode if child else 1)
