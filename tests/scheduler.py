"""Queue order, capacity, launch reservations and user controls in a made-up office."""
import concurrent.futures
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests/lib'))
import own_home
own_home.claim()   # never the real office: run by hand, these once wrote fixture tasks into it
sys.path.insert(0, str(ROOT / 'lib'))
import tasks as T
import handoff as H
import scheduler as S


class Scheduler(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        for mod, key, val in ((T, 'OFFICE', tmp.name), (T, 'TASKS', tmp.name + '/tasks'),
                              (T, 'SEQUENCE', tmp.name + '/sequence'), (H, 'EVENTS_DIR', tmp.name),
                              (H, 'DESKS', tmp.name + '/desks'), (S, 'T', T)):
            p = patch.object(mod, key, val); p.start(); self.addCleanup(p.stop)
        p = patch.dict(os.environ, XDG_CONFIG_HOME=tmp.name); p.start(); self.addCleanup(p.stop)
        self.api = SimpleNamespace(worker_at=self.worker, desk_for=lambda _: (str(self.base / 'desk'), {}))
        self.starts = []
        self.w = {'tasks': [], 'desks': [], 'releases': [], 'live_known': True,
                  'providers': ['codex'], 'default_provider': 'codex', 'config': {'at_once': 2, 'auto': False}, 'queue': S.queue()}

    def task(self, priority='normal', desk=None):
        if desk is None:
            folder = self.base / ('desk' + str(len(self.w['tasks'])))
            folder.mkdir()
            desk = {'worktree': str(folder), 'branch': folder.name, 'id': folder.name}
        t = T.new('Test queue ' + priority, 'test', 'user', priority=priority, desk=desk, topic='queued', worker={'use': 'codex'})
        self.w['tasks'].append(t)
        S.mutate('add', t['id'])
        self.refresh()
        return T.load(t['id'])

    def refresh(self):
        self.w['tasks'] = T.all_tasks(strict=True)
        self.w['queue'] = S.queue()
        return self.w

    def worker(self, folder, text, use, local, here, push, said, name, **kwargs):
        tid = kwargs['task_id']
        self.starts.append((tid, use, local, push, kwargs))
        T.launch(tid, use, 'user', 'queue', sequence=kwargs['launch_seq'])

    def test_priority_order_next_and_move(self):
        a, b, c = self.task('high'), self.task('critical'), self.task('high')
        order = lambda: [t['id'] for t in S.ordered(T.all_tasks(), S.queue())]
        self.assertEqual(order(), [b['id'], a['id'], c['id']])
        S.mutate('up', c['id']); self.assertEqual(order(), [b['id'], c['id'], a['id']])
        S.mutate('next', a['id']); self.assertEqual(order()[0], a['id'])
        S.mutate('priority', b['id'], 'low'); self.assertEqual(T.load(b['id'])['priority'], 'low')
        S.mutate('defer', a['id']); self.assertNotIn(a['id'], order())
        S.mutate('defer', c['id'], 'later'); self.assertEqual(T.load(c['id'])['status']['value'], 'backlog')
        S.mutate('cancel', b['id']); self.assertEqual(order(), [])

    def test_first_and_reconcile_missing_order(self):
        a, b = self.task(), self.task()
        S.mutate('defer', b['id']); S.mutate('add', b['id'], 'first')
        self.assertEqual(S.view(self.refresh())['next']['id'], b['id'])
        S.write('queue.json', {'version': 1, 'order': [], 'paused': False})
        self.assertEqual(len(S.view(self.refresh())['rows']), 2)
        self.assertIn(a['id'], S.view(self.w)['order'])

    def test_dependencies_skip_high_and_same_desk(self):
        a, b = self.task('high'), self.task('normal')
        dep = T.new('dependency', 'test', 'user', desk=a['desk'])
        T.update(a['id'], lambda t: t.update(after=[dep['id']]))
        self.assertEqual(S.view(self.refresh())['next']['id'], b['id'])
        T.move(dep['id'], 'running', 'user'); T.move(dep['id'], 'ready for release', 'user')
        self.assertEqual(S.view(self.refresh())['next']['id'], a['id'])
        T.update(dep['id'], lambda t: t.update(desk={'worktree': '/other'}))
        self.assertEqual(S.view(self.refresh())['next']['id'], b['id'])
        T.move(dep['id'], 'completed', 'user')
        self.assertEqual(S.view(self.refresh())['next']['id'], a['id'])

    def test_discovery_approval_provider_pause_release_and_capacity(self):
        t = self.task()
        self.w['live_known'] = False; self.assertFalse(S.eligible(t, self.w)[0]); self.w['live_known'] = True
        self.w['providers'] = []; self.assertFalse(S.eligible(t, self.w)[0]); self.w['providers'] = ['codex']
        self.w['queue']['paused'] = True; self.assertFalse(S.eligible(t, self.w)[0]); self.w['queue']['paused'] = False
        self.w['releases'] = [{'topic': t['desk']['branch']}]; self.assertFalse(S.eligible(t, self.w)[0]); self.w['releases'] = []
        self.w['desks'] = [{'id': t['desk']['worktree'], 'paused': True}]
        self.assertFalse(S.eligible(t, self.w)[0])
        self.w['desks'] = [{'id': '/busy', 'agents': [{'pid': 1}, {'pid': 2}], 'task_record': {'status': {'value': 'running'}}}]
        self.assertFalse(S.eligible(t, self.w)[0]); self.w['desks'][0]['paused'] = True
        self.assertTrue(S.eligible(t, self.w)[0])
        t['origin']['approved'] = None; self.assertFalse(S.eligible(t, self.w)[0])

    def test_own_desk_busy_and_gone(self):
        t = self.task()
        self.w['desks'] = [{'id': t['desk']['worktree'], 'agents': [{'pid': 4}]}]
        self.assertIn('worker', S.eligible(t, self.w)[1])
        self.w['desks'] = []; Path(t['desk']['worktree']).rmdir()
        self.assertIn('gone', S.eligible(t, self.w)[1])

    def test_auto_off_and_user_start_preserves_identity_choices_and_sequence(self):
        t = self.task()
        T.update(t['id'], lambda t: t['worker'].update(local=True, push=False, mode='supervised', no_tests=True))
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            S.tick(self.api, automatic=True)
            self.assertEqual(self.starts, [])
            result = S.tick(self.api, start=True)
        self.assertEqual(result['launched'], [t['id']])
        self.assertEqual(len(T.all_tasks()), 1)
        self.assertEqual(self.starts[0][1:4], ('codex', True, False))
        self.assertEqual(self.starts[0][4]['mode'], 'supervised')
        self.assertEqual(T.load(t['id'])['launch']['seq'], 1)
        self.assertEqual(S.intents()[t['id']]['seq'], 1)

    def test_simultaneous_ticks_never_launch_twice_and_reserve_capacity(self):
        for _ in range(4): self.task()
        self.w['config']['auto'] = True
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                list(pool.map(lambda _: S.tick(self.api, automatic=True), range(2)))
        self.assertEqual(len(self.starts), 2)
        self.assertEqual(len({s[0] for s in self.starts}), 2)
        self.assertEqual(S.occupied(self.refresh()), 2)

    def test_recover_reservation_no_double_count_and_no_retry(self):
        t = self.task()
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()): S.tick(self.api, start=True)
        intent = S.intents()[t['id']]
        self.w['desks'] = [{'id': t['desk']['worktree'], 'agents': [{'pid': 1}], 'task_record': T.load(t['id'])}]
        self.assertEqual(S.occupied(self.refresh()), 1)
        S.recover(self.w); self.assertEqual(S.intents(), {})
        self.w['desks'] = []
        intent['at'] = int(time.time()) - 121
        S.write('launching/' + t['id'], intent)
        S.recover(self.refresh())
        self.assertEqual(T.load(t['id'])['status']['value'], 'blocked')
        self.assertEqual(S.intents(), {})
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()): S.tick(self.api, start=True)
        self.assertEqual(len(self.starts), 1)

    def test_crash_before_launch_and_discovery_failure(self):
        t = self.task()
        S.write('launching/' + t['id'], {'at': int(time.time()) - 121, 'pid': 0, 'seq': 1, 'folder': t['desk']['worktree']})
        self.w['live_known'] = False; S.recover(self.w)
        self.assertTrue(S.intents())
        self.w['live_known'] = True; S.recover(self.w)
        self.assertEqual(T.load(t['id'])['status']['value'], 'blocked')

    def test_launch_failure_keeps_reservation_for_ambiguous_terminal(self):
        t = self.task()
        self.api.worker_at = Mock(side_effect=RuntimeError('terminal unavailable'))
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            with self.assertRaises(RuntimeError): S.tick(self.api, start=True)
        self.assertEqual(T.load(t['id'])['status']['value'], 'blocked')
        self.assertIn(t['id'], S.intents())

    def test_user_only_mutations_and_invalid_input(self):
        t = self.task()
        with self.assertRaises(T.TaskError): S.mutate('cancel', t['id'], by='codex 42')
        with self.assertRaises(T.TaskError): S.mutate('priority', t['id'], 'urgent')
        self.assertEqual(T.load(t['id'])['status']['value'], 'queued')
        with self.assertRaises(T.TaskError): S.require_task('../../bad')

    def test_config_defaults_and_opt_in(self):
        self.assertEqual(S.config(), {'at_once': 2, 'auto': False})
        (self.base / 'vikix').mkdir()
        (self.base / 'vikix/office').write_text('auto=on\nat_once=3 # slots\n')
        self.assertEqual(S.config(), {'at_once': 3, 'auto': True})


    def agents(self):
        spec = importlib.util.spec_from_loader('scheduler_agents', SourceFileLoader('scheduler_agents', str(ROOT / 'bin/vikix-agents')))
        api = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = api
        spec.loader.exec_module(api)
        for key, value in {'tasks_module': lambda: T, 'handoff_module': lambda: H,
                           'by_me': lambda: ('user', None), 'agents_at': lambda _: [],
                           'common_of': lambda _: '', 'project_of': lambda *_: 'test',
                           'default_agent': lambda: 'codex', 'default_mode': lambda: 'supervised',
                           'open_at': Mock(return_value=2)}.items():
            setattr(api, key, value)
        return api

    def test_real_launcher_preserves_task_and_first_prompt(self):
        api = self.agents()
        task = self.task()
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            S.tick(api, start=True)
        t = T.load(task['id'])
        self.assertEqual(len(T.all_tasks()), 1)
        self.assertEqual(t['launch']['how'], 'queue')
        self.assertEqual(t['launch']['seq'], 1)
        rec = H.load(H.desk_id('', task['desk']['worktree']))
        self.assertEqual(rec['task']['id'], task['id'])
        args = api.open_at.call_args.args[1]
        self.assertIn(task['id'], str(args))
        self.assertIn(task['text'], str(args))

    def test_cli_operations_and_agent_refusal(self):
        api = self.agents()
        t = self.task()
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()), patch.dict(os.environ, VIKIX_AGENT=''):
            api.main(['task', 'priority', t['id'], 'high'])
            api.main(['queue', 'next', t['id']])
            self.assertEqual(T.load(t['id'])['priority'], 'high')
            api.by_me = lambda: ('codex 42', {'pid': 42})
            with self.assertRaises(SystemExit): api.main(['queue', 'start'])
            with self.assertRaises(SystemExit): api.main(['task', 'cancel', t['id']])
            self.assertEqual(T.load(t['id'])['status']['value'], 'queued')

    def test_bump_and_go_restore_the_paused_task(self):
        api = self.agents()
        target, old = self.task(), self.task()
        T.move(old['id'], 'running', 'user')
        folder = old['desk']['worktree']
        api.desk_for = lambda _: (folder, {})
        api.pause_folder = Mock()
        api.task_id_at = lambda _: old['id']
        self.w['desks'] = [{'id': folder, 'agents': [{'pid': 1}], 'task_record': T.load(old['id'])}]
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            S.bump(api, target['id'], folder)
        api.pause_folder.assert_called_once_with(folder, 'user')
        self.assertEqual(T.load(old['id'])['blocked']['on'], target['id'])
        S.unpaused(api, folder)
        self.assertEqual(T.load(old['id'])['status']['value'], 'running')

    def test_plan_uses_shared_slots_and_original_worker_options(self):
        api = self.agents()
        folder = str(self.base / 'plan-desk'); Path(folder).mkdir()
        task = {'text': 'Plan work', 'agent': 'codex', 'local': False, 'push': False,
                'no_tests': True, 'mode': 'supervised', 'acceptance': ['keeps identity']}
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            self.assertTrue(S.start_plan(api, folder, task, 'book', 'test'))
            self.w['config']['at_once'] = 1
            self.assertFalse(S.start_plan(api, folder, task, 'book', 'test'))
        tasks = T.all_tasks()
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0]['origin']['source'], 'plan book')
        self.assertEqual(tasks[0]['launch']['how'], 'queue')
        self.assertTrue(tasks[0]['worker']['no_tests'])

    def test_new_desk_start_registers_desk_before_launch(self):
        task = self.task(desk={})
        folder = str(self.base / 'new-desk'); Path(folder).mkdir()
        api = self.agents()
        api.projects = lambda: SimpleNamespace(match=lambda _: SimpleNamespace(path='/project'))
        api.git = lambda *_: '/project'
        api.worktree = lambda *_: (folder, True)
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            S.tick(api, start=True)
        self.assertEqual(T.load(task['id'])['desk']['worktree'], folder)
        self.assertEqual(S.intents()[task['id']]['folder'], folder)


    def test_push_permission_does_not_leak_to_another_launch(self):
        api = self.agents()
        a, b = self.task(), self.task()
        T.update(a['id'], lambda t: t['worker'].update(push=True))
        grants = []
        api.open_at = lambda *_: grants.append(os.environ.get('VIKIX_AGENT_SSH'))
        with patch.dict(os.environ, VIKIX_AGENT_SSH='1'), patch.object(S, 'world', side_effect=lambda _: self.refresh()):
            S.tick(api, start=True, tid=a['id'])
            S.tick(api, start=True, tid=b['id'])
            self.assertEqual(os.environ.get('VIKIX_AGENT_SSH'), '1')
        self.assertEqual(grants, ['1', None])

    def test_recorded_exit_releases_capacity_immediately(self):
        t = self.task()
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()): S.tick(self.api, start=True)
        T.exited(t['id'], code=0)
        S.recover(self.refresh())
        self.assertEqual(S.intents(), {})
        self.assertEqual(T.load(t['id'])['status']['value'], 'blocked')


    def test_starting_existing_ready_desk_task_does_not_fold_itself(self):
        api = self.agents()
        task = self.task()
        H.update('', task['desk']['worktree'], lambda r: r.update(task={'text': task['text'], 'by': 'user', 'at': 1, 'id': task['id']}))
        with patch.object(S, 'world', side_effect=lambda _: self.refresh()): S.tick(api, start=True)
        rec = H.load(H.desk_id('', task['desk']['worktree']))
        self.assertFalse(rec.get('workers'))
        self.assertEqual(T.load(task['id'])['status']['value'], 'running')
        self.assertNotIn('blocked', [e['kind'] for e in T.events_read(task=task['id'])])


if __name__ == '__main__':
    unittest.main()
