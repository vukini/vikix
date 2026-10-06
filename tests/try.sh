#!/usr/bin/env bash
# tests/try.sh — vikix try: a desk's work on the desktop before it is released.
#
#   The installed checkout (a clone) takes a desk's last commit, detached
#   from main, and the core update's steps run from the desk's copy of the
#   script; the try is noted, status says it, and so does vikix agents; a
#   desk by its folder, from inside it, or by its topic (vikix agents
#   desks); files uncommitted at the desk refuse it, so does the project's
#   own folder, a desk that isn't, or a repository that isn't Vikix; a dry
#   run changes nothing; vikix update core goes back to main first and
#   pulls; vikix try off goes back to main with the steps, and on main
#   already says so.
#
# In a made-up repository: git only, no network; the stages, migrations and
# the programs an update runs are stubs, so nothing on this machine changes.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME/.config/vikix"; printf '[init]\n\tdefaultBranch = main\n' > "$t/gitconfig"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
not() { ! "$@"; }

# upstream: this working tree, with the stages, the migrations and the
# programs an update runs swapped for stubs, as a project (a log); machine:
# the installed checkout, a clone of it; a desk: a worktree beside upstream.
mkdir "$t/upstream"
( cd "$here" && git ls-files -z | xargs -0 cp --parents -t "$t/upstream" )
for s in "$t"/upstream/install/[0-9]*.sh; do printf '#!/bin/sh\necho "STUB %s"\n' "$(basename "$s" .sh)" > "$s"; done
for s in "$t"/upstream/migrations/*.sh; do printf '#!/bin/sh\necho "STUB migration"\n' > "$s"; done
for p in vikix-plugin vikix-updates vikix-docs vikix-eval vikix-wallpapers vikix-esploro; do
  printf '#!/bin/sh\nexit 0\n' > "$t/upstream/bin/$p"
done
echo '# Log' > "$t/upstream/log.md"
( cd "$t/upstream" && git init -q -b main && git add -A && git commit -qm current )
git clone -q "$t/upstream" "$t/machine"
printf 'root=%s\n' "$t" > "$HOME/.config/vikix/projects"
git -C "$t/upstream" worktree add -q "$t/upstream-feature" -b feature
echo "from the desk" >> "$t/upstream-feature/README.md"
git -C "$t/upstream-feature" commit -qam "feature: README"
desk_commit=$(git -C "$t/upstream-feature" rev-parse HEAD)
main_commit=$(git -C "$t/machine" rev-parse HEAD)

vx() { VIKIX_STATE="$t/state" VIKIX_SUDO_KEPT=1 bash "$t/machine/bin/vikix" "$@" 2>&1; }
head_of() { git -C "$t/machine" rev-parse HEAD; }
on_branch() { git -C "$t/machine" symbolic-ref -q --short HEAD 2>/dev/null || echo detached; }

check "status on main: $(vx try status)" grep -q '^the desktop runs main: Vikix' <<<"$(vx try status)"
out=$(DRY_RUN=1 vx try "$t/upstream-feature") || true
check "a dry run says what it would do and changes nothing: $(grep -c 'would' <<<"$out") lines; $(head_of)" \
  bash -c "grep -q 'would.*checkout -q --detach FETCH_HEAD' <<<\"\$1\" && grep -q 'would note the try' <<<\"\$1\" && [ '$(head_of)' = '$main_commit' ] && [ ! -e '$t/state/try' ]" _ "$out"

out=$(vx try "$t/upstream-feature") && code=0 || code=$?
check "a desk by its folder: the checkout takes its commit, detached: $code $(head_of) $(on_branch)" \
  bash -c "[ $code = 0 ] && [ '$(head_of)' = '$desk_commit' ] && [ '$(on_branch)' = detached ]"
check "and says so: $(grep 'the desktop takes' <<<"$out")" grep -q "the desktop takes $t/upstream-feature: feature at ${desk_commit:0:7}, not main" <<<"$out"
check "the core update's steps ran, from the desk's copy of the script" \
  bash -c "grep -q 'STUB 10-packages' <<<\"\$1\" && grep -q 'STUB 40-config' <<<\"\$1\" && grep -q 'STUB migration' <<<\"\$1\"" _ "$out"
check "the desk's change is on the machine" grep -q 'from the desk' "$t/machine/README.md"
check "the try is noted: $(head -1 "$t/state/try" 2>/dev/null)" \
  bash -c "[ \"\$(sed -n 1p '$t/state/try')\" = '$t/upstream-feature' ] && [ \"\$(sed -n 3p '$t/state/try')\" = feature ]"
check "and said at the end of the update" grep -q "the desktop runs $t/upstream-feature (feature at ${desk_commit:0:7}" <<<"$out"
check "status says the desk: $(vx try status)" grep -q "^the desktop runs $t/upstream-feature (feature at ${desk_commit:0:7}, since 20" <<<"$(vx try status)"

printf '#!/bin/sh\necho "=> NIL"\n' > "$t/eval"; chmod +x "$t/eval"
out=$(VIKIX_STATE="$t/state" VIKIX_EVAL="$t/eval" VIKIX_PROC=/nonexistent python3 "$here/bin/vikix-agents" 2>&1)
check "vikix agents says what the desktop runs: $(head -1 <<<"$out")" \
  grep -q "^The desktop runs $t/upstream-feature (feature at ${desk_commit:0:7}; vikix try), not a release.$" <<<"$out"

# Again: uncommitted files refuse it; committed, by its topic, the try is replaced; from inside, no name.
echo "more" >> "$t/upstream-feature/README.md"
out=$(vx try feature) && code=0 || code=$?
check "files uncommitted at the desk refuse it: $code $out" \
  bash -c "[ $code != 0 ] && grep -q '1 file(s) uncommitted at .*/upstream-feature aren.t taken: commit them there first' <<<\"\$1\"" _ "$out"
git -C "$t/upstream-feature" commit -qam "feature: more"
out=$(vx try feature) && code=0 || code=$?
check "by its topic, through vikix agents desks, replacing the try: $code $(grep 'replacing' <<<"$out")" \
  bash -c "[ $code = 0 ] && grep -q 'replacing the try of $t/upstream-feature' <<<\"\$1\" && [ '$(head_of)' = '$(git -C "$t/upstream-feature" rev-parse HEAD)' ]" _ "$out"
out=$(cd "$t/upstream-feature" && vx try) && code=0 || code=$?
check "from inside the desk, no name needed: $code" bash -c "[ $code = 0 ] && grep -q 'the desktop takes $t/upstream-feature' <<<\"\$1\"" _ "$out"
out=$(cd "$t/upstream" && vx try) && code=0 || code=$?
check "the project's own folder is no desk: $code $out" bash -c "[ $code != 0 ] && grep -q 'is the project.s own folder, not a desk' <<<\"\$1\"" _ "$out"
out=$(vx try nosuch) && code=0 || code=$?
check "a desk that isn't: $out" bash -c "[ $code != 0 ] && grep -q 'no desk called nosuch: vikix agents desks lists them' <<<\"\$1\"" _ "$out"
git -C "$t" init -q other; echo x > "$t/other/x"; git -C "$t/other" add x; git -C "$t/other" commit -qm x
out=$(vx try "$t/other") && code=0 || code=$?
check "a repository that isn't Vikix: $out" bash -c "[ $code != 0 ] && grep -q \"isn't a Vikix repository\" <<<\"\$1\"" _ "$out"

# An update goes back to main first, then pulls; off goes back with the steps.
( cd "$t/upstream" && echo "newer" >> TODO.md && git commit -qam newer )
out=$(vx update core) && code=0 || code=$?
check "vikix update core goes back to main first, then pulls: $code $(on_branch); $(grep 'back from the try' <<<"$out")" \
  bash -c "[ $code = 0 ] && [ '$(on_branch)' = main ] && grep -q 'back from the try of $t/upstream-feature' <<<\"\$1\" && grep -q newer '$t/machine/TODO.md' && [ ! -e '$t/state/try' ]" _ "$out"
check "the desk's change isn't on the machine any more" not grep -q 'from the desk' "$t/machine/README.md"
out=$(vx try off) && code=0 || code=$?
check "off on main already says so: $code $out" bash -c "[ $code = 0 ] && grep -q 'the desktop runs main already' <<<\"\$1\"" _ "$out"
vx try feature >/dev/null || true
out=$(vx try off) && code=0 || code=$?
check "vikix try off goes back to main, with the steps: $code $(on_branch)" \
  bash -c "[ $code = 0 ] && [ '$(on_branch)' = main ] && grep -q 'STUB 40-config' <<<\"\$1\" && [ ! -e '$t/state/try' ]" _ "$out"
check "the machine's checkout is clean after it all" test -z "$(git -C "$t/machine" status --porcelain)"

[ "$fail" = 0 ] && echo "try: a desk's commit on the installed checkout with the core steps, by folder, from inside or by topic; refused uncommitted, off a desk or not Vikix; status and vikix agents say it; update core and off go back to main"
exit "$fail"
