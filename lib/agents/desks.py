"""A desk each: the place (a workspace and a git worktree), a worker started at
it on a task, an agent here, sitting down from inside, closing a desk, and
which desk some words name.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import os
import re
import shutil
import subprocess
import sys
import time


# --- A desk: a workspace and a worktree for one agent --------------------------------
def topic_name(words):
    """WORDS as a branch and a folder's ending: lower case, dashes for spaces."""
    name = re.sub(r"[^a-z0-9]+", "-", words.strip().lower()).strip("-")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,40}", name):
        die(f"a topic is a word or two (letters, digits): '{words}' gives no name for a branch")
    return name


def worktree(top, topic):
    """The worktree of the repository TOP for TOPIC, made when it isn't
    there: TOP-TOPIC beside it, on the branch TOPIC. (folder, made)."""
    folder = os.path.join(os.path.dirname(top), f"{os.path.basename(top)}-{topic}")
    listed = git(top, "worktree", "list", "--porcelain") or ""
    known = {line[9:] for line in listed.splitlines() if line.startswith("worktree ")}
    if os.path.realpath(folder) in {os.path.realpath(k) for k in known}:
        return folder, False
    if os.path.exists(folder):
        die(f"{short(folder)} is there already, and isn't a worktree of {short(top)}: another topic, or move it away")
    has_branch = git(top, "show-ref", "--verify", f"refs/heads/{topic}") is not None
    args = ["worktree", "add", folder, topic] if has_branch else ["worktree", "add", folder, "-b", topic]
    r = subprocess.run(["git", "-C", top, *args], capture_output=True, text=True)
    if r.returncode != 0:
        die("git couldn't make the worktree: " + (r.stderr.strip().splitlines() or ["?"])[-1])
    return folder, True


def agents_offered():
    """What vikix agent --list says: (name, yours, installed, about) a line."""
    try:
        out = subprocess.run([os.path.join(VIKIX_DIR, "bin", "vikix-agent"), "--list"],
                             capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    rows = []
    for line in out.splitlines():
        m = re.match(r"([* ]) (\S+)\s+(installed|-)\s+(.*)", line)
        if m:
            rows.append((m.group(2), m.group(1) == "*", m.group(3) == "installed", m.group(4)))
    return rows


def ask_agent(what="this desk", absent=None):
    """Which agent for WHAT, asked on the desktop: (NAME or None for
    yours, local). None when the menu was closed."""
    rows = agents_offered()
    if not rows:
        return None, False
    rows.sort(key=lambda r: not r[1])     # yours first; the rest as --list has them
    choices, lines = [], []
    for name, yours, installed, about in rows:
        choices.append((None if yours else name, False))
        lines.append(f"{name:<12} {about}" + (" (yours)" if yours else "" if installed else " (not installed yet)"))
    for name, yours, installed, about in rows:
        if name in LOCAL and installed:
            choices.append((name, True))
            lines.append(f"{name:<12} on a model on this laptop (Ollama), offline")
    picked = rofi("Agent", f"The agent for {what}. One not installed yet is offered its installer in the terminal.",
                  lines, absent)
    if picked is None or not picked.isdigit() or int(picked) >= len(choices):
        return None
    return choices[int(picked)]


def ask_push():
    """Whether the agent may push as the user, asked on the desktop: True,
    False, or None when the menu was closed."""
    picked = rofi("Push", "May the agent push as you? With yes, your SSH agent goes with it: after your first "
                          "push of the day it holds your unlocked key, so the agent can push (git push) to "
                          "anything you can. With no, the agent commits and you push.",
                  ["no   it commits, you push (the usual)",
                   "yes  it may push as you (your SSH agent goes with it)"],
                  "say so on the command line: vikix agents desk PROJECT TOPIC [--push]")
    if picked is None or not picked.isdigit():
        return None
    return picked == "1"


def desk(argv):
    """vikix agents desk [PROJECT [TOPIC]] [--task "..."]: the place, and
    with a task a worker at it too."""
    use, local, here, push, words, task, notests = None, False, False, None, [], "", False
    while argv:
        a = argv.pop(0)
        if a == "--use":
            use = argv.pop(0) if argv else die("--use which agent? (vikix agent --list)")
        elif a == "--local":
            local = True
        elif a == "--here":
            here = True
        elif a == "--push":
            push = True
        elif a == "--no-tests":
            notests = True
        elif a == "--task":
            task = argv.pop(0) if argv else die("--task needs the words of the task")
        elif a.startswith("-"):
            die(f"vikix agents desk: {a}? (vikix agents help)")
        else:
            words.append(a)
    if len(words) > 2:
        die("vikix agents desk [PROJECT [TOPIC]]: a topic of several words goes in quotes")
    # The agent's words are the worker's: a desk alone seats nobody.
    agent_words = [w for w, on in (("--use", use), ("--local", local), ("--here", here), ("--push", push)) if on]
    if agent_words and not task and words:
        die(f"{' '.join(agent_words)} is for the worker, and a desk alone starts no agent: give --task \"...\" "
            f"too, or start one at the desk with vikix agents worker DESK {' '.join(agent_words)}")
    vp = projects()
    asked = not words
    if asked:
        table = vp.rows(vp.discover(), True)
        if not table:
            die("no projects found (vikix project list says where it looks)")
        wide = max(len(r[1]) for r in table)
        picked = rofi("Desk in", "The project the desk is for.",
                      [f"{name:<{wide}}  {nxt}"[:160] for _, name, _, _, nxt in table])
        if picked is None or not picked.isdigit():
            return 0
        project = table[int(picked)][0]
    else:
        project = vp.match(words[0])
    if len(words) == 2:
        topic = words[1]
    elif asked:
        topic = rofi("Topic", f"A word or two for what the desk is for in {project.full}: it gets a worktree and a "
                              "branch of that name, so one agent's work can't collide with another's. "
                              "(Only a project that is no repository works in its own folder, with no topic.)")
        if topic is None:
            return 0
    else:
        topic = ""
    if asked and not task:
        # The task, asked as --task would give it: typed, a worker is started at
        # the new desk; nothing typed is the desk alone, for a worker later.
        task = rofi("Task", "The task for a worker at this desk, in your words: written in the desk's record and "
                            "given to the agent as its first prompt. Enter with nothing for the desk alone.")
        if task is None:
            return 0
        task = task.strip()
    if task and asked and not use and not local:
        chosen = ask_agent()
        if chosen is None:
            return 0
        use, local = chosen
    if task and asked and push is None:
        push = ask_push()
        if push is None:
            return 0
    path = str(project.path)
    top = (git(path, "rev-parse", "--show-toplevel") or "").strip()
    said = f"in {short(path)}, the project's own folder (no repository, so no worktree)"
    folder = path
    if topic and not top:
        print(f"{project.full} isn't a git repository, so it has no worktrees: a desk there is its own folder")
    elif top and not topic:
        die(f"a repository's desk is a worktree of it, and {project.full} is one: give a topic "
            f"(vikix agents desk {project.name} TOPIC). The project's own folder is for merging only")
    elif topic:
        topic = topic_name(topic)
        tree, made = worktree(top, topic)
        # A project inside a collection (living-series/living-in-sql): its folder in the worktree.
        folder = os.path.normpath(os.path.join(tree, os.path.relpath(path, top)))
        said = (f"in {short(folder)}, " + (f"a new worktree on the branch {topic}" if made
                                           else f"the worktree that was there (branch {topic})"))
    if not os.path.isdir(folder):
        die(f"{short(folder)} isn't there")
    if top and topic:
        # --no-tests without a task is the desk's setting alone; with a task the worker sets it.
        desk_record(folder, by="user", change=(lambda rec: tests_set(rec, False)) if notests and not task else None)
    if not task:
        at = agents_at(folder)
        print(f"a desk: {said}" + (f"; {', '.join(who(a) for a in at)} is at it" if at else
                                   f". Nobody sits at it: vikix agents worker {topic or project.name} \"the task\" "
                                   "starts a worker there") + ("; its tests don't run by themselves" if notests else ""))
        return 0
    return worker_at(folder, task, use, local, here, push, f"a desk, and a worker at it: {said}", topic or project.name,
                     notests=notests)


def worker(argv):
    """vikix agents worker DESK ["..."]: an agent on a task at a desk that
    is there; without a task, a session there."""
    use, local, here, push, words, notests = None, False, False, False, [], False
    if argv == ["--menu"]:
        # From the desktop: the desk, the task, then the worker's questions as
        # desk asks them. A desk with an agent at it is refused before any
        # question, in a notification, since worker_at's refusal would go unseen.
        folder = pick_desk("A worker at", "The desk the worker is for: an agent on a task there, on a workspace "
                                          "to itself. A desk takes its workers one at a time.")
        if folder is None:
            return 0
        at = agents_at(folder)
        if at:
            say(f"{short(folder)}: {', '.join(who(a) for a in at)} is at this desk already, and a desk takes its "
                "workers one at a time: a note (i) speaks to it, dismiss (x) ends it first")
            return 0
        task = rofi("Task", f"The task for the worker at {short(folder)}, in your words: written in the desk's "
                            "record and given to the agent as its first prompt. Enter with nothing for a session: "
                            "an agent to talk with, the record left as it is.")
        if task is None:
            return 0
        task = task.strip()
        chosen = ask_agent()
        if chosen is None:
            return 0
        use, local = chosen
        push = ask_push()
        if push is None:
            return 0
        argv = [folder] + ([task] if task else [])
    while argv:
        a = argv.pop(0)
        if a == "--use":
            use = argv.pop(0) if argv else die("--use which agent? (vikix agent --list)")
        elif a == "--local":
            local = True
        elif a == "--here":
            here = True
        elif a == "--push":
            push = True
        elif a == "--no-tests":
            notests = True
        elif a.startswith("-"):
            die(f"vikix agents worker: {a}? (vikix agents help)")
        else:
            words.append(a)
    if not words:
        die("vikix agents worker DESK [\"the task\"]: which desk? (vikix agents desks lists them; "
            "vikix agents desk PROJECT TOPIC makes one)")
    folder, rec = desk_for([words[0]])
    task = " ".join(words[1:]).strip()
    if not os.path.isdir(folder):
        die(f"{short(folder)} is gone: vikix agents desk {(rec or {}).get('desk', {}).get('project', 'PROJECT')} "
            f"{os.path.basename(folder).split('-', 1)[-1] if rec else 'TOPIC'} makes the worktree again "
            "(the record is kept, and waits there)")
    return worker_at(folder, task, use, local, here, push, f"a worker at {short(folder)}" if task
                     else f"a session at {short(folder)}", desk_name(folder), notests=notests)


def worker_at(folder, task, use, local, here, push, said, name, notests=False):
    """An agent started at the desk FOLDER: on TASK, the record's task
    folded into the desk's history and TASK its first prompt; without one
    a session, the record left as it is (a line in its log). SAID is how
    the desk was named, NAME what its workspace is called. NOTESTS: the
    tester stays off when this worker hands in; a worker with a task
    started without it has the tests again (the setting is the desk's,
    decided as each worker starts), a session leaves it as it was."""
    H = handoff_module()
    at = agents_at(folder)
    if at:
        # One at a time: in one worktree git can't say whose files are whose,
        # so the house rules couldn't either.
        die(f"{', '.join(who(a) for a in at)} is at this desk already, and a desk takes its workers one at a time: "
            f"vikix agents tell {name} \"...\" leaves it a note, vikix agents dismiss {name} ends it first")
    provider = use or default_agent()
    folded = [None]
    first = None
    if task:
        def change(rec):
            folded[0] = H.start_worker(rec, task, "user", provider)
            tests_set(rec, not notests)
        desk_record(folder, change=change)
        # The task is the agent's first prompt, so a new worker never sits idle
        # with its task written only in the record (2026-10-07: one did, for
        # three minutes, until the user typed "read the handoff").
        first = H.first_prompt_args(provider, desk_prompt(task))
    elif desk_of(folder) or H.load(H.desk_id(common_of(folder), folder)):
        def change(rec):
            H._log(rec, "user", f"session: {provider}")
            if notests:
                tests_set(rec, False)   # a session leaves the setting alone unless told
        desk_record(folder, change=change)
    start = agent_start(use, first or (), local=local)
    if use or local:
        said += f", {use or 'your agent'}" + (" on a model on this laptop" if local else "")
    if push:
        # vikix agent keeps your SSH agent from the agent unless this says
        # otherwise; the terminal, and the agent in it, inherit it from here.
        os.environ["VIKIX_AGENT_SSH"] = "1"
        said += ", and it may push as you"
    if notests:
        said += ", its tests not run by themselves"
    if task:
        said += ", the task its first prompt" if first else f", the task in its handoff ({provider} takes no first prompt)"
        if folded[0]:
            said += f"; the task before it ({folded[0].get('status') or 'no status'}) is in the desk's history"
    else:
        said += ", no task: the handoff is what it has"
    if here:
        print(said)
        if task and not first:
            print(f"The task: {task}")
        open_here(folder, start)
    workspace = open_at(folder, start, name)
    print(said + (f", on workspace {workspace}" if workspace else ""))
    return 0


def desk_prompt(task):
    """The first prompt of an agent started at a desk with a task: the
    user's words, then where the desk's record is."""
    return (task.rstrip() + "\n\nThis is your desk's task, as its record keeps it (vikix agents handoff, or the "
            "MCP tool handoff): read the handoff before you start; once you know the shape of the work, say how "
            "long it will take, assuming no major issue turns up (handoff_update with status working and an "
            "estimate, or vikix agents handoff --status working --estimate \"40 min\"); and write yours "
            "when you hand back or finish.")


def here(argv):
    """An agent in a terminal in the home folder, on this workspace, with no
    desk: what Super+a always did, now its first choice. Which agent is
    asked as a desk asks it, unless --use or --local says."""
    use, local = None, False
    while argv:
        a = argv.pop(0)
        if a == "--use":
            use = argv.pop(0) if argv else die("--use which agent? (vikix agent --list)")
        elif a == "--local":
            local = True
        else:
            die(f"vikix agents here: {a}? (vikix agents help)")
    if not use and not local:
        chosen = ask_agent("this session", "say which agent: vikix agents here --use NAME (vikix agent --list names them)")
        if chosen is None:
            return 0
        use, local = chosen
    open_terminal(os.path.expanduser("~"), agent_start(use, local=local))
    return 0


def agent_start(use=None, extra=(), local=False):
    """What starts the agent: vikix agent with its words (--use, --local),
    or the stand-in the tests name, which gets the same words; EXTRA are
    the agent's own (a session to resume), after --."""
    words = (["--use", use] if use else []) + (["--local"] if local else [])
    start = ([os.environ["VIKIX_AGENT_CMD"]] if os.environ.get("VIKIX_AGENT_CMD")
             else [os.path.join(VIKIX_DIR, "bin", "vikix"), "agent"]) + words
    return start + (["--", *extra] if extra and not os.environ.get("VIKIX_AGENT_CMD") else list(extra))


def open_here(folder, start):
    """START in this terminal, in FOLDER: this process becomes it."""
    sys.stdout.flush()
    os.chdir(folder)
    os.execvp(start[0], start)


def open_terminal(folder, start):
    """START in a terminal of its own in FOLDER, on the workspace in view."""
    if not os.environ.get("DISPLAY"):
        die("no desktop to open a terminal on: add --here to start it in this terminal")
    term = os.environ.get("VIKIX_TERMINAL") or "alacritty"
    if not shutil.which(term):
        die(f"no terminal: {term} isn't installed (VIKIX_TERMINAL names another)")
    subprocess.Popen([term, "-e", *start], cwd=folder, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def open_at(folder, start, name=""):
    """START in a terminal of its own in FOLDER, on a workspace to itself
    (the first empty one of the nine; when all nine have windows, a new one
    called NAME, the desk's topic; this one when there is no name either).
    The workspace's name."""
    form = ("(if (fboundp 'vikix-agent-desk-claim) (princ (vikix-agent-desk-claim "
            + lisp_str(name) + ")) (princ \"\"))")
    try:
        r = subprocess.run(([sys.executable, EVAL] if EVAL.endswith("/bin/vikix-eval") else [EVAL]) + [form],
                           capture_output=True, text=True, timeout=20)
        workspace = next((l for l in r.stdout.splitlines() if l and not l.startswith("=> ")), "")
    except (OSError, subprocess.TimeoutExpired):
        workspace = ""
    open_terminal(folder, start)
    return workspace


# --- Sitting down: an agent takes a desk from where it is -------------------------------------
def sit(argv):
    task = ""
    if "--task" in argv:
        i = argv.index("--task")
        task = argv[i + 1] if len(argv) > i + 1 else die("--task needs the words of the task")
        argv = argv[:i] + argv[i + 2:]
    words = [a for a in argv if not a.startswith("-")]
    if len(words) != len(argv) or len(words) > 2:
        die("vikix agents sit [PROJECT [TOPIC]] [--task \"...\"]")
    me = my_agent()
    if not me:
        die("no agent runs this shell: vikix agents sit is for an agent, from its own shell "
            "(vikix agents desk starts one at a desk)")
    topic = ""
    if not words:
        # The shell's folder first (an agent that went into a worktree of its own: cd, or
        # Claude Code's worktree support, which leaves the process in its first folder).
        try:
            here = os.getcwd()
        except OSError:
            here = ""
        cwd = next((f for f in (here, me.get("cwd") or me["folder"]) if desk_of(f)), "")
        if not cwd:
            die("say which: vikix agents sit PROJECT TOPIC (your folder is not in a desk)")
        folder, said = cwd, ("the desk you are in, a worktree on the branch "
                             f"{(git(cwd, 'rev-parse', '--abbrev-ref', 'HEAD') or '?').strip()}")
    else:
        # A repository by its own folder's name (the hook names it so), else any part of a project's name.
        known = known_repos()
        common = next((c for c, n in known.items() if n == words[0]), None)
        if common:
            path = top = os.path.dirname(common)
        else:
            path = str(projects().match(words[0]).path)
            top = (git(path, "rev-parse", "--show-toplevel") or "").strip()
        if not top:
            folder, said = path, "its folder (no repository, so no worktree)"
        else:
            if len(words) < 2:
                die(f"a repository's desk is a worktree of it: vikix agents sit {os.path.basename(own_folder(top))} TOPIC "
                    "(a word or two for the work)")
            topic = topic_name(words[1])
            tree, made = worktree(own_folder(top), topic)
            folder = os.path.normpath(os.path.join(tree, os.path.relpath(path, top)))
            said = f"a new worktree on the branch {topic}" if made else f"the worktree that was there (branch {topic})"
    if not os.path.isdir(folder):
        die(f"{short(folder)} isn't there")
    seats = seats_read()
    seats[me["pid"]] = {"pid": me["pid"], "agent": me["agent"], "folder": folder, "at": int(time.time())}
    seats_write(seats)
    desktop_nudge()
    rec = desk_record(folder, task=task, by=who(me)) if (task or desk_of(folder)) else None
    if rec and (rec.get("task") or rec.get("handoff")):
        print(f"The desk has a handoff (vikix agents handoff shows it: read it before you start).")
    print(f"{who(me)} is seated at {short(folder)}: {said}. Work there (cd {short(folder)}) and commit there"
          + (f", on the branch {topic}" if topic else "") + "; the house rules take that folder as yours now, "
          "and vikix agents shows you at it.")
    return 0


# --- Closing a desk -----------------------------------------------------------------------
def desks(vp):
    """Every desk there is: a worktree TOP-TOPIC beside a project's
    repository TOP (vikix agents desk makes them so). {folder, top,
    branch} each, by folder; branch is None for a detached one."""
    tops, out = [], []
    for p in vp.discover():
        top = (git(str(p.path), "rev-parse", "--show-toplevel") or "").strip()
        if top and top not in tops:
            tops.append(top)
    for top in tops:
        beside, prefix = os.path.dirname(top), os.path.basename(top) + "-"
        folder, branch = None, None
        for line in (git(top, "worktree", "list", "--porcelain") or "").splitlines() + [""]:
            if line.startswith("worktree "):
                folder, branch = line[9:], None
            elif line.startswith("branch refs/heads/"):
                branch = line[18:]
            elif not line and folder:
                if (os.path.dirname(folder) == beside and os.path.basename(folder).startswith(prefix)
                        and os.path.realpath(folder) != os.path.realpath(top)):
                    out.append({"folder": folder, "top": top, "branch": branch})
                folder = None
    return sorted(out, key=lambda d: d["folder"])


def desk_state(d):
    """What stands in the way of closing D: the agents at work there, how
    many files wait uncommitted, and whether its branch is in (merged into
    the project's own branch, as git branch -d judges it)."""
    d["agents"] = [f"{a['agent']} {a['pid']}" for a in sorted(live_agents(), key=lambda a: a["pid"])
                   if a["folder"] and inside(os.path.realpath(a["folder"]), os.path.realpath(d["folder"]))]
    status = git(d["folder"], "status", "--porcelain")
    d["uncommitted"] = len(status.splitlines()) if status is not None else None
    merged = git(d["top"], "branch", "--merged", "HEAD", "--format=%(refname:short)") or ""
    d["head"] = (git(d["top"], "rev-parse", "--abbrev-ref", "HEAD") or "?").strip()
    d["merged"] = d["branch"] is None or d["branch"] in merged.split()
    return d


def desk_line(d):
    n = d["uncommitted"]
    parts = [f"branch {d['branch']}" + (", in" if d["merged"] else f", not in {d['head']} yet") if d["branch"] else "no branch",
             "nothing uncommitted" if n == 0 else f"{n} uncommitted" if n is not None else "?"]
    if d["agents"]:
        parts.append("at work: " + ", ".join(d["agents"]))
    return f"{short(d['folder'])}  ({'; '.join(parts)})"


def close(argv):
    force, words = False, []
    while argv:
        a = argv.pop(0)
        if a == "--force":
            force = True
        elif a.startswith("-"):
            die(f"vikix agents close: {a}? (vikix agents help)")
        else:
            words.append(a)
    if len(words) > 2:
        die("vikix agents close [DESK | PROJECT TOPIC] [--force]")
    vp = projects()
    every = [desk_state(d) for d in desks(vp)]
    if not every:
        die("no desk to close: no project has a worktree beside it (vikix agents desk makes one)")
    if not words:
        if os.environ.get("DISPLAY") and shutil.which("rofi"):
            picked = rofi("Close the desk", "Its worktree is removed, and its branch when the work is in. "
                          "One with an agent at work, or files uncommitted, is refused.", [desk_line(d) for d in every])
            if picked is None or not picked.isdigit():
                return 0
            hits = [every[int(picked)]]
        else:
            print("The desks:\n" + "\n".join("  " + desk_line(d) for d in every))
            die("say which: vikix agents close DESK (its folder, topic or branch, or PROJECT TOPIC)")
    elif len(words) == 2:
        top = (git(str(vp.match(words[0]).path), "rev-parse", "--show-toplevel") or "").strip()
        folder = os.path.join(os.path.dirname(top), f"{os.path.basename(top)}-{topic_name(words[1])}") if top else ""
        hits = [d for d in every if d["folder"] == folder]
    else:
        word = os.path.realpath(os.path.expanduser(words[0]))
        hits = [d for d in every if os.path.realpath(d["folder"]) == word]
        if not hits:
            hits = [d for d in every if d["branch"] == words[0] or os.path.basename(d["folder"]) == words[0]
                    or os.path.basename(d["folder"]).endswith("-" + words[0])]
    if not hits:
        die(f"no desk called {' '.join(words)}; the desks: " + ", ".join(short(d["folder"]) for d in every))
    if len(hits) > 1:
        die(f"{' '.join(words)} is several desks, say which: " + ", ".join(short(d["folder"]) for d in hits))
    d = hits[0]
    folder, top, branch = d["folder"], d["top"], d["branch"]
    try:
        cwd = os.getcwd()         # before the folder goes: afterwards there is no cwd to ask for
    except OSError:
        cwd = ""
    if d["agents"]:
        die(f"{', '.join(d['agents'])} still at work in {short(folder)}: let it finish, or close its terminal, then close the desk")
    if d["uncommitted"] and not force:
        die(f"{d['uncommitted']} file{'s' if d['uncommitted'] != 1 else ''} uncommitted in {short(folder)}: "
            "commit there first, or --force throws them away")
    common = common_of(folder)      # before the folder goes: the record's id is made from it
    r = subprocess.run(["git", "-C", top, "worktree", "remove"] + (["--force"] if force else []) + [folder],
                       capture_output=True, text=True)
    if r.returncode != 0:
        die("git couldn't remove the worktree: " + (r.stderr.strip().splitlines() or ["?"])[-1])
    said = f"the desk is closed: {short(folder)} removed"
    try:
        handoff_module().close_record(common, folder, "user")
    except Exception:  # noqa: BLE001  a record that can't be marked doesn't stop the closing
        pass
    if branch and (d["merged"] or force):
        r = subprocess.run(["git", "-C", top, "branch", "-D" if force else "-d", branch], capture_output=True, text=True)
        said += (f", the branch {branch} deleted" + (" (its work wasn't in)" if force and not d["merged"] else "")
                 if r.returncode == 0 else f"; the branch {branch} stays: " + (r.stderr.strip().splitlines() or ["?"])[-1])
    elif branch:
        said += (f"; the branch {branch} is kept: not in {d['head']} yet. Merge it, then git branch -d {branch} "
                 f"in {short(top)}; or --force throws it away")
    if cwd and (inside(cwd, os.path.realpath(folder)) or inside(cwd, folder)):
        said += ". This terminal was in it: cd somewhere else"
    say(said)
    return 0


def pick_desk(prompt, message):
    """The desk picked in rofi (the menu forms): its folder, or None when
    the menu was closed; dies with the desks listed when there is no
    desktop to ask on."""
    every = [desk_state(d) for d in desks(projects())]
    if not every:
        die("no desk: no project has a worktree beside it (vikix agents desk makes one)")
    picked = rofi(prompt, message, [desk_line(d) for d in every],
                  absent="say which desk: " + ", ".join(short(d["folder"]) for d in every))
    if picked is None or not picked.isdigit():
        return None
    return every[int(picked)]["folder"]


def desk_for(words, me=None):
    """The desk WORDS name (a folder, a topic, a branch, a record's id, or
    PROJECT TOPIC), or with none the desk the caller sits at (its seat,
    else its shell's folder). (folder, record or None); the folder may be
    gone when a record is all that is left."""
    H = handoff_module()
    if not words:
        me = me or my_agent()
        try:
            here = os.getcwd()
        except OSError:
            here = ""
        for f in ([me["folder"]] if me else []) + [here]:
            if f and (desk_of(f) or (not common_of(f) and project_folder_p(f))):
                return f, H.load(H.desk_id(common_of(f), f))
        die("no desk here: say which (vikix agents handoff DESK: its folder, topic or branch; "
            "vikix agents handoff list names them)")
    if len(words) == 1 and H.DESK_ID.match(words[0]):
        rec = H.load(words[0])
        if rec:
            return rec["desk"]["worktree"], rec
    vp = projects()
    every = desks(vp)
    if len(words) == 2:
        top = (git(str(vp.match(words[0]).path), "rev-parse", "--show-toplevel") or "").strip()
        folder = os.path.join(os.path.dirname(top), f"{os.path.basename(top)}-{topic_name(words[1])}") if top else ""
        hits = [d["folder"] for d in every if d["folder"] == folder]
    else:
        word = os.path.realpath(os.path.expanduser(words[0]))
        hits = [d["folder"] for d in every if os.path.realpath(d["folder"]) == word]
        if not hits:
            hits = [d["folder"] for d in every if d["branch"] == words[0] or os.path.basename(d["folder"]) == words[0]
                    or os.path.basename(d["folder"]).endswith("-" + words[0])]
        if not hits and os.path.isdir(word) and not common_of(word) and project_folder_p(word):
            hits = [word]
    if not hits:
        # A desk whose folder is gone: its record still answers by name.
        name = words[-1]
        recs = [r for r in H.all_records() if os.path.basename(r["desk"]["worktree"]) in (name, f"{words[0]}-{name}")
                or r["desk"]["branch"] == name or os.path.basename(r["desk"]["worktree"]).endswith("-" + name)]
        if len(recs) == 1:
            return recs[0]["desk"]["worktree"], recs[0]
        die(f"no desk called {' '.join(words)} (vikix agents handoff list names them)")
    if len(hits) > 1:
        die(f"{' '.join(words)} is several desks, say which: " + ", ".join(short(h) for h in hits))
    return hits[0], H.load(H.desk_id(common_of(hits[0]), hits[0]))
