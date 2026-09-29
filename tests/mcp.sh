#!/usr/bin/env bash
# tests/mcp.sh — vikix-mcp, the desktop as an MCP server.
#
#   it answers initialize (the client's protocol version, or its own), ping,
#   tools/list, tools/call, and no-method and not-JSON errors; notifications
#   get no answer; the read-only tools read the window manager through fixed
#   forms; eval and undo exist only when switched on; what an agent sends
#   is checked against the desktop (a workspace that exists, a theme there
#   is, a number) and never reaches Lisp or a shell otherwise; every call
#   is logged; register adds it to Claude Code with the flags asked for
#
# The window manager (vikix-eval), notify-send and claude are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
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
def lisp(s): return '=> "' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
if "workspaces" in form:
    print(lisp(json.dumps({"workspaces": [
        {"name": "1", "number": 1, "current": True, "windows": [
            {"number": 0, "title": 'a "quoted" \\ title', "class": "Alacritty", "focused": True}]},
        {"name": "web", "number": 2, "current": False, "windows": []}],
        "screens": [{"number": 0, "x": 0, "y": 0, "width": 1920, "height": 1080}]})))
elif "*vikix-bindings*" in form:
    print(lisp(json.dumps([{"key": "s-RET", "command": "vikix-terminal", "does": "Terminal"}])))
else:
    print("=> T")
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$t/notified"
EOF
cat > "$t/bin/claude" <<EOF
#!/bin/sh
echo "claude \$*" >> "$t/claude.calls"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_EVAL="$t/bin/eval" VIKIX_CLAUDE="$t/bin/claude" T="$t"

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
check "initialize should say it has tools" test "$(field '["result"]["capabilities"]["tools"]["listChanged"]' <<<"$out")" = False
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
check "the read-only tools should be there: $list" grep -q 'desktop keys doctor history changes themes version' <<<"$list"
check "eval shouldn't be there by default: $list" test -z "$(grep -ow 'eval\|undo' <<<"$list" || true)"
check "--allow-eval should add eval: $(names --allow-eval)" grep -qw eval <<<"$(names --allow-eval)"
check "--allow-undo should add undo: $(names --allow-undo)" grep -qw undo <<<"$(names --allow-undo)"
out=$(call eval '{"form":"(run-shell-command \"touch pwned\")"}')
check "eval without --allow-eval should be refused: $out" grep -q '^ERROR: no tool' <<<"$out"
check "a refused eval ran something" test ! -e "$t/forms"
ro=$(rpc -- '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 -c 'import json,sys; print(" ".join(t["name"] for t in json.loads(sys.stdin.readline())["result"]["tools"] if t["annotations"]["readOnlyHint"]))')
check "the read tools should say they only read: $ro" test "$ro" = "desktop keys doctor history changes themes version"

# Reading the desktop.
out=$(call desktop '{}')
check "desktop should give the workspaces: $out" grep -q '"name": "web"' <<<"$out"
check "a title with quotes and a backslash should come through whole: $out" grep -qF 'a \"quoted\" \\ title' <<<"$out"
check "desktop should give the theme" grep -q '"theme": "void"' <<<"$out"
out=$(call keys '{}')
check "keys should give the bindings: $out" grep -q 's-RET' <<<"$out"
out=$(call themes '{}')
check "themes should list them: $out" grep -q '"paper"' <<<"$out"

# Acting: checked against what's there.
: > "$t/forms"
out=$(call switch_workspace '{"name":"x\") (run-shell-command \"touch pwned"}')
check "a workspace that isn't there should be refused: $out" grep -q '^ERROR: no workspace' <<<"$out"
check "a refused workspace shouldn't reach Lisp: $(cat "$t/forms")" test -z "$(grep -v 'workspaces' "$t/forms" || true)"
out=$(call switch_workspace '{"name":"web"}')
check "an existing workspace should be shown: $out" grep -q 'on workspace web' <<<"$out"
check "it should be selected by name, as a Lisp string: $(tail -1 "$t/forms")" grep -q '(gselect (find-group (current-screen) "web"))' "$t/forms"
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
out=$(call notify '{"body":"no title"}')
check "notify without a title should say so: $out" grep -q '^ERROR: title' <<<"$out"
out=$(call snapshot '{"message":"before $(touch pwned2); x"}')
check "a snapshot's message shouldn't run anything" test ! -e "$t/pwned2"
out=$(call changes '{"snapshot":"HEAD; rm -rf ~"}')
check "changes with a bad id should be refused: $out" grep -q '^ERROR: snapshot' <<<"$out"

# With eval switched on, it runs; undo checks its id too.
out=$(call eval '{"form":"(+ 1 2)"}' --allow-eval)
check "eval, switched on, should run the form: $out" grep -q '(+ 1 2)' "$t/forms"
out=$(call undo '{"snapshot":"x y"}' --allow-undo)
check "undo with a bad id should be refused: $out" grep -q '^ERROR: snapshot' <<<"$out"

# The log.
check "calls should be logged: $(tail -2 "$VIKIX_STATE/mcp.log" 2>/dev/null)" grep -q ' set_theme {"name": "paper"}' "$VIKIX_STATE/mcp.log"

# Registering with Claude Code.
python3 "$here/bin/vikix-mcp" register --allow-eval >/dev/null
check "register should add it to Claude Code, for you, with the flags: $(cat "$t/claude.calls")" \
  grep -qE '^claude mcp add --scope user vikix -- .*vikix-mcp --allow-eval$' "$t/claude.calls"

[ "$fail" = 0 ] && echo "mcp: the protocol, read-only tools, checked acts, eval and undo only when switched on, a log, register"
exit "$fail"
