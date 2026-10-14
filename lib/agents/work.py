"""The work: the tasks (lib/tasks.py's records), one's page with its history,
the event log read back, and the launcher's exit line (vikix agents exited).

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import json
import os
import re
import sys
import time


# --- The tasks: a record each, apart from the desk and the agent --------------------------------
def tasks_cmd(argv):
    """vikix agents tasks [--json] [--all] | adopt: every task, the open ones
    in launch order (the unnumbered after, then by when they were made), the
    done ones of the last day after them (--all: every one); adopt makes
    the records for the desks from before."""
    T = tasks_module()
    H = handoff_module()
    if argv == ["adopt"]:
        made = T.adopt(H.all_records())
        print(f"{len(made)} task record{'s' if len(made) != 1 else ''} made from the desks' records"
              + (": " + ", ".join(made[:10]) + (", …" if len(made) > 10 else "") if made else "; nothing was waiting"))
        return 0
    as_json, every = False, False
    for a in argv:
        if a == "--json":
            as_json = True
        elif a == "--all":
            every = True
        else:
            die("vikix agents tasks [--json] [--all] | adopt")
    tasks = T.all_tasks()
    if as_json:
        print(json.dumps(tasks, indent=1, ensure_ascii=False))
        return 0
    if not tasks:
        print("No task yet: vikix agents worker DESK \"the task\" starts one at a desk, vikix agents tasks adopt "
              "makes records for the desks from before.")
        return 0
    open_, done = tasks_split(tasks, every)
    print(f"{len(open_)} task{'s' if len(open_) != 1 else ''} open" + (f", {len(done)} done" if done else "")
          + f"; the last launch number is {T.sequence()}:")
    for t in open_:
        print("  " + T.row_words(t))
    if done:
        print("Done" + ("" if every else " in the last day (--all for every one)") + ":")
        for t in done:
            print("  " + T.row_words(t))
    return 0


def tasks_split(tasks, every=False):
    """TASKS as (the open ones in launch order, the numbered first, then by
    when they were made; the done ones newest first, the last day's unless
    EVERY)."""
    T = tasks_module()
    open_ = [t for t in tasks if (t.get("status") or {}).get("value") not in T.FINAL]
    open_.sort(key=lambda t: (0 if (t.get("launch") or {}).get("seq") else 1, (t.get("launch") or {}).get("seq") or 0,
                              t.get("created") or 0))
    done = [t for t in tasks if (t.get("status") or {}).get("value") in T.FINAL
            and (every or (t.get("done") or 0) > time.time() - 86400)]
    done.sort(key=lambda t: -(t.get("done") or 0))
    return open_, done


def task_cmd(argv):
    """vikix agents task ID [--json]: one task's page, with its history."""
    T = tasks_module()
    as_json, words = False, []
    for a in argv:
        if a == "--json":
            as_json = True
        elif a.startswith("-"):
            die("vikix agents task ID [--json]")
        else:
            words.append(a)
    if len(words) != 1:
        die("vikix agents task ID [--json] (vikix agents tasks lists them; a desk's is in its handoff)")
    tid = words[0]
    if not T.task_id_ok(tid):
        # A desk's name: its task.
        folder, rec = desk_for([tid])
        tid = ((rec or {}).get("task") or {}).get("id") or die(f"{short(folder)} has no task record (vikix agents tasks adopt "
                                                               "makes one for a desk from before)")
    task = T.load(tid) or die(f"no task {tid} (vikix agents tasks lists them)")
    events = T.events_read(task=tid, limit=200)
    if as_json:
        print(json.dumps(dict(task, events=events), indent=1, ensure_ascii=False))
        return 0
    print(T.render(task, events[:40]))
    return 0


def since_of(text):
    """WHEN as epoch seconds: a span back from now (2h, 30 min, 3 days), a
    date (2026-10-10), or a number of seconds since the epoch."""
    H = handoff_module()
    text = text.strip()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", text):
        return int(time.mktime(time.strptime(text, "%Y-%m-%d")))
    if text.isdigit() and int(text) > 10 ** 9:
        return int(text)
    minutes = H.minutes_of(text)
    if not minutes:
        die(f"--since takes a span (2h, 30 min, 3 days), a date (2026-10-10) or seconds since the epoch, not '{text}'")
    return int(time.time()) - minutes * 60


def events_cmd(argv):
    """vikix agents events [TASK | DESK | --all] [--since WHEN] [--limit N]
    [--json]: the event log, newest first: a task's, a desk's, or all;
    none named: the desk you sit at."""
    T = tasks_module()
    H = handoff_module()
    as_json, every, since, limit, words = False, False, 0, 100, []
    while argv:
        a = argv.pop(0)
        if a == "--json":
            as_json = True
        elif a == "--all":
            every = True
        elif a == "--since":
            since = since_of(argv.pop(0) if argv else die("--since when? (2h, 2026-10-10)"))
        elif a == "--limit":
            n = argv.pop(0) if argv else "?"
            limit = int(n) if n.isdigit() and int(n) > 0 else die(f"--limit N: a number, not '{n}'")
        elif a.startswith("-"):
            die(f"vikix agents events: {a}? (vikix agents help)")
        else:
            words.append(a)
    task = desk = None
    if not every:
        if len(words) == 1 and T.task_id_ok(words[0]):
            task = words[0]
        else:
            folder, rec = desk_for(words)
            desk = (rec or {}).get("desk", {}).get("id") or H.desk_id(common_of(folder), folder)
    got = T.events_read(task=task, desk=desk, since=since, limit=limit)
    if as_json:
        print(json.dumps(got, indent=1, ensure_ascii=False))
        return 0
    if not got:
        print("No event" + (f" for {task}" if task else f" for desk {desk}" if desk else "") + (" since then" if since else "")
              + " (the log: ~/.local/state/vikix/office/events-YYYY-MM.jsonl).")
        return 0
    for e in got:
        print(T.event_line(e))
    return 0


def exited_cmd(argv):
    """vikix agents exited --code N [--task ID]: the launcher's exit line
    (exit_line in desks.py): the worker's process ended with code N; the
    task's last launch ends, the event exited is appended, and from running
    the task is blocked on its worker. Without --task, the desk this shell
    is in names it. Never fails the shell it runs in."""
    code, tid = None, ""
    while argv:
        a = argv.pop(0)
        if a == "--code":
            n = argv.pop(0) if argv else ""
            code = int(n) if re.fullmatch(r"-?\d+", n) else None
        elif a == "--task":
            tid = argv.pop(0) if argv else ""
        else:
            return 0
    try:
        if not tid:
            tid = task_id_at(os.getcwd())
        if not tid:
            return 0
        T = tasks_module()
        T.exited(tid, code=code if code is not None else -1, reason="" if code is not None else "exit code unknown", by="vikix")
    except Exception as e:  # noqa: BLE001  the exit line is a note; the terminal's end is not the place to fail
        sys.stderr.write(f"vikix agents exited: {e}\n")
    return 0
