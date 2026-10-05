#!/usr/bin/env bash
# tests/release.sh — .claude/release: a branch onto main, the version, the tag.
#
#   A topic is merged, VERSION goes up by one, the release commit has the
#   summary (and a co-author when given), it is tagged, and the worktree
#   and the branch are gone. When main has moved on, the topic is put on
#   top of it first. Two topics that changed the same line: the second is
#   refused and nothing changes (no version, no tag, its worktree as it
#   was). Tests that fail, changes not committed, a main folder with
#   changes of its own, a topic with nothing new: each refused, nothing
#   changed. Two releases at once both land, one after the other, with
#   numbers of their own. --plain merges without a version; --keep leaves
#   the worktree; --tests none runs none. --queue: nothing when nothing
#   is releasing; with one testing and one waiting, the one whose turn it
#   is first, each with what it is doing and its summary; a note left by a
#   release that died is cleared; none left when they have landed.
#
# In a made-up repository: git only, no network.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
command -v flock >/dev/null || { echo "release: needs flock; skipped"; exit 0; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"; printf '[init]\n\tdefaultBranch = main\n' > "$t/gitconfig"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# A repository shaped like Vikix: VERSION, .claude/release, and tests that
# pass unless the folder they run in has a file called fail.
r="$t/vikix"
mkdir -p "$r/.claude" "$r/tests"
cp "$here/.claude/release" "$r/.claude/"
printf '0.1.5\n' > "$r/VERSION"
printf 'one\ntwo\nthree\n' > "$r/words"
cat > "$r/tests/run.sh" <<'END'
#!/bin/sh
echo "run.sh $*" >> "$(dirname "$0")/../.git-test-calls" 2>/dev/null || true
while [ -e "$(dirname "$0")/../../hold" ]; do sleep 0.2; done   # held up while the test says so
[ -e "$(dirname "$0")/../fail" ] && { echo "FAIL: made to"; echo "FAILED: made"; exit 1; }
echo "all passed: made-up"
END
chmod +x "$r/tests/run.sh"
printf '.git-test-calls\n' > "$r/.gitignore"
git -C "$r" init -q
git -C "$r" add -A && git -C "$r" commit -q -m "Vikix 0.1.5: the start"
git -C "$r" tag v0.1.5

topic() {   # topic NAME FILE TEXT: a worktree with one commit that writes TEXT to FILE
  git -C "$r" worktree add -q "$t/vikix-$1" -b "$1" 2>/dev/null
  printf '%s\n' "$3" > "$t/vikix-$1/$2"
  git -C "$t/vikix-$1" add "$2" && git -C "$t/vikix-$1" commit -q -m "$1: $2"
}
release() { "$r/.claude/release" "$@" 2>&1; }
version() { cat "$r/VERSION"; }
head_of() { git -C "$r" log -1 --format=%s; }
state() { echo "$(version) $(git -C "$r" rev-parse --short HEAD) $(git -C "$r" tag | wc -l)"; }

# --- A release ---------------------------------------------------------------------
topic a file-a "from a"
out=$(release a "A thing" --co-author "Claude <c@example.com>") && code=0 || code=$?
check "a release should succeed: $code $out" test "$code" = 0
check "VERSION goes up by one: $(version)" test "$(version)" = 0.1.6
check "the release commit carries the summary: $(head_of)" test "$(head_of)" = "Vikix 0.1.6: A thing"
check "and the co-author" grep -q '^Co-Authored-By: Claude <c@example.com>$' <<<"$(git -C "$r" log -1 --format=%B)"
check "it is tagged" bash -c "git -C '$r' rev-parse -q --verify refs/tags/v0.1.6 >/dev/null"
check "the tag is on the release commit" test "$(git -C "$r" rev-parse v0.1.6)" = "$(git -C "$r" rev-parse HEAD)"
check "the topic's work is on main" test "$(cat "$r/file-a")" = "from a"
check "its worktree and branch are gone" bash -c "[ ! -e '$t/vikix-a' ] && ! git -C '$r' rev-parse -q --verify refs/heads/a >/dev/null"
check "the tests its changes reach were run, against main: $(cat "$t/vikix-a/.git-test-calls" 2>/dev/null || echo gone-with-the-worktree)" grep -q 'tests (changed)' <<<"$out"
check "it says it isn't pushed" grep -q 'not pushed' <<<"$out"

# --- main has moved on ----------------------------------------------------------------
topic b file-b "from b"; topic c file-c "from c"
release b "B" >/dev/null
out=$(release c "C") && code=0 || code=$?
check "a topic behind main is put on top of it and released: $code $out" bash -c "[ $code = 0 ] && grep -q 'main has moved on' <<<\"\$1\"" _ "$out"
check "both are there, with numbers of their own: $(version)" bash -c "[ '$(version)' = 0.1.8 ] && [ -e '$r/file-b' ] && [ -e '$r/file-c' ]"
check "main was never rewritten: every release is behind the newest" bash -c "git -C '$r' merge-base --is-ancestor v0.1.6 HEAD && git -C '$r' merge-base --is-ancestor v0.1.7 HEAD"

# --- The same line, twice -------------------------------------------------------------
topic d words "d's words"; topic e words "e's words"
release d "D" >/dev/null
before=$(state)
out=$(release e "E") && code=0 || code=$?
check "a topic that changed the same line is refused: $code $out" bash -c "[ $code != 0 ] && grep -q 'changed the same lines (words' <<<\"\$1\"" _ "$out"
check "and nothing changed: no version, no tag, no merge: $(state)" test "$(state)" = "$before"
check "its worktree is as it was, not in the middle of a rebase" bash -c "[ \"\$(cat '$t/vikix-e/words')\" = \"e's words\" ] && [ -z \"\$(git -C '$t/vikix-e' status --porcelain)\" ]"
git -C "$r" worktree remove --force "$t/vikix-e"; git -C "$r" branch -q -D e

# --- Refused, nothing changed ---------------------------------------------------------
topic f file-f "from f"; touch "$t/vikix-f/fail"; printf 'fail\n' >> "$t/vikix-f/.gitignore"; git -C "$t/vikix-f" add .gitignore; git -C "$t/vikix-f" commit -q -m "f: ignore"
before=$(state)
out=$(release f "F") && code=0 || code=$?
check "tests that fail stop it: $code $out" bash -c "[ $code != 0 ] && grep -q 'the tests failed' <<<\"\$1\" && grep -q 'Nothing merged' <<<\"\$1\"" _ "$out"
check "with nothing merged: $(state)" test "$(state)" = "$before"
check "the failures are shown" grep -q 'FAIL: made to' <<<"$out"
out=$(release f "F" --tests none) && code=0 || code=$?
check "--tests none runs none (you ran them): $code" bash -c "[ $code = 0 ] && grep -q 'tests: not run' <<<\"\$1\"" _ "$out"

topic g file-g "from g"; echo more >> "$t/vikix-g/file-g"
before=$(state)
out=$(release g "G") && code=0 || code=$?
check "changes not committed in the topic stop it: $code $out" bash -c "[ $code != 0 ] && grep -q 'not committed' <<<\"\$1\"" _ "$out"
git -C "$t/vikix-g" checkout -q -- file-g
echo stray > "$r/stray"
out=$(release g "G") && code=0 || code=$?
check "a main folder with changes of its own stops it: $code $out" bash -c "[ $code != 0 ] && grep -q 'for merging only' <<<\"\$1\"" _ "$out"
rm "$r/stray"
check "and nothing changed either time: $(state)" test "$(state)" = "$before"
out=$(release g) && code=0 || code=$?
check "no summary, no release: $code" test "$code" != 0
out=$(release nosuch "X") && code=0 || code=$?
check "a topic that isn't there: $out" grep -q 'no branch nosuch' <<<"$out"
release g "G" >/dev/null
git -C "$r" worktree add -q "$t/vikix-h" -b h
out=$(release h "H") && code=0 || code=$?
check "a topic with nothing new is refused: $out" bash -c "[ $code != 0 ] && grep -q \"nothing main hasn't\" <<<\"\$1\"" _ "$out"
git -C "$r" worktree remove "$t/vikix-h"; git -C "$r" branch -q -D h

# --- Two at once -----------------------------------------------------------------------
topic i file-i "from i"; topic j file-j "from j"
was=$(version)
release i "I" > "$t/i.out" & release j "J" > "$t/j.out" &
wait
n=${was##*.}
check "two releases at once both land: $(version); $(tail -1 "$t/i.out"); $(tail -1 "$t/j.out")" test "$(version)" = "0.1.$((n + 2))"
check "each with its own number and tag" bash -c "git -C '$r' rev-parse -q --verify refs/tags/v0.1.$((n + 1)) >/dev/null && git -C '$r' rev-parse -q --verify refs/tags/v0.1.$((n + 2)) >/dev/null"
check "and both topics' work" bash -c "[ -e '$r/file-i' ] && [ -e '$r/file-j' ]"
check "neither release is empty" bash -c "[ -n \"\$(git -C '$r' diff --name-only v0.1.$n v0.1.$((n + 1)) | grep -v VERSION)\" ] && [ -n \"\$(git -C '$r' diff --name-only v0.1.$((n + 1)) v0.1.$((n + 2)) | grep -v VERSION)\" ]"

# --- --plain, --keep ---------------------------------------------------------------------
topic k file-k "from k"
before=$(version); tags=$(git -C "$r" tag | wc -l)
out=$(release k --plain --keep) && code=0 || code=$?
check "--plain merges with no version and no tag: $code $(version)" bash -c "[ $code = 0 ] && [ '$(version)' = '$before' ] && [ \"\$(git -C '$r' tag | wc -l)\" = $tags ] && [ -e '$r/file-k' ]"
check "--keep leaves the worktree and the branch" bash -c "[ -d '$t/vikix-k' ] && git -C '$r' rev-parse -q --verify refs/heads/k >/dev/null"
check "the main folder is clean after it all" test -z "$(git -C "$r" status --porcelain)"

# --- The queue -----------------------------------------------------------------------
check "--queue with nothing releasing says so: $(release --queue)" test "$(release --queue)" = "No release is under way."
topic q1 file-q1 "q1"; topic q2 file-q2 "q2"
touch "$t/hold"
release q1 "the first of two" > "$t/q1.out" 2>&1 &
p1=$!
for _ in $(seq 1 50); do grep -q testing <<<"$(release --queue)" && break; sleep 0.2; done
release q2 --plain > "$t/q2.out" 2>&1 &
p2=$!
for _ in $(seq 1 50); do grep -q waiting <<<"$(release --queue)" && break; sleep 0.2; done
mkdir -p "$r/.git/vikix-release-queue"; printf 'ghost\ntesting (quick)\n1\n\na release that died\n' > "$r/.git/vikix-release-queue/999999"
out=$(release --queue)
check "--queue: the one whose turn it is first, testing, with its summary: $(sed -n 2p <<<"$out")" \
  grep -qE '^  q1 +testing \(changed\) +since [0-9]{2}:[0-9]{2}   the first of two$' <<<"$(sed -n 2p <<<"$out")"
check "then the one waiting, and that it brings no version: $(sed -n 3p <<<"$out")" \
  grep -qE '^  q2 +waiting for its turn +since [0-9]{2}:[0-9]{2}    ?\(no version\)$' <<<"$(sed -n 3p <<<"$out")"
check "a note left by a release that died isn't listed, and is cleared away: $(wc -l <<<"$out") lines" \
  bash -c "[ \"\$(wc -l <<<\"\$1\")\" = 3 ] && [ ! -e '$r/.git/vikix-release-queue/999999' ]" _ "$out"
check "--queue changes nothing: both still under way" bash -c "kill -0 $p1 && kill -0 $p2"
check "the one waiting is told how to see the queue" grep -q 'release --queue shows the queue' "$t/q2.out"
rm -f "$t/hold"
wait "$p1" || true; wait "$p2" || true
check "both land once the first is done: $(tail -1 "$t/q1.out"); $(tail -2 "$t/q2.out" | head -1)" bash -c "[ -e '$r/file-q1' ] && [ -e '$r/file-q2' ]"
check "and the queue is empty again, no note left: $(release --queue)" \
  bash -c "[ \"\$1\" = 'No release is under way.' ] && [ -z \"\$(ls '$r/.git/vikix-release-queue' 2>/dev/null)\" ]" _ "$(release --queue)"
check "the main folder is clean after the queue's releases" test -z "$(git -C "$r" status --porcelain)"

[ "$fail" = 0 ] && echo "release: merged, numbered and tagged; rebased when main moved; refused, with nothing changed, on a clash, failing tests or uncommitted work; two at once land in turn; --queue shows who is testing and who waits"
exit "$fail"
