"""The handoff: a desk's task, status, account and checks, kept across sessions
in its record; telling a worker; the handoff's menu and commands; taking a
desk up again (resume).

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import fcntl
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time


# --- The handoff: a desk's task, status, account and checks, kept across sessions ---------------
def inbox_path(folder):
    """The desk's inbox: a line a note, named by the desk's id as its record is
    (STATE is set further down, with the journal's)."""
    H = handoff_module()
    return os.path.join(STATE, "vikix", "office", "inbox", H.desk_id(common_of(folder), folder) + ".jsonl")


def inbox_add(folder, text, by, to=None):
    """TEXT left for the desk's agent, signed BY; for the one agent TO
    ({agent, pid}) when it is for one alone (a dismissal, a handover's
    request: 2026-10-11, "write your handoff, then stop" reached the next
    fresh worker, which obeyed), else for whoever works the desk. Raises
    HandoffError for text a record may not hold (a credential)."""
    H = handoff_module()
    text = H.clean(text, "the note").replace("\n", " ")
    if not text:
        raise H.HandoffError("a note needs words")
    path = inbox_path(folder)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    note = {"at": int(time.time()), "by": by, "text": text}
    if to:
        note["for"], note["pid"] = who(to), to["pid"]
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with open(path, "a") as f:
            f.write(json.dumps(note, ensure_ascii=False) + "\n")


def note_is_for(note, me, started, others):
    """Whether the note is ME's to read: addressed to it, or to nobody and
    the user's, or to nobody and from ME's own time at the desk (STARTED,
    0 when unknown: then every note). None when it is nobody's any more
    (its addressee gone; from before every agent at the desk, OTHERS'
    start times, and not the user's), False when it waits for another."""
    if note.get("for"):
        if me and note["for"] == who(me):
            return True
        return False if alive(note.get("pid", 0)) else None
    if note.get("by") == "user" or not started or note.get("at", 0) >= started:
        return True
    return False if any(t and t <= note.get("at", 0) for t in others) else None


def inbox_read(path):
    notes = []
    try:
        with open(path) as f:
            for line in f:
                try:
                    n = json.loads(line)
                except ValueError:
                    continue
                if isinstance(n, dict) and n.get("text"):
                    notes.append(n)
    except OSError:
        pass
    return notes


def inbox_peek(folder):
    """The notes waiting at the desk, left where they are."""
    return inbox_read(inbox_path(folder)) + decision_inbox(folder)


def inbox_take(folder, me=None):
    """The notes waiting at the desk for the agent ME, taken out of the
    inbox: for the hook, which hands them to the agent. A note for another
    agent stays; one nobody will read (note_is_for) is dropped. Without ME
    every note is taken, as before."""
    path = inbox_path(folder)
    if not os.path.exists(path):
        return decision_inbox(folder, take=True)
    started = started_at(me["pid"]) if me else 0
    others = [started_at(a["pid"]) for a in agents_at(folder) if not me or a["pid"] != me["pid"]] if me else []
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        notes = inbox_read(path)
        mine = [n for n in notes if not me or note_is_for(n, me, started, others)]
        left = [n for n in notes if me and note_is_for(n, me, started, others) is False]
        if len(left) != len(notes):
            with open(path, "w") as f:
                for n in left:
                    f.write(json.dumps(n, ensure_ascii=False) + "\n")
    return mine + decision_inbox(folder, take=True)


def decision_inbox(folder, take=False):
    H = handoff_module()
    did = H.desk_id(common_of(folder), folder)
    rec = H.load(did) or {}
    tid = rec.get('task', {}).get('id')
    return tasks_module().decision_notes(did, take=take, tid=tid) if tid else []


def decisions_at(rec):
    tid = (rec or {}).get('task', {}).get('id')
    return tasks_module().decisions(tid) if tid else []


def note_line(n):
    """A note as the page and resume show it: who, when, for whom when it is for one, the words."""
    H = handoff_module()
    return f"  {n['by']} ({H.when(n['at'])}" + (f", for {n['for']}" if n.get("for") else "") + f"): {n['text']}"


def wake(folder, text, by, what="the note"):
    """A worker at its prompt woken with TEXT as its prompt: a note reaches
    an agent only at a tool call, and one that handed in sits at its prompt
    making none (2026-10-11: a review's findings waited unread). The one
    agent at the desk, at its prompt by the journal (a stop let through,
    nothing since), with a conversation its provider can resume, is asked
    to exit and resumed with TEXT (resume keeps its conversation). (woken,
    what was done or why not, in a line; WHAT names TEXT there)."""
    H = handoff_module()
    there = agents_at(folder)
    if not there:
        return False, f"no agent is at the desk: vikix agents resume reads {what} out when one takes it up"
    states = {a["pid"]: a["state"] for a in journal_states([dict(a, state="running", doing="") for a in there])}
    idle = [a for a in there if states.get(a["pid"]) == "idle"]
    if not idle:
        working = [a for a in there if states.get(a["pid"]) == "working"]
        if working:
            return False, f"{', '.join(who(a) for a in working)} is working: {what} reaches it at its next tool call"
        return False, (f"{', '.join(who(a) for a in there)} may be at its prompt (its state isn't known): it must be "
                       f"woken to read {what}, by you, or vikix agents tell DESK --now once its hook has said")
    if len(there) > 1:
        return False, f"{', '.join(who(a) for a in there)} are at the desk: say which (vikix agents dismiss, then resume)"
    a = idle[0]
    rec = H.load(H.desk_id(common_of(folder), folder)) or {}
    plan = H.resume_plan(rec, a["agent"], folder)
    if plan["mode"] != "resumed":
        return False, (f"{who(a)} is at its prompt and its conversation can't be resumed ({plan['why']}): "
                       f"speak to it, and it reads {what} at its next tool call")
    if not H.first_prompt_args(a["agent"], text):
        return False, f"{who(a)} is at its prompt and {a['agent']} takes no first prompt: speak to it"
    if not os.environ.get("DISPLAY"):
        return False, f"{who(a)} is at its prompt, and there is no desktop here to open its terminal on: speak to it"
    if not signal_agent(a["pid"], signal.SIGTERM):
        return False, f"{who(a)} is at its prompt and couldn't be asked to exit: speak to it"
    for _ in range(25):
        if process_gone(a["pid"]):
            break
        time.sleep(0.2)
    if not process_gone(a["pid"]):
        return False, f"{who(a)} is still exiting: vikix agents resume {desk_name(folder)} --prompt \"...\" once it has gone"
    try:
        desk_record(folder, by=by, change=lambda r: H._log(r, by, f"woken: {who(a)} at its prompt, resumed with {what}"))
    except SystemExit:
        pass
    try:
        resume([folder, "--use", a["agent"], "--prompt", text])
    except SystemExit as e:
        return False, f"{who(a)} was asked to exit, and resuming it failed ({e}): vikix agents resume {desk_name(folder)}"
    return True, f"{who(a)} was at its prompt: its conversation is resumed with {what} as its prompt"


def tell(argv):
    """vikix agents tell DESK "..." [--now] | --menu: a note for the desk's agent."""
    if argv == ["--menu"]:
        folder = pick_desk("A note for", "The desk whose agent gets the note, at its next tool call.")
        if folder is None:
            return 0
        text = rofi("Note", f"For the agent at {short(folder)}: a line of text.")
        if not text:
            return 0
        argv = [folder, text]
    now = "--now" in argv
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) - (1 if now else 0) or len(words) < 2:
        die("vikix agents tell DESK \"the note\" [--now] (DESK as for close: the folder, the topic, the branch, or PROJECT TOPIC)")
    by, me = by_me()
    folder, _ = desk_for(words[:-1], me)
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: no agent can read a note there")
    H = handoff_module()
    if now:
        # An agent at its prompt is woken with the note as its prompt; else the note
        # waits in the inbox as usual, and why is said.
        try:
            H.clean(words[-1], "the note")
        except H.HandoffError as e:
            die(str(e))
        woken, said = wake(folder, words[-1], by)
        if woken:
            say(f"{short(folder)}: {said}")
            return 0
        print(f"{short(folder)}: {said}; the note waits in its inbox")
    try:
        inbox_add(folder, words[-1], by)
    except H.HandoffError as e:
        die(str(e))
    there = [a for a in live_agents() if a["folder"] and os.path.realpath(a["folder"]) == os.path.realpath(folder)]
    said = f"{short(folder)}: noted for its agent"
    if not there:
        said += " (none is there now: vikix agents resume reads it out when one takes the desk up)"
    elif all(a["agent"] not in NOTE_HOOKS for a in there):
        said += (f"; {', '.join(who(a) for a in there)} has no hook that carries a note, so it isn't told: "
                 "vikix agents handoff shows the note, and the agent reads it when it looks there")
    else:
        # What the agent is doing, from the desktop: a note reaches it only at an edit or a
        # command, which an agent at its prompt makes none of until it is spoken to.
        try:
            states = {a["pid"]: a["state"] for a in journal_states(desktop(strict=True))}
        except (RuntimeError, SystemExit):
            states = {}
        state = next((states.get(a["pid"]) for a in there if a["agent"] == "claude" and states.get(a["pid"])), "")
        if state in ("idle", "done"):
            said += "; its agent is at its prompt: it reads this when you next ask it something"
        elif state == "asks":
            said += "; its agent is waiting for you: answer it, and it reads this at its next tool call"
        else:
            said += ", delivered at its next tool call"
    say(said)
    return 0


def status_told(folder, before, rec, by):
    """The user told, on the desktop, when an agent's status comes to
    review, waiting or finished: the report of a worker. Never for the
    user's own change, or a status that stayed."""
    status = ((rec.get("handoff") or {}).get("status") or {}).get("value")
    if by == "user" or status == before or status not in ("review", "waiting", "finished"):
        return
    if not os.environ.get("DISPLAY") or not shutil.which("notify-send"):
        return
    h = rec.get("handoff") or {}
    said = {"review": "ready for review", "waiting": "waiting for you", "finished": "finished"}[status]
    body = ((h.get("next") or h.get("summary") or {}).get("text") or "").replace("\n", " ")[:200]
    T = tasks_module()
    tid = rec.get('task', {}).get('id')
    task = T.load(tid) if tid else None
    if status == 'waiting' and tid and T.decisions(tid, open_only=True):
        return
    kind = {'review': 'review', 'waiting': 'question', 'finished': 'release'}[status]
    since = (task or {}).get('status', {}).get('at') or h.get('status', {}).get('at')
    sys.path.insert(0, os.path.join(VIKIX_DIR, 'lib'))
    import office as office_view
    office_view.notify_attention([{'id': f"{kind}:{tid or folder}:{since or 'unknown'}", 'kind': kind,
                                   'notification_title': f"Agent at {short(folder)}: {said}",
                                   'why': body or f"by {by}"}], T.OFFICE)


def base_of(folder):
    """Where the desk's branch left the project's own: (merge base, the
    project's own folder, its branch). What the hand-in's changes and the
    tester's --changed are counted from."""
    top = (git(folder, "rev-parse", "--show-toplevel") or "").strip()
    own = own_folder(top) if top else ""
    own_branch = (git(own, "rev-parse", "--abbrev-ref", "HEAD") or "").strip() if own else ""
    base = (git(folder, "merge-base", "HEAD", own_branch) or "").strip() if own_branch and own_branch != "HEAD" else ""
    return base, own, own_branch


def handoff_apply(folder, data, by):
    """DATA (the fields --from takes) applied to the desk's record, signed
    BY, the user told of a status worth telling; what changed against the
    base and the commits read from git into it (set_changes), signed vikix;
    raises HandoffError."""
    H = handoff_module()
    common = common_of(folder)
    seen = {}
    base = base_of(folder)[0] if common else ""

    def change(rec):
        seen["before"] = ((rec.get("handoff") or {}).get("status") or {}).get("value")
        H.from_json(rec, data, by, folder)
        H.set_changes(rec, folder, base)
        if "task" in data:
            seen["new"] = not (rec.get("task") or {}).get("id")
            task_make(rec, folder, data["task"], by)
    rec = H.update(common, folder, change, branch=(git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip(),
                   project=project_of(folder, common))
    task_moved(folder, rec, data, by, seen.get("new"))
    status_told(folder, seen.get("before"), rec, by)
    status = ((rec.get("handoff") or {}).get("status") or {}).get("value")
    if (status == "review" and seen.get("before") != "review" and os.environ.get("VIKIX_TESTER") != "0"
            and rec["desk"].get("tests") != "off" and runner_of(folder)[1] and not tester_running(folder)):
        tester_start(folder)
    if status == "review" and seen.get("before") != "review":
        # A review by the provider the office file names (review=codex), when it does: off by default.
        provider = review_auto(folder)
        if provider and reviewer_program(provider) and not reviewer_running(folder):
            review_start(folder, provider)
    return rec


def task_moved(folder, rec, data, by, new=False):
    """The desk's task (lib/tasks.py) after a write of the handoff: a task
    just made by --task at a desk with an agent at it runs, with no launch
    number (the office never started that agent); a status given moves the
    task through the table (working: running, waiting: needs decision,
    review: needs review, finished: ready for release, parked: blocked), the
    handoff copied into the task; any other field copies the handoff alone."""
    tid = (rec.get("task") or {}).get("id")
    if not tid:
        return
    T = tasks_module()
    if new:
        at = agents_at(folder)
        if at:
            task_launch(tid, at[0]["agent"], by, "handoff --task", numbered=False)
    try:
        if "status" in data:
            T.handoff_move(tid, data["status"], by, rec.get("handoff") or {})
        elif any(k in data for k in ("summary", "next", "estimate", "acceptance", "done", "defect", "defect_done",
                                     "review", "review_done", "decided")):
            T.set_handoff(tid, rec.get("handoff") or {}, by)
    except (T.TaskError, OSError) as e:
        sys.stderr.write(f"the task {tid} wasn't moved: {e}\n")


def stopping(argv):
    """Claude Code's and Codex's Stop hook (config/claude/office.json,
    config/codex/hooks.json): a worker, an agent at a desk with a task,
    that changed files in this turn and hasn't written its handoff since
    is asked once to write it before it stops; the stop after that is let
    go (stop_hook_active), so nothing goes round. An agent at a desk with
    no task (a session started by hand, or seated from inside) is asked
    the same way until its record has a status, and then no more: it is a
    conversation, held only to leave one line behind it (2026-10-10: half
    the records had none, since nothing ever asked). An agent off a desk is
    never held to it. A stop let through is noted in the journal (kind
    stop), which is how the listing says "at its prompt" for an agent whose
    title says nothing; for Codex the agent-waiting plugin's note is
    written here too (done, with its last words), as Claude Code's own
    Stop hook writes it, so "finished its turn" no longer waits for
    Codex's notify setting."""
    hook_for(argv)
    got, raw = hook_input()
    me = my_agent()
    if HOOK == "codex" and me:
        plugin_note("done", raw)
    reason = stop_reason(got, me)
    last_words = got.get('last_assistant_message') or ''
    if reason and isinstance(last_words, str) and last_words.rstrip().endswith('?'):
        reason += ' Register a question the user must answer with vikix agents ask (or decide), not only in your last message.'
    if reason:
        print(json.dumps({"decision": "block", "reason": reason}))
    elif me:
        journal_add({"at": int(time.time()), "kind": "stop", "agent": me["agent"], "pid": me["pid"],
                     "folder": me["folder"], "file": ""})
    return 0


def stop_reason(got, me):
    """Why the agent ME may not stop yet, as the words for its next prompt,
    or None: the handoff unwritten after a turn that changed files."""
    if got.get("stop_hook_active") or not me or not me["folder"]:
        return None
    H = handoff_module()
    common = common_of(me["folder"])
    if not desk_of(me["folder"]):
        return None
    rec = H.load(H.desk_id(common, me["folder"])) or {}
    h = rec.get("handoff") or {}
    if not rec.get("task") and h.get("status"):
        return None
    last = H.handoff_written_at(rec)
    edited = {e.get("file") for e in journal_read()
              if e.get("pid") == me["pid"] and e.get("kind") in ("edit", "crossing", "shell") and e.get("at", 0) > last}
    if not edited:
        return None
    try:
        H.update(common, me["folder"], lambda r: H._log(r, "vikix", "asked for the handoff before the agent stopped"))
    except (H.HandoffError, OSError):
        pass
    n = len(edited)
    return (f"Vikix office: this turn changed {n} file{'s' if n != 1 else ''} at your desk and the handoff hasn't been "
            "written since. Write it now, then stop: vikix agents handoff --status working|waiting|review|finished|parked "
            "--summary \"what you changed and decided\" --next \"what is left, the very next action\" (or the MCP tool "
            "handoff_update); review when the work is ready for the user, waiting when you need them.")


# --- The network gone: a turn it ended is taken up again when it is back -----------------------
# Claude Code gives a request up after its own retries and ends the turn with an API error as
# the conversation's last message; its Stop hook doesn't run then (tried 2026-10-14), so the
# office follows the transcript's tail instead: a watcher an agent's hook starts for it.
RECONNECT_POLL = int(os.environ.get("VIKIX_RECONNECT_POLL") or 10)          # seconds between looks
RECONNECT_SETTLE = int(os.environ.get("VIKIX_RECONNECT_SETTLE") or 5)       # seconds a link back is given to settle
RECONNECT_LIMIT = int(os.environ.get("VIKIX_RECONNECT_LIMIT") or 24 * 3600)   # seconds the network is waited for, at most
RECONNECT_DIR = os.path.join(STATE, "vikix", "office", "reconnect")
# The API errors that are the network's (Claude Code's own words), never a login or the credits.
NETWORK_ERROR = re.compile(r"reach the API server|connection (error|lost|refused|reset|closed)|network|EAI_AGAIN|"
                           r"ECONN|ETIMEDOUT|ENETUNREACH|ENOTFOUND|EHOSTUNREACH|fetch failed|socket hang up|timed out", re.I)
NOT_NETWORK = ("authentication_failed", "rate_limit", "invalid_request")
API_HOST = ("api.anthropic.com", 443)


def transcript_tail(path, size=65536):
    """The last entries of a Claude Code transcript (JSON lines), newest
    last: the file's last SIZE bytes read, never the whole conversation."""
    out = []
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            end = f.tell()
            f.seek(max(0, end - size))
            chunk = f.read()
    except OSError:
        return out
    lines = chunk.split(b"\n")
    for line in (lines[1:] if end > size else lines):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if isinstance(e, dict):
            out.append(e)
    return out


def network_stop(path):
    """Whether the conversation at PATH ended with the network gone: the
    last message (the agent's or the user's; the lines after a turn, its
    duration and the snapshots, are no message) is an API error of the
    connection kind. (the error's words, when) or None: a message after it,
    the user's "continue" or the agent going on, is None too."""
    for e in reversed(transcript_tail(path)):
        if e.get("type") not in ("assistant", "user"):
            continue
        m = e.get("message") or {}
        if e.get("type") != "assistant" or not e.get("isApiErrorMessage"):
            return None
        if e.get("error") in NOT_NETWORK:
            return None
        text = " ".join(c.get("text", "") for c in (m.get("content") or []) if isinstance(c, dict)).strip()
        if not NETWORK_ERROR.search(text):
            return None
        stamp = 0
        try:
            from datetime import datetime
            stamp = int(datetime.fromisoformat((e.get("timestamp") or "").replace("Z", "+00:00")).timestamp())
        except ValueError:
            pass
        return text[:300], stamp
    return None


def api_host():
    """The API the agent reaches for: ANTHROPIC_BASE_URL's host when it is
    set, else Anthropic's; VIKIX_API_HOST (host:port) stands in for the tests."""
    standin = os.environ.get("VIKIX_API_HOST")
    if standin and ":" in standin:
        host, port = standin.rsplit(":", 1)
        return host, int(port)
    base = os.environ.get("ANTHROPIC_BASE_URL") or ""
    if base:
        from urllib.parse import urlparse
        u = urlparse(base)
        if u.hostname:
            return u.hostname, u.port or (80 if u.scheme == "http" else 443)
    return API_HOST


def api_reachable(timeout=5):
    """Whether the API's host answers a connection now: a name resolved and
    a socket opened, nothing sent."""
    import socket
    try:
        with socket.create_connection(api_host(), timeout=timeout):
            return True
    except OSError:
        return False


def reconnect_path(pid):
    return os.path.join(RECONNECT_DIR, str(pid) + ".json")


def reconnect_read(pid):
    try:
        with open(reconnect_path(pid)) as f:
            w = json.load(f)
        return w if isinstance(w, dict) else {}
    except (OSError, ValueError):
        return {}


def reconnect_write(pid, w):
    os.makedirs(RECONNECT_DIR, exist_ok=True)
    tmp = reconnect_path(pid) + ".tmp"
    with open(tmp, "w") as f:
        json.dump(w, f)
    os.replace(tmp, reconnect_path(pid))


def reconnect_watcher_alive(w):
    """Whether the watcher W names still runs, and is one."""
    pid = w.get("watcher")
    if not isinstance(pid, int) or process_gone(pid):
        return False
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return b"reconnect" in f.read()
    except OSError:
        return False


def reconnect_watch(got, me):
    """The watcher for the agent ME started from its hook, once: Claude
    Code's hook carries the transcript's path, and a watcher that lives is
    left as it is (one stat). Both hook entries run for an edit, at once,
    so the look and the start are under a lock, and the hook writes the
    watcher's file itself. Only an agent at a desk: the waking goes
    through the desk's record and resume."""
    path = (got or {}).get("transcript_path") or ""
    if HOOK != "claude" or not me or not path or not desk_of(me["folder"]) or os.environ.get("VIKIX_RECONNECT") == "0":
        return
    if os.path.exists(reconnect_path(me["pid"])) and reconnect_read(me["pid"]).get("transcript") == path \
            and reconnect_watcher_alive(reconnect_read(me["pid"])):
        return
    os.makedirs(RECONNECT_DIR, exist_ok=True)
    with open(reconnect_path(me["pid"]) + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        w = reconnect_read(me["pid"])
        if reconnect_watcher_alive(w):
            if w.get("transcript") == path:
                return
            # A new conversation under the same process (/clear): the watcher on the old
            # file is ended, by its pid checked to be one, and one started on the new.
            try:
                os.kill(w["watcher"], signal.SIGTERM)
            except OSError:
                pass
        with open(reconnect_path(me["pid"]) + ".log", "w") as out:
            p = subprocess.Popen([sys.executable, os.path.realpath(__file__), "reconnect", "--watch", me["folder"],
                                  "--pid", str(me["pid"]), "--transcript", path], cwd=me["folder"],
                                 stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
        reconnect_write(me["pid"], {"watcher": p.pid, "agent": me["pid"], "folder": me["folder"], "transcript": path,
                                    "since": int(time.time())})


def reconnect_note_stop(a):
    """The agent A's turn, ended by the network with no Stop hook run,
    noted in the journal as a stop with why, once: the listing says so,
    and wake asks the journal whether it sits at its prompt."""
    last = None
    for e in journal_read():
        if e.get("pid") == a["pid"] and e.get("kind") in ("turn", "edit", "crossing", "shell", "stop"):
            last = e
    if last and last.get("kind") == "stop" and last.get("why") == "network":
        return
    journal_add({"at": int(time.time()), "kind": "stop", "agent": a["agent"], "pid": a["pid"], "folder": a["folder"],
                 "file": "", "why": "network"})


def reconnect_log(folder, by, what):
    try:
        desk_record(folder, by=by, change=lambda r: handoff_module()._log(r, by, what))
    except SystemExit:
        pass


def reconnect_wake(folder, a, path, seen, by="vikix"):
    """The agent A at FOLDER, whose conversation at PATH ended with the
    network gone (SEEN: the error's words, when), woken with the words to
    carry on, as go wakes one whose pause ended its turn: its stop noted
    in the journal first (no Stop hook ran), since wake asks the journal
    whether it sits at its prompt. (woken, what was done, in a line)."""
    words, at_ = seen
    text = (f"Vikix office: your last turn ended {('at ' + at(at_)) if at_ else 'earlier'} because the network was down "
            f"({words}). The network is back ({api_host()[0]} answers again"
            + (f", after {how_long(max(0, int(time.time()) - at_))}" if at_ else "") + "), and this is your conversation "
            "taken up again by Vikix, not a new task: carry on from where you were, on the same task and plan. The reply "
            "that was cut off may be incomplete, so look at your last step and its result before going on. A note from the "
            "user, when there is one, reaches you at your next tool call.")
    reconnect_note_stop(a)
    reconnect_log(folder, by, f"the network was back: {who(a)} stopped by it {('at ' + at(at_)) if at_ else ''}".rstrip())
    woken, how = wake(folder, text, by, what="the words to carry on")
    if not woken and "is working" not in how:
        try:
            inbox_add(folder, text, by)
            how += "; the words to carry on wait in its inbox"
        except handoff_module().HandoffError:
            pass
    return woken, how


def reconnect_transcript(folder, a):
    """The transcript of the agent A at FOLDER: the session its desk's
    record notes for its pid, in Claude Code's store."""
    H = handoff_module()
    if a["agent"] != "claude":
        return ""
    rec = H.load(H.desk_id(common_of(folder), folder)) or {}
    for s in reversed(rec.get("sessions", [])):
        if s.get("provider") == "claude" and s.get("pid") == a["pid"]:
            found, where = H.session_store("claude", s.get("id", ""))
            if found:
                return os.path.expanduser(where)
    return ""


def reconnect_watch_loop(folder, pid, path):
    """The watcher: the transcript's tail looked at every RECONNECT_POLL
    seconds while the agent PID lives (a stat; read when it grew), and
    once it ends with the network gone, the API's host asked for until it
    answers (twice, RECONNECT_SETTLE apart), the transcript looked at again
    (the user may have gone on), and the agent woken. Ends with the agent,
    with the waking (the new process gets a watcher of its own at its
    first call), or at RECONNECT_LIMIT of waiting."""
    a = {"agent": "claude", "pid": pid, "folder": folder}
    w = {"watcher": os.getpid(), "agent": pid, "folder": folder, "transcript": path, "since": int(time.time())}
    was = reconnect_read(pid)
    if was.get("watcher") not in (None, os.getpid()) and reconnect_watcher_alive(was):
        print(f"another watcher ({was['watcher']}) has {who(a)}", flush=True)
        return 0
    reconnect_write(pid, w)
    print(f"watching {who(a)} at {short(folder)}: {short(path)}", flush=True)
    rc = 1
    try:
        rc = reconnect_follow(folder, pid, path, a, w)
    finally:
        # The watcher's file goes with it; its log too after a quiet end, kept when something went wrong.
        for name in (reconnect_path(pid),) + ((reconnect_path(pid) + ".log",) if rc == 0 else ()):
            try:
                os.unlink(name)
            except OSError:
                pass
    return rc


def reconnect_follow(folder, pid, path, a, w):
    last = None
    gone_at = None
    while True:
        if process_gone(pid):
            print(f"{who(a)} has left", flush=True)
            return 0
        try:
            st = os.stat(path)
            mark = (st.st_size, st.st_mtime_ns)
        except OSError:
            mark = None
        if mark != last:
            last = mark
            seen = network_stop(path) if mark else None
            if seen and not gone_at:
                gone_at = int(time.time())
                reconnect_write(pid, dict(w, gone_at=gone_at, error=seen[0]))
                reconnect_note_stop(a)
                print(f"{at(gone_at)}: the network ended its turn ({seen[0]}); waiting for {api_host()[0]}", flush=True)
            elif not seen and gone_at:
                gone_at = None
                reconnect_write(pid, w)
                print(f"{at(int(time.time()))}: the conversation went on by itself", flush=True)
        if gone_at:
            if int(time.time()) - gone_at > RECONNECT_LIMIT:
                print(f"waited {how_long(RECONNECT_LIMIT)}: giving up; vikix agents reconnect {desk_name(folder)} by hand", flush=True)
                reconnect_log(folder, "vikix", f"the network stayed gone {how_long(RECONNECT_LIMIT)}: {who(a)} is left at its prompt")
                return 1
            if api_reachable():
                time.sleep(RECONNECT_SETTLE)
                if api_reachable() and network_stop(path) and not process_gone(pid):
                    woken, how = reconnect_wake(folder, a, path, network_stop(path))
                    print(f"{at(int(time.time()))}: {how}", flush=True)
                    return 0 if woken else 1
        time.sleep(RECONNECT_POLL)


def reconnect(argv):
    """vikix agents reconnect [DESK | --all] [--wait]: an agent whose turn the
    network ended, taken up again; --watch FOLDER --pid N --transcript PATH
    is the watcher the hook starts."""
    if "--watch" in argv:
        i = argv.index("--watch")
        folder = argv[i + 1] if len(argv) > i + 1 else die("--watch FOLDER")
        pid = int(argv[argv.index("--pid") + 1]) if "--pid" in argv and argv[argv.index("--pid") + 1].isdigit() else die("--pid N")
        path = argv[argv.index("--transcript") + 1] if "--transcript" in argv else die("--transcript PATH")
        return reconnect_watch_loop(folder, pid, path)
    wait, every, words = "--wait" in argv, "--all" in argv, [a for a in argv if not a.startswith("-")]
    if any(a.startswith("-") and a not in ("--wait", "--all") for a in argv):
        die("vikix agents reconnect [DESK | --all] [--wait]")
    by, me = by_me()
    if every:
        folders = sorted({os.path.realpath(a["folder"]) for a in live_agents() if a["folder"] and desk_of(a["folder"])})
    else:
        folders = [desk_for(words, me)[0]]
    rc, found = 0, 0
    for folder in folders:
        for a in agents_at(folder):
            path = reconnect_transcript(folder, a)
            if not path:
                print(f"{short(folder)}: {who(a)}: no conversation of its own is noted (a Claude Code at a desk notes one "
                      "at its first tool call): nothing to look at")
                continue
            seen = network_stop(path)
            if not seen:
                print(f"{short(folder)}: {who(a)}: its last turn wasn't ended by the network")
                continue
            found += 1
            print(f"{short(folder)}: {who(a)} was stopped by the network {('at ' + at(seen[1])) if seen[1] else ''}: {seen[0]}")
            waited = 0
            while not api_reachable():
                if not wait:
                    print(f"  {api_host()[0]} doesn't answer yet: its watcher wakes it when it does, or --wait waits here")
                    rc = 1
                    break
                if waited == 0:
                    print(f"  waiting for {api_host()[0]} ...", flush=True)
                time.sleep(RECONNECT_POLL)
                waited += RECONNECT_POLL
                if waited > RECONNECT_LIMIT:
                    die(f"waited {how_long(RECONNECT_LIMIT)} for {api_host()[0]}: giving up")
            else:
                woken, how = reconnect_wake(folder, a, path, seen, by)
                print(f"  {how}")
                rc = rc if woken else 1
    return rc

def note_session(sid):
    """The resumable session id the hook's input carries (Claude Code's
    session_id), noted on the agent's desk once: nothing else of the
    conversation is kept."""
    H = handoff_module()
    if not H.session_id_ok(sid):
        return
    me = my_agent()
    if not me or not desk_of(me["folder"]):
        return
    common = common_of(me["folder"])
    rec = H.load(H.desk_id(common, me["folder"]))
    if rec and any(s["provider"] == me["agent"] and s["id"] == sid and s.get("pid") == me["pid"]
                   for s in rec.get("sessions", [])):
        return
    try:
        H.update(common, me["folder"], lambda r: H.add_session(r, me["agent"], sid, who(me), me["pid"]),
                 branch=(git(me["folder"], "rev-parse", "--abbrev-ref", "HEAD") or "").strip(),
                 project=project_of(me["folder"], common))
    except (H.HandoffError, OSError):
        pass


def protection_lines(folder):
    """What holds the house rules for each agent at the desk: honest about
    what there is. A hook is seen through the journal's proposed edits
    (noted before the edit, so a note is a proposal, not a change made)."""
    lines = []
    here = [a for a in live_agents() if a["folder"] and os.path.realpath(a["folder"]) == os.path.realpath(folder)]
    entries = journal_read()
    # How the last agent was started (the record's launch): a Codex row says its sandbox.
    try:
        H = handoff_module()
        launch = (H.load(H.desk_id(common_of(folder), folder)) or {}).get("launch") or {}
    except Exception:  # noqa: BLE001  a record that can't be read costs the mode's words, not the lines
        launch = {}
    for a in sorted(here, key=lambda a: a["pid"]):
        seen = sum(1 for e in entries if e.get("pid") == a["pid"] and e.get("kind") in ("edit", "crossing"))
        if a["agent"] in ("claude", "antigravity"):
            held = (f"pre-edit and pre-shell hooks (vikix agents touch): {seen} edit{'s' if seen != 1 else ''} proposed "
                    "through them" if seen else "pre-edit hooks expected from vikix agent, none seen yet "
                    "(a session started another way has only the instructions)")
        elif a["agent"] == "codex":
            # Its hooks (config/codex/hooks.json): the edit and command hook, the one on a
            # step out of its sandbox, the turn, the stop and the leaving; seen through
            # the journal as Claude Code's are, else by the file being Vikix's.
            if seen:
                held = (f"its PreToolUse hook (vikix agents touch --for codex): {seen} edit{'s' if seen != 1 else ''} "
                        "proposed through it; its PermissionRequest hook denies a step out of its sandbox into the "
                        "project's own folder, ~/vikix, another desk or secrets/; its Stop hook asks for the handoff")
            elif codex_hook_ours():
                held = ("its hooks installed (~/.codex/hooks.json is Vikix's: edits, commands, steps out of its "
                        "sandbox, turns and stops), none of its edits seen yet (a session started before the install, "
                        "or without the trust, has only the instructions)")
            else:
                held = "instructions only, unless its hook is installed (vikix agents hooks codex --install)"
        elif a["agent"] in ("opencode", "gemini"):
            held = (f"a pre-edit hook: {seen} edit{'s' if seen != 1 else ''} proposed through it" if seen else
                    f"instructions only, unless its hook is installed (vikix agents hooks {a['agent']})")
        else:
            held = "instructions only (no hook)"
        if a["agent"] == "codex" and launch.get("provider") == "codex" and launch.get("mode"):
            held += ("; no sandbox: unrestricted, by the user" if launch["mode"] == "unrestricted"
                     else f"; sandboxed to its desk (codex, {launch['mode']})")
        lines.append(f"{who(a)}: {held}")
    lines.append("no filesystem enforcement by Vikix: a worktree keeps copies apart, it is no sandbox"
                 + ("; Codex's own sandbox, narrowed to the desk by its mode, is the one there is"
                    if any(a["agent"] == "codex" for a in here) and launch.get("mode") in ("supervised", "autonomous") else ""))
    return here, lines


def handoff_menu():
    """From Super+m: pick a desk with a record, and read it in a terminal."""
    H = handoff_module()
    recs = H.all_records()
    if not recs:
        die("no desk has a handoff yet (vikix agents desk PROJECT TOPIC --task \"...\" starts one)")
    lines = [f"{short(r['desk']['worktree'])}  {((r.get('handoff') or {}).get('status') or {}).get('value', 'no status')}"
             f"  {(r.get('task') or {}).get('text', '')[:60]}" for r in recs]
    picked = rofi("Handoff of", "A desk's task, what the agent did and left, and its checks.", lines)
    if picked is None or not picked.isdigit():
        return 0
    did = recs[int(picked)]["desk"]["id"]
    term = os.environ.get("VIKIX_TERMINAL") or "alacritty"
    if not shutil.which(term):
        die(f"no terminal: {term} isn't installed")
    me = os.path.join(VIKIX_DIR, "bin", "vikix-agents")
    subprocess.Popen([term, "--title", "Handoff", "-e", "bash", "-c",
                      f"python3 {shlex.quote(me)} handoff {did}; echo; read -r -p 'Enter closes this window. ' _"],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 0


def handoff(argv):
    H = handoff_module()
    if argv == ["--menu"]:
        return handoff_menu()
    verb = argv.pop(0) if argv and argv[0] in ("show", "set", "check", "session", "list", "forget") else "show"
    as_json, desk, words, opts = False, None, [], {}
    # A setting given is a set: "handoff --status working", no verb needed.
    if verb == "show" and any(a in SETTINGS for a in argv):
        verb = "set"
    while argv:
        a = argv.pop(0)
        if a == "--json":
            as_json = True
        elif a == "--desk":
            desk = argv.pop(0).split() if argv else die("--desk which? (vikix agents handoff list)")
        elif a in SETTINGS_MANY:
            opts.setdefault(a, []).append(argv.pop(0) if argv else die(f"{a} needs words"))
        elif a in SETTINGS_NUMBER:
            n = argv.pop(0) if argv else die(f"{a} N: the number of the item, counted from 1")
            opts[a] = int(n) if n.isdigit() else die(f"{a} N: the number of the item, counted from 1, not '{n}'")
        elif a in SETTINGS or a == "--note":
            opts[a] = argv.pop(0) if argv else die(f"{a} needs words")
        elif a in ("--ok", "--failed"):
            opts["ok"] = a == "--ok"
        elif a.startswith("-"):
            die(f"vikix agents handoff: {a}? (vikix agents help)")
        else:
            words.append(a)
    if verb == "list":
        recs = H.all_records()
        if as_json:
            print(json.dumps(recs, indent=1, ensure_ascii=False))
            return 0
        if not recs:
            print("No desk has a record yet: vikix agents desk PROJECT TOPIC makes one, "
                  "vikix agents worker DESK \"...\" starts a worker at it.")
            return 0
        for r in recs:
            d, h = r["desk"], r.get("handoff") or {}
            status = (h.get("status") or {}).get("value", "no status")
            place = short(d["worktree"]) + ("" if os.path.isdir(d["worktree"]) else " (folder gone)")
            est = H.estimate_state(r)
            print(f"  {place}  {status}, {H.when(r['updated'])}: {(r.get('task') or {}).get('text', 'no task')[:80]}"
                  + (f"  ({est['line']})" if est else "")
                  + (f"  [closed {H.when(d['closed'])}]" if d.get("closed") else ""))
        return 0
    if verb == "forget":
        return handoff_forget(desk if desk is not None else words)
    by, me = by_me()
    if verb == "show":
        folder, rec = desk_for(desk if desk is not None else words, me)
        if not rec:
            die(f"{short(folder)} has no record yet: vikix agents handoff --task \"...\" starts one")
        if as_json:
            now = H.observe(folder) if os.path.isdir(folder) else {}
            rec = dict(rec, questions=decisions_at(rec), now=now, checks=[dict(c, freshness=H.freshness(c, now)) for c in rec.get("checks", [])])
            print(json.dumps(rec, indent=1, ensure_ascii=False))
            return 0
        agents_at, lines = protection_lines(folder) if os.path.isdir(folder) else ([], [])
        print(H.render(rec, [who(a) for a in agents_at], lines))
        for d in decisions_at(rec):
            print(tasks_module().decision_words(d))
        notes = inbox_peek(folder)
        if notes:
            print("Notes waiting for its agent (vikix agents tell; delivered at its next tool call):")
            for n in notes:
                print(note_line(n))
        return 0
    # set names its desk as show does, before the settings; check and session
    # take their own words, so for them it is --desk.
    folder, _ = desk_for(desk if desk is not None else (words if verb == "set" else []), me)
    if verb == "set":
        words = []
        data = {}
        if "--from" in opts:
            src = opts["--from"]
            try:
                text = sys.stdin.read() if src == "-" else open(src).read()
                data = json.loads(text or "{}")
            except (OSError, ValueError) as e:
                die(f"--from {src}: {e}")
        for k in SETTINGS:
            if k in opts and k != "--from":
                data[k[2:].replace("-", "_")] = opts[k]
        if not data:
            die("nothing to set: --task, --status (working|waiting|review|finished|parked), --summary, --next, "
                "--estimate, --acceptance, --done N, --defect, --defect-done N, --review, --review-done N, "
                "--decided, or --from")
        try:
            rec = handoff_apply(folder, data, by)
        except H.HandoffError as e:
            die(str(e))
        s = (rec.get("handoff") or {}).get("status")
        est = H.estimate_state(rec) if "estimate" in data else None
        d, n = H.acceptance_count(rec.get("handoff") or {})
        print(f"{short(folder)}: handoff updated by {by}" + (f", status {s['value']}" if s else "")
              + (f", estimate {H.span(est['minutes'])} from now" if est else "")
              + (f", acceptance {d} of {n} done" if n and ("acceptance" in data or "done" in data) else ""))
        return 0
    if verb == "check":
        if not words or "ok" not in opts:
            die("vikix agents handoff check NAME --ok|--failed [--note \"...\"]")
        rec = desk_record(folder, by=by, change=lambda r: H.add_check(r, " ".join(words), opts["ok"], by, folder,
                                                                       opts.get("--note", "")))
        c = rec["checks"][-1]
        print(f"{short(folder)}: {'passed' if c['ok'] else 'failed'} {c['name']} on {(c['commit'] or '?')[:7]}"
              + (", tree dirty" if c.get("dirty") else ", clean tree") + f" ({by})")
        return 0
    if verb == "session":
        if len(words) != 2:
            die("vikix agents handoff session PROVIDER ID (claude, codex, opencode, gemini, antigravity, aider, other)")
        pid = me["pid"] if me and me["agent"] == words[0] else 0
        desk_record(folder, by=by, change=lambda r: H.add_session(r, words[0], words[1], by, pid))
        print(f"{short(folder)}: {words[0]} session {words[1]} noted; vikix agents resume offers it")
        return 0
    return 0

def forgettable():
    """The records that may be forgotten: their worktree gone, no agent
    left in it. (record, why not) for every record whose folder is gone."""
    H = handoff_module()
    at = {}
    for a in live_agents():
        folder = a.get("folder") or ""
        # Linux names a running process's removed cwd "PATH (deleted)": still that desk's.
        if folder.endswith(" (deleted)") and not os.path.lexists(folder):
            folder = folder[:-10]
        at.setdefault(os.path.realpath(folder), []).append(who(a))
    out = []
    for rec in H.all_records():
        wt = rec["desk"]["worktree"]
        if os.path.lexists(wt):
            continue
        out.append((rec, ", ".join(at.get(os.path.realpath(wt), []))))
    return out


def forget_record(rec):
    """The record REC removed, for a desk whose worktree is gone and where
    no agent is left: what was done, in a line. HandoffError says why not."""
    H = handoff_module()
    d = rec["desk"]
    if os.path.lexists(d["worktree"]):
        raise H.HandoffError(f"{short(d['worktree'])} is there: a desk that stands is closed, not forgotten "
                             f"(vikix agents close {os.path.basename(d['worktree'])} takes it down and keeps the record)")
    there = dict((r["desk"]["id"], at) for r, at in forgettable()).get(d["id"], "")
    if there:
        raise H.HandoffError(f"{there} still at work in {short(d['worktree'])}, gone as it is: let it finish first")
    if not H.forget(d["id"]):
        raise H.HandoffError(f"the record of {short(d['worktree'])} is gone already")
    h = rec.get("handoff") or {}
    status = (h.get("status") or {}).get("value", "no status")
    return (f"forgotten: the record of {short(d['worktree'])} ({d.get('branch') or 'no branch'}, {status}"
            + (f", closed {H.when(d['closed'])}" if d.get("closed") else ", never closed")
            + "). Nothing else went with it: no file, no branch, no conversation of the provider's")


def handoff_forget(words):
    """vikix agents handoff forget [DESK]: the record of a desk whose
    worktree is gone, removed; with no desk named, the ones that could be."""
    H = handoff_module()
    if not words:
        gone = forgettable()
        if not gone:
            print("No record of a desk whose folder is gone: nothing to forget (vikix agents handoff list).")
            return 0
        print("The records of desks whose folder is gone:")
        for rec, at in gone:
            d = rec["desk"]
            status = ((rec.get("handoff") or {}).get("status") or {}).get("value", "no status")
            print(f"  {short(d['worktree'])}  {status}, {H.when(rec['updated'])}"
                  + (f"  [closed {H.when(d['closed'])}]" if d.get("closed") else "")
                  + (f"  ({at} still there)" if at else ""))
        die("say which: vikix agents handoff forget DESK (its topic, branch or folder)")
    folder, rec = desk_for(words)
    if not rec:
        die(f"{short(folder)} has no record: nothing to forget")
    try:
        print(forget_record(rec))
    except H.HandoffError as e:
        die(str(e))
    return 0


# --- Taking a desk up again: the handoff shown, the conversation resumed where it can be ----------
def resume(argv):
    H = handoff_module()
    use, here, fresh, another, words, mode = None, False, False, False, [], None
    require_saved, expect_session, menu, prompt = False, None, False, ""
    while argv:
        a = argv.pop(0)
        if a == "--menu":
            menu = True
        elif a == "--prompt":
            prompt = argv.pop(0) if argv and argv[0].strip() else die("--prompt needs words: the agent's first prompt")
        elif a == "--mode":
            mode = argv.pop(0) if argv else die(f"--mode which? {', '.join(MODES)}")
        elif a == "--use":
            use = argv.pop(0) if argv else die("--use which agent? (vikix agent --list)")
        elif a == "--here":
            here = True
        elif a == "--expect-session":
            expect_session = argv.pop(0) if argv else die("--expect-session needs a conversation id")
        elif a == "--require-saved":
            require_saved = True
        elif a == "--fresh":
            fresh = True
        elif a == "--another":
            another = True
        elif a.startswith("-"):
            die(f"vikix agents resume: {a}? (vikix agents help)")
        else:
            words.append(a)
    if menu and not words:
        # From the desktop (Super+Alt+d, r; Super+m): the desk picked in rofi.
        every = [desk_state(d) for d in desks(projects())]
        if not every:
            die("no desk to take up: no project has a worktree beside it (vikix agents desk makes one)")
        picked = rofi("Take a desk up again", "Its handoff is shown, and an agent started there: the conversation "
                      "resumed where its provider still has it.", [desk_line(d) for d in every])
        if picked is None or not picked.isdigit():
            return 0
        words = [every[int(picked)]["folder"]]
    folder, rec = desk_for(words)
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: vikix agents desk {(rec or {}).get('desk', {}).get('project', 'PROJECT')} "
            f"{os.path.basename(folder).split('-', 1)[-1] if rec else 'TOPIC'} makes the worktree again "
            "(the record is kept, and waits there)")
    at, lines = protection_lines(folder)
    if rec:
        print(H.render(rec, [who(a) for a in at], lines))
    else:
        print(f"Desk {short(folder)}: no record yet (vikix agents handoff --task \"...\" starts one)")
        for line in lines:
            print("  " + line)
    if at and not another:
        die(f"{', '.join(who(a) for a in at)} is at this desk already: go to it (vikix agents, Super+m), "
            "or --another starts a second agent there")
    sessions = (rec or {}).get("sessions", [])
    provider = use or (sessions[-1]["provider"] if sessions else "") or default_agent()
    # The mode: the one given, else the last launch's for the same provider, else the house default for Codex.
    mode = mode_check(provider, mode)
    launch = (rec or {}).get("launch") or {}
    if mode is None and provider == "codex":
        mode = launch["mode"] if launch.get("provider") == "codex" and launch.get("mode") in MODES else default_mode()
    plan = H.resume_plan(rec, provider, folder, fresh)
    if expect_session and (plan["mode"] != "resumed" or plan["session"]["id"] != expect_session):
        die("saved conversation changed or unavailable; refresh and choose again")
    if require_saved and plan["mode"] != "resumed":
        die("saved conversation unavailable: " + plan["why"] + "; choose --fresh explicitly")
    if plan["mode"] == "resumed":
        sid = plan["session"]["id"]
        said = (f"resumed: {provider} session {sid} at {short(folder)}" + (f", {mode}" if mode else "")
                + f", its conversation continues ({plan['why']})")
        if provider in H.UNVERIFIED:
            said += f"; {provider}'s resume is from its documentation, unverified on this machine"
    else:
        said = (f"fresh conversation with {provider} at {short(folder)}" + (f", {mode}" if mode else "")
                + f": {plan['why']}. The handoff above is what it has")
        disk = H.sessions_on_disk(provider, folder)
        if disk and not fresh:
            said += ("\n" + f"{provider}'s own store has a conversation in this folder: "
                     + ", ".join(f"{sid} ({H.when(t)})" for sid, t in disk)
                     + f". If it is this desk's, note it (vikix agents handoff session {provider} ID) and resume again; "
                     "nothing is resumed unasked")
    print()
    print(said)
    by = by_me()[0]
    if rec:
        def noted(r_):
            H._log(r_, by, f"{plan['mode']}: {provider}" + (f" {mode}" if mode else "")
                   + (f" {plan['session']['id']}" if plan["session"] and plan["mode"] == "resumed" else ""))
            H.set_launch(r_, provider, mode, by)
        try:
            H.update(common_of(folder), folder, noted)
        except H.HandoffError:
            pass
        # The desk's task launched again (a task blocked on its worker runs;
        # another provider is a handoff between them), with the next number.
        task_launch((rec.get("task") or {}).get("id"), provider, by, "resume", mode=mode)
    for d in decisions_at(rec):
        print(tasks_module().decision_words(d))
    notes = inbox_peek(folder)
    if notes:
        print("Notes waiting at the desk (vikix agents tell), read out here; the user's reach the agent through its hook, "
              "the rest were for the agent before it:")
        for n in notes:
            print(note_line(n))
    # A fresh conversation asked for at a desk with a task (a handover): the task, the
    # handoff and the hand-in's fields are its first prompt, so nothing of the record is
    # left for it to find; a resumed conversation has them already. --prompt gives a
    # resumed conversation its next words (a worker at its prompt woken with a note).
    first = ()
    task = ((rec or {}).get("task") or {}).get("text", "")
    if fresh and task:
        first = H.first_prompt_args(provider, desk_prompt(task, rec)) or ()
        print("the task and the handoff are its first prompt" if first else
              f"the task and the handoff are in the record ({provider} takes no first prompt)")
    elif prompt:
        first = H.first_prompt_args(provider, prompt) or ()
        print("the words given are its first prompt" if first else f"{provider} takes no first prompt: the words are lost")
    start = agent_start(provider if provider != default_agent() or plan["args"] or first else None,
                        list(plan["args"]) + list(first), mode=mode, task=((rec or {}).get("task") or {}).get("id") or "")
    if here:
        open_here(folder, start)
    workspace = open_at(folder, start, desk_name(folder))
    if workspace:
        print(f"on workspace {workspace}")
    return 0


# --- Handing a desk over: from one provider to the next, the record between them -----------------
HANDOVER_WAIT = int(os.environ.get("VIKIX_HANDOVER_WAIT") or 120)   # seconds waited for the handoff, at most


def mid_turn(agents):
    """Of AGENTS (live_agents' dicts), the ones the journal says are
    working now: an edit, a command or a turn begun within the last
    minute and no stop since (journal_states), as (agent, what it is
    doing) each."""
    rows = journal_states([dict(a, state="running", doing="") for a in agents])
    return [(a, a["doing"]) for a in rows if a["state"] == "working"]


def handover(argv):
    """vikix agents handover DESK --to NAME [--mode MODE] [--now] [--here]:
    the desk passed from the agent at it to a fresh one of PROVIDER, the
    record between them. Refused while the desk's agent is mid-turn unless
    --now; its handoff asked for in a note and waited for (two minutes at
    most, until the record's handoff moves; not for an agent at its prompt,
    which reads no note); the agent dismissed; then resume --use PROVIDER
    --fresh, whose first prompt is the task, the handoff and the hand-in's
    fields. Both sessions stay in the record."""
    H = handoff_module()
    to, mode, now, here, words, task = None, None, False, False, [], ""
    while argv:
        a = argv.pop(0)
        if a == "--to":
            to = argv.pop(0) if argv else die(f"--to which provider? {', '.join(H.PROVIDERS)}")
        elif a == "--task":
            task = argv.pop(0) if argv and argv[0].strip() else die("--task needs words: what the next provider is to do")
        elif a == "--mode":
            mode = argv.pop(0) if argv else die(f"--mode which? {', '.join(MODES)}")
        elif a == "--now":
            now = True
        elif a == "--here":
            here = True
        elif a.startswith("-"):
            die(f"vikix agents handover: {a}? (vikix agents help)")
        else:
            words.append(a)
    if not words or not to:
        die("vikix agents handover DESK --to NAME [--task \"...\"] [--mode MODE] [--now] (DESK as for close; the provider: "
            f"{', '.join(p for p in H.PROVIDERS if p != 'other')})")
    if to not in H.PROVIDERS or to == "other":
        die(f"--to {to}? the providers: {', '.join(p for p in H.PROVIDERS if p != 'other')} (vikix agent --list)")
    mode_check(to, mode)
    by, me = by_me()
    folder, rec = desk_for(words, me)
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: nothing to hand over (vikix agents desk makes the worktree again)")
    if not rec or not rec.get("task"):
        die(f"{short(folder)} has no task in its record: nothing to hand over "
            f"(vikix agents worker {desk_name(folder)} \"...\" --use {to} starts a worker there)")
    # The next provider's task: the words given, else what the record's next step says,
    # read once the agent has had its chance to write it (below). Never the task as it
    # stands: the designer's "no code, hand in" became Codex's orders (2026-10-11), and
    # it stopped in 27 s.
    if task:
        try:
            task = H.clean(task, "the task")
        except H.HandoffError as e:
            die(str(e))
    there = agents_at(folder)
    if me and any(a["pid"] == me["pid"] for a in there):
        die("that is your own desk: an agent doesn't hand itself over (write your handoff and end your turn; "
            "the user runs handover)")
    busy = mid_turn(there)
    if busy and not now:
        die(", ".join(f"{who(a)} is {doing}" for a, doing in busy) + ": wait for its prompt, or --now hands over "
            "mid-turn (its handoff is asked for all the same)")
    from_ = ", ".join(sorted({a["agent"] for a in there})) or (
        rec["sessions"][-1]["provider"] if rec.get("sessions") else "nobody")
    if there:
        for a in there:
            try:
                inbox_add(folder, f"handing over to {to}: write your handoff now (vikix agents handoff --status ... "
                          "--summary \"what you changed and decided\" --next \"what is left\", --decided and --defect "
                          "for the rest), then stop", by, to=a)
            except H.HandoffError:
                pass
        was = H.handoff_written_at(rec)
        # An agent at its prompt makes no tool call until spoken to, so the note waits
        # there unread: nothing to wait for. One with no hook never reads it either.
        reads = [a for a in there if a["agent"] in NOTE_HOOKS]
        states = {r["pid"]: r["state"] for r in journal_states([dict(a, state="running", doing="") for a in reads])}
        waiting = [a for a in reads if states.get(a["pid"]) != "idle"]
        if waiting and not now:
            print(f"asked {', '.join(who(a) for a in waiting)} for its handoff; waiting up to {HANDOVER_WAIT} s "
                  "for the record to move")
            end = time.time() + HANDOVER_WAIT
            while time.time() < end:
                time.sleep(min(2, max(0.2, end - time.time())))
                latest = H.load(H.desk_id(common_of(folder), folder)) or {}
                if H.handoff_written_at(latest) > was:
                    print("its handoff moved")
                    break
                if all(process_gone(a["pid"]) for a in there):
                    print("it has gone")
                    break
            else:
                print("no handoff came: what the record has is what the next agent gets")
        else:
            print(("handing over now" if now else f"{', '.join(who(a) for a in there)} is at its prompt, or has no hook "
                   "that carries a note") + ": what the record has is what the next agent gets")
    rec = H.load(H.desk_id(common_of(folder), folder)) or rec
    if not task:
        task = (((rec.get("handoff") or {}).get("next") or {}).get("text") or "").strip()
    if not task:
        die(f"{short(folder)}: what is {to} to do? --task \"...\" says, or the record's next step "
            "(vikix agents handoff --next \"...\"); the task as it stands was the last agent's and isn't passed on. "
            "Nothing done" + (": its agent stays" if there else ""))
    if there:
        dismiss([folder])
        # Asked of the kernel, not of /proc (the tests' made-up one outlives its stand-ins).
        for _ in range(25):
            if all(process_gone(a["pid"]) for a in there):
                break
            time.sleep(0.2)
        left = [a for a in there if not process_gone(a["pid"])]
        if left:
            die(f"{', '.join(who(a) for a in left)} is still at the desk after the dismissal: hand over once it has gone")

    base = base_of(folder)[0]
    before = (rec.get("task") or {}).get("text", "")

    def change(r):
        H._log(r, by, f"handed over: {from_} -> {to}")
        H.set_changes(r, folder, base)      # what the next agent is told it inherits, as git has it now
        # The task before, with the worker's handoff whole, goes into the history; the
        # desk's fields (criteria, decisions, defects, findings) stay for the next.
        H.start_worker(r, task, by, to, mode)
    desk_record(folder, by=by, change=change)
    print(f"{short(folder)}: handed over, {from_} -> {to}; its task: {task[:100]}{'…' if len(task) > 100 else ''}"
          + (f"\n  the task before it ({before[:60]}{'…' if len(before) > 60 else ''}) is in the desk's history with its handoff"
             if before != task else ""))
    return resume([folder, "--use", to, "--fresh"] + (["--mode", mode] if mode else []) + (["--here"] if here else []))


def handoff_brief(folder):
    """The desk's record in a line's worth: status, where the work stands
    against the estimate, next, the checks' freshness (fresh/stale
    counts). None without a record."""
    try:
        H = handoff_module()
        rec = H.load(H.desk_id(common_of(folder), folder))
    except Exception:  # noqa: BLE001  a record that can't be read costs the line, not the listing
        return None
    if not rec:
        return None
    h = rec.get("handoff") or {}
    now = H.observe(folder) if os.path.isdir(folder) else {}
    checks = rec.get("checks") or []
    fresh = sum(1 for c in checks if H.freshness(c, now) == "fresh")
    est = H.estimate_state(rec)
    return {"status": (h.get("status") or {}).get("value"), "next": (h.get("next") or {}).get("text", ""),
            "mode": (rec.get("launch") or {}).get("mode", ""),
            "estimate": est["line"] if est else "", "task": (rec.get("task") or {}).get("text", ""),
            "checks": f"{fresh} fresh, {len(checks) - fresh} stale" if checks else "",
            "notes": len(inbox_peek(folder))}
