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
            finished), an estimate of how long the work will take, barring
            a major issue, an account of what it changed and decided, what
            is left and the next action ("by": the agent, as "claude 48213")
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
PROVIDERS = ("claude", "codex", "opencode", "gemini", "antigravity", "aider", "other")
TEXT_MAX = 4000
LOG_MAX = 40
CHECKS_MAX = 20
SESSIONS_MAX = 10

# What never goes into a record: a key, a token, a password, in any field.
SECRET = re.compile(r"(sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}"
                    r"|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----"
                    r"|\b[A-Z_]*(API_KEY|SECRET|TOKEN|PASSWORD|PASSWD)\s*[=:]\s*\S{6,})")
SESSION_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{3,99}$")
ESTIMATE_MAX = 300
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


def set_handoff(rec, by, status=None, summary=None, next_=None, estimate=None):
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
    if not changed:
        raise HandoffError("nothing to set: --status, --summary, --next or --estimate")
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


def close_record(common, folder, by):
    """The record of the desk (COMMON, FOLDER) marked closed, when there is
    one: a desk closed by vikix agents close, or removed by a release. None
    is made for a desk that never had one. True when a record was marked."""
    if not load(desk_id(common, folder)):
        return False
    update(common, folder, lambda rec: mark_closed(rec, by))
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
    next, estimate, check {name, ok, note}, session {provider, id}. Other keys are
    refused, so a typo doesn't go quietly."""
    if not isinstance(data, dict):
        raise HandoffError("the JSON must be an object")
    allowed = {"task", "status", "summary", "next", "estimate", "check", "session"}
    odd = sorted(set(data) - allowed)
    if odd:
        raise HandoffError(f"unknown field{'s' if len(odd) > 1 else ''}: {', '.join(odd)} (the fields: {', '.join(sorted(allowed))})")
    if "task" in data:
        set_task(rec, data["task"], by)
    if any(k in data for k in ("status", "summary", "next", "estimate")):
        set_handoff(rec, by, data.get("status"), data.get("summary"), data.get("next"), data.get("estimate"))
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
    lines.append(f"Task ({t['by']}, {when(t['at'])}): {t['text']}" if t else "Task: none set (vikix agents handoff --task \"...\")")
    h = rec.get("handoff") or {}
    s = h.get("status")
    lines.append(f"Status: {s['value']} ({s['by']}, {when(s['at'])})" if s else "Status: not said")
    gone = rec.get("left") or {}
    if gone.get("reason") and not rec.get("desk", {}).get("closed"):
        n = gone.get("dirty")
        lines.append(f"Left: {gone['reason']} ({gone.get('by', '?')}, {when(gone.get('at', 0))})"
                     + (f", {n} uncommitted then" if n is not None else ""))
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


# --- Resuming a provider's conversation ---------------------------------------------------------
#
# What each provider offers, as its installed help says (claude, codex,
# opencode, checked 2026-10-06) or its documentation (gemini, aider: not
# installed here, so marked unverified):
#   claude    claude --resume ID          ~/.claude/projects/*/ID.jsonl
#   codex     codex resume ID             ~/.codex/sessions/Y/M/D/rollout-*-ID.jsonl
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
        root = os.environ.get("CODEX_HOME") or os.path.join(home(), ".codex")
        hits = glob.glob(os.path.join(root, "sessions", "*", "*", "*", f"rollout-*-{sid}.jsonl"))
        return (True, short(hits[0])) if hits else (False, short(os.path.join(root, "sessions")))
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
            root = os.environ.get("CODEX_HOME") or os.path.join(home(), ".codex")
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


if __name__ == "__main__":
    # For .claude/release, which has no desk of its own to speak from:
    #   python3 lib/handoff.py closed COMMON FOLDER [BY]
    # marks the record of the desk (COMMON, FOLDER) closed, when there is one.
    import sys
    if len(sys.argv) >= 4 and sys.argv[1] == "closed":
        sys.exit(0 if close_record(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "user") else 1)
    sys.stderr.write("usage: python3 handoff.py closed COMMON FOLDER [BY]\n")
    sys.exit(2)
