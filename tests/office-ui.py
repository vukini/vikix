"""Office projection and action tests, with no real desktop or sessions."""
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
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
        self.assertFalse(office.snapshot(A)['desks'][0]['exists'])

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


if __name__ == '__main__':
    unittest.main()
