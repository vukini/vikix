"""The tester: a desk's tests run as its work changes, the release's and the
batch's, with their results in the record.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


# --- The tester: a desk's tests, the result in its record and its inbox ----------------------------
def release_testing(folder):
    """The topic of a release of FOLDER's project whose tests are running
    now (.claude/release's note in the repository says testing), or ''."""
    common = common_of(folder)
    if not common:
        return ""
    for _, (topic, state, *_) in read_notes(os.path.join(common, "vikix-release-queue"), 5):
        if state.startswith("testing"):
            return topic
    return ""


def run_tests(where, runner, changed, base, log):
    """The runner in WHERE, all it says to LOG. (ok, the failed tests'
    names, a few lines of the first failure)."""
    cmd = [runner] + (["--changed", base] if changed and base else [])
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log, "w") as out:
        try:
            r = subprocess.run(cmd, cwd=where, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT)
            code = r.returncode
        except OSError as e:
            out.write(f"{runner}: {e}\n")
            code = 127
    try:
        with open(log, errors="replace") as f:
            text = f.read()
    except OSError:
        text = ""
    failed = re.findall(r"^FAILED: (.*)$", text, re.M)
    names = failed[-1].split() if failed else []
    ok = code == 0 and not names
    if not ok and not names:
        names = [f"exit {code}"]
    fails = [line.strip() for line in text.splitlines() if line.startswith("FAIL")][:3]
    excerpt = " | ".join(fails) if fails else " | ".join(line.strip() for line in text.splitlines()[-5:])
    return ok, names, excerpt


def tester_result(folder, name, ok, names, excerpt, took, note=""):
    """The run's result into the desk's record (a check by vikix) and its inbox; said."""
    H = handoff_module()
    words = (f"passed in {took} s" if ok else f"failed: {', '.join(names)}; {excerpt}")
    full = ((note + "; ") if note else "") + words
    base = base_of(folder)[0]

    def change(r):
        H.add_check(r, name, ok, "vikix", folder, full[:480])
        H.set_changes(r, folder, base)       # what the hand-in shows as changed, read again now
    desk_record(folder, by="vikix", change=change)
    line = (f"tests passed ({name}, {took} s)" if ok else
            f"tests: {len(names)} failed ({', '.join(names)}); vikix agents test --log {os.path.basename(folder)} shows them")
    if note:
        line += f" [{note}]"
    try:
        inbox_add(folder, line, "vikix")
    except H.HandoffError:
        pass
    print(f"{short(folder)}: {line}")
    return ok


def test_desk(folder, note=""):
    """One desk's tests, in its worktree. True, False, or None when the
    project has no runner (said; no check, no note)."""
    where, runner, changed = runner_of(folder)
    if not runner:
        print(f"{short(folder)}: no tests/run.sh in this project, nothing to run")
        return None
    base, _, _ = base_of(folder)
    log, running = tester_paths(folder)
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(running, "w") as f:
        f.write(f"{os.getpid()} {int(time.time())}\n")
    started = time.time()
    waited = 0
    try:
        # A release's tests and a desk's at once failed two timing checks for
        # load alone (2026-10-09), and the release is the one that merges: it
        # has the machine first. The running note is written already, so a
        # second tester isn't started meanwhile. Not for a change no test
        # covers (a plan, a design): the whole wait, then one second's run,
        # was "passed in 1801 s" (2026-10-11).
        topic = release_testing(folder) if changed_covers(where, base) else ""
        if topic:
            print(f"{short(folder)}: a release of {topic} is testing; waiting for it")
        step = min(5, max(1, RELEASE_WAIT))
        while topic and waited < RELEASE_WAIT:
            time.sleep(step)
            waited += step
            topic = release_testing(folder)
        ok, names, excerpt = run_tests(where, runner, changed, base, log)
    finally:
        try:
            os.unlink(running)
        except OSError:
            pass
    name = "tests/run.sh" + (f" --changed {base[:7]}" if changed and base else "")
    if waited:
        note = (note + "; " if note else "") + f"waited {waited} s for a release's tests first"
    return tester_result(folder, name, ok, names, excerpt, int(time.time() - started) - waited, note)


def changed_covers(where, base):
    """Whether a test covers the desk's change: the project's
    tests/changed.sh BASE (Vikix's map of files to tests) names one, or
    says all; True when the project has no such map, or it fails."""
    mapper = os.path.join(where or "", "tests", "changed.sh")
    if not where or not base or not os.access(mapper, os.X_OK):
        return True
    try:
        r = subprocess.run([mapper, base], cwd=where, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return True
    return r.returncode != 0 or bool(r.stdout.strip())


def tester_state(folder, lines=8):
    """The tester at work on the desk FOLDER, for the Office's Testing box:
    its pid, since when (from the running note), what it runs (the runner's
    line, as the check will be named), the log's last LINES (the runner
    prints each test's output whole when it ends, so the tail is the tests
    ended so far), the log's path, and the release whose tests it waits
    for ('' for none: the wait is the tester's own, so it is told by an
    empty log and a release of the project testing). {} when none runs."""
    pid = tester_running(folder)
    if not pid:
        return {}
    log, running = tester_paths(folder)
    at = 0
    try:
        with open(running) as f:
            at = int(f.read().split()[1])
    except (OSError, ValueError, IndexError):
        pass
    tail = []
    try:
        with open(log, errors="replace") as f:
            tail = [line.rstrip("\n")[:200] for line in f.readlines()[-lines:]]
    except OSError:
        pass
    _, runner, changed = runner_of(folder)
    base = base_of(folder)[0] if runner else ""
    name = ("tests/run.sh" + (f" --changed {base[:7]}" if changed and base else "")) if runner else ""
    return {"pid": pid, "at": at, "name": name, "log": log, "tail": tail,
            "waiting": release_testing(folder) if not tail else ""}


def tester_of(pid):
    """Whether PID is a tester: its command line, read from the kernel's
    /proc (the pid is the kernel's, never the made-up /proc of the tests),
    runs this script with test (the desk's running note was written by
    that pid; this guards against the number reused since)."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            args = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return False
    me = os.path.basename(os.path.realpath(__file__))
    return any(os.path.basename(a) == me and args[i + 1:i + 2] == ["test"] for i, a in enumerate(args[:-1]))


def tree_of(pid):
    """PID's descendants, the deepest first, from the kernel's /proc: what
    to end after PID itself (read before it ends, since its children go
    to init then and can't be found under it any more)."""
    parents = {}
    try:
        names = os.listdir("/proc")
    except OSError:
        return []
    for entry in names:
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                stat = f.read()
            parents.setdefault(int(stat[stat.rindex(")") + 2:].split()[1]), []).append(int(entry))
        except (OSError, ValueError, IndexError):
            continue
    out = []

    def walk(p):
        for child in parents.get(p, []):
            walk(child)
            out.append(child)
    walk(pid)
    return out


def tester_skip(folder, by="user"):
    """The desk's tests, running, not waited for: the tester ended (the
    tester first, so it records no failure of a run it didn't finish,
    then the runner and its tests under it; the runner's own trap ends
    what it started), its running note removed, a check marked skipped in
    the record (ok, on the commit as it stands, so a plan's chain goes on
    from the hand-in; the release never counts a skipped check for a run
    of its own), and a line in the inbox. What was said. Raises
    HandoffError when no tester is at work there."""
    import signal
    H = handoff_module()
    pid = tester_running(folder)
    if not pid:
        raise H.HandoffError(f"{short(folder)}: no tester is at work there (vikix agents test {os.path.basename(folder)} runs them)")
    if not tester_of(pid):
        raise H.HandoffError(f"{short(folder)}: pid {pid} in its running note isn't a tester of this desk; left alone")
    log, running = tester_paths(folder)
    at = 0
    try:
        with open(running) as f:
            at = int(f.read().split()[1])
    except (OSError, ValueError, IndexError):
        pass
    below = tree_of(pid)
    for p in [pid] + below:
        try:
            os.kill(p, signal.SIGTERM)
        except OSError:
            pass
    deadline = time.time() + 10
    while time.time() < deadline and any(not process_gone(p) for p in [pid] + below):
        time.sleep(0.1)
    for p in [pid] + below:
        if not process_gone(p):
            try:
                os.kill(p, signal.SIGKILL)
            except OSError:
                pass
    try:
        os.unlink(running)
    except OSError:
        pass
    _, _, changed = runner_of(folder)
    base = base_of(folder)[0]
    name = "tests/run.sh" + (f" --changed {base[:7]}" if changed and base else "")
    ran = f" after {int(time.time() - at)} s" if at else ""
    note = f"skipped by {by}{ran}: the tests were not waited for; the release runs its own"

    def change(r):
        H.add_check(r, name, True, by, folder, note, skipped=True)
    desk_record(folder, by=by, change=change)
    line = f"tests skipped by {by}{ran} (vikix agents test --skip): not waited for; the release runs its own"
    try:
        inbox_add(folder, line, by)
    except H.HandoffError:
        pass
    return f"{short(folder)}: {line}"


def test_batch(own, own_branch, batch):
    """BATCH, desks of one project that changed no file in common, merged
    onto the project's own branch in a throwaway worktree and tested there
    once; the check and the note on each. The desks a merge conflict kept
    out, to run alone."""
    tmp = tempfile.mkdtemp(prefix="vikix-tester-")
    wt = os.path.join(tmp, "batch")
    dropped, merged = [], []
    try:
        if git(own, "worktree", "add", "--detach", wt, own_branch) is None:
            return batch
        for d in batch:
            r = subprocess.run(["git", "-C", wt, "merge", "--no-ff", "-q", "-m", f"batch: {d['branch']}", d["branch"]],
                               capture_output=True, text=True)
            if r.returncode:
                subprocess.run(["git", "-C", wt, "merge", "--abort"], capture_output=True, text=True)
                d["note"] = "a merge conflict kept it out of the batch"
                dropped.append(d)
            else:
                merged.append(d)
        if len(merged) < 2:
            return dropped + merged
        where, runner, changed = runner_of(wt)
        base = (git(wt, "rev-parse", own_branch) or "").strip()
        log = os.path.join(STATE, "vikix", "office", "tests", f"batch-{int(time.time())}.log")
        started = time.time()
        ok, names, excerpt = run_tests(where, runner, changed, base, log)
        took = int(time.time() - started)
        name = "tests/run.sh" + (f" --changed {base[:7]}" if changed and base else "") + " (batch)"
        for d in merged:
            others = ", ".join(short(o["folder"]) for o in merged if o is not d)
            shutil.copyfile(log, tester_paths(d["folder"])[0])
            tester_result(d["folder"], name, ok, names, excerpt, took, f"with {others}")
        return dropped
    finally:
        subprocess.run(["git", "-C", own, "worktree", "remove", "--force", wt], capture_output=True, text=True)
        shutil.rmtree(tmp, ignore_errors=True)


def test_all():
    """Every desk in review: the disjoint ones of a project together, the
    overlapping ones alone, told which they overlap."""
    H = handoff_module()
    review = [r for r in H.all_records()
              if ((r.get("handoff") or {}).get("status") or {}).get("value") == "review"
              and not r["desk"].get("closed") and os.path.isdir(r["desk"]["worktree"])]
    for r in [r for r in review if r["desk"].get("tests") == "off"]:
        # Its tests are the user's to run: vikix agents test DESK does.
        print(f"{short(r['desk']['worktree'])}: in review, its tests not run by themselves (--no-tests); left out")
        review.remove(r)
    if not review:
        print("no desk is in review (vikix agents handoff list)")
        return 0
    desks = []
    for r in review[::-1]:                       # in the order they went to review
        folder = r["desk"]["worktree"]
        base, own, own_branch = base_of(folder)
        files = set((git(folder, "diff", "--name-only", base) or "").split()) if base else set()
        branch = r["desk"].get("branch") or (git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
        desks.append({"folder": folder, "own": own, "own_branch": own_branch, "files": files, "branch": branch, "note": ""})
    for own in dict.fromkeys(d["own"] for d in desks):
        mine = [d for d in desks if d["own"] == own]
        batch, alone = [], []
        for d in mine:
            # In the order they went to review: a desk joins the batch when it changed no
            # file the batch has; else it runs alone, told which desk it overlaps on what.
            overlap = [(o, d["files"] & o["files"]) for o in batch if d["files"] & o["files"]]
            if overlap:
                d["note"] = "; ".join(f"overlaps {short(o['folder'])} on {', '.join(sorted(f)[:3])}" for o, f in overlap)
                alone.append(d)
            elif d["files"] and own and runner_of(d["folder"])[1]:
                batch.append(d)
            else:
                alone.append(d)
        if len(batch) >= 2:
            alone += test_batch(own, mine[0]["own_branch"], batch)
        else:
            alone += batch
        for d in alone:
            test_desk(d["folder"], d["note"])
    return 0


def tester(argv):
    """vikix agents test [DESK | --all] [--log DESK] [--skip DESK]."""
    if argv == ["--all"]:
        return test_all()
    if argv and argv[0] == "--skip":
        H = handoff_module()
        by, me = by_me()
        folder, _ = desk_for(argv[1:], me)
        try:
            print(tester_skip(folder, by))
        except H.HandoffError as e:
            die(str(e))
        return 0
    if argv == ["--menu"]:
        folder = pick_desk("Test", "Its tests run in its worktree; the result goes into its handoff and its agent's inbox.")
        if folder is None:
            return 0
        if not runner_of(folder)[1]:
            say(f"{short(folder)}: no tests/run.sh in this project, nothing to run")
            return 0
        if tester_running(folder):
            say(f"{short(folder)}: a tester is at work there already")
            return 0
        tester_start(folder)
        say(f"{short(folder)}: its tests run; the result goes into its handoff and its agent's inbox")
        return 0
    show = "--log" in argv
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) - (1 if show else 0):
        die("vikix agents test [DESK | --all] [--log DESK] [--skip DESK]")
    by, me = by_me()
    folder, _ = desk_for(words, me)
    if show:
        log, _ = tester_paths(folder)
        try:
            with open(log, errors="replace") as f:
                sys.stdout.write(f.read())
        except OSError:
            print(f"{short(folder)}: no test run yet (vikix agents test {os.path.basename(folder)})")
        return 0
    pid = tester_running(folder)
    if pid:
        die(f"{short(folder)}: a tester is at work there already (pid {pid})")
    test_desk(folder)
    return 0


# --- The reviewer: another provider reads a desk's commit, read-only, in a throwaway worktree -------
# Who can review, and how it is run with no window and no prompt: the
# program, read-only, a schema for its answer. Codex's exec takes the schema
# as a file and writes its last message to one (-o); Claude Code's -p takes
# the schema on the line and answers JSON on stdout. Neither sits at the
# desk: the worktree is the reviewer's own and gone afterwards.
REVIEWERS = ("codex", "claude")
REVIEW_LIMIT = int(os.environ.get("VIKIX_REVIEW_LIMIT") or 1800)
# What a reviewer answers: each finding where it is (FILE:LINE, or ""), how
# much it matters, and the words a person acts on. Every key required and
# nothing else allowed, which is the shape Codex's structured output wants.
FINDINGS_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string", "description": "A line or two on the work as a whole."},
        "findings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "where": {"type": "string", "description": "FILE:LINE in the worktree, or an empty string."},
                    "severity": {"type": "string", "enum": ["high", "medium", "low"]},
                    "text": {"type": "string", "description": "One or two sentences a person acts on."},
                },
                "required": ["where", "severity", "text"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["summary", "findings"],
    "additionalProperties": False,
}


def review_paths(folder):
    """(the log of the desk's last review, the note of one under way)."""
    H = handoff_module()
    d = os.path.join(STATE, "vikix", "office", "reviews")
    did = H.desk_id(common_of(folder), folder)
    return os.path.join(d, did + ".log"), os.path.join(d, did + ".reviewing")


def review_note_read(path):
    """A review's note: {pid, at, provider, worktree}, or {} for none or
    for one whose reviewer is gone (its pid is nobody's)."""
    try:
        with open(path) as f:
            pid, at, provider, worktree = f.read().rstrip("\n").split("\t", 3)
        pid = int(pid)
        os.kill(pid, 0)
        return {"pid": pid, "at": int(at), "provider": provider, "worktree": worktree}
    except (OSError, ValueError):
        return {}


def reviewer_running(folder):
    """The review under way at the desk FOLDER ({pid, at, provider, worktree}), or {}."""
    return review_note_read(review_paths(folder)[1])


def reviews_running():
    """Every review under way on the machine, by the reviewer's worktree:
    {realpath of the worktree: the note with the desk's id}. For the listing,
    which names a reviewer's process for what it is."""
    found = {}
    d = os.path.join(STATE, "vikix", "office", "reviews")
    try:
        names = os.listdir(d)
    except OSError:
        return found
    for name in names:
        if name.endswith(".reviewing"):
            note = review_note_read(os.path.join(d, name))
            if note:
                note["desk_id"] = name[:-len(".reviewing")]
                found[os.path.realpath(note["worktree"])] = note
    return found


def reviewer_program(provider):
    """The reviewer's program, on PATH or beside the agents in ~/.local/bin; '' when it isn't installed."""
    found = shutil.which(provider)
    if found:
        return found
    beside = os.path.join(os.path.expanduser("~"), ".local", "bin", provider)
    return beside if os.access(beside, os.X_OK) else ""


def reviewer_env():
    """The reviewer's environment: as vikix agent gives an agent's, the keys
    and the SSH agent withheld (it reads code; it pushes and buys nothing)."""
    env = dict(os.environ)
    if env.get("VIKIX_AGENT_API_KEY") != "1":
        for k in list(env):
            if k.endswith(("_API_KEY", "_KEY", "_KEY_ID", "_TOKEN", "_SECRET", "_PASSWORD", "_PASSWD", "_CREDENTIALS")) \
                    or k == "DATABASE_URL":
                env.pop(k, None)
    env.pop("SSH_AUTH_SOCK", None)
    env.pop("SSH_AGENT_PID", None)
    return env


def review_prompt(rec, base, branch, extra):
    """What the reviewer is asked: the work's place in git, the task and the
    hand-in it was done against, what to look for, and the answer's shape."""
    H = handoff_module()
    h = (rec or {}).get("handoff") or {}
    lines = [f"Review the work in this git worktree, read-only: the commits on the branch {branch or 'HEAD'} past "
             + (f"{base[:12]} (git log {base[:12]}..HEAD; git diff {base[:12]}...HEAD shows the whole change)" if base
                else "its base (git log shows them)")
             + ". Change nothing, run nothing that writes; read the code, the tests and the guides it touches."]
    task = ((rec or {}).get("task") or {}).get("text")
    if task:
        lines.append(f"The task it was done for: {task}")
    acc = (h.get("acceptance") or {}).get("items") or []
    if acc:
        lines.append("The acceptance criteria, as the worker ticked them: "
                     + "; ".join(f"[{'x' if i.get('done') else ' '}] {i['text']}" for i in acc))
    if h.get("decisions"):
        lines.append("Decided already, not to be reopened: " + "; ".join(i["text"] for i in h["decisions"]))
    s = h.get("summary")
    if s:
        lines.append(f"The worker's own account: {s['text']}")
    lines.append("Look for defects, a criterion claimed and not met, a case the tests don't cover, a guide, a header or "
                 "a comment out of step with the code, and anything a careful colleague would send back; not style. "
                 "Each finding is one thing, where it is as FILE:LINE in this worktree, and one or two sentences a person "
                 "acts on; severity high for a defect or a criterion not met, medium for a gap, low for a nit worth a line. "
                 "No findings is an empty list. The summary is a line or two on the work as a whole.")
    if extra:
        lines.append(H.clean(extra, "the review's words"))
    lines.append("Answer with JSON alone, of exactly this shape: " + json.dumps(FINDINGS_SCHEMA, separators=(",", ":")))
    return "\n\n".join(lines)


def reviewer_command(provider, program, worktree, prompt, schema_file, out_file):
    """The reviewer's command line: Codex's exec or Claude Code's -p, read-only, the schema given."""
    if provider == "codex":
        cmd = [program, "exec", "--cd", worktree, "-s", "read-only", "-c", 'approval_policy="never"', "--ephemeral",
               "--color", "never", "--output-schema", schema_file, "-o", out_file]
        # The hooks' trust, as vikix agent passes it: Vikix's own hook file, in a project of the user's.
        hooks = os.path.join(os.path.expanduser("~"), ".codex", "hooks.json")
        ours = os.path.join(VIKIX_DIR, "config", "codex", "hooks.json")
        if os.environ.get("VIKIX_CODEX_HOOK_TRUST") != "ask" and os.path.exists(hooks) \
                and os.path.realpath(hooks) == os.path.realpath(ours) and common_of(worktree) in known_repos():
            cmd.append("--dangerously-bypass-hook-trust")
        return cmd + [prompt]
    return [program, "-p", "--permission-mode", "plan", "--output-format", "json",
            "--json-schema", json.dumps(FINDINGS_SCHEMA, separators=(",", ":")), prompt]


def review_parse(provider, out_file, stdout):
    """The reviewer's answer as (summary, findings) from the file Codex
    wrote or the JSON Claude Code printed; a text that isn't the shape is
    one finding holding it, so a review is never lost for its form."""
    text = ""
    try:
        with open(out_file, errors="replace") as f:
            text = f.read().strip()
    except OSError:
        pass
    if not text:
        text = stdout.strip()
    data = None
    try:
        data = json.loads(text)
    except ValueError:
        start, end = text.find("{"), text.rfind("}")
        if 0 <= start < end:
            try:
                data = json.loads(text[start:end + 1])
            except ValueError:
                data = None
    if isinstance(data, dict) and provider == "claude" and "findings" not in data:
        # claude -p --output-format json: the answer under structured_output, or result as text.
        inner = data.get("structured_output")
        if not isinstance(inner, dict):
            inner = data.get("result")
            if isinstance(inner, str):
                try:
                    inner = json.loads(inner[inner.find("{"):inner.rfind("}") + 1])
                except ValueError:
                    inner = {"summary": "", "findings": [{"where": "", "severity": "medium", "text": inner}]}
        data = inner if isinstance(inner, dict) else None
    if not isinstance(data, dict) or not isinstance(data.get("findings"), list):
        words = text[:900].replace("\n", " ").strip()
        return "", ([{"where": "", "severity": "medium", "text": words}] if words else [])
    findings = []
    for f in data["findings"]:
        if not isinstance(f, dict) or not str(f.get("text") or "").strip():
            continue
        where = str(f.get("where") or "").strip()
        sev = str(f.get("severity") or "").strip().lower()
        findings.append({"where": where if re.fullmatch(r"\S+:\d+", where) else "",
                         "severity": sev if sev in ("high", "medium", "low") else "medium",
                         "text": str(f["text"]).strip()})
    return str(data.get("summary") or "").strip(), findings


def review_result(folder, provider, pid, summary, findings, took, failure=""):
    """The review into the desk's record (the findings in review, each
    signed by the reviewer; a line in the log) and its inbox; said."""
    H = handoff_module()
    by = f"{provider} {pid}" if pid else provider
    n = len(findings)
    high = sum(1 for f in findings if f["severity"] == "high")
    lines = [((f"{f['where']} " if f["where"] else "") + (f"[{f['severity']}] " if f["severity"] != "medium" else "") + f["text"])
             for f in findings]

    def change(rec):
        if lines:
            H.set_handoff(rec, by, review=lines)
        H._log(rec, by, (f"review: {failure}" if failure else
                         f"review: {n} finding{'s' if n != 1 else ''}" + (f", {high} high" if high else "")
                         + (f"; {summary}" if summary else "")))
    desk_record(folder, by=by, change=change)
    if failure:
        line = f"review by {provider} failed: {failure} (vikix agents review --log {os.path.basename(folder)} shows its words)"
    elif n:
        line = (f"review by {by} ({took} s): {n} finding{'s' if n != 1 else ''}" + (f", {high} high" if high else "")
                + ", in your handoff's Review (vikix agents handoff): address each and mark it with "
                "vikix agents handoff --review-done N" + (f". {summary}" if summary else ""))
    else:
        line = f"review by {by} ({took} s): no findings" + (f". {summary}" if summary else "")
    try:
        inbox_add(folder, line, "vikix")
    except H.HandoffError:
        pass
    print(f"{short(folder)}: {line}")
    if n and not failure:
        # A worker that handed in sits at its prompt and makes no tool call, so the
        # findings would wait unread: one at its prompt is resumed with them as its prompt.
        woken, said = wake(folder, line, "vikix")
        print(f"{short(folder)}: {said}")
        if not woken and os.environ.get("DISPLAY") and shutil.which("notify-send"):
            subprocess.run(["notify-send", "-a", "Vikix", f"Review of {short(folder)}: {n} finding{'s' if n != 1 else ''}",
                            said[:200]], check=False)
    return not failure


def review_desk(folder, provider, extra=""):
    """One review of the desk's HEAD by PROVIDER: a throwaway worktree of
    that commit beside nothing of the desk's, the reviewer run in it with no
    window and no way to write, its answer into the record and the inbox,
    the worktree removed. True when the reviewer answered, False when it failed."""
    H = handoff_module()
    program = reviewer_program(provider)
    if not program:
        die(f"{provider} isn't installed here: vikix agent --install {provider} (the reviewers: {', '.join(REVIEWERS)})")
    head = (git(folder, "rev-parse", "HEAD") or "").strip()
    if not head:
        die(f"{short(folder)} has no commit to review")
    base, _, _ = base_of(folder)
    branch = (git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
    rec = H.load(H.desk_id(common_of(folder), folder)) or {}
    dirty = (H.observe(folder) or {}).get("dirty") or 0
    if dirty:
        print(f"{short(folder)}: {dirty} uncommitted file{'s' if dirty != 1 else ''} left out: the review is of its last commit, {head[:7]}")
    log, running = review_paths(folder)
    os.makedirs(os.path.dirname(log), exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="vikix-review-")
    wt = os.path.join(tmp, "review")
    started = time.time()
    proc = None
    try:
        if git(folder, "worktree", "add", "--detach", wt, head) is None:
            die(f"{short(folder)}: git couldn't make the reviewer's worktree (git worktree add)")
        schema_file, out_file = os.path.join(tmp, "findings.schema.json"), os.path.join(tmp, "findings.json")
        with open(schema_file, "w") as f:
            json.dump(FINDINGS_SCHEMA, f)
        prompt = review_prompt(rec, base, branch, extra)
        cmd = reviewer_command(provider, program, wt, prompt, schema_file, out_file)
        with open(log, "w") as out:
            out.write(f"# review of {short(folder)} at {head[:12]} by {provider}, {time.strftime('%Y-%m-%d %H:%M')}\n")
            out.write("# " + " ".join(shlex.quote(w) for w in cmd[:-1]) + " PROMPT\n\n")
            out.flush()
            try:
                proc = subprocess.Popen(cmd, cwd=wt, env=reviewer_env(), stdin=subprocess.DEVNULL,
                                        stdout=subprocess.PIPE, stderr=out, text=True, start_new_session=True)
            except OSError as e:
                out.write(f"{program}: {e}\n")
                return review_result(folder, provider, 0, "", [], 0, f"{provider} didn't start: {e}")
            with open(running, "w") as f:
                f.write(f"{proc.pid}\t{int(started)}\t{provider}\t{wt}\n")
            try:
                stdout, _ = proc.communicate(timeout=REVIEW_LIMIT)
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, _ = proc.communicate()
                out.write(f"\n# stopped after {REVIEW_LIMIT} s (VIKIX_REVIEW_LIMIT)\n")
                return review_result(folder, provider, proc.pid, "", [], int(time.time() - started),
                                     f"no answer in {REVIEW_LIMIT} s")
            out.write(stdout)
        summary, findings = review_parse(provider, out_file, stdout)
        if proc.returncode and not findings and not summary:
            return review_result(folder, provider, proc.pid, "", [], int(time.time() - started), f"exit {proc.returncode}")
        return review_result(folder, provider, proc.pid, summary, findings, int(time.time() - started))
    finally:
        try:
            os.unlink(running)
        except OSError:
            pass
        subprocess.run(["git", "-C", folder, "worktree", "remove", "--force", wt], capture_output=True, text=True)
        shutil.rmtree(tmp, ignore_errors=True)


def review_start(folder, provider, extra=""):
    """A review started by itself, apart from this process (a hand-in with
    review= in the office file, the Office's button): its words to the log's side file."""
    log, _ = review_paths(folder)
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log + ".reviewer", "w") as out:
        subprocess.Popen([sys.executable, os.path.realpath(__file__), "review", folder, "--use", provider, "--here"]
                         + (["--prompt", extra] if extra else []), cwd=folder,
                         stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)


def review_auto(folder):
    """The reviewer the office file names for a hand-in (review=PROVIDER in
    ~/.config/vikix/office), '' when none: off by default, since a review
    costs a model's time and is asked for, not assumed."""
    if os.environ.get("VIKIX_REVIEWER") == "0":
        return ""
    provider = office_setting("review").strip()
    return provider if provider in REVIEWERS else ""


def review(argv):
    """vikix agents review DESK [--use NAME] [--prompt "..."] [--here] | --log DESK | --menu."""
    if argv == ["--menu"]:
        folder = pick_desk("Review", "Another provider reads the desk's last commit, read-only; its findings go into the handoff and the agent's inbox.")
        if folder is None:
            return 0
        offered = [p for p in REVIEWERS if reviewer_program(p)]
        provider = rofi("Reviewer", "Which: " + ", ".join(offered)) if len(offered) > 1 else (offered[0] if offered else "")
        if not provider:
            return 0
        if provider not in REVIEWERS or not reviewer_program(provider):
            say(f"{provider} can't review here (the reviewers: {', '.join(offered) or 'none installed'})")
            return 0
        if reviewer_running(folder):
            say(f"{short(folder)}: a review is under way there already")
            return 0
        review_start(folder, provider)
        say(f"{short(folder)}: {provider} reviews its last commit; the findings go into its handoff and its agent's inbox")
        return 0
    use, extra, show, words, here = None, "", False, [], False
    while argv:
        a = argv.pop(0)
        if a == "--use":
            use = argv.pop(0) if argv else die("--use which reviewer? " + ", ".join(REVIEWERS))
        elif a == "--prompt":
            extra = argv.pop(0) if argv and argv[0].strip() else die("--prompt needs words for the reviewer")
        elif a == "--log":
            show = True
        elif a == "--here":
            here = True
        elif a.startswith("-"):
            die(f"vikix agents review: {a}? (vikix agents help review)")
        else:
            words.append(a)
    by, me = by_me()
    folder, _ = desk_for(words, me)
    if show:
        log, _ = review_paths(folder)
        try:
            with open(log, errors="replace") as f:
                sys.stdout.write(f.read())
        except OSError:
            print(f"{short(folder)}: no review yet (vikix agents review {os.path.basename(folder)} --use codex)")
        return 0
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: nothing to review")
    provider = use or ""
    if not provider:
        # The other provider: not the one at the desk, nor the one that last worked there.
        H = handoff_module()
        rec = H.load(H.desk_id(common_of(folder), folder)) or {}
        there = [a["agent"] for a in agents_at(folder)] + [s.get("provider") for s in rec.get("sessions") or []]
        last = next((p for p in there if p), "")
        provider = next((p for p in REVIEWERS if p != last and reviewer_program(p)), "")
        if not provider:
            die(f"--use which reviewer? {', '.join(REVIEWERS)} (none other than {last or 'the desk\'s'} is installed)")
    if provider not in REVIEWERS:
        die(f"{provider} can't review: the reviewers are {', '.join(REVIEWERS)} (run with no window, read-only)")
    note = reviewer_running(folder)
    if note:
        die(f"{short(folder)}: {note['provider']} is reviewing there already (pid {note['pid']}, since {at(note['at'])})")
    if extra:
        try:
            handoff_module().clean(extra, "the review's words")   # a credential in the words is refused, as in a note
        except handoff_module().HandoffError as e:
            die(str(e))
    if here:
        return 0 if review_desk(folder, provider, extra) else 1
    # Apart from this shell, as a hand-in's review runs: killed under a timeout, a review
    # read from a pipe here orphaned the reviewer and lost its findings (2026-10-11).
    if not reviewer_program(provider):
        die(f"{provider} isn't installed here: vikix agent --install {provider} (the reviewers: {', '.join(REVIEWERS)})")
    if not (git(folder, "rev-parse", "HEAD") or "").strip():
        die(f"{short(folder)} has no commit to review")
    review_start(folder, provider, extra)
    log, _ = review_paths(folder)
    print(f"{short(folder)}: {provider} reviews its last commit, apart from this shell; the findings go into its handoff "
          f"and its agent's inbox, and the reviewer's words to {short(log)} (vikix agents review --log "
          f"{os.path.basename(folder)}); --here would have waited for it")
    return 0
