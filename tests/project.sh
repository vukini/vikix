#!/usr/bin/env bash
# tests/project.sh — `vikix project` (bin/vikix-project), in a made-up home
# with made-up projects; no network, no desktop:
#   - discovery: a repo with log.md, a collection (its own LOG.md and two
#     projects in it), a public repo whose log is in ~/src/project-logs
#     (the logs repo itself no project), and what's skipped: a git
#     worktree, hidden folders, node_modules, deeper than depth;
#     ~/.config/vikix/projects (root=, logs=, depth=)
#   - list: newest entry first, the %, how long ago, the newer of the
#     Status' Next and the newest entry's, the collection, the terminal's
#     width; --all adds a project with no entries
#   - show, path; names: exact, a unique prefix or part, collection/name,
#     and an ambiguous one lists the candidates
#   - log: today's entry goes after the Status and before the newest one,
#     with --next and --status, (Vid) unless --agent or Claude Code; into
#     the log kept apart too, and a log with no entries; the rest of the
#     file unchanged; it says how to commit
#   - build: the log's Build line, build.sh (bash or sh), Makefile,
#     src/build.sh, package.json, none; runs in the folder, passes on the
#     exit status
#   - check: the log's Check line, check.sh (run itself when executable),
#     tests/run.sh, make check / make test (only a target that's there),
#     npm test, none; runs in the folder, passes on the exit status
#   - new: a folder and log listed at once, --in a collection, --private
#     (the log kept apart), ".", and it refuses a log or a worktree
#   - today: the day's entries, commits (not the day before's) and next;
#     yesterday, a date, --no-git; vikix today
#   - open: a terminal in the folder and Emacs on the log, both left
#     running; refuses without a desktop
#   - vikix project reaches it; the starter config is copied once, in
#     yours.list; the s-m entry and Super+Alt+p are there

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset CLAUDECODE XDG_CONFIG_HOME   # CLAUDECODE: run from Claude Code, a log entry would be the agent's
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
has() { grep -qF -- "$1" <<<"$2"; }
lacks() { ! grep -qF -- "$1" <<<"$2"; }
expect() { local what=$1; shift; "$@" || { echo "FAIL: $what"; fail=1; }; }

export HOME="$t/home" VIKIX_TODAY=2026-10-02 COLUMNS=200
unset DISPLAY
src="$HOME/src"
vp() { python3 "$here/bin/vikix-project" "$@"; }

# --- the projects ---------------------------------------------------------
mkdir -p "$src/alpha/.git"
cat > "$src/alpha/log.md" <<'EOF'
# Log: Alpha Book

**Status** (Alpha), as of 2026-09-20: 40% complete.

- Standing: three chapters
- Next: chapter four

Intro words after the Status.

## 2026-09-25 · chapters 1-3 (Vid)

Wrote chapter three.

Next: chapter four, the hard one

## 2026-09-10

Started.
EOF
cp "$src/alpha/log.md" "$t/alpha-before.md"

mkdir -p "$src/series/lambda-book" "$src/series/lisp-book/src" "$src/series/.git"
printf '# Log: The Series\n\n## 2026-09-01 · planned\n\nA plan.\n' > "$src/series/LOG.md"
cat > "$src/series/lambda-book/log.md" <<'EOF'
# Log: Lambda Book

**Status** (Lambda), as of 2026-09-30: 60% complete.

- Next: types, from the Status
- Build: echo built-by-line > out.txt

## 2026-09-28

Track three.

Next: older next, from an entry

## 2026-09-27

Two.

## 2026-09-26

One.

## 2026-09-20

Zero.
EOF
printf '# Log: Lisp Book\n\n## 2026-10-01 · drafts\n\nDrafts.\n\nNext: the evaluator\n' > "$src/series/lisp-book/log.md"
printf '#!/bin/sh\necho src-build\n' > "$src/series/lisp-book/src/build.sh"

# A worktree of alpha (its .git a file), hidden folders, node_modules: none count.
mkdir -p "$src/alpha-topic" "$src/.hidden" "$src/series/node_modules/x" "$src/deep/a/b"
echo "gitdir: $src/alpha/.git/worktrees/topic" > "$src/alpha-topic/.git"
for d in alpha-topic .hidden series/node_modules/x deep/a/b; do
  printf '# Log: skip me\n\n## 2026-10-01\n\nNo.\n' > "$src/$d/log.md"
done

# A public repo, its log kept in the logs repo, which is no project itself.
mkdir -p "$src/pubrepo/.git" "$src/project-logs/pubrepo" "$src/project-logs/.git"
printf '# Log: Pubrepo\n\nThis log is private.\n\n## 2026-09-29\n\nReleased.\n' > "$src/project-logs/pubrepo/log.md"
printf '# Logs\n\n## 2026-10-01\n\nnot a project\n' > "$src/project-logs/log.md"

# One with no entries yet.
mkdir -p "$src/empty"
printf '# Log: Empty\n\n**Status**, as of 2026-09-01: 0%% complete.\n\n- Next: begin\n' > "$src/empty/log.md"

# --- list -----------------------------------------------------------------
out=$(vp list)
names=$(awk '{print $1}' <<<"$out" | tr '\n' ' ')
expect "list's order, newest first (got: $names)" \
  test "$names" = "series/lisp-book pubrepo series/lambda-book alpha series "
expect "a worktree, hidden folders, node_modules or a too-deep folder was listed: $out" \
  lacks "skip" "$(vp show alpha-topic 2>&1; vp list --all)"
for n in alpha-topic hidden deep node_modules project-logs; do
  expect "$n is no project" lacks "$n" "$(vp list --all)"
done
alpha=$(grep '^alpha ' <<<"$out")
expect "list: alpha's %, date and how long ago: $alpha" has "40%  2026-09-25 (7 days ago)" "$alpha"
expect "list: the entry's Next, newer than the Status': $alpha" has "chapter four, the hard one" "$alpha"
lam=$(grep '^series/lambda-book' <<<"$out")
expect "list: the Status' Next, newer than the entry's: $lam" has "types, from the Status" "$lam"
expect "list: today and yesterday" has "(yesterday)" "$(grep lisp-book <<<"$out")"
expect "list leaves out a project with no entries" lacks "empty" "$out"
expect "list --all has it" has "no entries yet" "$(vp list --all | grep '^empty')"
expect "list: no line wider than COLUMNS" test "$(COLUMNS=50 vp list | awk '{ if (length($0) > m) m = length($0) } END { print m }')" -le 50
expect "list: a cut line ends with …" has "…" "$(COLUMNS=50 vp list)"
expect "vikix project (no command) is list" test "$(vp)" = "$out"

# --- show, path, names ----------------------------------------------------
s=$(vp show lambda)
expect "show: the title" has "Lambda Book" "$s"
expect "show: the folder" has "folder:  $src/series/lambda-book" "$s"
expect "show: the Status" has "**Status** (Lambda), as of 2026-09-30: 60% complete." "$s"
expect "show: the build line" has "build:   echo built-by-line" "$s"
expect "show: the last 3 of 4 entries" has "The last 3 of 4 entries" "$s"
expect "show: the third entry, not the fourth" bash -c 'has() { grep -qF -- "$1" <<<"$2"; }; has "## 2026-09-26" "$1" && ! has "## 2026-09-20" "$1"' _ "$s"
expect "show: a log kept apart says so" has "$src/project-logs/pubrepo/log.md (kept apart" "$(vp show pubrepo)"
expect "path: exact" test "$(vp path alpha)" = "$src/alpha"
expect "path: a unique prefix" test "$(vp path lam)" = "$src/series/lambda-book"
expect "path: a unique part" test "$(vp path isp)" = "$src/series/lisp-book"
expect "path: collection/name" test "$(vp path series/lisp-book)" = "$src/series/lisp-book"
expect "path: the collection itself" test "$(vp path series)" = "$src/series"
expect "path: the public repo is its folder, not the log's" test "$(vp path pubrepo)" = "$src/pubrepo"
set +e; amb=$(vp path book 2>&1); rc=$?; set -e
expect "an ambiguous name fails with 2 (got $rc)" test "$rc" = 2
expect "an ambiguous name lists the candidates: $amb" bash -c 'grep -q "series/lambda-book" <<<"$1" && grep -q "series/lisp-book" <<<"$1"' _ "$amb"
expect "no such project fails" bash -c '! python3 "$1" path nothing-like-it 2>/dev/null' _ "$here/bin/vikix-project"

# --- the config -----------------------------------------------------------
mkdir -p "$HOME/.config/vikix" "$t/other/proj" "$t/other/deep/a/b"
printf '# Log: Other\n\n## 2026-09-01\n\nx\n' > "$t/other/proj/log.md"
printf '# Log: Deep\n\n## 2026-09-01\n\nx\n' > "$t/other/deep/a/b/log.md"
printf 'root=%s   # mine\nroot=~/src\ndepth=3\nlogs=~/nowhere\n' "$t/other" > "$HOME/.config/vikix/projects"
cl=$(vp list)
expect "config: a second root" has "proj" "$cl"
expect "config: depth=3 reaches a/b" has "deep/a/b" "$cl"
expect "config: another logs folder, so the repo pubrepo has no log" bash -c '! grep -q "^pubrepo " <<<"$1"' _ "$cl"
rm "$HOME/.config/vikix/projects"

# --- log ------------------------------------------------------------------
w=$(vp log alpha "Wrote chapter four." --next "chapter five" --status "four of ten")
expect "log says where it wrote: $w" has "$src/alpha/log.md" "$w"
expect "log says how to commit, without committing: $w" has "git -C $src/alpha commit" "$w"
expected=$(sed -n '1,/^Intro words/p' "$t/alpha-before.md"; printf '\n## 2026-10-02 · four of ten (Vid)\n\nWrote chapter four.\n\nNext: chapter five\n\n'; sed -n '/^## 2026-09-25/,$p' "$t/alpha-before.md")
expect "log: the entry after the intro, before the newest (diff below)" test "$(cat "$src/alpha/log.md")" = "$expected"
[ "$(cat "$src/alpha/log.md")" = "$expected" ] || diff <(echo "$expected") "$src/alpha/log.md" || true
expect "log: list now has today's entry and its Next" has "2026-10-02 (today)        chapter five" "$(vp list | grep '^alpha')"
vp log alpha "By the agent." --agent >/dev/null
expect "log --agent: not marked (Vid)" grep -qx '## 2026-10-02' "$src/alpha/log.md"
CLAUDECODE=1 vp log alpha "From Claude Code." >/dev/null
expect "log from Claude Code: not marked (Vid)" test "$(grep -c '^## 2026-10-02$' "$src/alpha/log.md")" = 2
expect "log: the newest is on top" test "$(grep -m1 -A2 '^## ' "$src/alpha/log.md" | tail -1)" = "From Claude Code."
vp log pubrepo "A fix." >/dev/null
expect "log: into the log kept apart" grep -qx '## 2026-10-02 (Vid)' "$src/project-logs/pubrepo/log.md"
expect "log: the repo itself gets no log.md" test ! -e "$src/pubrepo/log.md"
expect "log: the intro of the log kept apart stays first" test "$(sed -n 3p "$src/project-logs/pubrepo/log.md")" = "This log is private."
vp log empty "Begun." >/dev/null
expect "log: a log with no entries gets one at the end" test "$(tail -3 "$src/empty/log.md" | head -1)" = "## 2026-10-02 (Vid)"
expect "log: the Status stays above it" test "$(grep -n -- '- Next: begin' "$src/empty/log.md" | cut -d: -f1)" -lt "$(grep -n '^## ' "$src/empty/log.md" | cut -d: -f1)"
expect "log without what was done fails" bash -c '! python3 "$1" log alpha 2>/dev/null' _ "$here/bin/vikix-project"
expect "log: no git repo, it says so" has "isn't in a git repo" "$(vp log empty "Two.")"

# --- build ----------------------------------------------------------------
mkdir -p "$src/b-bash" "$src/b-sh" "$src/b-make" "$src/b-npm" "$src/b-none" "$src/b-fail"
for d in b-bash b-sh b-make b-npm b-none b-fail; do printf '# Log: %s\n\n## 2026-09-01\n\nx\n' "$d" > "$src/$d/log.md"; done
printf '#!/usr/bin/env bash\necho "built in $PWD" > out.txt\n' > "$src/b-bash/build.sh"
printf '#!/bin/sh\necho hi\n' > "$src/b-sh/build.sh"
printf 'all:\n\techo made\n' > "$src/b-make/Makefile"
printf '{"scripts":{"build":"true"}}\n' > "$src/b-npm/package.json"
printf '#!/bin/sh\nexit 3\n' > "$src/b-fail/build.sh"
expect "build: build.sh with bash" has "b-bash: bash build.sh" "$(vp build b-bash -n)"
expect "build: build.sh with sh" has "b-sh: sh build.sh" "$(vp build b-sh -n)"
expect "build: Makefile" has "b-make: make" "$(vp build b-make -n)"
expect "build: src/build.sh" has "series/lisp-book: sh src/build.sh" "$(vp build lisp-book -n)"
expect "build: package.json" has "b-npm: npm run build" "$(vp build b-npm -n)"
expect "build: the log's Build line first" has "echo built-by-line > out.txt  (the log's Build line)" "$(vp build lambda -n)"
expect "build: nothing to run fails" bash -c '! python3 "$1" build b-none 2>/dev/null' _ "$here/bin/vikix-project"
expect "build -n runs nothing" test ! -e "$src/b-bash/out.txt"
(cd "$t" && vp build b-bash >/dev/null)
expect "build runs in the project's folder" grep -qx "built in $src/b-bash" "$src/b-bash/out.txt"
vp build lambda >/dev/null
expect "build: the Build line runs in the folder" grep -qx built-by-line "$src/series/lambda-book/out.txt"
set +e; bo=$(vp build b-fail 2>&1); rc=$?; set -e
expect "build passes on the exit status (got $rc)" test "$rc" = 3
expect "build says it failed: $bo" has "the build failed (exit status 3)" "$bo"

# --- check ----------------------------------------------------------------
mkdir -p "$src/c-line" "$src/c-exec" "$src/c-tests/tests" "$src/c-make" "$src/c-maketest" "$src/c-npm" "$src/c-none"
for d in c-line c-exec c-tests c-make c-maketest c-npm c-none; do printf '# Log: %s\n\n## 2026-09-01\n\nx\n' "$d" > "$src/$d/log.md"; done
printf '# Log: c-line\n\n**Status**, as of 2026-09-01: 1%% complete.\n\n- Check: echo checked-by-line > out.txt\n\n## 2026-09-01\n\nx\n' > "$src/c-line/log.md"
printf '#!/bin/sh\necho "checked in $PWD" > out.txt; exit 4\n' > "$src/c-exec/check.sh"; chmod +x "$src/c-exec/check.sh"
printf 'echo t\n' > "$src/c-tests/tests/run.sh"
printf 'all:\n\techo a\ncheck:\n\techo c\n' > "$src/c-make/Makefile"
printf 'all:\n\techo a\ntest: all\n\techo t\n' > "$src/c-maketest/Makefile"
printf '{"scripts":{"test":"true"}}\n' > "$src/c-npm/package.json"
printf 'all:\n\techo a\n' > "$src/c-none/Makefile"
expect "check: the log's Check line first" has "echo checked-by-line > out.txt  (the log's Check line)" "$(vp check c-line -n)"
expect "check: an executable check.sh" has "c-exec: ./check.sh" "$(vp check c-exec -n)"
expect "check: tests/run.sh, not executable, with bash" has "c-tests: bash tests/run.sh" "$(vp check c-tests -n)"
expect "check: make check" has "c-make: make check" "$(vp check c-make -n)"
expect "check: make test" has "c-maketest: make test" "$(vp check c-maketest -n)"
expect "check: npm test" has "c-npm: npm test" "$(vp check c-npm -n)"
expect "check: a Makefile without check or test is nothing to run" bash -c '! python3 "$1" check c-none 2>/dev/null' _ "$here/bin/vikix-project"
expect "show: the check line" has "check:   echo checked-by-line" "$(vp show c-line)"
vp check c-line >/dev/null
expect "check: the Check line runs in the folder" grep -qx checked-by-line "$src/c-line/out.txt"
set +e; co=$( (cd "$t" && vp check c-exec) 2>&1); rc=$?; set -e
expect "check passes on the exit status (got $rc)" test "$rc" = 4
expect "check runs in the project's folder" grep -qx "checked in $src/c-exec" "$src/c-exec/out.txt"
expect "check says it failed: $co" has "the checks failed (exit status 4)" "$co"

# --- new ------------------------------------------------------------------
n=$(vp new fresh-book --title "A Fresh Book" --next "an outline")
expect "new: says what it made: $n" has "made $src/fresh-book/log.md (and the folder" "$n"
expect "new: the title" grep -qx '# Log: A Fresh Book' "$src/fresh-book/log.md"
expect "new: a Status with today's date" grep -qx '\*\*Status\*\*, as of 2026-10-02: 0% complete.' "$src/fresh-book/log.md"
expect "new: the Next" grep -qx -- '- Next: an outline' "$src/fresh-book/log.md"
expect "new: a first entry, so list has it" has "fresh-book" "$(vp list)"
expect "new: list shows its Next" has "an outline" "$(vp list | grep '^fresh-book')"
expect "new: a default title from the name" bash -c 'python3 "$1" new other-thing >/dev/null && grep -qx "# Log: Other thing" "$2/other-thing/log.md"' _ "$here/bin/vikix-project" "$src"
expect "new: refuses a folder that has a log" bash -c '! python3 "$1" new alpha 2>/dev/null' _ "$here/bin/vikix-project"
expect "new: alpha's log untouched" grep -q '^Wrote chapter four.$' "$src/alpha/log.md"
vp new chapter-x --in series >/dev/null
expect "new --in: inside the collection" test -f "$src/series/chapter-x/log.md"
expect "new --in: listed as the collection's" has "series/chapter-x" "$(vp list)"
mkdir -p "$src/secret/.git"
p=$(vp new secret --private)
expect "new --private: the log in the logs folder" test -f "$src/project-logs/secret/log.md"
expect "new --private: none in the repo" test ! -e "$src/secret/log.md"
expect "new --private: says it is kept apart: $p" has "kept apart from the repo $src/secret" "$p"
expect "new --private: listed with the repo's folder" test "$(vp path secret)" = "$src/secret"
expect "new --private: no repo yet, it says so" has "is a git repo" "$(vp new later-repo --private)"
mkdir -p "$src/existing"
(cd "$src/existing" && vp new . >/dev/null)
expect "new .: the folder it is run in" test -f "$src/existing/log.md"
mkdir -p "$src/wt2"; echo "gitdir: $src/alpha/.git/worktrees/wt2" > "$src/wt2/.git"
set +e; wo=$(vp new "$src/wt2" 2>&1); set -e
expect "new: refuses a git worktree: $wo" has "is a git worktree" "$wo"
expect "new: no log in the worktree" test ! -e "$src/wt2/log.md"
expect "new: a folder outside the roots, it says so" has "doesn't see it" "$(vp new "$t/elsewhere")"
expect "new without a name fails" bash -c '! python3 "$1" new 2>/dev/null' _ "$here/bin/vikix-project"
expect "new --in and --private together fail" bash -c '! python3 "$1" new x --in series --private 2>/dev/null' _ "$here/bin/vikix-project"

# --- today ----------------------------------------------------------------
g() { git -C "$src/gitproj" -c user.name=T -c user.email=t@t -c commit.gpgsign=false "$@"; }
mkdir -p "$src/gitproj"
git -C "$src/gitproj" init -q
printf '# Log: Gitproj\n\n**Status**, as of 2026-09-01: 5%% complete.\n\n- Next: from the status\n\n## 2026-10-01 · yesterday words\n\nDid yesterday.\n\nNext: yesterday next\n' > "$src/gitproj/log.md"
g add log.md
GIT_AUTHOR_DATE=2026-10-01T15:00 GIT_COMMITTER_DATE=2026-10-01T15:00 g commit -qm "Yesterday's commit"
echo x > "$src/gitproj/f"; g add f
GIT_AUTHOR_DATE=2026-10-02T09:00 GIT_COMMITTER_DATE=2026-10-02T09:00 g commit -qm "Today's commit"
td=$(vp today)
expect "today: the heading" has "Today 2026-10-02" "$td"
expect "today: alpha's entries of today: $td" has "four of ten (Vid): Wrote chapter four." "$td"
expect "today: alpha's next" has "next: chapter five" "$td"
expect "today: the commits of the day" has "Today's commit" "$td"
expect "today: not yesterday's commit" lacks "Yesterday's commit" "$td"
expect "today: a project with nothing that day is left out" lacks "lambda-book" "$td"
expect "today --no-git: no commits" lacks "Today's commit" "$(vp today --no-git)"
y=$(vp today yesterday)
expect "today yesterday: that day" has "On 2026-10-01 (yesterday)" "$y"
expect "today yesterday: its entry and commit" bash -c 'grep -qF "yesterday words: Did yesterday." <<<"$1" && grep -qF "Yesterday'"'"'s commit" <<<"$1"' _ "$y"
expect "today DATE: an empty day says so" has "nothing logged or committed" "$(vp today 2020-01-01)"
expect "today: a bad date fails" bash -c '! python3 "$1" today someday 2>/dev/null' _ "$here/bin/vikix-project"
expect "vikix today reaches it" test "$(bash "$here/bin/vikix" today --no-git)" = "$(vp today --no-git)"

# --- open -----------------------------------------------------------------
mkdir -p "$t/bin"
for p in alacritty emacsclient; do
  printf '#!/bin/sh\necho "$PWD|$*" > "%s/%s.ran"\n' "$t" "$p" > "$t/bin/$p"
  chmod +x "$t/bin/$p"
done
expect "open refuses without a desktop" bash -c '! PATH="$2:$PATH" python3 "$1" open alpha 2>/dev/null' _ "$here/bin/vikix-project" "$t/bin"
PATH="$t/bin:$PATH" DISPLAY=:99 vp open alpha >/dev/null
for _ in $(seq 50); do [ -s "$t/alacritty.ran" ] && [ -s "$t/emacsclient.ran" ] && break; sleep 0.1; done
expect "open: a terminal in the folder ($(cat "$t/alacritty.ran" 2>/dev/null))" grep -qx "$src/alpha|" "$t/alacritty.ran"
expect "open: Emacs on the log, not waiting ($(cat "$t/emacsclient.ran" 2>/dev/null))" grep -qx "$src/alpha|-n -c -a  $src/alpha/log.md" "$t/emacsclient.ran"

# --- the rest of Vikix ----------------------------------------------------
expect "vikix project reaches it" test "$(bash "$here/bin/vikix" project path alpha)" = "$src/alpha"
expect "vikix help names it" has "vikix project" "$(bash "$here/bin/vikix" help)"
expect "the starter config is copied once" grep -q 'copy_user "$C/projects/projects" *"$HOME/.config/vikix/projects"' "$here/install/40-config.sh"
expect "the starter config is in yours.list" grep -q '^\.config/vikix/projects ' "$here/config/yours.list"
expect "the starter config's lines are all comments (the defaults stand)" bash -c '! grep -v "^#" "$1" | grep -q .' _ "$here/config/projects/projects"
expect "Super+m has Projects" grep -q '"vikix-project pick"' "$here/config/stumpwm/vikix/commands.lisp"
expect "Super+Alt+p picks a project" grep -q '("s-M-p" *"exec vikix-project pick"' "$here/config/stumpwm/vikix/keys.lisp"

[ "$fail" = 0 ] && echo "project: all passed"
exit "$fail"
