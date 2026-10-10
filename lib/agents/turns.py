"""Pause and go: a worker held and let go, a worker dismissed, turns on one
file, and what is left.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import json
import os
import signal
import time


# --- Pause and go; turns on one file ------------------------------------------------------------
PAUSE_LIMIT = int(os.environ.get("VIKIX_PAUSE_LIMIT") or 600)   # seconds a hook waits, at most
RELEASE_WAIT = int(os.environ.get("VIKIX_RELEASE_WAIT") or 1800)   # seconds the tester waits for a release's tests, at most


def pause_path(folder):
    """The desk's pause: a file named by the desk's id, {at, by, hard, stopped}."""
    H = handoff_module()
    return os.path.join(STATE, "vikix", "office", "pause", H.desk_id(common_of(folder), folder))


def pause_read(folder):
    try:
        with open(pause_path(folder)) as f:
            p = json.load(f)
        return p if isinstance(p, dict) else {}
    except (OSError, ValueError):
        return {}


def signal_agent(pid, sig):
    """SIG to the agent PID, pinned by a process descriptor and checked to
    be an agent still: never a bare pid, which may be another program's by
    now, and never a group. True when sent."""
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        return False
    try:
        fd = os.pidfd_open(pid)
    except OSError:
        return False
    try:
        if agent_name(cmdline(pid)) is None:
            return False
        signal.pidfd_send_signal(fd, sig)
        return True
    except OSError:
        return False
    finally:
        os.close(fd)


def pause(argv):
    """vikix agents pause DESK [--hard] | --menu."""
    if argv == ["--menu"]:
        folder = pick_desk("Pause, or go", "A paused desk's agent holds at its next tool call; a paused one picked goes on.")
        if folder is None:
            return 0
        argv = [folder]
        if os.path.exists(pause_path(folder)):
            say(go_folder(folder))
            return 0
    hard = "--hard" in argv
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) - (1 if hard else 0):
        die("vikix agents pause DESK [--hard] (DESK as for close)")
    by, me = by_me()
    folder, _ = desk_for(words, me)
    if hard and me and any(a["pid"] == me["pid"] for a in agents_at(folder)):
        die("you can't freeze your own process: vikix agents pause without --hard holds you at your next call")
    say(pause_folder(folder, by, hard))
    return 0


def pause_folder(folder, by, hard=False):
    """The desk FOLDER paused by BY (its agents' processes frozen when
    HARD); what was done, in words."""
    there = agents_at(folder)
    path = pause_path(folder)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    stopped = [a["pid"] for a in there if hard and signal_agent(a["pid"], signal.SIGSTOP)]
    with open(path, "w") as f:
        json.dump({"at": int(time.time()), "by": by, "hard": hard, "stopped": stopped}, f)
    names = ", ".join(who(a) for a in there)
    if hard:
        said = (f"{short(folder)}: frozen (SIGSTOP): {', '.join(who(a) for a in there if a['pid'] in stopped)}"
                if stopped else f"{short(folder)}: paused; no agent's process to freeze there now")
        said += "; vikix agents go lets it continue"
    elif there:
        said = (f"{short(folder)}: paused; {names} hold{'s' if len(there) == 1 else ''} at the next tool call, for up to "
                f"{PAUSE_LIMIT // 60} minutes, then that call is refused and the turn ends; vikix agents go lets it go on")
    else:
        said = f"{short(folder)}: paused (no agent is there now: one that comes holds at its first call)"
    return said


def go_folder(folder):
    """The desk FOLDER let go; what was done, in words."""
    path = pause_path(folder)
    if not os.path.exists(path):
        return f"{short(folder)} isn't paused"
    p = pause_read(folder)
    woken = [pid for pid in p.get("stopped", []) if isinstance(pid, int) and signal_agent(pid, signal.SIGCONT)]
    os.unlink(path)
    return f"{short(folder)}: go" + (f"; {len(woken)} process{'es' if len(woken) != 1 else ''} continue{'' if len(woken) != 1 else 's'}"
                                     if woken else "; its agent's next call goes through")


def go(argv):
    """vikix agents go DESK."""
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv):
        die("vikix agents go DESK")
    by, me = by_me()
    folder, _ = desk_for(words, me)
    print(go_folder(folder))
    return 0


def dismiss(argv):
    """vikix agents dismiss DESK | --menu: the desk's agents asked to exit,
    the desk kept."""
    if argv == ["--menu"]:
        folder = pick_desk("Dismiss", "Its agent is asked to exit; the desk, its branch and its files stay (vikix agents resume takes it up again).")
        if folder is None:
            return 0
        argv = [folder]
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) or not words:
        die("vikix agents dismiss DESK (DESK as for close)")
    by, me = by_me()
    folder, _ = desk_for(words, me)
    there = agents_at(folder)
    if me and any(a["pid"] == me["pid"] for a in there):
        die("that is your own desk: an agent doesn't dismiss itself (write your handoff and end your turn)")
    if not there:
        say(f"{short(folder)}: no agent is there to dismiss")
        return 0
    H = handoff_module()
    try:
        inbox_add(folder, f"dismissed by {by}: write your handoff if you can, then stop", by)
    except H.HandoffError:
        pass
    gone, left = [], []
    for a in there:
        if not signal_agent(a["pid"], signal.SIGTERM):
            left.append(a)
            continue
        for _ in range(15):
            if process_gone(a["pid"]):
                break
            time.sleep(0.2)
        (gone if process_gone(a["pid"]) else left).append(a)
    dirty = (H.observe(folder) if os.path.isdir(folder) else {}).get("dirty")

    def change(rec):
        rec["left"] = {"at": int(time.time()), "by": by, "reason": "dismissed", "dirty": dirty,
                       "agents": [who(a) for a in there]}
        H._log(rec, by, "dismissed " + ", ".join(who(a) for a in there))
    try:
        desk_record(folder, by=by, change=change)
    except H.HandoffError:
        pass
    said = f"{short(folder)}: " + (f"dismissed {', '.join(who(a) for a in gone)}" if gone else "")
    if left:
        said += ("; " if gone else "") + f"{', '.join(who(a) for a in left)} still exiting (not forced)"
    said += f". The desk, its branch and {dirty if dirty is not None else '?'} uncommitted file{'s' if dirty != 1 else ''} stay; vikix agents resume takes it up again"
    say(said)
    return 0


def turns(argv):
    """vikix agents turns DESK on|off."""
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) or len(words) < 2 or words[-1] not in ("on", "off"):
        die("vikix agents turns DESK on|off (DESK as for close)")
    on = words[-1] == "on"
    by, me = by_me()
    folder, _ = desk_for(words[:-1], me)
    H = handoff_module()

    def change(rec):
        rec["turns"] = {"on": on, "by": by, "at": int(time.time())}
        H._log(rec, by, f"turns {'on' if on else 'off'}")
    try:
        desk_record(folder, by=by, change=change)
    except H.HandoffError as e:
        die(str(e))
    print(f"{short(folder)}: turns {'on' if on else 'off'}: " + (
        "an edit of a file another agent has changed, uncommitted, waits for that agent's commit "
        f"(up to {PAUSE_LIMIT // 60} minutes), then asks you" if on else "a clash asks you, as usual"))
    return 0
