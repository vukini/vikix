"""Real Lisp and public dispatcher, with an authenticated TCP SC stand-in."""
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time


def engine(args):
    assert "-u" not in args
    assert args[args.index("-B") + 1] == "127.0.0.1"
    assert args[args.index("-i") + 1] == "0"
    t = Path(os.environ["MUSIC_TEST"])
    (t / "engine.pid").write_text(str(os.getpid()))
    with (t / "engine.pids").open("a") as record:
        record.write(str(os.getpid()) + "\n")
    if (t / "fail-engine").exists():
        return 2
    password = args[args.index("-p") + 1].encode() + b"\0"
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", int(args[args.index("-t") + 1])))
        listener.listen(1)
        listener.settimeout(10)
        conn, _ = listener.accept()
        with conn:
            conn.settimeout(10)
            def exact(n):
                data = b""
                while len(data) < n:
                    part = conn.recv(n-len(data))
                    if not part:
                        raise EOFError
                    data += part
                return data
            def packet():
                return exact(struct.unpack(">I", exact(4))[0])
            assert packet() == password
            try:
                while True:
                    data = packet()
                    if data.startswith(b"/sync\0"):
                        reply = b"/synced\0,i\0\0" + struct.pack(">i", 123)
                        conn.sendall(struct.pack(">I", len(reply)) + reply)
                    elif data.startswith(b"#bundle\0"):
                        stamp = struct.unpack(">Q", data[8:16])[0] / 2**32 - 2208988800
                        sound = next((name for name in ('tone', 'kick', 'snare', 'closed-hat', 'bass', 'bell')
                                      if ('vikix-' + name).encode() + b'\0' in data), None)
                        assert sound
                        with (t / "events").open("a") as out:
                            offset = data.index(b"freq\0") + 8
                            freq = struct.unpack(">f", data[offset:offset + 4])[0]
                            amp_offset = data.index(b"amp\0") + 4
                            amp = struct.unpack(">f", data[amp_offset:amp_offset + 4])[0]
                            out.write(json.dumps({"at": stamp, "freq": freq, "gain": amp, "sound": sound}) + "\n")
                    elif data.startswith(b"/quit\0"):
                        break
            except EOFError:
                pass
    return 0


if sys.argv[1] == "--engine":
    sys.exit(engine(sys.argv[2:]))
root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="vikix-music-test-") as temp:
    t = Path(temp)
    home = t / "home"
    home.mkdir()
    env = dict(os.environ, HOME=str(home), MUSIC_TEST=str(t),
               DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", PYTHONDONTWRITEBYTECODE="1")
    for key in ("VIKIX_DIR", "VIKIX_STATE", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME"):
        env.pop(key, None)
    commands = t / "bin"
    commands.mkdir()
    real_sbcl = shutil.which("sbcl")
    (commands / "sbcl").write_text('#!/bin/sh\necho $$ >> "$MUSIC_TEST/lisp.pids"\nexec ' + shlex.quote(real_sbcl) + ' "$@"\n')
    (commands / "pw-jack").write_text('#!/bin/sh\nexec "$@"\n')
    (commands / "scsynth").write_text('#!/bin/sh\nexec python3 ' + shlex.quote(__file__) + ' --engine "$@"\n')
    (commands / "notify-send").write_text('#!/bin/sh\nexit 0\n')
    for f in commands.iterdir():
        f.chmod(0o755)
    env["PATH"] = str(commands) + os.pathsep + env["PATH"]
    def run(*args, ok=True, **kwargs):
        child = subprocess.Popen([str(root / "bin/vikix"), *args], env=env,
                                 text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, start_new_session=True)
        try:
            out, err = child.communicate(input=kwargs.get("input"), timeout=20)
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=5)
        result = subprocess.CompletedProcess(args, child.returncode, out, err)
        assert (result.returncode == 0) == ok, (args, result.returncode, out, err)
        return result
    def gone():
        pid = int((t / "engine.pid").read_text())
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        raise AssertionError(f"engine {pid} survived launcher")
    pattern = home / "music/first-song/patterns.lisp"
    pattern.parent.mkdir(parents=True)
    original = "(tempo 200)\n(defpattern test '(a4 - c5 -))\n"
    pattern.write_text(original)
    run("music", "check", str(pattern))
    for text in ('#.(error "evaluated")', "(load foo)", "(tempo 0)",
                 "(defpattern bad '(c4 . c5))", "(defpattern bad '(z9))", "(" * 30,
                 "(defpattern bad '(c4)) (defpattern bad '(c5))",
                 "(defpattern bad '(c4)) :end (load bad)"):
        pattern.write_text(text)
        run("music", "check", str(pattern), ok=False)
    for bank in ('(bank 1)', '(bank 0 test)', '(bank 33 test)', '(bank 1.5 test)',
                 '(bank 1 test 1 test)', '(bank 1 missing)', '(bank 1 :test)',
                 '(bank 1 (test))', '(bank 1 test) (bank)', '(bank . test)'):
        pattern.write_text(original + bank)
        run("music", "check", str(pattern), ok=False)
    for bank in ('(bank)', '(bank 1 test 32 TEST)', '(bank 2 test)'):
        pattern.write_text(bank + '\n' + original)
        run("music", "check", str(pattern))
    for options in (":sound 'unknown", ":sound kick", ":sound '(kick)",
                    ":sound '#.(quit)", ":gain -0.1", ":gain 1.01", ":gain nil",
                    ":gain 1e999", ":gain 0.5 :gain 1", ":swing -0.1", ":swing .51",
                    ":swing nan", ":sound 'kick", ":unknown 1", ":gain"):
        pattern.write_text("(defpattern test '(c4 -) " + options + ")")
        run("music", "check", str(pattern), ok=False)
    pattern.write_text("(defpattern test '(x - x) :swing 0.2)")
    run("music", "check", str(pattern), ok=False)
    for score in ("(defprogression verse '(I vi IV V) :key 'f)",
                  "(defprogression verse '((i 2) (- 3) VII) :key 'bb :sound 'bell :gain .5)",
                  "(BANK 32 VERSE) (DEFPROGRESSION verse '(I ii))"):
        pattern.write_text(score)
        run('music', 'check', str(pattern))
    for body in ("'(I) :key 'h", "'(I) :key f", "'(Iv)", "'((I 0))", "'((I 17))",
                 "'((I 1.5))", "'((I 2 3))", "'(VIII)", "'(:I)", "'(I . V)", "'()",
                 "'(I) :swing 0", "'(I) :sound 'kick", "'(I) :key 'c :key 'd",
                 "'(" + ' '.join(['I'] * 33) + ")", "'(" + ' '.join(['(I 16)'] * 9) + ")"):
        pattern.write_text('(defprogression verse ' + body + ')')
        run('music', 'check', str(pattern), ok=False)
    pattern.write_text(original)
    run("music", "doctor", ok=False)
    data = home / ".local/share/vikix/music"
    data.mkdir(parents=True)
    (data / "palette-v1.scsyndef").write_bytes(b"SCgf fixture")
    run("music", "doctor")
    run("music", "tone")
    gone()
    assert len((t / "events").read_text().splitlines()) == 1
    assert json.loads((t / "events").read_text())["freq"] == 880
    (t / "events").unlink()
    run("music", "play", str(pattern), "--bars", "2")
    gone()
    events = [json.loads(line) for line in (t / "events").read_text().splitlines()]
    assert len(events) == 4
    assert all(abs(row["gain"] - .08) < 1e-6 for row in events)
    assert abs(events[2]["at"] - events[0]["at"] - 1.2) < 0.001
    # All palette choices pass through the public dispatcher and authenticated engine.
    for sound in ('sine', 'kick', 'snare', 'closed-hat', 'bass', 'bell'):
        pattern.write_text(f"(tempo 200) (defpattern test '(x x x x) :sound '{sound} :gain 0.5 :swing 0.5)")
        (t / "events").unlink()
        run("music", "play", str(pattern), "--bars", "2")
        gone()
        rows = [json.loads(line) for line in (t / "events").read_text().splitlines()]
        assert len(rows) == 8
        assert all(row['sound'] == ('tone' if sound == 'sine' else sound) and
                   abs(row['gain'] - .04) < 1e-6 and row['freq'] == 220 for row in rows)
        for index, row in enumerate(rows):
            expected = (index // 4) * 1.2 + ((index % 4) + (0.5 if index % 2 else 0)) * .3
            assert abs(row['at'] - rows[0]['at'] - expected) < .001
    # Real public launcher: major/minor triads, two-bar block, silence and loop.
    pattern.write_text("(tempo 200) (defprogression verse '((I 2) - vi) :key 'f :sound 'bell :gain .6)")
    (t / 'events').unlink()
    run('music', 'play', str(pattern), '--pattern', 'verse', '--bars', '5')
    gone()
    rows = [json.loads(line) for line in (t / 'events').read_text().splitlines()]
    assert len(rows) == 12, rows
    for group, (bar, pitches) in enumerate(((0, (53, 57, 60)), (1, (53, 57, 60)),
                                           (3, (62, 65, 69)), (4, (53, 57, 60)))):
        for voice, midi in enumerate(pitches):
            event = rows[group * 3 + voice]
            assert abs(event['freq'] - 440 * 2 ** ((midi - 69) / 12)) < .001
            assert abs(event['at'] - rows[0]['at'] - bar * 1.2) < .001
            assert abs(event['gain'] - .016) < 1e-6 and event['sound'] == 'bell'
    pattern.write_text("(tempo 200) (defprogression quiet '((- 2)))")
    (t / 'events').unlink()
    run('music', 'play', str(pattern), '--bars', '2')
    gone()
    assert not (t / 'events').exists(), 'silent progression emitted sound'
    pattern.write_text(original)
    run("music", "play", str(pattern), "--pattern", "missing", "--bars", "1", ok=False)
    gone()
    odd = home / "a song; still data.lisp"
    odd.write_text("(bank 32 low) (tempo 200) (defpattern low '(c0 -))")
    run("music", "play", str(odd), "--bars", "1")
    gone()
    run("music", "tone", "nan", ok=False)
    run("music", "play", "--bars", "0", ok=False)
    run("music", "repl", input="(tone 330)\n(stop)\n(quit)\n")
    gone()
    (t / "fail-engine").touch()
    run("music", "tone", ok=False)
    gone()
    (t / "fail-engine").unlink()
    for stop_signal in (signal.SIGINT, signal.SIGTERM):
        child = subprocess.Popen([str(root / "bin/vikix"), "music", "play", str(pattern)],
                                 env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True)
        try:
            time.sleep(1)
            child.send_signal(stop_signal)
            child.wait(timeout=10)
            assert child.returncode != 0
            gone()
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
    (pattern.parent / "capture.wav").write_bytes(b"private recording")
    (pattern.parent / "nested").mkdir()
    (pattern.parent / "nested/patterns.lisp").write_text("not a song")
    run("snapshot", "music before")
    git = ["git", "-C", str(home), "--git-dir=" + str(home / ".local/state/vikix/yours.git")]
    before = subprocess.check_output(git + ["rev-parse", "HEAD"], env=env, text=True).strip()
    files = subprocess.check_output(git + ["ls-files"], env=env, text=True).splitlines()
    assert "music/first-song/patterns.lisp" in files
    assert not any("capture" in f or "nested" in f for f in files), files
    pattern.write_text("(tempo 120) (defpattern test '(c4))\n")
    run("snapshot", "music after")
    # Undo reaches a running player through the same bar-boundary reload.
    (t / "events").unlink(missing_ok=True)
    child = subprocess.Popen([str(root / "bin/vikix"), "music", "play", str(pattern)],
                             env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
    def wait_note(hz):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if (t / "events").exists():
                rows = (t / "events").read_text().splitlines()
                if any(abs(json.loads(row)["freq"] - hz) < 0.1 for row in rows):
                    return
            time.sleep(0.05)
        raise AssertionError(f"player never scheduled {hz} Hz")
    try:
        wait_note(261.626)
        run("undo", before, "--yes")
        assert pattern.read_text() == original
        wait_note(440)
    finally:
        child.send_signal(signal.SIGINT)
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait(timeout=5)
        gone()
    # Stop during initial validation, before the sound engine exists.
    wrapper = commands / 'sbcl'
    normal_wrapper = wrapper.read_text()
    slow = t / 'slow-check.py'
    marker = t / 'checking.pid'
    slow.write_text('import os, pathlib, time\n' +
                    f'pathlib.Path({str(marker)!r}).write_text(str(os.getpid()))\n' +
                    'time.sleep(30)\n')
    wrapper.write_text('#!/bin/sh\nexec python3 ' + shlex.quote(str(slow)) + '\n')
    child = subprocess.Popen([str(root / 'bin/vikix'), 'music', 'play', str(pattern)],
                             env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
    try:
        deadline = time.monotonic() + 10
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(.05)
        assert marker.exists(), 'initial checker did not start'
        checker_pid = int(marker.read_text())
        child.terminate()
        child.wait(timeout=5)
        assert not Path('/proc', str(checker_pid)).exists(), 'initial checker survived Stop'
    finally:
        wrapper.write_text(normal_wrapper)
        # The process group belongs to this test, including a leaked checker
        # when this regression is exercised against the old launcher.
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        child.wait(timeout=5)
    test = t / "clock.lisp"
    test.write_text('(load ' + json.dumps(str(root / "lib/music/core.lisp")) + ')\n' +
      '(in-package :vikix-music)\n' +
      '(let ((at 0d0) (seen nil) (file ' + json.dumps(str(pattern)) + '))\n' +
      ' (setf *clock* (lambda () (incf at 0.5d0)))\n' +
      ' (setf *emit* (lambda (notes) (push notes seen)\n' +
      '   (with-open-file (out file :direction :output :if-exists :supersede)\n' +
      '     (write-line (if (= (length seen) 1) "(tempo 120) (defpattern test \'(c4))" "(load bad)") out))))\n' +
      ' (play-loop file nil 3)\n' +
      ' (assert (= 3 (length seen)))\n' +
      ' (assert (= 1 (length (first seen))))\n' +
      ' (assert (= (second (first (first seen))) (frequency \'c4)))\n' +
      ' (assert (= (second (first (second seen))) (frequency \'c4))))\n')
    result = subprocess.run(["sbcl", "--noinform", "--no-sysinit", "--no-userinit", "--script", str(test)],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr
    pattern.write_text("(tempo 120) (defpattern test '(x x) :sound 'kick :gain 0.5 :swing 0.5)")
    clock_source = f'''(load {json.dumps(str(root / "lib/music/core.lisp"))})
(in-package :vikix-music)
(let ((at 0d0) (seen nil) (bars nil) (file {json.dumps(str(pattern))}))
  (setf *clock* (lambda () (incf at 0.5d0)))
  (setf *bar* (lambda (start bpm steps swing)
               (push (list start bpm steps swing) bars)))
  (setf *emit*
    (lambda (notes)
      (push notes seen)
      (with-open-file (out file :direction :output :if-exists :supersede)
        (write-line (if (= (length seen) 1)
                        "(tempo 120) (defpattern test '(x x) :sound 'bell :gain 0.25 :swing 0)"
                        "(defpattern test '(c4) :sound 'kick)") out))))
  (play-loop file nil 3)
  (setf seen (reverse seen) bars (reverse bars))
  (assert (equal (mapcar (lambda (bar) (fifth (first bar))) seen) '(kick bell bell)))
  (assert (equal (mapcar (lambda (bar) (sixth (first bar))) seen) '(0.5 0.25 0.25)))
  (assert (equal (mapcar #'fourth bars) '(0.5 0 0)))
  (loop for notes in seen for spacing in '(1.5 1 1) do
    (assert (< (abs (- (- (first (second notes)) (first (first notes))) spacing)) 0.001))))
'''
    test.write_text(clock_source)
    result = subprocess.run(["sbcl", "--noinform", "--no-sysinit", "--no-userinit", "--script", str(test)],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stderr

    pattern.write_text("(tempo 120) (defprogression verse '(I - vi) :key 'c)")
    test.write_text(f"""(load {json.dumps(str(root / 'lib/music/core.lisp'))})
(in-package :vikix-music)
(let ((now 0d0) (seen nil) (positions nil) (file {json.dumps(str(pattern))}))
  (setf *clock* (lambda () (incf now 0.1d0)))
  (setf *bar* (lambda (start bpm steps swing)
               (declare (ignore swing)) (push (list start bpm steps) positions)))
  (setf *emit* (lambda (notes)
    (push notes seen)
    (with-open-file (out file :direction :output :if-exists :supersede)
      (write-line (if (= (length seen) 1)
        "(tempo 200) (defprogression verse '(I - vi) :key 'd)"
        "(defprogression verse '(VIII))") out))))
  (play-loop file "verse" 4)
  (setf seen (reverse seen) positions (reverse positions))
  (assert (equal (mapcar #'length seen) '(3 0 3 3)))
  (assert (equal (mapcar #'third positions) '(-1 -2 -3 -1)))
  (loop for events in seen for pitches in '((c3 e3 g3) nil (b3 d4 fs4) (d3 fs3 a3)) do
    (loop for event in events for pitch in pitches do
      (assert (< (abs (- (second event) (frequency pitch))) .001)))))
""")
    result = subprocess.run(['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--script', str(test)],
                            env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stderr

    # The bridge rejects malformed/unbounded events even if its child misbehaves.
    wrapper = commands / 'sbcl'
    normal_wrapper = wrapper.read_text()
    fake = t / 'bad-event.py'
    try:
        for event in ('0 440 .3 .08 unknown 1', '0 440 .3 .08 sine nan',
                      '0 440 .3 .11 sine 1', '0 440 .3 .08 sine 1.1',
                      'bar 0 120 3 .5', 'bar 0 120 4 nan',
                      'bar 0 120 -129 0', 'bar 0 120 -1 .2'):
            fake.write_text("import os\n" +
                            f"os.write(int(os.environ['VIKIX_MUSIC_FD']), {event.encode() + bytes([10])!r})\n")
            wrapper.write_text('#!/bin/sh\nexec python3 ' + shlex.quote(str(fake)) + '\n')
            (t / 'events').unlink(missing_ok=True)
            run('music', 'tone', ok=False)
            gone()
            assert not (t / 'events').exists()
    finally:
        wrapper.write_text(normal_wrapper)
    for pid in (t / "lisp.pids").read_text().splitlines():
        try:
            os.kill(int(pid), 0)
        except ProcessLookupError:
            continue
        raise AssertionError("Lisp child survived: " + pid)
    # Repeated setup prepares assets but does not overwrite a user's pattern.
    saved = pattern.read_text()
    (home / "quicklisp").mkdir()
    (home / "quicklisp/setup.lisp").touch()
    service = t / "services"
    (service / "rtkit").mkdir(parents=True)
    env["VIKIX_SERVICE_DIR"] = str(service)
    (commands / "sbcl").write_text("#!/usr/bin/env python3\nimport os\nfrom pathlib import Path\nPath(os.environ['VIKIX_MUSIC_SYNTH']).write_bytes(b'SCgf fixture')\n")
    (commands / "sbcl").chmod(0o755)
    # Exercise the real package stage with stand-ins, never the host package manager.
    (commands / "xbps-query").write_text("#!/bin/sh\ncase \"$1\" in -l|-R) exit 0;; *) exit 1;; esac\n")
    (commands / "sudo").write_text("#!/bin/sh\n[ \"$1\" = xbps-install ] || exit 91\nprintf '%s\\n' \"$*\" >> \"$MUSIC_TEST/packages\"\n")
    for name in ("xbps-query", "sudo"):
        (commands / name).chmod(0o755)
    run("music", "setup")
    installs = (t / "packages").read_text()
    assert "xbps-install -y supercollider libjack-pipewire rtkit" in installs
    run("music", "setup")
    assert pattern.read_text() == saved
    pattern.unlink()
    dry = dict(env, DRY_RUN="1")
    result = subprocess.run([str(root / "bin/vikix"), "music", "setup"], env=dry,
                            capture_output=True, timeout=10)
    assert result.returncode == 0 and not pattern.exists()
    run("music", "setup")
    assert "first-song" in pattern.read_text()
    run("music", "uninstall")
    assert pattern.exists() and not (data / "palette-v1.scsyndef").exists()
    print("music: parser, clock/reload, launcher/TCP, failures/cleanup and snapshot/undo passed")
