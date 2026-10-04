#!/usr/bin/env bash
# tests/propose.sh — an agent proposes a rule, and only the user adds it: the
# MCP server's propose_rule against a real StumpWM on a hidden screen.
#
#   A good rule waits: nothing is written and nothing runs, a notification
#   says so, vikix rules proposed and the agents' rules tool show it.
#   What isn't a rule made only of verbs and plain values is refused, with
#   the reason: a function of Lisp's, :where, a variable, a quoted value, a
#   value read with #., two rules at once, values that don't fit the verb,
#   text that tries to close the string it travels in. A rule that is there
#   already, or an eleventh waiting, is refused too.
#   Super+m, Rules lists the proposals first: Add writes the rule at the
#   end of rules.lisp under a dated comment with its why, after a snapshot,
#   and the rule works at once; Drop forgets it; the agent can read which.
#
# Needs what tests/lib/wm.sh needs (Xvfb, xdotool, alacritty, Vikix's
# StumpWM); skipped without.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup propose
# Never the real desktop's: a notify-send and a vikix (the snapshot) of the
# test's own, first on the test StumpWM's PATH, that write down what they're asked.
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s|" "$@" >> "%s/notified"; echo >> "%s/notified"\n' "$t" "$t" > "$t/bin/notify-send"
printf '#!/bin/sh\necho "$*" >> "%s/vikix-asked"\n' "$t" > "$t/bin/vikix"
chmod +x "$t/bin/notify-send" "$t/bin/vikix"
export PATH="$t/bin:$PATH"
wm_start

# call NAME ARGS-JSON — what the real server's tool answers, "ERROR: " before a refusal.
call() {
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" |
    HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-mcp" serve |
    python3 -c 'import json,sys; r=json.loads(sys.stdin.readline())["result"]; print(("ERROR: " if r["isError"] else "") + r["content"][0]["text"])'
}
# propose RULE [WHY] — the rule as an agent sends it (JSON does the quoting).
propose() { call propose_rule "$(python3 -c 'import json,sys; print(json.dumps({"rule": sys.argv[1], "why": sys.argv[2]}))' "$1" "${2:-}")"; }
waiting() { ask '(princ (length *vikix-rule-proposals*))'; }
both() { grep -qF -- "$2" <<<"$1" && grep -qF -- "$3" <<<"$1"; }   # both TEXT A B — TEXT has A and B
rules_file="$home/.stumpwm.d/rules.lisp"
w() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))"; }

# --- a good rule waits ---------------------------------------------------------------
before=$(ask '(princ (length *vikix-rules*))')
out=$(propose '(when-window (:class "Pictures") (workspace 5))' 'Pictures are edited on workspace 5')
check "a good rule is proposed: $out" grep -q '^proposed 1: (when-window (:class "Pictures") (workspace 5))' <<<"$out"
check "and the agent is told the user decides" grep -q 'nothing changes until they add it' <<<"$out"
check "it waits: $(waiting)" test "$(waiting)" = 1
check "no rule was added to the desktop" test "$(ask '(princ (length *vikix-rules*))')" = "$before"
check "nor written" bash -c "! grep -qs Pictures '$rules_file'"
sleep 0.5
check "a notification says so, with the rule and the why: $(cat "$t/notified" 2>/dev/null)" \
  bash -c "grep -q 'An agent proposes a rule' '$t/notified' && grep -q 'Why: Pictures are edited on workspace 5' '$t/notified'"
out=$(HOME=$home VIKIX_SWANK_PORT=$port bash "$here/bin/vikix-rules" proposed)
check "vikix rules proposed shows it with its why: $out" both "$out" '(when-window (:class "Pictures") (workspace 5))' 'why: Pictures are edited'
out=$(call rules '{}')
check "the agents' rules tool says it waits for the user" grep -q '"state": "waiting for the user"' <<<"$out"

# --- what isn't only verbs and plain values is refused ------------------------------
refused() {   # refused WHAT RULE WORDS — the tool refuses RULE, saying WORDS, and nothing more waits
  local n out
  n=$(waiting)
  out=$(propose "$2")
  check "$1 is refused: $out" grep -q "^ERROR: not proposed, nothing changed\\..*$3" <<<"$out"
  check "$1: nothing more waits" test "$(waiting)" = "$n"
}
refused "a function of Lisp's" "(when-window (:class \"X\") (run-shell-command \"touch $t/pwned\"))" "isn't a verb"
refused ":where" '(when-window (:where (lambda (w) t)) (dialog))' "no Lisp of its own"
refused "a variable" '(when-window (:class *my-class*) (workspace 2))' "no variable"
refused "a value worked out" '(when-window (:class "X") (workspace (+ 1 2)))' "no Lisp of its own"
refused "a quoted value" "(when-window (:class \"X\") (title 'foo))" "no Lisp of its own"
refused "a value read with #." "(when-window (:class \"X\") (workspace #.(run-shell-command \"touch $t/pwned\")))" "can't be read as a rule"
refused "two rules at once" '(when-window (:class "X") (workspace 2)) (when-window (:class "Y") (workspace 3))' "One rule at a time"
refused "what isn't a rule" '(progn (when-window (:class "X") (workspace 2)))' "A proposal is one rule"
refused "a verb without its value" '(when-window (:class "X") (workspace))' "doesn't fit the verb"
refused "a verb with a value it hasn't" '(when-window (:class "X") (float :wide 3))' "doesn't fit the verb"
refused "a list that is no verb" '(when-window (:class "X") (workspace 2) ("a" "b"))' "isn't a verb"
refused "a time that isn't one" '(at "25:99" (notify "x"))' "24-hour clock"
refused "text closing its own string" "(when-window (:class \"X\") (workspace 2))\") (run-shell-command \"touch $t/pwned\") (princ \"" "One rule at a time"
out=$(call propose_rule '{"why":"no rule"}')
check "without a rule, the tool says what it needs: $out" grep -q '^ERROR: propose_rule needs rule' <<<"$out"
out=$(call propose_rule "{\"rule\":\"$(printf '(at-login (say \\"%0990d\\"))' 0)\"}")
check "a rule longer than 1000 characters is refused: ${out:0:80}" grep -q '^ERROR: a rule is at most 1000' <<<"$out"
check "nothing an agent sent ran" test ! -e "$t/pwned"

# --- what a rule would run is said ---------------------------------------------------
out=$(propose '(at-login (run "echo hi") (notify "Started"))' 'say hi at login')
check "a rule that runs a program can be proposed: $out" grep -q '^proposed 2' <<<"$out"
out=$(ask '(vikix-rules-cli "proposed")')
check "and what it would run is said where it is shown: $out" grep -qF 'it runs: (run "echo hi")' <<<"$out"

# --- the user adds it, or drops it ---------------------------------------------------
ask '(run-commands "vikix-rules")' >/dev/null &
sleep 1.5; xdotool key Return      # the first line of the menu: the first proposal
sleep 1.2; xdotool key Return      # the line its menu opens on is the rule itself: nothing happens
sleep 1
check "a hasty Enter on a proposal adds nothing: $(waiting) wait" test "$(waiting)" = 2
ask '(run-commands "vikix-rules")' >/dev/null &
sleep 1.5; xdotool key Return
sleep 1.2; xdotool key Down; xdotool key Down; xdotool key Return      # past the rule and its why: add it
sleep 2
check "Super+m, Rules, the proposal, Add: one waits now: $(waiting)" test "$(waiting)" = 1
check "the rule is at the end of rules.lisp: $(tail -2 "$rules_file")" test "$(tail -1 "$rules_file")" = '(when-window (:class "Pictures") (workspace 5))'
check "under a dated comment with its why" bash -c "tail -2 '$rules_file' | head -1 | grep -qE '^;; Proposed by an agent, [0-9]{4}-[0-9]{2}-[0-9]{2}: Pictures are edited on workspace 5\$'"
check "a snapshot was asked for first: $(cat "$t/vikix-asked" 2>/dev/null)" grep -q '^snapshot before: a rule an agent proposed' "$t/vikix-asked"
check "the desktop has the rule, as written in rules.lisp: $(ask '(princ (vikix-rule-from (first (last *vikix-rules*))))')" \
  test "$(ask '(princ (list (vikix-rule-text (first (last *vikix-rules*))) (vikix-rule-owner (first (last *vikix-rules*)))))')" = '((when-window (:class "Pictures") (workspace 5)) rules.lisp)'
LIBGL_ALWAYS_SOFTWARE=1 alacritty --class Pictures --title Pic -e sleep 300 >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 1 40); do [ "$(ask "(princ (if $(w Pic) 1 0))")" = 1 ] && break; sleep 0.25; done
check "and it works: a window of that class opens on workspace 5: $(ask "(princ (group-name (window-group $(w Pic))))")" \
  test "$(ask "(princ (group-name (window-group $(w Pic))))")" = 5
out=$(propose '(when-window (:class "Pictures") (workspace 5))')
check "a rule that is there already is refused: $out" grep -q '^ERROR: .*already one of the desktop' <<<"$out"

ask '(run-commands "vikix-rules")' >/dev/null &
sleep 1.5; xdotool key Return      # the proposal left
sleep 1.2; xdotool key Down; xdotool key Down; xdotool key Down; xdotool key Down; xdotool key Return      # past the rule, its why, what it runs and Add: drop it
sleep 1.5
check "Drop: none waits now: $(waiting)" test "$(waiting)" = 0
check "and it was never written" bash -c "! grep -q 'echo hi' '$rules_file'"
out=$(call rules '{}')
check "the agent can read what became of each: $(grep -A12 '"proposed"' <<<"$out" | tr -s ' \n' ' ')" \
  both "$out" '"state": "added by the user"' '"state": "dropped by the user"'

# --- no more than ten wait -------------------------------------------------------------
for i in $(seq 1 10); do propose "(when-workspace $i (say \"Workspace $i\"))" >/dev/null; done
out=$(propose '(when-workspace 11 (say "Workspace 11"))')
check "ten wait: $(waiting)" test "$(waiting)" = 10
check "and an eleventh is refused: $out" grep -q '^ERROR: .*wait for the user already' <<<"$out"
check "no rule failed, and nothing asked" bash -c "[ '$(ask '(princ (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))')' = 0 ] && ! grep -qi 'debugger\|unhandled' '$t/wm.log'"

wm_report propose "an agent's rule is checked (only verbs and plain values: a function, :where, a variable, #. and a second rule are refused), waits with a notification, and only Super+m, Rules adds it to rules.lisp (a snapshot first) or drops it; the agent reads which"
exit "$fail"
