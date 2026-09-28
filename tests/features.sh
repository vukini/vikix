#!/usr/bin/env bash
# tests/features.sh — features and bundles (vikix add, vikix remove,
# vikix features), and the package lists they mean:
#
#   - features.list and bundles.list name only lists, features and bundles
#     that exist; every language list belongs to a feature, so none is in
#     the base by mistake
#   - with no choices file (a machine from before 0.46), every list is
#     wanted, as before, plus the old optional ones
#   - add installs only the new feature's lists, and runs the editors' and
#     languages' stages only when an editor or a language comes
#   - remove takes out what only the removed features needed (packages and
#     the features they alone needed), keeps what something else needs,
#     asks unless --yes, and keeps your comments and a linked choices file
#   - a feature with its own setup is recorded only once that succeeds
#   - the migration writes the choices of an older machine, once
#
# sudo and xbps-query are stubs: nothing is installed or removed.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
lacks() { ! grep -q -- "$1" <<<"$2"; }

export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_DIR="$here"
mkdir -p "$HOME" "$t/bin"
# xbps-query: a package is installed when it's a line of $t/installed;
# -X (what needs it) answers from $t/rdeps (lines "pkg: user-1.0_1 ...").
cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
if [ "\$1" = -X ]; then grep "^\$2:" "$t/rdeps" 2>/dev/null | cut -d: -f2; exit 0; fi
[ "\$1" = -R ] && exit 0
grep -qx "\$1" "$t/installed" 2>/dev/null
EOF
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$t/calls" > "$t/bin/sudo"
chmod +x "$t/bin/xbps-query" "$t/bin/sudo"
export PATH="$t/bin:$PATH"
: > "$t/installed" ; : > "$t/rdeps"; : > "$t/calls"
choices="$HOME/.config/vikix/features"
vx() { bash "$here/bin/vikix" "$@"; }
lib() { bash -c ". '$here/lib/common.sh'; . '$here/lib/features.sh'; $1"; }
pkgs_of() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$here/packages/$1.list"; }

# --- the data ---------------------------------------------------------------------
while IFS='|' read -r name lists needs _ _ about; do
  for l in $lists; do check "$name names a list that isn't there: $l" test -f "$here/packages/$l.list"; done
  for n in $needs; do check "$name needs '$n', which isn't a feature" lib "is_feature $n"; done
  check "$name has no line about it" test -n "$about"
done < <(lib features_rows)
while IFS='|' read -r name members _; do
  for m in $members; do check "bundle $name names '$m', which is neither" lib "is_feature $m || is_bundle $m"; done
done < <(lib bundles_rows)
base=$(lib base_lists)
check "a language list is in the base (no feature names it): $(grep lang- <<<"$base" | tr '\n' ' ')" lacks lang- "$base"
check "the base has no lists: $base" test -n "$base"
# everything and the base together are every list: what a full install had.
all=$(for l in "$here"/packages/*.list; do basename "$l" .list; done | sort)
got=$(lib 'base_lists; lists_of $(expand_features everything)' | grep -v '^optional/' | sort -u)
check "everything and the base aren't every list: $(comm -3 <(echo "$all") <(echo "$got") | tr '\n' ' ')" test "$all" = "$got"

# --- no choices file: as before 0.46 ------------------------------------------------
check "no choices file should want every list" test "$(lib wanted_lists | grep -vc '^optional/')" = "$(echo "$all" | wc -l)"
mkdir -p "$HOME/.config/vikix"; echo windows > "$HOME/.config/vikix/optional"
check "the old optional file isn't read without a choices file" has optional/windows "$(lib wanted_lists)"
rm "$HOME/.config/vikix/optional"
out=$(vx features)
check "vikix features should mark everything as there: $(grep -c '\[x\]' <<<"$out")" has '\[x\] office' "$out"
check "vikix features should say there's no choices file yet" has 'No choices file yet' "$out"

# --- add ---------------------------------------------------------------------------------
printf '# mine\nemacs\n' > "$choices"
out=$(DRY_RUN=1 vx add python 2>&1)
check "add python should also bring devtools: $(grep adding <<<"$out")" has 'adding: devtools python' "$out"
check "add python should install python's packages" has "would run: sudo xbps-install -y .*uv" "$out"
check "add python installed another feature's list (office)" lacks libreoffice "$out"
check "add python installed a base list again (firefox)" lacks 'xbps-install -y .*firefox' "$out"
check "add python ran the languages' stages" has 'stage 67-dev' "$out"
check "add python ran the editors' stage" lacks 'stage 45-editors' "$out"
check "a dry run changed the choices" test "$(grep -vc '^#' "$choices")" = 1
out=$(DRY_RUN=1 vx add neovim 2>&1)
check "add neovim should run the editors' stage" has 'stage 45-editors' "$out"
check "add neovim ran the languages' stages" lacks 'stage 65-languages' "$out"
out=$(vx add nosuchthing 2>&1) && { echo "FAIL: add of an unknown name succeeded"; fail=1; }
check "an unknown name should say so: $out" has "no feature or bundle called 'nosuchthing'" "$out"
check "an unknown name changed the choices" test "$(grep -vc '^#' "$choices")" = 1
# Windows without KVM: its setup refuses, and it isn't recorded.
out=$(VIKIX_KVM="$t/none" vx add windows 2>&1) && { echo "FAIL: add windows without KVM succeeded"; fail=1; }
check "a refused Windows setup was recorded as chosen" bash -c "! grep -qx windows '$choices'"

# --- remove -----------------------------------------------------------------------------
reset() { printf '# my choices\n%s\n' "$@" > "$choices"; : > "$t/calls"; }
installed() { for l in "$@"; do pkgs_of "$l"; done > "$t/installed"; }
installed lang-tools lang-python lang-c emacs editor-tools lang-lisp

reset emacs python
out=$(vx remove python --yes 2>&1)
check "removing python should take devtools too, which only it needed: $(grep removing: <<<"$out")" has 'removing: devtools python' "$out"
check "removing python should uninstall its packages: $(cat "$t/calls")" grep -q 'xbps-remove -Ry .*uv' "$t/calls"
check "removing python uninstalled emacs" bash -c "! grep -q 'emacs' '$t/calls'"
check "removing python should leave emacs chosen" grep -qx emacs "$choices"
check "your comment went" grep -qx '# my choices' "$choices"
check "python is still chosen" bash -c "! grep -qx python '$choices'"

reset emacs python devtools
out=$(vx remove python --yes 2>&1)
check "devtools, chosen by name, should stay: $(grep removing: <<<"$out")" has 'removing: python$' "$out"

reset python
out=$(vx remove devtools --yes 2>&1)
check "devtools, which python needs, should stay: $out" has 'devtools stays, needed by: python' "$out"
check "nothing should be uninstalled when nothing goes" test ! -s "$t/calls"

reset c python
out=$(vx remove python --yes 2>&1)
check "a package c's list also names shouldn't go (devtools stays for c)" bash -c "! grep -q 'ctags' '$t/calls'"

# nodejs is in JavaScript's list and in the editors' tools: with Emacs staying, it stays.
installed lang-tools lang-javascript emacs editor-tools
reset emacs javascript
vx remove javascript --yes >/dev/null 2>&1
check "nodejs went with javascript, though Emacs's tools need it: $(cat "$t/calls")" bash -c "! grep -q nodejs '$t/calls'"
installed lang-tools lang-python lang-c emacs editor-tools lang-lisp

reset essentials
echo 'llvm: clang-19.1_1' > "$t/rdeps"; echo llvm >> "$t/installed"
out=$(vx remove lisp --yes 2>&1)
check "a package another installed one needs should stay: $out" has 'llvm stays, needed by: clang' "$out"
check "llvm was uninstalled all the same" bash -c "! grep -q ' llvm' '$t/calls'"
check "removing lisp from essentials should leave its other features: $(grep -v '^#' "$choices" | tr '\n' ' ')" \
  test "$(grep -v '^#' "$choices" | sort | tr '\n' ' ')" = "c emacs python "
: > "$t/rdeps"

# Features without a package list (llm, local-ai, an agent) staying: remove
# once failed without a word, on the empty list names they give.
reset llm local-ai python
out=$(vx remove python --yes 2>&1) || { echo "FAIL: remove with llm and local-ai staying failed: $out"; fail=1; }
check "remove with llm and local-ai staying should remove python: $(cat "$t/calls")" grep -q 'xbps-remove -Ry .*uv' "$t/calls"
check "remove with llm and local-ai staying should keep them" grep -qx llm "$choices"

reset python
out=$(vx remove python </dev/null 2>&1) && { echo "FAIL: remove without --yes and no terminal went ahead"; fail=1; }
check "remove without a terminal should ask for --yes: $out" has -- '--yes' "$out"
check "remove without --yes changed the choices" grep -qx python "$choices"

# A choices file that is a link (into dotfiles, say) stays a link.
mkdir -p "$t/dotfiles"; printf 'emacs\npython\n' > "$t/dotfiles/features"
ln -sf "$t/dotfiles/features" "$choices"
vx remove python --yes >/dev/null 2>&1
check "the linked choices file was replaced by a plain file" test -L "$choices"
check "the removal didn't reach the linked file" bash -c "! grep -qx python '$t/dotfiles/features'"
rm "$choices"

# --- the migration ---------------------------------------------------------------------
mig=$(grep -l 'features (vikix add, vikix remove)' "$here"/migrations/*.sh)
echo windows > "$HOME/.config/vikix/optional"
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' > "$HOME/.local/bin/llm"; chmod +x "$HOME/.local/bin/llm"
bash "$mig" >/dev/null 2>&1
check "the migration should write everything, windows and llm: $(grep -v '^#' "$choices" 2>/dev/null | tr '\n' ' ')" \
  test "$(grep -v '^#' "$choices" | tr '\n' ' ')" = "everything windows llm "
echo '# kept' >> "$choices"
bash "$mig" >/dev/null 2>&1
check "a second run of the migration changed the choices" grep -qx '# kept' "$choices"

[ "$fail" = 0 ] && echo "features: the lists, add, remove (what goes, what stays), setup that refuses, and the migration"
exit "$fail"
