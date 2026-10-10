"""What every command of vikix agents needs: the constants, the agents at work
found in their terminals (the desktop asked, /proc read), what holds one's
shell (a release's turn, the tests' slots), the office's journal and seats,
the desk records (lib/handoff.py), and the small helpers.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from importlib.machinery import SourceFileLoader
import importlib.util

VIKIX_DIR = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
# Tests name a stand-in for vikix-eval (the live window manager), as vikix-mcp's do.
EVAL = os.environ.get("VIKIX_EVAL") or os.path.join(VIKIX_DIR, "bin", "vikix-eval")
# And another /proc: a test's desktop shouldn't list the real one's agents.
PROC = os.environ.get("VIKIX_PROC") or "/proc"
PROGRAMS = ("claude", "codex", "opencode", "gemini", "aider", "agy")
NAMES = {"agy": "antigravity"}     # a program whose name isn't its agent's
# A provider's program run as a server is no session: codex app-server (runit's
# daemon), claude mcp serve, opencode serve. Never listed as an agent.
SERVERS = {"codex": ("app-server", "exec-server", "mcp-server"), "claude": ("mcp",), "opencode": ("serve", "web", "acp")}
FIELDS = ("agent", "pid", "folder", "workspace", "window", "seconds", "state", "doing", "said", "title", "desk_title",
          "attention")   # what its terminal needs of you: asks, gup, close or "" (agents.lisp)
# What vikix agents handoff writes, given any of them (no "set" needed).
SETTINGS = ("--task", "--status", "--summary", "--next", "--estimate", "--from")


def die(message):
    print(f"vikix agents: {message}", file=sys.stderr)
    # From the menu there is no terminal to read this in: say it on the desktop.
    if not sys.stderr.isatty() and os.environ.get("DISPLAY") and shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Vikix", "vikix agents", message[:300]], check=False)
    sys.exit(1)


def desktop(strict=False):
    """The agents in the desktop's terminals, as StumpWM finds them
    (agents.lisp): a dict each."""
    def failed(message):
        if strict:
            raise RuntimeError(message)
        die(message)
    form = ("(if (fboundp 'vikix-agents-tsv) (progn (princ (vikix-agents-tsv)) (values)) "
            "(error \"this desktop is older than vikix agents: reload it (Super+m, Reload config)\"))")
    try:
        r = subprocess.run(([sys.executable, EVAL] if EVAL.endswith("/bin/vikix-eval") else [EVAL]) + [form],
                           capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        failed("StumpWM didn't answer (is the desktop running? vikix doctor)")
    out = r.stdout + r.stderr
    if "error: " in out:
        failed(out.split("error: ", 1)[1].splitlines()[0])
    if r.returncode != 0:
        failed("StumpWM didn't answer (is the desktop running? vikix doctor)")
    agents = []
    for line in r.stdout.splitlines():
        parts = line.split("\t")
        # A desktop from before the windows were named for their desks has two
        # fields fewer, one from before the colours one fewer.
        if line.startswith("=> ") or len(parts) not in (len(FIELDS) - 2, len(FIELDS) - 1, len(FIELDS)):
            continue
        a = dict(zip(FIELDS, parts + [""] * (len(FIELDS) - len(parts))))
        for k in ("pid", "seconds"):
            a[k] = int(a[k]) if a[k].isdigit() else 0
        agents.append(a)
    return agents


def cmdline(pid):
    try:
        with open(f"{PROC}/{pid}/cmdline", "rb") as f:
            return [w.decode("utf-8", "replace") for w in f.read().split(b"\0") if w]
    except OSError:
        return []


def agent_name(words):
    for word in words[:2]:
        name = os.path.basename(word).lstrip("-")
        if name in PROGRAMS:
            return NAMES.get(name, name)
    return None


def server_p(words):
    """True for a provider's program run as a server (SERVERS): its first
    word after the program that isn't a flag."""
    for i, word in enumerate(words[:2]):
        name = os.path.basename(word).lstrip("-")
        if name in PROGRAMS:
            sub = next((w for w in words[i + 1:] if not w.startswith("-")), "")
            return sub in SERVERS.get(name, ())
    return False


def whereabouts(pid, parent):
    """Where an agent without a window runs, in words: a text console, or
    whatever started it (an editor, tmux, a shell over ssh)."""
    by = (os.path.basename((cmdline(parent) or ["?"])[0]) or "?").lstrip("-")
    try:
        tty = os.readlink(f"{PROC}/{pid}/fd/0")
    except OSError:
        tty = ""
    if tty.startswith("/dev/tty") and tty[8:].isdigit():
        return f"on the text console {tty[5:]} (Ctrl+Alt+F{tty[8:]}), started by {by}"
    return f"started by {by}"


def elsewhere(known, strict=False):
    """Agents running with no terminal window of their own here (an
    editor's, one in tmux or over ssh): not children of one we know."""
    found = []
    try:
        uptime = float(open(f"{PROC}/uptime").read().split()[0])
    except OSError as e:
        if strict:
            raise RuntimeError("process discovery unavailable: " + str(e)) from e
        return found
    for entry in os.listdir(PROC):
        if not entry.isdigit() or int(entry) in known:
            continue
        pid = int(entry)
        try:
            if os.stat(f"{PROC}/{pid}").st_uid != os.getuid():
                continue
            words = cmdline(pid)
            name = agent_name(words)
            if not name:
                continue
            stat = open(f"{PROC}/{pid}/stat").read()
            rest = stat[stat.rindex(")") + 2:].split()
            parent = int(rest[1])
            # A daemon is not an agent (codex's app-server under runit was listed as
            # "codex running"): a server subcommand, or no controlling terminal (stat's
            # tty_nr) and no window here (those are KNOWN). A session in a terminal, in
            # tmux, over ssh or in an Emacs terminal has a tty; one on pipes alone hasn't.
            if server_p(words) or int(rest[4]) == 0:
                continue
            # One an agent started itself (a helper of the same name) is that agent's.
            if agent_name(cmdline(parent)) or parent in known:
                continue
            found.append({"agent": name, "pid": pid, "folder": os.readlink(f"{PROC}/{pid}/cwd"),
                          "workspace": "", "window": "", "seconds": max(0, round(uptime - int(rest[19]) / 100)),
                          "state": "running", "doing": "running", "said": "",
                          "title": "no window of its own: " + whereabouts(pid, parent), "desk_title": "",
                          "attention": ""})
        except (OSError, ValueError, IndexError):
            continue
    return found


# --- What holds an agent: a release's turn, a test slot ------------------------------------
def read_notes(folder, lines):
    """The notes in FOLDER, one a process (its pid the file's name, LINES
    lines in it): [(pid, lines)]. A note whose process is gone is nobody's
    and is cleared away, as .claude/release --queue clears its own."""
    notes = []
    try:
        names = os.listdir(folder)
    except OSError:
        return notes
    for name in names:
        if not name.isdigit():
            continue
        path = os.path.join(folder, name)
        try:
            os.kill(int(name), 0)
        except ProcessLookupError:
            try:
                os.unlink(path)
            except OSError:
                pass
            continue
        except OSError:
            pass
        try:
            with open(path) as f:
                got = [f.readline().rstrip("\n") for _ in range(lines)]
        except OSError:
            continue
        notes.append((int(name), got))
    return notes


def test_notes():
    """tests/run.sh's notes: (pid, [state, test, since]) each, state
    waiting (for a slot), alone (for the machine to itself) or running."""
    folder = os.environ.get("VIKIX_TEST_SLOTS_DIR") or os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp",
                                                                      "vikix-test-slots")
    return read_notes(os.path.join(folder, "notes"), 3)


def release_notes():
    """.claude/release's notes, in each project repository: (pid, [topic,
    state, since, kind, summary]) each."""
    notes = []
    for common in known_repos():
        notes += read_notes(os.path.join(common, "vikix-release-queue"), 5)
    return notes


def under(pid, agents):
    """The pid of the agent of AGENTS ({pid, folder} each) that PID runs
    under (PID itself when it is one), or 0. A process no agent is above
    (a shell Claude Code runs in the background is reparented to init) is
    the agent's whose folder it works in: the one with the deepest folder
    over its cwd, when that is one agent alone and not just home (an agent
    at home, no desk, is over everything)."""
    pids = {a["pid"] for a in agents}
    p = pid
    for _ in range(40):
        if p in pids:
            return p
        p = parent_of(p)
        if p <= 1:
            break
    try:
        cwd = os.readlink(f"{PROC}/{pid}/cwd")
    except OSError:
        return 0
    home = os.path.expanduser("~")
    over = [a for a in agents if a["folder"] and a["folder"].rstrip("/") != home and inside(cwd, a["folder"])]
    if not over:
        return 0
    deepest = max(len(a["folder"]) for a in over)
    over = [a for a in over if len(a["folder"]) == deepest]
    return over[0]["pid"] if len(over) == 1 else 0


def at(since):
    try:
        return time.strftime("%H:%M", time.localtime(int(since)))
    except (ValueError, OverflowError):
        return "?"


def waits(agents):
    """What holds each agent of AGENTS ({pid, folder} each), from the notes
    its processes left: {pid: (words, line)}. Tests of its waiting for a
    slot (and none running) are "waiting for a test slot"; its release
    waiting its turn is "waiting for a release"; a release under way or
    tests running, what step. The line under it says which, since when,
    and what it is behind."""
    held = {}
    tests = {}
    for pid, (state, name, since) in test_notes():
        a = under(pid, agents)
        if a:
            tests.setdefault(a, []).append((state, name, since))
    releases = {}
    all_releases = release_notes()
    for pid, (topic, state, since, kind, summary) in all_releases:
        a = under(pid, agents)
        if a:
            releases[a] = (pid, topic, state, since, kind, summary)
    for a in set(tests) | set(releases):
        words = line = None
        if a in releases:
            pid, topic, state, since, kind, summary = releases[a]
            if state.startswith("waiting"):
                # Ahead of it: the one whose turn it is, then those that came before it.
                ahead = [t for p, (t, st, s, *_) in sorted(all_releases, key=lambda n: (n[1][1].startswith("waiting"), n[1][2]))
                         if p != pid and (not st.startswith("waiting") or s < since)]
                words = "waiting for a release"
                line = (f"its release {topic} waits for its turn since {at(since)}"
                        + (f", behind {', '.join(ahead)}" if ahead else "") + " (.claude/release --queue)")
            else:
                words = f"releasing: {state}"
                line = f"its release {topic}: {state} since {at(since)}; {summary}"
        if a in tests:
            waiting = [n for st, n, _ in tests[a] if st != "running"]
            running = [n for st, n, _ in tests[a] if st == "running"]
            first = min(s for _, _, s in tests[a])
            if waiting and not running:
                words = "waiting for a test slot"
                line = (f"its test{'s' if len(waiting) != 1 else ''} {', '.join(sorted(waiting)[:4])}"
                        f"{'...' if len(waiting) > 4 else ''} wait{'' if len(waiting) != 1 else 's'} for a slot since "
                        f"{at(first)}: other runs are testing on this machine"
                        + (f" (release {releases[a][1]})" if a in releases else ""))
            elif running and not words:
                words = "testing"
                line = (f"its tests: {len(running)} running" + (f", {len(waiting)} waiting for a slot" if waiting else "")
                        + f" since {at(first)}")
        if words:
            held[a] = (words, line)
    return held


def git(folder, *args):
    try:
        r = subprocess.run(["git", "-C", folder, *args], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def with_git(agent):
    """The folder's branch and how many files wait uncommitted there."""
    folder = agent["folder"]
    agent["branch"], agent["uncommitted"] = None, None
    if folder and os.path.isdir(folder):
        branch = git(folder, "rev-parse", "--abbrev-ref", "HEAD")
        if branch is not None:
            agent["branch"] = branch.strip()
            status = git(folder, "status", "--porcelain")
            agent["uncommitted"] = len(status.splitlines()) if status is not None else None
    return agent


def how_long(seconds):
    if seconds < 60:
        return f"{seconds} s"
    if seconds < 3600:
        return f"{seconds // 60} min"
    if seconds < 86400:
        return f"{seconds // 3600} h {seconds % 3600 // 60} min"
    return f"{seconds // 86400} d"


def short(path):
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path == home or path.startswith(home + "/") else path


def where(agent):
    place = short(agent["folder"]) or "?"
    mark = "" if agent.get("desk") else "no desk"
    if agent["branch"] is None:
        return place + (f" ({mark})" if mark else "")
    n = agent["uncommitted"]
    left = "nothing uncommitted" if n == 0 else f"{n} uncommitted" if n is not None else "?"
    return f"{place} ({agent['branch']}, {left}{', ' + mark if mark else ''})"


def projects():
    """vikix-project as a module: its projects are the ones a desk is for."""
    sys.dont_write_bytecode = True     # no __pycache__ left in bin/
    loader = SourceFileLoader("vikix_project", os.path.join(VIKIX_DIR, "bin", "vikix-project"))
    spec = importlib.util.spec_from_loader("vikix_project", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def rofi(prompt, message, lines=None, absent=None):
    """Ask on the desktop: one of LINES (its number), or with none, a line
    of text. None when the menu was closed. ABSENT is what to say when
    there is no desktop to ask on."""
    if not os.environ.get("DISPLAY") or not shutil.which("rofi"):
        die(absent or "say which project: vikix agents desk PROJECT [TOPIC] (vikix project list names them)")
    cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-mesg", message]
    cmd += ["-format", "i", "-no-custom"] if lines is not None else ["-l", "0"]
    r = subprocess.run(cmd, input="\n".join(lines or []), capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return r.stdout.strip()


# The agents that can run on a model on this laptop (LOCAL_OK in bin/vikix-agent).
LOCAL = ("opencode", "codex", "aider")


def lisp_str(text):
    """TEXT as a Lisp string, for a form the desktop reads."""
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def desk_name(folder):
    """What a desk's workspace is called when it needs a name: the topic
    (the worktree's name after the repository's and a dash), else the
    folder's own name."""
    base = os.path.basename(folder.rstrip("/"))
    return base.split("-", 1)[1] if desk_of(folder) and "-" in base else base


def say(message):
    """Said in the terminal, and on the desktop when there is no terminal
    to read it in (the menu)."""
    print(message)
    if not sys.stdout.isatty() and os.environ.get("DISPLAY") and shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Vikix", "vikix agents", message[:300]], check=False)


# --- The desk records (lib/handoff.py): the handoff's helpers every part uses -------------------
_handoff = None


def handoff_module():
    """lib/handoff.py as a module: the desk records."""
    global _handoff
    if _handoff is None:
        sys.dont_write_bytecode = True
        loader = SourceFileLoader("vikix_handoff", os.path.join(VIKIX_DIR, "lib", "handoff.py"))
        spec = importlib.util.spec_from_loader("vikix_handoff", loader)
        _handoff = importlib.util.module_from_spec(spec)
        loader.exec_module(_handoff)
    return _handoff


def common_of(folder):
    """The repository's common git dir for FOLDER, '' for no repository."""
    common = (git(folder, "rev-parse", "--path-format=absolute", "--git-common-dir") or "").strip()
    return os.path.realpath(common) if common else ""


def project_of(folder, common):
    if common:
        name = known_repos().get(common)
        if name:
            return name
        return os.path.basename(os.path.dirname(common))
    return os.path.basename(folder.rstrip("/"))


def by_me():
    """Who writes: the agent this runs under, else the user."""
    me = my_agent()
    return (who(me), me) if me else ("user", None)


def desk_record(folder, task="", by="user", change=None):
    """The record of the desk FOLDER, made when there is none, with TASK
    set when given and CHANGE applied. The record."""
    H = handoff_module()
    common = common_of(folder)
    branch = (git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip() if common else ""

    def apply(rec):
        if task:
            H.set_task(rec, task, by)
        if change:
            change(rec)
    try:
        return H.update(common, folder, apply, branch=branch, project=project_of(folder, common))
    except H.HandoffError as e:
        die(str(e))


def tests_set(rec, on):
    """The desk's tester switch in its record: `tests` "off" under `desk`
    when a hand-in should run nothing by itself; absent when it should.
    Keyed under desk, not handoff, since it is the user's setting for the
    place, which a new worker's cleared handoff must not take away."""
    if on:
        rec["desk"].pop("tests", None)
    else:
        rec["desk"]["tests"] = "off"


def tests_off(folder):
    """Whether the desk's tests are not to run by themselves at a hand-in."""
    H = handoff_module()
    rec = H.load(H.desk_id(common_of(folder), folder)) or {}
    return (rec.get("desk") or {}).get("tests") == "off"


def agents_at(folder):
    """The agents whose seat or folder is FOLDER, from /proc alone."""
    return [a for a in live_agents() if a["folder"] and os.path.realpath(a["folder"]) == os.path.realpath(folder)]


def process_gone(pid):
    """Whether the process PID has ended, asked of the kernel (never of
    the /proc the tests make up, which outlives their stand-ins)."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except PermissionError:
        return False
    return False


def left(argv):
    """Claude Code's SessionEnd hook: how the agent left its desk, noted."""
    got = {}
    if not sys.stdin.isatty():
        try:
            got = json.loads(sys.stdin.read() or "{}")
        except ValueError:
            got = {}
    reason = str((got if isinstance(got, dict) else {}).get("reason") or "exit")[:40]
    me = my_agent()
    if not me or not me["folder"]:
        return 0
    H = handoff_module()
    common = common_of(me["folder"])
    if not H.load(H.desk_id(common, me["folder"])):
        return 0
    dirty = (H.observe(me["folder"]) if os.path.isdir(me["folder"]) else {}).get("dirty")

    def change(rec):
        before = rec.get("left") or {}
        # A dismissal noted a moment ago is the reason; the hook's "other" would hide it.
        if not (before.get("reason") == "dismissed" and time.time() - before.get("at", 0) < 120):
            rec["left"] = {"at": int(time.time()), "by": who(me), "reason": reason, "dirty": dirty}
        H._log(rec, who(me), f"left: {reason}")
    try:
        H.update(common, me["folder"], change)
    except (H.HandoffError, OSError):
        pass
    return 0


def tester_paths(folder):
    """(the log of the desk's last run, the note of a run under way)."""
    H = handoff_module()
    d = os.path.join(STATE, "vikix", "office", "tests")
    did = H.desk_id(common_of(folder), folder)
    return os.path.join(d, did + ".log"), os.path.join(d, did + ".running")


def tester_running(folder):
    """The pid of a tester at work on the desk, or 0; a note whose process is gone is nobody's."""
    try:
        with open(tester_paths(folder)[1]) as f:
            pid = int(f.read().split()[0])
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError, IndexError):
        return 0


def runner_of(folder):
    """The project's test runner for the desk FOLDER: tests/run.sh in the
    folder, else at its worktree's top. (where, runner, takes --changed),
    Nones without one."""
    top = (git(folder, "rev-parse", "--show-toplevel") or "").strip()
    for where in dict.fromkeys([folder, top]):
        runner = os.path.join(where, "tests", "run.sh") if where else ""
        if runner and os.access(runner, os.X_OK):
            try:
                with open(runner, errors="replace") as f:
                    changed = "--changed" in f.read()
            except OSError:
                changed = False
            return where, runner, changed
    return None, None, False


def tester_start(folder):
    """The desk's tests started by themselves, apart from this process
    (a hand-in): their words to the log's side file."""
    log, _ = tester_paths(folder)
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log + ".tester", "w") as out:
        subprocess.Popen([sys.executable, os.path.realpath(__file__), "test", folder], cwd=folder,
                         stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)


def project_folder_p(folder):
    """A project of vikix project's that is no repository: a desk of its own."""
    try:
        return any(os.path.realpath(str(p.path)) == os.path.realpath(folder) for p in projects().discover())
    except (OSError, SystemExit):
        return False


def default_agent():
    try:
        r = subprocess.run([os.path.join(VIKIX_DIR, "bin", "vikix-agent"), "--which"], capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or "claude"
    except (OSError, subprocess.TimeoutExpired):
        return "claude"


# --- The journal of edits, the agents' processes, and what a desk is (the house rules read them) ---
STATE = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
JOURNAL = os.path.join(STATE, "vikix", "office", "journal.jsonl")
RECORDS = os.path.join(VIKIX_DIR, "bin", "vikix-records")


IDLE_SHELL_AFTER = int(os.environ.get("VIKIX_IDLE_SHELL_AFTER") or 600)   # seconds a shell may sleep in a loop before it is said
SHELLS = ("bash", "sh", "dash", "zsh")


def process_table():
    """Every process: {pid: (ppid, name, age in seconds)}, from /proc's stat
    files (the age from the start time and the uptime)."""
    try:
        ticks = os.sysconf("SC_CLK_TCK")
    except (ValueError, OSError):
        ticks = 100
    uptime = 0.0
    for path in (f"{PROC}/uptime", "/proc/uptime"):
        try:
            with open(path) as f:
                uptime = float(f.read().split()[0])
            break
        except (OSError, ValueError, IndexError):
            continue
    table = {}
    try:
        names = os.listdir(PROC)
    except OSError:
        return table
    for entry in names:
        if not entry.isdigit():
            continue
        try:
            with open(f"{PROC}/{entry}/stat") as f:
                stat = f.read()
            end = stat.rindex(")")
            fields = stat[end + 2:].split()
            table[int(entry)] = (int(fields[1]), stat[stat.index("(") + 1:end], max(0.0, uptime - int(fields[19]) / ticks))
        except (OSError, ValueError, IndexError):
            continue
    return table


def idle_shells(pid, table=None, after=IDLE_SHELL_AFTER):
    """The shells under the agent PID that only sleep in a loop: a shell
    given its command on the line (bash -c, as an agent's tool runs one)
    whose children are all sleep, for AFTER seconds or more. [{pid,
    seconds, command}], the oldest first. What a command of the agent's
    leaves when its loop waits for a line that never comes (five of them,
    for hours, 2026-10-10): the agent sits at its prompt, nothing waits on
    them, and the Office sees only the agent. A script (bash tests/run.sh,
    a release) that sleeps between its steps is not one: it is doing
    something."""
    table = process_table() if table is None else table
    children = {}
    for p, (ppid, _, _) in table.items():
        children.setdefault(ppid, []).append(p)
    found, todo, seen = [], list(children.get(pid, [])), set()
    while todo:
        p = todo.pop()
        if p in seen:
            continue
        seen.add(p)
        _, name, age = table[p]
        kids = children.get(p, [])
        words = cmdline(p)
        if (name in SHELLS and len(words) > 1 and words[1] == "-c" and kids
                and all(table[k][1] == "sleep" for k in kids) and age >= after):
            found.append({"pid": p, "seconds": int(age), "command": " ".join(words[2:])[:120]})
        else:
            todo.extend(kids)
    return sorted(found, key=lambda s: -s["seconds"])


def end_shell(pid, table):
    """End the idle shell PID and its sleep, pinned by process descriptors and
    checked against TABLE (a fresh one) to be that shell still: True when
    ended. Never a bare kill of a number that may be another program's by now."""
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        return False
    row = table.get(pid)
    if not row or row[1] not in SHELLS:
        return False
    kids = [k for k, (ppid, name, _) in table.items() if ppid == pid and name == "sleep"]
    done = False
    for target in [pid] + kids:
        try:
            fd = os.pidfd_open(target)
        except OSError:
            continue
        try:
            signal.pidfd_send_signal(fd, signal.SIGTERM)
            done = done or target == pid
        except OSError:
            pass
        finally:
            os.close(fd)
    return done


def parent_of(pid):
    try:
        stat = open(f"{PROC}/{pid}/stat").read()
        return int(stat[stat.rindex(")") + 2:].split()[1])
    except (OSError, ValueError, IndexError):
        return 0


def my_agent():
    """The agent this process runs under (a hook is the agent's child, a
    few shells down), as {agent, pid, folder}; None when there is none.
    VIKIX_AGENT_PID names it outright (the MCP server, the tests)."""
    pid = int(os.environ.get("VIKIX_AGENT_PID") or 0) or os.getppid()
    for _ in range(8):
        if pid <= 1:
            return None
        name = agent_name(cmdline(pid))
        if name:
            # A helper the agent started under its own name (Claude Code's daemon runs
            # the shell commands) is that agent's: the topmost of the same name.
            for _ in range(8):
                up = parent_of(pid)
                if up <= 1 or agent_name(cmdline(up)) != name:
                    break
                pid = up
            try:
                folder = os.readlink(f"{PROC}/{pid}/cwd")
            except OSError:
                folder = ""
            # The folder is the desk it sat down at, when it did; cwd stays the process's own.
            return seated([{"agent": name, "pid": pid, "folder": folder, "cwd": folder}])[0]
        pid = parent_of(pid)
    return None


def live_agents():
    """Every agent running on the machine, from /proc alone (a terminal's
    or not): {agent, pid, folder} each. Nothing is asked of the desktop, so
    a hook never waits on it."""
    return seated([{k: a[k] for k in ("agent", "pid", "folder")} for a in elsewhere(set())])


def alive(pid):
    return agent_name(cmdline(pid)) is not None


def journal_read():
    entries = []
    try:
        with open(JOURNAL) as f:
            for line in f:
                try:
                    entries.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        pass
    return entries


def journal_add(entry):
    """ENTRY to the journal, which keeps only the agents still running:
    the pid of one that is gone may be another program's tomorrow."""
    journal_write([e for e in journal_read() if alive(e.get("pid", 0))] + [entry])


def journal_write(entries):
    os.makedirs(os.path.dirname(JOURNAL), exist_ok=True)
    tmp = JOURNAL + ".tmp"
    with open(tmp, "w") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    os.replace(tmp, JOURNAL)


def record(kind, title, data, key):
    """Into the record store (plugin office), where vikix day and the
    agents' records_search find it; the same key again updates."""
    body = json.dumps({"plugin": "office", "kind": kind, "key": key, "title": title[:500], "data": data})
    try:
        subprocess.run([sys.executable, RECORDS, "add"], input=body, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        pass


def who(a):
    return f"{a['agent']} {a['pid']}"


def repo_of(path):
    """(top, common git dir, path inside the top) for a file, or Nones: a
    file that isn't there yet (Write) is asked about through its folder."""
    folder = path if os.path.isdir(path) else os.path.dirname(path)
    while folder and not os.path.isdir(folder):
        folder = os.path.dirname(folder)
    top = (git(folder, "rev-parse", "--show-toplevel") or "").strip()
    if not top:
        return None, None, None
    common = (git(folder, "rev-parse", "--path-format=absolute", "--git-common-dir") or "").strip()
    return top, os.path.realpath(common), os.path.relpath(path, top)


def changed_in(top, rel):
    """What the worktree TOP has done to REL, uncommitted: '' for nothing."""
    out = git(top, "status", "--porcelain", "--untracked-files=all", "--", rel) or ""
    return out.strip()


def inside(path, folder):
    return bool(folder) and (path == folder or path.startswith(folder.rstrip("/") + "/"))


SEATS = os.path.join(STATE, "vikix", "office", "seats.jsonl")


def seats_read():
    """The seats taken (vikix agents sit), by pid: only the agents still
    running, since a pid that is gone may be another program's tomorrow."""
    seats = {}
    try:
        with open(SEATS) as f:
            for line in f:
                try:
                    e = json.loads(line)
                except ValueError:
                    continue
                if alive(e.get("pid", 0)):
                    seats[e["pid"]] = e
    except OSError:
        pass
    return seats


def desktop_nudge():
    """The desktop names the agent's window for its desk now (agents.lisp's
    pass), not at its next look. Nothing without a desktop, and never an
    error: the seat is taken either way."""
    form = "(progn (when (fboundp 'vikix-agent-titles-refresh) (vikix-agent-titles-refresh)) (values))"
    try:
        subprocess.run(([sys.executable, EVAL] if EVAL.endswith("/bin/vikix-eval") else [EVAL]) + [form],
                       capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass


def seats_write(seats):
    os.makedirs(os.path.dirname(SEATS), exist_ok=True)
    tmp = SEATS + ".tmp"
    with open(tmp, "w") as f:
        for e in seats.values():
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    os.replace(tmp, SEATS)


def seated(agents):
    """AGENTS, each one's folder replaced by the desk it sat down at."""
    seats = seats_read()
    for a in agents:
        s = seats.get(a["pid"])
        if s:
            a["folder"], a["seat"] = s["folder"], True
    return agents


_own = {}


def own_folder(top):
    """The project's own folder for the repository TOP is in: the first
    worktree listed, where main is merged. Never a desk."""
    if top not in _own:
        listed = git(top, "worktree", "list", "--porcelain") or ""
        first = next((line[9:] for line in listed.splitlines() if line.startswith("worktree ")), top)
        _own[top] = os.path.realpath(first)
    return _own[top]


def desk_of(folder):
    """The desk FOLDER is in: a worktree of a repository other than the
    project's own folder. None off one (home, a project's own folder, a
    folder that is no repository)."""
    if not folder or not os.path.isdir(folder):
        return None
    top, _, _ = repo_of(folder)
    if not top or os.path.realpath(top) == own_folder(top):
        return None
    return top


_known = None


def known_repos():
    """The repositories the rule holds for: the projects' (vikix project
    list), by their common git dir, each with the name of its own folder."""
    global _known
    if _known is None:
        _known = {}
        try:
            for p in projects().discover():
                common = (git(str(p.path), "rev-parse", "--path-format=absolute", "--git-common-dir") or "").strip()
                if common:
                    common = os.path.realpath(common)
                    _known.setdefault(common, os.path.basename(os.path.dirname(common)))
        except (OSError, SystemExit):
            pass
    return _known
