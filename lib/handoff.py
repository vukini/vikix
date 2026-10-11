"""handoff.py — the office's desk records: a task, a handoff and the checks
of each desk, kept across agent exits and reboots.

A desk is a folder an agent works in: a worktree of a project's repository
(vikix agents desk, vikix agents sit), or the folder of a project that is
no repository. Its record lives in ~/.local/state/vikix/office/desks/ID.json,
ID made from the repository and the worktree's folder, so it is the same
desk after a reboot and after the agent has gone; a process id is never
part of it. The record keeps three kinds of thing apart:

  task      what the user asked for, in their words ("by": "user")
  handoff   what the agent writes: a status (working, waiting, review,
            finished, or parked: kept aside, to be started later), an estimate of how long the work will take, barring
            a major issue, an account of what it changed and decided, what
            is left and the next action ("by": the agent, as "claude 48213");
            and the hand-in's fields (2026-10-10, TODO 116): acceptance,
            the criteria the user gave as lines, ticked one by one by the
            worker (2 of 3); defects, known defects and limits, open or
            closed; review, findings signed by their reviewer, open or
            addressed; decisions, the choices made, a line each, so the
            next worker doesn't reopen them. Each item signed, each list
            capped, every text through clean
  observed  what Vikix read itself: the commit, branch and uncommitted
            files at each write, and for each check the commit it ran on
            and whether the tree was dirty then; and in the handoff, signed
            vikix, changed (the files against the base, where the desk's
            branch left the project's own, with their line counts, the
            uncommitted marked) and commits (the branch's past the base),
            read from git at every write of the handoff and at the
            tester's run (set_changes)

A check (tests/run.sh house passed, 14:02, on 3f2a1c, tree dirty) is
stale once the code differs from what it ran on: another commit, or other
uncommitted changes (a fingerprint of the diff). Sessions are the
providers' resumable conversation ids (claude's uuid, codex's thread,
opencode's session), id and provider only: no transcript is copied here,
and no credential is accepted into any field.

Writes take a lock on the record, read, change and replace it atomically,
so two agents updating one desk at once lose nothing. Used by
bin/vikix-agents (the commands) and bin/vikix-mcp (the tools).

Each write that changes what others wait on is also a line of the event
log, ~/.local/state/vikix/office/events-YYYY-MM.jsonl, a file a month (as
vikix day keeps its screen log), appended under a lock and never rewritten:
a worker started (kind worker), a status changed (handoff: a hand-in), a
check added (tests done), a desk closed (closed: by close or a release),
an agent that left (left). One JSON object a line: at, kind, the desk's
id, by, and data with the worktree, branch and project and the kind's own
fields. It is what the plan runner (lib/plan.py) waits on instead of
polling the records (events_size, events_since), and anything else may
read it; the task board designed in plans/DESIGN-office-tasks.md writes
the same file.
"""
import copy
import fcntl
import hashlib
import json
import os
import re
import subprocess
import time

VERSION = 1
STATE = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
DESKS = os.path.join(STATE, "vikix", "office", "desks")
EVENTS_DIR = os.path.join(STATE, "vikix", "office")
STATES = ("working", "waiting", "review", "finished", "parked")
PROVIDERS = ("claude", "codex", "opencode", "gemini", "antigravity", "aider", "other")
TEXT_MAX = 4000
LOG_MAX = 40
CHECKS_MAX = 20
SESSIONS_MAX = 10

# The definition of done: what a worker at a desk does, one text (TODO 116,
# 2026-10-10). desk_prompt (lib/agents/desks.py) gives it to every worker
# after its task, the skill's projects.md has it as "A worker's day" and
# docs/agents.md quotes it; tests/codex.sh holds the three to this one.
# The last sentence is from the first live run of a Codex worker: inside
# its sandbox a desk's .git and ~/.local/state are read-only, and asked to
# commit and hand off it saw both fail and stopped, rather than ask to run
# them outside the sandbox, where Vikix's rules let them through.
DONE = ("Understand the task and its acceptance criteria; read the handoff and the project's instructions. "
        "Look at the files the task touches before changing them. Make the change at your desk, on its "
        "branch. Run the tests the change reaches through the project's runner (`tests/run.sh --changed`), "
        "fix what fails, run them again. Update the guides the change makes wrong, in the same commit. "
        "Commit only the files you changed, by name. Write the hand-in: status, what changed and why, what "
        "is decided, what is left, the tests run, the defects you know of. Hand back through the office "
        "(`vikix agents handoff --status review`); don't merge, release or push unless the task or the house "
        "says so. Ask when something essential is missing or an action would lose data, open a hole or "
        "change the design; decide the routine yourself. If your sandbox keeps the desk's `.git` or the "
        "office's state read-only (Codex's does), run git, the tests and `vikix` outside it: ask to escalate, "
        "and the house's rules let a desk's day through without a prompt.")

# What never goes into a record: a key, a token, a password, in any field.
SECRET = re.compile(r"(sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}"
                    r"|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----"
                    r"|\b[A-Z_]*(API_KEY|SECRET|TOKEN|PASSWORD|PASSWD)\s*[=:]\s*\S{6,})")
SESSION_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{3,99}$")
ESTIMATE_MAX = 300
# The desk's history of workers: how many are kept, and how much of each one's summary.
WORKERS_MAX = 50
WORKER_SUMMARY_MAX = 600
# The hand-in's lists: how many items each keeps, how long an item may be,
# how many files and commits the changes read from git keep.
ITEMS_MAX = 50
ITEM_MAX = 1000
FILES_MAX = 200
COMMITS_MAX = 50
SUBJECT_MAX = 120
# A review finding may start with where it is: "lib/x.py:12 the loop ...".
WHERE = re.compile(r"^(\S+:\d+)\s+(.*)$", re.S)
# How long, as an estimate says it: "40 min", "2 h 30 min", "1.5 h", "1:30",
# "2 days", or a bare number of minutes. Words may follow (what it assumes).
DURATION = re.compile(r"(\d+(?:[.,]\d+)?)\s*(min(?:ute)?s?|m|h(?:ou)?rs?|h|d(?:ays?)?)\b", re.I)
DURATION_HMM = re.compile(r"(?<![\d:])(\d{1,3}):([0-5]\d)(?![\d:])")
MINUTES = {"m": 1, "h": 60, "d": 1440}
DESK_ID = re.compile(r"^[0-9a-f]{12}$")


class HandoffError(Exception):
    """A record that can't be made or changed as asked; the message says why."""


# --- Text that may be kept ----------------------------------------------------------------

def clean(text, what="text"):
    """TEXT as a record may hold it: a string, control characters out,
    capped, and never a credential."""
    if text is None:
        return ""
    if not isinstance(text, str):
        raise HandoffError(f"{what} must be text")
    text = "".join(c if c in "\n\t" or ord(c) >= 32 else " " for c in text).strip()
    if SECRET.search(text):
        raise HandoffError(f"{what} looks like it holds a credential: a record keeps none")
    if len(text) > TEXT_MAX:
        text = text[:TEXT_MAX].rstrip() + " …"
    return text


def session_id_ok(sid):
    return isinstance(sid, str) and bool(SESSION_ID.match(sid)) and ".." not in sid and "/" not in sid


def minutes_of(text):
    """The minutes TEXT says, or None when it names no duration: the sum
    of every "N unit" in it ("2 h 30 min" is 150), "H:MM", or the whole
    text a number of minutes."""
    if not isinstance(text, str):
        return None
    if text.strip().isdigit():
        return int(text.strip()) or None
    total = 0.0
    for num, unit in DURATION.findall(text):
        total += float(num.replace(",", ".")) * MINUTES[unit[0].lower()]
    for hours, mins in DURATION_HMM.findall(text):
        total += int(hours) * 60 + int(mins)
    return int(round(total)) or None


def span(minutes):
    """MINUTES as a person says them: 40 min, 1 h 30 min, 2 d 3 h."""
    minutes = int(minutes)
    if minutes < 60:
        return f"{minutes} min"
    if minutes < 1440:
        return f"{minutes // 60} h" + (f" {minutes % 60} min" if minutes % 60 else "")
    return f"{minutes // 1440} d" + (f" {minutes % 1440 // 60} h" if minutes % 1440 // 60 else "")


# --- Where a record lives ------------------------------------------------------------------

def desk_id(common, folder):
    """The stable id of a desk: the repository's common git dir and the
    worktree's folder (the folder alone for a desk that is no repository)."""
    key = f"{os.path.realpath(common) if common else ''}\n{os.path.realpath(folder)}"
    return hashlib.sha1(key.encode()).hexdigest()[:12]


def record_path(did):
    if not DESK_ID.match(did or ""):
        raise HandoffError("not a desk id")
    return os.path.join(DESKS, did + ".json")


def load(did):
    """The record of desk DID, or None."""
    try:
        with open(record_path(did)) as f:
            rec = json.load(f)
    except (OSError, ValueError):
        return None
    return rec if isinstance(rec, dict) and rec.get("version") == VERSION else None


def all_records(strict=False):
    """Every record there is, newest change first."""
    out = []
    try:
        names = os.listdir(DESKS)
    except FileNotFoundError:
        return out
    except OSError:
        if strict:
            raise
        return out
    for name in names:
        if name.endswith(".json") and DESK_ID.match(name[:-5]):
            rec = load(name[:-5])
            if rec:
                out.append(rec)
            elif strict:
                raise HandoffError(f"Cannot read handoff record {name}")
    return sorted(out, key=lambda r: -(r.get("updated") or 0))


def new_record(common, folder, branch, project=""):
    return {"version": VERSION,
            "desk": {"id": desk_id(common, folder), "repo": os.path.realpath(common) if common else "",
                     "worktree": os.path.realpath(folder), "branch": branch or "", "project": project or "",
                     "made": int(time.time()), "closed": 0},
            "task": {}, "handoff": {}, "checks": [], "sessions": [], "observed": {}, "log": [],
            "updated": int(time.time())}


def update(common, folder, change, branch=None, project=None):
    """The record of the desk (COMMON, FOLDER), made when there is none,
    changed by CHANGE(record) under its lock, written atomically. The
    record after."""
    did = desk_id(common, folder)
    path = record_path(did)
    os.makedirs(DESKS, exist_ok=True)
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rec = load(did) or new_record(common, folder, branch, project)
        before = copy.deepcopy(rec)
        if branch:
            rec["desk"]["branch"] = branch
        if project:
            rec["desk"]["project"] = project
        rec["desk"]["closed"] = 0
        change(rec)
        rec["observed"] = observe(folder) if os.path.isdir(folder) else rec.get("observed") or {}
        rec["updated"] = int(time.time())
        rec["log"] = rec.get("log", [])[-LOG_MAX:]
        tmp = f"{path}.{os.getpid()}.tmp"
        with open(tmp, "w") as f:
            json.dump(rec, f, indent=1, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, path)
    for kind, by, data in events_between(before, rec):
        event(kind, by, rec, data)
    return rec


# --- The event log ------------------------------------------------------------------------

def events_between(before, after):
    """What a write changed that others wait on: (kind, fields) each. The
    worker started (the task set or started), the status changed, each check
    added, the desk closed, the agent that left."""
    out = []
    t0, t1 = before.get("task") or {}, after.get("task") or {}
    if t1 and (t1.get("at") != t0.get("at") or t1.get("text") != t0.get("text")):
        out.append(("worker", t1.get("by", ""), {"task": (t1.get("text") or "")[:120]}))
    s0 = ((before.get("handoff") or {}).get("status") or {})
    s1 = ((after.get("handoff") or {}).get("status") or {})
    if s1 and (s1.get("value") != s0.get("value") or s1.get("at") != s0.get("at")):
        out.append(("handoff", s1.get("by", ""), {"status": s1.get("value", "")}))
    c0, c1 = before.get("checks") or [], after.get("checks") or []
    for c in c1[len(c0):] if len(c1) > len(c0) else []:
        out.append(("tests done", c.get("by", ""), {"name": c.get("name", ""), "ok": bool(c.get("ok"))}))
    if (after.get("desk") or {}).get("closed") and not (before.get("desk") or {}).get("closed"):
        log = after.get("log") or [{}]
        out.append(("closed", log[-1].get("by", ""), {}))
    l0, l1 = before.get("left") or {}, after.get("left") or {}
    if l1 and l1.get("at") != l0.get("at"):
        out.append(("left", l1.get("by", ""), {"reason": l1.get("reason", "")}))
    return out


def events_path(now=None):
    """This month's event log."""
    return os.path.join(EVENTS_DIR, time.strftime("events-%Y-%m.jsonl", time.localtime(now or time.time())))


def event(kind, by, rec, data):
    """One line appended to this month's event log for the desk of REC, under
    a lock. Never raises: a log that can't be written loses a line, not the
    write."""
    d = rec.get("desk") or {}
    line = {"at": int(time.time()), "kind": kind, "desk": d.get("id", ""), "by": by,
            "data": dict({"worktree": d.get("worktree", ""), "branch": d.get("branch", ""),
                          "project": d.get("project", "")}, **data)}
    try:
        os.makedirs(EVENTS_DIR, exist_ok=True)
        with open(os.path.join(EVENTS_DIR, "events.lock"), "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with open(events_path(), "a") as f:
                f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except OSError:
        pass


def events_size():
    """How far this month's event log goes now, in bytes: what a reader
    notes to see new lines by (a new month's file starts small, so the
    number changes then too)."""
    try:
        return os.path.getsize(events_path())
    except OSError:
        return 0


def events_since(pos):
    """This month's event log's lines past POS bytes (dicts), and where it
    ends now; the whole file when it is shorter than POS (a new month)."""
    size = events_size()
    if size < pos:
        pos = 0
    out = []
    if size > pos:
        try:
            with open(events_path(), errors="replace") as f:
                f.seek(pos)
                for line in f.read().splitlines():
                    try:
                        got = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(got, dict):
                        out.append(got)
        except OSError:
            return [], pos
    return out, size


# --- What Vikix reads itself ----------------------------------------------------------------

def git(folder, *args):
    try:
        r = subprocess.run(["git", "-C", folder, *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def observe(folder):
    """The folder's git state now: commit, branch, how many files wait
    uncommitted, and a fingerprint of those changes (so a check that ran
    on them can be told from one that ran on others)."""
    now = {"at": int(time.time()), "commit": "", "branch": "", "dirty": None, "fingerprint": ""}
    head = git(folder, "rev-parse", "HEAD")
    if head is None:
        return now
    now["commit"] = head.strip()
    now["branch"] = (git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
    status = git(folder, "status", "--porcelain", "--untracked-files=all")
    if status is not None:
        now["dirty"] = len(status.splitlines())
        diff = git(folder, "diff", "--binary", "HEAD")
        untracked = git(folder, "ls-files", "--others", "--exclude-standard", "-z")
        if diff is None or untracked is None:
            now["dirty"] = None
            return now
        digest = hashlib.sha1((status + "\n" + diff).encode(errors="replace"))
        # Status names an untracked file, but says nothing when its contents
        # change. Include those contents so yesterday's check cannot look fresh.
        try:
            for name in sorted(n for n in untracked.split("\0") if n):
                path = os.path.join(folder, name)
                digest.update(name.encode(errors="replace") + b"\0")
                if os.path.islink(path):
                    digest.update(os.readlink(path).encode(errors="replace"))
                elif os.path.isfile(path):
                    with open(path, "rb") as stream:
                        for chunk in iter(lambda: stream.read(65536), b""):
                            digest.update(chunk)
                else:
                    now["dirty"] = None
        except OSError:
            now["dirty"] = None
        now["fingerprint"] = digest.hexdigest()[:12] if status else ""

    return now


def changes(folder, base):
    """What the desk's branch changed, from git: the files against BASE
    (committed past it, and the uncommitted, marked; a new untracked file
    too) with their line counts, sorted by path, and the commits past
    BASE, oldest first. None where FOLDER is no repository; without a
    BASE, the uncommitted alone and no commits."""
    if git(folder, "rev-parse", "HEAD") is None:
        return None
    files = {}

    def take(text, uncommitted):
        for line in (text or "").splitlines():
            parts = line.split("\t", 2)
            if len(parts) != 3:
                continue
            add, dele, path = parts
            try:
                path = clean(path, "a path")
            except HandoffError:
                continue
            f = files.setdefault(path, {"path": path, "add": 0, "del": 0, "uncommitted": False})
            f["add"] += int(add) if add.isdigit() else 0      # a binary file counts "-"
            f["del"] += int(dele) if dele.isdigit() else 0
            f["uncommitted"] = f["uncommitted"] or uncommitted
    if base:
        take(git(folder, "diff", "--numstat", f"{base}..HEAD"), False)
    take(git(folder, "diff", "--numstat", "HEAD"), True)
    for name in (git(folder, "ls-files", "--others", "--exclude-standard") or "").splitlines():
        try:
            name = clean(name, "a path")
        except HandoffError:
            continue
        if name and name not in files:
            files[name] = {"path": name, "add": 0, "del": 0, "uncommitted": True, "new": True}
    commits = []
    if base:
        for line in (git(folder, "log", "--reverse", "--format=%h%x09%s", f"{base}..HEAD") or "").splitlines():
            short_hash, _, subject = line.partition("\t")
            try:
                subject = clean(subject, "a subject").replace("\n", " ")[:SUBJECT_MAX]
            except HandoffError:
                subject = "(a subject that looks like a credential, withheld)"
            commits.append({"hash": short_hash, "subject": subject})
    return sorted(files.values(), key=lambda f: f["path"]), commits


def set_changes(rec, folder, base):
    """The handoff's changed and commits read again from git, signed vikix:
    at every write of the handoff and at the tester's run. Nothing where
    FOLDER is no repository. True when written."""
    got = changes(folder, base) if os.path.isdir(folder) else None
    if got is None:
        return False
    files, commits = got
    h = rec.setdefault("handoff", {})
    now = int(time.time())
    h["changed"] = {"base": (base or "")[:12], "files": files[:FILES_MAX], "more": max(0, len(files) - FILES_MAX),
                    "by": "vikix", "at": now}
    h["commits"] = {"base": (base or "")[:12], "list": commits[-COMMITS_MAX:], "more": max(0, len(commits) - COMMITS_MAX),
                    "by": "vikix", "at": now}
    return True


def freshness(check, now):
    """Whether CHECK still speaks for the code as it is NOW: 'fresh', or
    'stale' with why."""
    if not now.get("commit"):
        return "unknown (no repository to compare with)"
    if now.get("dirty") is None:
        return "unknown (current working tree could not be read)"
    if check.get("commit") != now["commit"]:
        return f"stale: the code moved on ({(check.get('commit') or '?')[:7]} then, {now['commit'][:7]} now)"
    if (check.get("fingerprint") or "") != (now.get("fingerprint") or ""):
        if check.get("dirty"):
            return "stale: the uncommitted changes differ from the ones it ran on"
        return "stale: uncommitted changes since it ran on a clean tree"
    return "fresh"


# --- The changes a record takes -------------------------------------------------------------

def _log(rec, by, what):
    rec.setdefault("log", []).append({"at": int(time.time()), "by": by, "what": what[:200]})


def set_task(rec, text, by):
    text = clean(text, "the task")
    if not text:
        raise HandoffError("a task needs words")
    rec["task"] = {"text": text, "by": by, "at": int(time.time())}
    _log(rec, by, "task set")


# The hand-in's fields that are the desk's, not a worker's: they stay in the
# live record when a new worker starts (2026-10-11: four review findings,
# three defects and the decisions were dropped at the third worker). The
# rest of the handoff (status, summary, next, estimate) is the worker's and
# goes into the history whole with it.
DESK_FIELDS = ("acceptance", "decisions", "defects", "review", "changed", "commits")


def start_worker(rec, text, by, provider="", mode=""):
    """A new worker at the desk: the task before it, with how it ended and
    the whole of its handoff, goes into the desk's history (`workers`,
    oldest first); the handoff keeps the desk's fields (DESK_FIELDS: the
    criteria, the decisions, the defects, the findings, what changed) and
    loses the worker's (status, summary, next, estimate); how the last
    agent left is cleared, and TEXT is the task. The checks stay: they
    speak for the code, and go stale with it. The entry folded, or None
    when the desk had no task. MODE, when given, is how free the worker
    is, said in the log's line."""
    text = clean(text, "the task")
    if not text:
        raise HandoffError("a worker needs a task (vikix agents worker DESK \"...\"; vikix agents resume takes the conversation up without one)")
    folded = fold_worker(rec)
    rec["task"] = {"text": text, "by": by, "at": int(time.time())}
    rec["handoff"] = {k: v for k, v in (rec.get("handoff") or {}).items() if k in DESK_FIELDS}
    rec.pop("left", None)
    _log(rec, by, f"worker started{', ' + provider if provider else ''}{' ' + mode if mode else ''}: {text[:80]}")
    return folded


def set_launch(rec, provider, mode, by):
    """How the last agent was started at the desk: the provider and its
    mode (how free it is; '' when the provider has none), who asked. Read
    by the listing, the Office and the protection lines; resume takes the
    mode up again for the same provider."""
    rec["launch"] = {"provider": provider or "", "mode": mode or "", "by": by, "at": int(time.time())}


def fold_worker(rec):
    """The current task and handoff as one entry of the desk's history,
    appended to `workers`; None, and nothing done, when there is no task.
    The entry has the task, its status, its summary's first part and who
    worked it, for the Office's list, and under `handoff` the worker's
    fields whole (status, summary, next, estimate: what isn't the desk's,
    DESK_FIELDS), so nothing a worker wrote is lost."""
    t = rec.get("task") or {}
    if not t:
        return None
    h = rec.get("handoff") or {}
    sessions = rec.get("sessions") or []
    entry = {"task": t.get("text", ""), "by": t.get("by", "?"), "at": t.get("at", 0), "ended": int(time.time()),
             "status": (h.get("status") or {}).get("value", ""),
             "summary": (h.get("summary") or {}).get("text", "")[:WORKER_SUMMARY_MAX],
             "provider": sessions[-1]["provider"] if sessions else "",
             "left": (rec.get("left") or {}).get("reason", ""),
             "handoff": {k: v for k, v in h.items() if k not in DESK_FIELDS}}
    d, n = acceptance_count(h)
    if n:
        entry["acceptance"] = f"{d} of {n}"
    rec.setdefault("workers", []).append(entry)
    rec["workers"] = rec["workers"][-WORKERS_MAX:]
    return entry


def lines_of(value, what):
    """VALUE, a string (lines) or a list of strings, as the clean non-empty
    lines a list field takes, each capped."""
    if isinstance(value, str):
        value = value.splitlines()
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        raise HandoffError(f"{what} is a line of text, or a list of them")
    out = []
    for v in value:
        text = clean(v, what).replace("\n", " ")[:ITEM_MAX]
        if text:
            out.append(text)
    return out


def tick(items, n, by, what, key="done"):
    """Item N (counted from 1) of ITEMS marked KEY, signed BY; the item."""
    if isinstance(n, bool) or not isinstance(n, int):
        raise HandoffError(f"{what} takes the number of the item, counted from 1")
    if not 1 <= n <= len(items):
        raise HandoffError(f"{what}: there is no item {n}" + (f" (1 to {len(items)})" if items else " (none yet)"))
    item = items[n - 1]
    item[key] = True
    item[key + "_by"] = by
    item[key + "_at"] = int(time.time())
    return item


def acceptance_count(h):
    """(done, all) of the handoff H's acceptance criteria."""
    items = (h.get("acceptance") or {}).get("items") or []
    return sum(1 for i in items if i.get("done")), len(items)


def handoff_written_at(rec):
    """When the agent (or the user) last wrote the handoff: the newest `at`
    of its fields, leaving out what Vikix observed into it (changed,
    commits). 0 for none."""
    h = rec.get("handoff") or {}
    return max([int(v.get("at") or 0) for v in h.values()
                if isinstance(v, dict) and v.get("by") != "vikix"]
               + [int(i.get("at") or 0) for k in ("defects", "review", "decisions") for i in (h.get(k) or [])]
               or [0])


def set_handoff(rec, by, status=None, summary=None, next_=None, estimate=None, acceptance=None, done=None,
                defect=None, defect_done=None, review=None, review_done=None, decided=None):
    h = rec.setdefault("handoff", {})
    changed = []
    if status is not None:
        if status not in STATES:
            raise HandoffError(f"a status is one of {', '.join(STATES)}, not '{status}'")
        h["status"] = {"value": status, "by": by, "at": int(time.time())}
        changed.append(f"status {status}")
    if estimate is not None:
        text = clean(estimate, "the estimate").replace("\n", " ")[:ESTIMATE_MAX]
        minutes = minutes_of(text)
        if not minutes:
            raise HandoffError("an estimate says how long the work will take, barring a major issue: "
                               "40 min, 2 h 30 min, 1.5 h (what it assumes may follow after a comma)")
        # The clock starts when the estimate is written: it is "from now".
        h["estimate"] = {"text": text, "minutes": minutes, "by": by, "at": int(time.time())}
        changed.append(f"estimate {span(minutes)}")
    if summary is not None:
        h["summary"] = {"text": clean(summary, "the summary"), "by": by, "at": int(time.time())}
        changed.append("summary")
    if next_ is not None:
        h["next"] = {"text": clean(next_, "the next step"), "by": by, "at": int(time.time())}
        changed.append("next")
    if acceptance is not None:
        # The criteria, given whole: a list written again replaces the last, ticks and all.
        items = [{"text": t, "done": False} for t in lines_of(acceptance, "an acceptance criterion")][:ITEMS_MAX]
        if not items:
            raise HandoffError("acceptance criteria are lines of text, one each")
        h["acceptance"] = {"items": items, "by": by, "at": int(time.time())}
        changed.append(f"acceptance ({len(items)})")
    if done is not None:
        items = (h.get("acceptance") or {}).get("items") or []
        item = tick(items, done, by, "--done")
        d, n = acceptance_count(h)
        changed.append(f"done {done} of {n}: {item['text'][:40]}" + (" (all done)" if d == n else ""))
    for value, key, what, word in ((defect, "defects", "a defect", "defect"), (review, "review", "a review finding", "review"),
                                   (decided, "decisions", "a decision", "decided")):
        if value is None:
            continue
        new = lines_of(value, what)
        if not new:
            raise HandoffError(f"{what} needs words")
        for text in new:
            item = {"text": text, "by": by, "at": int(time.time())}
            if key in ("defects", "review"):
                item["open"] = True
            if key == "review":
                m = WHERE.match(text)
                if m:
                    item["where"], item["text"] = m.group(1), m.group(2).strip()
            h.setdefault(key, []).append(item)
        h[key] = h[key][-ITEMS_MAX:]
        changed.append(f"{word} ({len(new)})")
    for n, key, what in ((defect_done, "defects", "--defect-done"), (review_done, "review", "--review-done")):
        if n is None:
            continue
        item = tick(h.get(key) or [], n, by, what, "closed")
        item["open"] = False
        changed.append(f"{what[2:]} {n}: {item['text'][:40]}")
    if not changed:
        raise HandoffError("nothing to set: --status, --summary, --next, --estimate, --acceptance, --done, --defect, "
                           "--defect-done, --review, --review-done or --decided")
    _log(rec, by, ", ".join(changed))


def estimate_state(rec, now=None):
    """Where the work stands against the agent's estimate, or None without
    one: the estimate's fields, the minutes elapsed since it was written
    (wall-clock: time waiting for the user counts, as it would for a
    person), the minutes left (negative when over), whether the work is
    done (status finished, said after the estimate), and a line saying it."""
    h = rec.get("handoff") or {}
    e = h.get("estimate") or {}
    if not e.get("minutes") or not e.get("at"):
        return None
    now = int(now if now is not None else time.time())
    status = h.get("status") or {}
    done = status.get("value") == "finished" and int(status.get("at") or 0) >= int(e["at"])
    elapsed = max(0, (int(status["at"]) if done else now) - int(e["at"])) // 60
    left = int(e["minutes"]) - elapsed
    total = span(e["minutes"])
    if done:
        line = f"finished in {span(elapsed)} against {total}" + (
            f", {span(-left)} over" if left < 0 else f", {span(left)} under" if left > 0 else ", to the minute")
    elif left > 0:
        line = f"{span(left)} left of {total}"
    elif left == 0:
        line = f"its {total} are up"
    else:
        line = f"{span(-left)} over its {total}"
    return {"text": e.get("text", ""), "minutes": int(e["minutes"]), "by": e.get("by", "?"), "at": int(e["at"]),
            "elapsed": elapsed, "left": left, "done": done, "line": line}


def add_check(rec, name, ok, by, folder, note=""):
    name = clean(name, "the check's name").replace("\n", " ")
    if not name:
        raise HandoffError("a check needs a name (the command that ran)")
    now = observe(folder) if os.path.isdir(folder) else {}
    rec.setdefault("checks", []).append(
        {"name": name[:200], "ok": bool(ok), "by": by, "at": int(time.time()), "note": clean(note, "the note")[:500],
         "commit": now.get("commit", ""), "branch": now.get("branch", ""), "dirty": now.get("dirty"),
         "fingerprint": now.get("fingerprint", "")})
    rec["checks"] = rec["checks"][-CHECKS_MAX:]
    _log(rec, by, f"check {'passed' if ok else 'failed'}: {name[:60]}")


def add_session(rec, provider, sid, by, pid=0):
    if provider not in PROVIDERS:
        raise HandoffError(f"a provider is one of {', '.join(PROVIDERS)}, not '{provider}'")
    if not session_id_ok(sid):
        raise HandoffError("a session id is letters, digits, dots, dashes (4 to 100 of them)")
    sessions = [s for s in rec.setdefault("sessions", []) if not (s["provider"] == provider and s["id"] == sid)]
    sessions.append({"provider": provider, "id": sid, "by": by, "pid": int(pid or 0), "at": int(time.time())})
    rec["sessions"] = sessions[-SESSIONS_MAX:]
    _log(rec, by, f"session {provider} {sid[:12]}")


def mark_closed(rec, by):
    rec["desk"]["closed"] = int(time.time())
    _log(rec, by, "desk closed")


def close_record(common, folder, by, summary=None):
    """The record of the desk (COMMON, FOLDER) marked closed, when there is
    one: a desk closed by vikix agents close, or removed by a release. None
    is made for a desk that never had one. With SUMMARY (the release's
    line), a handoff that has no status gets `finished` and that summary
    first, signed BY: the work is on main whatever the agent left unsaid,
    and the Office stops showing the desk as one with no handoff. A status
    the agent wrote stays. True when a record was marked."""
    if not load(desk_id(common, folder)):
        return False

    def change(rec):
        if summary and not (rec.get("handoff") or {}).get("status"):
            try:
                set_handoff(rec, by, status="finished", summary=summary)
            except HandoffError:
                pass     # a summary that can't be kept (a secret in it) costs nothing else
        mark_closed(rec, by)
    update(common, folder, change)
    return True


def forget(did):
    """The record DID removed, under its lock: for a desk whose worktree
    is gone and whose work is in, when the record itself is no longer
    wanted. Nothing else goes with it: no file, no branch, no conversation
    of the provider's. The lock file stays (removing it could split writers
    arriving at once across two inodes). The record as it was, or None
    when there was none; HandoffError when a writer holds it."""
    path = record_path(did)
    rec = load(did)
    if not rec:
        return None
    with open(path + ".lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as e:
            raise HandoffError("the record is being updated: try again in a moment") from e
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    return rec


def from_json(rec, data, by, folder):
    """DATA, a dict as --from reads it, applied: task, status, summary,
    next, estimate, check {name, ok, note}, session {provider, id}; the
    hand-in's acceptance (lines, or a list of them), done N, defect, review
    and decided (a line, or a list), defect_done N, review_done N. Other
    keys are refused, so a typo doesn't go quietly."""
    if not isinstance(data, dict):
        raise HandoffError("the JSON must be an object")
    allowed = {"task", "status", "summary", "next", "estimate", "check", "session",
               "acceptance", "done", "defect", "defect_done", "review", "review_done", "decided"}
    odd = sorted(set(data) - allowed)
    if odd:
        raise HandoffError(f"unknown field{'s' if len(odd) > 1 else ''}: {', '.join(odd)} (the fields: {', '.join(sorted(allowed))})")
    if "task" in data:
        set_task(rec, data["task"], by)
    fields = ("status", "summary", "next", "estimate", "acceptance", "done", "defect", "defect_done", "review",
              "review_done", "decided")
    if any(k in data for k in fields):
        set_handoff(rec, by, data.get("status"), data.get("summary"), data.get("next"), data.get("estimate"),
                    data.get("acceptance"), data.get("done"), data.get("defect"), data.get("defect_done"),
                    data.get("review"), data.get("review_done"), data.get("decided"))
    if "check" in data:
        c = data["check"]
        if not isinstance(c, dict) or "name" not in c or "ok" not in c:
            raise HandoffError("a check is {\"name\": ..., \"ok\": true|false, \"note\": ...}")
        add_check(rec, c["name"], c["ok"], by, folder, c.get("note") or "")
    if "session" in data:
        s = data["session"]
        if not isinstance(s, dict) or "provider" not in s or "id" not in s:
            raise HandoffError("a session is {\"provider\": ..., \"id\": ...}")
        add_session(rec, s["provider"], s["id"], by)


# --- The record as a page -------------------------------------------------------------------

def when(ts):
    if not ts:
        return "?"
    ago = int(time.time()) - int(ts)
    if ago < 90:
        return "just now"
    if ago < 3600:
        return f"{ago // 60} min ago"
    if ago < 86400:
        return f"{ago // 3600} h ago"
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(ts))


def short(path):
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path == home or path.startswith(home + "/") else path


def handin_lines(h):
    """The hand-in's fields of the handoff H as lines for a person: the
    acceptance criteria ticked, the decisions, the defects and the review
    findings open or closed, what changed and the commits (as Vikix read
    them). Nothing for a field that isn't there."""
    lines = []
    acc = h.get("acceptance") or {}
    if acc.get("items"):
        d, n = acceptance_count(h)
        lines.append(f"Acceptance ({acc.get('by', '?')}, {when(acc.get('at', 0))}): {d} of {n} done")
        for i in acc["items"]:
            lines.append(f"  [{'x' if i.get('done') else ' '}] {i['text']}"
                         + (f"  ({i.get('done_by', '?')}, {when(i.get('done_at', 0))})" if i.get("done") else ""))
    if h.get("decisions"):
        lines.append(f"Decided ({len(h['decisions'])}):")
        for i in h["decisions"]:
            lines.append(f"  {i['text']}  ({i.get('by', '?')}, {when(i.get('at', 0))})")
    for key, label in (("defects", "Defects"), ("review", "Review")):
        items = h.get(key) or []
        if not items:
            continue
        open_ = sum(1 for i in items if i.get("open"))
        lines.append(f"{label}: {open_} open" + (f", {len(items) - open_} {'closed' if key == 'defects' else 'addressed'}"
                                                 if len(items) - open_ else ""))
        for i in items:
            state = "open" if i.get("open") else ("closed" if key == "defects" else "addressed")
            lines.append(f"  {state:<9} " + (f"{i['where']} " if i.get("where") else "") + f"{i['text']}  ({i.get('by', '?')}, "
                         f"{when(i.get('at', 0))}" + (f"; {state} by {i.get('closed_by', '?')}" if not i.get("open") else "") + ")")
    ch = h.get("changed") or {}
    if ch.get("files") or ch.get("at"):
        n = len(ch.get("files") or []) + int(ch.get("more") or 0)
        lines.append(f"Changed ({ch.get('by', 'vikix')}, {when(ch.get('at', 0))}): {n} file{'s' if n != 1 else ''}"
                     + (f" against {ch['base'][:7]}" if ch.get("base") else " (uncommitted only: no base to compare with)"))
        for f in (ch.get("files") or [])[:20]:
            lines.append(f"  +{f.get('add', 0)} -{f.get('del', 0)}  {f['path']}"
                         + (" (new, uncommitted)" if f.get("new") else " (uncommitted)" if f.get("uncommitted") else ""))
        if n > 20:
            lines.append(f"  … and {n - 20} more")
    co = h.get("commits") or {}
    if co.get("list"):
        n = len(co["list"]) + int(co.get("more") or 0)
        lines.append(f"Commits ({co.get('by', 'vikix')}, {when(co.get('at', 0))}): {n} past {co.get('base', '?')[:7]}")
        for c in co["list"][-10:]:
            lines.append(f"  {c.get('hash', '?')}  {c.get('subject', '')}")
        if n > 10:
            lines.append(f"  … and {n - 10} before")
    return lines


def handin_text(rec):
    """The record's handoff and hand-in as a paragraph for an agent's first
    prompt (a handover): the status, what was done and decided, what is
    left, the criteria with their ticks, the decisions, the open defects
    and findings, what changed and the commits. '' with nothing written."""
    h = rec.get("handoff") or {}
    out = []
    s = h.get("status")
    if s:
        out.append(f"Status: {s['value']} ({s['by']}, {when(s['at'])}).")
    for key, label in (("summary", "Done and decided"), ("next", "Left to do, next")):
        v = h.get(key)
        if v:
            out.append(f"{label} ({v['by']}): {v['text']}")
    workers = rec.get("workers") or []
    if not s and workers and (workers[-1].get("handoff") or workers[-1].get("summary")):
        # A new worker, or a handover: the last worker's fields went into the history
        # whole (fold_worker); its account is what the next one starts from.
        w = workers[-1]
        wh = w.get("handoff") or {}
        status = (wh.get("status") or {}).get("value") or w.get("status") or "no status"
        out.append(f"The worker before you ({w.get('provider') or '?'}, {status}, {when(w.get('ended', 0))}) "
                   f"was on: {w.get('task', '')}")
        for key, label in (("summary", "It did and decided"), ("next", "It left to do")):
            v = wh.get(key) or ({"text": w["summary"]} if key == "summary" and w.get("summary") else None)
            if v and v.get("text"):
                out.append(f"{label}: {v['text']}")
    acc = h.get("acceptance") or {}
    if acc.get("items"):
        d, n = acceptance_count(h)
        out.append(f"Acceptance criteria, {d} of {n} done (tick one with vikix agents handoff --done N): "
                   + "; ".join(f"{i + 1}. [{'x' if it.get('done') else ' '}] {it['text']}" for i, it in enumerate(acc["items"])))
    if h.get("decisions"):
        out.append("Decided already (don't reopen without the user): " + "; ".join(i["text"] for i in h["decisions"]))
    for key, label in (("defects", "Defects open"), ("review", "Review findings open")):
        items = [i for i in (h.get(key) or []) if i.get("open")]
        if items:
            out.append(f"{label}: " + "; ".join((f"{i['where']} " if i.get("where") else "") + f"{i['text']} ({i.get('by', '?')})"
                                               for i in items))
    ch = h.get("changed") or {}
    if ch.get("files"):
        n = len(ch["files"]) + int(ch.get("more") or 0)
        out.append(f"Changed against {ch.get('base', '?')[:7] or 'HEAD'}: {n} file{'s' if n != 1 else ''}: "
                   + ", ".join(f"{f['path']} (+{f.get('add', 0)} -{f.get('del', 0)}" + (", uncommitted)" if f.get("uncommitted") else ")")
                               for f in ch["files"][:30]) + (", …" if n > 30 else ""))
    co = h.get("commits") or {}
    if co.get("list"):
        n = len(co["list"]) + int(co.get("more") or 0)
        out.append(f"Commits past {co.get('base', '?')[:7]}: {n}: " + "; ".join(f"{c.get('hash', '?')} {c.get('subject', '')}"
                                                                           for c in co["list"][-10:]))
    return "\n".join(out)


def render(rec, agents_at=(), protection=(), now=None):
    """The record as lines for a person: the task, the handoff, the checks
    with their freshness, the git state now, the sessions, who is there
    and what holds the rules for each."""
    d = rec["desk"]
    now = now if now is not None else (observe(d["worktree"]) if os.path.isdir(d["worktree"]) else {})
    lines = [f"Desk {short(d['worktree'])}" + (f" (branch {d['branch']})" if d.get("branch") else "")
             + (f", project {d['project']}" if d.get("project") else "") + f"  [{d['id']}]"]
    if d.get("closed"):
        lines.append(f"  closed {when(d['closed'])}: the record is kept")
    elif not os.path.isdir(d["worktree"]):
        lines.append("  its folder is gone (the record is kept; vikix agents desk makes the worktree again)")
    t = rec.get("task") or {}
    lines.append(f"Task ({t['by']}, {when(t['at'])}): {t['text']}" if t else "Task: none set (vikix agents handoff --task \"...\")")
    h = rec.get("handoff") or {}
    s = h.get("status")
    lines.append(f"Status: {s['value']} ({s['by']}, {when(s['at'])})" if s else "Status: not said")
    gone = rec.get("left") or {}
    if gone.get("reason") and not rec.get("desk", {}).get("closed"):
        n = gone.get("dirty")
        lines.append(f"Left: {gone['reason']} ({gone.get('by', '?')}, {when(gone.get('at', 0))})"
                     + (f", {n} uncommitted then" if n is not None else ""))
    launch = rec.get("launch") or {}
    if launch.get("mode"):
        lines.append(f"Mode: {launch['mode']} ({launch.get('provider') or '?'}; {launch.get('by', '?')}, {when(launch.get('at', 0))}): "
                     + ("no sandbox and no approvals, by the user's word" if launch["mode"] == "unrestricted" else
                        "its sandbox is the desk alone" + (", a reviewer of its own answers the steps out of it"
                                                           if launch["mode"] == "autonomous" else ", every step out of it asks you")))
    if d.get("tests") == "off":
        lines.append("Tests: not run by themselves at a hand-in (--no-tests); vikix agents test runs them")
    turns = rec.get("turns") or {}
    if turns.get("on"):
        lines.append(f"Turns: on ({turns.get('by', '?')}, {when(turns.get('at', 0))}): a clash waits for the other's commit")
    est = estimate_state(rec)
    if est:
        lines.append(f"Estimate ({est['by']}, {when(est['at'])}): {est['text']}; {est['line']}")
    for key, label in (("summary", "Done and decided"), ("next", "Left to do, next")):
        v = h.get(key)
        if v:
            lines.append(f"{label} ({v['by']}, {when(v['at'])}):")
            lines += ["  " + line for line in v["text"].splitlines()]
    lines += handin_lines(h)
    checks = rec.get("checks") or []
    if checks:
        lines.append("Checks:")
        for c in checks[-5:][::-1]:
            lines.append(f"  {'passed' if c['ok'] else 'FAILED'}  {c['name']}  ({c['by']}, {when(c['at'])}, on "
                         f"{(c.get('commit') or '?')[:7]}{', tree dirty' if c.get('dirty') else ', clean tree'})"
                         f"  {freshness(c, now)}" + (f"\n    {c['note']}" if c.get("note") else ""))
    else:
        lines.append("Checks: none recorded")
    workers = rec.get("workers") or []
    if workers:
        lines.append(f"Workers before this one: {len(workers)}")
        for w in workers[-5:][::-1]:
            lines.append(f"  {when(w.get('ended', 0))}  {w.get('status') or 'no status'}"
                         + (f", {w['provider']}" if w.get("provider") else "")
                         + f"  {w.get('task', '')} ({w.get('by', '?')})"
                         + (f"\n    {w['summary'].splitlines()[0]}" if w.get("summary") else ""))
    if now.get("commit"):
        lines.append(f"Now: {now['branch'] or '?'} at {now['commit'][:7]}, "
                     + ("nothing uncommitted" if now.get("dirty") == 0 else f"{now.get('dirty')} uncommitted"))
    sessions = rec.get("sessions") or []
    if sessions:
        lines.append("Sessions: " + "; ".join(f"{s['provider']} {s['id']} ({when(s['at'])})" for s in sessions[::-1]))
    if agents_at:
        lines.append("At the desk now: " + ", ".join(agents_at))
    for line in protection:
        lines.append("  " + line)
    return "\n".join(lines)


# --- Resuming a provider's conversation ---------------------------------------------------------
#
# What each provider offers, as its installed help says (claude, codex,
# opencode, checked 2026-10-06) or its documentation (gemini, aider: not
# installed here, so marked unverified):
#   claude    claude --resume ID          ~/.claude/projects/*/ID.jsonl
#   codex     codex resume ID             ~/.codex/sessions/Y/M/D/rollout-*-ID.jsonl, and from 0.160
#             its thread store beside them: session_index.jsonl (id, thread_name,
#             updated_at) and thread_history_N.sqlite (thread_turns, thread_items
#             by thread_id; a commandExecution item carries its cwd), both read here,
#             the rollout files first, since older installs have those alone
#   opencode  opencode --session ID       ~/.local/share/opencode/opencode.db (table session)
#   gemini    gemini --resume ID          ~/.gemini/tmp/*/chats/   (unverified)
#   antigravity  agy --conversation ID    ~/.gemini/antigravity-cli/brain/ID/ (agy --help 1.3.0,
#             and the folder on this machine); its cache/last_conversations.json
#             maps a folder to its last conversation (what agy -c takes)
#   aider     no session ids: --restore-chat-history reloads the folder's
#             .aider.chat.history.md, which is the folder's, not a session's
# A session is offered only when the record names it and its store still
# has it; never the newest conversation found lying about.

RESUME = {"claude": ["--resume"], "codex": ["resume"], "opencode": ["--session"], "gemini": ["--resume"],
          "antigravity": ["--conversation"]}
UNVERIFIED = {"gemini"}
# A first prompt, the conversation going on at the agent's prompt after it:
# the words that give one, as each installed help says (claude PROMPT,
# codex [PROMPT], opencode --prompt, gemini and agy -i, their
# --prompt-interactive). Aider has none: its --message runs one and exits.
FIRST_PROMPT = {"claude": [], "codex": [], "opencode": ["--prompt"], "gemini": ["-i"], "antigravity": ["-i"]}


def first_prompt_args(provider, text):
    """The arguments that give PROVIDER TEXT as its first prompt and keep
    the conversation going, or None for one that can't."""
    if provider in FIRST_PROMPT and text:
        return FIRST_PROMPT[provider] + [text]
    return None


def home():
    return os.path.expanduser("~")


def session_store(provider, sid, folder=""):
    """Whether PROVIDER's store still has the session SID: (True, where),
    (False, where looked), or (None, why it can't be known)."""
    import glob
    if not session_id_ok(sid or "x"):
        return False, "not a session id"
    if provider == "claude":
        hits = glob.glob(os.path.join(home(), ".claude", "projects", "*", sid + ".jsonl"))
        return (True, short(hits[0])) if hits else (False, short(os.path.join(home(), ".claude", "projects")))
    if provider == "codex":
        root = codex_root()
        hits = glob.glob(os.path.join(root, "sessions", "*", "*", "*", f"rollout-*-{sid}.jsonl"))
        if hits:
            return True, short(hits[0])
        if sid in codex_index(root):
            return True, short(os.path.join(root, "session_index.jsonl"))
        db = codex_db(root)
        if db:
            try:
                import sqlite3
                c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                row = c.execute("SELECT 1 FROM thread_turns WHERE thread_id = ? LIMIT 1", (sid,)).fetchone()
                c.close()
            except Exception:  # noqa: BLE001  a store that can't be read is one we can't vouch for
                return None, f"{short(db)} couldn't be read"
            if row:
                return True, short(db)
        return False, f"{short(root)} (sessions/, session_index.jsonl" + (f", {os.path.basename(db)}" if db else "") + ")"
    if provider == "opencode":
        db = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(home(), ".local", "share"), "opencode", "opencode.db")
        if not os.path.exists(db):
            return False, short(db)
        try:
            import sqlite3
            c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
            row = c.execute("SELECT directory FROM session WHERE id = ?", (sid,)).fetchone()
            c.close()
        except Exception:  # noqa: BLE001  a store that can't be read is one we can't vouch for
            return None, f"{short(db)} couldn't be read"
        return (True, short(db)) if row else (False, short(db))
    if provider == "gemini":
        root = os.path.join(home(), ".gemini", "tmp")
        hits = glob.glob(os.path.join(root, "*", "chats", f"*{sid}*"))
        return (True, short(hits[0])) if hits else (None, f"{short(root)} (gemini's store: unverified here)")
    if provider == "antigravity":
        root = os.path.join(home(), ".gemini", "antigravity-cli", "brain")
        return (True, short(os.path.join(root, sid))) if os.path.isdir(os.path.join(root, sid)) else (False, short(root))
    if provider == "aider":
        return None, "aider has no session ids"
    return None, f"{provider} has no resume known to Vikix"


def codex_root():
    return os.environ.get("CODEX_HOME") or os.path.join(home(), ".codex")


def codex_db(root):
    """Codex's thread store, thread_history_N.sqlite, the newest N; None without one."""
    import glob
    hits = sorted(glob.glob(os.path.join(root, "thread_history_*.sqlite")))
    return hits[-1] if hits else None


def codex_index(root):
    """Codex's session_index.jsonl as {thread id: updated, unix time}; {} without one."""
    out = {}
    try:
        with open(os.path.join(root, "session_index.jsonl")) as f:
            for line in f:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if isinstance(d, dict) and session_id_ok(d.get("id") or ""):
                    out[d["id"]] = iso_time(d.get("updated_at"))
    except OSError:
        pass
    return out


def iso_time(text):
    """An ISO time with any fraction and a Z (Codex's) as unix seconds; 0 for none."""
    import datetime
    try:
        t = re.sub(r"\.\d+", "", str(text or "")).replace("Z", "+00:00")
        return int(datetime.datetime.fromisoformat(t).timestamp())
    except (ValueError, OverflowError):
        return 0


def resume_args(provider, sid, folder=""):
    """The arguments that resume SID with PROVIDER, or None."""
    if provider in RESUME and session_id_ok(sid):
        return RESUME[provider] + [sid]
    if provider == "aider" and folder and os.path.exists(os.path.join(folder, ".aider.chat.history.md")):
        return ["--restore-chat-history"]
    return None


def sessions_on_disk(provider, folder, limit=3):
    """Conversations PROVIDER's own store has for FOLDER, newest first, as
    (id, time): a suggestion for the user to note, never resumed unasked."""
    import glob
    out = []
    try:
        if provider == "claude":
            key = re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(folder))
            for f in glob.glob(os.path.join(home(), ".claude", "projects", key, "*.jsonl")):
                out.append((os.path.basename(f)[:-6], int(os.path.getmtime(f))))
        elif provider == "codex":
            root = codex_root()
            real = os.path.realpath(folder)
            for f in sorted(glob.glob(os.path.join(root, "sessions", "*", "*", "*", "rollout-*.jsonl")))[-200:]:
                try:
                    with open(f) as fh:
                        meta = json.loads(fh.readline() or "{}")
                    p = meta.get("payload") or {}
                    if meta.get("type") == "session_meta" and os.path.realpath(p.get("cwd") or "") == real and p.get("id"):
                        out.append((p["id"], int(os.path.getmtime(f))))
                except (OSError, ValueError):
                    continue
            # The thread store keeps no folder of a thread's own: a thread that ran a
            # command in the folder is one of the folder's.
            db = codex_db(root)
            if db:
                import sqlite3
                index = codex_index(root)
                c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                rows = c.execute("SELECT thread_id, MAX(created_at_ms) FROM thread_items WHERE item_type = 'commandExecution' "
                                 "AND item_json LIKE ? GROUP BY thread_id ORDER BY 2 DESC LIMIT 20",
                                 ("%" + json.dumps({"cwd": real})[1:-1] + "%",)).fetchall()
                c.close()
                for sid, ms in rows:
                    if sid and sid not in {s for s, _ in out}:
                        out.append((sid, index.get(sid) or int((ms or 0) // 1000)))
        elif provider == "opencode":
            db = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(home(), ".local", "share"), "opencode", "opencode.db")
            if os.path.exists(db):
                import sqlite3
                c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                for sid, t in c.execute("SELECT id, time_updated FROM session WHERE directory = ? ORDER BY time_updated DESC LIMIT ?",
                                        (os.path.realpath(folder), limit)):
                    out.append((sid, int(t // 1000) if t and t > 10**11 else int(t or 0)))
                c.close()
        elif provider == "antigravity":
            cache = os.path.join(home(), ".gemini", "antigravity-cli", "cache", "last_conversations.json")
            if os.path.exists(cache):
                with open(cache) as fh:
                    last = json.load(fh)
                sid = last.get(os.path.realpath(folder)) or last.get(folder)
                if sid:
                    out.append((sid, int(os.path.getmtime(cache))))
    except Exception:  # noqa: BLE001  a store that can't be read suggests nothing
        return []
    return sorted(out, key=lambda x: -x[1])[:limit]


def resume_plan(rec, provider, folder, fresh=False):
    """How to open the desk again with PROVIDER: {mode: resumed|fresh,
    session, args, why}. Resumed only for a session the record names
    whose store still has it."""
    sessions = [s for s in (rec or {}).get("sessions", []) if s["provider"] == provider]
    if fresh:
        return {"mode": "fresh", "session": None, "args": [], "why": "a fresh conversation was asked for"}
    if not sessions:
        return {"mode": "fresh", "session": None, "args": [],
                "why": f"no {provider} session is noted on this desk"}
    s = sessions[-1]
    args = resume_args(provider, s["id"], folder)
    if not args:
        return {"mode": "fresh", "session": s, "args": [], "why": f"{provider} can't resume a session by id"}
    found, where = session_store(provider, s["id"], folder)
    if found:
        return {"mode": "resumed", "session": s, "args": args, "why": f"its store has it ({where})"}
    if found is None:
        return {"mode": "fresh", "session": s, "args": [],
                "why": f"whether {provider} still has {s['id']} can't be known: {where}"}
    return {"mode": "fresh", "session": s, "args": [], "why": f"{provider}'s session {s['id']} is gone from {where}"}


# A check's width: what a run of the project's runner covered, by its name.
# A run of named tests (tests/run.sh vk house) is nobody's whole.
RUN_WIDTH = {"changed": 1, "quick": 2, "full": 3}


def check_width(name):
    """How wide the run a check names was: 1 for tests/run.sh --changed
    (with or without a ref), 2 for --quick, 3 for the whole (tests/run.sh
    alone, or --all); 0 for a run of named tests, or anything else."""
    words = (name or "").split()
    if not words or not words[0].endswith("tests/run.sh"):
        return 0
    rest = words[1:]
    if not rest or rest == ["--all"]:
        return RUN_WIDTH["full"]
    if rest == ["--quick"]:
        return RUN_WIDTH["quick"]
    if rest[0] == "--changed" and len(rest) <= 2:
        return RUN_WIDTH["changed"]
    return 0


def fresh_check(rec, commit, kind="changed"):
    """The record's check that lets a release skip its own tests: one that
    passed, on COMMIT exactly, with a clean tree, as wide as the release
    would run (KIND: changed, quick or full) or wider. The newest such
    check, or None; a failed check on the same commit after it counts
    against (the code didn't change, but something did)."""
    want = RUN_WIDTH.get(kind, 1)
    found = None
    for c in rec.get("checks") or []:
        if (c.get("commit") or "") != commit or c.get("dirty"):
            continue
        if c.get("ok") and check_width(c.get("name")) >= want:
            found = c
        elif not c.get("ok") and check_width(c.get("name")) >= want and found:
            found = None
    return found


if __name__ == "__main__":
    # For .claude/release, which has no desk of its own to speak from:
    #   python3 lib/handoff.py closed COMMON FOLDER [BY]
    # marks the record of the desk (COMMON, FOLDER) closed, when there is one;
    #   python3 lib/handoff.py fresh-check COMMON FOLDER COMMIT [changed|quick|full]
    # prints the record's passing check on COMMIT (as wide as that kind of run
    # or wider) and exits 0, or exits 1 when there is none.
    import sys
    if len(sys.argv) >= 4 and sys.argv[1] == "closed":
        sys.exit(0 if close_record(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "user",
                                   sys.argv[5] if len(sys.argv) > 5 else None) else 1)
    if len(sys.argv) >= 5 and sys.argv[1] == "fresh-check":
        rec = load(desk_id(sys.argv[2], sys.argv[3])) or {}
        c = fresh_check(rec, sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else "changed")
        if not c:
            sys.exit(1)
        print(f"{c['name']} passed on {c['commit'][:7]} with a clean tree ({c['by']}, {when(c['at'])}"
              + (f": {c['note'][:120]}" if c.get("note") else "") + ")")
        sys.exit(0)
    sys.stderr.write("usage: python3 handoff.py closed COMMON FOLDER [BY] | fresh-check COMMON FOLDER COMMIT [KIND]\n")
    sys.exit(2)
