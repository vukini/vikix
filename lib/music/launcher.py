"""Own the engine and Lisp child; only timestamped notes cross their pipe."""
import argparse
import contextlib
import math
import os
from pathlib import Path
import secrets
import select
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time


def osc_string(value):
    data = value.encode() + b"\0"
    return data + b"\0" * (-len(data) % 4)


def message(address, *args):
    tags, data = ",", b""
    for value in args:
        if isinstance(value, str):
            tags += "s"
            data += osc_string(value)
        elif isinstance(value, bytes):
            tags += "b"
            data += struct.pack(">I", len(value)) + value + b"\0" * (-len(value) % 4)
        elif isinstance(value, int):
            tags += "i"
            data += struct.pack(">i", value)
        else:
            tags += "f"
            data += struct.pack(">f", value)
    return osc_string(address) + osc_string(tags) + data


def send(sock, data):
    sock.sendall(struct.pack(">I", len(data)) + data)


def receive(sock):
    def exact(n):
        data = b""
        while len(data) < n:
            part = sock.recv(n - len(data))
            if not part:
                raise RuntimeError("sound engine closed its connection")
            data += part
        return data
    size = struct.unpack(">I", exact(4))[0]
    if size > 65536:
        raise RuntimeError("invalid engine reply")
    return exact(size)


def sync(sock):
    send(sock, message("/sync", 123))
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        packet = receive(sock)
        if packet.startswith(osc_string("/fail")):
            raise RuntimeError("sound engine rejected a command")
        if packet == message("/synced", 123):
            return
    raise RuntimeError("sound engine did not acknowledge commands")


def end(child):
    if child is None:
        return
    if child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()
    child.wait(timeout=3)


def lisp(root, *args):
    return ["sbcl", "--noinform", "--no-sysinit", "--no-userinit", "--script",
            str(root / "lib/music/driver.lisp"), *map(str, args)]


def data_dir():
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "vikix/music"


def setup(root):
    if os.environ.get("DRY_RUN") == "1":
        print("would install music packages, enable rtkit, prepare cl-collider synth and copy first-song/patterns.lisp once")
        return 0
    if not (Path.home() / "quicklisp/setup.lisp").is_file():
        raise RuntimeError("Quicklisp is missing; complete Vikix's Lisp install first")
    subprocess.run(["bash", str(root / "lib/music/setup.sh")], check=True)
    folder = data_dir()
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="build-", dir=folder) as temp:
        output = Path(temp) / "palette-v1.scsyndef"
        env = dict(os.environ, VIKIX_MUSIC_SYNTH=str(output))
        subprocess.run(["sbcl", "--noinform", "--no-sysinit", "--no-userinit", "--non-interactive",
                        "--load", str(root / "lib/music/synth.lisp")], env=env, check=True, timeout=180)
        os.replace(output, folder / "palette-v1.scsyndef")
    starter = Path.home() / "music/first-song/patterns.lisp"
    starter.parent.mkdir(parents=True, exist_ok=True)
    try:
        with starter.open("x") as out:
            out.write((root / "config/music/patterns.lisp").read_text())
    except FileExistsError:
        pass
    print(f"Ready: {starter}. Try vikix music tone, then vikix music play.")
    return 0


def doctor():
    missing = []
    for name in ("sbcl", "scsynth", "pw-jack"):
        found = shutil.which(name)
        print(f"{name}: {found or 'missing (vikix add music)'}")
        if not found:
            missing.append(name)
    ready = (data_dir() / "palette-v1.scsyndef").is_file()
    print("synth: " + ("prepared" if ready else "missing (vikix music setup)"))
    print("Audio and realtime scheduling: verify with vikix music tone; not measured by this check.")
    return int(bool(missing) or not ready)


def perform(root, args, control=None, position=None):
    synth = data_dir() / "palette-v1.scsyndef"
    if doctor():
        return 1
    # Reserve a free loopback port. A competing bind causes a clean failure,
    # never attachment to that process: the random password must authenticate.
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    password = secrets.token_hex(12)
    engine = worker = None
    sock = None
    read_fd, write_fd = os.pipe()
    previous = {}
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        previous[sig] = signal.signal(sig, interrupted)
    try:
        # A view can stop immediately after Play. Own the initial checker too,
        # under the same signal handler and cleanup as the playing Lisp child.
        if args.command == "play":
            worker = subprocess.Popen(lisp(root, "check", args.file))
            code = worker.wait(timeout=10)
            if code:
                raise subprocess.CalledProcessError(code, worker.args)
            worker = None
        # No UDP listener, no microphone, no service advertisement, no saved synths.
        engine_env = dict(os.environ)
        engine_env.setdefault("SC_JACK_DEFAULT_OUTPUTS", "system")
        engine = subprocess.Popen(["pw-jack", "scsynth", "-t", str(port), "-B", "127.0.0.1",
                                   "-p", password, "-R", "0", "-D", "0", "-i", "0", "-o", "2"],
                                  stdin=subprocess.DEVNULL, stdout=sys.stderr, stderr=sys.stderr, env=engine_env)
        deadline = time.monotonic() + 15
        while sock is None:
            if engine.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("sound engine did not start; check PipeWire/JACK")
            try:
                sock = socket.create_connection(("127.0.0.1", port), timeout=0.2)
            except OSError:
                time.sleep(0.05)
        sock.settimeout(5)
        send(sock, password.encode() + b"\0")
        send(sock, message("/d_recv", synth.read_bytes()))
        sync(sock)
        env = dict(os.environ, VIKIX_MUSIC_FD=str(write_fd))
        if args.command == "tone":
            command = lisp(root, "tone", args.hz)
        elif args.command == "play":
            command = lisp(root, "play", args.file, args.pattern or "", args.bars or "")
        else:
            command = lisp(root, "repl", args.file)
        worker = subprocess.Popen(command, env=env, pass_fds=(write_fd,))
        os.close(write_fd)
        write_fd = None
        pending = b""
        view_gain = None
        while True:
            if control is not None:
                while control.poll():
                    view_gain = float(control.recv())
            if engine.poll() is not None:
                raise RuntimeError("sound engine exited")
            if select.select([read_fd], [], [], 0.1)[0]:
                chunk = os.read(read_fd, 8192)
                if not chunk:
                    break
                pending += chunk
                if len(pending) > 65536:
                    raise RuntimeError("invalid music event")
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    if line.startswith(b"bar "):
                        at, bpm, steps, swing = map(float, line.split()[1:])
                        if not (all(map(math.isfinite, (at, bpm, steps, swing))) and
                                0 <= swing <= 0.5 and (swing == 0 or steps % 2 == 0) and
                                60 <= bpm <= 200 and steps.is_integer() and 1 <= steps <= 128):
                            raise RuntimeError("invalid music bar")
                        if position is not None:
                            # Fixed-size shared memory: a closed or slow view
                            # cannot fill a telemetry pipe and block the clock.
                            with position.get_lock():
                                position[:4] = position[4:]
                                position[4:] = (at, 240 / bpm, steps, swing)
                        continue
                    if line == b"stop":
                        send(sock, message("/clearSched"))
                        send(sock, message("/g_freeAll", 0))
                        continue
                    fields = line.split()
                    if len(fields) != 6:
                        raise RuntimeError("invalid music note")
                    at, freq, dur, gain = map(float, fields[:4])
                    sound = fields[4].decode('ascii')
                    relative = float(fields[5])
                    sounds = {'sine': 'tone', 'kick': 'kick', 'snare': 'snare',
                              'closed-hat': 'closed-hat', 'bass': 'bass', 'bell': 'bell'}
                    if sound not in sounds or not math.isfinite(relative) or not 0 <= relative <= 1:
                        raise RuntimeError("invalid music sound or relative gain")
                    if not (all(map(math.isfinite, (at, freq, dur, gain))) and
                            16 <= freq <= 20000 and 0 < dur <= 5 and 0 <= gain <= 0.1):
                        raise RuntimeError("invalid music note")
                    if view_gain is not None:
                        if not math.isfinite(view_gain) or not 0 <= view_gain <= 0.1:
                            raise RuntimeError("invalid session gain")
                        gain = view_gain
                    gain *= relative
                    stamp = int((at + 2208988800) * 2**32)
                    note = message("/s_new", "vikix-" + sounds[sound], -1, 0, 0,
                                   "freq", freq, "dur", dur, "amp", gain)
                    send(sock, b"#bundle\0" + struct.pack(">Q", stamp) + struct.pack(">I", len(note)) + note)
            elif worker.poll() is not None:
                break
        return worker.wait(timeout=5)
    finally:
        # Ignore a second interrupt until both owned processes have been reaped.
        for sig in previous:
            signal.signal(sig, signal.SIG_IGN)
        try:
            end(worker)
            if sock is not None:
                with contextlib.suppress(OSError):
                    send(sock, message("/clearSched"))
                    send(sock, message("/quit"))
                sock.close()
            end(engine)
            os.close(read_fd)
            if write_fd is not None:
                os.close(write_fd)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


def main(root, argv):
    parser = argparse.ArgumentParser(prog="vikix music")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("setup", "doctor", "uninstall"):
        sub.add_parser(name)
    sub.add_parser("check").add_argument("file")
    tone = sub.add_parser("tone")
    tone.add_argument("hz", type=float, nargs="?", default=880)
    play = sub.add_parser("play")
    play.add_argument("file", nargs="?", default=str(Path.home() / "music/first-song/patterns.lisp"))
    play.add_argument("--pattern")
    play.add_argument("--bars", type=int)
    repl = sub.add_parser("repl")
    repl.set_defaults(file=str(Path.home() / "music/first-song/patterns.lisp"))
    serve = sub.add_parser("serve")
    serve.add_argument("file", nargs="?", default=str(Path.home() / "music/first-song/patterns.lisp"))
    for name in ("web", "cuis"):
        sub.add_parser(name)
    args = parser.parse_args(argv)
    try:
        if args.command in ("serve", "web", "cuis"):
            from session import main as session_main
            return session_main(root, args)
        if args.command == "setup":
            return setup(root)
        if args.command == "doctor":
            return doctor()
        if args.command == "uninstall":
            if os.environ.get("DRY_RUN") != "1":
                (data_dir() / "palette-v1.scsyndef").unlink(missing_ok=True)
                (data_dir() / "tone.scsyndef").unlink(missing_ok=True)
            print("Prepared synth removed; ~/music kept.")
            return 0
        if args.command == "check":
            return subprocess.run(lisp(root, "check", args.file), timeout=10).returncode
        if args.command == "tone" and not 20 <= args.hz <= 20000:
            raise RuntimeError("frequency must be 20 to 20000 Hz")
        if args.command == "play" and args.bars is not None and not 1 <= args.bars <= 100000:
            raise RuntimeError("bars must be 1 to 100000")
        return perform(root, args)
    except KeyboardInterrupt:
        return 130
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
        # Never include subprocess argv: the engine command contains its password.
        print("vikix music: " + ("child command failed or timed out" if isinstance(exc, subprocess.SubprocessError)
                                else str(exc)), file=sys.stderr)
        return 1
