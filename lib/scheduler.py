"""Persistent Office queue. Reads never launch; mutations serialize on queue.lock.

Launch intents reserve capacity before opening a terminal. An ambiguous launch
is blocked for the user, never retried automatically. All workers still use the
normal desk launcher and the choices recorded on their task.
"""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

import tasks as T


def config():
    values = {'at_once': 2, 'auto': False}
    path = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'vikix/office'
    try:
        for line in path.read_text().splitlines():
            key, sep, value = line.partition('#')[0].partition('=')
            key, value = key.strip(), value.strip()
            if sep and key == 'at_once':
                values[key] = max(1, min(64, int(value)))
            elif sep and key == 'auto':
                values[key] = value == 'on'
    except FileNotFoundError:
        pass
    return values


def read(name, default):
    try:
        return json.loads((Path(T.OFFICE) / name).read_text())
    except FileNotFoundError:
        return default


def write(name, value):
    path = Path(T.OFFICE) / name
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_name(path.name + f'.{os.getpid()}.tmp')
    with tmp.open('w') as stream:
        os.chmod(tmp, 0o600)
        json.dump(value, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(tmp, path)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


@contextmanager
def locked():
    Path(T.OFFICE).mkdir(parents=True, exist_ok=True, mode=0o700)
    with (Path(T.OFFICE) / 'queue.lock').open('a') as lock:
        end = time.monotonic() + 1
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= end:
                    raise T.TaskError('the queue is busy; try again') from None
                time.sleep(.02)
        yield


def queue():
    q = read('queue.json', {'version': 1, 'order': [], 'next': None, 'paused': False})
    if not isinstance(q, dict) or q.get('version') != 1 or not isinstance(q.get('order'), list):
        raise T.TaskError('invalid queue.json; no task started')
    return q


def ordered(tasks, q):
    positions = {tid: i for i, tid in enumerate(q['order'])}
    return sorted((t for t in tasks if t['status']['value'] == 'queued'),
                  key=lambda t: (t['id'] != q.get('next'), T.PRIORITIES.index(t['priority']),
                                 positions.get(t['id'], len(positions)), t['created'], t['id']))


def require_task(tid):
    task = T.load(tid)
    if not task:
        raise T.TaskError('no task ' + tid)
    return task


def mutate(action, tid=None, value=None, by='user'):
    """User queue operations. A task left queued across a crash is still
    visible: queued records missing from order sort by creation time."""
    if by != 'user':
        raise T.TaskError('only the user changes the queue or task priorities')
    with locked():
        q = queue()
        if action in ('pause', 'go'):
            q['paused'] = action == 'pause'
            write('queue.json', q)
            return q
        t = require_task(tid)
        if t['status']['value'] in T.FINAL:
            raise T.TaskError('this task is already ' + t['status']['value'])
        if action == 'priority':
            if value not in T.PRIORITIES:
                raise T.TaskError('priority is critical, high, normal or low')
            T.update(tid, lambda t: t.update(priority=value))
            T.event('priority', by, T.load(tid), data={'priority': value})
        elif action == 'cancel':
            T.move(tid, 'cancelled', by, value or 'cancelled by user')
            q['order'] = [i for i in q['order'] if i != tid]
        elif action == 'add':
            if t['status']['value'] != 'ready':
                raise T.TaskError('only a ready task can enter the queue')
            T.move(tid, 'queued', by)
            q['order'] = [i for i in q['order'] if i != tid]
            q['order'].insert(0 if value == 'first' else len(q['order']), tid)
        else:
            if t['status']['value'] != 'queued':
                raise T.TaskError('this task is not queued')
            ids = [x['id'] for x in ordered(T.all_tasks(strict=True), q)]
            if action == 'next':
                q['next'] = tid
            elif action in ('up', 'down'):
                peers = [x['id'] for x in ordered(T.all_tasks(strict=True), dict(q, next=None)) if x['priority'] == t['priority']]
                i = peers.index(tid)
                j = i + (-1 if action == 'up' else 1)
                if 0 <= j < len(peers):
                    a, b = ids.index(tid), ids.index(peers[j])
                    ids[a], ids[b] = ids[b], ids[a]
                q['order'] = ids
            elif action == 'defer':
                T.move(tid, 'backlog' if value == 'later' else 'ready', by)
                q['order'] = [i for i in q['order'] if i != tid]
            else:
                raise T.TaskError('unknown queue action ' + action)
            T.event('ordered' if action != 'defer' else 'deferred', by, T.load(tid), data={'action': action})
        if action in ('cancel', 'defer') and q.get('next') == tid:
            q['next'] = None
        write('queue.json', q)
        return q


def world(api, snapshot=None):
    if snapshot is None:
        import office
        snapshot = office.snapshot(api, include_queue=False)
    offered = api.agents_offered() if any(t['status']['value'] == 'queued' for t in snapshot['tasks']) else []
    return dict(snapshot, config=config(), providers=[r[0] for r in offered if r[2]],
                default_provider=next((r[0] for r in offered if r[1]), ''), queue=queue())


def intents():
    folder = Path(T.OFFICE) / 'launching'
    return {p.name: json.loads(p.read_text()) for p in folder.glob('t-*') if T.task_id_ok(p.name)}


def occupied(w):
    # Count workers, not desks. An intent reserves a slot until its worker
    # is visible, so a second tick cannot overfill a slowly opening terminal.
    count = 0
    folders = set()
    for row in w['desks']:
        if row.get('agents'):
            folders.add(row['id'])
        if not row.get('paused') and row.get('task_record', {}).get('status', {}).get('value') in ('running', 'needs review'):
            count += len(row.get('agents', []))
    count += sum(1 for d in intents().values() if d.get('folder') not in folders)
    return count


def eligible(task, w, capacity=True):
    if task['status']['value'] != 'queued':
        return False, 'not queued'
    if not w.get('live_known'):
        return False, 'live worker discovery unavailable'
    if w['queue'].get('paused'):
        return False, 'scheduler paused'
    if task['id'] in intents():
        return False, 'launch already reserved'
    if not task.get('origin', {}).get('approved'):
        return False, 'waits for your approval'
    if any(d['blocks'] for d in T.decisions(task['id'], open_only=True)):
        return False, 'waits for your answer'
    folder = task.get('desk', {}).get('worktree')
    all_tasks = {t['id']: t for t in w['tasks']}
    for tid in task['after']:
        dep = all_tasks.get(tid, {})
        same = bool(folder and folder == dep.get('desk', {}).get('worktree'))
        if dep.get('status', {}).get('value') != 'completed' and not (same and dep.get('status', {}).get('value') == 'ready for release'):
            return False, 'blocked by ' + tid
    row = next((r for r in w['desks'] if r['id'] == folder), {})
    if folder:
        if not os.path.isdir(folder) or row.get('closed') or row.get('archived'):
            return False, 'its desk is gone'
        if row.get('agents'):
            return False, 'its desk has a worker at it'
        if row.get('paused'):
            return False, 'its desk is paused'
    elif not task.get('project') or not task.get('topic'):
        return False, 'needs a project and a desk topic'
    branch = task.get('desk', {}).get('branch') or task.get('topic')
    if any(r.get('topic') == branch for r in w.get('releases', [])):
        return False, 'release under way on its branch'
    provider = task['worker']['use'] or w['default_provider']
    if provider not in w['providers']:
        return False, 'provider is not installed: ' + (provider or 'none selected')
    if capacity and occupied(w) >= w['config']['at_once']:
        return False, f"at_once {w['config']['at_once']} reached"
    return True, 'eligible in priority and queue order'


def view(w):
    rows, skipped, pick = [], [], None
    for pos, task in enumerate(ordered(w['tasks'], w['queue']), 1):
        ok, why = eligible(task, w)
        row = {'id': task['id'], 'title': task['title'], 'priority': task['priority'],
               'position': pos, 'eligible': ok, 'why': why, 'desk': task.get('desk', {}).get('worktree', '')}
        rows.append(row)
        if ok and pick is None:
            pick = row
        if not ok:
            skipped.append(row)
    return dict(w['config'], paused=bool(w['queue'].get('paused')), order=[r['id'] for r in rows],
                rows=rows, next=pick, skipped=skipped, active=occupied(w))


def recover(w):
    for tid, intent in intents().items():
        row = next((r for r in w['desks'] if r['id'] == intent.get('folder')), {})
        task = require_task(tid)
        ended = task.get('launch', {}).get('seq') == intent['seq'] and task.get('launch', {}).get('ended')
        if row.get('agents') or ended or task['status']['value'] in T.FINAL:
            (Path(T.OFFICE) / 'launching' / tid).unlink()
        elif time.time() - intent['at'] >= 120 and w.get('live_known'):
            # Even if a launch was recorded, a missing worker is ambiguous.
            # Never put it back in the queue and risk a second worker.
            if T.can_move(task, 'blocked')[0]:
                T.move(tid, 'blocked', 'vikix', 'launch did not produce an observed worker', blocked_on='worker')
            T.event('launch failed', 'vikix', T.load(tid), data={'seq': intent['seq']})
            (Path(T.OFFICE) / 'launching' / tid).unlink()


def launch(api, task, w, acceptance=()):
    tid = task['id']
    intent = {'at': int(time.time()), 'pid': os.getpid(), 'seq': T.next_seq(),
              'folder': task.get('desk', {}).get('worktree', '')}
    write('launching/' + tid, intent)
    try:
        folder = intent['folder']
        if not folder:
            project = api.projects().match(task['project'])
            top = (api.git(str(project.path), 'rev-parse', '--show-toplevel') or '').strip()
            if not top:
                raise T.TaskError('scheduled tasks need a repository desk')
            tree, made = api.worktree(top, api.topic_name(task['topic']))
            folder = os.path.normpath(os.path.join(tree, os.path.relpath(str(project.path), top)))
            if not made:
                raise T.TaskError('topic already has a desk; select it explicitly')
            rec = api.desk_record(folder)
            T.update(tid, lambda t: t.update(desk=T.desk_of_record(rec)))
            intent['folder'] = folder
            write('launching/' + tid, intent)
        choices = task['worker']
        previous_push = os.environ.pop('VIKIX_AGENT_SSH', None)
        try:
            api.worker_at(folder, task['text'], choices['use'] or None, choices['local'], False,
                          choices['push'], 'from the task queue', task['topic'] or os.path.basename(folder),
                          notests=choices['no_tests'], mode=choices['mode'] or None, acceptance=acceptance,
                          task_id=tid, launch_seq=intent['seq'])
        finally:
            # worker_at used to run once per CLI process. A scheduler may
            # launch several tasks, so one task's push grant must not leak.
            if previous_push is None:
                os.environ.pop('VIKIX_AGENT_SSH', None)
            else:
                os.environ['VIKIX_AGENT_SSH'] = previous_push
        # Keep the reservation until discovery observes the worker. The
        # process opens asynchronously, and its early exit may race us.
    except (Exception, SystemExit):
        current = require_task(tid)
        if T.can_move(current, 'blocked')[0]:
            T.move(tid, 'blocked', 'vikix', 'launch failed; inspect the desk before retrying', blocked_on='worker')
        T.event('launch failed', 'vikix', T.load(tid), data={'seq': intent['seq']})
        raise


def tick(api, start=False, tid=None, automatic=False):
    with locked():
        w = world(api)
        recover(w)
        w = world(api)
        launched = []
        if automatic and not w['config']['auto']:
            result = view(w)
            ready = result['next']
            previous = read('queue-ready.json', {})
            cycle = previous.get('cycle', 0)
            if ready and previous.get('id') != ready['id']:
                cycle += 1
                import office
                office.notify_attention([{'id': f"queue:{ready['id']}:{cycle}", 'kind': 'queue ready', 'why': ready['title']}], T.OFFICE)
            write('queue-ready.json', {'id': ready['id'] if ready else None, 'cycle': cycle})
            return result
        if start or automatic:
            limit = w['config']['at_once'] if automatic else 1
            for _ in range(limit):
                result = view(w)
                candidate = require_task(tid) if tid else (require_task(result['next']['id']) if result['next'] else None)
                if candidate is None:
                    break
                ok, why = eligible(candidate, w)
                if not ok:
                    raise T.TaskError(why)
                launch(api, candidate, w)
                launched.append(candidate['id'])
                q = queue()
                q['order'] = [i for i in q['order'] if i != candidate['id']]
                if q.get('next') == candidate['id']:
                    q['next'] = None
                write('queue.json', q)
                w = world(api)
        return dict(view(w), launched=launched)


def wake(script):
    """Event writers schedule a bounded tick; no queue means no process.
    flock coalesces simultaneous events. The caller's credentials stay as-is."""
    if os.environ.get('VIKIX_SCHEDULER') == '0' or not (Path(T.OFFICE) / 'queue.json').exists():
        return
    with open(os.devnull, 'wb') as null:
        subprocess.Popen(['timeout', '--kill-after=5s', '60s', script, 'queue', 'tick'],
                         stdin=null, stdout=null, stderr=null, start_new_session=True, close_fds=True)


def bump(api, tid, over):
    """Only an explicit user command preempts. Check the target before
    pausing; undo our pause if launch setup fails."""
    with locked():
        w = world(api)
        task = require_task(tid)
        folder, rec = api.desk_for([over])
        if task.get('desk', {}).get('worktree') == folder:
            raise T.TaskError('bump needs a different desk for the queued task')
        row = next((r for r in w['desks'] if r['id'] == folder), {})
        old = row.get('task_record', {})
        if not row.get('agents') or row.get('paused') or old.get('status', {}).get('value') not in ('running', 'needs review'):
            raise T.TaskError('the worker to pause must be running and hold a slot')
        ok, why = eligible(task, w, capacity=False)
        if not ok:
            raise T.TaskError(why)
        if occupied(w) - len(row['agents']) >= w['config']['at_once']:
            raise T.TaskError('pausing this desk would not free a slot')
        api.pause_folder(folder, 'user')
        try:
            T.move(old['id'], 'blocked', 'user', 'paused for ' + tid, blocked_on=tid)
            T.event('paused', 'user', T.load(old['id']), data={'for': tid})
            launch(api, task, w)
        except (Exception, SystemExit):
            api.go_folder(folder, 'user')
            unpaused(api, folder)
            raise
        return dict(view(world(api)), launched=[tid])


def unpaused(api, folder):
    tid = api.task_id_at(folder)
    task = T.load(tid) if tid else None
    if task and task['status']['value'] == 'blocked' and task['status'].get('reason', '').startswith('paused for '):
        T.move(tid, 'running', 'user', 'resumed after queue bump')
        T.event('resumed', 'user', T.load(tid))


def start_plan(api, folder, task, plan_name, project):
    """A running plan is explicit authorization for its steps. Use the same
    capacity lock and launch reservation as the queue; keep plan sequencing
    and release gates in the plan runner."""
    with locked():
        w = world(api)
        recover(w)
        w = world(api)
        if not w.get('live_known') or w['queue'].get('paused') or occupied(w) >= w['config']['at_once']:
            return False
        rec = api.desk_record(folder)
        choices = {'use': task['agent'], 'local': task['local'], 'push': task['push'],
                   'no_tests': task['no_tests'], 'mode': task.get('mode') or ''}
        record = T.new(task['text'], project, 'vikix', kind='automation', source='plan ' + plan_name,
                       desk=T.desk_of_record(rec), worker=choices)
        T.update(record['id'], lambda t: t['origin'].update(approved={'by': 'plan ' + plan_name, 'at': int(time.time())}))
        T.move(record['id'], 'queued', 'vikix', 'authorized plan step')
        candidate = T.load(record['id'])
        w = world(api)
        ok, why = eligible(candidate, w)
        if not ok:
            T.move(record['id'], 'blocked', 'vikix', why, blocked_on='worker')
            raise T.TaskError(why)
        launch(api, candidate, w, acceptance=task.get('acceptance') or ())
        return True
