"""tasks.py — the office's tasks: a record of its own for each piece of work,
apart from the desk it is done at and the agent doing it (TODO 115, phase 1
of plans/DESIGN-office-tasks.md, 2026-10-13).

A task lives in ~/.local/state/vikix/office/tasks/ID.json, ID the day it was
made and six hex digits (t-20261013-7f3a9c), for life: a desk's workers come
and go, the task keeps its id, its origin, its priority, its timestamps
(created, queued, launched, activity, done), the launches that worked it and
the agent's handoff as it stood at each write. The desk record points at its
task by id (task.id in lib/handoff.py's record); the task points back at its
desk, when it has one.

Two states, never one (the design's rule). The worker's state is observed at
each snapshot, with where it was read and how sure (worker_state: reliable,
inferred, unknown). The task's state is recorded, in its status, and changes
only by a transition of the table TRANSITIONS (move refuses any other): the
user's act, the agent's handoff (its four words, and parked, map into the
table through HANDOFF_TO: working is running, waiting needs decision,
review needs review, finished ready for release, never completed, since the
agent's work is done and the user's is not; parked is blocked, kept aside),
the tester, the release, the launcher's exit line. A worker's exit never
completes or cancels anything: the task goes to blocked on worker and stays
in view.

The launch sequence is one file, office/sequence, a number taken under flock
and written back plus one at each launch (next_seq); it never goes down, and
a record from before has launch.seq None, shown as "launch order unknown",
never a made-up number.

Every transition is an event: office/events-YYYY-MM.jsonl, the file
lib/handoff.py already writes (a worker started, a hand-in, a check, a desk
closed, an agent that left) and the plan runner wakes on, grown: a line an
event, appended under the same lock, never rewritten, the kinds in KINDS. A
line names its task and its desk, so a task's history is read back from the
log (events_read), and the record's own log keeps only the last forty.

Older records are adopted, not rewritten (adopt): a task record for each
desk record's task and for each entry of its workers history, with what the
record knew and nothing more; what it didn't is null and shown as unknown.

The rules are the desk record's: a write takes the file's lock, reads,
changes, replaces; every text goes through clean (lib/handoff.py's: no
control characters, capped, never a credential); by is user, vikix or an
agent as "claude 48213"; an unknown key is refused. Used by
bin/vikix-agents (the arms tasks, task, events, exited; the writers that make
or move a task), lib/office.py (the snapshot), bin/vikix-mcp (the tool
tasks) and .claude/release (released, below).
"""
import copy
from contextlib import nullcontext
import fcntl
import importlib.util
import json
import os
import re
import sys
import time
from importlib.machinery import SourceFileLoader

VERSION = 1
STATE = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
OFFICE = os.path.join(STATE, "vikix", "office")
TASKS = os.path.join(OFFICE, "tasks")
SEQUENCE = os.path.join(OFFICE, "sequence")
LAUNCHING = os.path.join(OFFICE, "launching")     # the scheduler's launch intents (a later phase writes them)
PRIORITIES = ("critical", "high", "normal", "low")
STATES = ("backlog", "ready", "queued", "running", "needs decision", "needs review", "blocked",
          "ready for release", "completed", "cancelled")
FINAL = ("completed", "cancelled")
OPEN_AT_DESK = ("running", "needs decision", "needs review")     # a worker is at it, or was
ORIGINS = ("user", "agent", "automation", "unknown")
# The agent's four handoff words, and parked, read into the table.
HANDOFF_TO = {"working": "running", "waiting": "needs decision", "review": "needs review",
              "finished": "ready for release", "parked": "blocked"}
# From, to: the design's table (plans/DESIGN-office-tasks.md, Two states),
# with the agent's finished straight from running (no review asked first) and
# a worker's exit from the states a worker holds. The release completes from
# any state that isn't final (released): the branch is on main, whatever the
# record said. Cancelled from any but completed.
TRANSITIONS = {
    (None, "backlog"), (None, "ready"),
    ("backlog", "ready"), ("ready", "queued"), ("queued", "ready"),
    ("queued", "running"), ("ready", "running"), ("blocked", "running"),
    ("running", "needs decision"), ("running", "needs review"), ("running", "blocked"),
    ("needs decision", "running"), ("needs decision", "needs review"), ("needs decision", "blocked"),
    ("needs review", "needs decision"), ("ready for release", "needs decision"),
    ("needs review", "running"), ("needs review", "ready for release"), ("needs review", "blocked"),
    ("running", "ready for release"), ("ready for release", "running"),
    ("ready for release", "completed"), ("needs review", "completed"),
    ("blocked", "ready"), ("queued", "backlog"), ("queued", "blocked"),
    # A worker reporting from a blocked task (one that sat down itself, or
    # was started by hand) ends the block: 2026-10-13, from the first run.
    ("blocked", "needs decision"), ("blocked", "needs review"), ("blocked", "ready for release"),
}
# The event each transition makes, by where it goes (and where from, when
# that decides): the kinds the design names, nothing else.
EVENT_OF = {
    (None, "backlog"): "proposed", (None, "ready"): "created",
    ("backlog", "ready"): "approved", ("ready", "queued"): "queued", ("queued", "ready"): "deferred",
    ("queued", "running"): "launched", ("ready", "running"): "launched", ("blocked", "running"): "launched",
    ("running", "needs decision"): "asked", ("running", "needs review"): "review asked", ("running", "blocked"): "blocked",
    ("needs decision", "running"): "answered", ("needs decision", "needs review"): "review asked",
    ("needs decision", "blocked"): "blocked",
    ("needs review", "needs decision"): "asked", ("ready for release", "needs decision"): "asked",
    ("needs review", "running"): "sent back", ("needs review", "ready for release"): "accepted",
    ("needs review", "blocked"): "blocked",
    ("running", "ready for release"): "accepted", ("ready for release", "running"): "sent back",
    ("ready for release", "completed"): "completed", ("needs review", "completed"): "completed",
    ("blocked", "ready"): "unblocked", ("queued", "backlog"): "deferred", ("queued", "blocked"): "blocked",
    ("blocked", "needs decision"): "asked", ("blocked", "needs review"): "review asked", ("blocked", "ready for release"): "accepted",
}
KINDS = ("created", "approved", "priority", "ordered", "queued", "deferred", "launched", "paused", "resumed",
         "asked", "answered", "handoff", "tests started", "tests done", "review asked", "accepted", "sent back",
         "blocked", "unblocked", "exited", "handed off", "released", "completed", "cancelled", "proposed",
         "uncertain", "adopted", "launch failed",
         # lib/handoff.py's own, in the same file since before this design.
         "worker", "closed", "left")
FIELDS = ("version", "id", "title", "text", "project", "desk", "topic", "origin", "priority", "status", "blocked",
          "after", "worker", "launch", "launches", "created", "queued", "launched", "activity", "done", "handoff",
          "decisions", "children", "log")
TASK_ID = re.compile(r"^t-\d{8}-[0-9a-f]{6}$")
TITLE_MAX = 80
LOG_MAX = 40
LAUNCHES_MAX = 50
FAILED_WITHIN = 60       # a process gone this soon after its launch failed, as far as the record can tell
STARTING_WITHIN = 30     # a launch intent this young is a worker starting
SURE = ("reliable", "inferred", "unknown")

_H = None


def handoff_module():
    """lib/handoff.py, which keeps clean, the credential rule, the desk
    records and the event log's path: the copy already loaded (by
    bin/vikix-agents as vikix_handoff, by a test as handoff), else the file
    beside this one."""
    global _H
    if _H is None:
        _H = sys.modules.get("vikix_handoff") or sys.modules.get("handoff")
    if _H is None:
        sys.dont_write_bytecode = True
        loader = SourceFileLoader("vikix_handoff", os.path.join(os.path.dirname(os.path.realpath(__file__)), "handoff.py"))
        spec = importlib.util.spec_from_loader("vikix_handoff", loader)
        _H = importlib.util.module_from_spec(spec)
        loader.exec_module(_H)
    return _H


class TaskError(Exception):
    """A task that can't be made or moved as asked; the message says why."""


def clean(text, what="text"):
    """TEXT as a record may hold it (lib/handoff.py's clean: control
    characters out, capped, never a credential), as a TaskError."""
    H = handoff_module()
    try:
        return H.clean(text, what)
    except H.HandoffError as e:
        raise TaskError(str(e)) from e


def word(text, what, limit=200):
    """A short text, one line."""
    return clean(text, what).replace("\n", " ")[:limit]


def now_s():
    return int(time.time())


# --- Where a record lives ------------------------------------------------------------------

def task_id_ok(tid):
    return isinstance(tid, str) and bool(TASK_ID.match(tid))


def path(tid):
    if not task_id_ok(tid):
        raise TaskError("not a task id (t-20261013-7f3a9c is one; vikix agents tasks lists them)")
    return os.path.join(TASKS, tid + ".json")


def new_id(when=None):
    """A fresh id: the day and six hex digits, not one in use."""
    day = time.strftime("%Y%m%d", time.localtime(when or time.time()))
    for _ in range(20):
        tid = f"t-{day}-{os.urandom(3).hex()}"
        if not os.path.exists(os.path.join(TASKS, tid + ".json")):
            return tid
    raise TaskError("no free task id found (twenty tries)")


def check(rec):
    """REC as a record: its keys the record's, its status and priority
    words, its texts clean. Refuses otherwise, so a typo never goes in."""
    if not isinstance(rec, dict):
        raise TaskError("a task record is an object")
    odd = sorted(set(rec) - set(FIELDS))
    if odd:
        raise TaskError(f"unknown field{'s' if len(odd) > 1 else ''}: {', '.join(odd)}")
    if rec.get("version") != VERSION or not task_id_ok(rec.get("id")):
        raise TaskError("not a task record of this version")
    if (rec.get("status") or {}).get("value") not in STATES:
        raise TaskError(f"a status is one of {', '.join(STATES)}")
    if rec.get("priority") not in PRIORITIES:
        raise TaskError(f"a priority is one of {', '.join(PRIORITIES)}")
    if (rec.get("origin") or {}).get("kind") not in ORIGINS:
        raise TaskError(f"an origin is one of {', '.join(ORIGINS)}")
    for key in ("title", "text", "project", "topic"):
        rec[key] = clean(rec.get(key) or "", key)
    return rec


def load(tid):
    """The record of task TID, or None."""
    try:
        with open(path(tid)) as f:
            rec = json.load(f)
    except (OSError, ValueError, TaskError):
        return None
    return rec if isinstance(rec, dict) and rec.get("version") == VERSION else None


def all_tasks(strict=False):
    """Every task there is, newest created first."""
    out = []
    try:
        names = os.listdir(TASKS)
    except FileNotFoundError:
        return out
    except OSError:
        if strict:
            raise
        return out
    for name in names:
        if name.endswith(".json") and task_id_ok(name[:-5]):
            rec = load(name[:-5])
            if rec:
                out.append(rec)
            elif strict:
                raise TaskError(f"Cannot read task record {name}")
    return sorted(out, key=lambda r: -(r.get("created") or 0))


def write(rec):
    """REC written atomically, checked; the caller holds its lock."""
    check(rec)
    rec["log"] = (rec.get("log") or [])[-LOG_MAX:]
    rec["launches"] = (rec.get("launches") or [])[-LAUNCHES_MAX:]
    os.makedirs(TASKS, exist_ok=True)
    p = path(rec["id"])
    tmp = f"{p}.{os.getpid()}.tmp"
    with open(tmp, "w") as f:
        json.dump(rec, f, indent=1, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, p)
    return rec


def update(tid, change):
    """The record of TID, changed by CHANGE(record) under its lock, written
    atomically. The record after; TaskError when there is none."""
    p = path(tid)
    os.makedirs(TASKS, exist_ok=True)
    with open(p + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rec = load(tid)
        if not rec:
            raise TaskError(f"no task {tid} (vikix agents tasks lists them)")
        change(rec)
        rec["activity"] = now_s()
        write(rec)
    return rec


def _log(rec, by, what):
    rec.setdefault("log", []).append({"at": now_s(), "by": by, "what": what[:200]})


def title_of(text):
    """The first line of TEXT, TITLE_MAX characters at most."""
    first = (text.strip().splitlines() or [""])[0].strip()
    return first if len(first) <= TITLE_MAX else first[:TITLE_MAX - 1].rstrip() + "…"


def desk_of_record(rec):
    """A task's desk fields from a desk record REC (lib/handoff.py's)."""
    d = (rec or {}).get("desk") or {}
    if not d.get("id"):
        return {}
    return {"id": d["id"], "worktree": d.get("worktree", ""), "branch": d.get("branch", "")}


# --- The sequence ------------------------------------------------------------------------

def next_seq():
    """The next launch number: office/sequence plus one, under flock. It
    never goes down; nothing else gives numbers."""
    os.makedirs(OFFICE, exist_ok=True)
    with open(SEQUENCE + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(SEQUENCE) as f:
                n = int((f.read().strip() or "0"))
        except (OSError, ValueError):
            n = 0
        n += 1
        tmp = f"{SEQUENCE}.{os.getpid()}.tmp"
        with open(tmp, "w") as f:
            f.write(f"{n}\n")
        os.replace(tmp, SEQUENCE)
    return n


def sequence():
    """The last launch number given, 0 for none yet."""
    try:
        with open(SEQUENCE) as f:
            return int(f.read().strip() or "0")
    except (OSError, ValueError):
        return 0


# --- The event log ------------------------------------------------------------------------

def event(kind, by, task=None, desk=None, data=None, seq=None):
    """One line appended to this month's event log, under the lock
    lib/handoff.py uses: at, kind, the task's id and the desk's, by, seq
    when a launch gives one, and data. TASK is a task record or id, DESK a
    desk record's desk dict or id. Never raises: a log that can't be
    written loses a line, not the write."""
    by = word(by, "who", 60)
    if kind not in KINDS:
        raise TaskError(f"not an event kind: {kind}")
    H = handoff_module()
    if isinstance(task, dict):
        desk = desk or task.get("desk") or {}
        task = task.get("id", "")
    d = desk if isinstance(desk, dict) else {"id": desk or ""}
    line = {"at": now_s(), "kind": kind, "task": task or "", "desk": d.get("id", ""), "by": by}
    if seq is not None:
        line["seq"] = seq
    line["data"] = dict({k: d.get(k, "") for k in ("worktree", "branch") if d.get(k)}, **(data or {}))
    try:
        os.makedirs(H.EVENTS_DIR, exist_ok=True)
        with open(os.path.join(H.EVENTS_DIR, "events.lock"), "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with open(H.events_path(), "a") as f:
                f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except OSError:
        pass
    return line


def events_files():
    """The event log's files, newest month first."""
    H = handoff_module()
    try:
        names = [n for n in os.listdir(H.EVENTS_DIR) if re.fullmatch(r"events-\d{4}-\d{2}\.jsonl", n)]
    except OSError:
        return []
    return [os.path.join(H.EVENTS_DIR, n) for n in sorted(names, reverse=True)]


def events_read(task=None, desk=None, since=0, limit=200):
    """The events, newest first: of TASK (an id), of DESK (a desk id), or
    all; those at or after SINCE (epoch seconds); LIMIT at most. Read from
    the newest month back, stopping when there are enough."""
    out = []
    for file in events_files():
        try:
            with open(file, errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            continue
        for line in reversed(lines):
            try:
                got = json.loads(line)
            except ValueError:
                continue
            if not isinstance(got, dict):
                continue
            if since and (got.get("at") or 0) < since:
                continue
            if task and got.get("task") != task:
                continue
            if desk and got.get("desk") != desk:
                continue
            out.append(got)
            if len(out) >= limit:
                return out
        if since and lines:
            try:
                first = json.loads(lines[0])
                if (first.get("at") or 0) < since:
                    break        # the older files are older still
            except ValueError:
                pass
    return out


# --- Making and moving a task --------------------------------------------------------------

def new(text, project, by, kind="user", desk=None, topic="", priority="normal", worker=None, status="ready",
        created=None, parent=None, origin_worker=None, source=""):
    """A task made: TEXT the words, PROJECT its project, BY who made it,
    KIND its origin's (user, agent, automation, unknown; SOURCE says which
    automation, PARENT an agent's own task), DESK the desk dict (id,
    worktree, branch) or none, TOPIC the desk to make, PRIORITY, WORKER the
    choices as the forms have them, STATUS ready (the user's) or backlog
    (an agent's proposal). Written, with its created event. The record."""
    text = clean(text, "the task")
    if not text:
        raise TaskError("a task needs words")
    if status not in ("backlog", "ready"):
        raise TaskError("a new task is ready, or backlog for a proposal")
    if kind not in ORIGINS:
        raise TaskError(f"an origin is one of {', '.join(ORIGINS)}")
    if priority not in PRIORITIES:
        raise TaskError(f"a priority is one of {', '.join(PRIORITIES)}")
    at = int(created or now_s())
    by = word(by, "who", 60)
    rec = {"version": VERSION, "id": new_id(at), "title": title_of(text), "text": text,
           "project": word(project or "", "the project", 120), "desk": dict(desk or {}), "topic": word(topic or "", "the topic", 60),
           "origin": {"kind": kind, "by": by, "parent": parent, "worker": origin_worker, "source": word(source or "", "the source", 120),
                      "approved": {"by": by, "at": at} if kind == "user" else None},
           "priority": priority, "status": {"value": status, "by": by, "at": at, "reason": ""},
           "blocked": {}, "after": [], "worker": worker_choices(worker), "launch": {}, "launches": [],
           "created": at, "queued": None, "launched": None, "activity": at, "done": None,
           "handoff": {}, "decisions": [], "children": [], "log": []}
    _log(rec, by, f"created, {status}")
    os.makedirs(TASKS, exist_ok=True)
    with open(path(rec["id"]) + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        write(rec)
    event(EVENT_OF[(None, status)], by, rec, data={"origin": kind, "title": rec["title"][:120]})
    return rec


def worker_choices(choices):
    """The worker's choices as the record keeps them: use (a provider or
    ''), local, push, no_tests, mode."""
    c = choices or {}
    return {"use": word(c.get("use") or "", "the provider", 40), "local": bool(c.get("local")), "push": bool(c.get("push")),
            "no_tests": bool(c.get("no_tests")), "mode": word(c.get("mode") or "", "the mode", 40)}


def can_move(rec, to, done=False):
    """Whether the task REC may go to TO: (ok, why not). DONE is the fact
    that the work is in (the release, a branch seen merged): completed from
    any state that isn't final, whatever the record said."""
    at = (rec.get("status") or {}).get("value")
    if to not in STATES:
        return False, f"not a state: {to}"
    if at == to:
        return False, f"it is {to} already"
    if at in FINAL:
        return False, f"it is {at}, which is final: a new task is made instead"
    if to == "cancelled" or (to == "completed" and done):
        return True, ""
    if (at, to) not in TRANSITIONS:
        return False, f"no way from {at} to {to} in the table"
    return True, ""


def _move(rec, to, by, reason="", kind=None, done=False):
    """REC's status set to TO, signed BY, with REASON; the event's kind.
    TaskError for a transition the table refuses (DONE: see can_move)."""
    ok, why = can_move(rec, to, done)
    if not ok:
        raise TaskError(f"{rec['id']} can't go to {to}: {why}")
    frm = (rec.get("status") or {}).get("value")
    at = now_s()
    rec["status"] = {"value": to, "by": by, "at": at, "reason": word(reason or "", "the reason")}
    if to == "queued":
        rec["queued"] = at
    if to in FINAL:
        rec["done"] = at
    if to != "blocked":
        rec["blocked"] = {}
    _log(rec, by, f"{frm} -> {to}" + (f": {reason}" if reason else ""))
    return frm, kind or ("cancelled" if to == "cancelled" else "completed" if to == "completed" else EVENT_OF.get((frm, to), "uncertain"))


def move(tid, to, by, reason="", kind=None, data=None, blocked_on="", done=False):
    """Task TID moved to TO by BY, with REASON, and its event appended:
    KIND when given, else the table's for the transition; BLOCKED_ON what
    holds it (another task's id, worker, tests, release, decision); DONE
    the fact that the work is in (completed from anywhere but final).
    TaskError for a transition the table refuses. The record after."""
    by = word(by, "who", 60)
    out = {}

    def change(rec):
        out["from"], out["kind"] = _move(rec, to, by, reason, kind, done)
        if to == "blocked":
            rec["blocked"] = {"on": word(blocked_on or "", "what blocks", 60), "why": word(reason or "", "why")}
    rec = update(tid, change)
    d = dict(data or {}, **{"from": out["from"], "to": to})
    if reason:
        d["reason"] = word(reason, "the reason")
    if to == "blocked" and blocked_on:
        d["on"] = word(blocked_on, "what blocks", 60)
    event(out["kind"], by, rec, data=d)
    return rec


def launch(tid, provider, by, how, pid=0, mode="", numbered=True, start="", sequence=None):
    """Task TID launched: a worker started on it, PROVIDER's, by BY, HOW (worker,
    desk --task, resume, sit, handoff --task; the queue's start later).
    The next sequence number is taken (NUMBERED false for an agent that
    sat down itself, which the office never started: its launch keeps no
    number, as the design wants no made-up one) and the launch kept, in
    launches too; the status goes to running from ready, queued or blocked,
    and stays where a worker holds it (running, needs decision, needs
    review: a resumed conversation on a task already open). A change of
    provider from the launch before is an event handed off. The record."""
    by = word(by, "who", 60)
    seq = (sequence if sequence is not None else next_seq()) if numbered else None
    out = {}

    def change(rec):
        before = rec.get("launch") or {}
        at = now_s()
        rec["launch"] = {"seq": seq, "at": at, "by": by, "provider": word(provider or "", "the provider", 40),
                         "pid": int(pid or 0), "start": str(start or ""), "mode": word(mode or "", "the mode", 40), "how": word(how, "how", 60)}
        rec.setdefault("launches", []).append(dict(rec["launch"], ended=None, code=None, left=""))
        rec["launched"] = rec.get("launched") or at
        rec.pop("left", None)
        status = (rec.get("status") or {}).get("value")
        out["from"] = status
        if status in ("ready", "queued", "blocked"):
            _move(rec, "running", by, how)
        elif status in FINAL:
            raise TaskError(f"{tid} is {status}: a new task is made instead")
        else:
            _log(rec, by, f"launched again, {how}" + (f" #{seq}" if seq else ""))
        out["handed"] = (before.get("provider"), provider) if before.get("provider") and before.get("provider") != provider else None
    rec = update(tid, change)
    if out["handed"]:
        event("handed off", by, rec, data={"from": out["handed"][0], "to": out["handed"][1]})
    event("launched", by, rec, seq=seq, data={"provider": provider, "pid": int(pid or 0), "how": how, "from": out["from"]})
    return rec


def exited(tid, code=None, reason="", by="vikix", dirty=None):
    """The worker of task TID gone: the last launch ended, with the exit
    CODE (the launcher's line) or REASON (the SessionEnd hook's; the
    process gone); the event exited; and from running the task goes to
    blocked on worker (never completed or cancelled: the design's rule).
    The record, or None without the task."""
    by = word(by, "who", 60)
    rec = load(tid)
    if not rec:
        return None
    out = {}

    def change(rec):
        launches = rec.setdefault("launches", [])
        at = now_s()
        if launches and not launches[-1].get("ended"):
            launches[-1]["ended"] = at
            launches[-1]["code"] = code
            launches[-1]["left"] = word(reason or "", "how it left", 60)
        if rec.get("launch"):
            rec["launch"]["ended"] = at
        status = (rec.get("status") or {}).get("value")
        out["moved"] = None
        why = (f"the worker stopped: exit {code}" if code not in (None, 0) else "the worker stopped" if code == 0
               else f"the worker left: {reason}" if reason else "the worker left")
        if status == "running":
            _move(rec, "blocked", by, why, "blocked")
            rec["blocked"] = {"on": "worker", "why": why}
            out["moved"] = why
        else:
            _log(rec, by, why)
    rec = update(tid, change)
    event("exited", by, rec, data={"code": code, "reason": word(reason or "", "how it left", 60), "dirty": dirty})
    if out["moved"]:
        event("blocked", by, rec, data={"from": "running", "to": "blocked", "on": "worker", "reason": out["moved"]})
    return rec


def handoff_move(tid, status, by, handoff=None):
    """The agent's handoff STATUS (its four words, or parked) read into the
    task TID's state through HANDOFF_TO, with HANDOFF (the desk record's)
    copied into the task; a word that asks for the state it is in, or a
    transition the table refuses, moves nothing and is noted in the task's
    log (the agent's claim stays in the handoff, which is its own). The
    record, or None without the task."""
    by = word(by, "who", 60)
    rec = load(tid)
    if not rec:
        return None
    to = HANDOFF_TO.get(status)
    out = {}

    def change(rec):
        if handoff is not None:
            rec["handoff"] = copy.deepcopy(handoff)
        out["kind"] = out["from"] = None
        if not to:
            _log(rec, by, f"handoff status {status}: no state of the task's for it")
            return
        if to != 'needs decision' and any(d['blocks'] for d in decisions(tid, open_only=True)):
            _log(rec, by, 'handoff leaves the task waiting for its open decisions')
            return
        ok, why = can_move(rec, to)
        if not ok:
            _log(rec, by, f"handoff status {status}: {why}")
            return
        frm = (rec.get("status") or {}).get("value")
        # working again is the block, the question or the review over, not a launch.
        kind = ({"blocked": "unblocked", "needs decision": "answered", "needs review": "sent back",
                 "ready for release": "sent back"}.get(frm) if status == "working" else None)
        out["from"], out["kind"] = _move(rec, to, by, f"the agent's handoff says {status}", kind)
        if to == "blocked":
            rec["blocked"] = {"on": "parked", "why": "kept aside, to be started later (parked)"}
    rec = update(tid, change)
    if out["kind"]:
        event(out["kind"], by, rec, data={"from": out["from"], "to": to, "status": status})
    return rec


def set_handoff(tid, handoff, by):
    """The desk's handoff copied into task TID at a write of it, so the
    history has the agent's words; nothing moves."""
    by = word(by, "who", 60)
    if not load(tid):
        return None
    return update(tid, lambda rec: rec.__setitem__("handoff", copy.deepcopy(handoff or {})))


def tests_moved(tid, ok, names, worker_there, by="vikix"):
    """The tester's result for task TID read into its state: a check that
    failed with the worker gone blocks the task on tests; failed with the
    worker still there, a task in review goes back to running (it reads
    the inbox and goes on); a check that passed moves nothing. The record,
    or None."""
    by = word(by, "who", 60)
    rec = load(tid)
    if not rec or ok:
        return rec
    status = (rec.get("status") or {}).get("value")
    why = "tests failed: " + ", ".join(names or [])[:120]
    try:
        if not worker_there and status in OPEN_AT_DESK:
            return move(tid, "blocked", by, why, blocked_on="tests")
        if worker_there and status == "needs review":
            return move(tid, "running", by, why)
    except TaskError:
        pass
    return rec


# --- The worker's state, observed -----------------------------------------------------------

def _state(state, source, sure, **more):
    return dict({"state": state, "source": source, "sure": sure}, **more)


def worker_state(agent, task, now=None):
    """The worker's state for TASK, read from AGENT (the listing's row for
    the agent at its desk, or None when none is there) and the task's
    launches: the state, where it was read, and how sure (reliable,
    inferred, unknown). Never guessed: a state that can't be read is
    unknown, with why."""
    now = int(now or time.time())
    task = task or {}
    if task.get("id"):
        intent = os.path.join(LAUNCHING, task["id"])
        try:
            if now - int(os.path.getmtime(intent)) < STARTING_WITHIN and not agent:
                return _state("starting", "a launch intent with no process yet", "reliable")
        except OSError:
            pass
    if agent:
        if agent.get("paused"):
            return _state("paused", "the pause file", "reliable", by=(agent["paused"] or {}).get("by", ""))
        if agent.get("waits"):
            return _state("held", "the notes of the tests and the release queue", "reliable", why=str(agent["waits"])[:120])
        s = str(agent.get("state") or "")
        noted = bool(agent.get("said"))
        if s in ("asks", "permission"):
            return (_state("waiting for permission", "the agent-waiting plugin's note", "reliable") if noted or agent.get("agent") == "claude"
                    else _state("waiting for permission", "the window's title", "inferred"))
        if s in ("question", "waiting"):
            return _state("waiting for input", "the agent-waiting plugin's note", "reliable")
        if s == "done":
            return _state("idle", "the agent-waiting plugin's note (its turn done)", "reliable")
        if s == "idle":
            return (_state("idle", "the title's mark (at its prompt)", "reliable") if agent.get("agent") == "claude"
                    else _state("idle", "the title's mark", "inferred"))
        if s == "working":
            return _state("running", "the title's turning mark", "inferred")
        if s == "running":
            return _state("running", "a process in the terminal, no mark", "inferred")
        return _state("unknown", "a state this reading doesn't know" + (f": {s}" if s else ""), "unknown")
    launch = task.get("launch") or {}
    if not launch:
        return _state("unknown", "no launch recorded (an agent the office never started, or a record from before)", "unknown")
    last = (task.get("launches") or [launch])[-1]
    if last.get("ended"):
        code = last.get("code")
        if code is not None:
            return _state("failed" if code else "exited", "the launcher's exit line", "reliable", code=code)
        left = last.get("left") or ""
        return _state("exited", f"the hook's note of how it left: {left}" if left else "the process gone", "reliable" if left else "inferred")
    if now - int(launch.get("at") or 0) < FAILED_WITHIN:
        return _state("failed", "the process gone within a minute of its launch", "inferred")
    return _state("exited", "the process gone", "inferred")


# --- Older records, adopted --------------------------------------------------------------

def _desk_mark(did, live_id=None, history=None):
    """The desk record DID's task.id and its history entries' task_id
    written, under the record's lock, and nothing else touched (updated,
    closed and the rest stay as they are: adoption rewrites no record).
    HISTORY maps the entry's index to its task id."""
    H = handoff_module()
    p = H.record_path(did)
    os.makedirs(H.DESKS, exist_ok=True)
    with open(p + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(p) as f:
                rec = json.load(f)
        except (OSError, ValueError):
            return False
        if live_id and isinstance(rec.get("task"), dict) and rec["task"]:
            rec["task"]["id"] = live_id
        for i, tid in (history or {}).items():
            try:
                rec["workers"][i]["task_id"] = tid
            except (IndexError, KeyError, TypeError):
                pass
        tmp = f"{p}.{os.getpid()}.tmp"
        with open(tmp, "w") as f:
            json.dump(rec, f, indent=1, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, p)
    return True


def _adopt_status(status, closed_by, closed):
    """The task's state for a handoff STATUS of a record from before, on a
    desk closed by CLOSED_BY (release, user, '' for open): the table's
    reading; completed for a desk the release closed when the agent said
    finished or review; cancelled for none on a closed desk. (state, what
    wasn't known)."""
    unknown = []
    if closed:
        if closed_by == "release" and status in ("finished", "review", "working", "waiting", "parked", ""):
            return "completed", (["the status at the end: none written"] if not status else [])
        if status in ("finished", "review"):
            return "completed", []
        unknown.append("how the desk closed: the status read as cancelled")
        return "cancelled", unknown
    if not status:
        return None, ["the status: none written"]
    return HANDOFF_TO.get(status, "ready"), []


def adopt(records, by="vikix"):
    """A task record for each desk record's task and for each entry of its
    workers history that has none yet (RECORDS: lib/handoff.py's, as
    all_records gives them), with what the record knew: created from the
    task's at, done from the entry's ended or the desk's closed, origin
    user when by is user, else unknown with who; launch from the record's
    last launch for the live task, with no number; priority normal; the
    status by _adopt_status. What isn't known is null, said in the event
    adopted. Nothing is invented, and the desk record is rewritten in no
    other field than the ids. The task ids made."""
    H = handoff_module()
    made = []
    # What is adopted already, by the desk, the time and the words: a record
    # whose ids couldn't be written back (unreadable, or not a file at all)
    # is never adopted twice.
    have = {((t.get("desk") or {}).get("id"), t.get("created"), t.get("text")) for t in all_tasks()}
    for rec in records or []:
        d = rec.get("desk") or {}
        did = d.get("id")
        if not did or not H.DESK_ID.match(did):
            continue
        closed = int(d.get("closed") or 0)
        closed_by = ""
        if closed:
            for line in reversed(rec.get("log") or []):
                if isinstance(line, dict) and line.get("what") == "desk closed":
                    closed_by = str(line.get("by") or "")
                    break
        desk = {"id": did, "worktree": d.get("worktree", ""), "branch": d.get("branch", "")}
        live_id, history = None, {}
        t = rec.get("task") or {}
        if t and t.get("text") and not t.get("id") and (did, int(t.get("at") or rec.get("updated") or 0), t.get("text")) not in have:
            h = rec.get("handoff") or {}
            status = (h.get("status") or {}).get("value", "")
            state, unknown = _adopt_status(status, closed_by, closed)
            launch = rec.get("launch") or {}
            if launch and int(launch.get("at") or 0) < int(t.get("at") or 0):
                launch = {}
            if state is None:
                state = "running" if launch and not rec.get("left") else "ready"
            tid = _adopt_one(rec, t.get("text"), t.get("by", ""), t.get("at"), desk, state, launch, h,
                             done=closed or None, left=rec.get("left") or {}, unknown=unknown, by=by,
                             activity=rec.get("updated"))
            made.append(tid)
            live_id = tid
        for i, w in enumerate(rec.get("workers") or []):
            if not isinstance(w, dict) or not w.get("task") or w.get("task_id"):
                continue
            if (did, int(w.get("at") or rec.get("updated") or 0), w.get("task")) in have:
                continue
            status = w.get("status") or ""
            state, unknown = _adopt_status(status, closed_by, closed)
            if state is None:
                state = "cancelled"
                unknown = ["the status at its end: none written, read as cancelled"]
            tid = _adopt_one(rec, w["task"], w.get("by", ""), w.get("at"), desk, state, {}, w.get("handoff") or {},
                             done=w.get("ended"), left={"reason": w.get("left")} if w.get("left") else {},
                             unknown=unknown + ["its launch: a worker from before the launches were kept"], by=by,
                             provider=w.get("provider", ""), activity=w.get("ended"))
            made.append(tid)
            history[i] = tid
        if live_id or history:
            try:
                _desk_mark(did, live_id, history)
            except OSError:
                pass
    return made


def _adopt_one(drec, text, who, at, desk, state, launch, handoff, done=None, left=None, unknown=(), by="vikix",
               provider="", activity=None):
    """One task record from what a desk record held; its id."""
    try:
        text = clean(text, "the task")
    except TaskError:
        text = "(a task whose words look like a credential, withheld)"
        unknown = list(unknown) + ["its words"]
    at = int(at or drec.get("updated") or now_s())
    who = word(who or "", "who", 60) or "?"
    kind = "user" if who == "user" else "unknown"
    unknown = list(unknown) + ["its launch order"] + ([] if kind == "user" else [f"its origin: set by {who}"])
    rec = {"version": VERSION, "id": new_id(at), "title": title_of(text), "text": text,
           "project": word((drec.get("desk") or {}).get("project") or "", "the project", 120), "desk": dict(desk), "topic": "",
           "origin": {"kind": kind, "by": who, "parent": None, "worker": None, "source": "",
                      "approved": {"by": who, "at": at} if kind == "user" else None},
           "priority": "normal", "status": {"value": state, "by": by, "at": at, "reason": "adopted from the desk's record"},
           "blocked": {}, "after": [], "worker": worker_choices({"use": provider or launch.get("provider", ""), "mode": launch.get("mode", "")}),
           "launch": {}, "launches": [], "created": at, "queued": None, "launched": None, "activity": int(activity or at),
           "done": int(done) if done and state in FINAL else None,
           "handoff": copy.deepcopy(handoff or {}), "decisions": [], "children": [], "log": []}
    if launch:
        rec["launch"] = {"seq": None, "at": int(launch.get("at") or 0) or None, "by": word(launch.get("by") or "", "who", 60),
                         "provider": word(launch.get("provider") or "", "the provider", 40), "pid": None, "start": "",
                         "mode": word(launch.get("mode") or "", "the mode", 40), "how": "adopted"}
        rec["launched"] = rec["launch"]["at"]
        if left:
            rec["launch"]["ended"] = int(left.get("at") or 0) or None
        rec["launches"] = [dict(rec["launch"], ended=rec["launch"].get("ended"), code=None, left=word(left.get("reason") or "", "how it left", 60) if left else "")]
    else:
        unknown.append("when it was launched")
    if state == "blocked":
        rec["blocked"] = {"on": "parked", "why": "the desk's handoff said parked"}
    _log(rec, by, "adopted from the desk's record; unknown: " + "; ".join(unknown))
    os.makedirs(TASKS, exist_ok=True)
    with open(path(rec["id"]) + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        write(rec)
    event("adopted", by, rec, data={"status": state, "unknown": unknown, "title": rec["title"][:120]})
    return rec["id"]


def needs_adoption(records):
    """Whether any of RECORDS still holds a task, or a history entry, with
    no task id: what the snapshot asks before adopting."""
    for rec in records or []:
        t = rec.get("task") or {}
        if t and t.get("text") and not t.get("id"):
            return True
        if any(isinstance(w, dict) and w.get("task") and not w.get("task_id") for w in rec.get("workers") or []):
            return True
    return False


# --- The desk's task ---------------------------------------------------------------------

def desk_task(drec):
    """The task record a desk record DREC points at (task.id), or None."""
    tid = ((drec or {}).get("task") or {}).get("id")
    return load(tid) if task_id_ok(tid or "") else None


def tasks_of_desk(did, open_only=False):
    """Every task of the desk DID, newest first; OPEN_ONLY the ones not final."""
    return [t for t in all_tasks() if (t.get("desk") or {}).get("id") == did
            and (not open_only or (t.get("status") or {}).get("value") not in FINAL)]


def released(common, folder, version, by="release"):
    """The desk (COMMON, FOLDER) released as VERSION (.claude/release): every
    task of the desk not final gets the event released and is completed,
    since the branch is on main whatever the record said. The ids done."""
    by = word(by, "who", 60)
    H = handoff_module()
    did = H.desk_id(common, folder)
    done = []
    for t in tasks_of_desk(did, open_only=True):
        try:
            event("released", by, t, data={"version": version or ""})
            move(t["id"], "completed", by, f"released{' as ' + version if version else ''}", kind="completed",
                 data={"version": version or ""}, done=True)
            done.append(t["id"])
        except TaskError:
            continue
    return done


# --- The record as a page -------------------------------------------------------------------

def when(ts):
    return handoff_module().when(ts) if ts else "unknown"


def origin_words(rec):
    """The origin in the row's words: yours; proposed by claude #104;
    made by claude 48213 under t-…; by the tester; unknown (set by …)."""
    o = rec.get("origin") or {}
    kind, who = o.get("kind", "unknown"), o.get("by") or "?"
    if kind == "user":
        return "yours"
    if kind == "agent":
        seq = o.get("worker")
        return f"proposed by {who}" + (f" #{seq}" if seq else "") + (f" under {o['parent']}" if o.get("parent") else "")
    if kind == "automation":
        return f"by {o.get('source') or 'an automation'}"
    return f"unknown (set by {who})"


def launch_words(rec):
    """The last launch in a few words: #104 claude · 35 min ago; launch
    order unknown; not launched."""
    H = handoff_module()
    launch = rec.get("launch") or {}
    if not launch:
        return "not launched"
    seq = launch.get("seq")
    head = f"#{seq}" if seq else "launch order unknown"
    return (head + (f" {launch['provider']}" if launch.get("provider") else "") + f" · {H.when(launch.get('at') or 0)}"
            + (f" · by {launch['by']}" if launch.get("by") else "") + (" · ended" if launch.get("ended") else ""))


def row_words(rec, worker=None):
    """One line for the list: #104  running  vikix/wifi-fix  claude  the
    title  [id]; the worker's state after the task's when given."""
    H = handoff_module()
    launch = rec.get("launch") or {}
    seq = f"#{launch['seq']}" if launch.get("seq") else "#?"
    d = rec.get("desk") or {}
    place = (f"{rec.get('project') or '?'}/{d.get('branch') or os.path.basename(d.get('worktree') or '') or '?'}" if d
             else f"{rec.get('project') or '?'}, no desk" + (f" (topic {rec['topic']})" if rec.get("topic") else ""))
    status = (rec.get("status") or {}).get("value", "?")
    return (f"{seq:<6} {status:<18} {place:<32} {launch.get('provider') or rec.get('worker', {}).get('use') or '?':<8} "
            f"{rec.get('priority', 'normal'):<8} {H.when(rec.get('activity') or 0):<16} {rec.get('title', '')}  [{rec['id']}]"
            + (f"\n       worker: {worker['state']} ({worker['sure']}: {worker['source']})" if worker else ""))


def render(rec, events=(), worker=None):
    """The task as a page for a person: its metadata, its text, the
    handoff's copy, the launches, the worker's state when given, and its
    history (EVENTS, newest first)."""
    H = handoff_module()
    s = rec.get("status") or {}
    d = rec.get("desk") or {}
    lines = [f"Task {rec['id']}: {rec.get('title', '')}",
             f"Status: {s.get('value', '?')} ({s.get('by', '?')}, {H.when(s.get('at') or 0)})" + (f": {s['reason']}" if s.get("reason") else "")]
    b = rec.get("blocked") or {}
    if b:
        lines.append(f"Blocked on {b.get('on') or '?'}" + (f": {b['why']}" if b.get("why") else ""))
    o = rec.get("origin") or {}
    lines.append(f"Origin: {origin_words(rec)}" + (f"; approved by {o['approved']['by']} {H.when(o['approved']['at'])}"
                                                  if o.get("approved") and o["kind"] != "user" else ""))
    lines.append(f"Priority: {rec.get('priority', 'normal')}")
    lines.append(f"Project: {rec.get('project') or 'unknown'}")
    if d:
        lines.append(f"Desk: {H.short(d.get('worktree') or '?')}" + (f" (branch {d['branch']})" if d.get("branch") else "") + f"  [{d.get('id', '?')}]")
    else:
        lines.append("Desk: none" + (f" (the desk to make: {rec['topic']})" if rec.get("topic") else ""))
    if rec.get("after"):
        lines.append("After: " + ", ".join(rec["after"]))
    lines.append(f"Launch: {launch_words(rec)}")
    w = rec.get("worker") or {}
    if any(w.values()):
        lines.append("Worker's choices: " + ", ".join(x for x in (w.get("use") and f"use {w['use']}", w.get("local") and "local",
                                                                   w.get("push") and "may push", w.get("no_tests") and "no tests by themselves",
                                                                   w.get("mode") and f"mode {w['mode']}") if x))
    if worker:
        lines.append(f"Worker now: {worker['state']} ({worker['sure']}: {worker['source']})")
    lines.append("Created: " + when(rec.get("created")) + "; queued: " + when(rec.get("queued")) + "; launched: " + when(rec.get("launched"))
                 + "; last activity: " + when(rec.get("activity")) + "; done: " + when(rec.get("done")))
    lines.append("Text:")
    lines += ["  " + line for line in (rec.get("text") or "").splitlines()]
    h = rec.get("handoff") or {}
    hs = h.get("status")
    if hs or h.get("summary") or h.get("next"):
        lines.append("Handoff (the agent's words, as the desk's record had them at the last write):")
        if hs:
            lines.append(f"  status {hs.get('value', '?')} ({hs.get('by', '?')}, {H.when(hs.get('at') or 0)})")
        for key, label in (("summary", "done and decided"), ("next", "left to do, next")):
            v = h.get(key)
            if v:
                lines.append(f"  {label} ({v.get('by', '?')}): {(v.get('text') or '').splitlines()[0] if v.get('text') else ''}")
    launches = rec.get("launches") or []
    if launches:
        lines.append(f"Launches: {len(launches)}")
        for l in launches[-10:][::-1]:
            lines.append(f"  {'#' + str(l['seq']) if l.get('seq') else 'no number'}  {l.get('provider') or '?'}  {H.when(l.get('at') or 0)}"
                         + (f"  by {l['by']}" if l.get("by") else "") + (f"  ({l['how']})" if l.get("how") else "")
                         + (f"  ended {H.when(l['ended'])}" + (f", exit {l['code']}" if l.get("code") is not None else "")
                            + (f", {l['left']}" if l.get("left") else "") if l.get("ended") else "  not ended"))
    if events:
        lines.append(f"History ({len(events)} events, newest first; vikix agents events {rec['id']} has them all):")
        for e in events:
            lines.append("  " + event_line(e))
    return "\n".join(lines)


def event_line(e):
    """One event as a line: 10:12 (2026-10-13)  launched #104  by user  claude, worker."""
    H = handoff_module()
    data = e.get("data") or {}
    words = []
    for k in ("status", "provider", "how", "from", "to", "on", "reason", "code", "version", "ok", "name", "task", "unknown", "title"):
        v = data.get(k)
        if v in (None, "", [], False) and not (k == "ok" and v is False) and not (k == "code" and v == 0):
            continue
        if k == "from" and data.get("to"):
            words.append(f"{v} -> {data['to']}")
        elif k == "to" and data.get("from"):
            continue
        elif k == "unknown":
            words.append("unknown: " + "; ".join(str(x) for x in v))
        elif k == "ok":
            words.append("passed" if v else "failed")
        else:
            words.append(f"{k} {str(v)[:80]}")
    return (f"{time.strftime('%Y-%m-%d %H:%M', time.localtime(e.get('at') or 0))}  {e.get('kind', '?')}"
            + (f" #{e['seq']}" if e.get("seq") else "") + f"  by {e.get('by') or '?'}" + ("  " + ", ".join(words) if words else "")
            + (f"  [{e['task']}]" if e.get("task") and not words else ""))


# Decisions belong to a task, not a process: a restarted worker reads the
# same answer. Task locks serialize the ten-open limit; decision locks
# serialize answers and their delivery. Readers see only complete files.
DECISION_ID = re.compile(r"^d-\d{8}-[0-9a-f]{6}$")


def decision_path(did):
    if not isinstance(did, str) or not DECISION_ID.fullmatch(did):
        raise TaskError("a decision id is d-YYYYMMDD-xxxxxx")
    return os.path.join(OFFICE, "decisions", did + ".json")


def decision(did):
    try:
        with open(decision_path(did)) as f:
            return json.load(f)
    except FileNotFoundError:
        raise TaskError(f"no decision {did}") from None


def decisions(tid=None, open_only=False):
    folder = os.path.join(OFFICE, "decisions")
    try:
        names = os.listdir(folder)
    except FileNotFoundError:
        return []
    rows = [decision(n[:-5]) for n in sorted(names) if n.endswith('.json') and DECISION_ID.fullmatch(n[:-5])]
    return [d for d in rows if (tid is None or d['task'] == tid) and (not open_only or not d.get('answer'))]


def decision_write(d):
    p = decision_path(d['id'])
    os.makedirs(os.path.dirname(p), mode=0o700, exist_ok=True)
    tmp = p + f'.{os.getpid()}.tmp'
    with open(tmp, 'w') as f:
        os.chmod(tmp, 0o600)
        json.dump(d, f, ensure_ascii=False)
        f.write('\n')
    os.replace(tmp, p)


def ask(tid, question, by, choices=None, recommended='', context='', reason='', blocks=False):
    question, by = clean(question, 'question'), word(by, 'who', 60)
    if not question.strip():
        raise TaskError('a decision needs a question')
    if not isinstance(blocks, bool):
        raise TaskError('blocks is true or false')
    if choices is None:
        choices = []
    if not isinstance(choices, list) or len(choices) > 10:
        raise TaskError('choices is a list of at most ten choices')
    parsed = []
    for c in choices:
        if not isinstance(c, dict) or set(c) - {'label', 'consequence'}:
            raise TaskError('each choice has label and consequence only')
        label = word(c.get('label', ''), 'choice label', 80)
        if not label or label in [p['label'] for p in parsed]:
            raise TaskError('choice labels must be nonempty and distinct')
        parsed.append({'label': label, 'consequence': clean(c.get('consequence', ''), 'consequence')})
    recommended = word(recommended, 'recommended choice', 80)
    if recommended and recommended not in [c['label'] for c in parsed]:
        raise TaskError('recommend one of the choice labels')
    context, reason = clean(context, 'context'), clean(reason, 'recommendation reason')
    d = {'version': 1, 'id': 'd-' + time.strftime('%Y%m%d') + '-' + os.urandom(3).hex(),
         'task': tid, 'by': by, 'question': question, 'choices': parsed, 'recommended': recommended,
         'context': context, 'reason': reason, 'blocks': blocks, 'at': now_s(), 'answer': None}

    def change(t):
        if t['status']['value'] in FINAL:
            raise TaskError('a completed or cancelled task cannot ask a decision')
        if len(decisions(tid, open_only=True)) >= 10:
            raise TaskError('ten decisions already open for this task')
        d['desk'] = dict(t.get('desk') or {})
        if not d['desk'].get('id'):
            raise TaskError('the task needs a desk for its answer')
        if blocks and t['status']['value'] in ('running', 'needs review', 'ready for release'):
            _move(t, 'needs decision', by, question)
        while os.path.exists(decision_path(d['id'])):
            d['id'] = 'd-' + time.strftime('%Y%m%d') + '-' + os.urandom(3).hex()
        decision_write(d)
        t.setdefault('decisions', []).append(d['id'])
        _log(t, by, 'asked ' + d['id'])
    update(tid, change)
    event('asked', by, load(tid), data={'decision': d['id']})
    return d


def answer(did, text, by='user'):
    # There is deliberately no MCP answer tool. The CLI and Office also
    # check their caller; this check keeps the model's API honest.
    if by != 'user':
        raise TaskError('only the user answers a decision')
    text = clean(text, 'answer').strip()
    if not text:
        raise TaskError('an answer needs words')
    p = decision_path(did)
    with open(p + '.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        d = decision(did)
        if d.get('answer'):
            if d['answer']['text'] != text:
                raise TaskError('this decision already has an answer')
            if d['answer'].get('applied'):
                return d
        else:
            d['answer'] = {'text': text, 'choice': text if text in [c['label'] for c in d['choices']] else None,
                       'by': by, 'at': now_s(), 'delivered': None}
        decision_write(d)
        # The answer is a durable inbox item in the decision itself. The
        # inbox reader consumes it under this lock; no two-file delivery
        # transaction can lose or duplicate a queued answer after a crash.
        def change(t):
            others = [x for x in decisions(t['id'], open_only=True) if x['blocks']]
            if d['blocks'] and not others and t['status']['value'] == 'needs decision':
                _move(t, 'running', by, 'decision answered')
            _log(t, by, 'answered ' + did)
        update(d['task'], change)
        d['answer']['applied'] = now_s()
        decision_write(d)
        event('answered', by, load(d['task']), data={'decision': did})
        return d


def decision_notes(desk, take=False, tid=None):
    """Pending answers, as inbox notes; TAKE acknowledges under a lock.
    The answer stays on the decision for resume and hook-less providers."""
    notes = []
    for old in decisions(tid):
        if old.get('desk', {}).get('id') != desk or not old.get('answer') or old['answer'].get('delivered'):
            continue
        with (open(decision_path(old['id']) + '.lock', 'a') if take else nullcontext()) as lock:
            if take:
                fcntl.flock(lock, fcntl.LOCK_EX)
            d = decision(old['id'])
            a = d['answer']
            if a.get('delivered'):
                continue
            notes.append({'at': a['at'], 'by': 'user', 'decision': d['id'],
                          'text': f"[decision {d['id']} answered by user: {a['text']}]"})
            if take:
                a['delivered'] = now_s()
                decision_write(d)
    return notes


def decision_words(d):
    out = [f"{d['id']}: {d['question']}"]
    if d.get('context'):
        out.append('  Context: ' + d['context'])
    for c in d['choices']:
        out.append('  ' + c['label'] + ': ' + c['consequence'])
    if d.get('recommended'):
        out.append('  Recommended: ' + d['recommended'] + (' — ' + d['reason'] if d.get('reason') else ''))
    out.append('  Answer: ' + d['answer']['text'] if d.get('answer') else '  Waiting for the user' + (' (blocks the task)' if d['blocks'] else ''))
    return '\n'.join(out)

if __name__ == "__main__":
    # For .claude/release, which has no desk of its own to speak from:
    #   python3 lib/tasks.py released COMMON FOLDER VERSION
    # completes every open task of the desk (COMMON, FOLDER) with the event
    # released; exits 0, 1 when the desk has no open task.
    if len(sys.argv) >= 4 and sys.argv[1] == "released":
        sys.exit(0 if released(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "") else 1)
    sys.stderr.write("usage: python3 tasks.py released COMMON FOLDER [VERSION]\n")
    sys.exit(2)
