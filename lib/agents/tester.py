"""The tester: a desk's tests run as its work changes, the release's and the
batch's, with their results in the record.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import os
import re
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


def base_of(folder):
    """Where the desk's branch left the project's own: (merge base, the
    project's own folder, its branch)."""
    top = (git(folder, "rev-parse", "--show-toplevel") or "").strip()
    own = own_folder(top) if top else ""
    own_branch = (git(own, "rev-parse", "--abbrev-ref", "HEAD") or "").strip() if own else ""
    base = (git(folder, "merge-base", "HEAD", own_branch) or "").strip() if own_branch and own_branch != "HEAD" else ""
    return base, own, own_branch


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
    desk_record(folder, by="vikix", change=lambda r: H.add_check(r, name, ok, "vikix", folder, full[:480]))
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
    try:
        # A release's tests and a desk's at once failed two timing checks for
        # load alone (2026-10-09), and the release is the one that merges: it
        # has the machine first. The running note is written already, so a
        # second tester isn't started meanwhile.
        topic = release_testing(folder)
        if topic:
            print(f"{short(folder)}: a release of {topic} is testing; waiting for it")
        waited, step = 0, min(5, max(1, RELEASE_WAIT))
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
    return tester_result(folder, name, ok, names, excerpt, int(time.time() - started), note)


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
    """vikix agents test [DESK | --all] [--log DESK]."""
    if argv == ["--all"]:
        return test_all()
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
        die("vikix agents test [DESK | --all] [--log DESK]")
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
