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
            finished), an account of what it changed and decided, what is
            left and the next action ("by": the agent, as "claude 48213")
  observed  what Vikix read itself: the commit, branch and uncommitted
            files at each write, and for each check the commit it ran on
            and whether the tree was dirty then

A check (tests/run.sh house passed, 14:02, on 3f2a1c, tree dirty) is
stale once the code differs from what it ran on: another commit, or other
uncommitted changes (a fingerprint of the diff). Sessions are the
providers' resumable conversation ids (claude's uuid, codex's thread,
opencode's session), id and provider only: no transcript is copied here,
and no credential is accepted into any field.

Writes take a lock on the record, read, change and replace it atomically,
so two agents updating one desk at once lose nothing. Used by
bin/vikix-agents (the commands) and bin/vikix-mcp (the tools).
"""
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
STATES = ("working", "waiting", "review", "finished")
PROVIDERS = ("claude", "codex", "opencode", "gemini", "aider", "other")
TEXT_MAX = 4000
LOG_MAX = 40
CHECKS_MAX = 20
SESSIONS_MAX = 10

# What never goes into a record: a key, a token, a password, in any field.
SECRET = re.compile(r"(sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}"
                    r"|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----"
                    r"|\b[A-Z_]*(API_KEY|SECRET|TOKEN|PASSWORD|PASSWD)\s*[=:]\s*\S{6,})")
SESSION_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{3,99}$")
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


def all_records():
    """Every record there is, newest change first."""
    out = []
    try:
        names = os.listdir(DESKS)
    except OSError:
        return out
    for name in names:
        if name.endswith(".json") and DESK_ID.match(name[:-5]):
            rec = load(name[:-5])
            if rec:
                out.append(rec)
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
    return rec


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
        diff = git(folder, "diff", "HEAD") or ""
        now["fingerprint"] = hashlib.sha1((status + "\n" + diff).encode(errors="replace")).hexdigest()[:12] if status else ""
    return now


def freshness(check, now):
    """Whether CHECK still speaks for the code as it is NOW: 'fresh', or
    'stale' with why."""
    if not now.get("commit"):
        return "unknown (no repository to compare with)"
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


def set_handoff(rec, by, status=None, summary=None, next_=None):
    h = rec.setdefault("handoff", {})
    changed = []
    if status is not None:
        if status not in STATES:
            raise HandoffError(f"a status is one of {', '.join(STATES)}, not '{status}'")
        h["status"] = {"value": status, "by": by, "at": int(time.time())}
        changed.append(f"status {status}")
    if summary is not None:
        h["summary"] = {"text": clean(summary, "the summary"), "by": by, "at": int(time.time())}
        changed.append("summary")
    if next_ is not None:
        h["next"] = {"text": clean(next_, "the next step"), "by": by, "at": int(time.time())}
        changed.append("next")
    if not changed:
        raise HandoffError("nothing to set: --status, --summary or --next")
    _log(rec, by, ", ".join(changed))


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


def from_json(rec, data, by, folder):
    """DATA, a dict as --from reads it, applied: task, status, summary,
    next, check {name, ok, note}, session {provider, id}. Other keys are
    refused, so a typo doesn't go quietly."""
    if not isinstance(data, dict):
        raise HandoffError("the JSON must be an object")
    allowed = {"task", "status", "summary", "next", "check", "session"}
    odd = sorted(set(data) - allowed)
    if odd:
        raise HandoffError(f"unknown field{'s' if len(odd) > 1 else ''}: {', '.join(odd)} (the fields: {', '.join(sorted(allowed))})")
    if "task" in data:
        set_task(rec, data["task"], by)
    if any(k in data for k in ("status", "summary", "next")):
        set_handoff(rec, by, data.get("status"), data.get("summary"), data.get("next"))
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
    lines.append(f"Task ({t['by']}, {when(t['at'])}): {t['text']}" if t else "Task: none set (vikix agents handoff set --task \"...\")")
    h = rec.get("handoff") or {}
    s = h.get("status")
    lines.append(f"Status: {s['value']} ({s['by']}, {when(s['at'])})" if s else "Status: not said")
    for key, label in (("summary", "Done and decided"), ("next", "Left to do, next")):
        v = h.get(key)
        if v:
            lines.append(f"{label} ({v['by']}, {when(v['at'])}):")
            lines += ["  " + line for line in v["text"].splitlines()]
    checks = rec.get("checks") or []
    if checks:
        lines.append("Checks:")
        for c in checks[-5:][::-1]:
            lines.append(f"  {'passed' if c['ok'] else 'FAILED'}  {c['name']}  ({c['by']}, {when(c['at'])}, on "
                         f"{(c.get('commit') or '?')[:7]}{', tree dirty' if c.get('dirty') else ', clean tree'})"
                         f"  {freshness(c, now)}" + (f"\n    {c['note']}" if c.get("note") else ""))
    else:
        lines.append("Checks: none recorded")
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
