"""Decisions and attention, in a temporary office; invoked by tasks.sh."""
import concurrent.futures
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests/lib'))
import own_home
own_home.claim()   # never the real office: run by hand, these once wrote fixture tasks into it
sys.path.insert(0, str(ROOT / 'lib'))
import tasks as T
import office
import handoff as H


class Decisions(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        for mod, key, value in ((T, 'OFFICE', self.temp.name), (T, 'TASKS', self.temp.name + '/tasks'),
                                (H, 'EVENTS_DIR', self.temp.name)):
            p = patch.object(mod, key, value); p.start(); self.addCleanup(p.stop)
        self.task = T.new('Test the picker', 'book', 'user', desk={'id': 'abc', 'worktree': '/test/desk', 'branch': 'test'})
        self.tid = self.task['id']
        T.move(self.tid, 'running', 'user')

    def ask(self, **kw):
        return T.ask(self.tid, 'Keep it?', 'codex 42', **kw)

    def test_blocking_answers_and_inbox_once(self):
        a = self.ask(blocks=True, choices=[{'label': 'keep', 'consequence': 'one more test'}], recommended='keep')
        b = self.ask(blocks=True)
        self.assertEqual(T.load(self.tid)['status']['value'], 'needs decision')
        T.handoff_move(self.tid, 'working', 'codex 42')
        self.assertEqual(T.load(self.tid)['status']['value'], 'needs decision')
        T.answer(a['id'], 'keep')
        self.assertEqual(T.load(self.tid)['status']['value'], 'needs decision')
        T.answer(b['id'], 'Other words')
        self.assertEqual(T.load(self.tid)['status']['value'], 'running')
        self.assertEqual(len(T.decision_notes('abc')), 2)
        self.assertEqual(T.decision_notes('other', take=True), [])
        self.assertEqual(len(T.decision_notes('abc', take=True)), 2)
        self.assertEqual(T.decision_notes('abc', take=True), [])
        self.assertEqual(T.answer(a['id'], 'keep')['answer']['text'], 'keep')
        self.assertEqual(T.decision_notes('abc'), [])
        with self.assertRaises(T.TaskError): T.answer(a['id'], 'drop')
        self.assertTrue(T.decision(a['id'])['answer']['delivered'])

    def test_nonblocking_and_worker_exit(self):
        a = self.ask()
        self.assertEqual(T.load(self.tid)['status']['value'], 'running')
        T.move(self.tid, 'blocked', 'vikix', blocked_on='worker')
        T.answer(a['id'], 'yes')
        self.assertEqual(T.load(self.tid)['status']['value'], 'blocked')

    def test_question_after_worker_exit_does_not_restart_it(self):
        T.move(self.tid, 'blocked', 'vikix', blocked_on='worker')
        d = self.ask(blocks=True)
        self.assertEqual(T.load(self.tid)['status']['value'], 'blocked')
        T.answer(d['id'], 'yes')
        self.assertEqual(T.load(self.tid)['status']['value'], 'blocked')

    def test_review_answers_and_stale_reviews(self):
        from types import SimpleNamespace
        T.move(self.tid, 'needs review', 'codex 42')
        rec = {'task': {'id': self.tid}, 'desk': {}, 'checks': [{'ok': True}]}
        api = SimpleNamespace(by_me=lambda: ('user', None), desk_for=lambda _: ('/test/desk', rec),
                              tasks_module=lambda: T, handoff_module=lambda: SimpleNamespace(
                                  observe=lambda _: {}, freshness=lambda *_: 'stale: changed'))
        with self.assertRaisesRegex(ValueError, 'current code'):
            office.review_action(api, '/test/desk', True)
        self.assertEqual(T.load(self.tid)['status']['value'], 'needs review')
        d = self.ask(blocks=True)
        self.assertEqual(T.load(self.tid)['status']['value'], 'needs decision')
        T.answer(d['id'], 'yes')
        self.assertEqual(T.load(self.tid)['status']['value'], 'running')

    def test_release_passes_words_as_arguments(self):
        from types import SimpleNamespace
        from unittest.mock import Mock
        folder = Path(self.temp.name, 'desk with spaces'); (folder / '.claude').mkdir(parents=True)
        (folder / '.claude' / 'release').write_text('# stand-in')
        api = SimpleNamespace(by_me=lambda: ('user', None),
                              desk_for=lambda _: (str(folder), {'desk': {'branch': 'topic'}}),
                              tasks_module=lambda: T, open_terminal=Mock(), release_conflicts=lambda _: ('main', []))
        office.release_action(api, str(folder), 'literal $(touch bad); words')
        where, argv = api.open_terminal.call_args.args
        self.assertEqual(where, str(folder))
        self.assertEqual(argv[-2:], ['topic', 'literal $(touch bad); words'])
        self.assertFalse(Path(self.temp.name, 'bad').exists())
        api.by_me = lambda: ('codex 42', {'pid': 42})
        with self.assertRaises(ValueError): office.release_action(api, str(folder), 'summary')
        self.assertEqual(api.open_terminal.call_count, 1)
        # A branch that changed the same lines as main is refused before any
        # terminal opens, with the script's own words; git unable to say is no refusal.
        api.by_me = lambda: ('user', None)
        api.release_conflicts = lambda _: ('main', ['lib/man.py'])
        with self.assertRaisesRegex(ValueError, r'topic and main changed the same lines \(lib/man.py\): in .* run git rebase main'):
            office.release_action(api, str(folder), 'summary')
        self.assertEqual(api.open_terminal.call_count, 1)
        api.release_conflicts = lambda _: None
        office.release_action(api, str(folder), 'summary')
        self.assertEqual(api.open_terminal.call_count, 2)

    def test_validation_and_user_only(self):
        for kw in ({'recommended': 'missing'}, {'choices': [{'label': 'a'}, {'label': 'a'}]},
                   {'choices': [{'label': 'x', 'surprise': True}]}, {'blocks': 'false'},
                   {'context': 'sk-ant-api03-' + 'X' * 90}):
            with self.assertRaises(T.TaskError): self.ask(**kw)
        a = self.ask()
        with self.assertRaises(T.TaskError): T.answer(a['id'], 'yes', 'codex 42')
        with self.assertRaises(T.TaskError): T.decision('../bad')
        self.assertEqual(len(T.decisions(self.tid)), 1)

    def test_concurrent_limit_and_answers(self):
        def ask(_):
            try: return self.ask()
            except T.TaskError: return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=15) as pool:
            rows = list(pool.map(ask, range(20)))
        self.assertEqual(len([d for d in rows if d]), 10)
        did = next(d for d in rows if d)['id']
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
            list(pool.map(lambda _: T.answer(did, 'yes'), range(10)))
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
            deliveries = list(pool.map(lambda _: T.decision_notes('abc', take=True), range(10)))
        self.assertEqual(sum(len(notes) for notes in deliveries), 1)
        self.assertEqual(T.decision_notes('abc', take=True), [])

    def test_attention_order_freshness_and_uncertainty(self):
        d = self.ask()
        t = T.load(self.tid)
        t['questions'] = [d]
        t['activity'] = 1
        row = {'id': '/test/desk', 'task_record': t, 'worker_state': {'sure': 'unknown'}, 'agents': [],
               'checks': [{'name': 'tests/run.sh keys', 'ok': False, 'freshness': 'fresh', 'at': 20}]}
        snap = {'tasks': [t], 'desks': [row], 'live_known': True}
        kinds = [i['kind'] for i in office.attention(snap, now=5000)]
        self.assertEqual(kinds, ['decision', 'tests failed', 'uncertain'])
        row['checks'][0]['freshness'] = 'stale: code moved'
        self.assertNotIn('tests failed', [i['kind'] for i in office.attention(snap, now=5000)])
        row['worker_state']['sure'] = 'reliable'
        self.assertNotIn('uncertain', [i['kind'] for i in office.attention(snap, now=5000)])
        snap['live_known'] = False
        self.assertIn('discovery unavailable', [i['kind'] for i in office.attention(snap)])

    def test_release_under_way_asks_nothing(self):
        """A task ready for release has a Release item until the release is
        started, in the Office or by the agent: under way, the item goes and
        the board's row says the step; released and not pushed, gup is yours."""
        t = T.load(self.tid)
        t['status'] = {'value': 'ready for release', 'by': 'user', 'at': 10}
        row = {'id': '/test/desk', 'task_record': t, 'agents': [], 'release': ''}
        snap = {'tasks': [t], 'desks': [row], 'live_known': True}
        self.assertEqual([(i['kind'], i['actions']) for i in office.attention(snap, now=5000)], [('release', ['release', 'go'])])
        self.assertEqual(office.board_row(t, row, 5000, {})['state'], 'accepted, not yet released')
        row['release'] = 'step 4 of 7: testing (changed) · since 07:07'
        self.assertEqual([i['kind'] for i in office.attention(snap, now=5000)], [])
        self.assertEqual(office.board_row(t, row, 5000, {})['state'], 'under release: step 4 of 7: testing (changed) · since 07:07')
        row['attention'] = 'gup'
        self.assertEqual([(i['kind'], i['why'], i['actions']) for i in office.attention(snap, now=5000)],
                         [('release', 'run gup to push and update', ['go'])])
        # A branch main would conflict with (the row's conflicts, from merge-tree)
        # has no Release button: the item and the row say to rebase at the desk first.
        row['attention'], row['release'] = '', ''
        row['conflicts'] = 'conflicts with main in lib/man.py'
        self.assertEqual([(i['kind'], i['why'], i['actions']) for i in office.attention(snap, now=5000)],
                         [('release', 'conflicts with main in lib/man.py: rebase at the desk first (git rebase there), then release', ['go'])])
        self.assertEqual(office.board_row(t, row, 5000, {})['state'], 'accepted, conflicts with main in lib/man.py: rebase at the desk first')
        row['attention'] = 'gup'
        self.assertEqual([i['why'] for i in office.attention(snap, now=5000)], ['run gup to push and update'])

    def test_mcp_register_read_and_no_answer_tool(self):
        from types import SimpleNamespace
        spec = importlib.util.spec_from_loader('decision_mcp', SourceFileLoader('decision_mcp', str(ROOT / 'bin/vikix-mcp')))
        m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        api = SimpleNamespace(tasks_module=lambda: T, desk_for=lambda _: ('/test/desk', {'task': {'id': self.tid}}),
                              by_me=lambda: ('codex 42', {'folder': '/test/desk'}), attention_notify_decision=lambda _: None)
        with patch.object(m, 'office', return_value=api):
            d = json.loads(m.t_decide({'question': 'Keep it?', 'blocks': True}))
            self.assertEqual(json.loads(m.t_decision({'id': d['id']}))['question'], 'Keep it?')
            T.answer(d['id'], 'yes')
            self.assertEqual(json.loads(m.t_decision({'id': d['id']}))['answer']['text'], 'yes')
            with self.assertRaises(m.ToolError): m.t_decision({'id': '../bad'})
        names = [tool[0] for tool in m.TOOLS]
        self.assertIn('decide', names)
        self.assertIn('decision', names)
        self.assertNotIn('answer', names)
        self.assertFalse(next(t for t in m.TOOLS if t[0] == 'decide')[4]['readOnlyHint'])
        self.assertTrue(next(t for t in m.TOOLS if t[0] == 'decision')[4]['readOnlyHint'])

    def test_answer_retries_after_task_write_failed(self):
        d = self.ask(blocks=True)
        with patch.object(T, 'update', side_effect=OSError('disk temporarily unavailable')):
            with self.assertRaises(OSError): T.answer(d['id'], 'yes')
        self.assertEqual(T.decision(d['id'])['answer']['text'], 'yes')
        T.answer(d['id'], 'yes')
        self.assertEqual(T.load(self.tid)['status']['value'], 'running')
        self.assertEqual(len(T.decision_notes('abc', take=True)), 1)

    def test_answered_provider_question_stays_resolved_until_new_note(self):
        d = self.ask()
        T.answer(d['id'], 'yes')
        d = T.decision(d['id'])
        task = T.load(self.tid); task['questions'] = [d]
        a = {'pid': 42, 'agent': 'claude', 'state': 'done', 'note_kind': 'reply',
             'said': 'Keep it?', 'attention_since': d['at']}
        snap = {'live_known': True, 'tasks': [task], 'desks': [{'id': '/desk', 'task_record': task, 'agents': [a]}]}
        self.assertNotIn('question', [i['kind'] for i in office.attention(snap)])
        a['attention_since'] = d['answer']['at'] + 1
        self.assertIn('question', [i['kind'] for i in office.attention(snap)])

    def test_sessions_without_tasks_still_show_permissions(self):
        snap = {'live_known': True, 'tasks': [], 'desks': [
            {'id': '/home/test', 'title': 'Session', 'agents': [{'pid': 42, 'agent': 'codex', 'state': 'asks'}]}]}
        rows = office.attention(snap)
        self.assertEqual(rows[0]['kind'], 'permission')
        self.assertIsNone(rows[0]['task'])
        self.assertIsNone(rows[0]['since'])
        self.assertEqual(rows[0]['worker'], 'codex 42')

    def test_titles_count_changes_not_first_sightings(self):
        a = {'pid': 42, 'process_start': '100', 'title': 'Working on chapter one'}
        data = {'at': 100, 'live_known': True, 'desks': [{'agents': [a]}]}
        self.assertEqual(office.title_activity(a, {}, 100), 0)
        office.remember_titles(data, self.temp.name)
        first = office.title_observations(self.temp.name)
        self.assertEqual(office.title_activity(a, first, 200), 0)
        a['title'] = 'Working on chapter two'
        self.assertEqual(office.title_activity(a, first, 200), 200)
        data['at'] = 200
        office.remember_titles(data, self.temp.name)
        self.assertEqual(office.title_activity(a, office.title_observations(self.temp.name), 300), 200)
        self.assertNotIn('chapter', Path(self.temp.name, 'attention-titles.json').read_text())

    def test_notifications_once(self):
        rows = [{'id': 'one', 'kind': 'decision', 'why': 'Keep it?'}]
        with patch.dict(os.environ, DISPLAY=':test'), patch.object(office.shutil, 'which', return_value='/stub'), \
             patch.object(office.subprocess, 'run') as run:
            run.return_value.returncode = 0
            office.notify_attention(rows, self.temp.name)
            office.notify_attention(rows, self.temp.name)
            self.assertEqual(run.call_count, 1)


if __name__ == '__main__':
    unittest.main()
