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
        print(json.dumps(dict(task, events=events, questions=T.decisions(tid)), indent=1, ensure_ascii=False))
        return 0
    print(T.render(task, events[:40]))
    for d in T.decisions(tid):
        print(T.decision_words(d))
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


def ask_cmd(argv):
    T = tasks_module()
    if len(argv) == 2 and argv[0] == '--wait':
        limit = max(0, min(600, int(os.environ.get('VIKIX_ASK_LIMIT', '600'))))
        end = time.monotonic() + limit
        while True:
            d = T.decision(argv[1])
            if d.get('answer'):
                print(T.decision_words(d))
                return 0
            if time.monotonic() >= end:
                print('No answer yet: ' + d['id'])
                return 3
            time.sleep(min(2, max(0, end - time.monotonic())))
    words, opts = [], {'choices': []}
    while argv:
        a = argv.pop(0)
        if a == '--blocks':
            opts['blocks'] = True
        elif a in ('--choice', '--recommend', '--context', '--reason', '--desk'):
            if not argv:
                die(a + ' needs words')
            v = argv.pop(0)
            if a == '--choice':
                label, _, consequence = v.partition(':')
                opts['choices'].append({'label': label.strip(), 'consequence': consequence.strip()})
            else:
                opts[{'--recommend': 'recommended'}.get(a, a[2:])] = v
        elif a.startswith('-'):
            die('vikix agents ask: unknown option ' + a)
        else:
            words.append(a)
    if len(words) != 1:
        die('vikix agents ask "question" [--choice "label: consequence"] [--recommend LABEL] [--context TEXT] [--reason TEXT] [--blocks]')
    by, me = by_me()
    named = opts.pop('desk', '')
    folder, rec = desk_for([named] if named else [], me)
    if me and os.path.realpath(me['folder']) != os.path.realpath(folder):
        die('a worker registers decisions only for its own desk')
    tid = (rec or {}).get('task', {}).get('id') or die('this desk needs a task before it can ask a decision')
    d = T.ask(tid, words[0], by, **opts)
    attention_notify_decision(d)
    print(T.decision_words(d))
    return 0


def answer_cmd(argv):
    by, me = by_me()
    if me or by != 'user':
        die('only the user answers a decision; leave it in the Office for them')
    if len(argv) != 2:
        die('vikix agents answer DECISION "choice or free text"')
    d = tasks_module().answer(argv[0], argv[1], by)
    print(tasks_module().decision_words(d))
    return 0


def attention_notify_decision(d):
    # The same stable key is used by the Office's notifier, so opening the
    # Office after an ask does not repeat its notification.
    sys.path.insert(0, os.path.join(VIKIX_DIR, "lib"))
    import office as office_view
    office_view.notify_attention([{'id': d['id'], 'kind': 'decision', 'why': d['question']}], tasks_module().OFFICE)


def attention_cmd(argv):
    sys.path.insert(0, os.path.join(VIKIX_DIR, "lib"))
    import office as office_view
    if any(a not in ('--json', '--menu', '--notify') for a in argv):
        die('vikix agents attention [--json | --menu | --notify]')
    snap = office_view.snapshot(sys.modules[__name__])
    rows = snap['attention']
    if '--notify' in argv:
        office_view.remember_titles(snap, tasks_module().OFFICE)
        office_view.notify_attention(rows, tasks_module().OFFICE)
    if '--json' in argv:
        print(json.dumps(rows, ensure_ascii=False, indent=1))
    elif '--menu' in argv:
        labels = [f"{r['kind']}: {r['title']} — {r['why']}" for r in rows]
        if not labels:
            print('Nothing needs attention.')
            return 0
        result = subprocess.run(['rofi', '-dmenu', '-i', '-p', 'Needs attention', '-format', 'i'],
                                input='\n'.join(labels), text=True, capture_output=True)
        if result.returncode == 0 and result.stdout.strip().isdigit():
            row = rows[int(result.stdout.strip())]
            if row.get('question'):
                d = row['question']
                choices = [c['label'] for c in d['choices']]
                result = subprocess.run(['rofi', '-dmenu', '-i', '-p', d['question']],
                                        input='\n'.join(choices), text=True, capture_output=True)
                if result.returncode == 0 and result.stdout.strip():
                    return answer_cmd([d['id'], result.stdout.strip()])
            elif row.get('pid'):
                office_view.focus(sys.modules[__name__], str(row['pid']))
    else:
        for r in rows:
            age = f"{max(0, (int(time.time()) - r['since']) // 60)} min" if r.get('since') else 'time unknown'
            worker = r['worker'] or r['provider'] or 'worker unknown'
            seq = f"#{r['seq']}" if r.get('seq') else 'launch order unknown'
            print(f"{r['kind']}: {r['project']} · {r['title']} [{r.get('task') or 'office'}] · {worker}, {seq} — {r['why']} ({age})")
        if not rows:
            print('Nothing needs attention.')
    return 0
