"""plan.py — the plan runner: a plan file's tasks run as workers at desks,
in order (vikix agents plan; loaded by bin/vikix-agents with itself as api).

A plan is one project's work in tasks, each one worker's job, in a TOML
file:

    project = "vikix"          # one of vikix project's, by any part of its name
    at-once = 2                # workers running together, at most (1)
    gate = "me"                # a desk's release waits for your yes (none: it goes)

    [[task]]
    name = "events"            # a word: what after names
    desk = "office-events"     # the desk it works at (the name when unsaid)
    task = "An event log for the office: ..."     # the worker's words
    agent = "codex"            # the worker's choices, as the New worker form has them:
    local = true               #   --use, --local, --push, --no-tests
    push = false
    no-tests = false
    release = "The office's event log"  # the release's line, for the last task at a desk

    [[task]]
    name = "runner"
    after = ["events"]
    desk = "office-events"
    task = "..."

Tasks at one desk are a chain: its workers in turn, on one branch, in the
file's order. The next starts once the last has handed in (status review
or finished) and its tests pass (a fresh check; a task with no-tests, or a
project with no tests/run.sh, needs the hand-in alone), and it reads the
handoff the last one left; the desk is released once, at the chain's end,
with the project's .claude/release. Tasks at different desks run side by
side, up to at-once. A task after a task at another desk waits for that
desk to be released, and must be the first at its own desk, so its
worktree is made from the released main; a task whose after is at its own
desk needs nothing more than its turn.

The runner is a script, never an agent: it edits no file, answers no
prompt, puts one worker at a desk at a time (a worker that handed in is
dismissed once its tests are in), never merges or pushes (the release
script merges; gup stays the user's). A round is one worker on a task;
one that handed in with failing tests, or left without handing in, failed,
and the next round's worker is told why in the desk's inbox; the third
failure stops that desk under Needs you, as does a release that failed, a
desk whose task is another's, and a hand-in left with files uncommitted
while its worker is gone. Its state is worked out each time from the plan
file and the desk records (which task is the record's, what came before
in its history, the checks and their freshness, who is at the desk), so a
reboot loses nothing and running it again carries on; only its own
switches (paused, stopped, the gate's yes, the release it started) are in
its note, ~/.local/state/vikix/office/plans/ID.json. It wakes on the event
log (lib/handoff.py: hand-ins, checks, releases, agents that left) and
looks round on its own once a minute besides.

What it can't know: which files two desks will touch (turns and the clash
rules handle that), and whether a worker at its prompt will ever read a
note (it won't: that is why a worker that handed in is dismissed).
"""
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import tomllib

STATE = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
PLANS = os.path.join(STATE, "vikix", "office", "plans")
POLL = int(os.environ.get("VIKIX_PLAN_POLL") or 60)       # seconds between looks when no event comes
GRACE = int(os.environ.get("VIKIX_PLAN_GRACE") or 120)    # seconds a worker just started has to appear
ROUNDS = 3                                                 # failed rounds that stop a desk
KEYS = ("project", "at-once", "gate", "task")
TASK_KEYS = ("name", "task", "desk", "after", "agent", "local", "push", "no-tests", "release")
NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,40}$")
GATES = ("none", "me")
RUNNING = ("running", "starting", "testing", "to-test")    # states that hold a worker's slot


class PlanError(Exception):
    """A plan that can't be read or run as it is; the message says why."""


# --- The plan file ---------------------------------------------------------------------------

def read_plan(path):
    """The plan in PATH, read and checked: {file, name, project, at_once,
    gate, tasks, desks}. Each task {name, text, desk, after, agent, local,
    push, no_tests, release, index}; desks the topics in the file's order,
    each with its tasks. Raises PlanError with the line of a mistake."""
    path = os.path.realpath(os.path.expanduser(path))
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except OSError as e:
        raise PlanError(f"{path}: {e.strerror or e}")
    except tomllib.TOMLDecodeError as e:
        raise PlanError(f"{path}: not TOML: {e}")
    for k in data:
        if k not in KEYS:
            raise PlanError(f"{path}: '{k}'? a plan has {', '.join(KEYS)}")
    project = data.get("project")
    if not isinstance(project, str) or not project.strip():
        raise PlanError(f"{path}: project = \"NAME\" says which project the plan is for")
    at_once = data.get("at-once", 1)
    if not isinstance(at_once, int) or isinstance(at_once, bool) or at_once < 1:
        raise PlanError(f"{path}: at-once is a number of workers, 1 or more")
    gate = data.get("gate", "none")
    if gate not in GATES:
        raise PlanError(f"{path}: gate is \"me\" (a release waits for your yes) or \"none\"")
    raw = data.get("task")
    if not isinstance(raw, list) or not raw or not all(isinstance(t, dict) for t in raw):
        raise PlanError(f"{path}: no tasks: each is a [[task]] table with a name and its words")
    tasks, names, desks = [], {}, {}
    for i, t in enumerate(raw):
        where = f"{path}: task {i + 1}"
        for k in t:
            if k not in TASK_KEYS:
                raise PlanError(f"{where}: '{k}'? a task has {', '.join(TASK_KEYS)}")
        name = t.get("name")
        if not isinstance(name, str) or not NAME.match(name):
            raise PlanError(f"{where}: name is a word (letters, digits, dashes)")
        if name in names:
            raise PlanError(f"{where}: the name {name} is taken by task {names[name] + 1}")
        text = t.get("task")
        if not isinstance(text, str) or not text.strip():
            raise PlanError(f"{where} ({name}): task = \"...\" is the worker's job, in your words")
        desk = t.get("desk", name)
        if not isinstance(desk, str) or not NAME.match(desk):
            raise PlanError(f"{where} ({name}): desk is a topic: a word (letters, digits, dashes)")
        after = t.get("after", [])
        if isinstance(after, str):
            after = [after]
        if not isinstance(after, list) or not all(isinstance(a, str) for a in after):
            raise PlanError(f"{where} ({name}): after is a list of task names")
        for a in after:
            if a not in names:
                raise PlanError(f"{where} ({name}): after names {a}, which isn't a task before it")
        for k in ("local", "push", "no-tests"):
            if k in t and not isinstance(t[k], bool):
                raise PlanError(f"{where} ({name}): {k} is true or false")
        for k in ("agent", "release"):
            if k in t and (not isinstance(t[k], str) or not t[k].strip()):
                raise PlanError(f"{where} ({name}): {k} is text")
        elsewhere = [a for a in after if tasks[names[a]]["desk"] != desk]
        if elsewhere and desk in desks:
            raise PlanError(f"{where} ({name}): after {', '.join(elsewhere)}, at another desk, so it needs a desk of "
                            f"its own, made from main once that desk is released; {desk} has {desks[desk][0]} already")
        names[name] = i
        tasks.append({"name": name, "text": text.strip(), "desk": desk, "after": after, "agent": t.get("agent", ""),
                      "local": t.get("local", False), "push": t.get("push", False),
                      "no_tests": t.get("no-tests", False), "release": (t.get("release") or "").strip(), "index": i})
        desks.setdefault(desk, []).append(name)
    base = os.path.basename(path)
    return {"file": path, "name": base[:-5] if base.endswith(".toml") else base, "project": project.strip(),
            "at_once": at_once, "gate": gate, "tasks": tasks, "desks": desks}


def plan_id(path):
    return hashlib.sha1(os.path.realpath(os.path.expanduser(path)).encode()).hexdigest()[:12]


# --- The runner's note: its switches, nothing of the tasks' state ----------------------------

def note_path(pid):
    return os.path.join(PLANS, pid + ".json")


def note_read(pid):
    try:
        with open(note_path(pid)) as f:
            got = json.load(f)
    except (OSError, ValueError):
        return None
    return got if isinstance(got, dict) and got.get("file") else None


def note_write(note):
    os.makedirs(PLANS, exist_ok=True)
    path = note_path(note["id"])
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w") as f:
        json.dump(note, f, indent=1, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def note_change(pid, change):
    """NOTE read, CHANGE(note) applied, written; the note after. The loop
    and the commands both write, so each change is read-modify-write."""
    note = note_read(pid)
    if not note:
        raise PlanError("no such plan is running (vikix agents plan status lists them)")
    change(note)
    note_write(note)
    return note


def notes():
    """Every plan with a note, newest start first."""
    out = []
    try:
        names = os.listdir(PLANS)
    except OSError:
        return out
    for name in names:
        if name.endswith(".json") and len(name) == 17:
            got = note_read(name[:-5])
            if got:
                out.append(got)
    return sorted(out, key=lambda n: -(n.get("started") or 0))


def alive(pid):
    """Whether the process PID runs; 0 (no runner noted) never does."""
    try:
        pid = int(pid)
        if pid <= 0:
            return False
        os.kill(pid, 0)
        return True
    except (OSError, ValueError, TypeError):
        return False


def new_note(plan):
    return {"id": plan_id(plan["file"]), "file": plan["file"], "name": plan["name"], "project": plan["project"],
            "started": int(time.time()), "pid": 0, "paused": False, "stopped": False, "done": 0,
            "yes": {}, "releases": {}, "told": {}}


def told_once(note, key):
    """Whether KEY was done already for this note; noted when it wasn't."""
    if key in note.get("told", {}):
        return True
    note.setdefault("told", {})[key] = int(time.time())
    return False


# --- The state of each desk and task, worked out from the records --------------------------

def resolve(api, plan):
    """The plan's project: (its own folder, the repository's top, common
    dir). A project that is no repository can't take a plan: a desk is a
    worktree."""
    try:
        project = api.projects().match(plan["project"])
    except SystemExit:
        raise PlanError(f"no project called {plan['project']} (vikix project list names them)")
    path = str(project.path)
    top = (api.git(path, "rev-parse", "--show-toplevel") or "").strip()
    if not top:
        raise PlanError(f"{project.full} isn't a git repository, and a plan's desks are worktrees of one")
    own = api.own_folder(top)
    return project, own, top, api.common_of(own)


def desk_folder(top, topic):
    return os.path.join(os.path.dirname(top), f"{os.path.basename(top)}-{topic}")


def fresh_check(H, rec, now):
    """The newest check that still speaks for the code as it is NOW, or None."""
    for c in reversed(rec.get("checks") or []):
        if H.freshness(c, now) == "fresh":
            return c
    return None


def task_at(api, H, task, rec, folder, exists, agents, now_obs, now):
    """The state of TASK, the desk's current task: (state, words).
    handed in states: passed (done), failed, dirty, testing, to-test;
    waiting (the agent asks); running, starting, gone."""
    status = ((rec.get("handoff") or {}).get("status") or {}).get("value", "")
    who = ", ".join(api.who(a) for a in agents)
    if status in ("review", "finished"):
        wanted = not task["no_tests"] and bool(api.runner_of(folder)[1]) if exists else False
        check = fresh_check(H, rec, now_obs) if exists else None
        dirty = now_obs.get("dirty")
        if wanted and not check:
            if api.tester_running(folder):
                return "testing", f"handed in ({status}); its tests run"
            return "to-test", f"handed in ({status}); its tests are next"
        if wanted and not check["ok"]:
            return "failed", f"handed in ({status}); tests failed: {(check.get('note') or '')[:80]}"
        if dirty:
            return "dirty", f"handed in ({status}), {dirty} file{'s' if dirty != 1 else ''} uncommitted" + (
                f"; {who} told" if agents else ", the worker gone")
        return "passed", f"handed in ({status})" + (", tests passed" if wanted else "") + (f"; {who} still at the desk" if agents else "")
    if status == "waiting":
        h = rec.get("handoff") or {}
        if (h.get("status") or {}).get("by") == "vikix":
            return "waiting", (h.get("next") or {}).get("text") or "stopped by the plan"
        return "waiting", f"waiting for you ({who or 'the worker gone'})"
    at = (rec.get("task") or {}).get("at") or 0
    if agents:
        return "running", f"{who} at work, {api.how_long(now - at)}" if at else f"{who} at work"
    if now - at < GRACE:
        return "starting", "the worker starts"
    left = (rec.get("left") or {}).get("reason") or "gone"
    return "gone", f"the worker left without handing in ({left})"


def chain_view(api, H, plan, topic, top, common, own, now):
    """One desk of the plan: its folder, record, agents, whether released,
    and a state for each of its tasks: done, current (with task_at's state
    and words), another (the desk's task is none of the plan's), pending.
    {topic, folder, exists, rec, agents, released, merged, tasks: [...],
    current: the index of the task in hand or None}."""
    folder = desk_folder(top, topic)
    exists = os.path.isdir(folder)
    rec = H.load(H.desk_id(common, folder)) or {}
    agents = api.agents_at(folder) if exists else []
    now_obs = H.observe(folder) if exists else {}
    names = plan["desks"][topic]
    tasks = [t for t in plan["tasks"] if t["name"] in names]
    clean = lambda s: H.clean(s or "", "text") if s else ""   # noqa: E731
    texts = [clean(t["text"]) for t in tasks]
    current_text = clean((rec.get("task") or {}).get("text", ""))
    history = [clean(w.get("task", "")) for w in rec.get("workers") or []]
    view = {"topic": topic, "folder": folder, "exists": exists, "rec": rec, "agents": agents, "now": now_obs,
            "released": bool((rec.get("desk") or {}).get("closed")), "merged": False, "tasks": [], "current": None}
    cur = texts.index(current_text) if current_text in texts else None
    if cur is None and current_text:
        # The record's task is none of the plan's: the desk is someone else's for now.
        other = (rec.get("task") or {}).get("text", "")[:60]
        for t in tasks:
            view["tasks"].append({"task": t, "state": "another", "words": f"the desk's task is another: {other}", "rounds": 0})
        return view
    for i, t in enumerate(tasks):
        if cur is not None and i < cur:
            state, words = "done", "done (the desk moved on)"
        elif cur is not None and i == cur:
            state, words = task_at(api, H, t, rec, folder, exists, agents, now_obs, now)
            view["current"] = i
        else:
            state, words = "pending", ""
        view["tasks"].append({"task": t, "state": state, "words": words, "rounds": history.count(texts[i]) + (1 if i == cur else 0)})
    if view["released"]:
        for s in view["tasks"]:
            if s["state"] != "another":
                s["state"], s["words"] = "done", "done (the desk released)"
    elif exists and view["tasks"] and all(s["state"] in ("done", "passed") for s in view["tasks"]) and rec:
        # Merged by hand into the project's own branch: the work is in, the desk waits to be closed.
        branch = (rec.get("desk") or {}).get("branch") or ""
        merged = api.git(own, "branch", "--merged", "HEAD", "--format=%(refname:short)") or ""
        view["merged"] = bool(branch) and branch in merged.split() and not now_obs.get("dirty")
        if view["merged"]:
            view["released"] = True
    return view


def before_met(plan, task, views):
    """Whether TASK's befores are met: at its own desk its turn (chain_view
    orders that); at another desk, that desk released. (met, waiting on)."""
    waiting = []
    for a in task["after"]:
        other = next(t for t in plan["tasks"] if t["name"] == a)
        if other["desk"] != task["desk"] and not views[other["desk"]]["released"]:
            waiting.append(f"{a} ({other['desk']} released)")
    return not waiting, waiting


def release_line(task):
    """What the release says the desk brings: the task's release line, else
    the first sentence of its words."""
    if task["release"]:
        return task["release"][:120]
    first = re.split(r"(?<=[.!?])\s|\n", task["text"].strip(), maxsplit=1)[0]
    return first.rstrip(".")[:100]


def plan_view(api, plan, note, now=None):
    """The whole plan now: the desks (chain_view each), what each desk is
    doing in words (the line the status and the Office show), what needs
    you, how many workers run, and whether it is done. Nothing is changed."""
    H = api.handoff_module()
    now = now or int(time.time())
    project, own, top, common = resolve(api, plan)
    views = {topic: chain_view(api, H, plan, topic, top, common, own, now) for topic in plan["desks"]}
    releases = note.get("releases", {}) if note else {}
    yes = note.get("yes", {}) if note else {}
    failed = note.get("failed", {}) if note else {}
    needs, running = [], 0
    for topic, v in views.items():
        v["line"], v["needs"], v["act"] = "", "", None
        another = [s for s in v["tasks"] if s["state"] == "another"]
        if v["released"]:
            v["line"] = "released" if (v["rec"].get("desk") or {}).get("closed") else "merged by hand; close the desk"
            continue
        if another:
            v["needs"] = f"{topic}: {another[0]['words']}"
            v["line"] = another[0]["words"]
            continue
        cur = v["current"]
        if cur is not None:
            s = v["tasks"][cur]
            t = s["task"]
            v["line"] = f"{t['name']}: {s['words']}"
            if s["state"] in RUNNING or s["state"] == "to-test":
                running += 1
                if s["state"] == "to-test":
                    v["act"] = ("test", t)
            elif s["state"] == "waiting":
                by = ((v["rec"].get("handoff") or {}).get("status") or {}).get("by")
                v["needs"] = s["words"] if by == "vikix" else f"{topic}: {t['name']} {s['words']}"
            elif s["state"] in ("failed", "gone") or (s["state"] == "dirty" and not v["agents"]):
                if s["rounds"] >= ROUNDS:
                    v["needs"] = f"{topic}: {t['name']} failed {s['rounds']} rounds ({s['words']})"
                    v["line"] = f"{t['name']}: stopped after {s['rounds']} rounds: {s['words']}"
                else:
                    v["act"] = ("again", t)
                    v["line"] = f"{t['name']}: round {s['rounds']} failed ({s['words']}); the next starts"
            elif s["state"] == "dirty":
                running += 1
                v["act"] = ("tell-dirty", t)
            elif s["state"] == "passed":
                if v["agents"]:
                    running += 1
                    v["act"] = ("dismiss", t)
                elif cur + 1 < len(v["tasks"]):
                    nxt = v["tasks"][cur + 1]["task"]
                    met, waiting = before_met(plan, nxt, views)
                    v["act"] = ("start", nxt) if met else None
                    v["line"] = f"{nxt['name']}: next" + ("" if met else ", after " + ", ".join(waiting))
                else:
                    v["act"] = ("release", t)
                    v["line"] = f"{t['name']} handed in; the desk's release is next"
            continue
        # Nothing of the plan's at the desk yet: its first task.
        first = v["tasks"][0]["task"]
        met, waiting = before_met(plan, first, views)
        if v["agents"]:
            v["line"] = f"{first['name']}: waits, {', '.join(api.who(a) for a in v['agents'])} is at the desk"
        elif met:
            v["act"] = ("start", first)
            v["line"] = f"{first['name']}: ready to start"
        else:
            v["line"] = f"{first['name']}: after " + ", ".join(waiting)
    # The release step, and what the note knows of releases under way.
    for topic, v in views.items():
        rel = releases.get(topic)
        if v["released"]:
            continue
        if topic in failed:
            v["needs"] = f"{topic}: {failed[topic]}"
            v["line"], v["act"] = "stopped: " + failed[topic][:60], None
            continue
        if rel:
            if alive(rel.get("pid")):
                v["line"], v["act"] = f"releasing ({release_state(api, common, topic) or 'under way'})", None
                continue
            v["needs"] = f"{topic}: its release failed; {rel.get('log', '')} says why, vikix agents plan release {topic} tries again"
            v["line"], v["act"] = "release failed", None
            continue
        if v["act"] and v["act"][0] == "release":
            script = os.path.join(own, ".claude", "release")
            if not os.access(script, os.X_OK):
                v["needs"] = f"{topic}: its work is in and handed in; no .claude/release in {plan['project']}: merge its branch and close the desk yourself"
                v["line"], v["act"] = "ready: merge it yourself", None
            elif plan["gate"] == "me" and topic not in yes:
                v["needs"] = f"{topic}: ready to release: vikix agents plan release {topic} is your yes"
                v["line"], v["act"] = "ready to release: your yes", None
    for v in views.values():
        if v["needs"]:
            needs.append(v["needs"])
    done = all(v["released"] for v in views.values())
    return {"plan": plan, "project": project, "own": own, "top": top, "common": common, "views": views,
            "needs": needs, "running": running, "done": done, "now": now}


def release_state(api, common, topic):
    """What the release of TOPIC says it is doing, from its note in the repository."""
    for _, (t, state, *_) in api.read_notes(os.path.join(common, "vikix-release-queue"), 5):
        if t == topic:
            return state
    return ""


# --- Acting: the desks and workers, through vikix agents desk and worker --------------------

def agents_cmd():
    return [sys.executable, os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "bin", "vikix-agents")]


def run(words, log, cwd=None):
    """vikix agents WORDS (or any command), its output to LOG; (ok, the last line)."""
    r = subprocess.run(words, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    log(f"$ {' '.join(words[2:] if words[:2] == agents_cmd() else words)}\n{out}" if out else f"$ {' '.join(words)}")
    return r.returncode == 0, (out.splitlines() or [""])[-1]


def start_worker(api, view, task, plan, project, note, log, why=""):
    """The desk made when it isn't, then a worker at it on TASK, with its
    choices; WHY, when given, goes into the desk's inbox first (what failed
    in the round before). True when the worker started."""
    cmd = agents_cmd()
    if not view["exists"]:
        ok, last = run(cmd + ["desk", plan["project"], view["topic"]], log)
        if not ok:
            return fail(note, view, f"couldn't make the desk: {last}", log)
    if why:
        try:
            api.inbox_add(view["folder"], why, "vikix")
        except Exception as e:  # noqa: BLE001  a note that can't be left doesn't stop the round
            log(f"{view['topic']}: no note left: {e}")
    words = cmd + ["worker", view["folder"], task["text"]]
    words += ["--use", task["agent"]] if task["agent"] else []
    words += ["--local"] if task["local"] else []
    words += ["--push"] if task["push"] else []
    words += ["--no-tests"] if task["no_tests"] else []
    ok, last = run(words, log)
    if not ok:
        return fail(note, view, f"couldn't start the worker for {task['name']}: {last}", log)
    return True


def fail(note, view, words, log):
    """Something the runner couldn't do at a desk, kept in the note (the
    desk is under Needs you until plan run or plan release clears it)."""
    note.setdefault("failed", {})[view["topic"]] = words[:300]
    log(f"{view['topic']}: {words}")
    return False


def notify(title, body):
    """Said on the desktop, when there is one."""
    if os.environ.get("DISPLAY") and shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Vikix", title[:100], body[:300]], check=False)


def put_waiting(api, view, words, note, key):
    """The desk's status set waiting by vikix, with WORDS as the next step,
    once per KEY: what puts it under Needs you, and tells the user."""
    if told_once(note, key) or not view["exists"]:
        return
    try:
        api.handoff_apply(view["folder"], {"status": "waiting", "next": words}, "vikix")
    except Exception:  # noqa: BLE001  a record that can't be written is said in the log alone
        pass


def act(api, state, note, log):
    """One round of acting on STATE (plan_view): the tester started, a
    worker told or dismissed, the next worker started while slots allow,
    the release started or asked for. The note is written for what it
    remembers. True when something was done."""
    plan, project, own = state["plan"], state["project"], state["own"]
    running, did = state["running"], False
    for topic, v in state["views"].items():
        if v["needs"]:
            key = "needs:" + v["needs"][:200]
            if not told_once(note, key):
                did = True
                log(f"needs you: {v['needs']}")
                notify(f"Plan {plan['name']}: needs you", v["needs"])
                cur = v["current"]
                if cur is not None and v["tasks"][cur]["state"] in ("failed", "gone", "dirty"):
                    put_waiting(api, v, v["needs"], note, "waiting:" + v["needs"][:200])
            continue
        if not v["act"]:
            continue
        verb, task = v["act"]
        if verb == "test":
            if not api.tester_running(v["folder"]):
                api.tester_start(v["folder"])
                log(f"{topic}: {task['name']} handed in; its tests started")
                did = True
        elif verb == "tell-dirty":
            at = ((v["rec"].get("handoff") or {}).get("status") or {}).get("at", 0)
            if not told_once(note, f"dirty:{topic}:{at}"):
                n = v["now"].get("dirty")
                try:
                    api.inbox_add(v["folder"], f"plan {plan['name']}: you handed in with {n} file{'s' if n != 1 else ''} "
                                               "uncommitted; commit them, then hand in again", "vikix")
                except Exception:  # noqa: BLE001
                    pass
                log(f"{topic}: {task['name']} handed in with {n} uncommitted; the worker told")
                did = True
        elif verb == "dismiss":
            if not told_once(note, f"dismiss:{topic}:{v['tasks'][v['current']]['rounds']}:{task['name']}:done"):
                run(agents_cmd() + ["dismiss", v["folder"]], log)
                log(f"{topic}: {task['name']} is in; its worker dismissed, the desk goes on")
                did = True
        elif verb == "again":
            s = v["tasks"][v["current"]]
            if v["agents"]:
                if not told_once(note, f"dismiss:{topic}:{s['rounds']}:{task['name']}:failed"):
                    run(agents_cmd() + ["dismiss", v["folder"]], log)
                    log(f"{topic}: round {s['rounds']} of {task['name']} failed; its worker dismissed")
                    did = True
                continue
            if running >= plan["at_once"]:
                continue
            why = (f"plan {plan['name']}, round {s['rounds'] + 1} of {ROUNDS} for this task: round {s['rounds']} "
                   f"{s['words']}. The handoff and the checks say where it stands: carry on from there")
            if start_worker(api, v, task, plan, project, note, log, why):
                running += 1
                did = True
        elif verb == "start":
            if running >= plan["at_once"]:
                continue
            if start_worker(api, v, task, plan, project, note, log):
                running += 1
                did = True
        elif verb == "release":
            script = os.path.join(own, ".claude", "release")
            logf = os.path.join(PLANS, f"{note['id']}-{topic}.release.log")
            line = release_line(task)
            with open(logf, "w") as out:
                p = subprocess.Popen([script, topic, line], cwd=own, stdin=subprocess.DEVNULL, stdout=out,
                                     stderr=subprocess.STDOUT, start_new_session=True)
            note.setdefault("releases", {})[topic] = {"pid": p.pid, "at": int(time.time()), "log": logf, "line": line}
            note.get("yes", {}).pop(topic, None)
            log(f"{topic}: release started ({line}); {logf}")
            did = True
    # A release that ended with the desk released is forgotten.
    for topic in list(note.get("releases", {})):
        v = state["views"].get(topic)
        if v and v["released"] and not alive(note["releases"][topic].get("pid")):
            note["releases"].pop(topic)
            log(f"{topic}: released")
            did = True
    if state["done"] and not note.get("done"):
        note["done"] = int(time.time())
        log("the plan is done: every desk released")
        did = True
    note_write(note)
    return did


# --- The loop ----------------------------------------------------------------------------

def logger(pid, to_stdout=False):
    path = os.path.join(PLANS, pid + ".log")

    def log(words):
        stamp = time.strftime("%H:%M:%S")
        try:
            os.makedirs(PLANS, exist_ok=True)
            with open(path, "a") as f:
                f.write(f"{stamp} {words}\n")
        except OSError:
            pass
        if to_stdout:
            print(f"{stamp} {words}", flush=True)
    return log


def one_round(api, pid, log):
    """The plan read, its state worked out, acted on unless paused. The
    state, or None when the plan can't be read (said)."""
    note = note_read(pid)
    if not note or note.get("stopped"):
        return None
    try:
        plan = read_plan(note["file"])
        state = plan_view(api, plan, note)
    except PlanError as e:
        log(f"the plan can't be read: {e}")
        return None
    if not note.get("paused"):
        act(api, state, note, log)
    return state


def wait_round(api, pos, note_mtime, pid):
    """Until an event comes, the note changes, or POLL seconds: (events
    position after, the note's mtime after)."""
    H = api.handoff_module()
    waited = 0
    while waited < POLL:
        time.sleep(2)
        waited += 2
        size = H.events_size()
        try:
            mtime = os.path.getmtime(note_path(pid))
        except OSError:
            mtime = 0
        if size != pos or mtime != note_mtime:
            return size, mtime
    return pos, note_mtime


def loop(api, pid, to_stdout=False, once=False):
    """The runner: rounds until the plan is done or stopped."""
    log = logger(pid, to_stdout)
    note = note_read(pid)
    if not note:
        raise PlanError("no such plan (vikix agents plan run FILE starts one)")
    note_change(pid, lambda n: n.update(pid=os.getpid()))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    H = api.handoff_module()
    pos = H.events_size()
    try:
        mtime = os.path.getmtime(note_path(pid))
    except OSError:
        mtime = 0
    log(f"runner started (pid {os.getpid()}) for {note['file']}")
    try:
        while True:
            state = one_round(api, pid, log)
            note = note_read(pid)
            if not note or note.get("stopped"):
                log("stopped")
                break
            if state and state["done"]:
                break
            if once:
                break
            try:
                mtime = os.path.getmtime(note_path(pid))   # the round's own write of the note isn't a wake
            except OSError:
                mtime = 0
            pos, mtime = wait_round(api, pos, mtime, pid)
    finally:
        try:
            note_change(pid, lambda n: n.update(pid=0))
        except PlanError:
            pass
    return 0


# --- The commands ------------------------------------------------------------------------

def find(words):
    """The plan WORDS name: a file, a plan's name or its id. (note, plan file)."""
    if not words:
        raise PlanError("which plan? its file, or its name (vikix agents plan status lists them)")
    word = words[0]
    path = os.path.realpath(os.path.expanduser(word))
    for n in notes():
        if n["file"] == path or n["id"] == word or n["name"] == word:
            return n, n["file"]
    if os.path.isfile(path):
        return None, path
    raise PlanError(f"no plan called {word} (vikix agents plan status lists them; a file starts one)")


def status_lines(api, state, note):
    """The plan as words: a line for the plan, one a desk, one a task."""
    plan = state["plan"]
    head = f"Plan {plan['name']} ({api.short(plan['file'])}): {plan['project']}, "
    head += f"{plan['at_once']} worker{'s' if plan['at_once'] != 1 else ''} at once" + (", your yes before a release" if plan["gate"] == "me" else "")
    if not note:
        head += "; not running (vikix agents plan run starts it)"
    elif note.get("done"):
        head += f"; done {api.handoff_module().when(note['done'])}"
    elif note.get("stopped"):
        head += "; stopped (plan run carries on)"
    elif note.get("paused"):
        head += "; paused: nothing new starts (plan run carries on)"
    elif alive(note.get("pid")):
        head += f"; running (pid {note['pid']})"
    else:
        head += "; its runner isn't running (plan run starts it again; nothing is lost)"
    lines = [head]
    for topic, v in state["views"].items():
        lines.append(f"  desk {topic}: {v['line'] or 'nothing yet'}")
        for s in v["tasks"]:
            if s["state"] in ("done", "passed"):
                mark, words = "done", s["words"]
            elif s["state"] == "pending":
                t = s["task"]
                met, waiting = before_met(plan, t, state["views"])
                mark, words = "    ", ("waits for " + ", ".join(waiting)) if not met else (
                    "its turn next" if not t["after"] else "after " + ", ".join(t["after"]))
            else:
                mark, words = "now ", s["words"]
            lines.append(f"    {mark} {s['task']['name']:<20} {words}" + (f"  (round {s['rounds']})" if s["rounds"] > 1 else ""))
    if state["needs"]:
        lines.append("Needs you:")
        lines += [f"  {n}" for n in state["needs"]]
    return lines


def plans_view(api):
    """Every plan with a note, for the Office: {name, file, project, state,
    pid, done, desks: [{topic, line, tasks: [{name, state, words}]}],
    needs}. A plan whose file is gone or can't be read says so."""
    out = []
    for n in notes():
        row = {"id": n["id"], "name": n["name"], "file": n["file"], "project": n["project"], "pid": n.get("pid", 0),
               "paused": bool(n.get("paused")), "stopped": bool(n.get("stopped")), "done": n.get("done") or 0,
               "started": n.get("started") or 0, "desks": [], "needs": [], "error": ""}
        row["state"] = ("done" if row["done"] else "stopped" if row["stopped"] else "paused" if row["paused"]
                        else "running" if alive(row["pid"]) else "not running")
        try:
            plan = read_plan(n["file"])
            state = plan_view(api, plan, n)
        except PlanError as e:
            row["error"] = str(e)
            out.append(row)
            continue
        row["gate"] = plan["gate"]
        row["at_once"] = plan["at_once"]
        for topic, v in state["views"].items():
            row["desks"].append({"topic": topic, "folder": v["folder"], "line": v["line"], "released": v["released"],
                                 "tasks": [{"name": s["task"]["name"], "state": s["state"], "words": s["words"],
                                            "rounds": s["rounds"]} for s in v["tasks"]]})
        row["needs"] = state["needs"]
        out.append(row)
    return out


def main(api, argv):
    """vikix agents plan ..."""
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip().split("\n\n", 1)[0])
        print("\nvikix agents plan run FILE [--here|--once] | status [PLAN] | pause PLAN | stop PLAN | release DESK | log PLAN")
        return 0
    verb, words = argv[0], argv[1:]
    if verb == "run":
        here = "--here" in words
        once = "--once" in words
        words = [w for w in words if not w.startswith("--")]
        if len(words) != 1:
            raise PlanError("vikix agents plan run FILE [--here | --once]")
        plan = read_plan(words[0])
        pid = plan_id(plan["file"])
        note = note_read(pid)
        if note and alive(note.get("pid")) and not (here or once):
            if note.get("paused") or note.get("stopped"):
                note_change(pid, lambda n: n.update(paused=False, stopped=False))
                print(f"plan {plan['name']} carries on (its runner, pid {note['pid']}, was {'paused' if note.get('paused') else 'stopping'})")
            else:
                print(f"plan {plan['name']} is running already (pid {note['pid']}); vikix agents plan status {plan['name']} says where it stands")
            return 0
        if note:
            note.update(paused=False, stopped=False, done=0, failed={}, file=plan["file"], name=plan["name"],
                        project=plan["project"])
        else:
            note = new_note(plan)
        # Another running plan with one of these desks would put two workers at one.
        for other in notes():
            if other["id"] != pid and alive(other.get("pid")) and not other.get("done"):
                try:
                    shared = set(read_plan(other["file"])["desks"]) & set(plan["desks"])
                except PlanError:
                    shared = set()
                if shared and read_plan(other["file"])["project"] == plan["project"]:
                    raise PlanError(f"plan {other['name']} is running with the desk {', '.join(sorted(shared))} too: "
                                    f"stop it first, or give this plan other desks")
        note_write(note)
        state = plan_view(api, plan, note)     # a project that doesn't resolve stops here, before any runner
        if once:
            loop(api, pid, to_stdout=True, once=True)
            return 0
        if here:
            return loop(api, pid, to_stdout=True)
        log = os.path.join(PLANS, pid + ".log")
        with open(log, "a") as out:
            p = subprocess.Popen(agents_cmd() + ["plan", "loop", pid], stdin=subprocess.DEVNULL, stdout=out,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        note_change(pid, lambda n_: n_.update(pid=p.pid))   # the loop writes the same; status asked at once sees it
        n = len(plan["tasks"])
        print(f"plan {plan['name']} runs (pid {p.pid}): {n} task{'s' if n != 1 else ''} at {len(plan['desks'])} desk"
              f"{'s' if len(plan['desks']) != 1 else ''} of {plan['project']}; vikix agents plan status {plan['name']} "
              f"says where it stands, {api.short(log)} what it did")
        for line in status_lines(api, state, note)[1:]:
            print(line)
        return 0
    if verb == "loop":
        if len(words) != 1:
            raise PlanError("vikix agents plan loop ID (plan run starts it)")
        return loop(api, words[0])
    if verb == "status":
        if not words:
            every = notes()
            if not every:
                print("no plan has run yet: vikix agents plan run FILE starts one")
                return 0
            for n in every:
                try:
                    plan = read_plan(n["file"])
                    print("\n".join(status_lines(api, plan_view(api, plan, n), n)))
                except PlanError as e:
                    print(f"Plan {n['name']} ({api.short(n['file'])}): can't be read: {e}")
                print()
            return 0
        note, path = find(words)
        plan = read_plan(path)
        print("\n".join(status_lines(api, plan_view(api, plan, note), note)))
        return 0
    if verb in ("pause", "stop"):
        note, _ = find(words)
        if not note:
            raise PlanError(f"plan {words[0]} isn't running: nothing to {verb}")
        if verb == "pause":
            note_change(note["id"], lambda n: n.update(paused=True))
            print(f"plan {note['name']} paused: the workers at work carry on, nothing new starts and no release; "
                  f"vikix agents plan run {api.short(note['file'])} carries on")
        else:
            note_change(note["id"], lambda n: n.update(stopped=True))
            if alive(note.get("pid")):
                try:
                    os.kill(int(note["pid"]), signal.SIGTERM)
                except OSError:
                    pass
            print(f"plan {note['name']} stopped: its runner ends, the workers at work carry on; "
                  f"vikix agents plan run {api.short(note['file'])} carries on from where it stands")
        return 0
    if verb == "release":
        if len(words) != 1:
            raise PlanError("vikix agents plan release DESK: your yes to the release of that desk")
        topic = words[0].split("/")[-1]
        for n in notes():
            if n.get("done"):
                continue
            try:
                plan = read_plan(n["file"])
            except PlanError:
                continue
            hit = next((d for d in plan["desks"] if d == topic or topic.endswith("-" + d)), None)
            if hit:
                def change(x):
                    x.setdefault("yes", {})[hit] = int(time.time())
                    x.get("releases", {}).pop(hit, None)
                    x.get("failed", {}).pop(hit, None)
                    x["told"] = {k: v for k, v in x.get("told", {}).items() if not k.startswith("needs:" + hit + ":")}
                note_change(n["id"], change)
                print(f"yes to the release of {hit} (plan {n['name']}): it goes once the desk's last task is in"
                      + ("" if alive(n.get("pid")) else f"; the runner isn't running: vikix agents plan run {api.short(n['file'])}"))
                return 0
        raise PlanError(f"no plan has a desk called {topic} (vikix agents plan status names them)")
    if verb == "log":
        note, _ = find(words)
        if not note:
            raise PlanError(f"plan {words[0]} hasn't run: no log")
        try:
            with open(os.path.join(PLANS, note["id"] + ".log"), errors="replace") as f:
                sys.stdout.write(f.read())
        except OSError:
            print("nothing logged yet")
        return 0
    raise PlanError(f"vikix agents plan {verb}? run, status, pause, stop, release or log (vikix agents help plan)")
