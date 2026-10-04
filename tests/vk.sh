#!/usr/bin/env bash
# tests/vk.sh — less typing: a command by the start of its name when only one
# begins so, an ambiguous start naming the candidates (exit 2), the next word
# made whole when it starts exactly one of the command's own (from the
# scripts' usage lines), a free word (a theme, a message) left as it is; Tab
# completion's lists (commands, a command's words, themes, features); vk
# linked by 40-config, and the completion in vikix.bash.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home"; mkdir -p "$HOME"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
vk() { bash "$here/bin/vikix" "$@"; }

check "vk vers is vikix version" test "$(vk vers)" = "$(cat "$here/VERSION")"
check "vk upd --help is vikix update's help" grep -q 'vikix update core' <<<"$(vk upd --help)"
set +e; out=$(vk d 2>&1); code=$?; set -e
check "an ambiguous start should exit 2: $code" test "$code" = 2
check "and name the candidates: $out" grep -q 'could be: debug diagnose dictate docs doctor' <<<"$out"
check "vk docs f is docs find" grep -q 'find what' <<<"$(vk docs f 2>&1 || true)"
check "an unknown command is still said" grep -q 'unknown command: zzz' <<<"$(vk zzz 2>&1 || true)"

# Completion's lists.
cmds=$(vk __complete 1)
check "commands, without help's dashes" bash -c '! grep -q -- "^-" <<<"$1" && grep -qx theme <<<"$1" && grep -qx docs <<<"$1"' _ "$cmds"
check "docs' words, from its usage lines only" test "$(vk __complete 2 docs | tr '\n' ' ')" = "find get index open pick read status "
check "theme: import and the themes" bash -c 'grep -qx import <<<"$1" && grep -qx paper <<<"$1" && grep -qx void <<<"$1"' _ "$(vk __complete 2 th)"
check "add: the features" bash -c 'grep -qx python <<<"$1" && grep -qx emacs <<<"$1"' _ "$(vk __complete 2 add)"
check "screens' words" test "$(vk __complete 2 scr | tr '\n' ' ')" = "auto extend external laptop mirror pick "

# A free word stays as it is: a theme's name isn't made into a subcommand.
check "vk theme pa isn't made into vk theme import" grep -q "no theme called 'pa'" <<<"$(DISPLAY= vk theme pa 2>&1 || true)"

# The completion function in vikix.bash, with vikix on PATH.
mkdir -p "$t/bin"; ln -s "$here/bin/vikix" "$t/bin/vikix"; ln -s "$here/bin/vikix" "$t/bin/vk"
out=$(PATH="$t/bin:$PATH" bash -c '
  source <(sed -n "/^_vikix_complete()/,/^complete -F/p" "$1/config/bash/vikix.bash")
  t() { COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]}-1)); _vikix_complete; echo "${COMPREPLY[*]}"; }
  t vk the; t vk theme pa; t vk docs f' _ "$here")
check "Tab completes: $out" test "$out" = $'theme\npaper\nfind'
check "40-config links vk" grep -q 'link_managed "$VIKIX_DIR/bin/vikix" "$HOME/.local/bin/vk"' "$here/install/40-config.sh"

[ "$fail" = 0 ] && echo "vk: commands and their words by the start of the name, ambiguous ones named, free words left alone, Tab completion's lists"
exit "$fail"
