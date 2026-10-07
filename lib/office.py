"""The Office: a read-only projection of desks, handoffs and live discovery.

No state is written here. Terminal clients and the Emacs view share this
snapshot; unavailable discovery is explicitly different from an empty office.
"""
import json
import os
import shutil
import subprocess
import time


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
        if a.get('folder'):
            path = os.path.realpath(a['folder'])
            rows.setdefault(path, {'desk': {'worktree': path}})
    held = api.waits(agents) if live_known else {}
    for a in agents:
        if a['pid'] in held and a.get('state') in ('working', 'running', 'idle'):
            a['doing'], a['waits'] = held[a['pid']]
    default = api.default_agent()
    for path, row in rows.items():
        d = row['desk']
        # The path stays stable when an active desk gets its first handoff.
        row['id'] = path
        row['exists'] = os.path.isdir(path)
        row['agents'] = [a for a in agents if os.path.realpath(a.get('folder') or '/') == path]
        row['live_known'] = live_known
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
    order = ['Needs you', 'Working', 'Parked', 'Finished']
    return {'version': 1, 'at': int(time.time()), 'live_known': live_known, 'errors': errors,
            'desks': sorted(rows.values(), key=lambda r: (order.index(r['group']), r['title'].lower(), r['id']))}


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
    form = '(progn (load ' + json.dumps(source, ensure_ascii=False) + ' nil t) (vikix-office-open))'
    if shutil.which('emacsclient'):
        try:
            result = subprocess.run(['emacsclient', '--eval', form], capture_output=True, text=True, timeout=8)
            if result.returncode == 0:
                return
        except (OSError, subprocess.TimeoutExpired):
            pass
    if shutil.which('emacs'):
        subprocess.Popen(['emacs', '--load', source, '--funcall', 'vikix-office-open'], start_new_session=True)
        return
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
    elif not args:
        launch(api)
    else:
        raise ValueError('vikix agents office [--json | --go PID]')
    return 0
