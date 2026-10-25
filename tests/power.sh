#!/usr/bin/env bash
# tests/power.sh — kernel power profiles through the real CLI and menu,
# with fabricated sysfs and rofi; authenticated writes mocked in Python.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop
export EMACS_SOCKET_NAME=/nonexistent/emacs-server
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # never the desktop session settings
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/sys" "$t/bin"
export VIKIX_POWER_SYSFS="$t/sys"
printf 'quiet balanced performance\n' > "$t/sys/platform_profile_choices"
printf 'performance\n' > "$t/sys/platform_profile"
# Tests enter through vikix's public dispatcher as well as the desktop menu.
python3 - "$here" "$t" <<'PY'
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch
root, temp = map(Path, sys.argv[1:])

def cli(*args, ok=True, extra=None):
    result = subprocess.run(['bash', str(root / 'bin/vikix'), 'power', *args],
                            text=True, capture_output=True, timeout=10,
                            env={**os.environ, **(extra or {})})
    assert (result.returncode == 0) == ok, (args, result.stdout, result.stderr)
    return result

assert 'available: quiet balanced performance' in cli().stdout
cli('set', 'quiet')
assert (temp / 'sys/platform_profile').read_text() == 'quiet\n'
cli('set', 'performance', extra={'DRY_RUN': '1'})
assert (temp / 'sys/platform_profile').read_text() == 'quiet\n'
assert 'unsupported profile' in cli('set', 'bogus', ok=False).stderr
assert 'unsupported profile' in cli('set', '../../bad', ok=False).stderr
rofi = temp / 'bin/rofi'
rofi.write_text('#!/bin/sh\ncat > "$VIKIX_POWER_SYSFS/menu-input"\nprintf "%s\\n" "${PICK:-balanced}"\nexit "${CANCEL:-0}"\n')
rofi.chmod(0o755)
menu_env = {'PATH': str(temp / 'bin') + ':' + os.environ['PATH']}
cli('menu', extra=menu_env)
assert (temp / 'sys/platform_profile').read_text() == 'balanced\n'
assert (temp / 'sys/menu-input').read_text() == 'quiet\nbalanced\nperformance\n'
cli('menu', extra={**menu_env, 'PICK': 'performance', 'CANCEL': '1'})
assert (temp / 'sys/platform_profile').read_text() == 'balanced\n'
cli('menu', extra={**menu_env, 'PICK': 'bogus'}, ok=False)
(temp / 'sys/platform_profile_choices').unlink()
assert 'does not expose' in cli(ok=False).stderr
(temp / 'sys/platform_profile_choices').write_text('low-power balanced-performance\n')
cli('set', 'low-power')
assert 'low-power' in cli().stdout

# The privileged path uses a fixed target, input data and no shell;
# a custom root must never become an authenticated arbitrary file write.
loader = importlib.machinery.SourceFileLoader('power', str(root / 'bin/vikix-power'))
spec = importlib.util.spec_from_loader(loader.name, loader)
power = importlib.util.module_from_spec(spec)
loader.exec_module(power)
with patch.object(power.os, 'access', return_value=False), patch.object(power.subprocess, 'run') as run:
    try:
        power.select('balanced-performance')
        raise AssertionError('custom root elevated')
    except SystemExit as exc:
        assert exc.code == 1
    run.assert_not_called()
power.ROOT = power.DEFAULT_ROOT
with patch.object(power, 'profiles', side_effect=[('quiet', ['quiet', 'performance']), ('performance', ['quiet', 'performance'])]), \
     patch.object(power.os, 'access', return_value=False), \
     patch.object(power.shutil, 'which', return_value='/usr/bin/pkexec'), \
     patch.object(power.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
    power.select('performance')
    assert run.call_args.args[0] == ['/usr/bin/pkexec', '/usr/bin/tee', '--', '/sys/firmware/acpi/platform_profile']
    assert run.call_args.kwargs['input'] == 'performance\n'
with patch.object(power, 'profiles', return_value=('quiet', ['quiet', 'performance'])), \
     patch.object(power.os, 'access', return_value=False), \
     patch.object(power.shutil, 'which', return_value='/usr/bin/pkexec'), \
     patch.object(power.subprocess, 'run', return_value=subprocess.CompletedProcess([], 126)):
    try:
        power.select('performance')
        raise AssertionError('cancelled authorization was accepted')
    except SystemExit as exc:
        assert exc.code == 1
print('power: real dispatcher and menu, supported/unsupported machines, dry-run, no arbitrary privileged target, authorization cancellation')
PY
# Extract the formatters into bare SBCL: a fake sysfs path, no X or desktop.
if command -v sbcl >/dev/null; then
  {
    echo '(defun vikix-ml-what (kind text) (declare (ignore kind)) text)'
    echo '(defun vikix-battery-file (name) (declare (ignore name)) nil)'
    awk '/^\(defparameter \*vikix-power-profile-root\*/,/^$/; /^\(defun vikix-mode-line-power-profile/,/^$/; /^\(defun vikix-mode-line-battery-charge/,/^$/; /^\(defun vikix-mode-line-battery \(/,/^$/' "$here/config/stumpwm/vikix/modeline.lisp"
    printf '(setf *vikix-power-profile-root* #p"%s/sys/")\n' "$t"
    echo '(assert (equal (vikix-mode-line-battery nil) "power low-power  "))'
    printf '(setf *vikix-power-profile-root* #p"%s/missing/")\n' "$t"
    echo '(assert (equal (vikix-mode-line-battery nil) ""))'
  } > "$t/bar.lisp"
  sbcl --noinform --script "$t/bar.lisp"
else
  echo 'power: SBCL missing; bar formatter check skipped'
fi
