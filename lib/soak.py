#!/usr/bin/env python3
"""lib/soak.py [MINUTES] — the desktop used hard for a while, on a hidden screen.

A hidden StumpWM (Xvfb) with this checkout's config, in a home of its own,
is worked as a busy person would: windows open and close, move between
workspaces, float and tile again, go fullscreen, frames split and join,
focus moves, the config reloads now and then. Every ten seconds it is
asked something over Swank, and the time it takes to answer, its memory
and its timers are written down. At the end, with every window closed
again, it's compared with how it began.

It fails when StumpWM:
  - stopped answering, or answered slowly (one over 3 s, or one in twenty
    over 1 s)
  - grew: the Lisp heap after a full collection more than it may (the
    limit grows with the minutes)
  - kept repeating timers or hooks it didn't have at the start (one added
    at each reload, say)
  - wrote an error (errors.lisp's ~/.local/state/vikix/errors/)

The samples go to ~/.local/state/vikix/soak/DATE.csv; the last line
printed says what was found. `vikix times soak` runs it; tests/soak.sh
for a minute. Needs Xvfb, xdotool and Vikix's StumpWM; alacritty or xterm
for the windows. Exits 2 when one is missing.
"""
import csv
import datetime
import os
import random
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
HOME = os.path.expanduser("~")
WM = os.environ.get("VIKIX_TEST_STUMPWM", os.path.join(HOME, ".local/bin/stumpwm"))
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "vikix", "soak")
MAX_WINDOWS = 10
SAMPLE_EVERY = 10          # seconds
RELOAD_EVERY = 300         # seconds
HEAP_MB_PER_HOUR = 40      # growth allowed, with every window closed again, after a full collection
HEAP_MB_FLOOR = 15         # whatever the length: the noise of a short run


def free_display():
    n = 600 + random.randrange(300)
    while os.path.exists(f"/tmp/.X{n}-lock") or os.path.exists(f"/tmp/.X11-unix/X{n}"):
        n += 1
    return n


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class Desktop:
    """A hidden StumpWM, and ways to ask it things and press its keys."""

    def __init__(self):
        self.tmp = tempfile.mkdtemp(prefix="vikix-soak-")
        self.home = os.path.join(self.tmp, "home")
        self.n, self.port = free_display(), free_port()
        self.env = dict(os.environ, DISPLAY=f":{self.n}", HOME=self.home, VIKIX_SWANK_PORT=str(self.port),
                        LIBGL_ALWAYS_SOFTWARE="1")
        self.procs, self.windows = [], []
        self.terminal = shutil.which("alacritty") or shutil.which("xterm")

    def start(self):
        d = os.path.join(self.home, ".stumpwm.d")
        os.makedirs(os.path.join(self.home, ".local/state/vikix"))
        os.makedirs(os.path.join(self.home, ".config/vikix"))
        shutil.copytree(os.path.join(HERE, "config/stumpwm/vikix"), os.path.join(d, "vikix"))
        shutil.copy(os.path.join(HERE, "config/stumpwm/init.lisp"), d)
        swank = os.path.join(d, "vikix/swank.lisp")
        with open(swank) as f:
            text = f.read()
        with open(swank, "w") as f:
            f.write(text.replace("(defparameter *vikix-swank-port* 4004)",
                                 f"(defparameter *vikix-swank-port* {self.port})"))
        if os.path.isdir(os.path.join(HOME, "quicklisp")):
            os.symlink(os.path.join(HOME, "quicklisp"), os.path.join(self.home, "quicklisp"))
        with open(os.path.join(self.home, ".slime-secret"), "w") as f:
            f.write("soak\n")
        os.chmod(os.path.join(self.home, ".slime-secret"), 0o600)
        open(os.path.join(self.home, ".local/state/vikix/welcome"), "w").close()
        self.procs.append(subprocess.Popen(["Xvfb", f":{self.n}", "-screen", "0", "1280x800x24", "-nolisten", "tcp"],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        for _ in range(50):
            if subprocess.run(["xdpyinfo"], env=self.env, capture_output=True).returncode == 0:
                break
            time.sleep(0.2)
        self.log = open(os.path.join(self.tmp, "wm.log"), "w")
        self.wm = subprocess.Popen([WM], env=self.env, stdout=self.log, stderr=self.log)
        self.procs.append(self.wm)
        for _ in range(120):
            if self.ask("(princ 1)")[0] == "1":
                return True
            time.sleep(0.5)
        return False

    def ask(self, form, timeout=20):
        """(answer, seconds); answer None when StumpWM didn't answer."""
        t0 = time.time()
        try:
            r = subprocess.run([sys.executable, os.path.join(HERE, "bin/vikix-eval"), form], env=self.env,
                               capture_output=True, text=True, timeout=timeout)
            out = "\n".join(line for line in r.stdout.splitlines() if not line.startswith("=> "))
            ok = r.returncode == 0
        except subprocess.TimeoutExpired:
            ok, out = False, ""
        return (out.strip() if ok else None), time.time() - t0

    def key(self, k):
        subprocess.run(["xdotool", "key", k], env=self.env, capture_output=True)

    def command(self, c):
        self.ask(f'(run-commands "{c}")')

    def open_window(self):
        if not self.terminal:
            return
        p = subprocess.Popen([self.terminal, "-e", "sleep", "3600"], env=self.env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.windows.append(p)

    def close_window(self):
        alive = [p for p in self.windows if p.poll() is None]
        if alive:
            p = random.choice(alive)
            p.terminate()
            self.windows.remove(p)

    def close_all(self):
        for p in self.windows:
            if p.poll() is None:
                p.terminate()
        self.windows = []

    def rss_mb(self):
        try:
            with open(f"/proc/{self.wm.pid}/status") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        return int(line.split()[1]) / 1024
        except OSError:
            pass
        return None

    def stop(self):
        for p in self.windows + self.procs:
            if p.poll() is None:
                p.terminate()
        for p in self.windows + self.procs:
            try:
                p.wait(5)
            except subprocess.TimeoutExpired:
                p.kill()
        shutil.rmtree(self.tmp, ignore_errors=True)


COUNTS = ("(progn (sb-ext:gc :full t) (setf *print-pretty* nil)"
          " (format t \"~d ~d ~d ~d ~d\""
          "  (floor (sb-kernel:dynamic-usage) 1048576)"
          # Timers that repeat: the kind a reload can pile up. A message's own
          # timeout, a one-shot, was counted as a leak when one happened to be
          # showing at the end.
          "  (count-if (function timer-repeat) *timer-list*)"
          "  (+ (length *new-window-hook*) (length *destroy-window-hook*) (length *focus-window-hook*)"
          "     (length *focus-group-hook*) (length *key-press-hook*) (length *start-hook*))"
          "  (length (all-windows))"
          "  (length (group-frames (current-group)))))")


def counts(desk):
    out, _ = desk.ask(COUNTS, timeout=60)
    try:
        heap, timers, hooks, wins, frames = (int(x) for x in out.split())
        return {"heap": heap, "timers": timers, "hooks": hooks, "windows": wins, "frames": frames}
    except (AttributeError, ValueError):
        return None


def act(desk, frames):
    """One thing a busy person does."""
    alive = len([p for p in desk.windows if p.poll() is None])
    choices = [("open", 4 if alive < MAX_WINDOWS else 0), ("close", 2 if alive > 2 else 0),
               ("workspace", 3), ("move", 2), ("split", 2 if frames < 5 else 0), ("join", 2 if frames > 1 else 0),
               ("float", 1), ("fullscreen", 1), ("focus", 3)]
    what = random.choices([c for c, _ in choices], [w for _, w in choices])[0]
    if what == "open":
        desk.open_window()
    elif what == "close":
        desk.close_window()
    elif what == "workspace":
        desk.key(f"super+{random.randint(1, 4)}")
    elif what == "move":
        desk.key(f"super+shift+{random.randint(1, 4)}")
    elif what == "split":
        desk.key(random.choice(["super+b", "super+v"]))
    elif what == "join":
        desk.command("remove")
    elif what == "float":
        desk.key("super+t")
    elif what == "fullscreen":
        desk.key("super+f")
    elif what == "focus":
        desk.key("super+" + random.choice("hjkl"))
    return what


def main(argv):
    minutes = float(argv[0]) if argv else 60.0
    for need in ("Xvfb", "xdotool", "xdpyinfo"):
        if not shutil.which(need):
            print(f"soak: needs {need} and an X server", file=sys.stderr)
            return 2
    if not os.access(WM, os.X_OK):
        print(f"soak: needs Vikix's StumpWM ({WM})", file=sys.stderr)
        return 2
    desk = Desktop()
    signal.signal(signal.SIGTERM, lambda *_: (desk.stop(), sys.exit(1)))
    os.makedirs(STATE, exist_ok=True)
    path = os.path.join(STATE, datetime.datetime.now().strftime("%Y-%m-%d-%H%M") + ".csv")
    try:
        if not desk.start():
            print("soak: the hidden StumpWM didn't start", file=sys.stderr)
            return 1
        start = counts(desk)
        errors_dir = os.path.join(desk.home, ".local/state/vikix/errors")
        t0 = time.time()
        end = t0 + minutes * 60
        # A short run reloads a few times too.
        reload_every = min(RELOAD_EVERY, max(20, minutes * 60 / 4))
        next_sample, next_reload = t0, t0 + reload_every
        answers, actions, frames = [], 0, 1
        with open(path, "w", newline="") as f:
            out = csv.writer(f)
            out.writerow(["seconds", "answer", "rss_mb", "windows", "frames", "timers", "actions"])
            while time.time() < end:
                now = time.time()
                if now >= next_sample:
                    a, secs = desk.ask("(progn (setf *print-pretty* nil) (format t \"~d ~d ~d\" "
                                       "(length (all-windows)) (length (group-frames (current-group))) "
                                       "(length *timer-list*)))")
                    answers.append(secs if a is not None else float("inf"))
                    w, frames, timers = (a.split() + ["", "", ""])[:3] if a else ("", 1, "")
                    frames = int(frames) if str(frames).isdigit() else 1
                    out.writerow([round(now - t0), round(secs, 3) if a is not None else "none",
                                  round(desk.rss_mb() or 0, 1), w, frames, timers, actions])
                    f.flush()
                    if a is None and secs >= 20:
                        break                     # kept busy: nothing more to learn
                    next_sample += SAMPLE_EVERY
                if now >= next_reload:
                    desk.command("vikix-reload")
                    next_reload += reload_every
                act(desk, frames)
                actions += 1
                time.sleep(random.uniform(0.3, 1.2))
        desk.close_all()
        time.sleep(3)
        desk.command("only")
        end_counts = counts(desk)
        errors = len(os.listdir(errors_dir)) if os.path.isdir(errors_dir) else 0
    finally:
        desk.stop()

    problems = []
    if not answers or float("inf") in answers:
        problems.append("StumpWM stopped answering")
    else:
        worst, p95 = max(answers), sorted(answers)[int(len(answers) * 0.95) - 1] if len(answers) >= 20 else max(answers)
        if worst > 3:
            problems.append(f"an answer took {worst:.1f} s")
        if p95 > 1:
            problems.append(f"one answer in twenty took over {p95:.1f} s")
    if start and end_counts:
        allowed = max(HEAP_MB_FLOOR, HEAP_MB_PER_HOUR * minutes / 60)
        grew = end_counts["heap"] - start["heap"]
        if grew > allowed:
            problems.append(f"the Lisp heap grew {grew} MB (allowed {allowed:.0f})")
        if end_counts["timers"] > start["timers"]:
            problems.append(f"timers {start['timers']} → {end_counts['timers']}")
        if end_counts["hooks"] > start["hooks"]:
            problems.append(f"hooks {start['hooks']} → {end_counts['hooks']}")
    elif not problems:
        problems.append("couldn't count its heap, timers and hooks at the end")
    if errors:
        problems.append(f"{errors} error(s) written")
    summary = (f"{minutes:g} min, {actions} actions, {len(answers)} answers"
               + (f" (median {statistics.median(answers) * 1000:.0f} ms, worst {max(answers) * 1000:.0f} ms)"
                  if answers and float('inf') not in answers else "")
               + (f", heap {start['heap']} → {end_counts['heap']} MB, timers {start['timers']} → "
                  f"{end_counts['timers']}, hooks {start['hooks']} → {end_counts['hooks']}"
                  if start and end_counts else ""))
    print(f"samples: {path}")
    if problems:
        print(f"soak FAILED: {'; '.join(problems)} ({summary})")
        return 1
    print(f"soak passed: {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
