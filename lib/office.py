"""The Office: desk snapshots and explicit user actions.

Terminal clients and the Emacs view share a read-only snapshot; unavailable
discovery is explicitly different from an empty office.
"""
import json
import hashlib
import fcntl
from contextlib import ExitStack
import os
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


def snapshot(api):
    H = api.handoff_module()
    errors = []
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
    for a in agents:
        a['process_start'] = process_start(api, a['pid'])
        if a.get('folder'):
            path = agent_folder(a)
            rows.setdefault(path, {'desk': {'worktree': path}})
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
        row['exists'] = os.path.isdir(path)
        row['agents'] = [a for a in agents if agent_folder(a) == path]
        row['live_known'] = live_known
        row['archived'] = bool(d.get('id')) and live_known and missing_folder(path) and not row['agents']
        if row['archived']:
            archive_records.append(next((r for r in records if r.get('desk') == d), {}))
        row['now'] = H.observe(path)
        row['checks'] = [dict(c, freshness=H.freshness(c, row['now'])) for c in row.get('checks', [])]
        row['sessions'] = [dict(s, available=H.session_store(s['provider'], s['id'], path)[0])
                           for s in row.get('sessions', [])]
        handoff = row.get('handoff') or {}
        status = (handoff.get('status') or {}).get('value', 'unrecorded')
        row['status'] = status
        row['title'] = (row.get('task') or {}).get('text') or ' / '.join(
            str(x) for x in (d.get('project'), d.get('branch') or os.path.basename(path)) if x)
        row['next_action'] = (handoff.get('next') or {}).get('text', '')
        if not row['next_action']:
            row['next_action'] = 'Go to agent' if row['agents'] else 'Continue' if row['exists'] else 'Worktree removed'
        needs = any(a.get('state') in ('asks', 'permission', 'question', 'waiting', 'done') for a in row['agents'])
        row['group'] = ('Needs you' if needs or status in ('waiting', 'review') or not live_known
                        else 'Working' if row['agents'] else 'Finished' if status == 'finished' or d.get('closed')
                        else 'Parked')
        providers = list(dict.fromkeys([s['provider'] for s in row['sessions']] + [default]))
        row['resume'] = {p: H.resume_plan(row, p, path) for p in providers}
        row['provider'] = ', '.join(dict.fromkeys([a['agent'] for a in row['agents']] + [s['provider'] for s in row['sessions']])) or 'unrecorded'
        if row['archived']:
            row['group'] = 'Archived'
            row['next_action'] = 'Archived — worktree removed'
            row['resume'] = {}
    order = ['Needs you', 'Working', 'Parked', 'Finished']
    return {'version': 1, 'at': int(time.time()), 'live_known': live_known, 'errors': errors,
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
            '(if (vikix-agent-away-p a) (vikix-bring-window-here (getf a :window)) '
            '(vikix-goto-window (getf a :window))))')
    r = subprocess.run([api.EVAL, form], capture_output=True, text=True, timeout=20)
    if r.returncode or 'error: ' in r.stdout + r.stderr:
        raise RuntimeError((r.stderr or r.stdout).strip() or 'Desktop did not answer')


def launch(api):
    source = os.path.join(api.VIKIX_DIR, 'config', 'emacs', 'vikix-office.el')
    display = json.dumps(os.environ.get('DISPLAY', ''), ensure_ascii=False)
    form = '(progn (load ' + json.dumps(source, ensure_ascii=False) + ' nil t) (vikix-office-open ' + display + '))'
    if shutil.which('emacsclient'):
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
    elif not args:
        launch(api)
    else:
        raise ValueError('vikix agents office [--json | --go PID | --close-agent PID START | --forget ID | --purge-archive TOKEN]')
    return 0
