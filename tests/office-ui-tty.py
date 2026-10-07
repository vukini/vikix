"""The Office in a terminal, end to end: the real launcher (bin/vikix-agents
office, no DISPLAY) on a pty against the test daemon tests/office-ui.sh
started (EMACS_SOCKET_NAME), the Office drawn on that terminal, q ending
the client and its frame, the buffers gone. Never a display."""
import fcntl
import os
import pty
import struct
import select
import subprocess
import sys
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT = ['emacsclient', '--alternate-editor=false', '--eval']


def ask(form):
    r = subprocess.run(CLIENT + [form], capture_output=True, text=True, timeout=10)
    if r.returncode:
        raise SystemExit(f'daemon did not answer {form}: {r.stderr.strip()}')
    return r.stdout.strip()


def read_until(fd, wanted, deadline):
    out = b''
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.2)
        if ready:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
            if all(w in out for w in wanted):
                return out, True
    return out, False


def main():
    env = dict(os.environ, TERM='xterm')
    env.pop('DISPLAY', None)
    frames = int(ask('(length (frame-list))'))
    pid, fd = pty.fork()
    if pid == 0:
        # A fresh pty is 0 by 0: give the terminal a size, as a real one has.
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
        os.execvpe(sys.executable, [sys.executable, os.path.join(ROOT, 'bin', 'vikix-agents'), 'office'], env)
    # The Office's header and the desk pane, drawn on this terminal.
    out, seen = read_until(fd, [b'The Office', b'Office desk'], time.time() + 25)
    if not seen:
        os.kill(pid, 15)
        raise SystemExit('the Office did not appear on the terminal:\n' + out[-1500:].decode('utf-8', 'replace'))
    if int(ask('(length (frame-list))')) != frames + 1:
        raise SystemExit('the Office did not make a tty frame of its own')
    if ask('(frame-parameter (selected-frame) (quote window-system))') != 'nil':
        raise SystemExit('the Office frame is not a terminal frame')
    if ask('(buffer-name (window-buffer (frame-selected-window (selected-frame))))') != '"*The Office*"':
        raise SystemExit('the Office is not what the terminal frame shows')
    os.write(fd, b'q')
    deadline = time.time() + 10
    status = None
    while time.time() < deadline:
        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            break
        read_until(fd, [b'\0'], time.time() + 0.2)   # drain, so the client is never blocked on the pty
    else:
        os.kill(pid, 15)
        raise SystemExit('q did not give the shell back: the launcher is still running')
    if os.waitstatus_to_exitcode(status) != 0:
        raise SystemExit(f'the launcher ended with {os.waitstatus_to_exitcode(status)} after q')
    if int(ask('(length (frame-list))')) != frames:
        raise SystemExit('q left the terminal frame in Emacs')
    if ask('(list (get-buffer "*The Office*") (get-buffer "*Office desk*"))') != '(nil nil)':
        raise SystemExit('q left the Office buffers')
    if ask('(cl-some (lambda (tm) (string-match-p "vikix-office" (format "%S" tm))) timer-list)') != 'nil':
        raise SystemExit('q left the refresh timer running')
    print('Office in a terminal: drawn on the pty in a tty frame, q ended the client, frame, buffers and timer')


main()
