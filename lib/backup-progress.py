#!/usr/bin/env python3
"""backup-progress: restic's progress, as a bar (bin/vikix-backup).

vikix backup runs restic with --json (a status line a second, with
RESTIC_PROGRESS_FPS=1) and pipes everything it says here. What comes out:

  the terminal   a bar on stderr while stderr is one (or with --bar):
                 percent, done of total, files, time left; one line,
                 redrawn in place
  --notify       one notification kept up to date (notify-send -r, with
                 the int:value hint dunst draws as a bar), at most every
                 five seconds; "Backup done" with the summary replaces it
  --progress F   "PERCENT AT" (AT Unix time) for the bar's field, written a
                 second at a time and removed at the end, so a backup that
                 died leaves a file that goes stale, not a frozen number
  --log F        a readable log: a line a minute of progress, every error,
                 and the summary in words; never restic's JSON
  stdout         the summary in words, and the errors as they come

The exit status is restic's (the pipeline's pipefail): this exits 0 once
stdin ends, and never holds restic up.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

NOTIFY_EVERY = 5      # seconds between two notifications
LOG_EVERY = 60        # seconds between two lines of progress in the log


def human(n):
    """Bytes in words: 1.2 GB."""
    n = float(n or 0)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1000 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1000
    return f"{n:.1f} TB"


def took(secs):
    secs = int(secs or 0)
    if secs < 60:
        return f"{secs} s"
    if secs < 3600:
        return f"{(secs + 30) // 60} min"
    return f"{secs // 3600} h {(secs % 3600 + 30) // 60} min"


def left(secs):
    if secs is None:
        return ""
    return f"{took(secs)} left"


def percent(st):
    return max(0, min(100, int(float(st.get("percent_done") or 0) * 100)))


def amounts(st):
    """\"1.2 GB of 29.1 GB, 1234/5000 files, 4 min left\"."""
    text = f"{human(st.get('bytes_done'))} of {human(st.get('total_bytes'))}"
    text += f", {st.get('files_done', 0)}/{st.get('total_files', 0)} files"
    eta = left(st.get("seconds_remaining"))
    if eta:
        text += f", {eta}"
    return text


def bar_text(st, width):
    cells = max(10, min(30, width - 60))
    filled = percent(st) * cells // 100
    text = f"  [{'#' * filled}{'.' * (cells - filled)}] {percent(st):3d}%  {amounts(st)}"
    return text[: max(20, width - 1)]


def summary_text(s):
    """The summary in words."""
    parts = [f"{s.get('files_new', 0)} files new", f"{s.get('files_changed', 0)} changed",
             f"{s.get('files_unmodified', 0)} unchanged", f"{human(s.get('data_added'))} added",
             f"took {took(s.get('total_duration'))}"]
    text = ", ".join(parts)
    snap = s.get("snapshot_id")
    if snap:
        text += f"; backup {str(snap)[:8]}"
    return text


class Notifier:
    """One notification, replaced in place: notify-send -p gives its id the
    first time, -r replaces it after."""

    def __init__(self):
        self.id = None
        self.last = 0.0

    def send(self, title, body, value=None, urgency="low"):
        cmd = ["notify-send", "-a", "Vikix", "-u", urgency]
        if value is not None:
            cmd += ["-h", f"int:value:{value}"]
        cmd += ["-r", str(self.id)] if self.id else ["-p"]
        cmd += [title, body]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return
        if self.id is None and out.isdigit():
            self.id = int(out)

    def progress(self, st, now):
        if now - self.last < NOTIFY_EVERY:
            return
        self.last = now
        self.send(f"Backup {percent(st)}%", amounts(st), value=percent(st))


class Progress:
    def __init__(self, args):
        self.args = args
        self.log = open(args.log, "a", encoding="utf-8") if args.log else None
        self.notifier = Notifier() if args.notify else None
        self.bar = args.bar or sys.stderr.isatty()
        self.bar_shown = False
        self.last_log = 0.0
        # A real terminal's width; 80 columns when the bar is only asked for.
        self.width = shutil.get_terminal_size((80, 24)).columns if sys.stderr.isatty() else 80

    def note(self, line):
        if self.log:
            self.log.write(time.strftime("%H:%M:%S ") + line + "\n")
            self.log.flush()

    def clear_bar(self):
        if self.bar_shown:
            sys.stderr.write("\r\x1b[K")
            sys.stderr.flush()
            self.bar_shown = False

    def status(self, st, now):
        if self.args.progress:
            tmp = self.args.progress + ".new"
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(f"{percent(st)} {int(now)}\n")
            os.replace(tmp, self.args.progress)
        if self.bar:
            sys.stderr.write("\r\x1b[K" + bar_text(st, self.width))
            sys.stderr.flush()
            self.bar_shown = True
        if self.notifier:
            self.notifier.progress(st, now)
        if now - self.last_log >= LOG_EVERY:
            self.last_log = now
            self.note(f"{percent(st):3d}%  {amounts(st)}")

    def error(self, msg):
        self.clear_bar()
        self.note("error: " + msg)
        print("error: " + msg, file=sys.stderr, flush=True)

    def summary(self, s):
        self.clear_bar()
        text = summary_text(s)
        self.note("done: " + text)
        print("backup done: " + text, flush=True)
        if self.notifier:
            self.notifier.send("Backup done", text, value=100)

    def line(self, raw, now):
        raw = raw.rstrip("\n")
        if not raw:
            return
        try:
            msg = json.loads(raw)
        except ValueError:
            # restic's plain words (a warning before JSON mode takes over).
            self.error(raw)
            return
        if not isinstance(msg, dict):
            return
        kind = msg.get("message_type")
        if kind == "status":
            self.status(msg, now)
        elif kind == "summary":
            self.summary(msg)
        elif kind == "error":
            err = msg.get("error") or {}
            text = err.get("message") if isinstance(err, dict) else str(err)
            item = msg.get("item")
            self.error(f"{text or 'restic failed'}" + (f" ({item})" if item else ""))
        elif kind == "exit_error":
            self.error(msg.get("message") or "restic failed")
        # verbose_status and the rest: nothing to show.

    def end(self):
        self.clear_bar()
        if self.args.progress:
            try:
                os.remove(self.args.progress)
            except OSError:
                pass
        if self.log:
            self.log.close()


def main():
    p = argparse.ArgumentParser(description="restic's --json progress as a bar")
    p.add_argument("--log", help="the readable log to append to")
    p.add_argument("--progress", help="the bar's file: PERCENT AT, removed at the end")
    p.add_argument("--notify", action="store_true", help="one notification kept up to date")
    p.add_argument("--bar", action="store_true", help="draw the bar on stderr even when it isn't a terminal")
    args = p.parse_args()
    progress = Progress(args)
    try:
        for raw in sys.stdin:
            progress.line(raw, time.time())
    finally:
        progress.end()


if __name__ == "__main__":
    main()
