"""The Office: desk snapshots and explicit user actions.

Terminal clients and the Emacs view share a read-only snapshot; unavailable
discovery is explicitly different from an empty office.
"""
import json
import hashlib
import fcntl
from contextlib import ExitStack
import os
import re
import select
import signal
import shutil
import subprocess
import time


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
# beside its lock in the repository's common git dir. Five lines: the topic,
# what it is doing (checking, testing (quick), waiting for its turn, ...),
# since when (epoch seconds), "no version" for a --plain release or nothing,
# and the summary. The script's --queue reads them the same way.
QUEUE_DIR = 'vikix-release-queue'


def release_queue(api):
    """The releases under way in the projects' repositories, the one whose
    turn it is first, then the waiting by when they came; and whether any
    repository has the notes' folder at all (so an empty queue can be told
    from a machine that never released). Read only: a note whose process
    has ended is skipped and left for the script, which clears it."""
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
                    lines = (f.read().split('\n') + [''] * 5)[:5]
            except OSError:
                continue
            topic, state, since, kind, summary = (l.strip() for l in lines)
            if not topic:
                continue
            rows.append({'project': name, 'common': common, 'pid': pid, 'topic': topic, 'state': state or 'unknown',
                         'since': int(since) if since.isdigit() else None, 'kind': kind, 'summary': summary,
                         'waiting': state.startswith('waiting')})
    rows.sort(key=lambda r: (r['waiting'], r['since'] or 0, r['topic']))
    return rows, kept


def release_line(release):
    """One release as the desk's row says it: what it does, since when."""
    since = time.strftime('%H:%M', time.localtime(release['since'])) if release['since'] else '?'
    return f"{release['state']} · since {since}" + (f" · {release['kind']}" if release['kind'] else '')


def snapshot(api):
    H = api.handoff_module()
    errors = []
    try:
        releases, releases_kept = release_queue(api)
    except (OSError, ValueError, SystemExit) as e:
        releases, releases_kept = [], False
        errors.append(f'Release queue unknown: {e}')
    try:
        agents = api.desktop(strict=True)
        agents += api.elsewhere({a['pid'] for a in agents}, strict=True)
        agents = api.seated(agents)
        live_known = True
    except (RuntimeError, OSError, ValueError) as e:
        agents, live_known = [], False
        errors.append(f'Live activity unknown: {e}')
    try:
        records = H.all_records(strict=True)
    except H.HandoffError as e:
        raise RuntimeError(str(e)) from e
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
    for a in agents:
        if a['pid'] in held and a.get('state') in ('working', 'running', 'idle'):
            a['doing'], a['waits'] = held[a['pid']]
    default = api.default_agent()
    archive_records = []
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
        row['archived'] = bool(d.get('id')) and live_known and missing_folder(path) and not row['agents']
        if row['archived']:
            archive_records.append(next((r for r in records if r.get('desk') == d), {}))
        row['now'] = H.observe(path) if row['kind'] == 'desk' else {}
        row['checks'] = [dict(c, freshness=H.freshness(c, row['now'])) for c in row.get('checks', [])]
        row['sessions'] = [dict(s, available=H.session_store(s['provider'], s['id'], path)[0])
                           for s in row.get('sessions', [])]
        handoff = row.get('handoff') or {}
        status = (handoff.get('status') or {}).get('value', 'unrecorded')
        row['status'] = status
        # Where the work stands against the agent's estimate, as a line; '' without one.
        row['estimate'] = (H.estimate_state(row) or {}).get('line', '')
        # The desk's release, when .claude/release is at work on its branch:
        # the note's topic is the branch, in the same repository. Git is asked
        # for the repository only while a release is under way at all.
        row['release'] = ''
        if releases and row['kind'] == 'desk':
            branch = row['now'].get('branch') or d.get('branch')
            mine = [r for r in releases if r['topic'] == branch]
            if mine:
                common = api.common_of(path) if row['exists'] else ''
                if common:   # a removed worktree can't say whose it was: the topic's name has to do
                    mine = [r for r in mine if r['common'] == common]
                if mine:
                    row['release'] = release_line(mine[0])
        row['title'] = (row.get('task') or {}).get('text') or (short(path) if row['kind'] == 'folder' else ' / '.join(
            str(x) for x in (d.get('project'), d.get('branch') or os.path.basename(path)) if x))
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
        row['notes'] = len(api.inbox_peek(path)) if row['kind'] == 'desk' else 0
        # The user's switch on the desk: a hand-in runs no tests by itself (Test still does).
        row['tests_off'] = d.get('tests') == 'off'
        row['left'] = row.get('left') or {}
        row['group'] = ('Needs you' if needs or row['attention'] or status in ('waiting', 'review') or not live_known
                        else 'Working' if row['agents'] and not row['paused']
                        else 'Finished' if status == 'finished' or d.get('closed')
                        else 'Parked')
        if row['paused'] and row['agents']:
            row['next_action'] = 'Paused: vikix agents go ' + os.path.basename(path)
        providers = list(dict.fromkeys([s['provider'] for s in row['sessions']] + [default]))
        # Nothing to continue in a plain folder: Continue is for desks.
        row['resume'] = {p: H.resume_plan(row, p, path) for p in providers} if row['kind'] == 'desk' else {}
        row['provider'] = ', '.join(dict.fromkeys([a['agent'] for a in row['agents']] + [s['provider'] for s in row['sessions']])) or 'unrecorded'
        if row['archived']:
            row['group'] = 'Archived'
            row['next_action'] = 'Archived — worktree removed'
            row['resume'] = {}
    order = ['Needs you', 'Working', 'Parked', 'Finished']
    return {'version': 1, 'at': int(time.time()), 'live_known': live_known, 'errors': errors,
            'releases': releases, 'releases_kept': releases_kept,
            'desks': sorted((r for r in rows.values() if not r['archived']),
                            key=lambda r: (order.index(r['group']), r['title'].lower(), r['id'])),
            'archive': sorted((r for r in rows.values() if r['archived']), key=lambda r: (r['title'].lower(), r['id'])),
            'archive_token': hashlib.sha256(''.join(sorted(json.dumps(r, sort_keys=True) for r in archive_records)).encode()).hexdigest()}


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
    """One archived record, forgotten by its id: the same refusals as
    vikix agents handoff forget (the folder stands, an agent is in it)."""
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
    """A worker's desk acted on from the Office: pause or unpause, its
    tests started, a note left. PATH is a desk's folder, as the row's id is."""
    if not isinstance(path, str) or not os.path.isdir(path) or not api.desk_of(path):
        raise ValueError('Needs a desk folder (a worktree of a project)')
    if verb == 'pause':
        print(api.go_folder(path) if os.path.exists(api.pause_path(path)) else api.pause_folder(path, 'user'))
    elif verb == 'unpause':
        print(api.go_folder(path))
    elif verb == 'test':
        if not api.runner_of(path)[1]:
            raise RuntimeError('No tests/run.sh in this project: nothing to run')
        if api.tester_running(path):
            raise RuntimeError('A tester is at work there already; refresh')
        api.tester_start(path)
        print("Tests started; the result goes into the handoff and the agent's inbox.")
    elif verb == 'tell':
        H = api.handoff_module()
        try:
            api.inbox_add(path, text, 'user')
        except H.HandoffError as e:
            raise RuntimeError(str(e)) from e
        print('Noted for its agent; delivered at its next tool call.')


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
    return {'projects': projects, 'agents': agents, 'default': api.default_agent(),
            'display': bool(os.environ.get('DISPLAY'))}


def worker_words(args, what):
    """The worker's words from the form's ARGS, as vikix agents WHAT takes
    them: --use NAME, --local, --push, --no-tests. Anything else is refused,
    so a form out of step with the command says so instead of starting an
    agent with words it didn't mean."""
    out, rest = [], list(args)
    while rest:
        a = rest.pop(0)
        if a == '--use':
            if not rest or rest[0].startswith('-'):
                raise ValueError('--use which agent?')
            out += ['--use', rest.pop(0)]
        elif a in ('--local', '--push', '--no-tests'):
            out.append(a)
        else:
            raise ValueError(f'vikix agents office --{what}: {a}? (--use NAME, --local, --push, --no-tests)')
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
        raise ValueError('vikix agents office --desk PROJECT [TOPIC] [--task "..."] [--use NAME] [--local] [--push] [--no-tests]')
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


def main(api, args):
    if args == ['--json']:
        print(json.dumps(snapshot(api), ensure_ascii=False))
    elif len(args) == 2 and args[0] == '--go':
        focus(api, args[1])
    elif len(args) == 3 and args[0] == '--close-agent':
        close_agent(api, args[1], args[2])
    elif len(args) == 2 and args[0] == '--purge-archive':
        purge_archive(api, args[1])
    elif len(args) == 2 and args[0] == '--forget':
        forget_record(api, args[1])
    elif len(args) == 2 and args[0] in ('--pause', '--unpause', '--test'):
        desk_action(api, args[0][2:], args[1])
    elif len(args) == 3 and args[0] == '--tell':
        desk_action(api, 'tell', args[1], args[2])
    elif args == ['--form']:
        print(json.dumps(form(api), ensure_ascii=False))
    elif args and args[0] == '--desk':
        return new_desk(api, args[1:])
    elif args and args[0] == '--worker':
        return new_worker(api, args[1:])
    elif args in ([], ['--tty']):
        launch(api, tty=bool(args))
    else:
        raise ValueError('vikix agents office [--tty | --json | --go PID | --close-agent PID START | --forget ID | --purge-archive TOKEN | --pause DESK | --unpause DESK | --test DESK | --tell DESK TEXT | --form | --desk PROJECT [TOPIC] [--task "..."] [--use NAME] [--local] [--push] [--no-tests] | --worker DESK ["..."] [--use NAME] [--local] [--push] [--no-tests]]')
    return 0
