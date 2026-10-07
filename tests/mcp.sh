#!/usr/bin/env bash
# tests/mcp.sh — vikix-mcp, the desktop as an MCP server.
#
#   it answers initialize (the client's protocol version, or its own), ping,
#   tools/list, tools/call, and no-method and not-JSON errors; notifications
#   get no answer; the read-only tools read the window manager through fixed
#   forms (the desktop, the keys, the rules and why a window is where it
#   is); eval and undo exist only when switched on; what an agent sends
#   is checked against the desktop (a workspace that exists, a theme there
#   is, a number) and never reaches Lisp or a shell otherwise; every call
#   is logged; register adds it to Claude Code with the flags asked for
#
# The window manager (vikix-eval), notify-send and claude are stand-ins.
# So the forms the tools send are also compiled against the real StumpWM,
# from Quicklisp, when it's there: a stand-in answers anything, and 0.54.1
# shipped a focus_window that the real one refused (a group given to
# gselect, a command that takes its argument as typed text).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}/setup.lisp   # before HOME moves
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$HOME" "$t/bin"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
cd "$t"

# The window manager: every form is logged; the desktop and the keys come
# back as vikix-eval prints a Lisp string (\" and \\ escaped).
cat > "$t/bin/eval" <<'EOF'
#!/usr/bin/env python3
import sys, os, json
form = sys.argv[1]
t = os.environ["T"]
open(t + "/forms", "a").write(form.replace("\n", " ") + "\n")
# Whole, too, one file each, for compiling against the real StumpWM below.
d = t + "/forms.d"
os.makedirs(d, exist_ok=True)
open("%s/%03d.lisp" % (d, len(os.listdir(d))), "w").write(form)
def lisp(s): return '=> "' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
if "workspaces" in form:
    print("=> a title printed first, with => in it")
    print(lisp(json.dumps({"workspaces": [
        {"name": "1", "number": 1, "current": True, "windows": [
            {"number": 0, "title": 'a "quoted" \\ title => not the end', "class": "Alacritty", "focused": True}]},
        {"name": "web", "number": 2, "current": False, "windows": []}],
        "screens": [{"number": 0, "x": 0, "y": 0, "width": 1920, "height": 1080}]})))
elif "vikix-rules-list" in form:
    if os.path.exists(t + "/old-desktop"):   # one started before it could list its rules
        print(lisp("null"))
    else:
        why = None
        if "(find 0 (group-windows g)" in form:
            why = {"window": 'Alacritty "a title" (workspace 1, window 0)',
                   "ran": [{"at": "09:14", "on": "open", "rule": 1, "text": '(when-window (:class "Alacritty") (title "t"))', "failed": None}],
                   "match_but_have_not_run": []}
        print(lisp(json.dumps({"rules": [
            {"number": 1, "on": True, "off": None, "rule": '(when-window (:class "Alacritty") (title "t"))', "name": None,
             "from": "rules.lisp:2", "runs_on": "open", "runs": 3, "last_run": "09:14", "last_error": None}],
            "why": why})))
elif "vikix-agent-commands" in form:
    if os.path.exists(t + "/old-desktop"):   # one started before the registry
        print(lisp("null"))
    else:
        print(lisp(json.dumps([{"name": "quiet", "does": "Do not disturb on/off", "key": "Super+Ctrl+d"},
                               {"name": "tray", "does": "Tray on/off", "key": None}])))
elif "vikix-agents-tsv" in form:
    # As agents.lisp prints them: a line an agent, tab-separated (and a title with the user's text in it).
    print("\t".join(["claude", str(os.getpid()), t, "2", "0", "125", "asks", "waits for your yes", "May I run it?", "a title => not the end"]))
    print("=> NIL")
elif "vikix-why-entries" in form:
    if os.path.exists(t + "/old-desktop"):
        print(lisp("null"))
    else:
        print(lisp(json.dumps(['21:04:10  Super+Ctrl+d ran vikix-quiet (Do not disturb on/off)  ·  Vikix\'s key: registry.lisp, line 83',
                               '21:03:59  A rule, as a window opened ran (when-window (:class "Firefox") (workspace 2))  ·  rules.lisp:3, for Firefox "a \\ title"'])))
elif "vikix-agent-run" in form:
    # As registry.lisp answers: done for one marked for agents, refused otherwise.
    if '"quiet"' in form:
        print(lisp("done: quiet (Do not disturb on/off)"))
    elif '"terminal"' in form:
        print(lisp("refused: terminal (Terminal) is not for agents to run; the user has it on Super+Return"))
    else:
        print(lisp("refused: there is no command called that (the commands tool lists them)"))
elif "(+ 1 2)" in form:
    print("=> 3")
elif "(car nil nil)" in form:
    print("error: invalid number of arguments")
elif "*vikix-bindings*" in form:
    print(lisp(json.dumps([{"key": "s-RET", "command": "vikix-terminal", "does": "Terminal"}])))
else:
    print("=> T")
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$t/notified"
echo "DISPLAY=\$DISPLAY" >> "$t/notified"
EOF
# esploro: keeps the plan it was given, and answers as the core would;
# $t/refuse makes it refuse.
cat > "$t/bin/esploro" <<EOF
#!/bin/sh
if [ "\$1" = changes ]; then
  [ "\$2" = --lines ] && printf '2026-10-04 06:15:41  duplicated "bin" in ~/vikix\n    copy ~/vikix/bin to ~/vikix/bin copy\n' && echo "limit \$3" > "$t/changes.limit"
  exit 0
fi
[ "\$1" = propose ] || exit 2
cp "\$2" "$t/proposed.lisp"; echo "\$3" > "$t/proposed.why"
if [ -e "$t/refuse" ]; then echo '(:refused ("step 1: /no/such is not there"))'; exit 1; fi
echo "(:proposed \$(grep -c . "\$2"))"
EOF
chmod +x "$t/bin/esploro"
cat > "$t/bin/claude" <<EOF
#!/bin/sh
echo "claude \$*" >> "$t/claude.calls"
EOF
# Antigravity CLI's agy: mcp add, remove and list, remembered in a file.
cat > "$t/bin/agy" <<EOF
#!/bin/sh
echo "agy \$*" >> "$t/agy.calls"
case "\$1 \$2" in
  "mcp add")    : > "$t/agy.has" ;;
  "mcp remove") rm -f "$t/agy.has" ;;
  "mcp list")   printf 'NAME   TYPE   STATUS   COMMAND/URL\n'; [ -e "$t/agy.has" ] && echo 'vikix  stdio  enabled  vikix-mcp serve --allow-eval' ;;
esac
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_EVAL="$t/bin/eval" VIKIX_CLAUDE="$t/bin/claude" VIKIX_AGY="$t/bin/agy" T="$t"

# rpc [FLAGS] -- one request (a JSON line) per argument; the answers, a line each.
rpc() {
  local flags=()
  while [ "$1" != -- ]; do flags+=("$1"); shift; done; shift
  printf '%s\n' "$@" | python3 "$here/bin/vikix-mcp" "${flags[@]}"
}
call() {   # call NAME ARGS-JSON [FLAGS...] — the text a tool answered; isError as "ERROR: " before it
  local name=$1 args=$2; shift 2
  rpc "$@" -- "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$name\",\"arguments\":$args}}" |
    python3 -c 'import json,sys; r=json.loads(sys.stdin.readline())["result"]; print(("ERROR: " if r["isError"] else "") + r["content"][0]["text"])'
}
field() { python3 -c "import json,sys; print(json.loads(sys.stdin.readline())$1)"; }

# The protocol.
out=$(rpc -- '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}')
check "initialize should answer the client's version: $out" test "$(field '["result"]["protocolVersion"]' <<<"$out")" = 2025-06-18
check "initialize should say it has tools, which can change" test "$(field '["result"]["capabilities"]["tools"]["listChanged"]' <<<"$out")" = True
out=$(rpc -- '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}')
check "an unknown version should get the server's newest: $out" test "$(field '["result"]["protocolVersion"]' <<<"$out")" = 2025-11-25
out=$(rpc -- '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":7,"method":"ping"}')
check "a notification should get no answer, a ping one: $out" test "$(wc -l <<<"$out")" = 1 -a "$(field '["id"]' <<<"$out")" = 7
out=$(rpc -- '{"jsonrpc":"2.0","id":2,"method":"no/such"}')
check "an unknown method should be -32601: $out" test "$(field '["error"]["code"]' <<<"$out")" = -32601
out=$(rpc -- 'not json at all')
check "not JSON should be -32700: $out" test "$(field '["error"]["code"]' <<<"$out")" = -32700

# The tools: eval and undo only when switched on.
names() { rpc "$@" -- '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c 'import json,sys; print(" ".join(t["name"] for t in json.loads(sys.stdin.readline())["result"]["tools"]))'; }
list=$(names)
check "the read-only tools should be there: $list" grep -q 'desktop keys commands why agents office handoff doctor history changes themes version rules' <<<"$list"
check "eval shouldn't be there by default: $list" test -z "$(grep -ow 'eval\|undo' <<<"$list" || true)"
check "--allow-eval should add eval: $(names --allow-eval)" grep -qw eval <<<"$(names --allow-eval)"
check "--allow-undo should add undo: $(names --allow-undo)" grep -qw undo <<<"$(names --allow-undo)"
out=$(call eval '{"form":"(run-shell-command \"touch pwned\")"}')
check "eval without --allow-eval should be refused: $out" grep -q '^ERROR: no tool' <<<"$out"
check "a refused eval ran something" test ! -e "$t/forms"
ro=$(rpc -- '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c 'import json,sys; print(" ".join(t["name"] for t in json.loads(sys.stdin.readline())["result"]["tools"] if t["annotations"]["readOnlyHint"]))')
check "the read tools should say they only read: $ro" test "$ro" = "desktop keys commands why agents office handoff doctor history changes themes version rules records_search records_get docs_search docs_read file_changes"

# Reading the desktop.
out=$(call desktop '{}')
check "desktop should give the workspaces: $out" grep -q '"name": "web"' <<<"$out"
check "a title with quotes and a backslash should come through whole: $out" grep -qF 'a \"quoted\" \\ title' <<<"$out"
check "desktop should give the theme" grep -q '"theme": "void"' <<<"$out"
out=$(call keys '{}')
check "keys should give the bindings: $out" grep -q 's-RET' <<<"$out"
out=$(call themes '{}')
check "themes should list them: $out" grep -q '"paper"' <<<"$out"
# The rules: the list alone, or with why for a window that is there.
out=$(call rules '{}')
check "rules should give the list: $out" grep -q '"from": "rules.lisp:2"' <<<"$out"
check "rules without a window shouldn't have a why: $out" bash -c "! grep -q '\"why\"' <<<'$out'"
: > "$t/forms"
out=$(call rules '{"workspace":"x\") (run-shell-command \"touch pwned","number":0}')
check "rules for a workspace that isn't there should be refused: $out" grep -q '^ERROR: no workspace' <<<"$out"
check "a refused workspace shouldn't reach Lisp: $(cat "$t/forms")" test -z "$(grep -v 'workspaces' "$t/forms" || true)"
out=$(call rules '{"workspace":"1"}')
check "rules for a window without its number should be refused: $out" grep -q '^ERROR: number' <<<"$out"
out=$(call rules '{"workspace":"1","number":5}')
check "rules for a window that isn't there should be refused: $out" grep -q '^ERROR: workspace 1 has no window 5' <<<"$out"
out=$(call rules '{"workspace":"1","number":0}')
check "rules for a window should say what ran for it: $out" grep -q '"at": "09:14"' <<<"$out"
check "the window should be found by its workspace's name, as a Lisp string, and its number: $(tail -1 "$t/forms" | cut -c1-80)" \
  grep -qF '(find-group (current-screen) "1"))) (and g (find 0 (group-windows g) :key' "$t/forms"
touch "$t/old-desktop"
out=$(call rules '{}')
check "a desktop started before the rules tool should say to reload: $out" grep -q '^ERROR: .*reload it' <<<"$out"
rm -f "$t/old-desktop"

# The desktop's commands (registry.lisp): the ones marked for agents listed,
# one run by name, any other refused by the desktop, a name out of shape
# never sent.
out=$(call commands '{}')
check "commands should list what an agent may run, with what each does and its key: $out" \
  grep -q '"name": "quiet"' <<<"$out"
check "a command without a key says so" grep -q '"key": null' <<<"$out"
out=$(call run_command '{"name":"quiet"}')
check "run_command should run one marked for agents: $out" grep -q '^done: quiet' <<<"$out"
check "by its name, as a Lisp string: $(tail -1 "$t/forms")" grep -q "(funcall 'vikix-agent-run \"quiet\")" "$t/forms"
out=$(call run_command '{"name":"terminal"}')
check "one not for agents should be refused, in the desktop's words: $out" grep -q '^ERROR: refused: terminal (Terminal) is not for agents' <<<"$out"
: > "$t/forms"
out=$(call run_command '{"name":"quiet\") (run-shell-command \"touch pwned"}')
check "a name that isn't a command's shape should be refused: $out" grep -q '^ERROR: name' <<<"$out"
check "and never reach Lisp: $(cat "$t/forms")" test ! -s "$t/forms"
# The Office reuses the shared snapshot, including retained desks.
mkdir -p "$t/proc"; echo "5000.00 1.00" > "$t/proc/uptime"
out=$(VIKIX_PROC=$t/proc call office '{}')
check "Office exposes discovery certainty: $out" grep -q '"live_known": true' <<<"$out"
check "Office exposes desk rows: $out" grep -q '"desks":' <<<"$out"

# A desk's handoff: the record read and written through the office's own code, signed by the caller.
mkdir -p "$t/src" "$t/proc" "$HOME/.config/vikix"; echo "5000.00 1.00" > "$t/proc/uptime"; printf 'root=%s\n' "$t/src" > "$HOME/.config/vikix/projects"
git -C "$t/src" init -q -b main book; git -C "$t/src/book" config user.name T; git -C "$t/src/book" config user.email t@example.com
echo '# Log' > "$t/src/book/log.md"; git -C "$t/src/book" add log.md; git -C "$t/src/book" commit -q -m first
git -C "$t/src/book" worktree add -q "$t/src/book-a" -b a
mkdir -p "$t/proc/1001"; printf 'claude\0--x\0' > "$t/proc/1001/cmdline"; ln -sfn "$t/src/book-a" "$t/proc/1001/cwd"
printf '1001 (claude) S 1 1001 1 34816 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100000 0 0\n' > "$t/proc/1001/stat"
out=$(VIKIX_PROC=$t/proc VIKIX_AGENT_PID=1001 call handoff '{}')
check "handoff without a record says how one starts: $out" grep -q '"record": null' <<<"$out"
out=$(VIKIX_PROC=$t/proc VIKIX_AGENT_PID=1001 call handoff_update '{"status":"working","summary":"read the log","next":"fix ch1","check":{"name":"spell","ok":true}}')
check "handoff_update writes the caller's handoff on its desk, signed: $out" grep -q '^handoff of .*/book-a updated by claude 1001: status working; check, next, status, summary set' <<<"$out"
out=$(VIKIX_PROC=$t/proc VIKIX_AGENT_PID=1001 call handoff '{}')
check "handoff then reads it back, with the freshness and what holds the rules: $out" python3 -c '
import json, sys
r = json.loads(sys.argv[1])
assert r["handoff"]["status"]["value"] == "working" and r["handoff"]["status"]["by"] == "claude 1001", r["handoff"]
assert r["checks"][0]["freshness"] == "fresh" and r["now"]["commit"], r
assert r["at_the_desk"] == ["claude 1001"] and any("no filesystem enforcement" in p for p in r["protection"]), r' "$out"
out=$(VIKIX_PROC=$t/proc VIKIX_AGENT_PID=1001 call handoff_update '{"summary":"token sk-ant-abcdefghijklmnopqrstu"}')
check "a credential is refused: $out" grep -q '^ERROR: .*looks like it holds a credential' <<<"$out"
out=$(VIKIX_PROC=$t/proc VIKIX_AGENT_PID=1001 call handoff '{"desk":"nowhere"}')
check "a desk that isn't: $out" grep -q '^ERROR: no such desk here' <<<"$out"
out=$(VIKIX_PROC=$t/proc call handoff_update '{"task":"Fix chapter one","desk":"a"}')
check "from no agent the writer is the user, by the desk named: $out" grep -q 'updated by user: status working; task set' <<<"$out"
rm -rf "$t/proc" "$t/src"; rm -f "$HOME/.config/vikix/projects"
out=$(VIKIX_PROC=/nonexistent call agents '{}')
check "agents should list the agents at work, each with its folder and what it does: $out" \
  python3 -c '
import json, sys
a = json.loads(sys.argv[1])
assert len(a) == 1 and a[0]["agent"] == "claude" and a[0]["state"] == "asks" and a[0]["workspace"] == "2", a
assert a[0]["said"] == "May I run it?" and a[0]["seconds"] == 125 and "branch" in a[0], a
' "$out"
out=$(call why '{}')
check "why should say what the desktop did, a line each: $out" test "$(grep -c -e 'Super+Ctrl+d ran vikix-quiet' -e 'A rule, as a window opened' <<<"$out")" = 2
check "with how many asked for, a number: $(grep 'vikix-why-entries' "$t/forms" | tail -1 | cut -c1-60)" grep -q "(funcall 'vikix-why-entries 20)" "$t/forms"
out=$(call why '{"limit":"5) (run-shell-command \"touch pwned"}')
check "a limit that isn't a number should be refused: $out" grep -q '^ERROR: limit' <<<"$out"
touch "$t/old-desktop"
out=$(call why '{}')
check "a desktop older than why should say to update: $out" grep -q '^ERROR: .*vikix update' <<<"$out"
out=$(call commands '{}')
check "a desktop older than the registry should say to update: $out" grep -q '^ERROR: .*vikix update' <<<"$out"
rm -f "$t/old-desktop"

# Acting: checked against what's there.
: > "$t/forms"
out=$(call switch_workspace '{"name":"x\") (run-shell-command \"touch pwned"}')
check "a workspace that isn't there should be refused: $out" grep -q '^ERROR: no workspace' <<<"$out"
check "a refused workspace shouldn't reach Lisp: $(cat "$t/forms")" test -z "$(grep -v 'workspaces' "$t/forms" || true)"
out=$(call switch_workspace '{"name":"web"}')
check "an existing workspace should be shown: $out" grep -q 'on workspace web' <<<"$out"
check "it should be selected by name, as a Lisp string: $(tail -1 "$t/forms")" grep -q '(switch-to-group (find-group (current-screen) "web"))' "$t/forms"
out=$(call focus_window '{"workspace":"1","number":"0) (run-shell-command 1"}')
check "a number that isn't one should be refused: $out" grep -q '^ERROR: number' <<<"$out"
out=$(call focus_window '{"workspace":"1","number":true}')
check "true isn't a window number: $out" grep -q '^ERROR: number' <<<"$out"
out=$(call focus_window '{"workspace":"1","number":5}')
check "a window that isn't there should be refused: $out" grep -q '^ERROR: workspace 1 has no window 5' <<<"$out"
out=$(call focus_window '{"workspace":"1","number":0}')
check "an existing window should get the focus: $out" grep -q 'has the focus' <<<"$out"
out=$(call set_theme '{"name":"../../etc"}')
check "a theme that isn't there should be refused: $out" grep -q "^ERROR: no theme" <<<"$out"
out=$(call set_theme '{"name":"paper"}')
check "set_theme should switch, and say how to go back: $out" grep -q 'theme paper (it was void' <<<"$out"
out=$(call notify '{"title":"Hi","body":"a <b>bold</b> & more"}')
check "notify should show it: $out" test "$out" = shown
check "the notification should be marked as the agent's: $(head -2 "$t/notified")" grep -qx 'Vikix (agent)' "$t/notified"
check "its markup should be escaped" grep -qF 'a &lt;b>bold&lt;/b> &amp; more' "$t/notified"
# propose_file_changes: never done there, only proposed to Esploro.
out=$(call propose_file_changes '{"steps":[{"op":"mkdir","path":"/home/u/archive"},{"op":"move","path":"/home/u/a \"b\".txt","to":"/home/u/archive/a.txt"},{"op":"rename","path":"/home/u/c","to":"d"}],"why":"tidy up"}')
check "a plan should be proposed, nothing done: $out" grep -q '^proposed 3 steps: the user reviews them in Esploro' <<<"$out"
want=$(printf '%s\n' '(:mkdir "/home/u/archive")' '(:move "/home/u/a \"b\".txt" "/home/u/archive/a.txt")' '(:rename "/home/u/c" "d")')
check "the plan should reach esploro as Lisp steps, quotes kept: $(cat "$t/proposed.lisp")" test "$(cat "$t/proposed.lisp")" = "$want"
check "why should go with it" grep -qx 'tidy up' "$t/proposed.why"
out=$(call propose_file_changes '{"steps":[{"op":"delete","path":"/home/u/a"}]}')
check "an op that isn't a plan's should be refused here: $out" grep -q '^ERROR: step 1: op is one of' <<<"$out"
out=$(call propose_file_changes '{"steps":[{"op":"trash","path":"a.txt"}]}')
check "a relative path should be refused: $out" grep -q 'whole path' <<<"$out"
out=$(call propose_file_changes '{"steps":[{"op":"rename","path":"/home/u/a","to":"x/y"}]}')
check "a rename into another folder should be refused: $out" grep -q "rename's to is a name" <<<"$out"
out=$(call propose_file_changes '{"steps":[{"op":"tag","path":"/home/u/a.pdf","to":"tender,to read"},{"op":"tag","path":"/home/u/b.pdf","to":""}]}')
check "tags should be proposed as plan steps: $(cat "$t/proposed.lisp")" test "$(cat "$t/proposed.lisp")" = '(:tag "/home/u/a.pdf" "tender,to read")
(:tag "/home/u/b.pdf" "")'
out=$(call propose_file_changes '{"steps":[{"op":"tag","path":"/home/u/a.pdf"}]}')
check "a tag step without its tags should be refused: $out" grep -q 'tag needs to' <<<"$out"
touch "$t/refuse"
out=$(call propose_file_changes '{"steps":[{"op":"trash","path":"/no/such"}]}')
check "a plan the core refuses should come back with why: $out" grep -q '^ERROR: not proposed, nothing changed' <<<"$out"
rm -f "$t/refuse"
mv "$t/bin/esploro" "$t/esploro.off"
out=$(PATH="$t/bin:/usr/bin:/bin" call propose_file_changes '{"steps":[{"op":"mkdir","path":"/home/u/x"}]}')
check "without Esploro it should say so: $out" grep -q "Esploro isn't installed" <<<"$out"
mv "$t/esploro.off" "$t/bin/esploro"
# file_changes: Esploro's journal in words, read only.
out=$(call file_changes '{"limit":5}')
check "file_changes should give the changes in words, steps below: $out" grep -q 'duplicated "bin" in ~/vikix' <<<"$out"
check "and ask Esploro for that many" grep -qx 'limit 5' "$t/changes.limit"
out=$(call file_changes '{"limit":0}')
check "a limit out of range should be refused: $out" grep -q '^ERROR: limit is 1 to 200' <<<"$out"
# The user's sorting rules go with propose_file_changes, to every agent.
described() { rpc -- '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c 'import json,sys; print(next(t["description"] for t in json.loads(sys.stdin.readline())["result"]["tools"] if t["name"] == "propose_file_changes"))'; }
out=$(described)
check "without rules it should say where they'd go: $out" grep -qF "$HOME/.config/esploro/sorting.md: when they correct a plan" <<<"$out"
mkdir -p "$HOME/.config/esploro"
printf '# Where my files go\n\n- A work zip goes in Work, not in Archives.\n' >"$HOME/.config/esploro/sorting.md"
out=$(described)
check "the rules should be in the description: $out" grep -qF -- "- A work zip goes in Work, not in Archives." <<<"$out"
check "and said to be followed: $out" grep -qF "follow the user's rules for where their files go" <<<"$out"
head -c 6000 /dev/zero | tr '\0' x >>"$HOME/.config/esploro/sorting.md"
out=$(described)
check "long rules should be cut, and say so: ${#out}" grep -qF "[cut short: read the whole file]" <<<"$out"
rm -r "$HOME/.config/esploro"

out=$(call notify '{"body":"no title"}')
check "notify without a title should say so: $out" grep -q '^ERROR: notify needs a title' <<<"$out"
out=$(call snapshot '{"message":"before $(touch pwned2); x"}')
check "a snapshot's message shouldn't run anything" test ! -e "$t/pwned2"
out=$(call changes '{"snapshot":"HEAD; rm -rf ~"}')
check "changes with a bad id should be refused: $out" grep -q '^ERROR: snapshot' <<<"$out"

# With eval switched on, it runs; undo checks its id too.
out=$(call eval '{"form":"(+ 1 2)"}' --allow-eval)
check "eval, switched on, should run the form: $out" grep -q '(+ 1 2)' "$t/forms"
out=$(call undo '{"snapshot":"x y"}' --allow-undo)
check "undo with a bad id should be refused: $out" grep -q '^ERROR: snapshot' <<<"$out"

# Malformed input: an error answer, and the server lives on (a ping after).
alive() { rpc -- "$1" '{"jsonrpc":"2.0","id":99,"method":"ping"}' | tail -1 | field '["id"]'; }
check "params as a list shouldn't stop it" test "$(alive '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":[1]}')" = 99
check "a list as the tool's name shouldn't stop it" test "$(alive '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":["x"]}}')" = 99
check "a lone surrogate in an argument shouldn't stop it" test "$(alive '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notify","arguments":{"title":"\ud800"}}}')" = 99
deep=$(python3 -c 'print("["*100000 + "]"*100000)')
check "deep nesting shouldn't stop it" test "$(alive "$deep")" = 99
out=$(printf '\xff\xfe{bad}\n{"jsonrpc":"2.0","id":99,"method":"ping"}\n' | python3 "$here/bin/vikix-mcp" serve | tail -1)
check "bytes that aren't UTF-8 shouldn't stop it: $out" test "$(field '["id"]' <<<"$out")" = 99
out=$(rpc -- '[{"jsonrpc":"2.0","id":1,"method":"ping"}]')
check "a batch should get -32600: $out" test "$(field '["error"]["code"]' <<<"$out")" = -32600

# Answers that aren't what they seem, and failures that are failures.
out=$(call desktop '{}')
check "a title with => in it shouldn't cut the answer short: $out" grep -qF 'not the end' <<<"$out"
out=$(call changes '{"snapshot":"abcdef1"}')
check "changes for a snapshot that isn't there should be an error: $out" grep -q '^ERROR' <<<"$out"
out=$(call eval '{"form":"(car nil nil)"}' --allow-eval)
check "a Lisp error should be an error: $out" grep -q '^ERROR: error:' <<<"$out"
out=$(call notify '{"title":"Hi <there>"}')
check "the title should start Agent:, escaped: $(head -4 "$t/notified")" grep -qx 'Agent: Hi &lt;there>' "$t/notified"
mkdir -p "$VIKIX_STATE"; printf 'DISPLAY=:7\nDBUS_SESSION_BUS_ADDRESS=unix:path=/x\nXDG_RUNTIME_DIR=/run/user/1\n' > "$VIKIX_STATE/session.env"
call notify '{"title":"x"}' >/dev/null
check "without DISPLAY, it should take the session's: $(tail -1 "$t/notified")" grep -qx 'DISPLAY=:7' "$t/notified"
mkdir -p "$HOME/.config/vikix/themes"; cp "$here/themes/void.theme" "$HOME/.config/vikix/themes/x) (run-shell-command \"touch pwned\") (list.theme"
out=$(call themes '{}')
check "a theme file named like Lisp shouldn't be offered: $out" test -z "$(grep -F 'pwned' <<<"$out" || true)"
out=$(call set_theme '{"name":"x) (run-shell-command \"touch pwned\") (list"}')
check "a theme named like Lisp should be refused: $out" grep -q '^ERROR: no theme' <<<"$out"

# At a terminal, on its own, it shows its help rather than wait; a wrong flag is refused.
out=$(timeout 10 script -qec "python3 '$here/bin/vikix-mcp'" /dev/null </dev/null 2>&1) || true
check "vikix mcp at a terminal should show its help: ${out:0:80}" grep -q 'register' <<<"$out"
python3 "$here/bin/vikix-mcp" register --allow-evl >/dev/null 2>&1 && { echo "FAIL: a misspelt flag was taken"; fail=1; }

# The log.
out=$(call eval '{"form":"(+ 1 1)"}')
check "a refused call should be logged: $(tail -1 "$VIKIX_STATE/mcp.log")" grep -q ' refused eval ' "$VIKIX_STATE/mcp.log"
check "the log should be yours alone, is $(stat -c %a "$VIKIX_STATE/mcp.log")" test "$(stat -c %a "$VIKIX_STATE/mcp.log")" = 600
check "calls should be logged, with how they went: $(tail -2 "$VIKIX_STATE/mcp.log" 2>/dev/null)" grep -q ' ok set_theme {"name": "paper"}' "$VIKIX_STATE/mcp.log"

# The forms, against the real StumpWM: each compiles without a warning
# (an unknown function, a wrong number of arguments), and calls no
# command (a command's arguments are typed text, not Lisp values).
if command -v sbcl >/dev/null && [ -f "$ql" ]; then
  rm -rf "$t/forms.d"
  call desktop '{}' >/dev/null
  call keys '{}' >/dev/null
  call switch_workspace '{"name":"web"}' >/dev/null
  call focus_window '{"workspace":"1","number":0}' >/dev/null
  call rules '{"workspace":"1","number":0}' >/dev/null
  set +e
  out=$(FORMS="$t/forms.d/" sbcl --noinform --no-sysinit --no-userinit --non-interactive --load "$ql" \
    --eval '(handler-case (ql:quickload :stumpwm :silent t) (error () (sb-ext:exit :code 2)))' \
    --eval '
(let ((failed 0))
  (dolist (file (directory (concatenate (quote string) (sb-ext:posix-getenv "FORMS") "*.lisp")))
      (let* ((*package* (find-package :stumpwm))
             (form (with-open-file (in file) (read in)))
             (line (substitute #\Space #\Newline (string-trim " " (with-open-file (in file) (read-line in)))))
             (problems (list)))
        (labels ((walk (x)
                   (when (consp x)
                     (when (and (car x) (symbolp (car x)) (stumpwm::get-command-structure (car x) nil))
                       (push (format nil "calls the command ~(~a~); call a function" (car x)) problems))
                     (loop for y on x do (walk (car y))))))
          (walk form))
        ;; *vikix-bindings* is from the Vikix layer, not StumpWM.
        (handler-bind ((warning (lambda (w)
                                  (let ((s (remove #\Newline (princ-to-string w))))
                                    (unless (search "*VIKIX-" s) (push s problems)))
                                  (muffle-warning w))))
          (with-compilation-unit () (compile nil (list (quote lambda) nil form))))
        (when problems
          (incf failed)
          (format t "~a...: ~{~a~^; ~}~%" (subseq line 0 (min 60 (length line))) problems))))
  (sb-ext:exit :code (if (zerop failed) 0 1)))' 2>&1)
  rc=$?
  set -e
  case $rc in
    0) ;;
    2) echo "mcp: StumpWM isn't in Quicklisp here; its forms weren't compiled" ;;
    *) echo "FAIL: a form the tools send doesn't fit the real StumpWM:"; grep -v -e "^;" -e "^$" <<<"$out" | head -12; fail=1 ;;
  esac
else
  echo "mcp: no sbcl or Quicklisp; the forms weren't compiled against StumpWM"
fi

# Staying current: an update changes the server's files while an agent
# holds it. The next request is answered by the new code, in the same
# process, with nothing lost; new code that doesn't compile is left alone.
mkdir -p "$t/co/bin" "$t/co/lib"
cp "$here/bin/vikix-mcp" "$t/co/bin/"; cp "$here/lib/debug-report.py" "$t/co/lib/"; echo 1.0.0 > "$t/co/VERSION"
out=$(python3 - "$t/co" "$here/bin/vikix-mcp" <<'PY' 2>&1
import json, os, subprocess, sys, time
co = sys.argv[1]
p = subprocess.Popen([sys.executable, co + "/bin/vikix-mcp", "serve"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
def req(i):
    return json.dumps({"jsonrpc": "2.0", "id": i, "method": "tools/call", "params": {"name": "version", "arguments": {}}}) + "\n"
def version_answer():
    while True:
        m = json.loads(p.stdout.readline())
        if "id" in m:
            return m["result"]["content"][0]["text"], seen
        seen.append(m["method"])
def settle(path):
    t = time.time() - 10
    os.utime(path, (t, t))
def status(server=co + "/bin/vikix-mcp"):
    out = subprocess.run([sys.executable, server, "status"], capture_output=True, text=True).stdout
    return next(l for l in out.splitlines() if "running" in l)     # after the agents' lines
seen = []
p.stdin.write(req(1).encode()); p.stdin.flush()
print("before", version_answer()[0])
print("status1", status())
with open(co + "/VERSION", "w") as f: f.write("2.0.0\n")
settle(co + "/VERSION")
print("status2", status())
time.sleep(0.2)
p.stdin.write((req(2) + req(3)).encode()); p.stdin.flush()      # two at once: neither lost
print("after", version_answer()[0], version_answer()[0], ",".join(seen))
print("status3", status())
with open(co + "/bin/vikix-mcp", "a") as f: f.write("\ndef broken(:\n")
with open(co + "/VERSION", "w") as f: f.write("3.0.0\n")
settle(co + "/bin/vikix-mcp"); settle(co + "/VERSION")
p.stdin.write(req(4).encode()); p.stdin.flush()
seen.clear()
print("broken", version_answer()[0], ",".join(seen) or "no-restart")
p.stdin.close(); p.wait(5)
print("status4", status(sys.argv[2]))      # this copy is broken by now: the checkout's
PY
)
check "an unchanged server should answer as itself: $out" grep -qx "before 1.0.0" <<<"$out"
check "after an update the new code should answer both requests, and say the tools changed: $out" \
  grep -qx "after 2.0.0 2.0.0 notifications/tools/list_changed" <<<"$out"
check "new code that doesn't compile should be left alone: $out" grep -qx "broken 3.0.0 no-restart" <<<"$out"
check "the restart should be logged" grep -q "ok restart.*2.0.0" "$VIKIX_STATE/mcp.log"
check "status should show a running server and its version: $out" grep -q "^status1 1 running .*all on 1.0.0" <<<"$out"
check "after an update, one still on the old version until its next call: $out" \
  grep -q "^status2 1 running .*0 on 2.0.0, 1 on an older one: 1.0.0 since .*; those run 2.0.0 from their next call" <<<"$out"
check "and after that call, on the new one: $out" grep -q "^status3 1 running .*all on 2.0.0" <<<"$out"
check "a server that ended shouldn't be listed: $out" grep -q "^status4 None running" <<<"$out"
check "the refused restart should be logged" grep -q "refused restart" "$VIKIX_STATE/mcp.log"

# Registering with Claude Code.
python3 "$here/bin/vikix-mcp" register --allow-eval >/dev/null
check "register should add it to Claude Code, for you, with the flags: $(cat "$t/claude.calls")" \
  grep -qE '^claude mcp add --scope user vikix -- .*vikix-mcp serve --allow-eval$' "$t/claude.calls"
check "and to Antigravity CLI, through agy mcp add, the command after --: $(cat "$t/agy.calls")" \
  grep -qE '^agy mcp add vikix -- .*vikix-mcp serve --allow-eval$' "$t/agy.calls"
out=$(python3 "$here/bin/vikix-mcp" status 2>&1)
check "status should say Antigravity CLI has it: $out" grep -q '^Antigravity CLI has it$' <<<"$out"
python3 "$here/bin/vikix-mcp" unregister >/dev/null
check "unregister should take it out of Antigravity CLI too: $(tail -1 "$t/agy.calls")" grep -q '^agy mcp remove vikix$' "$t/agy.calls"
out=$(python3 "$here/bin/vikix-mcp" status 2>&1)
check "and status say so: $out" grep -q "^Antigravity CLI doesn't have it: vikix mcp register$" <<<"$out"

[ "$fail" = 0 ] && echo "mcp: the protocol, read-only tools, checked acts, eval and undo only when switched on, a log, register (Claude Code and Antigravity CLI)"
exit "$fail"
