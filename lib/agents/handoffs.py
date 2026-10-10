"""The handoff: a desk's task, status, account and checks, kept across sessions
in its record; telling a worker; the handoff's menu and commands; taking a
desk up again (resume).

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import fcntl
import json
import os
import shlex
import shutil
import subprocess
import sys
import time


# --- The handoff: a desk's task, status, account and checks, kept across sessions ---------------
def inbox_path(folder):
    """The desk's inbox: a line a note, named by the desk's id as its record is
    (STATE is set further down, with the journal's)."""
    H = handoff_module()
    return os.path.join(STATE, "vikix", "office", "inbox", H.desk_id(common_of(folder), folder) + ".jsonl")


def inbox_add(folder, text, by):
    """TEXT left for the desk's agent, signed BY; raises HandoffError for
    text a record may not hold (a credential)."""
    H = handoff_module()
    text = H.clean(text, "the note").replace("\n", " ")
    if not text:
        raise H.HandoffError("a note needs words")
    path = inbox_path(folder)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with open(path, "a") as f:
            f.write(json.dumps({"at": int(time.time()), "by": by, "text": text}, ensure_ascii=False) + "\n")


def inbox_read(path):
    notes = []
    try:
        with open(path) as f:
            for line in f:
                try:
                    n = json.loads(line)
                except ValueError:
                    continue
                if isinstance(n, dict) and n.get("text"):
                    notes.append(n)
    except OSError:
        pass
    return notes


def inbox_peek(folder):
    """The notes waiting at the desk, left where they are."""
    return inbox_read(inbox_path(folder))


def inbox_take(folder):
    """The notes waiting at the desk, and the inbox emptied: for the hook,
    which hands them to the agent."""
    path = inbox_path(folder)
    if not os.path.exists(path):
        return []
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        notes = inbox_read(path)
        if notes:
            open(path, "w").close()
    return notes


def tell(argv):
    """vikix agents tell DESK "..." | --menu: a note for the desk's agent."""
    if argv == ["--menu"]:
        folder = pick_desk("A note for", "The desk whose agent gets the note, at its next tool call.")
        if folder is None:
            return 0
        text = rofi("Note", f"For the agent at {short(folder)}: a line of text.")
        if not text:
            return 0
        argv = [folder, text]
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) or len(words) < 2:
        die("vikix agents tell DESK \"the note\" (DESK as for close: the folder, the topic, the branch, or PROJECT TOPIC)")
    by, me = by_me()
    folder, _ = desk_for(words[:-1], me)
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: no agent can read a note there")
    H = handoff_module()
    try:
        inbox_add(folder, words[-1], by)
    except H.HandoffError as e:
        die(str(e))
    there = [a for a in live_agents() if a["folder"] and os.path.realpath(a["folder"]) == os.path.realpath(folder)]
    said = f"{short(folder)}: noted for its agent"
    if not there:
        said += " (none is there now: vikix agents resume reads it out when one takes the desk up)"
    elif all(a["agent"] != "claude" for a in there):
        said += (f"; {', '.join(who(a) for a in there)} has no hook that carries a note, so it isn't told: "
                 "vikix agents handoff shows the note, and the agent reads it when it looks there")
    else:
        # What the agent is doing, from the desktop: a note reaches it only at an edit or a
        # command, which an agent at its prompt makes none of until it is spoken to.
        try:
            states = {a["pid"]: a["state"] for a in desktop(strict=True)}
        except (RuntimeError, SystemExit):
            states = {}
        state = next((states.get(a["pid"]) for a in there if a["agent"] == "claude" and states.get(a["pid"])), "")
        if state in ("idle", "done"):
            said += "; its agent is at its prompt: it reads this when you next ask it something"
        elif state == "asks":
            said += "; its agent is waiting for you: answer it, and it reads this at its next tool call"
        else:
            said += ", delivered at its next tool call"
    say(said)
    return 0


def status_told(folder, before, rec, by):
    """The user told, on the desktop, when an agent's status comes to
    review, waiting or finished: the report of a worker. Never for the
    user's own change, or a status that stayed."""
    status = ((rec.get("handoff") or {}).get("status") or {}).get("value")
    if by == "user" or status == before or status not in ("review", "waiting", "finished"):
        return
    if not os.environ.get("DISPLAY") or not shutil.which("notify-send"):
        return
    h = rec.get("handoff") or {}
    said = {"review": "ready for review", "waiting": "waiting for you", "finished": "finished"}[status]
    body = ((h.get("next") or h.get("summary") or {}).get("text") or "").replace("\n", " ")[:200]
    subprocess.run(["notify-send", "-a", "Vikix", f"Agent at {short(folder)}: {said}", body or f"by {by}"], check=False)


def handoff_apply(folder, data, by):
    """DATA (the fields --from takes) applied to the desk's record, signed
    BY, the user told of a status worth telling; raises HandoffError."""
    H = handoff_module()
    common = common_of(folder)
    seen = {}

    def change(rec):
        seen["before"] = ((rec.get("handoff") or {}).get("status") or {}).get("value")
        H.from_json(rec, data, by, folder)
    rec = H.update(common, folder, change, branch=(git(folder, "rev-parse", "--abbrev-ref", "HEAD") or "").strip(),
                   project=project_of(folder, common))
    status_told(folder, seen.get("before"), rec, by)
    status = ((rec.get("handoff") or {}).get("status") or {}).get("value")
    if (status == "review" and seen.get("before") != "review" and os.environ.get("VIKIX_TESTER") != "0"
            and rec["desk"].get("tests") != "off" and runner_of(folder)[1] and not tester_running(folder)):
        tester_start(folder)
    return rec


def stopping(argv):
    """Claude Code's Stop hook (config/claude/office.json): a worker, an
    agent at a desk with a task, that changed files in this turn and
    hasn't written its handoff since is asked once to write it before it
    stops; the stop after that is let go (stop_hook_active), so nothing
    goes round. A desk with no task, and an agent off a desk, are never
    held to it."""
    got = {}
    if not sys.stdin.isatty():
        try:
            got = json.loads(sys.stdin.read() or "{}")
        except ValueError:
            got = {}
    if not isinstance(got, dict) or got.get("stop_hook_active"):
        return 0
    me = my_agent()
    if not me or not me["folder"]:
        return 0
    H = handoff_module()
    common = common_of(me["folder"])
    rec = H.load(H.desk_id(common, me["folder"]))
    if not rec or not rec.get("task"):
        return 0
    h = rec.get("handoff") or {}
    last = max([v.get("at", 0) for v in h.values() if isinstance(v, dict)] or [0])
    edited = {e.get("file") for e in journal_read()
              if e.get("pid") == me["pid"] and e.get("kind") in ("edit", "crossing", "shell") and e.get("at", 0) > last}
    if not edited:
        return 0
    try:
        H.update(common, me["folder"], lambda r: H._log(r, "vikix", "asked for the handoff before the agent stopped"))
    except (H.HandoffError, OSError):
        pass
    n = len(edited)
    print(json.dumps({"decision": "block", "reason": (
        f"Vikix office: this turn changed {n} file{'s' if n != 1 else ''} at your desk and the handoff hasn't been "
        "written since. Write it now, then stop: vikix agents handoff --status working|waiting|review|finished "
        "--summary \"what you changed and decided\" --next \"what is left, the very next action\" (or the MCP tool "
        "handoff_update); review when the work is ready for the user, waiting when you need them.")}))
    return 0


def note_session(sid):
    """The resumable session id the hook's input carries (Claude Code's
    session_id), noted on the agent's desk once: nothing else of the
    conversation is kept."""
    H = handoff_module()
    if not H.session_id_ok(sid):
        return
    me = my_agent()
    if not me or not desk_of(me["folder"]):
        return
    common = common_of(me["folder"])
    rec = H.load(H.desk_id(common, me["folder"]))
    if rec and any(s["provider"] == me["agent"] and s["id"] == sid and s.get("pid") == me["pid"]
                   for s in rec.get("sessions", [])):
        return
    try:
        H.update(common, me["folder"], lambda r: H.add_session(r, me["agent"], sid, who(me), me["pid"]),
                 branch=(git(me["folder"], "rev-parse", "--abbrev-ref", "HEAD") or "").strip(),
                 project=project_of(me["folder"], common))
    except (H.HandoffError, OSError):
        pass


def protection_lines(folder):
    """What holds the house rules for each agent at the desk: honest about
    what there is. A hook is seen through the journal's proposed edits
    (noted before the edit, so a note is a proposal, not a change made)."""
    lines = []
    here = [a for a in live_agents() if a["folder"] and os.path.realpath(a["folder"]) == os.path.realpath(folder)]
    entries = journal_read()
    for a in sorted(here, key=lambda a: a["pid"]):
        seen = sum(1 for e in entries if e.get("pid") == a["pid"] and e.get("kind") in ("edit", "crossing"))
        if a["agent"] in ("claude", "antigravity"):
            held = (f"pre-edit and pre-shell hooks (vikix agents touch): {seen} edit{'s' if seen != 1 else ''} proposed "
                    "through them" if seen else "pre-edit hooks expected from vikix agent, none seen yet "
                    "(a session started another way has only the instructions)")
        elif a["agent"] in ("codex", "opencode", "gemini"):
            held = (f"a pre-edit hook: {seen} edit{'s' if seen != 1 else ''} proposed through it" if seen else
                    f"instructions only, unless its hook is installed (vikix agents hooks {a['agent']})")
        else:
            held = "instructions only (no hook)"
        lines.append(f"{who(a)}: {held}")
    lines.append("no filesystem enforcement: a worktree keeps copies apart, it is no sandbox")
    return here, lines


def handoff_menu():
    """From Super+m: pick a desk with a record, and read it in a terminal."""
    H = handoff_module()
    recs = H.all_records()
    if not recs:
        die("no desk has a handoff yet (vikix agents desk PROJECT TOPIC --task \"...\" starts one)")
    lines = [f"{short(r['desk']['worktree'])}  {((r.get('handoff') or {}).get('status') or {}).get('value', 'no status')}"
             f"  {(r.get('task') or {}).get('text', '')[:60]}" for r in recs]
    picked = rofi("Handoff of", "A desk's task, what the agent did and left, and its checks.", lines)
    if picked is None or not picked.isdigit():
        return 0
    did = recs[int(picked)]["desk"]["id"]
    term = os.environ.get("VIKIX_TERMINAL") or "alacritty"
    if not shutil.which(term):
        die(f"no terminal: {term} isn't installed")
    me = os.path.join(VIKIX_DIR, "bin", "vikix-agents")
    subprocess.Popen([term, "--title", "Handoff", "-e", "bash", "-c",
                      f"python3 {shlex.quote(me)} handoff {did}; echo; read -r -p 'Enter closes this window. ' _"],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 0


def handoff(argv):
    H = handoff_module()
    if argv == ["--menu"]:
        return handoff_menu()
    verb = argv.pop(0) if argv and argv[0] in ("show", "set", "check", "session", "list", "forget") else "show"
    as_json, desk, words, opts = False, None, [], {}
    # A setting given is a set: "handoff --status working", no verb needed.
    if verb == "show" and any(a in SETTINGS for a in argv):
        verb = "set"
    while argv:
        a = argv.pop(0)
        if a == "--json":
            as_json = True
        elif a == "--desk":
            desk = argv.pop(0).split() if argv else die("--desk which? (vikix agents handoff list)")
        elif a in SETTINGS or a == "--note":
            opts[a] = argv.pop(0) if argv else die(f"{a} needs words")
        elif a in ("--ok", "--failed"):
            opts["ok"] = a == "--ok"
        elif a.startswith("-"):
            die(f"vikix agents handoff: {a}? (vikix agents help)")
        else:
            words.append(a)
    if verb == "list":
        recs = H.all_records()
        if as_json:
            print(json.dumps(recs, indent=1, ensure_ascii=False))
            return 0
        if not recs:
            print("No desk has a record yet: vikix agents desk PROJECT TOPIC makes one, "
                  "vikix agents worker DESK \"...\" starts a worker at it.")
            return 0
        for r in recs:
            d, h = r["desk"], r.get("handoff") or {}
            status = (h.get("status") or {}).get("value", "no status")
            place = short(d["worktree"]) + ("" if os.path.isdir(d["worktree"]) else " (folder gone)")
            est = H.estimate_state(r)
            print(f"  {place}  {status}, {H.when(r['updated'])}: {(r.get('task') or {}).get('text', 'no task')[:80]}"
                  + (f"  ({est['line']})" if est else "")
                  + (f"  [closed {H.when(d['closed'])}]" if d.get("closed") else ""))
        return 0
    if verb == "forget":
        return handoff_forget(desk if desk is not None else words)
    by, me = by_me()
    if verb == "show":
        folder, rec = desk_for(desk if desk is not None else words, me)
        if not rec:
            die(f"{short(folder)} has no record yet: vikix agents handoff --task \"...\" starts one")
        if as_json:
            now = H.observe(folder) if os.path.isdir(folder) else {}
            rec = dict(rec, now=now, checks=[dict(c, freshness=H.freshness(c, now)) for c in rec.get("checks", [])])
            print(json.dumps(rec, indent=1, ensure_ascii=False))
            return 0
        agents_at, lines = protection_lines(folder) if os.path.isdir(folder) else ([], [])
        print(H.render(rec, [who(a) for a in agents_at], lines))
        notes = inbox_peek(folder)
        if notes:
            print("Notes waiting for its agent (vikix agents tell; delivered at its next tool call):")
            for n in notes:
                print(f"  {n['by']} ({H.when(n['at'])}): {n['text']}")
        return 0
    # set names its desk as show does, before the settings; check and session
    # take their own words, so for them it is --desk.
    folder, _ = desk_for(desk if desk is not None else (words if verb == "set" else []), me)
    if verb == "set":
        words = []
        data = {}
        if "--from" in opts:
            src = opts["--from"]
            try:
                text = sys.stdin.read() if src == "-" else open(src).read()
                data = json.loads(text or "{}")
            except (OSError, ValueError) as e:
                die(f"--from {src}: {e}")
        for k in ("--task", "--status", "--summary", "--next", "--estimate"):
            if k in opts:
                data[k[2:]] = opts[k]
        if not data:
            die("nothing to set: --task, --status (working|waiting|review|finished), --summary, --next, "
                "--estimate, or --from")
        try:
            rec = handoff_apply(folder, data, by)
        except H.HandoffError as e:
            die(str(e))
        s = (rec.get("handoff") or {}).get("status")
        est = H.estimate_state(rec) if "estimate" in data else None
        print(f"{short(folder)}: handoff updated by {by}" + (f", status {s['value']}" if s else "")
              + (f", estimate {H.span(est['minutes'])} from now" if est else ""))
        return 0
    if verb == "check":
        if not words or "ok" not in opts:
            die("vikix agents handoff check NAME --ok|--failed [--note \"...\"]")
        rec = desk_record(folder, by=by, change=lambda r: H.add_check(r, " ".join(words), opts["ok"], by, folder,
                                                                       opts.get("--note", "")))
        c = rec["checks"][-1]
        print(f"{short(folder)}: {'passed' if c['ok'] else 'failed'} {c['name']} on {(c['commit'] or '?')[:7]}"
              + (", tree dirty" if c.get("dirty") else ", clean tree") + f" ({by})")
        return 0
    if verb == "session":
        if len(words) != 2:
            die("vikix agents handoff session PROVIDER ID (claude, codex, opencode, gemini, antigravity, aider, other)")
        pid = me["pid"] if me and me["agent"] == words[0] else 0
        desk_record(folder, by=by, change=lambda r: H.add_session(r, words[0], words[1], by, pid))
        print(f"{short(folder)}: {words[0]} session {words[1]} noted; vikix agents resume offers it")
        return 0
    return 0

def forgettable():
    """The records that may be forgotten: their worktree gone, no agent
    left in it. (record, why not) for every record whose folder is gone."""
    H = handoff_module()
    at = {}
    for a in live_agents():
        folder = a.get("folder") or ""
        # Linux names a running process's removed cwd "PATH (deleted)": still that desk's.
        if folder.endswith(" (deleted)") and not os.path.lexists(folder):
            folder = folder[:-10]
        at.setdefault(os.path.realpath(folder), []).append(who(a))
    out = []
    for rec in H.all_records():
        wt = rec["desk"]["worktree"]
        if os.path.lexists(wt):
            continue
        out.append((rec, ", ".join(at.get(os.path.realpath(wt), []))))
    return out


def forget_record(rec):
    """The record REC removed, for a desk whose worktree is gone and where
    no agent is left: what was done, in a line. HandoffError says why not."""
    H = handoff_module()
    d = rec["desk"]
    if os.path.lexists(d["worktree"]):
        raise H.HandoffError(f"{short(d['worktree'])} is there: a desk that stands is closed, not forgotten "
                             f"(vikix agents close {os.path.basename(d['worktree'])} takes it down and keeps the record)")
    there = dict((r["desk"]["id"], at) for r, at in forgettable()).get(d["id"], "")
    if there:
        raise H.HandoffError(f"{there} still at work in {short(d['worktree'])}, gone as it is: let it finish first")
    if not H.forget(d["id"]):
        raise H.HandoffError(f"the record of {short(d['worktree'])} is gone already")
    h = rec.get("handoff") or {}
    status = (h.get("status") or {}).get("value", "no status")
    return (f"forgotten: the record of {short(d['worktree'])} ({d.get('branch') or 'no branch'}, {status}"
            + (f", closed {H.when(d['closed'])}" if d.get("closed") else ", never closed")
            + "). Nothing else went with it: no file, no branch, no conversation of the provider's")


def handoff_forget(words):
    """vikix agents handoff forget [DESK]: the record of a desk whose
    worktree is gone, removed; with no desk named, the ones that could be."""
    H = handoff_module()
    if not words:
        gone = forgettable()
        if not gone:
            print("No record of a desk whose folder is gone: nothing to forget (vikix agents handoff list).")
            return 0
        print("The records of desks whose folder is gone:")
        for rec, at in gone:
            d = rec["desk"]
            status = ((rec.get("handoff") or {}).get("status") or {}).get("value", "no status")
            print(f"  {short(d['worktree'])}  {status}, {H.when(rec['updated'])}"
                  + (f"  [closed {H.when(d['closed'])}]" if d.get("closed") else "")
                  + (f"  ({at} still there)" if at else ""))
        die("say which: vikix agents handoff forget DESK (its topic, branch or folder)")
    folder, rec = desk_for(words)
    if not rec:
        die(f"{short(folder)} has no record: nothing to forget")
    try:
        print(forget_record(rec))
    except H.HandoffError as e:
        die(str(e))
    return 0


# --- Taking a desk up again: the handoff shown, the conversation resumed where it can be ----------
def resume(argv):
    H = handoff_module()
    use, here, fresh, another, words = None, False, False, False, []
    require_saved, expect_session, menu = False, None, False
    while argv:
        a = argv.pop(0)
        if a == "--menu":
            menu = True
        elif a == "--use":
            use = argv.pop(0) if argv else die("--use which agent? (vikix agent --list)")
        elif a == "--here":
            here = True
        elif a == "--expect-session":
            expect_session = argv.pop(0) if argv else die("--expect-session needs a conversation id")
        elif a == "--require-saved":
            require_saved = True
        elif a == "--fresh":
            fresh = True
        elif a == "--another":
            another = True
        elif a.startswith("-"):
            die(f"vikix agents resume: {a}? (vikix agents help)")
        else:
            words.append(a)
    if menu and not words:
        # From the desktop (Super+Alt+d, r; Super+m): the desk picked in rofi.
        every = [desk_state(d) for d in desks(projects())]
        if not every:
            die("no desk to take up: no project has a worktree beside it (vikix agents desk makes one)")
        picked = rofi("Take a desk up again", "Its handoff is shown, and an agent started there: the conversation "
                      "resumed where its provider still has it.", [desk_line(d) for d in every])
        if picked is None or not picked.isdigit():
            return 0
        words = [every[int(picked)]["folder"]]
    folder, rec = desk_for(words)
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: vikix agents desk {(rec or {}).get('desk', {}).get('project', 'PROJECT')} "
            f"{os.path.basename(folder).split('-', 1)[-1] if rec else 'TOPIC'} makes the worktree again "
            "(the record is kept, and waits there)")
    at, lines = protection_lines(folder)
    if rec:
        print(H.render(rec, [who(a) for a in at], lines))
    else:
        print(f"Desk {short(folder)}: no record yet (vikix agents handoff --task \"...\" starts one)")
        for line in lines:
            print("  " + line)
    if at and not another:
        die(f"{', '.join(who(a) for a in at)} is at this desk already: go to it (vikix agents, Super+m), "
            "or --another starts a second agent there")
    sessions = (rec or {}).get("sessions", [])
    provider = use or (sessions[-1]["provider"] if sessions else "") or default_agent()
    plan = H.resume_plan(rec, provider, folder, fresh)
    if expect_session and (plan["mode"] != "resumed" or plan["session"]["id"] != expect_session):
        die("saved conversation changed or unavailable; refresh and choose again")
    if require_saved and plan["mode"] != "resumed":
        die("saved conversation unavailable: " + plan["why"] + "; choose --fresh explicitly")
    if plan["mode"] == "resumed":
        sid = plan["session"]["id"]
        said = f"resumed: {provider} session {sid} at {short(folder)}, its conversation continues ({plan['why']})"
        if provider in H.UNVERIFIED:
            said += f"; {provider}'s resume is from its documentation, unverified on this machine"
    else:
        said = f"fresh conversation with {provider} at {short(folder)}: {plan['why']}. The handoff above is what it has"
        disk = H.sessions_on_disk(provider, folder)
        if disk and not fresh:
            said += ("\n" + f"{provider}'s own store has a conversation in this folder: "
                     + ", ".join(f"{sid} ({H.when(t)})" for sid, t in disk)
                     + f". If it is this desk's, note it (vikix agents handoff session {provider} ID) and resume again; "
                     "nothing is resumed unasked")
    print()
    print(said)
    if rec:
        try:
            H.update(common_of(folder), folder,
                     lambda r_: H._log(r_, "user", f"{plan['mode']}: {provider}" + (f" {plan['session']['id']}" if plan["session"] and plan["mode"] == "resumed" else "")))
        except H.HandoffError:
            pass
    notes = inbox_peek(folder)
    if notes:
        print("Notes waiting for its agent (vikix agents tell), read out here since a resumed agent's hook delivers them too:")
        for n in notes:
            print(f"  {n['by']} ({H.when(n['at'])}): {n['text']}")
    start = agent_start(provider if provider != default_agent() or plan["args"] else None, plan["args"])
    if here:
        open_here(folder, start)
    workspace = open_at(folder, start, desk_name(folder))
    if workspace:
        print(f"on workspace {workspace}")
    return 0


def handoff_brief(folder):
    """The desk's record in a line's worth: status, where the work stands
    against the estimate, next, the checks' freshness (fresh/stale
    counts). None without a record."""
    try:
        H = handoff_module()
        rec = H.load(H.desk_id(common_of(folder), folder))
    except Exception:  # noqa: BLE001  a record that can't be read costs the line, not the listing
        return None
    if not rec:
        return None
    h = rec.get("handoff") or {}
    now = H.observe(folder) if os.path.isdir(folder) else {}
    checks = rec.get("checks") or []
    fresh = sum(1 for c in checks if H.freshness(c, now) == "fresh")
    est = H.estimate_state(rec)
    return {"status": (h.get("status") or {}).get("value"), "next": (h.get("next") or {}).get("text", ""),
            "estimate": est["line"] if est else "", "task": (rec.get("task") or {}).get("text", ""),
            "checks": f"{fresh} fresh, {len(checks) - fresh} stale" if checks else "",
            "notes": len(inbox_peek(folder))}
