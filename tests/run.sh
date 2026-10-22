#!/usr/bin/env bash
# tests/run.sh — run the tests that fit this machine.
#
#   tests/run.sh          the quick ones (about two minutes): lint, lisp (with
#                         sbcl), battery, memory, home, services, ledger, rollback, backup and
#                         versions (with restic), image, theme, theme-import, bar, rofi,
#                         wallpaper, examples, dev-ai, notes, project, drives, nodes, firmware, fingerprint, firewall, updates, doctor, notifications, idle, lock, lazarus, capture,
#                         mimeapps, nightlight, update, windows, steam, ai, ai-local, llm, ai-keys, agents, codex, debug, dictate, voice, lisp-apps, esploro, cuis, mcp, swank (with Quicklisp), errors (with Quicklisp's StumpWM), webapp, features, nvim, emacs, welcome, menu (with sbcl), docs-open, nyxt (with sbcl), pkg, oneline, installer, man, day, info (with makeinfo),
#                         and on Void also packages and dry-run
#   tests/run.sh --quick  the same without the slow ones that check only
#                         one corner: packages and dry-run (Void's mirror,
#                         over the network), examples (builds every
#                         language's examples) and lazarus. For changes that
#                         don't touch what the stages install (packages/,
#                         features.list, dev/, install/10-packages.sh)
#   tests/run.sh --all    those, plus editors (several minutes, network)
#   tests/run.sh --changed [REF]
#                         only the tests for what changed since REF (default:
#                         origin/main), uncommitted changes included; see
#                         tests/changed.sh for how files map to tests
#   tests/run.sh NAME...  just those tests (lint, lisp, ...), side by side
#
# Each test is its own script in tests/ and can be run alone. They run side
# by side, as many at once as the machine has cores (VIKIX_TEST_JOBS sets
# it; 1 is one after another), and no more than that over every run on the
# machine together (the slots, below; `tests/run.sh NAME` queues one test), each one's output printed whole when it
# ends, so a failure reads as it would alone. A test must therefore keep
# to its own temporary folder, display and ports. A screen test that fails
# runs once more with the machine to itself, and counts as passed when it
# passes then (noted in ~/.local/state/vikix/test-flakes.log; see below).
# GitHub runs them too: .github/workflows/test.yml.

set -uo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# The tests make up a home folder, and Vikix follows the XDG variables
# where they are set; GitHub's runners set XDG_CONFIG_HOME, which would
# send a test's files into the runner's real config instead.
# The hidden desktops the tests start share one folder of compiled copies
# of the layer (init.lisp), so each needn't compile it again: a copy is
# named by what it was made from, so runs of different branches don't mix.
export VIKIX_FASL_DIR=${VIKIX_FASL_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/vikix/test-fasl}
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
cd "$(dirname "$0")" || exit 1
# A run started by a test of a run (queue, changed-map) is nobody's to record.
nested=${VIKIX_TEST_RUN:-}
export VIKIX_TEST_RUN=1
mode=${1:-}
case $mode in
  ''|--quick|--all|--changed) ;;
  -*) echo "usage: tests/run.sh [--quick|--all|--changed [REF]|NAME...]" >&2; exit 2 ;;
  *) mode=--names ;;
esac
tests=(lint)
if command -v sbcl >/dev/null; then tests+=(lisp); else echo "(lisp needs sbcl; skipped here)"; fi
tests+=(battery memory gestures home services ledger rollback lisp-stage session image theme theme-import bar rofi wallpaper mimeapps examples dev-ai translate-guides notes project drives firmware fingerprint firewall updates doctor notifications idle lock queue release lazarus capture nightlight update try windows vm steam ai ai-local llm ai-keys agents debug dictate voice lisp-apps esploro cuis music hype publish winapps learn mcp swank errors bitwarden plugin records grok obsidian docs-check screens wifi network nodes docs vk webapp features nvim emacs editor-theme welcome menu docs-open nyxt pkg oneline installer man changed-map day back viri main drawer layouts rules keys reload resume palette used registry maps why what gather workspaces refile office titles house handoff tester reconnect plan tasks scheduler office-ui codex tray focus propose door socket events focus-time pixmaps times soak rescue)
if command -v restic >/dev/null; then tests+=(backup versions); else echo "(backup and versions need restic; skipped here)"; fi
if command -v makeinfo >/dev/null; then tests+=(info); else echo "(info needs makeinfo; skipped here)"; fi
# --quick leaves these out (the run says so); the full run and GitHub keep them.
slow=(examples lazarus)
if [ "$mode" = --quick ] || [ "$mode" = --changed ]; then
  kept=()
  for t in "${tests[@]}"; do [[ " ${slow[*]} " == *" $t "* ]] || kept+=("$t"); done
  tests=("${kept[@]}")
  echo "(${slow[*]} packages dry-run left out: --quick)"
elif command -v xbps-query >/dev/null && [ "$(id -u)" -ne 0 ]; then
  tests+=(packages dry-run)
else
  echo "(packages and dry-run need Void and a normal user; skipped here)"
fi
[ "$mode" = --all ] && tests+=(editors)

if [ "$mode" = --names ]; then
  tests=()
  for t in "$@"; do
    [ -x "./$t.sh" ] || { echo "no test $t (tests/$t.sh)" >&2; exit 2; }
    tests+=("$t")
  done
elif [ "$mode" = --changed ]; then
  # From the quick set, those the changes reach. "all" is changed.sh's guess
  # (a file no test names): the quick set, less the tests that run alone
  # (times, soak, rescue), which wait for the whole machine and held two
  # runs past their deadline in a day (2026-10-11); a change that reaches
  # one names it, and tests/run.sh rescue runs it by itself.
  changed_ref=${2:-origin/main}
  mapfile -t wanted < <(./changed.sh "$changed_ref")
  if [ "${wanted[*]}" = all ]; then
    wanted=()
    for t in "${tests[@]}"; do [[ " times soak rescue " == *" $t "* ]] || wanted+=("$t"); done
    echo "(the changes reach too far to pick: the quick set, less times, soak and rescue, which run alone)"
  fi
  kept=()
  for t in "${tests[@]}"; do [[ " ${wanted[*]} " == *" $t "* ]] && kept+=("$t"); done
  tests=("${kept[@]}")
  if [ "${#tests[@]}" -eq 0 ]; then echo "nothing changed that a test covers"; exit 0; fi
  echo "(for what changed: ${tests[*]})"
fi

# The long ones start first, so the run isn't left waiting on one at the end.
first=(emacs mcp learn ai-local errors lint swank dev-ai dictate features editors packages dry-run examples lazarus)
ordered=()
for t in "${first[@]}"; do [[ " ${tests[*]} " == *" $t "* ]] && ordered+=("$t"); done
for t in "${tests[@]}"; do [[ " ${first[*]} " == *" $t "* ]] || ordered+=("$t"); done

jobs=${VIKIX_TEST_JOBS:-$(nproc 2>/dev/null || echo 2)}
[ "$jobs" -ge 1 ] 2>/dev/null || jobs=1
logs=$(mktemp -d)
trap 'rm -rf "$logs"; [ -z "${run_note:-}" ] || rm -f "$run_note"' EXIT
failed=() took=() shown=()
# The machine as the run begins: said with a failure, since a load past the
# cores makes a timing check fail on its own (house, at a load of 5.5 on 4
# cores, cost a release an hour, 2026-10-11).
load_at_start="load $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo '?') on $(nproc 2>/dev/null || echo '?') cores"

# The machine's test slots. Several sessions test at once, each run side
# by side: with no more said, five runs on four cores were twenty tests at
# a time, hidden desktops among them, and tests failed for slowness alone
# (2026-10-03 and 04: a load of 70 to 100). So every run on this machine
# draws from one set of slots, as many as there are cores: a test starts
# when one is free, in whichever run. And a test that must have the machine
# to itself (the `alone` list) waits until no other test is running
# anywhere, and holds the others back while it runs.
slots_dir=${VIKIX_TEST_SLOTS_DIR:-${XDG_RUNTIME_DIR:-/tmp}/vikix-test-slots}
slots=${VIKIX_TEST_SLOTS:-$(nproc 2>/dev/null || echo 2)}
[ "$slots" -ge 1 ] 2>/dev/null || slots=1
queue=1
command -v flock >/dev/null 2>&1 && mkdir -p "$slots_dir" 2>/dev/null || queue=

# A run's plan and live files let the Office show progress even when a
# worker invoked this runner directly. Durations exclude time in the queue.
run_note=""
if mkdir -p "$slots_dir/runs" "$slots_dir/durations" 2>/dev/null; then
  printf '%s\n' "${ordered[@]}" > "$logs/plan"
  printf '%s\n' "$(pwd -P)" "$jobs" "$(date +%s)" > "$logs/run"
  for t in "${ordered[@]}"; do
    [ ! -f "$slots_dir/durations/$t" ] || cp "$slots_dir/durations/$t" "$logs/$t.expected"
  done
  run_note="$slots_dir/runs/$$"
  printf '%s\n' "$logs" > "$run_note.tmp"
  mv "$run_note.tmp" "$run_note"
fi

# Each test leaves a note of what it is doing ($slots_dir/notes/PID: waiting
# for a slot, waiting for the machine to itself, or running; the test; since
# when), gone when it ends: what `vikix agents` reads to say that an agent's
# tests wait for a slot. A note whose process is gone is nobody's.
note_slot() {   # note_slot STATE TEST SINCE
  mkdir -p "$slots_dir/notes" 2>/dev/null || return 0
  printf '%s\n%s\n%s\n' "$1" "$2" "$3" > "$slots_dir/notes/$BASHPID" 2>/dev/null || true
}

in_slot() {     # in_slot COMMAND...: run it holding one of the machine's slots
  [ -n "$queue" ] || { "$@"; return; }
  local all fd i code waited=0 since name
  since=$(date +%s); name=${*: -1}
  exec {all}>"$slots_dir/all"
  note_slot waiting "$name" "$since"
  flock -s "$all"                    # not while a test has the machine to itself
  while :; do
    for i in $(seq 1 "$slots"); do
      exec {fd}>"$slots_dir/$i"
      if flock -n "$fd"; then
        note_slot running "$name" "$since"
        "$@"; code=$?
        rm -f "$slots_dir/notes/$BASHPID"
        exec {fd}>&- {all}>&-
        return "$code"
      fi
      exec {fd}>&-
    done
    waited=$((waited + 1))
    [ "$waited" = 20 ] && echo "(waiting for a free test slot: other runs are testing on this machine)" >&2
    sleep 0.5
  done
}

alone_slot() {  # alone_slot COMMAND...: run it while no other test runs anywhere
  [ -n "$queue" ] || { "$@"; return; }
  local all code since name
  since=$(date +%s); name=${*: -1}
  exec {all}>"$slots_dir/all"
  flock -n -x "$all" || { echo "(waiting for the machine to be free of other tests)" >&2; note_slot alone "$name" "$since"; flock -x "$all"; }
  note_slot running "$name" "$since"
  "$@"; code=$?
  rm -f "$slots_dir/notes/$BASHPID"
  exec {all}>&-
  return "$code"
}

run_one() {
  local start=$SECONDS code=0
  date +%s > "$logs/$1.started"
  ./"$1".sh > "$logs/$1.out" 2>&1 || code=$?
  echo "$code $((SECONDS - start))" > "$logs/$1.done.tmp"
  mv "$logs/$1.done.tmp" "$logs/$1.done"
  if [ "$code" = 0 ] && [ -d "$slots_dir/durations" ]; then
    printf '%s\n' "$((SECONDS - start))" > "$slots_dir/durations/$1.$BASHPID.tmp"
    mv "$slots_dir/durations/$1.$BASHPID.tmp" "$slots_dir/durations/$1"
  fi
}

# Prints each test that has ended and isn't printed yet, whole.
show_ended() {
  local t code secs
  for t in "${ordered[@]}"; do
    [[ " ${shown[*]} " == *" $t "* ]] && continue
    [ -e "$logs/$t.done" ] || continue
    read -r code secs < "$logs/$t.done"
    echo "=== $t (${secs}s)"
    cat "$logs/$t.out"
    # A test that died before any check failed shows nothing (a check prints
    # only when it fails), so its exit says what there is: a signal (killed:
    # earlyoom, a timeout), or a set -e exit (its own ERR trap, if it has one,
    # names the line).
    if [ "$code" != 0 ]; then
      [ -s "$logs/$t.out" ] || echo "(no output)"
      if [ "$code" -gt 128 ]; then echo "(exit $code: killed by signal $((code - 128)))"; else echo "(exit $code)"; fi
    fi
    [ "$code" = 0 ] || failed+=("$t")
    took+=("$secs $t")
    shown+=("$t")
  done
}

# Stopped from outside (a timeout on the run, Ctrl+C) while tests wait for
# a slot or for the machine: what passed and failed so far is said, with
# what was left waiting or running, rather than lost with the run.
stopped() {
  trap - TERM INT
  show_ended
  local waiting=() running=() t
  for t in "${ordered[@]}"; do
    [[ " ${shown[*]} " == *" $t "* ]] && continue
    if [ -e "$logs/$t.out" ]; then running+=("$t"); else waiting+=("$t"); fi
  done
  echo
  echo "stopped before the end ($load_at_start as the run began):"
  [ "${#running[@]}" -eq 0 ] || echo "  running, stopped: ${running[*]}"
  [ "${#waiting[@]}" -eq 0 ] || echo "  not run: ${waiting[*]} (waiting for a slot or for the machine: other runs were testing)"
  [ "${#shown[@]}" -eq 0 ] || echo "  passed: $(for t in "${shown[@]}"; do [[ " ${failed[*]} " == *" $t "* ]] || printf '%s ' "$t"; done)"
  [ "${#failed[@]}" -eq 0 ] || echo "  FAILED: ${failed[*]}"
  # Its own jobs and what they started (a test's shell, which a subshell ended by
  # the signal would otherwise leave running), never a process group; their
  # notes go with them, or vikix agents would see tests still running.
  # No wait here: bash's wait inside a trap that interrupted a wait -n spun
  # for good (2026-10-11); the exit reaps what is left.
  local j
  for j in "${started[@]}"; do kill_tree "$j"; rm -f "$slots_dir/notes/$j"; done
  exit 124
}
kill_tree() {   # kill_tree PID: PID's children first, then PID
  local c
  for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
  kill "$1" 2>/dev/null
}
trap stopped TERM INT

# Tests that can't share the machine with others (a fixed real port or
# display) run after the rest, one at a time: times and soak, whose measures
# others running beside it would slow, and rescue, which makes a hidden
# desktop work flat out and counts the seconds.
alone=(times soak rescue)
started=()
for t in "${ordered[@]}"; do
  [[ " ${alone[*]} " == *" $t "* ]] && continue
  while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do
    wait -n 2>/dev/null || true
    show_ended
  done
  in_slot run_one "$t" &
  started+=("$!")
done
wait
show_ended
# In the background and waited on, as the others: a signal reaches a wait at
# once, where one in a foreground flock would be held until the lock came.
for t in "${ordered[@]}"; do
  [[ " ${alone[*]} " == *" $t "* ]] || continue
  alone_slot run_one "$t" &
  started+=("$!")
  wait "$!" 2>/dev/null || true
  show_ended
done

# Once more, alone. A test that drives a hidden desktop (it sources
# tests/lib/wm.sh, or starts an Xvfb of its own) types against deadlines,
# and fails for slowness alone when the machine is full: on 2026-10-22
# three releases in a row were refused, each by a screen test that passed
# on its own right after (palette, docs, workspaces). So each such test
# that failed runs again, once, with the machine to itself; one that
# passes then counts as passed, is said so, and goes into
# ~/.local/state/vikix/test-flakes.log (when, the commit, the test, the
# load as the run began, its FAIL lines), so one that does it often is
# seen and mended rather than forgiven for ever. Any other test's failure
# stands, as does a screen test's second. VIKIX_TEST_RETRY=0 keeps the
# first answer (for a test being fixed), and a single named test, which
# ran as good as alone, isn't tried again.
flakes_log=${VIKIX_TEST_FLAKES:-$HOME/.local/state/vikix/test-flakes.log}
screen_test() { grep -qE 'lib/wm\.sh|Xvfb' "./$1.sh" 2>/dev/null; }
note_flake() {   # note_flake TEST FIRST-OUTPUT
  mkdir -p "$(dirname "$flakes_log")" 2>/dev/null || return 0
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M)" "$(git rev-parse --short HEAD 2>/dev/null || echo '?')" \
    "$1" "$load_at_start" "$(grep '^FAIL' "$2" | head -3 | tr '\n' ' ' | cut -c1-300)" >> "$flakes_log" 2>/dev/null || true
}
flaky=()
if [ "${VIKIX_TEST_RETRY:-1}" != 0 ] && { [ "$mode" != --names ] || [ "${#tests[@]}" -gt 1 ]; }; then
  for t in "${failed[@]}"; do
    screen_test "$t" || continue
    echo "=== $t, once more alone (it drives a hidden desktop; the machine may have been full)"
    mv "$logs/$t.out" "$logs/$t.first"; rm -f "$logs/$t.done"
    alone_slot run_one "$t" &
    started+=("$!")
    wait "$!" 2>/dev/null || true
    read -r code secs < "$logs/$t.done"
    cat "$logs/$t.out"
    if [ "$code" = 0 ]; then
      echo "=== $t passed once more alone (${secs}s): a timing flake, noted in $flakes_log"
      flaky+=("$t"); note_flake "$t" "$logs/$t.first"
    else
      echo "=== $t failed again alone (${secs}s)"
    fi
  done
  if [ "${#flaky[@]}" -gt 0 ]; then
    kept=()
    for t in "${failed[@]}"; do [[ " ${flaky[*]} " == *" $t "* ]] || kept+=("$t"); done
    failed=("${kept[@]}")
  fi
fi
echo
# The slow ones, so a run that takes long says why.
echo "slowest: $(printf '%s\n' "${took[@]}" | sort -rn | head -5 | awk '{printf "%s %ss  ", $2, $1}')"

# The run into the desk's record (vikix agents handoff check), when it ran
# at a desk: the tester at the hand-in and the release then see a run that
# passed on this very commit and don't run it again (one commit was tested
# three times in an hour, 2026-10-16). Not a run a test started (VIKIX_TEST_RUN
# was set as it began); nothing said, and a folder that is no desk is refused
# by the command itself.
record_run() {
  [ -z "$nested" ] || return 0
  local top; top=$(cd .. && pwd -P)
  [ -x "$top/bin/vikix-agents" ] || return 0
  local name="tests/run.sh" state=--ok
  case $mode in
    --names) name="tests/run.sh ${tests[*]}" ;;
    --changed) name="tests/run.sh --changed $changed_ref" ;;
    '') ;;
    *) name="tests/run.sh $mode" ;;
  esac
  [ "${#failed[@]}" -eq 0 ] || state=--failed
  timeout 20 "$top/bin/vikix-agents" handoff check "$name" "$state" --note "$1" --desk "$top" >/dev/null 2>&1 || true
}
[ "${#flaky[@]}" -eq 0 ] || echo "(passed only once more alone, a timing flake: ${flaky[*]}; noted in $flakes_log)"
if [ "${#failed[@]}" -eq 0 ]; then
  echo "all passed: ${tests[*]}"
  record_run "${#tests[@]} tests in $SECONDS s ($load_at_start as the run began)${flaky[0]:+; passed only once more alone: ${flaky[*]}}"
else
  echo "($load_at_start as the run began)"
  echo "FAILED: ${failed[*]}"
  record_run "failed: ${failed[*]} ($load_at_start as the run began)"
  exit 1
fi
