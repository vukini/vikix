#!/usr/bin/env python3
"""learn-view.py RUNNER COURSE [--dump WIDTH] — vikix learn's lesson pane.

The lesson you're on, from the top (or where you left it), with the last
check of your work below it. bin/vikix-learn runs it, in the left pane of
`vikix learn COURSE` or on its own (--here); everything about the course
comes from the runner (info, test, next, prev, hint, reset), so this knows
nothing about C.

Keys: the arrows, j/k, PgUp/PgDn, Space and Home/End scroll; n or Right
goes to the next lesson, p or Left to the one before; h shows a hint, c
checks now, r resets the lesson (after asking), q quits. The lesson and
where you were in it are saved as you go, so the next start opens there.

--dump WIDTH prints the lesson as the pane would show it and exits: for
the tests, and for a look without a terminal.
"""

import curses
import os
import re
import subprocess
import sys
import textwrap
import time

POLL = float(os.environ.get("VIKIX_LEARN_POLL", "0.5"))
KEYS = " ↑↓ scroll   n/→ next   p/← back   h hint   c check   r reset   q quit "


def runner(args, runner_path, course):
    """Run `vikix-learn COURSE ARGS...`: (exit code, output)."""
    r = subprocess.run(["bash", runner_path, course, *args], capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).rstrip("\n")


def info(runner_path, course):
    _, out = runner(["info"], runner_path, course)
    return dict(line.split("=", 1) for line in out.splitlines() if "=" in line)


def render(markdown, width):
    """The lesson as (text, style) lines, wrapped to WIDTH. Styles: h (a
    heading), code, plain. The evidence markers (<!-- output: ... -->) are
    for the tests, not the reader, and are left out."""
    lines, in_code = [], False
    width = max(width, 20)
    for raw in markdown.splitlines():
        if raw.startswith("```"):
            in_code = not in_code
            if not in_code:
                lines.append(("", "plain"))
            continue
        if in_code:
            lines.append(("  " + raw, "code"))
            continue
        if re.fullmatch(r"\s*<!--.*-->\s*", raw):
            continue
        m = re.match(r"(#+)\s+(.*)", raw)
        if m:
            if lines and lines[-1][0]:
                lines.append(("", "plain"))
            lines.append((m.group(2).replace("`", ""), "h"))
            continue
        if not raw.strip():
            if lines and lines[-1][0]:
                lines.append(("", "plain"))
            continue
        item = re.match(r"(\s*(?:[-*]|\d+\.)\s+)(.*)", raw)
        lead = item.group(1) if item else ""
        text = item.group(2) if item else raw
        text = re.sub(r"(?<![\w*])\*(\S[^*]*?)\*(?![\w*])", r"\1", text.replace("**", "")).replace("`", "")
        for i, part in enumerate(textwrap.wrap(text, width - len(lead)) or [""]):
            lines.append(((lead if i == 0 else " " * len(lead)) + part, "plain"))
    while lines and not lines[-1][0]:
        lines.pop()
    return lines


class Pane:
    def __init__(self, scr, runner_path, course):
        self.scr, self.runner_path, self.course = scr, runner_path, course
        self.status = []          # the last check's lines
        self.status_ok = None     # True passed, False failed, None not checked yet
        self.note = ""
        self.load()

    # --- the lesson -----------------------------------------------------------
    def load(self):
        self.info = info(self.runner_path, self.course)
        self.dir = self.info.get("dir", "")
        self.work = self.info.get("work", "").split()
        self.state = self.info.get("state", "")
        try:
            with open(os.path.join(self.dir, "lesson.md")) as f:
                self.md = f.read()
        except OSError:
            self.md = "(no lesson.md in %s)" % self.dir
        self.top = self.saved_top()
        self.stamp = self.work_stamp()
        self.status, self.status_ok = ["Save %s in the other pane, and it's checked here." % " ".join(self.work)], None

    def pos_file(self):
        return os.path.join(self.state, "pos-" + self.info.get("lesson", "?"))

    def saved_top(self):
        try:
            with open(self.pos_file()) as f:
                return max(0, int(f.read().strip()))
        except (OSError, ValueError):
            return 0

    def save_top(self):
        try:
            os.makedirs(self.state, exist_ok=True)
            with open(self.pos_file(), "w") as f:
                f.write(str(self.top))
        except OSError:
            pass

    def work_stamp(self):
        out = []
        for name in self.work:
            try:
                st = os.stat(os.path.join(self.dir, name))
                out.append((st.st_mtime_ns, st.st_size))
            except OSError:
                out.append(None)
        return out

    # --- acting -------------------------------------------------------------------
    def check(self):
        rc, out = runner(["test", self.info.get("lesson", "")], self.runner_path, self.course)
        self.status = out.splitlines() or ["(the check said nothing)"]
        self.status_ok = rc == 0
        if rc == 0:
            self.info["done"] = "yes"
            self.note = "Done! n goes on to the next lesson."
        elif rc == 2:
            self.note = "Every check passes: delete the NOT DONE line to finish."
        else:
            self.note = ""

    def step(self, args):
        self.save_top()
        rc, out = runner(args, self.runner_path, self.course)
        if rc == 0:
            self.load()
            self.note = "The shell pane moves here at its next prompt (Enter there)."
        else:
            self.note = out.replace(":: ", "")

    def hint(self):
        _, out = runner(["hint"], self.runner_path, self.course)
        self.status, self.status_ok = out.replace(":: ", "").splitlines(), None
        self.note = "h again for the next hint."

    def reset(self):
        self.note = "Reset this lesson's files as they came? (y/n) Your version stays in vikix undo."
        self.draw()
        if self.scr.getch() in (ord("y"), ord("Y")):
            num = self.info.get("lesson", "")[:2]
            _, out = runner(["reset", num], self.runner_path, self.course)
            self.load()
            self.note = out.replace(":: ", "")
        else:
            self.note = ""

    # --- drawing --------------------------------------------------------------------
    def draw(self):
        scr = self.scr
        scr.erase()
        h, w = scr.getmaxyx()
        if h < 8 or w < 30:
            scr.addnstr(0, 0, "(too small)", w - 1)
            scr.refresh()
            return
        panel = min(max(len(self.status), 2) + 2, max(4, h // 3))
        body_h = h - 2 - panel
        lines = render(self.md, w - 2)
        self.top = max(0, min(self.top, max(0, len(lines) - body_h)))
        done = "  ✓ done" if self.info.get("done") == "yes" else ""
        head = " %s · lesson %s of %s: %s%s " % (self.info.get("title", self.course), self.info.get("number", "?"),
                                                self.info.get("total", "?"), self.info.get("lesson", "?"), done)
        scr.addnstr(0, 0, head.ljust(w), w - 1, curses.A_REVERSE)
        for i, (text, style) in enumerate(lines[self.top:self.top + body_h]):
            attr = {"h": curses.A_BOLD | self.color(3), "code": self.color(4)}.get(style, curses.A_NORMAL)
            scr.addnstr(1 + i, 1, text, w - 2, attr)
        if self.top + body_h < len(lines):
            more = " ↓ %d%% " % (100 * (self.top + body_h) // len(lines))
            scr.addnstr(body_h, w - len(more) - 1, more, len(more), curses.A_DIM)
        y = 1 + body_h
        scr.hline(y, 0, curses.ACS_HLINE, w)
        colour = self.color(2) if self.status_ok else self.color(1) if self.status_ok is False else curses.A_NORMAL
        status = self.status[-(panel - 2):] if len(self.status) > panel - 2 else self.status
        for i, text in enumerate(status):
            attr = colour if ("NOT YET" in text or "ok " in text.lstrip()[:3] or "done" in text) else curses.A_NORMAL
            scr.addnstr(y + 1 + i, 1, text, w - 2, attr)
        if self.note:
            scr.addnstr(h - 2, 1, self.note, w - 2, curses.A_BOLD)
        scr.addnstr(h - 1, 0, KEYS.ljust(w), w - 1, curses.A_REVERSE)
        scr.refresh()

    def color(self, n):
        return curses.color_pair(n) if curses.has_colors() else curses.A_NORMAL

    # --- the loop --------------------------------------------------------------------
    def run(self):
        scr = self.scr
        curses.curs_set(0)
        scr.timeout(int(POLL * 1000))
        if curses.has_colors():
            curses.use_default_colors()
            for n, c in ((1, curses.COLOR_RED), (2, curses.COLOR_GREEN), (3, curses.COLOR_CYAN), (4, curses.COLOR_YELLOW)):
                curses.init_pair(n, c, -1)
        while True:
            self.draw()
            key = scr.getch()
            h, _ = scr.getmaxyx()
            page = max(1, h - 8)
            if key == -1:
                now = self.work_stamp()
                if now != self.stamp:
                    self.stamp = now
                    time.sleep(0.1)   # an editor may write the file in two steps
                    self.check()
                continue
            if key in (ord("q"), ord("Q")):
                self.save_top()
                return
            if key in (curses.KEY_DOWN, ord("j")):
                self.top += 1
            elif key in (curses.KEY_UP, ord("k")):
                self.top = max(0, self.top - 1)
            elif key in (curses.KEY_NPAGE, ord(" ")):
                self.top += page
            elif key in (curses.KEY_PPAGE, ord("b")):
                self.top = max(0, self.top - page)
            elif key == curses.KEY_HOME:
                self.top = 0
            elif key == curses.KEY_END:
                self.top = 10 ** 6
            elif key in (ord("n"), curses.KEY_RIGHT):
                self.step(["next"])
            elif key in (ord("p"), curses.KEY_LEFT):
                self.step(["prev"])
            elif key == ord("h"):
                self.hint()
            elif key == ord("c"):
                self.check()
            elif key == ord("r"):
                self.reset()
            if key not in (-1,):
                self.save_top()


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    runner_path, course = sys.argv[1], sys.argv[2]
    if len(sys.argv) >= 5 and sys.argv[3] == "--dump":
        i = info(runner_path, course)
        with open(os.path.join(i["dir"], "lesson.md")) as f:
            for text, style in render(f.read(), int(sys.argv[4])):
                print(("# " if style == "h" else "") + text)
        return
    try:
        curses.wrapper(lambda scr: Pane(scr, runner_path, course).run())
    except KeyboardInterrupt:
        pass
    # The two panes close together: the shell pane goes with this one.
    if os.environ.get("VIKIX_LEARN_PANES"):
        subprocess.run(["python3", os.path.join(os.path.dirname(runner_path), "vikix-eval"), "(vikix-learn-close)"],
                       capture_output=True)


if __name__ == "__main__":
    main()
