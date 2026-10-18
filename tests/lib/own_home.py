"""A home of the test's own, before the office modules are imported.

lib/tasks.py, lib/handoff.py and lib/agents/common.py read the office's
folders from HOME and XDG_STATE_HOME when they are imported. The shell
wrappers (tests/office-ui.sh, tasks.sh, scheduler.sh) export a temporary
home first; a test file run by hand, `python3 tests/office-ui.py`, had
none, and on 2026-10-18 it wrote twenty fixture tasks into the real
office (~/.local/state/vikix/office/tasks, "Old task", "Keep me", ...)
and took three real launch numbers, and its queue ticks (bin/vikix-agents
queue tick, four children of up to a minute that outlive the test) ran on
the real queue. So each of those files calls `claim()` before its first
office import: when HOME or the state dir is still the real one, a
temporary home replaces both, cleaned at exit, and the scheduler's ticks
are off (VIKIX_SCHEDULER=0, as tests/scheduler.sh has them).
"""
import atexit
import os
import pwd
import shutil
import tempfile


def real_home():
    return os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir)


def inside(path, folder):
    path = os.path.realpath(path)
    return path == folder or path.startswith(folder + os.sep)


def claim():
    """Point HOME and the XDG folders at a temporary directory unless the
    environment already keeps them away from the real home; return the
    directory made, or None when none was needed."""
    home = real_home()
    state = os.environ.get("XDG_STATE_HOME") or os.path.join(os.environ.get("HOME") or home, ".local", "state")
    if not inside(os.environ.get("HOME") or home, home) and not inside(state, home):
        return None
    tmp = tempfile.mkdtemp(prefix="vikix-test-home-")
    atexit.register(shutil.rmtree, tmp, True)
    os.environ["HOME"] = tmp
    for kind in ("STATE", "CONFIG", "DATA", "CACHE"):
        os.environ["XDG_%s_HOME" % kind] = os.path.join(tmp, kind.lower())
    os.environ.pop("VIKIX_STATE", None)
    os.environ["VIKIX_SCHEDULER"] = "0"
    return tmp
