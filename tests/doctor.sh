#!/usr/bin/env bash
# tests/doctor.sh — vikix doctor, in a made-up home and checkout with
# stand-ins for the programs, the services and the desktop: all good when
# all is; a fault with one safe answer is said with what --fix would do,
# and the plain run's end lists them; --fix --yes mends a service not
# enabled, a link of Vikix's that is broken or gone (the old moved aside),
# ~/.slime-secret's and the secrets folder's modes (nothing in them read),
# the manual and man pages from another Vikix (40-config run again), and
# the plugins behind the pin (vikix plugin sync); DRY_RUN=1 prints instead;
# --fix without --yes and without a terminal leaves everything as it is; a
# link into another checkout is said, not counted; the records an update
# kept are said; a checkout on no branch is a fault, a desk's commit tried
# is said; help and a bad option.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY VIKIX_SOCKET VIKIX_PLUGINS_COMMIT DRY_RUN
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
no() { ! "$@"; }
git_q() { git -c user.name=t -c user.email=t@t "$@"; }

export HOME="$t/home"
v="$t/vikix"   # the checkout
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/info" "$HOME/.local/share/man/man1" "$HOME/.local/share/vikix" "$HOME/.local/state/vikix/yours.git" \
         "$HOME/.config/vikix" "$HOME/.stumpwm.d" "$HOME/.claude/skills" "$t/bin" "$t/sv" "$t/service" "$t/run" \
         "$v/bin" "$v/lib" "$v/install" "$v/config/stumpwm/vikix" "$v/config/x11" "$v/config/bash" "$v/config/claude/skills/vikix" "$v/docs"
# The checkout: the doctor, what it sources, what it reads, and stand-ins
# for the scripts it runs (each writes down what it was asked).
cp "$here/bin/vikix-doctor" "$v/bin/"
cp "$here/lib/common.sh" "$here/lib/features.sh" "$v/lib/"
cp "$here/features.list" "$here/bundles.list" "$v/"
printf 'dbus\nelogind\n' > "$v/services.list"
printf '0.72.200\n' > "$v/VERSION"
printf 'QL_DIST="2026-01-01"\n' > "$v/install/30-lisp.sh"
printf '#!/bin/sh\necho ran >> "%s/40-config.ran"\n' "$t" > "$v/install/40-config.sh"
printf '#!/bin/sh\nexit 0\n' > "$v/bin/vikix"
printf '# a guide\n' > "$v/docs/README.md"
printf '(in-package :stumpwm)\n' > "$v/config/stumpwm/init.lisp"
printf 'exec vikix-session\n' > "$v/config/x11/xinitrc"
printf ': vikix\n' > "$v/config/bash/vikix.bash"
printf '# the skill\n' > "$v/config/claude/skills/vikix/SKILL.md"
for s in vikix-backup vikix-local-ai vikix-windows vikix-steam vikix-ai vikix-plugin; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/asked"\nexit 0\n' "$s" "$t" > "$v/bin/$s"
done
printf 'PLUGINS_COMMIT=${VIKIX_PLUGINS_COMMIT:-1111111111111111111111111111111111111111}   # the pin\n' >> "$v/bin/vikix-plugin"
chmod +x "$v/bin/"* "$v/install/40-config.sh"
git_q -C "$v" init -q && git_q -C "$v" add -A && git_q -C "$v" commit -q -m one
# The programs, as names on PATH; sudo runs what it is given; makeinfo is
# there so the manual is looked at; nothing else of the machine's.
for p in sbcl stumpwm alacritty rofi picom dunst pipewire i3lock firefox nmtui clipmenu maim restic makeinfo; do
  printf '#!/bin/sh\n' > "$t/bin/$p"; chmod +x "$t/bin/$p"
done
printf '#!/bin/sh\nexec "$@"\n' > "$t/bin/sudo"; chmod +x "$t/bin/sudo"
export PATH="$t/bin:/usr/bin:/bin" VIKIX_SV_DIR="$t/sv" VIKIX_SERVICE_DIR="$t/service" XDG_RUNTIME_DIR="$t/run"
# The machine as 40-config leaves it: the services, the links, the
# password, the manual and the pages of this Vikix, no feature chosen.
for sv in dbus elogind NetworkManager; do mkdir -p "$t/sv/$sv"; ln -s "$t/sv/$sv" "$t/service/$sv"; done
ln -s "$v/config/stumpwm/init.lisp" "$HOME/.stumpwm.d/init.lisp"
ln -s "$v/config/stumpwm/vikix" "$HOME/.stumpwm.d/vikix"
ln -s "$v/config/x11/xinitrc" "$HOME/.xinitrc"
ln -s "$v/bin/vikix" "$HOME/.local/bin/vikix"
ln -s "$v/config/bash/vikix.bash" "$HOME/.config/vikix/vikix.bash"
ln -s "$v/config/claude/skills/vikix" "$HOME/.claude/skills/vikix"
( umask 077; echo secret > "$HOME/.slime-secret" )
printf 'The guides.\n\nFor Vikix 0.72.200.\n' > "$HOME/.local/share/info/vikix.info"
printf '.TH "VIKIX" 1 "2026-10-22" "Vikix 0.72.200" "Vikix"\n' > "$HOME/.local/share/man/man1/vikix.1"
printf '# agents\n' > "$HOME/.local/share/vikix/AGENTS.md"
: > "$HOME/.config/vikix/features"
# Vikix's socket, answering (vikix-eval's stand-in says 1).
python3 -c 'import socket, os, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); os.chmod(sys.argv[1], 0o600)' "$t/run/vikix.sock"
printf 'import sys\nprint(1)\n' > "$v/bin/vikix-eval"

doc() { bash "$v/bin/vikix-doctor" "$@" 2>&1; }
plain() { out=$(doc "$@") && code=0 || code=$?; }

echo "--- all good"
plain
check "all good exits 0: $code: $out" test "$code" = 0
check "and says so" grep -q ':: all good' <<<"$out"
check "the links are this checkout's: $out" grep -q "links point into $v" <<<"$out"
check "the manual and the pages are this Vikix's" grep -q "this Vikix's (0.72.200)" <<<"$out"
check "no fix is offered" no grep -q 'fix would' <<<"$out"
check "the stand-ins were asked (backup doctor, ai key check)" grep -q 'vikix-ai key check' "$t/asked"

echo "--- a service not enabled: said with its fix, listed at the end, enabled on --fix --yes"
rm "$t/service/elogind"
plain
check "a fault exits 1: $code" test "$code" = 1
check "the service is named: $out" grep -q '!! service elogind not enabled' <<<"$out"
check "with what --fix would do" grep -q 'vikix doctor --fix would: enable the service elogind (sudo)' <<<"$out"
check "and the end counts it" grep -q 'vikix doctor --fix would mend 1 of these' <<<"$out"
check "listing it" grep -q '^     enable the service elogind' <<<"$out"
check "nothing was done" test ! -e "$t/service/elogind"
plain --fix --yes
check "--fix --yes exits 1 still (it found a fault): $code" test "$code" = 1
check "it says what it fixes: $out" grep -q ':: fixing: enable the service elogind' <<<"$out"
check "and counts it" grep -q 'fixed 1 of 1' <<<"$out"
check "the service is enabled" test -L "$t/service/elogind"
plain
check "clean after: $code: $out" test "$code" = 0

echo "--- DRY_RUN=1 --fix prints and does nothing"
rm "$t/service/elogind"
out=$(DRY_RUN=1 doc --fix --yes) && code=0 || code=$?
check "prints the command: $out" grep -q "would run: sudo ln -s $t/sv/elogind $t/service/" <<<"$out"
check "and says none was done" grep -q '1 fix(es) printed, none done' <<<"$out"
check "nothing changed" test ! -e "$t/service/elogind"

echo "--- --fix without --yes, no terminal: left as it is"
out=$(doc --fix </dev/null) && code=0 || code=$?
check "says it leaves it: $out" grep -q 'left as it is' <<<"$out"
check "and fixed none" grep -q 'fixed 0 of 1' <<<"$out"
check "nothing changed" test ! -e "$t/service/elogind"
ln -s "$t/sv/elogind" "$t/service/elogind"

echo "--- a broken link of Vikix's: made again, the old moved aside"
rm "$HOME/.stumpwm.d/init.lisp"; ln -s "$t/nowhere" "$HOME/.stumpwm.d/init.lisp"
plain
check "a broken link is a fault: $code: $out" test "$code" = 1
check "said as broken" grep -q "init.lisp is a broken link (to $t/nowhere)" <<<"$out"
check "with its fix" grep -q "fix would: link $HOME/.stumpwm.d/init.lisp to $v/config/stumpwm/init.lisp" <<<"$out"
plain --fix --yes
check "relinked: $out" test "$(readlink "$HOME/.stumpwm.d/init.lisp")" = "$v/config/stumpwm/init.lisp"
check "the old moved aside, not deleted" test -n "$(ls -d "$HOME/.stumpwm.d/init.lisp.vikix-bak."* 2>/dev/null)"
rm -f "$HOME/.stumpwm.d/init.lisp.vikix-bak."*
echo "--- a link gone, and a file in its place"
rm "$HOME/.xinitrc"
printf 'mine\n' > "$HOME/.config/vikix/vikix.bash.new" && rm "$HOME/.config/vikix/vikix.bash" && mv "$HOME/.config/vikix/vikix.bash.new" "$HOME/.config/vikix/vikix.bash"
plain
check "the missing one is said: $out" grep -q '!! .*\.xinitrc is missing' <<<"$out"
check "the file in the way is said" grep -q "vikix.bash isn't Vikix's link" <<<"$out"
check "two fixes" grep -q 'would mend 2 of these' <<<"$out"
plain --fix --yes
check "both relinked: $out" test "$(readlink "$HOME/.xinitrc")" = "$v/config/x11/xinitrc" -a "$(readlink "$HOME/.config/vikix/vikix.bash")" = "$v/config/bash/vikix.bash"
check "the file kept" grep -qx mine "$HOME/.config/vikix/vikix.bash.vikix-bak."*
rm -f "$HOME/.config/vikix/vikix.bash.vikix-bak."*
plain; check "clean after the links: $code: $out" test "$code" = 0

echo "--- a link into another checkout is said, not counted or touched"
o="$t/other"; mkdir -p "$o/bin" "$o/config/stumpwm" && cp -r "$v/VERSION" "$o/" && cp "$v/bin/vikix" "$o/bin/" && cp "$v/config/stumpwm/init.lisp" "$o/config/stumpwm/"
rm "$HOME/.stumpwm.d/init.lisp"; ln -s "$o/config/stumpwm/init.lisp" "$HOME/.stumpwm.d/init.lisp"
plain
check "exits 0: $code: $out" test "$code" = 0
check "and says which" grep -q ":: Vikix's links point into $o, not this checkout" <<<"$out"
plain --fix --yes
check "nothing relinked" test "$(readlink "$HOME/.stumpwm.d/init.lisp")" = "$o/config/stumpwm/init.lisp"
rm "$HOME/.stumpwm.d/init.lisp"; ln -s "$v/config/stumpwm/init.lisp" "$HOME/.stumpwm.d/init.lisp"

echo "--- the modes: ~/.slime-secret, the secrets folder; nothing read"
chmod 644 "$HOME/.slime-secret"
mkdir -p "$HOME/.config/vikix/secrets"; echo key > "$HOME/.config/vikix/secrets/anthropic"; chmod 755 "$HOME/.config/vikix/secrets"; chmod 644 "$HOME/.config/vikix/secrets/anthropic"
plain
check "the password's mode: $out" grep -q 'slime-secret, is 644, not 600' <<<"$out"
check "with chmod as the fix" grep -q 'fix would: chmod 600 ~/.slime-secret' <<<"$out"
check "the folder's" grep -q "fix would: chmod 700 $HOME/.config/vikix/secrets and 600 its files" <<<"$out"
check "the key isn't printed" no grep -q '^key$' <<<"$out"
plain --fix --yes
check "fixed both: $out" grep -q 'fixed 2 of 2' <<<"$out"
check "600" test "$(stat -c %a "$HOME/.slime-secret")" = 600
check "700 and 600" test "$(stat -c %a "$HOME/.config/vikix/secrets")" = 700 -a "$(stat -c %a "$HOME/.config/vikix/secrets/anthropic")" = 600
check "the key as it was" grep -qx key "$HOME/.config/vikix/secrets/anthropic"
rm -rf "$HOME/.config/vikix/secrets"
rm "$HOME/.slime-secret"; plain
check "no password at all is a fault with no fix: $out" grep -q 'no ~/.slime-secret (vikix update makes it)' <<<"$out"
check "no fix offered for it" no grep -q 'fix would' <<<"$out"
( umask 077; echo secret > "$HOME/.slime-secret" )

echo "--- the manual and the pages from another Vikix: 40-config run again"
printf '.TH "VIKIX" 1 "2026-10-01" "Vikix 0.72.100" "Vikix"\n' > "$HOME/.local/share/man/man1/vikix.1"
plain
check "said with both versions: $out" grep -q 'the man pages are from Vikix 0.72.100, not 0.72.200' <<<"$out"
check "the fix is the stage" grep -q 'fix would: run install/40-config.sh again' <<<"$out"
rm "$HOME/.local/share/info/vikix.info"
plain
check "the manual missing too, one fix: $out" grep -q 'the Info manual of the guides is missing; the man pages are from' <<<"$out"
check "one" grep -q 'would mend 1 of these' <<<"$out"
plain --fix --yes
check "the stage ran: $out" test "$(cat "$t/40-config.ran" 2>/dev/null)" = ran
printf 'The guides.\n\nFor Vikix 0.72.200.\n' > "$HOME/.local/share/info/vikix.info"
printf '.TH "VIKIX" 1 "2026-10-22" "Vikix 0.72.200" "Vikix"\n' > "$HOME/.local/share/man/man1/vikix.1"

echo "--- the plugins behind the pin: vikix plugin sync"
pl="$HOME/.local/share/vikix/plugins"; mkdir -p "$pl"
git_q -C "$pl" init -q && git_q -C "$pl" commit -q --allow-empty -m one
head=$(git -C "$pl" rev-parse HEAD)
plain
check "said with both: $out" grep -q "the plugins are at ${head:0:7}, the pin is 1111111" <<<"$out"
check "the fix is sync" grep -q 'fix would: vikix plugin sync: the plugins to the pin 1111111' <<<"$out"
plain --fix --yes
check "sync was run: $(cat "$t/asked")" grep -q '^vikix-plugin sync$' "$t/asked"
out=$(VIKIX_PLUGINS_COMMIT="$head" doc) && code=0 || code=$?
check "at the pin (the environment's, as vikix plugin reads it): $code: $out" grep -q "the plugins are at the pin (${head:0:7})" <<<"$out"
rm -rf "$pl"

echo "--- what an update kept, and a checkout on no branch"
mkdir -p "$HOME/.local/state/vikix/rollback/20261020-100000" "$HOME/.local/state/vikix/rollback/20261021-120000"
printf '0.72.190\n' > "$HOME/.local/state/vikix/rollback/20261021-120000/version"
plain
check "the records are said, the newest named: $out" grep -q ':: 2 record(s) of the system before an update, the newest 20261021-120000 (Vikix 0.72.190): vikix update --back' <<<"$out"
check "and not a fault" test "$code" = 0
git -C "$v" checkout -q --detach
plain
check "no branch is a fault: $code: $out" grep -q "!! $v is on no branch (after vikix update --back" <<<"$out"
check "with no fix of the doctor's" no grep -q 'fix would' <<<"$out"
printf '%s\nabc1234\ntopic\n2026-10-22\n' "$HOME/src/vikix-topic" > "$HOME/.local/state/vikix/try"
plain
check "a try is said, not counted: $code: $out" test "$code" = 0
check "naming the desk" grep -q ":: $v runs a desk's commit, $HOME/src/vikix-topic (vikix try status" <<<"$out"
rm "$HOME/.local/state/vikix/try"; git -C "$v" checkout -q master 2>/dev/null || git -C "$v" checkout -q main

echo "--- help, and a bad option"
out=$(doc help) && code=0 || code=$?
check "help prints the header: $code: $out" grep -q '^vikix-doctor — check the pieces' <<<"$out"
check "with --fix in it" grep -q 'vikix doctor --fix \[--yes\]' <<<"$out"
out=$(doc --mend) && code=0 || code=$?
check "a bad option dies with the usage: $code: $out" test "$code" = 1
grep -q 'vikix doctor \[--fix \[--yes\]\]' <<<"$out" || { echo "FAIL: the usage: $out"; fail=1; }
out=$(bash "$here/bin/vikix" doctor --help) && code=0 || code=$?
check "vikix doctor hands over to the script: $code: $out" grep -q '^vikix-doctor — ' <<<"$out"

[ "$fail" = 0 ] && echo "doctor: ok"
exit "$fail"
