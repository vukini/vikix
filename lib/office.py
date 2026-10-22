"""The Office: desk snapshots and explicit user actions.

Terminal clients and the Emacs view share a read-only snapshot; unavailable
discovery is explicitly different from an empty office.
"""
import json
import hashlib
import fcntl
from contextlib import ExitStack
import os
import sys
import re
import select
import signal
import shutil
import subprocess
import time


# A closed desk (vikix agents close, or a release that removed it) stays
# among the desks this long, in the Closed group, so what was done today is
# in view; after that its record is in the Archive, as any removed worktree's.
CLOSED_SHOWN = 24 * 3600


def closed_by(rec):
    """Who closed the desk, from the record's log: 'release', or the user."""
    for line in reversed(rec.get('log') or []):
        if isinstance(line, dict) and line.get('what') == 'desk closed':
            return str(line.get('by') or '')
    return ''


def missing_folder(path):
    try:
        os.lstat(path)
    except FileNotFoundError:
        return True
    except OSError:
        pass
    return False


def agent_folder(agent):
    path = agent.get('folder') or '/'
    # Linux marks a running process's removed cwd with this suffix.
    # It still belongs to that desk and must prevent archive purging.
    if path.endswith(' (deleted)') and missing_folder(path):
        path = path[:-10]
    return os.path.realpath(path)


def short(path):
    """PATH with the home folder as ~, as the terminal listing shows it."""
    home = os.path.expanduser('~')
    return '~' + path[len(home):] if path == home or path.startswith(home + '/') else path


# .claude/release's notes: one file a release under way, named by its pid,
# beside its lock in the repository's common git dir. Eight lines: the topic,
# its step in words (checking, testing (quick), waiting for its turn, ...),
# when the release began (epoch seconds), "no version" for a --plain release
# or nothing, the summary, when the step began, the step's number (0 while
# it waits for its turn, else 1 to 7 of RELEASE_STEPS, skipped ones counted),
# and the worktree the tests run in. A note of five lines (a release script
# from before) has no step. The script's --queue reads them the same way.
QUEUE_DIR = 'vikix-release-queue'
# The steps of a release, in the script's order: the note's number is one of
# these. The Office draws them as a strip, the one under way marked.
RELEASE_STEPS = ('checking', 'looking at origin', 'onto main', 'testing', 'merging', 'version and tag', 'closing the desk')
RELEASE_TESTS_STEP = 4
# What the steps after the tests take together, about: a merge, a commit and
# a tag, a worktree removed. Seconds, so the estimate can say "under a minute".
RELEASE_TAIL_SECONDS = 20


def release_queue(api):
    """The releases under way in the projects' repositories, the one whose
    turn it is first, then the waiting by when they came; and whether any
    repository has the notes' folder at all (so an empty queue can be told
    from a machine that never released). Each one's step, of how many, and
    since when; while it tests, the run's tests (tests/run.sh's plan in the
    worktree: test_progress) and how long is left; waiting, whom it is
    behind. Read only: a note whose process has ended is skipped and left
    for the script, which clears it."""
    rows, kept = [], False
    for common, name in sorted(api.known_repos().items()):
        folder = os.path.join(common, QUEUE_DIR)
        if not os.path.isdir(folder):
            continue
        kept = True
        for entry in os.listdir(folder):
            if not entry.isdigit():
                continue
            pid = int(entry)
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                continue
            except OSError:
                pass   # another user's: alive, we can't signal it
            try:
                with open(os.path.join(folder, entry), encoding='utf-8', errors='replace') as f:
                    lines = (f.read().split('\n') + [''] * 8)[:8]
            except OSError:
                continue
            topic, state, since, kind, summary, step_since, step, worktree = (l.strip() for l in lines)
            if not topic:
                continue
            row = {'project': name, 'common': common, 'pid': pid, 'topic': topic, 'state': state or 'unknown',
                   'since': int(since) if since.isdigit() else None, 'kind': kind, 'summary': summary,
                   'waiting': state.startswith('waiting'),
                   'step': int(step) if step.isdigit() else None, 'steps': len(RELEASE_STEPS),
                   'step_since': int(step_since) if step_since.isdigit() else None, 'worktree': worktree}
            row.update(release_tests(api, row))
            rows.append(row)
    rows.sort(key=lambda r: (r['waiting'], r['since'] or 0, r['topic']))
    # A waiting release is behind the one whose turn it is and those that came before it.
    for i, r in enumerate(rows):
        r['behind'] = [a['topic'] for a in rows[:i] if a['common'] == r['common']] if r['waiting'] else []
        r['left'], r['left_words'] = release_left(r, rows[:i])
        r['line'] = release_line(r)
    return rows, kept


def release_tests(api, release):
    """The tests a RELEASE runs now, from the runner's plan in its worktree
    (test_progress, the Testing box's reader): the run's rows, its summary
    and how long is left (None when a test has no estimate); nothing while
    it isn't testing, or when the worktree or the plan can't be found."""
    none = {'tests': [], 'tests_summary': '', 'tests_left': None}
    if not release['state'].startswith('testing') or not release['worktree'] or not hasattr(api, 'test_progress'):
        return none
    try:
        runs = api.test_progress(release['worktree'])
    except (OSError, ValueError):
        return none
    if not runs:
        return none
    run = runs[0]
    return {'tests': run['tests'], 'tests_summary': run['summary'], 'tests_left': run['eta']}


def release_left(release, ahead):
    """How long a RELEASE has left, about, and the words for it: while it
    tests, the run's estimate plus the steps after; past the tests, under a
    minute; before them, the tests decide (their estimate comes as they
    start); waiting its turn, after the one AHEAD of it (the rows before it
    in the queue), with that one's estimate when it has one. (seconds or
    None, words)."""
    step = release['step']
    if release['waiting']:
        mine = [a for a in ahead if a['common'] == release['common']]
        first = mine[0] if mine else None
        if first and first.get('left') is not None:
            return None, f"after {first['topic']}, which has about {left_words(first['left'])} left"
        return None, (f"after {first['topic']}" if first else 'after the release whose turn it is')
    if step is None:
        return None, ''
    if step < RELEASE_TESTS_STEP:
        return None, 'how long: the tests decide; their estimate comes as they start'
    if step == RELEASE_TESTS_STEP:
        if release['tests_left'] is None:
            return None, ('tests running, estimate unknown' if release['tests'] else 'tests starting')
        left = release['tests_left'] + RELEASE_TAIL_SECONDS
        return left, f'about {left_words(left)} left'
    return RELEASE_TAIL_SECONDS, 'under a minute left'


def left_words(seconds):
    """SECONDS ahead in a few words: 40 s, 3 min, 1 h 5 min."""
    n = max(0, int(seconds))
    return f'{n} s' if n < 60 else span_words(n)


def release_line(release):
    """One release as the desk's row says it: its step of how many, what it
    does, since when, and how long is left."""
    since = time.strftime('%H:%M', time.localtime(release['since'])) if release['since'] else '?'
    step = release.get('step')
    head = f"step {step} of {release['steps']}: " if step else ''
    return (f"{head}{release['state']} · since {since}" + (f" · {release['kind']}" if release['kind'] else '')
            + (f" · behind {', '.join(release['behind'])}" if release.get('behind') else '')
            + (f" · {release['left_words']}" if release.get('left_words') else ''))


def plan_rows(api):
    """The plans the runner has (lib/plan.py's view), and a line for each desk
    a plan holds, by its folder: "NAME: task (state)"."""
    sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
    import plan
    rows = plan.plans_view(api)
    by_folder = {}
    for p in rows:
        for d in p['desks']:
            now = next((t for t in d['tasks'] if t['state'] not in ('done', 'pending')), None)
            words = f"{now['name']} ({now['state']})" if now else d['line'] or 'nothing yet'
            by_folder[os.path.realpath(d['folder'])] = f"{p['name']}: {words}"
    return rows, by_folder


def task_rows(api, events_by_task, errors):
    """The task records (lib/tasks.py), each with its events of this
    month and the last, newest first, forty at most; and the last launch
    number. ({id: row}, sequence)."""
    T = api.tasks_module()
    rows = {}
    try:
        questions = {}
        for d in T.decisions():
            questions.setdefault(d['task'], []).append(d)
        for t in T.all_tasks(strict=True):
            t = dict(t)
            t['questions'] = questions.get(t['id'], [])
            t['events'] = events_by_task.get(t['id'], [])[:40]
            t['origin_words'] = T.origin_words(t)
            t['launch_words'] = T.launch_words(t)
            rows[t['id']] = t
    except Exception as e:  # noqa: BLE001
        errors.append(f'Tasks unknown: {e}')
    return rows, T.sequence()


def events_grouped(api):
    """This month's and the last's events (lib/tasks.py's log) by task id,
    newest first; {} when the log can't be read."""
    T = api.tasks_module()
    out = {}
    try:
        for e in T.events_read(limit=5000):
            if e.get('task'):
                out.setdefault(e['task'], []).append(e)
    except Exception:  # noqa: BLE001
        return {}
    return out



def attention(snapshot, now=None, quiet=20):
    """Actionable items, not a guess that an idle worker finished its task.
    Stable ids include the event time; refreshes never reset waiting time."""
    now = int(time.time()) if now is None else now
    items = []
    desks = {r.get('task_record', {}).get('id'): r for r in snapshot.get('desks', [])}
    def add(kind, task, row, why, since=None, question=None, actions=()):
        worker = (row.get('agents') or [{}])[0]
        item = {'id': question['id'] if question else f"{kind}:{task.get('id', row.get('id', 'office'))}:{since or 'unknown'}",
                'kind': kind, 'task': task.get('id'), 'title': task.get('title') or row.get('title') or 'Office',
                'project': task.get('project', ''), 'desk': row.get('id') or task.get('desk', {}).get('worktree', ''),
                'worker': f"{worker.get('agent', '')} {worker.get('pid', '')}".strip(),
                'provider': worker.get('agent') or task.get('launch', {}).get('provider', ''),
                'pid': worker.get('pid'), 'since': since, 'seq': task.get('launch', {}).get('seq'),
                'why': why, 'question': question, 'actions': list(actions)}
        items.append(item)
    if not snapshot.get('live_known', True):
        add('discovery unavailable', {}, {}, '; '.join(snapshot.get('errors') or ['Live activity unknown']), actions=['refresh'])
    work = [(t, desks.get(t['id'], {})) for t in snapshot.get('tasks', [])]
    work += [({}, r) for r in snapshot.get('desks', []) if not r.get('task_record')]
    for task, row in work:
        state = task.get('status', {}).get('value')
        if state in ('completed', 'cancelled'):
            if row.get('attention') in ('gup', 'close'):
                why = 'run gup to push and update' if row['attention'] == 'gup' else 'close the finished terminal'
                add('release', task, row, why, task.get('done'), actions=['go'])
            continue
        status_at = task.get('status', {}).get('at')
        questions = [d for d in task.get('questions', []) if not d.get('answer')]
        for d in questions:
            add('decision', task, row, d['question'], d['at'], d, ['answer', 'go'])
        for a in row.get('agents', []):
            # A provider's last prose question can stay on its terminal
            # until the next turn. An answer to that very question has
            # already resolved it; a newer question is still shown.
            if a.get('note_kind') in ('reply', 'question') and any(
                    d.get('answer') and d['question'].strip() == (a.get('said') or '').strip()
                    and a.get('attention_since') and d['answer']['at'] >= a['attention_since']
                    for d in task.get('questions', [])):
                continue
            s = a.get('state')
            if s in ('permission', 'asks') or a.get('attention') == 'asks':
                if not questions:
                    kind = 'question' if a.get('note_kind') in ('reply', 'question') else 'permission'
                    add(kind, task, dict(row, agents=[a]), a.get('said') or 'waits for your yes', a.get('attention_since'),
                        actions=['go', 'register'] if kind == 'question' else ['go'])
            elif (s in ('question', 'waiting') or a.get('note_kind') in ('reply', 'question')) and not questions:
                add('question', task, dict(row, agents=[a]), a.get('said') or 'waiting for input', a.get('attention_since'), actions=['go', 'register'])
        if state == 'needs decision' and not questions and not any(i['task'] == task.get('id') and i['kind'] in ('question', 'permission') for i in items):
            add('question', task, row, row.get('next_action') or 'waiting for a decision', status_at, actions=['go', 'register'])
        checks = row.get('checks') or []
        latest = checks[-1] if checks else {}
        fresh = latest.get('freshness', '') == 'fresh' and not latest.get('skipped')
        idle = not any(a.get('state') in ('working', 'running') for a in row.get('agents', []))
        if latest and not latest.get('ok') and fresh and idle and not row.get('testing'):
            add('tests failed', task, row, latest.get('name', 'tests') + ': ' + latest.get('note', '').split('\n')[0], latest.get('at'), actions=['go', 'test', 'tell'])
        if state == 'needs review' and not row.get('testing') and (row.get('tests_off') or (latest.get('ok') and fresh)):
            add('review', task, row, row.get('next_action') or 'review the handoff', status_at, actions=['accept', 'back', 'go', 'tell'])
        # A release already under way on the desk's branch (the row's release
        # line, from .claude/release's note) asks nothing of you: the item goes
        # when the release is started, in the Office or in the agent's terminal
        # (2026-10-22: three desks kept their Release link through their
        # releases); the Releases box and the task's row say where it is.
        terminal = row.get('attention')
        releasing = bool(row.get('release')) and terminal not in ('gup', 'close')
        if (state == 'ready for release' and not releasing) or terminal in ('gup', 'close'):
            # A branch that can't go on top of the project's own (the row's
            # conflicts, from merge-tree) gets no Release button: the rebase
            # at the desk comes first, and the item says where.
            if terminal in ('gup', 'close'):
                why, actions = 'run gup to push and update' if terminal == 'gup' else 'close the finished terminal', ['go']
            elif row.get('conflicts'):
                why, actions = row['conflicts'] + ': rebase at the desk first (git rebase there), then release', ['go']
            else:
                why, actions = row.get('next_action') or 'ready for release', ['release', 'go']
            add('release', task, row, why, status_at, actions=actions)
        if state == 'blocked':
            b = task.get('blocked') or {}
            kind = ('worker stopped' if b.get('on') == 'worker' else 'desk removed' if b.get('on') == 'desk'
                    else 'blocked by task' if str(b.get('on', '')).startswith('t-') else 'blocked')
            # A desk removed has no worker to go to or tell: cancel the task, or make it ready again (its page).
            add(kind, task, row, b.get('why') or task.get('status', {}).get('reason') or 'blocked', status_at,
                actions=[] if kind == 'desk removed' else ['go', 'tell'])
        if state == 'backlog' and task.get('origin', {}).get('kind') == 'agent':
            add('proposed', task, row, 'proposed by ' + task['origin'].get('by', 'an agent'), task.get('created'), actions=['go'])
        last = max([task.get('activity') or 0] + [a.get('activity_at') or 0 for a in row.get('agents', [])])
        worker = row.get('worker_state') or task.get('worker') or {}
        if state == 'running' and worker.get('sure', 'unknown') in ('inferred', 'unknown') and last and now - last >= quiet * 60:
            add('uncertain', task, row, f'no reliable activity for {(now-last)//60} min; inspect the worker', last, actions=['go', 'tell'])
    for e in snapshot.get('clashes', []):
        task = next((t for t in snapshot.get('tasks', []) if t.get('desk', {}).get('worktree') == e.get('folder')), {})
        row = desks.get(task.get('id'), {})
        add('clash', task, row, (e.get('file') or 'workers waiting on the same file') + ' — ' + ', '.join(e.get('with') or []), e.get('at'), actions=['go'])
    for r in snapshot.get('releases', []):
        if any(w in r.get('state', '') for w in ('refused', 'stopped')):
            add('release stopped', {}, {'id': r.get('topic'), 'title': r.get('topic')}, r['state'], r.get('since'), actions=['go'])
    rank = {k: i for i, k in enumerate(('decision', 'permission', 'question', 'worker stopped', 'tests failed', 'clash', 'review', 'release stopped', 'release', 'proposed', 'blocked by task', 'desk removed', 'blocked', 'uncertain', 'discovery unavailable'))}
    return sorted(items, key=lambda i: (rank.get(i['kind'], 99), i['since'] or now, i['id']))


# The board (phase 4 of plans/DESIGN-office-tasks.md, 2026-10-16): the Office
# drawn around the work. Five sections, a row a task, then the desks standing
# empty and the ones closed; the Emacs view, the text board (vikix agents
# tasks) and the MCP tool tasks all draw from this one reading, so nothing is
# shown in one that another can't say.
BOARD_SECTIONS = ('Needs attention', 'Running', 'Queue', 'Blocked', 'Completed', 'Desks', 'Closed')
SORTS = ('launch', 'newest', 'created', 'activity', 'priority', 'status', 'project', 'provider')
SORT_WORDS = {'launch': 'launch order, oldest first', 'newest': 'newest launch first', 'created': 'when created',
              'activity': 'last activity first', 'priority': 'priority', 'status': 'status', 'project': 'project',
              'provider': 'provider'}
PRIORITY_RANK = {'critical': 0, 'high': 1, 'normal': 2, 'low': 3}
COMPLETED_SHOWN = 24 * 3600


def span_words(seconds):
    """SECONDS in a few words: just now, 35 min, 2 h 10 min, 3 days."""
    n = max(0, int(seconds))
    if n < 60:
        return 'just now'
    if n < 3600:
        return f'{n // 60} min'
    if n < 86400:
        h, m = divmod(n // 60, 60)
        return f'{h} h {m} min' if m else f'{h} h'
    d = n // 86400
    return f'{d} day' if d == 1 else f'{d} days'


def ago_words(seconds):
    """SECONDS back in words: just now, 35 min ago, 2 h ago."""
    words = span_words(seconds)
    return words if words == 'just now' else words + ' ago'


def board_row(task, desk, now, queue_rows):
    """One row of the board for TASK (the snapshot's record, its worker's
    state projected) at DESK (the snapshot's row, or {} for a task with no
    desk): where it goes (section), the one line every view shows, a
    second line when there is more to say, and the fields a sort goes by.
    Every state is a word; no colour carries alone."""
    launch = task.get('launch') or {}
    state = (task.get('status') or {}).get('value', '?')
    status_at = (task.get('status') or {}).get('at') or task.get('created') or now
    worker = task.get('worker_state') or {}
    choices = task.get('worker') if 'use' in (task.get('worker') or {}) else {}
    seq = launch.get('seq')
    provider = launch.get('provider') or (choices or {}).get('use') or ''
    if not provider and desk.get('agents'):
        provider = desk['agents'][0].get('agent', '')
    d = task.get('desk') or {}
    if d.get('worktree'):
        place = f"{task.get('project') or '?'}/{d.get('branch') or os.path.basename(d['worktree'])}"
    elif desk.get('title'):
        place = desk['title']
    else:
        place = f"{task.get('project') or '?'}" + (f", desk to make: {task['topic']}" if task.get('topic') else ', no desk')
    head = (f"#{seq}" if seq else 'launch order unknown') + (f" {provider}" if provider else '')
    title = task.get('title') or ''
    since = launch.get('at') if state in ('running',) and launch.get('at') else status_at
    ago = span_words(now - int(since or now))
    q = queue_rows.get(task['id'], {})
    detail, section, words, release = '', 'Running', state, ''
    if state in ('running', 'needs decision', 'needs review'):
        w = worker.get('state', '')
        if state == 'running':
            words = ('idle, task open' if w == 'idle' else w if w in ('starting', 'paused', 'waiting for permission', 'waiting for input')
                     else f"held: {worker.get('why', '')}" if w == 'held' else 'running' if w == 'running'
                     else f'running, worker {w}' if w in ('exited', 'failed') else 'running' if not w else f'running, worker {w}')
        else:
            words = state + (f" · worker {w}" if w and w not in ('running',) else '')
        if desk.get('paused'):
            words += f" · paused by {desk['paused'].get('by', '?')}"
        if desk.get('testing'):
            words += ' · testing'
        line = f"{head} · {place} · {ago} · {words} · {title}"
    elif state == 'queued':
        section = 'Queue'
        words = 'queued'
        line = (f"{q.get('position', '?')}. {title} · {place} · priority {task.get('priority', 'normal')}"
                + (f" · {q['why']}" if q.get('why') and not q.get('eligible') else ' · next, when a slot is free' if q.get('eligible') else ''))
    elif state in ('ready', 'backlog'):
        words = 'ready, not queued' if state == 'ready' else 'backlog, waits for your approval'
        # At a desk that stands, the task waits with it; with none, or with
        # one that is gone, it waits in the Queue's tail, said so.
        section = 'Desks' if desk else 'Queue'
        if d.get('worktree') and not desk:
            words += ', its desk is gone'
        line = (f"{title} · {place} · priority {task.get('priority', 'normal')} · {words}" if section == 'Queue'
                else f"{place} · {words} · {title}")
    elif state == 'blocked':
        section = 'Blocked'
        b = task.get('blocked') or {}
        on = b.get('on') or '?'
        words = f'blocked on {on}'
        if on == 'worker':
            last = (task.get('launches') or [launch])[-1] if (task.get('launches') or launch) else {}
            ended = last.get('ended')
            detail = 'worker stopped' + (f" {ago_words(now - int(ended))}" if ended else '') \
                + (f": exit {last['code']}" if last.get('code') is not None else '') \
                + (f", {desk['now']['dirty']} uncommitted" if (desk.get('now') or {}).get('dirty') else '')
        elif str(on).startswith('t-'):
            detail = f"waits for {on}" + (f": {b['why']}" if b.get('why') else '')
        else:
            detail = b.get('why') or (task.get('status') or {}).get('reason') or ''
        line = f"{head} · {place} · {ago} · {words} · {title}"
    elif state == 'ready for release':
        section = 'Completed'
        # Under release: the step the release is at, from the desk's row.
        words = (f"under release: {desk['release']}" if desk.get('release')
                 else f"accepted, {desk['conflicts']}: rebase at the desk first" if desk.get('conflicts')
                 else 'accepted, not yet released')
        line = f"{head} · {place} · {words} · {title}"
    elif state in ('completed', 'cancelled'):
        section = 'Completed'
        for e in task.get('events') or []:
            if e.get('kind') == 'released' and (e.get('data') or {}).get('version'):
                release = e['data']['version']
                break
        words = (f'released {release}' if release else state)
        took = ((task.get('done') or 0) - (task.get('launched') or 0)) if task.get('done') and task.get('launched') else None
        detail = (f"took {'under a minute' if took < 60 else span_words(took)}" if took is not None and took >= 0 else '')
        if desk.get('estimate'):
            detail += (' · ' if detail else '') + desk['estimate']
        line = f"{head} · {place} · {words} · {ago_words(now - int(task.get('done') or status_at))} · {title}"
    else:
        line = f"{head} · {place} · {state} · {title}"
    row = {'kind': 'task', 'id': desk.get('id') or f"task:{task['id']}", 'task': task['id'], 'desk': desk.get('id', ''),
           'section': section, 'line': line, 'detail': detail, 'state': words, 'status': state, 'title': title,
           'project': task.get('project', ''), 'place': place, 'provider': provider, 'seq': seq,
           'priority': task.get('priority', 'normal'), 'since': since, 'ago': ago, 'release': release,
           'position': q.get('position'), 'why': q.get('why', ''), 'eligible': bool(q.get('eligible')),
           'sort': {'launch': seq or 10 ** 9, 'created': task.get('created') or 0,
                    'activity': max(task.get('activity') or 0, *(a.get('activity_at') or 0 for a in desk.get('agents') or [{}])),
                    'priority': PRIORITY_RANK.get(task.get('priority'), 2), 'status': state,
                    'project': (task.get('project') or '').lower(), 'provider': provider}}
    return row


def desk_board_row(desk, section):
    """A desk with no task of its own as a row of SECTION: the ones standing
    empty, the ones closed, a folder an agent runs in, an agent at a desk
    with no task record."""
    agents = desk.get('agents') or []
    who = '; '.join(f"{a.get('agent', '?')} · workspace {a.get('workspace') or 'unknown'}" if a.get('window') and a.get('workspace')
                    else f"{a.get('agent', '?')} · no desktop window" if not a.get('window') else f"{a.get('agent', '?')} · workspace unknown"
                    for a in agents)
    words = ('not a desk' if desk.get('kind') == 'folder' else 'no task record' if agents
             else desk.get('next_action', '') if section == 'Closed' else 'stands empty')
    # With no task record, what its agent was first asked in its terminal (the
    # prompt hook's note) is what the row is about.
    asked = next((' '.join(a['first_prompt'].split()) for a in agents if a.get('first_prompt')), '')
    if asked:
        words += ' · prompted: ' + (asked[:117] + '…' if len(asked) > 120 else asked)
    return {'kind': 'desk', 'id': desk['id'], 'task': '', 'desk': desk['id'], 'section': section,
            'line': f"{desk.get('title', '')} · {who or desk.get('provider', '')} · {words}", 'detail': '',
            'state': words, 'status': '', 'title': desk.get('title', ''), 'project': (desk.get('desk') or {}).get('project', ''),
            'place': desk.get('title', ''), 'provider': desk.get('provider', ''), 'seq': desk.get('launch_seq'),
            'priority': '', 'since': (desk.get('closed') or {}).get('at'), 'ago': '', 'release': '', 'position': None,
            'why': '', 'eligible': False,
            'sort': {'launch': 10 ** 9, 'created': 0, 'activity': max((a.get('activity_at') or 0 for a in agents), default=0),
                     'priority': 9, 'status': '', 'project': (desk.get('desk') or {}).get('project', '').lower(),
                     'provider': desk.get('provider', '')}}


def board_sort(rows, key):
    """ROWS in the order KEY (one of SORTS) asks: launch order (the
    unnumbered after, then by when made), newest launch first, created,
    last activity first, priority, status, project, provider; a tie keeps
    launch order."""
    if key not in SORTS:
        raise ValueError(f"sort by one of {', '.join(SORTS)}")
    base = sorted(rows, key=lambda r: (r['sort']['launch'], r['sort']['created'], r['id']))
    if key == 'launch':
        return base
    if key == 'newest':
        return sorted(base, key=lambda r: -r['sort']['launch'] if r['sort']['launch'] < 10 ** 9 else 1)
    if key in ('created', 'activity'):
        return sorted(base, key=lambda r: -(r['sort'][key] or 0))
    return sorted(base, key=lambda r: r['sort'][key])


def board(snapshot, now=None, every=False, sort='launch'):
    """The Office as a task board: the sections in BOARD_SECTIONS' order,
    each with its rows (Needs attention's are the snapshot's items, as
    they are). A task's row goes by its state (board_row); a desk with no
    open task stands in Desks, a closed one in Closed, and a desk with an
    agent at it but no task record is in Running, said so. Completed holds
    the last day's (EVERY: all); older ones are the Archive's. Running and
    Completed are in SORT's order; the Queue is always in queue order."""
    now = int(now or time.time())
    desks = {r['id']: r for r in snapshot.get('desks', [])}
    by_worktree = {os.path.realpath(r['id']): r for r in desks.values()}
    queue_rows = {r['id']: r for r in (snapshot.get('queue') or {}).get('rows', [])}
    sections = {name: [] for name in BOARD_SECTIONS}
    sections['Needs attention'] = list(snapshot.get('attention') or [])
    taken = set()
    for task in snapshot.get('tasks', []):
        state = (task.get('status') or {}).get('value')
        wt = (task.get('desk') or {}).get('worktree') or ''
        desk = by_worktree.get(os.path.realpath(wt), {}) if wt else {}
        if state in ('completed', 'cancelled') and not every and (task.get('done') or 0) < now - COMPLETED_SHOWN:
            continue
        row = board_row(task, desk, now, queue_rows)
        if desk and (state not in ('completed', 'cancelled') or desk.get('agents')):
            if desk['id'] in taken:
                continue      # a desk's second final task: one row for the place
            taken.add(desk['id'])
        sections[row['section']].append(row)
    for desk in snapshot.get('desks', []):
        if desk['id'] in taken:
            continue
        if desk.get('closed'):
            sections['Closed'].append(desk_board_row(desk, 'Closed'))
        elif desk.get('agents') and desk.get('live_known', True):
            sections['Running'].append(desk_board_row(desk, 'Running'))
        else:
            sections['Desks'].append(desk_board_row(desk, 'Desks'))
    order = [r['id'] for r in (snapshot.get('queue') or {}).get('rows', [])]
    sections['Queue'].sort(key=lambda r: (0 if r['status'] == 'queued' else 1,
                                          order.index(r['task']) if r['task'] in order else 10 ** 6, r['sort']['created']))
    sections['Running'] = board_sort(sections['Running'], sort)
    sections['Blocked'] = board_sort(sections['Blocked'], 'launch')
    sections['Completed'] = board_sort(sections['Completed'], sort)
    sections['Desks'].sort(key=lambda r: (r['status'] != 'ready', r['title'].lower(), r['id']))
    sections['Closed'].sort(key=lambda r: -(r['since'] or 0))
    return {'sort': sort, 'sorts': list(SORTS), 'every': bool(every),
            'sections': [{'name': name, 'count': len(sections[name]), 'rows': sections[name]} for name in BOARD_SECTIONS]}


def queue_count_words(rows):
    """What the Queue holds, in words: the queued tasks, the ready ones not
    queued and the proposals waiting for approval apart, so the count never
    says queued of a task that isn't (the Office's box said *Queue (1)* of
    a task ready and not queued, 2026-10-22)."""
    queued = sum(1 for r in rows if r.get('status') == 'queued')
    proposed = sum(1 for r in rows if r.get('status') == 'backlog')
    ready = len(rows) - queued - proposed
    if not rows:
        return 'empty'
    parts = [f'{queued} queued' if queued else 'none queued']
    if ready:
        parts.append(f'{ready} ready to queue')
    if proposed:
        parts.append(f'{proposed} waiting for your approval')
    return ', '.join(parts)


def queue_words(queue):
    """The scheduler's summary in words: the workers running and at_once,
    whether it starts the next by itself (auto), and whether it is paused."""
    return (f"{queue.get('active', '?')} workers running, up to {queue.get('at_once', '?')} at once · "
            + ('auto on: the next starts when a slot is free' if queue.get('auto')
               else 'auto off: nothing starts by itself, queue start does')
            + (' · scheduler paused by you' if queue.get('paused') else ''))


def board_text(snapshot, board_, now=None):
    """The board as text, for vikix agents tasks: a section a heading with
    its count, a row a line (its second line indented under it), the
    Queue with the scheduler's summary, the Completed's as the day's."""
    now = int(now or time.time())
    out = []
    queue = snapshot.get('queue') or {}
    for section in board_['sections']:
        name, rows = section['name'], section['rows']
        head = f"{name} ({queue_count_words(rows) if name == 'Queue' else len(rows)})"
        if name in ('Running', 'Completed'):
            head += f" · sorted by {SORT_WORDS[board_['sort']]}"
        if name == 'Queue' and queue:
            head += ' · ' + queue_words(queue)
        if name == 'Completed':
            head += ' · every one' if board_.get('every') else ' · the last day'
        if name == 'Desks':
            head = f"Desks standing empty ({len(rows)})"
        if name == 'Closed':
            head = f"Closed today ({len(rows)})"
        out.append(head + ':')
        if name == 'Needs attention':
            for r in rows:
                age = span_words(now - r['since']) if r.get('since') else 'time unknown'
                worker = r.get('worker') or r.get('provider') or 'worker unknown'
                seq = f"#{r['seq']}" if r.get('seq') else 'launch order unknown'
                out.append(f"  {r['kind']}: {r.get('project', '')} · {r['title']} [{r.get('task') or 'office'}] · {worker}, {seq} — {r['why']} ({age})")
        else:
            for r in rows:
                out.append('  ' + r['line'] + (f"  [{r['task']}]" if r['task'] else ''))
                if r.get('detail'):
                    out.append('      ' + r['detail'])
        if name == 'Queue' and queue:
            nxt = queue.get('next')
            out.append('  Next to start: ' + (f"{nxt['title']} — {nxt['why']} (vikix agents queue start)" if nxt
                                               else 'none can start now'))
        if not rows:
            out.append('  none')
    return '\n'.join(out)


def new_task(api, args):
    """The Office's New task (the T form): PROJECT "text" [--desk FOLDER |
    --topic TOPIC] [--priority LEVEL] [--after ID]... [--use NAME] [--local]
    [--push] [--no-tests] [--mode MODE] [--queue]. A task record, ready,
    at a desk that stands (its record names the task, as desk --task would,
    with nobody started at it) or with the topic of the desk to make; with
    --queue it enters the queue at once. Nothing is started: the scheduler
    does that on your word. The user's act: an agent is refused."""
    by, me = api.by_me()
    if me or by != 'user':
        raise ValueError('only the user makes a task from the Office (an agent proposes, later)')
    usage = ('vikix agents office --new-task PROJECT "task" [--desk FOLDER | --topic TOPIC] [--priority LEVEL] '
             '[--after ID]... [--use NAME] [--local] [--push] [--no-tests] [--mode MODE] [--queue]')
    rest = list(args)
    if len(rest) < 2 or (rest[0].startswith('-') and rest[0] != '-') or rest[1].startswith('-'):
        raise ValueError(usage)
    project, text = rest.pop(0), rest.pop(0).strip()
    opts = {'after': [], 'worker': {}}
    while rest:
        a = rest.pop(0)
        if a in ('--desk', '--topic', '--priority', '--after', '--use', '--mode'):
            if not rest or rest[0].startswith('-'):
                raise ValueError(f'{a} needs its words')
            v = rest.pop(0).strip()
            if a == '--after':
                opts['after'].append(v)
            elif a in ('--use', '--mode'):
                opts['worker'][a[2:]] = v
            else:
                opts[a[2:]] = v
        elif a in ('--local', '--push', '--no-tests'):
            opts['worker'][a[2:].replace('-', '_')] = True
        elif a == '--queue':
            opts['queue'] = True
        else:
            raise ValueError(usage)
    if not text:
        raise ValueError('the task needs words')
    if opts.get('desk') and opts.get('topic'):
        raise ValueError('a desk that stands, or the topic of the desk to make: not both')
    T = api.tasks_module()
    S = api.scheduler_module()
    if opts.get('priority', 'normal') not in T.PRIORITIES:
        raise ValueError(f"a priority is one of {', '.join(T.PRIORITIES)}")
    for tid in opts['after']:
        S.require_task(tid)
    desk, repo, full = {}, False, ''
    if opts.get('desk'):
        # A desk that stands: the task's project is the desk's (the form sends "-").
        folder = opts['desk']
        if not os.path.isdir(folder) or not api.desk_of(folder):
            raise ValueError('--desk names a desk folder (a worktree of a project)')
        full = api.project_of(folder, api.common_of(folder))
    elif project == '-':
        raise ValueError('a project, or --desk for a desk that stands')
    else:
        vp = api.projects()
        try:
            found = vp.match(project)
        except SystemExit as e:
            raise ValueError(f'no project {project}: vikix project list names them') from e
        full = found.full
        repo = bool((api.git(str(found.path), 'rev-parse', '--show-toplevel') or '').strip())
    if opts.get('desk'):
        open_ = [t for t in T.tasks_of_desk(api.handoff_module().desk_id(api.common_of(folder), folder), open_only=True)]
        if open_:
            raise ValueError(f"that desk has an open task already ({open_[0]['id']}): cancel it, or pick a topic for a new desk")
        rec = api.desk_record(folder, text, by)
        desk = T.desk_of_record(rec)
    elif repo and not opts.get('topic'):
        raise ValueError("a repository's task needs a desk that stands (--desk) or the topic of the desk to make (--topic)")
    topic = api.topic_name(opts['topic']) if opts.get('topic') else ''
    task = T.new(text, full, by, desk=desk, topic=topic, priority=opts.get('priority', 'normal'), worker=opts['worker'])
    if opts['after']:
        T.update(task['id'], lambda t: t.update(after=list(opts['after'])))
    if desk:
        api.handoff_module().update(api.common_of(folder), folder, lambda r: r['task'].update(id=task['id']))
    if opts.get('queue'):
        S.mutate('add', task['id'], None, by)
    print(f"Task {task['id']} made, {'queued' if opts.get('queue') else 'ready'}"
          + (f" at {short(folder)}" if desk else f", desk to make: {topic}" if topic else '')
          + ('; the scheduler starts it on your word (S, or vikix agents queue start)' if opts.get('queue') else '; Q queues it'))
    return task['id']


def quiet_minutes():
    path = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'vikix', 'office')
    try:
        with open(path) as f:
            for line in f:
                match = re.fullmatch(r'\s*quiet\s*=\s*(\d+)\s*(?:#.*)?', line.strip())
                if match:
                    return max(1, int(match[1]))
    except OSError:
        pass
    return 20


def notify_attention(items, folder):
    """Once per stable item, including across Office restarts. Explicitly
    called by the UI/notification command; a read-only snapshot never notifies."""
    if not os.environ.get('DISPLAY') or not shutil.which('notify-send'):
        return
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, 'attention-notified.json')
    with open(path + '.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(path) as f:
                seen = json.load(f)
        except (OSError, ValueError):
            seen = {}
        if not isinstance(seen, dict):
            seen = {}
        deadline = time.monotonic() + 3
        for item in items:
            if time.monotonic() >= deadline:
                break
            if item['id'] in seen:
                continue
            try:
                result = subprocess.run(['notify-send', '-a', 'Vikix', item.get('notification_title') or 'Office: ' + item['kind'], item['why'][:300]], timeout=max(0.01, deadline - time.monotonic()), check=False)
                if result.returncode == 0:
                    seen[item['id']] = int(time.time())
            except (OSError, subprocess.TimeoutExpired):
                continue
        tmp = path + '.tmp'
        with open(tmp, 'w') as f:
            json.dump(seen, f)
        os.replace(tmp, path)


def title_observations(folder):
    try:
        with open(os.path.join(folder, 'attention-titles.json')) as f:
            data = json.load(f)
            return {k: v for k, v in data.items() if isinstance(v, dict) and isinstance(v.get('digest'), str) and isinstance(v.get('at'), int)} if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def title_activity(agent, observed, now):
    title = agent.get('title') or ''
    if not title:
        return 0
    key = f"{agent['pid']}:{agent.get('process_start', '')}"
    previous = observed.get(key)
    digest = hashlib.sha256(title.encode()).hexdigest()
    # A first sighting is not evidence that a title changed just now.
    return (now if previous['digest'] != digest else previous['at']) if previous else 0


def remember_titles(data, folder):
    """Only the UI/explicit notifier keeps observations; reads stay read-only.
    Hashes suffice to notice changes and do not retain terminal titles."""
    if not data.get('live_known'):
        return
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, 'attention-titles.json')
    with open(path + '.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        before, after = title_observations(folder), {}
        for row in data.get('desks', []):
            for a in row.get('agents', []):
                if not a.get('title'):
                    continue
                key = f"{a['pid']}:{a.get('process_start', '')}"
                digest = hashlib.sha256(a['title'].encode()).hexdigest()
                old = before.get(key)
                after[key] = {'digest': digest, 'at': (old['at'] if old['digest'] == digest else data['at']) if old else 0}
        tmp = path + '.tmp'
        with open(tmp, 'w') as f:
            json.dump(after, f)
        os.replace(tmp, path)

def snapshot(api, include_queue=True):
    H = api.handoff_module()
    errors = []
    try:
        releases, releases_kept = release_queue(api)
    except (OSError, ValueError, SystemExit) as e:
        releases, releases_kept = [], False
        errors.append(f'Release queue unknown: {e}')
    try:
        plans, plan_desks = plan_rows(api)
    except Exception as e:  # noqa: BLE001  a plan that can't be read never hides the desks
        plans, plan_desks = [], {}
        errors.append(f'Plans unknown: {e}')
    # A plan done (every desk released) is the Archive's, not the first page's
    # (2026-10-11: a finished plan sat in the Plans box among the ones under way).
    plans_done = [p for p in plans if p['state'] == 'done']
    plans = [p for p in plans if p['state'] != 'done']
    try:
        agents = api.desktop(strict=True)
        agents += api.elsewhere({a['pid'] for a in agents}, strict=True)
        agents = api.seated(agents)
        api.journal_states(agents)   # working or at its prompt from the hooks' journal, where the title says nothing
        api.journal_prompts(agents)  # what each was asked (prompt, first_prompt), from the prompt hooks' notes
        live_known = True
    except (RuntimeError, OSError, ValueError) as e:
        agents, live_known = [], False
        errors.append(f'Live activity unknown: {e}')
    try:
        records = H.all_records(strict=True)
    except H.HandoffError as e:
        raise RuntimeError(str(e)) from e
    # The desks' records from before adopted first (lib/tasks.py: a task record
    # each, the ids written back), then read again, so this very snapshot has
    # the ids and the Archive's token is the same at the next one: a write
    # a snapshot makes (with settle_gone, below), and one that invents nothing.
    T = api.tasks_module()
    try:
        if T.needs_adoption(records):
            T.adopt(records)
            records = H.all_records(strict=True)
    except Exception as e:  # noqa: BLE001  a record that can't be adopted never hides the desks
        errors.append(f'Tasks not adopted: {e}')
    # The other write, of the same kind: an open task whose desk's worktree
    # is gone goes to blocked on desk (lib/tasks.py settle_gone), so it stops
    # standing in Running with a worker nobody will ever see again.
    try:
        T.settle_gone()
    except Exception as e:  # noqa: BLE001
        errors.append(f'Gone desks not settled: {e}')
    rows = {os.path.realpath(r['desk']['worktree']): dict(r) for r in records
            if isinstance(r.get('desk'), dict) and r['desk'].get('worktree')}
    try:
        for d in api.desks(api.projects()):
            path = os.path.realpath(d['folder'])
            rows.setdefault(path, {'desk': {'worktree': path, 'branch': d['branch'],
                                           'project': os.path.basename(d['top'])}})
    except (OSError, ValueError, SystemExit) as e:
        errors.append(f'Desk discovery unavailable: {e}')
    # A row for every folder an agent runs in: a desk only when the folder is one.
    folders = set()
    for a in agents:
        a['process_start'] = process_start(api, a['pid'])
        if a.get('folder'):
            path = agent_folder(a)
            if path not in rows:
                rows[path] = {'desk': {'worktree': path}}
                folders.add(path)
    held = api.waits(agents) if live_known else {}
    try:
        table = api.process_table() if live_known else {}
    except Exception:  # noqa: BLE001  the shells left are a note, never the snapshot's failure
        table = {}
    journal = api.journal_read()
    observed_titles = title_observations(api.tasks_module().OFFICE)
    for a in agents:
        events = [e for e in journal if e.get('pid') == a['pid']]
        a['activity_at'] = max(max((e.get('at', 0) for e in events), default=0), title_activity(a, observed_titles, int(time.time())))
        try:
            note = os.path.join(api.STATE, 'vikix', 'agents', str(a.get('window', '')))
            if a.get('window') and os.path.isfile(note):
                with open(note) as f:
                    bits = f.readline(200).split()
                a['note_kind'] = bits[0] if bits else ''
                a['attention_since'] = int(bits[1]) if len(bits) > 1 and bits[1].isdigit() else int(os.stat(note).st_mtime)
                a['activity_at'] = max(a['activity_at'], a['attention_since'])
        except OSError:
            pass
        if a['pid'] in held and a.get('state') in ('working', 'running', 'idle'):
            a['doing'], a['waits'] = held[a['pid']]
        # Shells it left sleeping in a loop (vikix agents tidy), while at its prompt.
        try:
            a['idle_shells'] = api.idle_shells(a['pid'], table) if table and a.get('state') not in ('working', 'running') else []
        except Exception:  # noqa: BLE001
            a['idle_shells'] = []
    default = api.default_agent()
    archive_records = []
    tasks, sequence = task_rows(api, events_grouped(api), errors)
    for path, row in rows.items():
        d = row['desk']
        # The path stays stable when an active desk gets its first handoff.
        row['id'] = path
        # A folder with no record that no project's desks list (an agent started
        # in ~, or in a project's own folder) is no desk: a worktree desks() missed
        # still is (desk_of). The view says so instead of an empty Git state.
        row['kind'] = 'folder' if path in folders and not api.desk_of(path) else 'desk'
        row['exists'] = os.path.isdir(path)
        row['agents'] = [a for a in agents if agent_folder(a) == path]
        row['live_known'] = live_known
        gone = bool(d.get('id')) and live_known and missing_folder(path) and not row['agents']
        # A desk closed in the last day is shown among the desks, as Closed;
        # older, or removed without being closed, it is archived.
        closed_at = d.get('closed') if isinstance(d.get('closed'), int) else 0
        row['closed'] = ({'at': closed_at, 'by': closed_by(row)}
                         if gone and closed_at and time.time() - closed_at < CLOSED_SHOWN else {})
        row['archived'] = gone and not row['closed']
        if row['archived']:
            archive_records.append(next((r for r in records if r.get('desk') == d), {}))
        row['now'] = H.observe(path) if row['kind'] == 'desk' else {}
        row['checks'] = [dict(c, freshness=H.freshness(c, row['now'])) for c in row.get('checks', [])]
        row['sessions'] = [dict(s, available=H.session_store(s['provider'], s['id'], path)[0])
                           for s in row.get('sessions', [])]
        handoff = row.get('handoff') or {}
        # A desk whose agent never wrote one says so plainly: it is no fault
        # of the record's.
        status = (handoff.get('status') or {}).get('value', 'no handoff')
        row['status'] = status
        # Where the work stands against the agent's estimate, as a line; '' without one.
        row['estimate'] = (H.estimate_state(row) or {}).get('line', '')
        # The desk's release, when .claude/release is at work on its branch:
        # the note's topic is the branch, in the same repository. Git is asked
        # for the repository only while a release is under way at all.
        row['release'] = ''
        # The plan this desk is a part of, and where that plan has it (lib/plan.py).
        row['plan'] = plan_desks.get(path, '')
        if releases and row['kind'] == 'desk':
            branch = row['now'].get('branch') or d.get('branch')
            mine = [r for r in releases if r['topic'] == branch]
            if mine:
                common = api.common_of(path) if row['exists'] else ''
                if common:   # a removed worktree can't say whose it was: the topic's name has to do
                    mine = [r for r in mine if r['common'] == common]
                if mine:
                    row['release'] = release_line(mine[0])
        # A row is a desk (2026-10-09, desks and workers apart): named for the
        # place, project / branch, its task and its workers under it.
        row['title'] = short(path) if row['kind'] == 'folder' else ' / '.join(
            str(x) for x in (d.get('project'), d.get('branch') or os.path.basename(path)) if x)
        row['workers'] = workers_before(row)
        row['next_action'] = (handoff.get('next') or {}).get('text', '')
        if not row['next_action']:
            row['next_action'] = ('Go to agent' if row['agents'] else 'Not a desk' if row['kind'] == 'folder'
                                  else 'Continue' if row['exists'] else 'Worktree removed')
        needs = any(a.get('state') in ('asks', 'permission', 'question', 'waiting', 'done') for a in row['agents'])
        # What the desk's terminals need of you, as the desktop colours them
        # (agents.lisp): asks over gup over close; '' when nothing.
        kinds = [a.get('attention') or '' for a in row['agents']]
        row['attention'] = next((k for k in ('asks', 'gup', 'close') if k in kinds), '')
        row['paused'] = api.pause_read(path) if row['kind'] == 'desk' else {}
        row['testing'] = api.tester_running(path) if row['kind'] == 'desk' else 0
        # The tester at work, for the Testing box: since when, what runs, the log's tail (tester_state).
        row['tester'] = api.tester_state(path) if row['kind'] == 'desk' else {}
        row['testing'] = row['testing'] or row['tester'].get('pid', 0)
        # A review of the desk under way: who reads it, since when (vikix agents review).
        row['reviewing'] = api.reviewer_running(path) if row['kind'] == 'desk' else {}
        row['notes'] = len(api.inbox_peek(path)) if row['kind'] == 'desk' else 0
        # The user's switch on the desk: a hand-in runs no tests by itself (Test still does).
        row['tests_off'] = d.get('tests') == 'off'
        row['left'] = row.get('left') or {}
        # A desk whose tests run is in Testing, whatever else it is doing (2026-10-12:
        # it sat under Needs you, in review, with nothing to do at it but wait or skip).
        row['group'] = ('Needs you' if not live_known
                        else 'Testing' if row['testing']
                        else 'Needs you' if needs or row['attention'] or status in ('waiting', 'review')
                        else 'Working' if row['agents'] and not row['paused']
                        else 'Finished' if status == 'finished' or d.get('closed')
                        # Kept aside: a status parked (vikix agents park, by the user or
                        # the agent), or a desk with no agent and nothing asked of you.
                        else 'Parked')
        if row['paused'] and row['agents']:
            row['next_action'] = 'Paused: vikix agents go ' + os.path.basename(path)
        providers = list(dict.fromkeys([s['provider'] for s in row['sessions']] + [default]))
        # Nothing to continue in a plain folder: Continue is for desks.
        row['resume'] = {p: H.resume_plan(row, p, path) for p in providers} if row['kind'] == 'desk' else {}
        row['provider'] = ', '.join(dict.fromkeys([a['agent'] for a in row['agents']] + [s['provider'] for s in row['sessions']])) or 'unrecorded'
        # How the last worker was started: its mode (Codex's: supervised, autonomous, unrestricted), '' for none.
        row['mode'] = (row.get('launch') or {}).get('mode', '') if row['kind'] == 'desk' else ''
        # The desk's task as its own record (lib/tasks.py): its id, origin, priority,
        # state, the launch with its number, its history; and the worker's state as
        # observed, with where it was read and how sure. {} for a desk with no task record.
        task = tasks.get(((row.get('task') or {}).get('id') or ''), {})
        row['task_record'] = task
        row['worker_state'] = T.worker_state(row['agents'][0] if row['agents'] else None, task) if task else {}
        if task and not live_known:
            row['worker_state'] = {'state': 'unknown', 'source': 'discovery unavailable', 'sure': 'unknown'}
        elif task and row['paused']:
            row['worker_state'] = {'state': 'paused', 'source': 'the pause file', 'sure': 'reliable'}
        if task:
            task['worker'] = row['worker_state']
            task['worker_state'] = row['worker_state']
        row['launch_seq'] = (task.get('launch') or {}).get('seq') if task else None
        # A desk ready for release whose branch and the project's own changed
        # the same lines: the release's rebase would stop on them, so the
        # Office says so instead of offering Release (2026-10-22: a Release
        # link ended in 'changed the same lines' in a terminal). Git is asked
        # (merge-tree, nothing written) only for such a desk, standing, with
        # no release under way on it; '' otherwise, or when git can't say.
        row['conflicts'] = ''
        if (task and (task.get('status') or {}).get('value') == 'ready for release'
                and row['kind'] == 'desk' and row['exists'] and not row['release']):
            found = api.release_conflicts(path)
            if found and found[1]:
                row['conflicts'] = f"conflicts with {found[0]} in {', '.join(found[1])}"
        if row['archived']:
            row['group'] = 'Archived'
            row['next_action'] = 'Archived — worktree removed'
            row['resume'] = {}
        elif row['closed']:
            row['group'] = 'Closed'
            row['next_action'] = 'Closed' + (f" by {row['closed']['by']}" if row['closed']['by'] else '') \
                + f" {H.when(row['closed']['at'])}: nothing to do"
            row['resume'] = {}
    order = ['Needs you', 'Testing', 'Working', 'Parked', 'Finished', 'Closed']
    # Version 2 (2026-10-13): tasks, the task records with their events, and
    # sequence, the last launch number; desks as before. A new version goes into
    # vikix-office-snapshot-versions (config/emacs/vikix-office.el) too, or the page
    # refuses the snapshot and the Office shows nothing (0.72.68 did; tests/office-ui.el holds them together).
    result = {'version': 2, 'at': int(time.time()), 'live_known': live_known, 'errors': errors,
            'releases': releases, 'releases_kept': releases_kept, 'plans': plans, 'plans_done': plans_done,
            'tasks': sorted(tasks.values(), key=lambda t: (0 if (t.get('launch') or {}).get('seq') else 1,
                                                           (t.get('launch') or {}).get('seq') or 0, t.get('created') or 0)),
            'sequence': sequence,
            # Who can review a desk here (vikix agents review): the Review by… button's choices.
            'reviewers': [p for p in api.REVIEWERS if api.reviewer_program(p)],
            'desks': sorted((r for r in rows.values() if not r['archived']),
                            # The closed ones newest first: the day's log.
                            key=lambda r: (order.index(r['group']), -(r['closed'] or {}).get('at', 0),
                                           r['title'].lower(), r['id'])),
            'archive': sorted((r for r in rows.values() if r['archived']), key=lambda r: (r['title'].lower(), r['id'])),
            'archive_token': hashlib.sha256(''.join(sorted(json.dumps(r, sort_keys=True) for r in archive_records)).encode()).hexdigest()}

    result['clashes'] = []
    for e in journal:
        if e.get('kind') not in ('asked', 'waiting') or not any(a['pid'] == e.get('pid') for a in agents):
            continue
        others = [(a, 'waiting') for a in agents if api.who(a) in (e.get('with') or [])]
        if e.get('file') and api.clash_live(e['file'], others):
            result['clashes'].append(e)
    result['attention'] = attention(result, quiet=quiet_minutes())
    if include_queue:
        import scheduler
        scheduler.T = api.tasks_module()
        result['queue'] = scheduler.view(scheduler.world(api, result))
    # The board: the five sections and the desks, from the rows above (phase 4).
    result['board'] = board(result)
    return result


def workers_before(row):
    """The desk's workers before the task it has now, newest first, as the
    record's history keeps them (fold_worker in lib/handoff.py): the task,
    how it ended (its status, how the agent left), who worked it, when it
    ended and the first line of its last summary."""
    out = []
    for w in (row.get('workers') or [])[::-1]:
        if not isinstance(w, dict):
            continue
        out.append({'task': str(w.get('task') or ''), 'status': str(w.get('status') or ''),
                    'provider': str(w.get('provider') or ''), 'by': str(w.get('by') or ''),
                    'at': w.get('at') if isinstance(w.get('at'), int) else 0,
                    'ended': w.get('ended') if isinstance(w.get('ended'), int) else 0,
                    'left': str(w.get('left') or ''),
                    'summary': (str(w.get('summary') or '').splitlines() or [''])[0]})
    return out


def purge_archive(api, expected_token):
    """Delete exactly the archived records the user confirmed, under writer locks."""
    H = api.handoff_module()
    before = snapshot(api)
    if before['errors'] or not before['live_known']:
        raise RuntimeError('Cannot purge while discovery is unavailable; refresh first')
    if before['archive_token'] != expected_token:
        raise RuntimeError('Archive changed; refresh and confirm again')
    paths = sorted(H.record_path(r['desk']['id']) for r in before['archive'] if r['desk'].get('id'))
    with ExitStack() as locks:
        for path in paths:
            lock = locks.enter_context(open(path + '.lock', 'w'))
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as e:
                raise RuntimeError('A handoff is being updated; try again after it finishes') from e
        # Recheck activity, folders and record contents after taking all locks.
        current = snapshot(api)
        if current['errors'] or not current['live_known'] or current['archive_token'] != expected_token:
            raise RuntimeError('Archive or live activity changed; refresh and confirm again')
        for path in paths:
            os.unlink(path)
        # Keep the empty lock files: unlinking them can split waiting writers
        # across two different lock inodes. No task or conversation is in them.
    print(f'Purged {len(paths)} archived desk records. Project files and provider conversations were not changed.')


def forget_record(api, did):
    """One removed desk's record (archived, or closed today), forgotten by
    its id: the same refusals as vikix agents handoff forget (the folder
    stands, an agent is in it)."""
    H = api.handoff_module()
    if not H.DESK_ID.match(str(did)):
        raise ValueError('Forget needs a desk record id')
    rec = H.load(did)
    if not rec:
        raise RuntimeError('No such record; refresh the Office')
    try:
        print(api.forget_record(rec))
    except H.HandoffError as e:
        raise RuntimeError(str(e)) from e


def desk_action(api, verb, path, text=''):
    """A worker's desk acted on from the Office: pause or unpause, parked
    (vikix agents park), its tests started or skipped, a note left, a
    review by TEXT's provider started. PATH is a desk's folder, as the
    row's id is."""
    if not isinstance(path, str) or not os.path.isdir(path) or not api.desk_of(path):
        raise ValueError('Needs a desk folder (a worktree of a project)')
    if verb == 'pause':
        print(api.go_folder(path) if os.path.exists(api.pause_path(path)) else api.pause_folder(path, 'user'))
    elif verb == 'unpause':
        print(api.go_folder(path))
    elif verb == 'park':
        print(api.park_folder(path, 'user'))
    elif verb == 'test':
        if not api.runner_of(path)[1]:
            raise RuntimeError('No tests/run.sh in this project: nothing to run')
        if api.tester_running(path):
            raise RuntimeError('A tester is at work there already; refresh')
        api.tester_start(path)
        print("Tests started; the result goes into the handoff and the agent's inbox.")
    elif verb == 'skip':
        H = api.handoff_module()
        try:
            print(api.tester_skip(path, 'user'))
        except H.HandoffError as e:
            raise RuntimeError(str(e)) from e
    elif verb == 'tell':
        H = api.handoff_module()
        try:
            api.inbox_add(path, text, 'user')
        except H.HandoffError as e:
            raise RuntimeError(str(e)) from e
        print('Noted for its agent; delivered at its next tool call.')
    elif verb == 'review':
        if text not in api.REVIEWERS:
            raise ValueError(f"Review by which? {', '.join(api.REVIEWERS)}")
        if not api.reviewer_program(text):
            raise RuntimeError(f"{text} isn't installed here: vikix agent --install {text}")
        if api.reviewer_running(path):
            raise RuntimeError('A review is under way there already; refresh')
        if not (api.git(path, 'rev-parse', 'HEAD') or '').strip():
            raise RuntimeError('No commit to review yet')
        api.review_start(path, text)
        print(f"Review by {text} started on its last commit; the findings go into the handoff and the agent's inbox.")


def form(api):
    """What the desk form offers: the projects (the full name, which
    vikix agents desk takes as it is; the folder; whether it is a
    repository, so a topic is needed; the next step from its log), the
    agents as vikix agent --list has them, yours first, with which can
    run on a model on this laptop, and whether a terminal can open here."""
    vp = api.projects()
    projects = []
    for p, full, _pct, _date, nxt in vp.rows(vp.discover(), True):
        path = str(p.path)
        projects.append({'name': full, 'path': path, 'short': short(path),
                         'repo': bool((api.git(path, 'rev-parse', '--show-toplevel') or '').strip()),
                         'next': nxt})
    agents = [{'name': name, 'yours': yours, 'installed': installed, 'about': about,
               'local': name in api.LOCAL and installed}
              for name, yours, installed, about in api.agents_offered()]
    agents.sort(key=lambda a: not a['yours'])
    sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
    import plan
    roots, logs, _depth = vp.read_config()
    return {'projects': projects, 'agents': agents, 'default': api.default_agent(),
            'modes': list(api.MODES), 'mode': api.default_mode(),
            'display': bool(os.environ.get('DISPLAY')),
            # The New plan form's part: the templates, each with its tasks (the form's fields), and where the plan goes.
            'templates': [t for t in plan.templates() if not t['error']], 'plans_folder': plan.PLANS_HOME,
            # The New project form's part: where a project goes, where a log kept apart goes,
            # and GitHub's account through gh (null: gh is not installed, not signed in, or GitHub is out of reach).
            'root': str(roots[0]), 'logs': str(logs), 'gh': bool(shutil.which('gh')), 'github': github_account(),
            'guide': guide_file()}


def github_account():
    """The GitHub login gh is signed in as, or None: not installed, not
    signed in (gh auth login), or GitHub out of reach. Asked of GitHub
    itself, since a token can have expired, with a bound: the form waits
    on it."""
    if not shutil.which('gh'):
        return None
    try:
        r = subprocess.run(['gh', 'api', 'user', '-q', '.login'], capture_output=True, text=True, timeout=8)
    except (OSError, subprocess.TimeoutExpired):
        return None
    login = r.stdout.strip()
    return login if r.returncode == 0 and login else None


PROJECT_WHERE = ('public', 'private', 'local', 'folder')


def new_project(api, args):
    """The Office's New project: NAME --where public|private|local|folder
    [--title "..."] [--next "..."] [--description "..."] [--log-apart],
    handed to vikix project new as its words: --github public|private, --git
    for local, nothing for a folder with a log alone."""
    usage = ('vikix agents office --project NAME --where public|private|local|folder '
             '[--title "..."] [--next "..."] [--description "..."] [--log-apart]')
    rest = list(args)
    if not rest or rest[0].startswith('-'):
        raise ValueError(usage)
    name = rest.pop(0).strip()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', name):
        raise ValueError("The project's name is a word: letters, digits, dots, dashes (my-book); it names the folder and the repository")
    opts = {}
    while rest:
        a = rest.pop(0)
        if a in ('--where', '--title', '--next', '--description'):
            if not rest or not rest[0].strip():
                raise ValueError(f'{a} needs its words' if a != '--where' else '--where which? public, private, local, folder')
            opts[a] = rest.pop(0).strip()
        elif a == '--log-apart':
            opts[a] = True
        else:
            raise ValueError(usage)
    where = opts.get('--where')
    if where not in PROJECT_WHERE:
        raise ValueError(f"--where which? {', '.join(PROJECT_WHERE)}")
    if where == 'folder' and '--description' in opts:
        raise ValueError('A description goes into a README, which a folder with a log alone has not: pick a repository')
    words = ['new', name]
    if where in ('public', 'private'):
        words += ['--github', where]
    elif where == 'local':
        words.append('--git')
    for a in ('--title', '--next', '--description'):
        if a in opts:
            words += [a, opts[a]]
    if opts.get('--log-apart'):
        words.append('--log-apart')
    return run_project(api, words)


def run_project(api, words):
    """vikix project with WORDS, its output through; a RuntimeError with
    its words when it refuses. Apart, so the tests stand in for it."""
    r = subprocess.run([sys.executable, os.path.join(api.VIKIX_DIR, 'bin', 'vikix-project'), *words],
                       capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip() or f'vikix project {words[0]} failed')
    return 0


def guide_file():
    """The Vikix manual as 40-config installs it, for the Office's Guide
    button (Emacs's Info opens a file named in the node); '' when it isn't there."""
    data = os.environ.get('XDG_DATA_HOME') or os.path.join(os.path.expanduser('~'), '.local', 'share')
    path = os.path.join(data, 'info', 'vikix.info')
    return path if os.path.isfile(path) else ''


def new_plan(api, args):
    """The Office's New plan: TEMPLATE NAME PROJECT [--at-once N] [--gate me|none]
    [--tasks], handed to lib/plan.py's new_plan; with --tasks, the plan's
    tasks come as JSON on stdin (a list, each a task's TOML keys), the
    form's fields, and the file is composed from them. Prints the file's
    path alone, for the Office to open; the words are the form's."""
    sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
    import plan
    at_once, gate, tasks, rest = None, None, None, []
    it = iter(args)
    for w in it:
        if w == '--tasks':
            try:
                tasks = json.load(sys.stdin)
            except ValueError as e:
                raise ValueError(f'--tasks: the tasks on stdin are not JSON: {e}') from e
            if not isinstance(tasks, list):
                raise ValueError('--tasks: the tasks on stdin are a JSON list, a task each')
        elif w == '--at-once':
            n = next(it, '')
            if not n.isdigit():
                raise ValueError('--at-once takes a number of workers')
            at_once = int(n)
        elif w == '--gate':
            gate = next(it, None)
        elif w.startswith('-'):
            raise ValueError(f'vikix agents office --plan: {w}? (--at-once N, --gate me|none, --tasks)')
        else:
            rest.append(w)
    if len(rest) != 3 or not all(rest):
        raise ValueError('vikix agents office --plan TEMPLATE NAME PROJECT [--at-once N] [--gate me|none] [--tasks]')
    try:
        print(plan.new_plan(rest[0], rest[1].strip(), rest[2], at_once, gate, tasks))
    except plan.PlanError as e:
        raise RuntimeError(str(e)) from e


def worker_words(args, what):
    """The worker's words from the form's ARGS, as vikix agents WHAT takes
    them: --use NAME, --local, --push, --no-tests, --mode MODE. Anything
    else is refused, so a form out of step with the command says so instead
    of starting an agent with words it didn't mean."""
    out, rest = [], list(args)
    while rest:
        a = rest.pop(0)
        if a in ('--use', '--mode'):
            if not rest or rest[0].startswith('-'):
                raise ValueError('--use which agent?' if a == '--use' else '--mode which? supervised, autonomous, unrestricted')
            out += [a, rest.pop(0)]
        elif a in ('--local', '--push', '--no-tests'):
            out.append(a)
        else:
            raise ValueError(f'vikix agents office --{what}: {a}? (--use NAME, --local, --push, --no-tests, --mode MODE)')
    return out


def new_desk(api, args):
    """The Office's New desk: PROJECT [TOPIC] [--task "..."] and the
    worker's words, handed to vikix agents desk, which asks nothing when
    the project is named. A task starts a worker at the desk."""
    words, task, rest = [], None, list(args)
    while rest and not rest[0].startswith('-'):
        words.append(rest.pop(0))
    if '--task' in rest:
        i = rest.index('--task')
        if i + 1 >= len(rest):
            raise ValueError('--task needs the words of the task')
        task = rest[i + 1].strip()
        del rest[i:i + 2]
    words = [w for w in words if w]   # a project that is no repository: no topic
    if not words:
        raise ValueError('vikix agents office --desk PROJECT [TOPIC] [--task "..."] [--use NAME] [--local] [--push] [--no-tests] [--mode MODE]')
    agent = worker_words(rest, 'desk')
    if task:
        return api.desk(words + ['--task', task] + agent)
    # Nobody sits at a desk alone: the agent's words would be refused; the setting stays.
    return api.desk(words + [w for w in agent if w == '--no-tests'])


def new_worker(api, args):
    """The Office's Worker: DESK ["..."] and the worker's words, handed to
    vikix agents worker. DESK is the desk's folder, the snapshot's id."""
    rest = list(args)
    if not rest or not os.path.isdir(rest[0]) or not api.desk_of(rest[0]):
        raise ValueError('Needs a desk folder (a worktree of a project)')
    folder = rest.pop(0)
    task = rest.pop(0).strip() if rest and not rest[0].startswith('-') else ''
    return api.worker([folder] + ([task] if task else []) + worker_words(rest, 'worker'))


def close_desk(api, args):
    """The Office's Close desk: DESK [--force], handed to vikix agents close,
    which refuses one with an agent at it or files uncommitted (--force
    throws the files and an unmerged branch away). DESK is the desk's
    folder, the snapshot's id."""
    rest = list(args)
    if not rest or not os.path.isdir(rest[0]) or not api.desk_of(rest[0]):
        raise ValueError('Needs a desk folder (a worktree of a project)')
    folder = rest.pop(0)
    if rest not in ([], ['--force']):
        raise ValueError('vikix agents office --close-desk DESK [--force]')
    return api.close([folder] + rest)


def process_start(api, pid):
    """Linux start ticks distinguish a process from a later reuse of its PID."""
    try:
        with open(f'{api.PROC}/{pid}/stat') as f:
            return f.read().rsplit(')', 1)[1].split()[19]
    except (OSError, IndexError):
        return None


def close_agent(api, pid, expected_start):
    if not str(pid).isdigit() or int(pid) <= 1 or not str(expected_start).isdigit():
        raise ValueError('Close agent needs a process number and its start identity')
    pid = int(pid)
    if not hasattr(os, 'pidfd_open') or not hasattr(signal, 'pidfd_send_signal'):
        raise RuntimeError('Safe agent closing needs Linux process descriptor support')
    # Pin the process before rechecking identity. Never signal a bare PID or
    # a process group: that could reach a replacement or an unrelated shell.
    fd = os.pidfd_open(pid)
    try:
        if process_start(api, pid) != expected_start or api.agent_name(api.cmdline(pid)) is None:
            raise RuntimeError('Agent ended or changed; refresh the Office')
        signal.pidfd_send_signal(fd, signal.SIGTERM)
        poll = select.poll()
        poll.register(fd, select.POLLIN)
        if poll.poll(3000):
            print('Agent closed. Desk, branch and files retained.')
        else:
            print('Close requested; agent is still exiting. Refresh to check. Desk and files retained.')
    finally:
        os.close(fd)


def focus(api, pid):
    # Resolve the PID again inside the desktop, rather than trusting a stale
    # workspace/window number from a snapshot. Only an integer enters Lisp.
    if not str(pid).isdigit() or int(pid) <= 0:
        raise ValueError('Go to agent needs a positive process number')
    form = (f"(let ((a (find {int(pid)} (vikix-agents) :key (lambda (a) (getf a :pid))))) "
            '(unless a (error "Agent has no desktop window, or has ended")) '
            '(vikix-show-window (getf a :window)))')
    r = subprocess.run([api.EVAL, form], capture_output=True, text=True, timeout=20)
    if r.returncode or 'error: ' in r.stdout + r.stderr:
        raise RuntimeError((r.stderr or r.stdout).strip() or 'Desktop did not answer')


def show_again(api, answer):
    """The Office was open already: ANSWER, emacsclient's, is its frame's X
    window id as a string (vikix-office-open), nil for a frame made now.
    Emacs selecting the frame itself is not heard by StumpWM from another
    workspace or behind another window, so the desktop is asked to go to
    it. Only an integer enters Lisp, and a desktop that doesn't answer
    costs nothing: the Office is open all the same."""
    found = re.fullmatch(r'"([0-9]+)"', (answer or '').strip())
    if not found:
        return
    form = f'(vikix-show-window-id {int(found.group(1))})'
    subprocess.run([api.EVAL, form], capture_output=True, text=True, check=False, timeout=20)


def launch(api, tty=False):
    """Open the Office in the user's existing Emacs: an X frame of its own
    on the desktop, or, with no DISPLAY or with --tty, in this terminal."""
    source = os.path.join(api.VIKIX_DIR, 'config', 'emacs', 'vikix-office.el')
    load = '(load ' + json.dumps(source, ensure_ascii=False) + ' nil t)'
    if shutil.which('emacsclient'):
        if tty or not os.environ.get('DISPLAY'):
            # The terminal path: a headless server, SSH, or --tty. emacsclient
            # -nw with --eval, as Emacs 29 on does it (checked on 31): the
            # client's tty frame is made and selected first, the form is
            # evaluated in it, and the client stays until that frame is
            # deleted, so the Office takes over this terminal and q (which
            # deletes the frame) gives the shell back. No --create-frame is
            # needed, and --eval alone would run in the daemon's invisible
            # frame. The terminal is the Office's while it runs: no timeout,
            # and only stderr is caught, for the error message when there is
            # no server.
            form = '(progn ' + load + ' (vikix-office-open-here t))'
            try:
                result = subprocess.run(['emacsclient', '--alternate-editor=false', '-nw', '--eval', form],
                                        stderr=subprocess.PIPE, text=True)
            except OSError as e:
                raise RuntimeError(f'The Office could not run emacsclient: {e}. '
                                   'No second Emacs was started.') from e
            if result.returncode:
                detail = (result.stderr or '').strip()[:400] or 'emacsclient failed'
                raise RuntimeError('The Office could not open in the existing Emacs. '
                                   'In that Emacs, use M-x server-start if needed, then try again. '
                                   f'vikix agents remains available. Details: {detail}')
            return
        display = json.dumps(os.environ.get('DISPLAY', ''), ensure_ascii=False)
        form = '(progn ' + load + ' (vikix-office-open ' + display + '))'
        # Override ALTERNATE_EDITOR too: a connection failure must never
        # start another Emacs competing for the user's saved desktop.
        try:
            result = subprocess.run(['emacsclient', '--alternate-editor=false', '--eval', form],
                                    capture_output=True, text=True, timeout=8)
        except subprocess.TimeoutExpired as e:
            raise RuntimeError('The Office: Emacs did not answer within 8 seconds. '
                               'Finish any prompt in your existing Emacs, or wait, then try again. '
                               'No second Emacs was started.') from e
        except OSError as e:
            raise RuntimeError(f'The Office could not run emacsclient: {e}. '
                               'No second Emacs was started.') from e
        if result.returncode:
            detail = (result.stderr or result.stdout).strip()[:400] or 'emacsclient failed'
            raise RuntimeError('The Office could not open in the existing Emacs. '
                               'In that Emacs, use M-x server-start if needed, then try again. '
                               f'vikix agents remains available. Details: {detail}')
        show_again(api, result.stdout)
        return
    if shutil.which('emacs'):
        raise RuntimeError('The Office needs emacsclient to use your existing Emacs. '
                           'emacsclient is not available; use vikix agents in a terminal.')
    # Preserve the existing desktop menu and terminal interface on machines
    # without Emacs. No new dependency is installed just to open the Office.
    print('The Office needs Emacs; opening the existing agent menu. Use vikix agents in a terminal.')
    subprocess.run([api.EVAL, '(run-with-timer 0 nil (lambda () (run-commands "vikix-agents-pick")))'],
                   check=False, timeout=20)


def release_action(api, folder, summary):
    by, me = api.by_me()
    if me or by != 'user':
        raise ValueError('the user starts a release from the Office')
    folder, rec = api.desk_for([folder])
    script = os.path.join(folder, '.claude', 'release')
    summary = api.tasks_module().word(summary, 'release summary', 200).strip()
    if not summary or not rec or not os.path.isfile(script):
        raise ValueError('this desk needs a release script and a summary')
    branch = rec['desk'].get('branch') or ''
    if not branch or branch.startswith('-'):
        raise ValueError('the desk has no release branch')
    found = api.release_conflicts(folder)
    if found and found[1]:
        raise ValueError(f"{branch} and {found[0]} changed the same lines ({', '.join(found[1])}): "
                         f"in {folder} run git rebase {found[0]}, settle them, and release again")
    # A terminal preserves the release workflow and its visible checks.
    # The summary is an argv element, never shell source.
    api.open_terminal(folder, ['bash', '-c', '"$@"; code=$?; read -r -p "Press Enter to close"; exit "$code"',
                               'office-release', script, branch, summary])
    print('Release opened in a terminal; nothing pushed.')


def review_action(api, folder, accept, text=''):
    by, me = api.by_me()
    if me or by != 'user':
        raise ValueError('only the user accepts a review or sends it back')
    folder, rec = api.desk_for([folder])
    T = api.tasks_module()
    task = T.load((rec or {}).get('task', {}).get('id', ''))
    if not task or task['status']['value'] != 'needs review':
        raise ValueError('this task is no longer waiting for review; refresh first')
    if accept:
        checks = rec.get('checks') or []
        latest = checks[-1] if checks else {}
        if rec['desk'].get('tests') != 'off' and (not latest.get('ok') or latest.get('skipped') or api.handoff_module().freshness(latest, api.handoff_module().observe(folder)) != 'fresh'):
            raise ValueError('run the tests on the current code before accepting the review')
        api.handoff_apply(folder, {'status': 'finished', 'next': 'Review accepted by the user; ready for release.'}, by)
        print('Review accepted; ready for release.')
    else:
        text = T.clean(text, 'review feedback').strip()
        if not text:
            raise ValueError('say what needs changing')
        api.inbox_add(folder, text, by)
        api.handoff_apply(folder, {'status': 'working', 'next': text}, by)
        print('Sent back to work; feedback is in the inbox.')


def main(api, args):
    if args in (['--json'], ['--json', '--notify']):
        data = snapshot(api)
        if '--notify' in args:
            remember_titles(data, api.tasks_module().OFFICE)
            notify_attention(data['attention'], api.tasks_module().OFFICE)
        print(json.dumps(data, ensure_ascii=False))
    elif len(args) == 3 and args[0] == '--release':
        release_action(api, args[1], args[2])
    elif len(args) == 2 and args[0] == '--accept':
        review_action(api, args[1], True)
    elif len(args) == 3 and args[0] == '--back':
        review_action(api, args[1], False, args[2])
    elif len(args) == 3 and args[0] == '--answer':
        return api.answer_cmd(args[1:])
    elif len(args) == 2 and args[0] == '--go':
        focus(api, args[1])
    elif len(args) == 3 and args[0] == '--close-agent':
        close_agent(api, args[1], args[2])
    elif len(args) == 2 and args[0] == '--purge-archive':
        purge_archive(api, args[1])
    elif len(args) == 2 and args[0] == '--forget':
        forget_record(api, args[1])
    elif len(args) == 2 and args[0] in ('--pause', '--unpause', '--test', '--skip', '--park'):
        desk_action(api, args[0][2:], args[1])
    elif len(args) == 3 and args[0] == '--tell':
        desk_action(api, 'tell', args[1], args[2])
    elif len(args) == 3 and args[0] == '--review':
        desk_action(api, 'review', args[1], args[2])
    elif args == ['--form']:
        print(json.dumps(form(api), ensure_ascii=False))
    elif args and args[0] == '--plan':
        new_plan(api, args[1:])
    elif args and args[0] == '--desk':
        return new_desk(api, args[1:])
    elif args and args[0] == '--worker':
        return new_worker(api, args[1:])
    elif args and args[0] == '--close-desk':
        return close_desk(api, args[1:])
    elif args and args[0] == '--project':
        return new_project(api, args[1:])
    elif args and args[0] == '--new-task':
        new_task(api, args[1:])
    elif args in ([], ['--tty']):
        launch(api, tty=bool(args))
    else:
        raise ValueError('vikix agents office [--tty | --json [--notify] | --answer ID TEXT | --accept DESK | --back DESK TEXT | --release DESK TEXT | --go PID | --close-agent PID START | --forget ID | --purge-archive TOKEN | --pause DESK | --unpause DESK | --park DESK | --test DESK | --skip DESK | --tell DESK TEXT | --review DESK PROVIDER | --form | --plan TEMPLATE NAME PROJECT [--at-once N] [--gate me|none] [--tasks] | --desk PROJECT [TOPIC] [--task "..."] [--use NAME] [--local] [--push] [--no-tests] [--mode MODE] | --worker DESK ["..."] [--use NAME] [--local] [--push] [--no-tests] [--mode MODE] | --close-desk DESK [--force] | --project NAME --where public|private|local|folder [--title "..."] [--next "..."] [--description "..."] [--log-apart] | --new-task PROJECT "task" [--desk FOLDER | --topic TOPIC] [--priority LEVEL] [--after ID]... [--use NAME] [--local] [--push] [--no-tests] [--mode MODE] [--queue]]')
    if args and args[0] in ('--unpause', '--pause'):
        api.scheduler_module().wake(os.path.join(api.VIKIX_DIR, 'bin', 'vikix-agents'))
    return 0
