"""Fixture discovery, cancellation, scope, preferences, and real launcher checks."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
def interrupted(_signum, _frame):
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, interrupted)
ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader('network', str(ROOT / 'bin/vikix-network'))
spec = importlib.util.spec_from_loader(loader.name, loader)
N = importlib.util.module_from_spec(spec)
loader.exec_module(N)

STUB = r'''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
base = Path(os.environ['NETWORK_FIXTURE'])
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with (base / 'calls').open('a') as f: f.write(json.dumps([tool] + args) + '\n')
data = json.loads((base / 'network.json').read_text())
if tool == 'nmcli':
    if data.get('connected', True):
        print('fixture-uuid:802-11-wireless:wlan9:' + data.get('name', 'Test LAN') + ':/org/freedesktop/NetworkManager/ActiveConnection/' + str(data.get('attachment', 1)))
elif tool == 'ip':
    if 'address' in args:
        value = [{'ifname': 'wlan9', 'addr_info': [{'family': 'inet', 'local': '192.0.2.10', 'prefixlen': 24}]}]
    elif 'neigh' in args:
        value = [] if data.get('unknown') else [{'dev': 'wlan9', 'dst': '192.0.2.1', 'lladdr': data.get('mac', '00:11:22:33:44:55'), 'state': ['REACHABLE']}]
    elif 'rule' in args:
        value = [{'table': 'local'}, {'table': 'main'}, {'table': 'default'}]
        if data.get('vpn'): value.insert(0, {'table': '100'})
    else:
        value = [{'dev': 'wlan9', 'dst': data.get('subnet', '192.0.2.0/24'), 'scope': 'link'},
                 {'dev': 'wlan9', 'dst': 'default', 'gateway': '192.0.2.1'}]
        if data.get('overlap'): value.append({'dev': 'tun0', 'dst': '192.0.2.20/32'})
    print(json.dumps(value))
elif tool == 'nmap':
    (base / 'scanner.pid').write_text(str(os.getpid()))
    if data.get('slow'): time.sleep(30)
    if data.get('fail'): sys.exit(2)
    if data.get('badxml'): print('<broken'); sys.exit(0)
    if data.get('learn_gateway'):
        data['unknown'] = False
        (base / 'network.json').write_text(json.dumps(data))
    print('<nmaprun><host><status state="up"/><address addr="192.0.2.20" addrtype="ipv4"/>')
    if '-sT' in args:
        print('<ports><port protocol="tcp" portid="22"><state state="open"/><service name="ssh"/></port>'
              '<port protocol="tcp" portid="443"><state state="open"/><service name="https"/></port>'
              '<extraports state="closed" count="24"/></ports>')
    print('</host><host><status state="up"/><address addr="203.0.113.8" addrtype="ipv4"/></host></nmaprun>')
elif tool == 'notify-send': pass
'''


class Network(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        for name in ('ip', 'nmcli', 'nmap', 'notify-send'):
            path = self.bin / name
            path.write_text(STUB)
            path.chmod(0o755)
        self.env = patch.dict(os.environ, NETWORK_FIXTURE=str(self.base),
                              PATH=str(self.bin) + ':' + os.environ['PATH'],
                              XDG_RUNTIME_DIR=str(self.base), XDG_CONFIG_HOME=str(self.base / 'config'))
        self.env.start()
        self.state()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(self.env.stop)

    def state(self, **kw):
        (self.base / 'network.json').write_text(json.dumps(kw))

    def cli(self, *args, ok=True):
        result = subprocess.run([str(ROOT / 'bin/vikix'), 'network', *args], capture_output=True, text=True, timeout=15)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def identity(self):
        return json.loads(self.cli('status').stdout)['networks'][0]['id']

    def calls(self, name):
        return [x for x in map(json.loads, (self.base / 'calls').read_text().splitlines()) if x[0] == name]

    def test_manual_read_only_and_escaped_names(self):
        self.state(name=r'Test\: A\\B')
        data = json.loads(self.cli('refresh').stdout)
        net = data['networks'][0]
        self.assertEqual(net['name'], 'Test: A\\B')
        self.assertEqual(net['policy'], 'manual')
        self.assertEqual({d['role'] for d in net['devices']}, {'Gateway', 'This computer'})
        self.assertFalse(self.calls('nmap'))
        self.assertEqual(N.fields(r'a\\:b'), ['a\\', 'b'])

    def test_discovery_ports_and_scope(self):
        identity = self.identity()
        net = json.loads(self.cli('discover', identity).stdout)['networks'][0]
        self.assertIn('192.0.2.20', [d['address'] for d in net['devices']])
        self.assertNotIn('203.0.113.8', [d['address'] for d in net['devices']])
        net = json.loads(self.cli('ports', identity, '192.0.2.20').stdout)['networks'][0]
        peer = next(d for d in net['devices'] if d['address'] == '192.0.2.20')
        self.assertTrue(peer['checked'])
        self.assertEqual([p['port'] for p in peer['ports']], [22, 443])
        self.assertEqual(peer['other_ports'], '24 closed')
        count = len(self.calls('nmap'))
        for ip in ('203.0.113.1', '--script=all', '127.0.0.1', '192.0.2.255', '192.0.2.20;touch /tmp/no'):
            self.cli('ports', identity, ip, ok=False)
        self.assertEqual(len(self.calls('nmap')), count)
        self.assertTrue(all('-n' in c and '--unprivileged' in c for c in self.calls('nmap')))

    def test_preferences_rejoin_and_no_history(self):
        identity = self.identity()
        self.cli('policy', identity, 'ports')
        self.cli('refresh')
        self.assertEqual(len(self.calls('nmap')), 2)
        self.cli('refresh')
        self.assertEqual(len(self.calls('nmap')), 2)
        self.state(connected=False)
        self.assertFalse(json.loads(self.cli('refresh').stdout)['networks'])
        self.assertEqual([p.name for p in N.runtime().glob('*.json')], ['joins.json'])
        self.state(attachment=2)
        new_id = self.identity()
        self.assertNotEqual(identity, new_id)
        self.cli('refresh')
        self.assertEqual(len(self.calls('nmap')), 4)
        self.state(mac='00:11:22:33:44:99', attachment=3)
        net = json.loads(self.cli('refresh').stdout)['networks'][0]
        self.assertEqual(net['policy'], 'manual')
        self.assertEqual(len(self.calls('nmap')), 4)
        self.cli('discover', identity, ok=False)
        prefs = N.preferences()
        self.assertEqual(prefs.stat().st_mode & 0o777, 0o600)
        self.assertNotIn('192.0.2', prefs.read_text())

    def test_unknown_large_vpn_and_overlap(self):
        self.state(unknown=True)
        identity = self.identity()
        self.cli('policy', identity, 'discover', ok=False)
        for options in ({'subnet': '192.0.0.0/16'}, {'vpn': True}, {'overlap': True}):
            self.state(**options)
            identity = self.identity()
            self.cli('discover', identity, ok=False)
        self.assertFalse(self.calls('nmap'))

    def test_scan_failure_is_not_an_empty_success(self):
        self.state(fail=True)
        self.cli('discover', self.identity(), ok=False)
        self.state(badxml=True)
        self.cli('discover', self.identity(), ok=False)
        self.assertFalse(N.cached(N.networks()[0]))

    def test_old_devices_expire_even_after_another_device_is_checked(self):
        net = N.networks()[0]
        now = time.time()
        N.write(N.cache_path(net), dict(id=net['id'], at=now, devices=[
            dict(address='192.0.2.20', observed_at=now - 601),
            dict(address='192.0.2.21', observed_at=now)]))
        self.assertEqual([d['address'] for d in N.cached(net)['devices']], ['192.0.2.21'])

    def test_disconnect_and_interrupt_reap_scanner(self):
        for disconnect in (True, False):
            self.state(slow=True)
            pid_file = self.base / 'scanner.pid'
            pid_file.unlink(missing_ok=True)
            proc = subprocess.Popen([str(ROOT / 'bin/vikix'), 'network', 'discover', self.identity()],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                end = time.monotonic() + 5
                while not pid_file.exists() and time.monotonic() < end:
                    time.sleep(.03)
                self.assertTrue(pid_file.exists())
                child = int(pid_file.read_text())
                if disconnect:
                    self.state(connected=False)
                else:
                    proc.send_signal(signal.SIGTERM)
                proc.communicate(timeout=10)
                self.assertNotEqual(proc.returncode, 0)
                with self.assertRaises(ProcessLookupError):
                    os.kill(child, 0)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    proc.communicate(timeout=10)

    def test_automatic_policy_cancellation(self):
        identity = self.identity()
        self.cli('policy', identity, 'discover')
        self.state(slow=True)
        proc = subprocess.Popen([str(ROOT / 'bin/vikix-network'), 'refresh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            end = time.monotonic() + 5
            while not (self.base / 'scanner.pid').exists() and time.monotonic() < end:
                time.sleep(.03)
            self.assertTrue((self.base / 'scanner.pid').exists())
            self.cli('policy', identity, 'manual')
            proc.communicate(timeout=10)
            self.assertIn('preference changed', N.cached(N.networks()[0])['error'])
        finally:
            if proc.poll() is None:
                proc.terminate()
                proc.communicate(timeout=10)

    def test_busy_scanner_retries_without_losing_results(self):
        net = N.networks()[0]
        N.set_policy(net['id'], 'discover')
        seen = {}
        with N.lock(N.runtime() / 'scan.lock'):
            N.auto_once(seen)
        self.assertNotIn(net['id'], seen)
        N.auto_once(seen)
        self.assertEqual(seen[net['id']], 'discover')
        self.assertTrue(N.cached(net)['devices'])

    def test_scan_deadline_reaps_child(self):
        self.state(slow=True)
        net = N.networks()[0]
        with patch.object(N, 'SCAN_SECONDS', .05):
            with self.assertRaisesRegex(RuntimeError, 'timed out'):
                N.scan(net, net['subnets'])
        child = int((self.base / 'scanner.pid').read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(child, 0)

    def test_first_discovery_can_learn_the_gateway(self):
        self.state(unknown=True, learn_gateway=True)
        identity = self.identity()
        net = json.loads(self.cli('discover', identity).stdout)['networks'][0]
        self.assertNotEqual(identity, net['id'])
        self.assertTrue(net['identifiable'])
        self.assertIn('192.0.2.20', [d['address'] for d in net['devices']])
        self.assertEqual(net['policy'], 'manual')

    def test_preference_file_link_is_preserved(self):
        path = N.preferences()
        target = self.base / 'my-network-preferences.json'
        target.write_text('{}')
        path.symlink_to(target)
        N.set_policy(self.identity(), 'discover')
        self.assertTrue(path.is_symlink())
        self.assertIn('discover', target.read_text())

    def test_launcher_failures_and_safe_forms(self):
        self.cli(ok=False)  # no display
        with patch.dict(os.environ, DISPLAY=':99999'):
            self.cli(ok=False)  # unavailable server, never start another Emacs
        with patch.object(N, 'run', return_value='nil') as called, patch.dict(os.environ, DISPLAY=':9"\\\n(test)'):
            N.launch()
            argv = called.call_args.args[0]
            self.assertEqual(argv[1], '--alternate-editor=false')
            self.assertIn(json.dumps(os.environ['DISPLAY']), argv[-1])

    @unittest.skipUnless(shutil.which('Xvfb') and shutil.which('emacs'), 'needs Xvfb and Emacs')
    def test_real_launcher_from_headless_and_graphical_emacs(self):
        # Own both processes before starting either; reap them even on a failed assertion.
        screen = daemon = None
        readfd, writefd = os.pipe()
        try:
            with (self.base / 'x.log').open('w') as xlog, (self.base / 'emacs.log').open('w') as elog:
                screen = subprocess.Popen(['Xvfb', '-displayfd', str(writefd), '-screen', '0', '1500x1000x24', '-nolisten', 'tcp'],
                                          pass_fds=(writefd,), stdout=xlog, stderr=xlog)
                os.close(writefd)
                writefd = None
                self.assertTrue(select.select([readfd], [], [], 10)[0], 'Xvfb did not start')
                display = ':' + os.read(readfd, 40).decode().strip()
                socket = str(self.base / 'emacs-server')
                with patch.dict(os.environ, DISPLAY=display, EMACS_SOCKET_NAME=socket):
                    daemon = subprocess.Popen(['emacs', '-Q', '--fg-daemon=' + socket], stdout=elog, stderr=elog)
                    end = time.monotonic() + 15
                    while not Path(socket).exists() and time.monotonic() < end:
                        time.sleep(.1)
                    self.assertTrue(Path(socket).exists(), (self.base / 'emacs.log').read_text())
                    def evaluate(form):
                        result = subprocess.run(['emacsclient', '--alternate-editor=false', '--eval', form],
                                                capture_output=True, text=True, timeout=10)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        return result
                    evaluate('(require (quote cl-lib))')
                    self.assertEqual(evaluate('(length (cl-remove-if-not (quote display-graphic-p) (frame-list)))').stdout.strip(), '0')
                    self.cli()
                    count = '(length (cl-remove-if-not (lambda (f) (frame-parameter f (quote vikix-network-buffer))) (frame-list)))'
                    self.assertEqual(evaluate(count).stdout.strip(), '1')
                    self.cli()  # reuses the existing graphical frame
                    self.assertEqual(evaluate(count).stdout.strip(), '1')
                    self.assertEqual(evaluate('(let ((frame (cl-find-if (lambda (f) (frame-parameter f (quote vikix-network-buffer))) (frame-list)))) '
                                              '(equal (vikix-network-open ' + json.dumps(display) + ') '
                                              '(frame-parameter frame (quote outer-window-id))))').stdout.strip(), 't')
                    evaluate('(with-current-buffer "*Network Office*" (vikix-network-close))')
                    self.assertEqual(evaluate(count).stdout.strip(), '0')
                    evaluate("(make-frame '((display . " + json.dumps(display) + ')))')
                    self.cli()
                    self.assertEqual(evaluate(count).stdout.strip(), '1')
                    end = time.monotonic() + 10
                    while time.monotonic() < end:
                        ready = evaluate('(with-current-buffer "*Network Office*" (and (null vikix-network--process) vikix-network--data))')
                        if ready.stdout.strip() != 'nil':
                            break
                        time.sleep(.1)
                    self.assertNotEqual(ready.stdout.strip(), 'nil', 'Office never received its local snapshot')
                    self.assertIn('Test LAN', ready.stdout)
                    if os.environ.get('VIKIX_NETWORK_PREVIEW'):
                        # Hold periodic refresh while preparing a reproducible screenshot.
                        evaluate('(with-current-buffer "*Network Office*" '
                                 '(cancel-timer vikix-network--timer) (setq vikix-network--timer nil))')
                        end = time.monotonic() + 10
                        while time.monotonic() < end:
                            if evaluate('(with-current-buffer "*Network Office*" (null vikix-network--process))').stdout.strip() == 't':
                                break
                            time.sleep(.1)
                        identity = self.identity()
                        self.cli('discover', identity)
                        self.cli('ports', identity, '192.0.2.20')
                        evaluate('(with-current-buffer "*Network Office*" (vikix-network-refresh))')
                        end = time.monotonic() + 10
                        while time.monotonic() < end:
                            if evaluate('(with-current-buffer "*Network Office*" (null vikix-network--process))').stdout.strip() == 't':
                                break
                            time.sleep(.1)
                        evaluate('(with-current-buffer "*Network Office*" (vikix-network--choose ' + json.dumps(identity) + ' "192.0.2.20"))')
                        evaluate('(progn (redisplay t) (with-temp-file ' + json.dumps(os.environ['VIKIX_NETWORK_PREVIEW']) +
                                 ' (set-buffer-multibyte nil) (insert (x-export-frames nil (quote png)))))')
                    evaluate('(with-current-buffer "*Network Office*" (vikix-network-close))')
                    self.assertEqual(evaluate('(length (cl-remove-if-not (quote display-graphic-p) (frame-list)))').stdout.strip(), '1')
                    with patch.dict(os.environ, DISPLAY=':99999'):
                        self.cli(ok=False)
                    evaluate('(kill-emacs 0)')
                    daemon.wait(timeout=10)
        finally:
            os.close(readfd)
            if writefd is not None:
                os.close(writefd)
            for proc in (daemon, screen):
                if proc is not None:
                    if proc.poll() is None:
                        proc.terminate()
                        try:
                            proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            proc.kill()
                    proc.wait(timeout=5)
                    self.assertIsNotNone(proc.returncode)


if __name__ == '__main__':
    unittest.main()
