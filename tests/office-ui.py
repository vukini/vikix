"""Office projection and action tests, with no real desktop or sessions."""
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
import office
import handoff as H

spec = importlib.util.spec_from_loader('office_agents', SourceFileLoader('office_agents', str(ROOT / 'bin/vikix-agents')))
A = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = A
spec.loader.exec_module(A)


class Office(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = str(Path(self.temp.name) / 'desk with spaces')
        Path(self.folder).mkdir()
        self.rec = {'desk': {'worktree': self.folder, 'id': 'abc', 'project': 'Vikix'},
                    'task': {'text': 'Fix the picker'}, 'handoff': {}, 'checks': [], 'sessions': []}
        self.records, self.agents, self.desks = [], [], []
        for name, replacement in {
            'handoff_module': lambda: H,
            'desktop': lambda **kw: self.agents,
            'elsewhere': lambda known, **kw: [], 'seated': lambda agents: agents,
            'waits': lambda agents: {}, 'default_agent': lambda: 'codex',
            'projects': lambda: None, 'desks': lambda vp: self.desks,
        }.items():
            p = patch.object(A, name, replacement)
            p.start(); self.addCleanup(p.stop)
        p = patch.object(H, 'all_records', lambda **kw: self.records)
        p.start(); self.addCleanup(p.stop)

    def agent(self, pid=1, state='working', window='2'):
        return {'folder': self.folder, 'pid': pid, 'agent': 'codex', 'state': state,
                'doing': state, 'window': window, 'workspace': '4'}

    def test_empty_and_incomplete(self):
        self.assertEqual(office.snapshot(A)['desks'], [])
        self.agents = [self.agent()]
        row = office.snapshot(A)['desks'][0]
        self.assertEqual(row['group'], 'Working')
        self.assertEqual(row['status'], 'unrecorded')
        self.assertIn('desk with spaces', row['title'])
        self.records = [{'desk': {}}, {'desk': {'worktree': self.folder}}]
        self.assertEqual(len(office.snapshot(A)['desks']), 1)

    def test_estimate_counted_down(self):
        # The agent's estimate, counted down from when it was written; '' without one.
        self.records = [self.rec]
        self.assertEqual(office.snapshot(A)['desks'][0]['estimate'], '')
        self.rec['handoff'] = {'status': {'value': 'working', 'at': int(time.time()) - 600},
                               'estimate': {'text': '40 min', 'minutes': 40, 'by': 'codex 1', 'at': int(time.time()) - 600}}
        self.assertEqual(office.snapshot(A)['desks'][0]['estimate'], '30 min left of 40 min')

    def test_groups_and_multiple_agents(self):
        self.records = [self.rec]
        self.assertEqual(office.snapshot(A)['desks'][0]['group'], 'Parked')
        self.agents = [self.agent(), self.agent(2, 'asks', '')]
        row = office.snapshot(A)['desks'][0]
        self.assertEqual(row['group'], 'Needs you')
        self.assertEqual(len(row['agents']), 2)
        self.assertEqual(row['title'], 'Fix the picker')
        self.agents = []
        self.rec['handoff'] = {'status': {'value': 'review'}}
        self.assertEqual(office.snapshot(A)['desks'][0]['group'], 'Needs you')
        self.rec['handoff']['status']['value'] = 'finished'
        self.assertEqual(office.snapshot(A)['desks'][0]['group'], 'Finished')
        Path(self.folder).rmdir()
        result = office.snapshot(A)
        self.assertEqual(result['desks'], [])
        self.assertEqual(result['archive'][0]['group'], 'Archived')
        self.assertEqual(result['archive'][0]['resume'], {})

    def test_removed_review_record_is_archived_but_live_agent_is_not(self):
        self.records = [self.rec]
        self.rec['handoff'] = {'status': {'value': 'review'}}
        Path(self.folder).rmdir()
        result = office.snapshot(A)
        self.assertEqual(result['desks'], [])
        self.assertTrue(result['archive'][0]['archived'])
        self.agents = [self.agent()]
        self.assertEqual(office.snapshot(A)['archive'], [])
        self.assertEqual(len(office.snapshot(A)['desks']), 1)
        self.agents[0]['folder'] += ' (deleted)'
        self.assertEqual(office.snapshot(A)['archive'], [])
        self.assertEqual(len(office.snapshot(A)['desks']), 1)
        self.agents = []
        with patch.object(A, 'desktop', side_effect=RuntimeError('offline')):
            self.assertEqual(office.snapshot(A)['archive'], [])

    def test_archive_reopened_and_unreadable_folders(self):
        self.records = [self.rec]
        Path(self.folder).rmdir()
        self.assertEqual(len(office.snapshot(A)['archive']), 1)
        Path(self.folder).mkdir()
        self.assertEqual(office.snapshot(A)['archive'], [])
        with patch.object(office.os, 'lstat', side_effect=PermissionError):
            self.assertFalse(office.missing_folder(self.folder))

    def test_plain_folder_is_not_a_desk(self):
        # An agent started in ~ makes a row for its folder: a folder, not a desk.
        self.agents = [self.agent()]
        row = office.snapshot(A)['desks'][0]
        self.assertEqual(row['kind'], 'folder')
        self.assertEqual(row['title'], office.short(self.folder))
        self.assertEqual(row['group'], 'Working')
        self.assertEqual(row['next_action'], 'Go to agent')
        self.assertEqual(row['resume'], {})
        self.assertEqual(row['now'], {})
        self.assertEqual(office.short(os.path.expanduser('~/x y')), '~/x y')
        # The same folder listed as a project's desk, or a worktree desks() missed: a desk.
        self.desks = [{'folder': self.folder, 'branch': 'topic', 'top': '/tmp/book'}]
        row = office.snapshot(A)['desks'][0]
        self.assertEqual((row['kind'], row['title']), ('desk', 'book / topic'))
        self.assertIn('codex', row['resume'])
        self.desks = []
        with patch.object(A, 'desk_of', return_value=self.folder):
            self.assertEqual(office.snapshot(A)['desks'][0]['kind'], 'desk')
        # A record makes it a desk too, and the row keeps its identity.
        self.records = [self.rec]
        row = office.snapshot(A)['desks'][0]
        self.assertEqual((row['kind'], row['title']), ('desk', 'Fix the picker'))

    def test_first_handoff_keeps_selection_identity(self):
        self.agents = [self.agent()]
        before = office.snapshot(A)['desks'][0]['id']
        self.records = [self.rec]
        self.assertEqual(before, office.snapshot(A)['desks'][0]['id'])

    def test_process_discovery_failure_is_unknown(self):
        with patch.object(A, 'elsewhere', side_effect=RuntimeError('process discovery failed')):
            result = office.snapshot(A)
        self.assertFalse(result['live_known'])
        self.assertIn('process discovery failed', result['errors'][0])

    def test_unknown_is_not_stopped(self):
        self.records = [self.rec]
        with patch.object(A, 'desktop', side_effect=RuntimeError('delayed desktop')):
            result = office.snapshot(A)
        self.assertFalse(result['live_known'])
        self.assertEqual(result['desks'][0]['group'], 'Needs you')
        self.assertIn('delayed desktop', result['errors'][0])

    def test_stale_checks_and_session_availability(self):
        self.records = [self.rec]
        self.rec['checks'] = [{'name': 'tests', 'commit': 'old', 'dirty': 0, 'ok': True}]
        self.rec['sessions'] = [{'provider': 'codex', 'id': 'abcd'}]
        with patch.object(H, 'observe', return_value={'commit': 'new', 'dirty': 0}), \
             patch.object(H, 'session_store', return_value=(False, 'missing')):
            row = office.snapshot(A)['desks'][0]
        self.assertTrue(row['checks'][0]['freshness'].startswith('stale'))
        self.assertFalse(row['sessions'][0]['available'])
        self.assertEqual(row['resume']['codex']['mode'], 'fresh')

    def test_unreadable_working_tree_is_not_fresh(self):
        self.assertTrue(H.freshness({'commit': 'same', 'dirty': 0},
                                   {'commit': 'same', 'dirty': None}).startswith('unknown'))

    def test_untracked_content_changes_make_checks_stale(self):
        def git(*args):
            subprocess.run(['git', '-C', self.folder, *args], check=True, capture_output=True)
        git('init')
        git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-m', 'fixture')
        path = Path(self.folder) / 'new file.py'
        path.write_text('first')
        before = H.observe(self.folder)
        self.assertEqual(H.freshness(before, H.observe(self.folder)), 'fresh')
        path.write_text('other')
        self.assertTrue(H.freshness(before, H.observe(self.folder)).startswith('stale'))

    def test_focus_only_integer_and_failure(self):
        with patch.object(office.subprocess, 'run') as run:
            with self.assertRaises(ValueError): office.focus(A, '1) (quit)')
            run.assert_not_called()
            run.return_value.returncode = 0
            run.return_value.stdout = ''
            run.return_value.stderr = ''
            office.focus(A, '123')
            self.assertIn('(find 123 (vikix-agents)', run.call_args.args[0][1])
            self.assertNotIn('shell', run.call_args.kwargs)
            run.return_value.returncode = 1
            run.return_value.stderr = 'no desktop window'
            with self.assertRaisesRegex(RuntimeError, 'no desktop window'): office.focus(A, '123')

    def test_close_refuses_stale_or_non_agent_process(self):
        with patch.object(office.os, 'pidfd_open', return_value=42), \
             patch.object(office.os, 'close') as close, \
             patch.object(office, 'process_start', return_value='new'), \
             patch.object(office.signal, 'pidfd_send_signal') as send:
            with self.assertRaises(ValueError): office.close_agent(A, '1;bad', '100')
            with self.assertRaisesRegex(RuntimeError, 'ended or changed'):
                office.close_agent(A, '123', '100')
            send.assert_not_called()
            close.assert_called_once_with(42)
        with patch.object(office.os, 'pidfd_open', return_value=42), \
             patch.object(office.os, 'close'), \
             patch.object(office, 'process_start', return_value='100'), \
             patch.object(A, 'cmdline', return_value=['/bin/bash']), \
             patch.object(office.signal, 'pidfd_send_signal') as send:
            with self.assertRaisesRegex(RuntimeError, 'ended or changed'):
                office.close_agent(A, '123', '100')
            send.assert_not_called()

    def test_close_owned_process_and_keep_files(self):
        # An owned stand-in exercises real pidfd delivery, never a live agent.
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
        try:
            start = office.process_start(A, child.pid)
            with patch.object(A, 'agent_name', return_value='codex'):
                office.main(A, ['--close-agent', str(child.pid), start])
            self.assertEqual(child.wait(timeout=5), -15)
            self.assertTrue(Path(self.folder).is_dir())
        finally:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=5)

    def test_close_reports_still_exiting_without_force(self):
        with patch.object(office.os, 'pidfd_open', return_value=42), \
             patch.object(office.os, 'close'), \
             patch.object(office, 'process_start', return_value='100'), \
             patch.object(A, 'cmdline', return_value=['codex']), \
             patch.object(office.signal, 'pidfd_send_signal') as send, \
             patch.object(office.select, 'poll') as poll, patch('builtins.print') as output:
            poll.return_value.poll.return_value = []
            office.close_agent(A, '123', '100')
            send.assert_called_once_with(42, office.signal.SIGTERM)
            self.assertIn('still exiting', output.call_args.args[0])

    def test_changed_conversation_is_not_resumed(self):
        with patch.object(A, 'desk_for', return_value=(self.folder, self.rec)), \
             patch.object(A, 'protection_lines', return_value=([], [])), \
             patch.object(A, 'die', side_effect=ValueError), \
             patch.object(H, 'render', return_value='handoff'), \
             patch.object(H, 'resume_plan', return_value={'mode': 'resumed', 'session': {'id': 'changed'}}), \
             patch.object(A, 'open_at') as start:
            with self.assertRaises(ValueError):
                A.resume([self.folder, '--use', 'codex', '--expect-session', 'chosen'])
            start.assert_not_called()

    def test_resume_guard_and_path_with_spaces(self):
        with patch.object(A, 'desk_for', return_value=(self.folder, self.rec)) as resolve, \
             patch.object(A, 'protection_lines', return_value=([], [])), \
             patch.object(A, 'die', side_effect=ValueError), \
             patch.object(H, 'render', return_value='handoff'), \
             patch.object(H, 'resume_plan', return_value={'mode': 'fresh', 'why': 'gone'}), \
             patch.object(A, 'open_at') as start:
            with self.assertRaises(ValueError):
                A.resume([self.folder, '--use', 'codex', '--require-saved'])
            resolve.assert_called_once_with([self.folder])
            start.assert_not_called()
        with patch.object(A, 'desk_for', return_value=(self.folder, None)), \
             patch.object(A, 'protection_lines', return_value=([self.agent()], [])), \
             patch.object(A, 'die', side_effect=ValueError), patch.object(A, 'open_at') as start:
            with self.assertRaises(ValueError): A.resume([self.folder, '--fresh'])
            start.assert_not_called()


class ArchivePurge(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name) / 'removed desk'
        self.folder.mkdir()
        self.records_dir = Path(self.temp.name) / 'records'
        for name, value in {'DESKS': str(self.records_dir)}.items():
            p = patch.object(H, name, value)
            p.start(); self.addCleanup(p.stop)
        for name, value in {
            'handoff_module': lambda: H, 'desktop': lambda **kw: [],
            'elsewhere': lambda known, **kw: [], 'seated': lambda a: a,
            'waits': lambda a: {}, 'default_agent': lambda: 'codex',
            'projects': lambda: [], 'desks': lambda p: [],
        }.items():
            p = patch.object(A, name, value)
            p.start(); self.addCleanup(p.stop)
        self.rec = H.update('', str(self.folder), lambda r: H.set_task(r, 'Old task', 'user'))
        self.path = Path(H.record_path(self.rec['desk']['id']))
        self.folder.rmdir()
        self.token = office.snapshot(A)['archive_token']

    def test_purge_only_archived_records(self):
        active = Path(self.temp.name) / 'active'
        active.mkdir()
        keep = H.update('', str(active), lambda r: H.set_task(r, 'Keep me', 'user'))
        office.main(A, ['--purge-archive', self.token])
        self.assertFalse(self.path.exists())
        self.assertTrue(Path(H.record_path(keep['desk']['id'])).exists())
        self.assertTrue(active.is_dir())
        self.assertEqual(office.snapshot(A)['archive'], [])

    def test_forget_one_record_by_id_only(self):
        with self.assertRaises(ValueError): office.main(A, ['--forget', '../etc/passwd'])
        with self.assertRaisesRegex(RuntimeError, 'No such record'): office.forget_record(A, '0123456789ab')
        keep = H.update('', str(Path(self.temp.name) / 'other gone'), lambda r: H.set_task(r, 'Keep me', 'user'))
        office.main(A, ['--forget', self.rec['desk']['id']])
        self.assertFalse(self.path.exists())
        self.assertTrue(Path(str(self.path) + '.lock').exists())
        self.assertTrue(Path(H.record_path(keep['desk']['id'])).exists())
        self.assertEqual(office.snapshot(A)['archive'][0]['desk']['id'], keep['desk']['id'])

    def test_forget_refuses_standing_desk_and_agent_in_it(self):
        did = self.rec['desk']['id']
        self.folder.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'is there: a desk that stands is closed'):
            office.forget_record(A, did)
        self.folder.rmdir()
        gone = [{'agent': 'codex', 'pid': 7, 'folder': str(self.folder) + ' (deleted)'}]
        with patch.object(A, 'live_agents', return_value=gone):
            with self.assertRaisesRegex(RuntimeError, 'codex 7 still at work'):
                office.forget_record(A, did)
        self.assertTrue(self.path.exists())

    def test_changed_record_requires_new_confirmation(self):
        H.update('', str(self.folder), lambda r: H.set_task(r, 'Changed task', 'user'))
        with self.assertRaisesRegex(RuntimeError, 'Archive changed'):
            office.purge_archive(A, self.token)
        self.assertTrue(self.path.exists())

    def test_reopened_desk_and_unknown_discovery_are_not_purged(self):
        self.folder.mkdir()
        with self.assertRaises(RuntimeError): office.purge_archive(A, self.token)
        self.folder.rmdir()
        with patch.object(A, 'desktop', side_effect=RuntimeError('offline')):
            with self.assertRaises(RuntimeError): office.purge_archive(A, self.token)
        self.assertTrue(self.path.exists())

    def test_concurrent_update_and_recheck(self):
        import fcntl
        with open(str(self.path) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with self.assertRaisesRegex(RuntimeError, 'being updated'):
                office.purge_archive(A, self.token)
        before = office.snapshot(A)
        after = dict(before, archive_token='changed')
        with patch.object(office, 'snapshot', side_effect=[before, after]):
            with self.assertRaisesRegex(RuntimeError, 'changed'):
                office.purge_archive(A, self.token)
        self.assertTrue(self.path.exists())


class Launcher(unittest.TestCase):
    """No connection attempt reaches a real server or saved desktop."""
    def setUp(self):
        self.client = patch.object(office.shutil, 'which', return_value='/test/emacsclient')
        self.run = patch.object(office.subprocess, 'run')
        self.spawn = patch.object(office.subprocess, 'Popen')
        self.client.start()
        self.called = self.run.start()
        self.spawned = self.spawn.start()
        self.addCleanup(self.client.stop)
        self.addCleanup(self.run.stop)
        self.addCleanup(self.spawn.stop)

    def tearDown(self):
        self.spawned.assert_not_called()

    def test_uses_existing_server_even_with_alternate_editor_configured(self):
        self.called.return_value = subprocess.CompletedProcess([], 0, 'nil', '')
        with patch.dict(os.environ, {'ALTERNATE_EDITOR': 'emacs', 'DISPLAY': ':91'}), \
             patch.object(A, 'VIKIX_DIR', '/tmp/Office desk "quoted"'):
            office.launch(A)
        self.called.assert_called_once()
        args = self.called.call_args.args[0]
        self.assertEqual(args[:3], ['emacsclient', '--alternate-editor=false', '--eval'])
        quoted = json.dumps('/tmp/Office desk "quoted"/config/emacs/vikix-office.el')
        self.assertEqual(args[3], '(progn (load ' + quoted + ' nil t) (vikix-office-open \":91\"))')
        self.assertNotIn('-nw', args)
        self.assertNotIn('shell', self.called.call_args.kwargs)

    def test_open_already_asks_the_desktop_to_go_to_its_window(self):
        # vikix-office-open answers the existing frame's X window id: the
        # desktop is asked to show that window, by its number alone.
        self.called.return_value = subprocess.CompletedProcess([], 0, '"62914563"\n', '')
        with patch.dict(os.environ, {'DISPLAY': ':91'}):
            office.launch(A)
        self.assertEqual(self.called.call_count, 2)
        args = self.called.call_args.args[0]
        self.assertEqual(args, [A.EVAL, '(vikix-show-window-id 62914563)'])
        self.assertNotIn('shell', self.called.call_args.kwargs)

    def test_a_frame_made_now_asks_nothing_of_the_desktop(self):
        # nil: the frame is new and takes the focus as it opens.
        for answer in ('nil\n', '', '"7) (quit)"\n', '"-3"\n', '""\n'):
            self.called.reset_mock()
            self.called.return_value = subprocess.CompletedProcess([], 0, answer, '')
            with patch.dict(os.environ, {'DISPLAY': ':91'}):
                office.launch(A)
            self.assertEqual(self.called.call_count, 1, answer)

    def test_a_desktop_that_does_not_answer_costs_nothing(self):
        self.called.side_effect = [subprocess.CompletedProcess([], 0, '"62914563"\n', ''),
                                   subprocess.CompletedProcess([], 1, '', 'error: no window')]
        with patch.dict(os.environ, {'DISPLAY': ':91'}):
            office.launch(A)
        self.assertEqual(self.called.call_count, 2)

    def test_no_display_opens_in_this_terminal(self):
        # A headless server or SSH: -nw in the foreground, the Office in the
        # selected frame as the frame's own, no timeout on the session.
        self.called.return_value = subprocess.CompletedProcess([], 0, '', '')
        env = {k: v for k, v in os.environ.items() if k != 'DISPLAY'}
        with patch.dict(os.environ, env, clear=True), patch.object(A, 'VIKIX_DIR', '/tmp/Office desk "quoted"'):
            office.launch(A)
        self.called.assert_called_once()
        args = self.called.call_args.args[0]
        self.assertEqual(args[:4], ['emacsclient', '--alternate-editor=false', '-nw', '--eval'])
        quoted = json.dumps('/tmp/Office desk "quoted"/config/emacs/vikix-office.el')
        self.assertEqual(args[4], '(progn (load ' + quoted + ' nil t) (vikix-office-open-here t))')
        kwargs = self.called.call_args.kwargs
        self.assertNotIn('timeout', kwargs)
        self.assertNotIn('capture_output', kwargs)   # the terminal is the Office's
        self.assertNotIn('stdout', kwargs)
        self.assertNotIn('stdin', kwargs)

    def test_tty_forces_the_terminal_with_a_display(self):
        self.called.return_value = subprocess.CompletedProcess([], 0, '', '')
        with patch.dict(os.environ, {'DISPLAY': ':91'}):
            office.main(A, ['--tty'])
        args = self.called.call_args.args[0]
        self.assertIn('-nw', args)
        self.assertIn('(vikix-office-open-here t)', args[-1])
        with self.assertRaises(ValueError):
            office.main(A, ['--tty', 'more'])

    def test_terminal_without_a_server_is_the_same_honest_message(self):
        self.called.return_value = subprocess.CompletedProcess([], 1, '', 'emacsclient: no socket')
        env = {k: v for k, v in os.environ.items() if k != 'DISPLAY'}
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'could not open in the existing Emacs.*no socket'):
                office.launch(A)
        self.called.assert_called_once()
        self.assertEqual(self.called.call_args.args[0][1], '--alternate-editor=false')

    def test_failed_connection_or_lisp_error_is_reported(self):
        for code, stdout, stderr, expected in ((1, '', 'no server', 'no server'),
                                              (1, 'Lisp error', '', 'Lisp error'),
                                              (1, '', '', 'emacsclient failed')):
            with self.subTest(expected=expected), patch.dict(os.environ, {'DISPLAY': ':91'}):
                self.called.reset_mock()
                self.called.return_value = subprocess.CompletedProcess([], code, stdout, stderr)
                with self.assertRaisesRegex(RuntimeError, expected):
                    office.launch(A)
                self.called.assert_called_once()

    def test_timeout_does_not_start_another_emacs(self):
        self.called.side_effect = subprocess.TimeoutExpired('emacsclient', 8)
        with patch.dict(os.environ, {'DISPLAY': ':91'}), \
             self.assertRaisesRegex(RuntimeError, 'did not answer within 8 seconds'):
            office.launch(A)
        self.called.assert_called_once()

    def test_client_execution_error_does_not_start_another_emacs(self):
        self.called.side_effect = OSError('cannot execute client')
        with self.assertRaisesRegex(RuntimeError, 'cannot execute client'):
            office.launch(A)
        self.called.assert_called_once()

    def test_missing_client_is_reported_when_emacs_is_installed(self):
        with patch.object(office.shutil, 'which', side_effect=lambda name: '/test/emacs' if name == 'emacs' else None):
            with self.assertRaisesRegex(RuntimeError, 'emacsclient is not available'):
                office.launch(A)
        self.called.assert_not_called()

    def test_without_emacs_the_existing_agent_menu_remains(self):
        with patch.object(office.shutil, 'which', return_value=None):
            office.launch(A)
        self.called.assert_called_once()
        args = self.called.call_args.args[0]
        self.assertEqual(args[0], A.EVAL)
        self.assertIn('(run-with-timer 0 nil', args[1])
        self.assertIn('(run-commands "vikix-agents-pick")', args[1])


if __name__ == '__main__':
    unittest.main()
