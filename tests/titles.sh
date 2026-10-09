#!/usr/bin/env bash
# tests/titles.sh — an agent's terminal named for its desk (agents.lisp,
# bin/vikix-agents), in a real StumpWM on a hidden screen.
#
#   A terminal with an agent at a desk is named "TOPIC · Provider" on the
#   desktop (the window's user title, what the window list and the title
#   bar show; _VIKIX_DESK on the window) from a desk started with vikix
#   agents desk, taken with sit (the seat's folder, not the process's) and
#   taken up again with resume; the title the agent writes stays apart and
#   still says what it is doing (at its prompt, working), and a title that
#   turns several times a second names nothing again; two of one provider
#   at one desk are numbered, each keeping its number when the other
#   leaves, another provider is not; an agent gone leaves the terminal
#   unnamed when it is a shell again, and renamed when another agent runs
#   there; a terminal with no agent, an agent off a desk (home, the
#   project's own folder) and a name the user gave are left alone; a desk
#   with spaces, punctuation and Unicode in its name; a reload leaves one
#   hook and one wrapper, and the names as they were; vikix agents and
#   --json say the same name. A desk gone while its agent runs (released, or
#   closed) keeps the terminal's name, and the terminal takes a colour for
#   what is left to do: gup while the repository's branch has commits its
#   origin hasn't, close once pushed, asks over both while the agent waits
#   for you; the colours are the theme's, and the listing says the same.
#
# Needs Xvfb, xdotool, alacritty and Vikix's own StumpWM, as office does;
# without them it says so and stops there. Its own screen, port and home.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_STATE_HOME XDG_CONFIG_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/wm.sh
. "$here/tests/lib/wm.sh"
wm_setup titles
wm_start

yes() { test "$(ask "(princ (if $1 1 0))")" = 1; }
cli() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-agents" "$@" 2>&1 || true; }
# The window whose X title (what its program wrote) is TITLE, as a Lisp form.
by_title() { printf '(find "%s" (all-windows) :key (function window-title) :test (function equal))' "$1"; }
# The name of the window titled TITLE, after up to ten seconds: the pass runs
# three seconds after a terminal opens, and at a title change.
name_of() {
  local want=$2 got=''
  for _ in $(seq 1 40); do
    got=$(ask "(princ (or (window-user-title $(by_title "$1")) \"\"))")
    [ "$got" = "$want" ] && break
    sleep 0.25
  done
  printf '%s' "$got"
}
sets() { ask '(princ *vikix-agent-title-sets*)'; }
# A pass as the ticker runs it (every 30 seconds): now.
pass() { ask '(vikix-agent-titles-refresh)' >/dev/null; sleep 0.3; }

# Stand-in agents: claude [TITLEFILE] writes the title TITLEFILE holds whenever
# it changes, or a turning mark five times a second while it holds "churn";
# codex and agy only stay.
mkdir -p "$t/bin" "$home/src"
cat > "$t/bin/claude" <<'C'
#!/bin/sh
last=
while :; do
  if [ -n "${1:-}" ] && [ -r "$1" ]; then
    want=$(cat "$1")
    if [ "$want" = churn ]; then
      for m in ◐ ◑ ◒ ◓; do printf '\033]0;%s Thinking\007' "$m"; sleep 0.2; done
      continue
    fi
    if [ "$want" != "$last" ]; then printf '\033]0;%s\007' "$want"; last=$want; fi
  fi
  sleep 0.2
done
C
for name in codex agy; do printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$t/bin/$name"; done
chmod +x "$t/bin/"*
# A project (vikix project finds a folder with a log.md under ~/src), its
# repository, and a worktree made by hand whose name has spaces, punctuation
# and Unicode in it.
mkdir -p "$home/src/books"; echo '# Log: books' > "$home/src/books/log.md"
git -C "$home/src/books" init -q -b main; git -C "$home/src/books" config user.name T; git -C "$home/src/books" config user.email t@example.com
git -C "$home/src/books" add -A; git -C "$home/src/books" commit -q -m first
odd="$home/src/books-ünï cøde & \"quotes\""
git -C "$home/src/books" worktree add -q "$odd" -b odd

# term TITLEFILE TITLE DIR COMMAND...: a terminal in DIR running COMMAND, whose
# agent writes TITLE first (TITLEFILE holds it), waited for by that title.
# term -T TITLE DIR COMMAND...: the same for an agent that writes none
# (codex, agy): the terminal is started with that title.
term() {
  local file=$1 title=$2 dir=$3; shift 3
  local -a opts=()
  if [ "$file" = -T ]; then opts=(--title "$title"); else printf '%s' "$title" > "$file"; fi
  LIBGL_ALWAYS_SOFTWARE=1 alacritty --class titlestest "${opts[@]}" --working-directory "$dir" -e "$@" >/dev/null 2>&1 &
  pids+=($!)
  for _ in $(seq 1 40); do
    yes "$(by_title "$title")" && break
    sleep 0.25
  done
  sleep 0.3
}
export LIBGL_ALWAYS_SOFTWARE=1
desk() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_AGENT_CMD="$t/bin/claude" python3 "$here/bin/vikix-agents" desk "$@" 2>&1 || true; }
resume() { HOME=$home VIKIX_SWANK_PORT=$port VIKIX_AGENT_CMD="$t/bin/claude" python3 "$here/bin/vikix-agents" resume "$@" 2>&1 || true; }

# --- A desk started: named without the agent writing any title ----------------------------------
win Shell
out=$(desk books "Fix typos")
check "a desk is made: $out" grep -q 'a new worktree on the branch fix-typos' <<<"$out"
got=$(name_of Alacritty "fix-typos · Claude")
check "the terminal of an agent started at a desk is named for the desk, though the agent wrote no title: '$got'" test "$got" = "fix-typos · Claude"
check "its X title is still the terminal's own" yes "(equal (window-title $(by_title Alacritty)) \"Alacritty\")"
check "the name is written on the window (_VIKIX_DESK)" \
  yes "(equal (sb-ext:octets-to-string (coerce (xlib:get-property (window-xwin $(by_title Alacritty)) :_VIKIX_DESK) (quote (vector (unsigned-byte 8)))) :external-format :utf-8) \"fix-typos · Claude\")"
check "a terminal with no agent is left alone" yes "(null (window-user-title $(by_title Shell)))"

# --- The provider's own title: kept apart, and still read ----------------------------------------
term "$t/title-b" "✳ Ready B" "$home/src/books-fix-typos" "$t/bin/claude" "$t/title-b"
got=$(name_of "✳ Ready B" "fix-typos · Claude 2")
check "a second Claude at the desk is numbered: '$got'" test "$got" = "fix-typos · Claude 2"
got=$(name_of Alacritty "fix-typos · Claude 1")
check "and the first takes 1: '$got'" test "$got" = "fix-typos · Claude 1"
check "at its prompt, from its own title" yes "(eq (vikix-agent-state $(by_title "✳ Ready B")) :idle)"
printf '%s' "◐ Working B" > "$t/title-b"
for _ in $(seq 1 20); do yes "$(by_title "◐ Working B")" && break; sleep 0.25; done
check "the title it writes reaches window-title: $(ask "(princ (window-title $(by_title "◐ Working B")))")" yes "$(by_title "◐ Working B")"
check "and says it works" yes "(eq (vikix-agent-state $(by_title "◐ Working B")) :working)"
check "while the name stays: $(ask "(princ (window-user-title $(by_title "◐ Working B")))")" \
  yes "(equal (window-user-title $(by_title "◐ Working B")) \"fix-typos · Claude 2\")"
before=$(sets)
printf churn > "$t/title-b"
sleep 4
check "a title turning five times a second names nothing again: $before sets before, $(sets) after" test "$(sets)" = "$before"
check "the mark still says it works" yes '(eq (vikix-agent-state (find "titlestest" (all-windows) :key (function window-class) :test (function equal))) :working)'
printf '%s' "✳ Done B" > "$t/title-b"
for _ in $(seq 1 20); do yes "$(by_title "✳ Done B")" && break; sleep 0.25; done
check "at its prompt again" yes "(eq (vikix-agent-state $(by_title "✳ Done B")) :idle)"
check "the window list shows the name, not the mark" yes "(equal (window-name $(by_title "✳ Done B")) \"fix-typos · Claude 2\")"

# --- vikix agents and --json say the same name --------------------------------------------------
out=$(cli)
check "vikix agents puts the name before what the agent wrote: $(grep 'Claude 2' <<<"$out")" grep -qx '           fix-typos · Claude 2: ✳ Done B' <<<"$out"
# (The ones with a window: a desk name is for a window, and the machine's
# own agents, listed too, are elsewhere.)
check "--json has it as desk_title" python3 -c '
import json, sys
agents = json.loads(sys.argv[1])
mine = [a for a in agents if a["folder"].endswith("books-fix-typos") and a["window"]]
names = sorted(a["desk_title"] for a in mine)
assert names == ["fix-typos · Claude 1", "fix-typos · Claude 2"], [(a["pid"], a["window"], a["title"], a["desk_title"]) for a in mine]
' "$(cli --json)"

# --- Another provider at the desk; one that leaves; a terminal that is a shell again -----------
term -T "codex C" "$home/src/books-fix-typos" sh -c "$t/bin/codex"
got=$(name_of "codex C" "fix-typos · Codex")
check "another provider at the desk is named without a number: '$got'" test "$got" = "fix-typos · Codex"
# Claude 1 (the desk's own, whose terminal closes with it) leaves: Claude 2 keeps its number.
pid=$(ask "(princ (getf (vikix-window-agent $(by_title Alacritty)) :pid))")
kill "$pid"; sleep 1; pass
check "the one that stays keeps its number when the first leaves: $(ask "(princ (window-user-title $(by_title "✳ Done B")))")" \
  yes "(equal (window-user-title $(by_title "✳ Done B")) \"fix-typos · Claude 2\")"
# An agent that ends and leaves a shell behind: the terminal is unnamed.
term "$t/title-d" "✳ Ready D" "$home/src/books-fix-typos" sh -c "$t/bin/claude $t/title-d; exec sleep 300"
got=$(name_of "✳ Ready D" "fix-typos · Claude 1")
check "a new Claude takes the lowest free number: '$got'" test "$got" = "fix-typos · Claude 1"
pid=$(ask "(princ (getf (vikix-window-agent $(by_title "✳ Ready D")) :pid))")
kill "$pid"; sleep 1; pass
check "its agent gone and a shell in its place, the terminal is unnamed" \
  yes "(and (null (window-user-title $(by_title "✳ Ready D"))) (null (xlib:get-property (window-xwin $(by_title "✳ Ready D")) :_VIKIX_DESK)))"
# An agent that ends and another agent runs in the same terminal: renamed for that one.
term "$t/title-e" "✳ Ready E" "$home/src/books-fix-typos" sh -c "$t/bin/claude $t/title-e; exec $t/bin/agy"
got=$(name_of "✳ Ready E" "fix-typos · Claude 1")
pid=$(ask "(princ (getf (vikix-window-agent $(by_title "✳ Ready E")) :pid))")
kill "$pid"; sleep 1; pass
check "another agent in the same terminal: named for it: $(ask "(princ (window-user-title $(by_title "✳ Ready E")))")" \
  yes "(equal (window-user-title $(by_title "✳ Ready E")) \"fix-typos · Antigravity\")"

# --- Off a desk: home, the project's own folder; a name the user gave -------------------------------
term "$t/title-f" "✳ Home F" "$home" "$t/bin/claude" "$t/title-f"
term "$t/title-g" "✳ Own G" "$home/src/books" "$t/bin/claude" "$t/title-g"
sleep 4; pass
check "an agent in the home folder is not at a desk: unnamed" yes "(null (window-user-title $(by_title "✳ Home F")))"
check "nor one in the project's own folder" yes "(null (window-user-title $(by_title "✳ Own G")))"
ask "(setf (window-user-title $(by_title "✳ Done B")) \"mine\")" >/dev/null
pass
check "a name the user gave with title stays" yes "(equal (window-user-title $(by_title "✳ Done B")) \"mine\")"

# --- sit: the seat's folder, a name with spaces, punctuation and Unicode --------------------------------
pid=$(ask "(princ (getf (vikix-window-agent $(by_title "✳ Home F")) :pid))")
out=$(cd "$odd" && HOME=$home VIKIX_SWANK_PORT=$port VIKIX_AGENT_PID=$pid python3 "$here/bin/vikix-agents" sit 2>&1 || true)
check "the agent at home sits at the odd desk: $out" grep -q 'is seated at' <<<"$out"
sleep 0.5
got=$(ask "(princ (or (window-user-title $(by_title "✳ Home F")) \"\"))")
check "named at once for the seat's folder, not the process's, spaces, punctuation and Unicode kept: '$got'" \
  test "$got" = "ünï cøde & \"quotes\" · Claude"
check "--json agrees" python3 -c '
import json, sys
agents = json.loads(sys.argv[1])
assert any(a["desk_title"] == "ünï cøde & \"quotes\" · Claude" for a in agents), [a["desk_title"] for a in agents]
' "$(cli --json)"

# --- resume: the terminal it opens is named -----------------------------------------------------
out=$(desk books resume-me)
got=$(name_of Alacritty "resume-me · Claude")
check "a second desk's terminal is named for it: '$got'" test "$got" = "resume-me · Claude"
pid=$(ask "(princ (getf (vikix-window-agent $(by_title Alacritty)) :pid))")
kill "$pid"; sleep 1
out=$(resume resume-me)
check "resume starts an agent at the desk again: $out" grep -q 'fresh conversation with claude at ~/src/books-resume-me' <<<"$out"
got=$(name_of Alacritty "resume-me · Claude")
check "and its terminal is named for the desk: '$got'" test "$got" = "resume-me · Claude"

# --- A desk gone while its agent runs: the name stays, the colour says what is left ----------------
# The repository gets an origin; the desk's branch is merged, its worktree removed
# and its branch deleted, as .claude/release leaves things.
git init -q --bare "$t/origin.git"
git -C "$home/src/books" remote add origin "$t/origin.git"
git -C "$home/src/books" push -q -u origin main 2>/dev/null
echo note > "$home/src/books-resume-me/note.md"
git -C "$home/src/books-resume-me" add note.md; git -C "$home/src/books-resume-me" commit -q -m note
rm_win=$(by_title Alacritty)
check "nothing is asked of you while the desk stands" yes "(null (vikix-window-attention $rm_win))"
git -C "$home/src/books" merge -q --ff-only resume-me
git -C "$home/src/books" worktree remove --force "$home/src/books-resume-me"
git -C "$home/src/books" branch -q -d resume-me
pass
check "the terminal keeps its desk's name once the desk is gone: $(ask "(princ (window-user-title $rm_win))")" \
  yes "(equal (window-user-title $rm_win) \"resume-me · Claude\")"
check "and says gup: main has commits origin hasn't" yes "(eq (vikix-window-attention $rm_win) :gup)"
# The colours are the theme's: agent_released when the theme names it, else its color2.
ask '(setf (getf (getf *vikix-themes* *vikix-theme*) :agent_released) "#112233")' >/dev/null
check "the colour is the theme's agent_released" yes '(equal (vikix-attention-colour :gup) "#112233")'
ask '(progn (remf (getf *vikix-themes* *vikix-theme*) :agent_released) (setf (getf (getf *vikix-themes* *vikix-theme*) :color2) "#445566"))' >/dev/null
check "or its color2 without one" yes '(equal (vikix-attention-colour :gup) "#445566")'
check "the bar's entry is in that colour" \
  yes "(equal (vikix-window-list-entry $rm_win \"7 x\") (format nil \"^(:push)^(:fg \\\"~a\\\")7 x^(:pop)\" (vikix-attention-colour :gup)))"
check "viri's list entry goes through it" yes "(search (vikix-attention-colour :gup) (viri-window-entry $rm_win nil))"
out=$(cli)
check "vikix agents says gup: $(grep -i 'gup' <<<"$out")" grep -q 'its desk is gone; main has commits to push: gup' <<<"$out"
check "--json has attention gup" python3 -c '
import json, sys
agents = json.loads(sys.argv[1])
assert any(a["attention"] == "gup" and a["desk_title"] == "resume-me · Claude" for a in agents), [(a["desk_title"], a.get("attention")) for a in agents]
' "$(cli --json)"
# Pushed: the terminal can go.
git -C "$home/src/books" push -q origin main 2>/dev/null
sleep 5   # the ref files are read again five seconds on
pass
check "once pushed, close" yes "(eq (vikix-window-attention $rm_win) :close)"
ask '(setf (getf (getf *vikix-themes* *vikix-theme*) :color6) "#778899")' >/dev/null
check "in the theme's colour for it (color6 without agent_pushed)" yes '(equal (vikix-attention-colour :close) "#778899")'
check "the listing says to close the terminal" grep -q 'its desk is gone and main is pushed: close the terminal' <<<"$(cli)"
# The agent asks: seen at once from its note, without a pass, and over the rest.
xid=$(ask "(princ (xlib:window-id (window-xwin $rm_win)))")
mkdir -p "$home/.local/state/vikix/agents"
printf 'ask 1700000000\n%s\nMay I?\n' "$home/src/books-resume-me" > "$home/.local/state/vikix/agents/$xid"
check "an agent that asks is asks, from its note, before any pass" yes "(eq (vikix-window-attention $rm_win) :asks)"
ask '(setf (getf (getf *vikix-themes* *vikix-theme*) :agent_asks) "#aabbcc")' >/dev/null
check "in the theme's colour for asking" yes '(equal (vikix-attention-colour :asks) "#aabbcc")'
rm -f "$home/.local/state/vikix/agents/$xid"
check "the note gone, what the pass found is back" yes "(eq (vikix-window-attention $rm_win) :close)"
check "a terminal with no agent needs nothing" yes "(null (vikix-window-attention $(by_title Shell)))"
# A window named away (a desktop from before did that as the desk went) and the
# repository forgotten: the name and the colour come back from the folder alone.
pid=$(ask "(princ (getf (vikix-window-agent $rm_win) :pid))")
ask "(progn (xlib:delete-property (window-xwin $rm_win) :_VIKIX_DESK) (remhash $rm_win *vikix-agent-marks*) (setf (window-user-title $rm_win) nil) (remhash $pid *vikix-agent-repos*))" >/dev/null
pass
check "the name is back from the folder alone: $(ask "(princ (window-user-title $rm_win))")" yes "(equal (window-user-title $rm_win) \"resume-me · Claude\")"
check "and so is the colour" yes "(eq (vikix-window-attention $rm_win) :close)"

# --- A reload: one hook, one wrapper, the names as they were ------------------------------------
before=$(sets)
ask '(loadrc)' >/dev/null; sleep 2
check "after a reload the hook is there once" test "$(ask '(princ (count (quote vikix-agent-title-new-window) *new-window-hook*))')" = 1
check "and the wrapper on update-window-properties once" yes "(sb-int:encapsulated-p 'update-window-properties 'vikix-agent-title)"
printf '%s' "◐ Working F" > "$t/title-f"
for _ in $(seq 1 20); do yes "$(by_title "◐ Working F")" && break; sleep 0.25; done
sleep 1.5
check "a title change after the reload names nothing again: $before sets before, $(sets) after" test "$(sets)" = "$before"
check "the name as it was: $(ask "(princ (window-user-title $(by_title "◐ Working F")))")" \
  test "$(ask "(princ (window-user-title $(by_title "◐ Working F")))")" = "ünï cøde & \"quotes\" · Claude"
check "the desktop met no error" test -z "$(ls "$home/.local/state/vikix/errors" 2>/dev/null)"

wm_report titles "an agent's terminal named for its desk: started, seated, resumed; the provider's title kept apart and still read, no name again while it turns; numbered by provider at a shared desk, stable as one leaves; unnamed or renamed as the agent goes; home, the own folder and a hand-given name left alone; a desk gone keeps the name and colours the terminal gup, close or asks, the theme's colours, said in the listing; a reload leaves one hook and one wrapper"
exit "$fail"
