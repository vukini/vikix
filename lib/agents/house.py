"""The house rules: the hooks each provider runs, the turn a hook waits for,
the journal of edits, clashes and crossings, no desk no work (the seats,
touch), and the Bash commands held to the same rule.

A part of bin/vikix-agents, which reads the parts into its one namespace in
their order (its header lists the commands): not a module to import.
"""
import json
import os
import re
import shlex
import sys
import time


RESUMED = ""    # the words for an agent whose held call goes through: it was paused, and let go


def pause_hold(me, tell=True):
    """A hook's wait while the agent's desk is paused: a second at a time,
    up to PAUSE_LIMIT, then the call is refused with why, so the turn ends
    cleanly and nothing waits for ever. True when refused. Let go (vikix
    agents go, the Office's Go), the call goes through, and with TELL the
    agent, which saw nothing of the wait, is told it was paused and to
    carry on where it was (RESUMED, which hook_output adds): the entry
    before every tool tells, the matcher's holds silently, so an edit,
    which both hooks hold, hears it once."""
    global RESUMED
    if not me or not me["folder"]:
        return False
    path = pause_path(me["folder"])
    if not os.path.exists(path):
        return False
    p = pause_read(me["folder"])
    held = int(time.time())
    end = held + PAUSE_LIMIT
    while os.path.exists(path):
        if time.time() >= end:
            hook_output(permissionDecision="deny", permissionDecisionReason=(
                f"Vikix office: your desk is paused by {p.get('by', 'the user')} since {at(p.get('at', 0))}, and the "
                f"wait reached {PAUSE_LIMIT // 60} minutes. End this turn now, saying you are paused; nothing is lost. "
                "The user's `vikix agents go` and their next words to you start you again."))
            return True
        time.sleep(1)
    if tell:
        since = p.get("at") if isinstance(p.get("at"), int) else held
        RESUMED = (f"Vikix office: your desk was paused by {p.get('by', 'the user')} at {at(since)} and let go just now, "
                   f"after {how_long(max(0, int(time.time()) - since))} (vikix agents go, or the Office's Go). This call, "
                   "held meanwhile, goes through now: carry on from where you were, on the same task and plan; the pause "
                   "changed nothing of yours. A note from the user, when there is one, follows.")
    return False


def turns_on(folder):
    H = handoff_module()
    rec = H.load(H.desk_id(common_of(folder), folder))
    return bool(((rec or {}).get("turns") or {}).get("on"))


def clash_live(path, clashes):
    """Of CLASHES, those that hold a turn: the file still changed,
    uncommitted, in that agent's worktree. A journal entry alone, once the
    file is committed there, holds nobody."""
    _, _, rel = repo_of(path)
    live = []
    for o, how in clashes:
        otop = repo_of(o["folder"])[0] if os.path.isdir(o["folder"]) else None
        if otop and rel and changed_in(otop, rel):
            live.append((o, how))
    return live


def take_turn(me, path, clashes, now):
    """With turns on: wait for the other agents' commits of PATH, up to
    PAUSE_LIMIT. (clashes left, words for the agent): none left and "your
    turn" when the file is committed; the clashes and why when the wait
    ran out, or when the other waits on this agent already (then the later
    one, this one, asks the user at once rather than both waiting)."""
    live = clash_live(path, clashes)
    if not live:
        return [], f"Vikix office: your turn on {short(path)}: what the other agent changed there is committed."
    pids = {o["pid"] for o, _ in live}
    for e in journal_read():
        if e.get("kind") == "waiting" and e.get("pid") in pids and who(me) in (e.get("with") or []):
            return clashes, f"{e.get('agent')} {e.get('pid')} waits on you already (since {at(e.get('at', 0))}), so you ask"
    journal_add({"at": now, "kind": "waiting", "agent": me["agent"], "pid": me["pid"], "folder": me["folder"],
                 "file": path, "with": [who(o) for o, _ in live]})
    end = time.time() + PAUSE_LIMIT
    try:
        while live and time.time() < end:
            time.sleep(1)
            live = clash_live(path, clashes)
    finally:
        journal_write([e for e in journal_read() if not (e.get("kind") == "waiting" and e.get("pid") == me["pid"]
                                                          and e.get("file") == path)])
    if live:
        return clashes, f"waited {PAUSE_LIMIT // 60} minutes for the commit; still uncommitted"
    return [], f"Vikix office: your turn on {short(path)}: the other agent's change there is committed now."


# --- The hooks each provider can run: what holds the rules, honestly --------------------------------
ADAPTERS = {
    "claude": ("config/claude/office.json", None,
               "given to Claude Code by vikix agent at every start (--settings): pre-edit and pre-shell hooks"),
    "codex": ("config/codex/hooks.json", ".codex/hooks.json",
              "PreToolUse hook in ~/.codex/hooks.json, and Vikix's rules in ~/.codex/rules/vikix.rules (git on a "
              "desk's branch, the tests, vikix and the release run without a prompt; sudo and a force-push never). "
              "Its hook format is Claude Code's, from Codex's documentation: unverified on this machine"),
    "opencode": ("config/opencode/vikix-office.js", ".config/opencode/plugins/vikix-office.js",
                 "a plugin on tool.execute.before (edit, write, bash): a refused edit throws, with the reason; a "
                 "clash is refused once and goes through when tried again within ten minutes"),
    "gemini": ("config/gemini/hooks.json", None,
               "a BeforeTool hook to merge into ~/.gemini/settings.json by hand (its hooks key); from Gemini CLI's "
               "documentation, unverified here, and not installed by Vikix since that file is yours"),
    "antigravity": (None, None,
                    "a plugin of Vikix's that vikix agent installs with agy plugin install (under ~/.gemini/config/plugins/vikix): "
                    "pre-edit and pre-shell hooks, answered in agy's shape"),
    "aider": (None, None, "no hooks: instructions only (the guide it reads), and git"),
}


# Files of Vikix's linked beside a provider's hook on --install, a file of the user's own there left alone.
EXTRA_LINKS = {"codex": (("config/codex/vikix.rules", ".codex/rules/vikix.rules"),)}


def link_state(name, src, dest, install, asked):
    """One link's state, made on --install when asked for by name: installed,
    in the way, made now, or how to make it."""
    target = os.path.join(os.path.expanduser("~"), dest)
    source = os.path.join(VIKIX_DIR, src)
    if os.path.islink(target) and os.path.realpath(target) == os.path.realpath(source):
        return "installed"
    if os.path.exists(target) or os.path.islink(target):
        return f"{short(target)} is there and isn't Vikix's: left alone"
    if install and asked:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        os.symlink(source, target)
        return f"installed: {short(target)} -> {short(source)}"
    return f"not installed (vikix agents hooks {name} --install links {short(target)})"


def codex_trust_line():
    """Whether Codex's start trusts the hook for it: the launcher passes
    --dangerously-bypass-hook-trust when the hook file is Vikix's and the
    folder is one of your projects, unless VIKIX_CODEX_HOOK_TRUST=ask."""
    if os.environ.get("VIKIX_CODEX_HOOK_TRUST") == "ask":
        return "trust: Codex's own /hooks prompt everywhere (VIKIX_CODEX_HOOK_TRUST=ask)"
    return ("trust: vikix agent passes --dangerously-bypass-hook-trust in your projects when the hook file is "
            "Vikix's (it vets the file by making it); elsewhere Codex's own /hooks prompt stays")


def hooks(argv):
    install = "--install" in argv
    words = [a for a in argv if not a.startswith("-")]
    if words and words[0] not in ADAPTERS:
        die(f"vikix agents hooks [{'|'.join(ADAPTERS)}] [--install]")
    for name in (words or list(ADAPTERS)):
        src, dest, said = ADAPTERS[name]
        states = []
        if dest:
            states.append(link_state(name, src, dest, install, bool(words)))
            states += [link_state(name, s_, d_, install, bool(words)) for s_, d_ in EXTRA_LINKS.get(name, ())]
        if name == "codex":
            states.append(codex_trust_line())
        print(f"{name:<9} {said}" + "".join(f"\n          {state}" for state in states))
    if install and not words:
        die("say which: vikix agents hooks codex|opencode --install")
    return 0


def clashes_for(me, path, others, entries):
    """The other agents on PATH too: one that edited it (the journal), or
    one whose worktree of the same repository has it changed, uncommitted."""
    found = {}
    for e in entries:
        if e.get("file") == path and e.get("pid") != me["pid"] and e.get("kind") in ("edit", "crossing"):
            o = {"agent": e.get("agent", "?"), "pid": e.get("pid", 0), "folder": e.get("folder", "")}
            found[o["pid"]] = (o, f"edited it too, {how_long(max(0, int(time.time() - e.get('at', 0))))} ago")
    top, common, rel = repo_of(path)
    if top:
        for o in others:
            if o["pid"] == me["pid"] or o["pid"] in found or not os.path.isdir(o["folder"]):
                continue
            otop, ocommon, _ = repo_of(o["folder"])
            if otop and ocommon == common and os.path.realpath(otop) != os.path.realpath(top):
                if changed_in(otop, rel):
                    found[o["pid"]] = (o, f"has changed it in {short(otop)}, uncommitted")
    return list(found.values())


def owns_nothing(folder):
    """An agent in your home folder (Super+a starts them there) works on
    whatever it is told: it owns no folder, so nothing is a crossing into
    it, and everything under home would be."""
    home = os.path.realpath(os.path.expanduser("~"))
    return not folder or os.path.realpath(folder) == home or inside(home, folder)


def crossing_for(me, path, others):
    """The other agent whose folder PATH is in, when it isn't in mine: the
    nearest folder when several are."""
    if inside(path, me["folder"]):
        return None
    hits = [o for o in others if o["pid"] != me["pid"] and inside(path, o["folder"]) and not owns_nothing(o["folder"])]
    return max(hits, key=lambda o: len(o["folder"]), default=None)


# Whose hook asks: Claude Code's JSON has tool_name and tool_input and takes
# hookSpecificOutput back (Codex's and Vikix's OpenCode plugin read the same);
# Antigravity CLI's has toolCall and takes a
# decision (allow, ask, deny) with a reason, nothing else, so what Claude
# Code is told beside an allowed edit (a crossing) asks there, with the
# reason, and nothing to say is {"decision": "ask"}: agy's own way, as the
# decision is required there. HOOK is set by touch.
HOOK = "claude"
SAID = False
NOTES = None


def notes_for_hook():
    """The notes waiting at the agent's desk, taken from the inbox, as the
    words the hook hands the agent; "" when there are none. Taken once."""
    global NOTES
    if NOTES is None:
        NOTES = ""
        me = my_agent()
        if me and me["folder"]:
            notes = inbox_take(me["folder"])
            if notes:
                NOTES = ("Vikix office, notes for you at this desk (vikix agents tell): "
                         + " ".join(f"[{n['by']}, {at(n['at'])}] {n['text']}" for n in notes))
    return NOTES


def hook_output(**fields):
    global SAID
    SAID = True
    if HOOK == "claude":
        # Only Claude Code's hook carries words to the agent beside its decision:
        # that its pause was lifted, then the notes left for it.
        extra = "\n\n".join(x for x in (RESUMED, notes_for_hook()) if x)
        if extra:
            fields["additionalContext"] = (fields.get("additionalContext", "") + "\n\n" + extra).strip()
    if HOOK in ("agy", "gemini"):
        # Gemini CLI's BeforeTool reads the same decision and reason (from its
        # documentation: unverified here); nothing beside an allowed edit there is allow.
        reason = fields.get("permissionDecisionReason") or fields.get("additionalContext") or ""
        print(json.dumps({"decision": fields.get("permissionDecision") or ("ask" if HOOK == "agy" else "allow"),
                          "reason": reason}))
        return
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", **fields}}))


# --- No desk, no work: the seats, and what a desk is -----------------------------------------
def off_desk(me, path):
    """Why ME may not change PATH, in words, or None: a file of a project's
    repository is changed from a desk alone, and never in the project's
    own folder, which is for merging only."""
    top, common, _ = repo_of(path)
    if not top or common not in known_repos():
        return None
    own = own_folder(top)
    name = known_repos()[common] or os.path.basename(own)
    desk = desk_of(me["folder"])
    if desk is None:
        return (f"Vikix office: {short(path)} is in the project {name}, and you are not at a desk. An agent works on a "
                f"repository only from a desk of its own, a worktree of it. Take one from here: run "
                f"`vikix agents sit {name} TOPIC` (a word or two for the work; it makes {short(os.path.dirname(own))}/"
                f"{name}-TOPIC on the branch TOPIC, or takes the one that is there, and seats you at it), then work in "
                f"that folder and commit there; in a worktree of your own already, `vikix agents sit` alone, run from "
                f"inside it, seats you there. The project's own folder, {short(own)}, is for merging only.")
    if os.path.realpath(top) == own:
        return (f"Vikix office: {short(path)} is in {short(own)}, the project's own folder, which is for merging only: "
                f"no agent changes it. Your desk is {short(desk)}: make the change there"
                + ("" if repo_of(desk)[1] == common else f", or take a desk of {name}: vikix agents sit {name} TOPIC")
                + ".")
    return None


# A Bash command is held to the rule when it would write: these programs,
# a redirection, sed -i, or git with a verb that changes something.
WRITERS = {"tee", "mv", "cp", "rm", "rmdir", "mkdir", "touch", "ln", "chmod", "chown", "truncate", "dd", "install",
           "patch", "rsync", "unlink", "shred", "sed", "perl"}
GIT_WRITERS = {"commit", "merge", "rebase", "push", "pull", "checkout", "switch", "reset", "restore", "cherry-pick",
               "revert", "am", "apply", "rm", "mv", "add", "clean", "worktree", "branch", "tag", "stash", "remote",
               "notes", "filter-branch", "update-ref", "symbolic-ref", "gc", "prune"}
GIT_READS = {"list", "show", "-l", "--list", "-a", "-r", "--show-current", "--merged", "--no-merged", "--contains",
             "--points-at", "-v", "--verbose", "get-url"}
SEPARATORS = {"&&", "||", ";", "|", "|&"}


def writes(tokens):
    """Whether the shell command TOKENS would write somewhere."""
    for i, tok in enumerate(tokens):
        if re.fullmatch(r"\d*>>?", tok) or re.fullmatch(r"&>>?", tok):
            # A redirection to a file: '> out' (not 2>&1, not /dev/null).
            target = tokens[i + 1] if i + 1 < len(tokens) else ""
            if target and not target.startswith("&") and target != "/dev/null":
                return True
        elif re.fullmatch(r"\d*>>?[^&].*", tok) or re.fullmatch(r"&>>?.+", tok):
            if not tok.endswith("/dev/null"):
                return True
        name = os.path.basename(tok)
        if name in ("sed", "perl"):
            rest = tokens[i + 1:]
            rest = rest[:next((j for j, t in enumerate(rest) if t in SEPARATORS), len(rest))]
            if any(t.startswith("-i") or t == "--in-place" or (name == "perl" and t.startswith("-p") and "i" in t)
                   for t in rest):
                return True
        elif name in WRITERS:
            return True
        elif name == "git":
            rest = tokens[i + 1:]
            rest = rest[:next((j for j, t in enumerate(rest) if t in SEPARATORS), len(rest))]
            verb, k = "", 0
            while k < len(rest):
                if rest[k] in ("-C", "-c", "--git-dir", "--work-tree"):
                    k += 2
                    continue
                if not rest[k].startswith("-"):
                    verb = rest[k]
                    break
                k += 1
            after = rest[k + 1:]
            if verb in GIT_WRITERS:
                if verb in ("branch", "tag", "stash", "worktree", "remote", "notes"):
                    if not after or set(after) & GIT_READS:
                        continue
                return True
    return False


def paths_named(tokens, cwd):
    """The places a command names: every token with a slash in it (a
    redirection's target, a VAR=path, --opt=path too), made absolute from CWD."""
    out = []
    for tok in tokens:
        t = re.sub(r"^\d*>>?|^&>>?", "", tok)
        if "=" in t and not t.startswith(("/", "~", ".")):
            t = t.split("=", 1)[1]
        t = os.path.expanduser(t)
        if "/" not in t or t.startswith("-") or t.startswith("http"):
            continue
        out.append(os.path.normpath(t if os.path.isabs(t) else os.path.join(cwd or os.getcwd(), t)))
    # The places that are there first: a sed pattern (s/a/b/) names nothing, a file to make may.
    return sorted(out, key=lambda p: not os.path.exists(p))


def refuse(me, path, why, how):
    record("refused", f"{who(me)} was refused {short(path)}: {how}",
           {"agent": me["agent"], "pid": me["pid"], "folder": me["folder"], "file": path, "how": how},
           key=f"{me['pid']}:{path}")
    hook_output(permissionDecision="deny", permissionDecisionReason=why)


def touch_bash(command, cwd):
    """The rule for a Bash command: refused when it would write into a
    repository it may not change. Only the places it names are looked at,
    and its folder when it names none."""
    me = my_agent()
    if not me or not command.strip():
        return 0
    if pause_hold(me, tell=False):
        return 0
    try:
        tokens = shlex.split(command)
    except ValueError:
        tokens = command.split()
    # A semicolon stays glued to its word ('x; y'): a token of its own here.
    tokens = [t for tok in tokens for t in re.split(r"(;)", tok) if t]
    if not writes(tokens):
        return 0
    named = [p for p in paths_named(tokens, cwd) if repo_of(p)[0]]
    seen = set()
    for p in named or ([cwd] if cwd else []):
        top = repo_of(p)[0]
        if top in seen:
            continue
        seen.add(top)
        why = off_desk(me, p)
        if why:
            refuse(me, p, why + " (This command would write there.)", "a Bash command, off a desk")
            return 0
    if named:
        # Noted for the Stop hook (a worker that only used sed -i changed files too); the
        # clash and protection counts read edits and crossings alone.
        journal_add({"at": int(time.time()), "kind": "shell", "agent": me["agent"], "pid": me["pid"],
                     "folder": me["folder"], "file": named[0]})
    return 0


def touch(argv):
    global HOOK
    if "--for" in argv:         # whose hook runs this: codex, opencode, gemini (claude without)
        i = argv.index("--for")
        HOOK = argv[i + 1] if len(argv) > i + 1 else "claude"
        argv = argv[:i] + argv[i + 2:]
    if "--pause-only" in argv:
        # Before every tool (office.json's second entry): the pause alone, one stat when there
        # is none; lifted, the words that it was go with this call (RESUMED, in the front).
        pause_hold(my_agent())
        return 0
    path = argv[0] if argv and not argv[0].startswith("-") else ""
    if not path and not sys.stdin.isatty():
        try:
            got = json.loads(sys.stdin.read() or "{}")
            if isinstance(got.get("toolCall"), dict):
                # Antigravity CLI: the tool's name and args, and the workspaces.
                HOOK = "agy"
                call = got["toolCall"]
                args = call.get("args") or {}
                here = (got.get("workspacePaths") or [""])[0]
                note_session(got.get("conversationId"))     # what agy --conversation resumes
                if call.get("name") == "run_command":
                    return touch_bash(args.get("CommandLine") or "", args.get("Cwd") or here)
                path = args.get("TargetFile") or ""
                if path and not os.path.isabs(path) and here:
                    path = os.path.join(here, path)
            else:
                tool = got.get("tool_input") or {}
                path = tool.get("file_path") or tool.get("notebook_path") or ""
                note_session(got.get("session_id"))
                if not path and got.get("tool_name") == "Bash":
                    return touch_bash(tool.get("command") or "", got.get("cwd") or "")
        except ValueError:
            return 0
    if not path:
        return 0
    me = my_agent()
    if not me:
        return 0
    if pause_hold(me, tell=False):
        return 0
    path = os.path.realpath(os.path.abspath(path))
    why = off_desk(me, path)
    if why:
        refuse(me, path, why, "off a desk" if desk_of(me["folder"]) is None else "the project's own folder")
        return 0
    others = live_agents()
    entries = journal_read()
    now = int(time.time())
    crossing = crossing_for(me, path, others)
    clashes = clashes_for(me, path, others, entries)
    turn = ""
    if clashes and HOOK != "opencode" and turns_on(me["folder"]):
        clashes, turn = take_turn(me, path, clashes, now)
        entries = journal_read()
    if clashes and HOOK == "opencode":
        # OpenCode's plugin can only block or let through: a clash is refused
        # once, with the reason, and the same edit tried again within ten
        # minutes (the agent having told the user) goes through.
        asked = [e for e in entries if e.get("kind") == "asked" and e.get("pid") == me["pid"]
                 and e.get("file") == path and now - e.get("at", 0) < 600]
        if not asked:
            journal_add({"at": now, "kind": "asked", "agent": me["agent"], "pid": me["pid"], "folder": me["folder"],
                         "file": path, "clash": [who(o) for o, _ in clashes]})
            said = "; ".join(f"{who(o)} ({short(o['folder'])}) {how}" for o, how in clashes)
            hook_output(permissionDecision="ask",
                        permissionDecisionReason=f"Vikix office: another agent is on this file. {said}. "
                                                 f"`vikix agents clash {short(path)}` shows both changes. Tell the user; "
                                                 "if they want this edit too, the same edit within ten minutes goes through.")
            return 0
        clashes = []
    entry = {"at": now, "kind": "crossing" if crossing else "edit", "agent": me["agent"], "pid": me["pid"],
             "folder": me["folder"], "file": path}
    if crossing:
        entry["with"] = who(crossing)
        record("crossing", f"{who(me)} edited {short(path)}, in {who(crossing)}'s folder",
               {"agent": me["agent"], "pid": me["pid"], "folder": me["folder"], "file": path,
                "other": crossing["agent"], "other_pid": crossing["pid"], "other_folder": crossing["folder"]},
               key=f"{me['pid']}:{path}")
    if clashes:
        entry["clash"] = [who(o) for o, _ in clashes]
        record("clash", f"{who(me)} and {', '.join(who(o) for o, _ in clashes)} on {short(path)}",
               {"agent": me["agent"], "pid": me["pid"], "file": path,
                "with": [{"agent": o["agent"], "pid": o["pid"], "folder": o["folder"], "how": how} for o, how in clashes]},
               key=f"{me['pid']}:{path}")
    journal_add(entry)
    if clashes:
        said = "; ".join(f"{who(o)} ({short(o['folder'])}) {how}" for o, how in clashes)
        hook_output(permissionDecision="ask",
                    permissionDecisionReason=f"Vikix office: another agent is on this file. {said}. "
                                             + (f"Turns: {turn}. " if turn else "")
                                             + f"`vikix agents clash {short(path)}` shows both changes. Let this one edit it too?")
    elif turn:
        hook_output(additionalContext=turn)
    elif crossing:
        hook_output(additionalContext=f"Vikix office: {short(path)} is in {short(crossing['folder'])}, the folder "
                                      f"{who(crossing)} works in, not yours ({short(me['folder'])}). The crossing is "
                                      "recorded (vikix agents crossings). Edit it only if the user asked for that; "
                                      "else leave it to that agent and tell the user.")
    return 0


def all_clashes(agents):
    """Among AGENTS, the files two or more are on: {file: [(agent, how,
    path)]}. What a worktree has changed, uncommitted, is its agent's when
    it is the only agent there (with two in one copy, git can't say whose,
    and the journal does); what the journal says an agent edited is its."""
    by_pid = {a["pid"]: a for a in agents}
    tops = {}
    for a in agents:
        if a.get("folder") and os.path.isdir(a["folder"]):
            top, common, _ = repo_of(a["folder"])
            if top:
                tops.setdefault((os.path.realpath(top), common), []).append(a)
    on = {}
    for (top, common), there in tops.items():
        if len(there) != 1:
            continue
        a = there[0]
        status = git(top, "status", "--porcelain", "--untracked-files=all") or ""
        for line in status.splitlines():
            rel = line[3:].split(" -> ")[-1].strip().strip('"')
            on.setdefault((common, rel), {})[a["pid"]] = (a, f"changed in {short(top)}", os.path.join(top, rel))
    for e in journal_read():
        if e.get("pid") in by_pid and e.get("kind") in ("edit", "crossing") and e.get("file"):
            top, common, rel = repo_of(e["file"])
            key = (common, rel) if top else (None, e["file"])
            on.setdefault(key, {}).setdefault(e["pid"], (by_pid[e["pid"]], "edited it", e["file"]))
    found = {}
    for (common, rel), by in on.items():
        if len(by) > 1:
            found[rel if common else short(rel)] = sorted(by.values(), key=lambda row: row[0]["pid"])
    return found


def clash(argv):
    agents = live_agents()
    found = all_clashes(agents)
    if argv:
        want = os.path.realpath(os.path.abspath(argv[0]))
        hits = [(a, how, p) for rows in found.values() for a, how, p in rows
                if os.path.realpath(p) == want or (os.path.exists(want) and os.path.basename(p) == os.path.basename(want)
                                                   and repo_of(p)[2] == repo_of(want)[2])]
        if not hits:
            print(f"No two agents are on {short(want)}.")
            return 0
        print(f"{short(want)}: {len(hits)} agents on it. Each one's change, uncommitted:")
        for a, how, p in hits:
            top, _, rel = repo_of(p)
            print(f"\n== {who(a)}, {how} ==")
            if top:
                status = changed_in(top, rel)
                diff = (git(top, "diff", "HEAD", "--", rel) or "").rstrip()
                if status.startswith("??"):
                    try:
                        lines = open(p, errors="replace").read().splitlines()
                    except OSError:
                        lines = []
                    print(f"new file, {len(lines)} lines:")
                    print("\n".join("  " + l for l in lines[:40]))
                elif diff:
                    print(diff)
                else:
                    print("(no change in the worktree: the edit is still to come)")
            else:
                print("(not in a repository: no diff to show)")
        print("\nWhich stays is yours to say: tell the other agent to drop its change, "
              "or let both go in and settle the merge.")
        return 0
    if not found:
        print("No two agents are on one file." + ("" if agents else " No agent is running."))
        return 0
    print(f"{len(found)} file{'s' if len(found) != 1 else ''} with two agents on it:")
    for rel, rows in found.items():
        print(f"  {rel}")
        for a, how, _ in rows:
            print(f"      {who(a):<14} {short(a['folder'])}: {how}")
    print("vikix agents clash FILE shows each one's change.")
    return 0


def window_crossing(me, other, what):
    """An agent went to another agent's window (the MCP server calls this):
    recorded, never refused."""
    journal_add({"at": int(time.time()), "kind": "window", "agent": me["agent"], "pid": me["pid"],
                 "folder": me["folder"], "file": "", "with": who(other), "what": what})
    record("crossing", f"{who(me)} went to {who(other)}'s {what}",
           {"agent": me["agent"], "pid": me["pid"], "other": other["agent"], "other_pid": other["pid"], "window": what},
           key=f"{me['pid']}:{what}")
