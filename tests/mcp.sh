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
# So the forms the tools send are also compiled against the real StumpWM,
# from Quicklisp, when it's there: a stand-in answers anything, and 0.54.1
# shipped a focus_window that the real one refused (a group given to
# gselect, a command that takes its argument as typed text).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
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

# Registering with Claude Code.
python3 "$here/bin/vikix-mcp" register --allow-eval >/dev/null
check "register should add it to Claude Code, for you, with the flags: $(cat "$t/claude.calls")" \
  grep -qE '^claude mcp add --scope user vikix -- .*vikix-mcp serve --allow-eval$' "$t/claude.calls"

[ "$fail" = 0 ] && echo "mcp: the protocol, read-only tools, checked acts, eval and undo only when switched on, a log, register"
exit "$fail"
