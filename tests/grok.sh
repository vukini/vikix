#!/usr/bin/env bash
# tests/grok.sh — public vikix grok dispatch, concurrent claims, durable review,
# retries, invalid inputs, and no execution or fetching of returned content.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live Emacs
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's
here=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$here" <<'PY'
import concurrent.futures
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='vikix-grok-test-') as temp:
    work = Path(temp)
    store = work / 'queue'
    fakebin = work / 'bin'
    fakebin.mkdir()
    (fakebin / 'notify-send').write_text('#!/bin/sh\nexit 1\n')
    (fakebin / 'notify-send').chmod(0o700)
    env = {**os.environ, 'VIKIX_GROK_DIR': str(store),
           'PATH': str(fakebin) + ':' + os.environ['PATH'],
           'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent/grok-test-bus'}

    def run(*args, data=None, ok=True):
        p = subprocess.run(['bash', str(root / 'bin/vikix'), 'grok', *args],
                           input=data, text=True, capture_output=True, env=env, timeout=15)
        if ok is not None:
            assert (p.returncode == 0) == ok, (args, p.returncode, p.stdout, p.stderr)
        return p

    def new(title='Research', brief='Read the public release notes.'):
        return run('new', title, '--brief', '-', '--project', 'example', data=brief).stdout.strip()

    def task(task_id):
        return json.loads(run('show', task_id, '--json').stdout)

    assert json.loads(run('list', '--json').stdout) == []
    assert 'not probed' in run('status').stdout
    assert not store.exists(), 'read commands must not create a queue'
    assert 'vikix grok' in run('help').stdout
    assert 'LOCAL computer' in run('instructions').stdout

    first = new()
    assert task(first)['state'] == 'queued'
    assert stat.S_IMODE(store.stat().st_mode) == 0o700
    assert stat.S_IMODE((store / 'tasks.db').stat().st_mode) == 0o600
    prompt = run('prompt', first).stdout
    assert 'vikix grok claim ' + first in prompt
    assert 'vikix grok result ' + first in prompt
    assert 'Read the public release notes.' not in prompt, 'claim carries the selected brief'
    run('accept', first, ok=False)
    result = {'summary': 'Found two changes.', 'sources': ['https://example.com/notes'],
              'artifacts': [], 'questions': []}
    raw = json.dumps(result)
    run('result', first, '--file', '-', data=raw, ok=False)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(lambda _: run('claim', first, ok=None), range(2)))
    assert sorted(p.returncode for p in claims) == [0, 1], claims
    winner = json.loads(next(p.stdout for p in claims if p.returncode == 0))
    assert winner['brief'] == 'Read the public release notes.'
    assert task(first)['state'] == 'running'
    run('prompt', first, ok=False)

    bad_results = [[], {}, {'summary': 'missing fields'}, {**result, 'command': 'true'},
                   {**result, 'sources': ['file:///etc/passwd']},
                   {**result, 'artifacts': ['https://user:password@example.com/a']},
                   {**result, 'questions': 'not a list'},
                   {**result, 'summary': '\x1b]52;payload'},
                   {**result, 'sources': ['https://example.com/\nforged']},
                   {**result, 'summary': ''}]
    for bad in bad_results:
        run('result', first, '--file', '-', data=json.dumps(bad), ok=False)
        assert task(first)['state'] == 'running'
    run('result', first, '--file', '-', data='not JSON', ok=False)
    run('result', first, '--file', '-', data='x' * (1024 * 1024 + 1), ok=False)
    run('result', first, '--file', '-', data=raw)
    before = task(first)
    assert before['state'] == 'review'
    assert before['result'] == result
    run('result', first, '--file', '-', data=raw)
    assert task(first) == before, 'identical retries must not change history or timestamps'
    run('result', first, '--file', '-', data=json.dumps({**result, 'summary': 'Changed'}), ok=False)
    assert task(first) == before
    assert first in run('list', '--state', 'review').stdout
    run('accept', first)
    accepted = task(first)
    assert accepted['state'] == 'accepted'
    assert [s['state'] for s in accepted['history']] == ['queued', 'running', 'review', 'accepted']
    run('result', first, '--file', '-', data=raw)
    assert task(first) == accepted, 'a late identical retry must not reopen an accepted task'
    run('cancel', first, ok=False)
    run('claim', first, ok=False)

    failed = new('Blocked')
    run('claim', failed)
    run('fail', failed, 'Source is unavailable.')
    assert task(failed)['reason'] == 'Source is unavailable.'
    run('result', failed, '--file', '-', data=raw, ok=False)
    run('cancel', failed)
    assert task(failed)['reason'] == '', 'cancel clears a current failure reason'
    cancelled = new('Cancel before work')
    run('cancel', cancelled)
    run('claim', cancelled, ok=False)
    late = new('Cancel during work')
    run('claim', late)
    run('cancel', late)
    run('result', late, '--file', '-', data=raw, ok=False)

    marker = work / 'must-not-exist'
    malicious = f'$(touch {marker}) `touch {marker}`'
    inert = new(malicious, malicious)
    run('claim', inert)
    run('result', inert, '--file', '-', data=json.dumps({**result, 'summary': malicious}))
    run('show', inert)
    run('accept', inert)
    assert not marker.exists(), 'briefs and results must never be executed'
    assert task(inert)['result']['summary'] == malicious
    run('show', '../../outside', ok=False)
    run('show', 'g-' + '0' * 16, ok=False)
    run('new', 'bad\ntitle', '--brief', '-', data='brief', ok=False)
    run('new', 'Empty', '--brief', '-', data='', ok=False)
    source = work / 'brief.txt'
    source.write_text('A selected file only.')
    file_id = run('new', 'From file', '--brief', str(source)).stdout.strip()
    assert task(file_id)['brief'] == source.read_text()
    link = work / 'brief-link'
    link.symlink_to(source)
    run('new', 'From link', '--brief', str(link), ok=False)
    fifo = work / 'fifo'
    os.mkfifo(fifo)
    run('new', 'From FIFO', '--brief', str(fifo), ok=False)
    assert 'summary' not in json.loads(run('list', '--json').stdout)[0]

    # A redirected database must not be followed, even for read-only commands.
    elsewhere = work / 'elsewhere'
    elsewhere.mkdir()
    (elsewhere / 'tasks.db').symlink_to(store / 'tasks.db')
    env['VIKIX_GROK_DIR'] = str(elsewhere)
    run('list', ok=False)
    env['VIKIX_GROK_DIR'] = str(work / 'queue-link')
    (work / 'queue-link').symlink_to(store)
    run('list', ok=False)

print('grok: CLI handoff, atomic claims, review, retries, cancellation, bounded inputs and inert results passed')
PY
