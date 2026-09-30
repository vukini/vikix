#!/usr/bin/env bash
# tests/update.sh — `vikix update` runs the NEW version's steps after it
# pulls, and logs both halves of the run to one file.
#
# The pull replaces bin/vikix while it runs; 0.13.0's new stage was
# skipped because bash went on with the old copy. This builds a fake
# upstream with a newer bin/vikix whose update only prints a marker, and
# updates a clone of the current tree from it. Nothing is installed.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
git_q() { git -c user.name=test -c user.email=test@example.org "$@"; }

# upstream: this working tree (committed or not), then a "newer release"
mkdir "$t/upstream"
( cd "$here" && git ls-files -z | xargs -0 cp --parents -t "$t/upstream" )
( cd "$t/upstream" && git init -q && git_q add -A && git_q commit -qm current )
git clone -q "$t/upstream" "$t/machine"
sed -i 's/^  say "updating Void"$/  say "NEW VERSION STEPS"; exit 0/' "$t/upstream/bin/vikix"
grep -q 'NEW VERSION STEPS' "$t/upstream/bin/vikix" || { echo "FAIL: test setup (no 'updating Void' line)"; exit 1; }
( cd "$t/upstream" && git_q commit -qam newer )

out=$(HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_SUDO_KEPT=1 bash "$t/machine/bin/vikix" update 2>&1)
fail=0
grep -q 'NEW VERSION STEPS' <<<"$out" || { echo "FAIL: the old version's steps ran after the pull"; fail=1; }
log=$(ls "$t"/state/logs/update-*.log 2>/dev/null | head -1)
if [ -z "$log" ]; then
  echo "FAIL: no update log in \$VIKIX_STATE/logs"; fail=1
else
  grep -q 'pulling Vikix' "$log" && grep -q 'NEW VERSION STEPS' "$log" ||
    { echo "FAIL: the log is missing one half of the run"; fail=1; }
fi
[ "$fail" = 0 ] && echo "update: restarts into the new version, and logs the whole run"

# Changes made in the checkout (another program edited TODO.md) would stop
# the pull. They're set aside, in a patch file and a stash, and the update
# goes on; an editor's leftover isn't a change (.gitignore).
upd() { HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_SUDO_KEPT=1 bash "$t/machine/bin/vikix" update 2>&1; }
( cd "$t/upstream" && echo "upstream's change" >> TODO.md && git_q commit -qam "newer still" )
echo "an edit made in the installed checkout" >> "$t/machine/README.md"
echo "(an editor's autosave)" > "$t/machine/#theme.lisp#"
echo "a note of my own" > "$t/machine/my-note.txt"
out=$(DRY_RUN=1 upd) || true
grep -q 'would set them aside' <<<"$out" || { echo "FAIL: a dry run should say it would set them aside: $out"; fail=1; }
[ -z "$(git -C "$t/machine" stash list)" ] || { echo "FAIL: a dry run made a stash"; fail=1; }
out=$(upd) || true
grep -q 'NEW VERSION STEPS' <<<"$out" || { echo "FAIL: local changes stopped the update:"; echo "$out" | tail -5 | sed 's/^/  /'; fail=1; }
grep -q "upstream's change" "$t/machine/TODO.md" || { echo "FAIL: the pull didn't bring upstream's TODO.md"; fail=1; }
grep -qE 'changed +.*/README.md' <<<"$out" || { echo "FAIL: the changes should be listed in words (changed ...): $out"; fail=1; }
grep -q 'theme.lisp#' <<<"$out" && { echo "FAIL: an editor's leftover was treated as a change"; fail=1; }
patch=$(ls "$t"/state/checkout-changes/*.patch 2>/dev/null | head -1)
[ -n "$patch" ] && grep -q 'an edit made in the installed checkout' "$patch" && grep -q 'a note of my own' "$patch" ||
  { echo "FAIL: no patch file holding the edit in \$VIKIX_STATE/checkout-changes:"
    ls -la "$t"/state/checkout-changes/ 2>&1 | sed 's/^/  /'; head -5 "$patch" 2>/dev/null | sed 's/^/  patch: /'
    grep -iE 'set aside|stash|patch|changed' <<<"$out" | sed 's/^/  said: /'; fail=1; }
grep -q 'vikix update .*: README.md' <<<"$(git -C "$t/machine" stash list)" || { echo "FAIL: the stash should be named after the update and its files"; fail=1; }
grep -q 'stash pop' <<<"$out" && { echo "FAIL: stash pop is suggested (it can clash with Vikix's files)"; fail=1; }
# (The fake newer version stops after the pull, so the end of a run isn't
# seen here: the reminder must be in cmd_update, after the stages.)
sed -n '/^cmd_update()/,/^}/p' "$here/bin/vikix" | awk '/for stage in/ { s = 1 } s && /were set aside before this update/ { ok = 1 } END { exit !ok }' ||
  { echo "FAIL: the end of an update should repeat that changes were set aside"; fail=1; }
out=$(upd) || true
grep -q 'changes of its own' <<<"$out" && { echo "FAIL: a clean checkout was said to have changes"; fail=1; }
git -C "$t/machine" stash clear

# Set-aside changes put back by hand, clashing: stop, and say how to fix it.
( cd "$t/upstream" && sed -i '1s/.*/# upstream heading/' TODO.md && git_q commit -qam "clash upstream" )
sed -i '1s/.*/# my own heading/' "$t/machine/TODO.md"
git -C "$t/machine" -c user.name=t -c user.email=t@t stash push -q
git -C "$t/machine" pull -q --ff-only 2>/dev/null
git -C "$t/machine" stash pop -q >/dev/null 2>&1 || true
out=$(upd) && { echo "FAIL: the update went on over a clash"; fail=1; }
grep -q 'clash' <<<"$out" && grep -q 'reset --hard' <<<"$out" || { echo "FAIL: a clash should be named, with how to fix it: $out"; fail=1; }
git -C "$t/machine" reset -q --hard; git -C "$t/machine" stash clear

# A commit made in the checkout: Vikix can't update over it; it says how to keep it.
echo "committed here" >> "$t/machine/README.md"; git_q -C "$t/machine" commit -qam "mine"
( cd "$t/upstream" && echo "more" >> TODO.md && git_q commit -qam "newer again" )
out=$(upd) && { echo "FAIL: the update went on over a commit of its own"; fail=1; }
grep -q 'commit(s) of its own' <<<"$out" && grep -q 'format-patch' <<<"$out" ||
  { echo "FAIL: a commit in the checkout should be named, with how to keep it: $out"; fail=1; }
git -C "$t/machine" reset -q --hard '@{u}'
[ "$fail" = 0 ] && echo "update: changes made in the checkout are set aside in a patch file and a stash, a clash or a commit there is explained, and the update goes on"

# A checkout whose remote is SSH (its owner pushes from it) still pulls
# over HTTPS: vikix update may ask for nothing but sudo's password, and SSH
# would ask for the key's passphrase even though the repo is public.
# spy_git DIR LOG — a git that, asked to pull or fetch, writes to LOG the
# URL the real git would use with the same options, and stops there (no
# network); anything else goes to the real git.
spy_git() {
  local real; real=$(command -v git)
  mkdir -p "$1"
  cat > "$1/git" <<SPY
#!/usr/bin/env bash
opts=()
while [ "\$#" -gt 0 ]; do
  case \$1 in
    -C|-c) opts+=("\$1" "\$2"); shift 2 ;;
    pull|fetch) "$real" "\${opts[@]}" ls-remote --get-url origin >> "$2"; exit 0 ;;
    *) break ;;
  esac
done
exec "$real" "\${opts[@]}" "\$@"
SPY
  chmod +x "$1/git"
}
spy_git "$t/spy" "$t/pulled-from"
for remote in git@github.com:vukini/vikix.git ssh://git@github.com/vukini/vikix.git; do
  git -C "$t/machine" remote set-url origin "$remote"
  : > "$t/pulled-from"
  PATH="$t/spy:$PATH" HOME="$t/home" VIKIX_STATE="$t/state-ssh" VIKIX_SUDO_KEPT=1 \
    bash "$t/machine/bin/vikix" update >/dev/null 2>&1 || true
  [ "$(head -n 1 "$t/pulled-from")" = https://github.com/vukini/vikix.git ] ||
    { echo "FAIL: with the remote $remote, vikix update pulls from: $(head -n 1 "$t/pulled-from")"; fail=1; }
done
[ "$fail" = 0 ] && echo "update: an SSH remote is still pulled over HTTPS, so no passphrase is asked"

# A failed stage must not stop the others, or the migrations, and must be
# named at the end. The stages are swapped for stubs, the first of which
# fails; DRY_RUN keeps xbps and the migrations to printing. The machine
# now has the fake newer bin/vikix from above, so it gets the real one back.
cp "$here/bin/vikix" "$t/machine/bin/vikix"
for s in "$t"/machine/install/[0-9]*.sh; do
  printf '#!/bin/sh\necho "STUB %s"\n' "$(basename "$s" .sh)" > "$s"
done
printf '#!/bin/sh\nexit 1\n' > "$t/machine/install/10-packages.sh"
status=0
out=$(HOME="$t/home" VIKIX_STATE="$t/state2" VIKIX_SUDO_KEPT=1 DRY_RUN=1 \
  bash "$t/machine/bin/vikix" update --pulled 2>&1) || status=$?
for s in 20-services 40-config 45-editors 65-languages 67-dev; do
  grep -q "STUB $s" <<<"$out" || { echo "FAIL: stage $s didn't run after a failed one"; fail=1; }
done
grep -q 'new migration(s)' <<<"$out" || { echo "FAIL: the migrations didn't run after a failed stage"; fail=1; }
grep -q "would run: vikix eval '(loadrc)'" <<<"$out" || { echo "FAIL: update doesn't reload StumpWM, so the old keys, bar and menu stay"; fail=1; }
grep -q 'these stages failed: 10-packages' <<<"$out" || { echo "FAIL: the failed stage isn't named at the end"; fail=1; }
[ "$status" != 0 ] || { echo "FAIL: update exits 0 although a stage failed"; fail=1; }
[ "$fail" = 0 ] && echo "update: a failed stage is reported, and the rest still run; StumpWM is reloaded"
exit "$fail"
