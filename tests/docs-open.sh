#!/usr/bin/env bash
# tests/docs-open.sh — vikix-docs-open: guides and docs go to Nyxt when it's
# installed, as file:// URLs it can't take for searches; a running Nyxt's
# window is asked forward; xdg-open without Nyxt; ~/.config/vikix/docs-browser
# names another browser.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config"
unset DISPLAY   # nothing here may open a window on the desktop
mkdir -p "$HOME/.config/vikix" "$t/bin" "$t/sys" "$t/docs/a dir"
# The script sees only the stand-ins below and the tools it needs: never the
# real nyxt, xdg-open or firefox, so "not installed" really is.
for p in sh bash sed readlink id setsid; do ln -s "$(command -v "$p")" "$t/sys/$p"; done
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# Stand-ins: each writes what it was given, a line an argument.
for p in nyxt xdg-open firefox vikix; do
  printf '#!/bin/sh\nfor a in "$@"; do echo "%s $a"; done >> "%s/calls"\n' "$p" "$t" > "$t/bin/$p"
  chmod +x "$t/bin/$p"
done
# pgrep says whether Nyxt runs: yes when $t/running exists.
printf '#!/bin/sh\n[ -e "%s/running" ]\n' "$t" > "$t/bin/pgrep"
chmod +x "$t/bin/pgrep"
open() { rm -f "$t/calls"; PATH="$t/bin:$t/sys" "$here/bin/vikix-docs-open" "$@"; }
# setsid -f returns at once: wait for the stand-in's lines.
calls() { local _; for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$t/calls" ] && break; sleep 0.1; done; sleep 0.1; cat "$t/calls" 2>/dev/null || true; }

: > "$t/docs/index.html"; : > "$t/docs/a dir/c#1.html"

open "$t/docs/index.html" "$t/docs/a dir/c#1.html" https://vikix.dev
out=$(calls)
check "a file goes to Nyxt as a file:// URL" grep -qx "nyxt file://$t/docs/index.html" <<<"$out"
check "spaces and # are escaped" grep -qx "nyxt file://$t/docs/a%20dir/c%231.html" <<<"$out"
check "a URL goes as it is" grep -qx "nyxt https://vikix.dev" <<<"$out"
check "no raise when Nyxt wasn't running" bash -c "! grep -q raise-class <<<'$out'"

touch "$t/running"
open "$t/docs/index.html"
out=$(calls)
# Through `vikix eval`: vikix-eval itself isn't on PATH (40-config leaves it out).
check "a running Nyxt's window is asked forward" grep -qx 'vikix (vikix-raise-class "Nyxt")' <<<"$out"
rm "$t/running"

rm "$t/bin/nyxt"
open "$t/docs/index.html" https://vikix.dev
out=$(calls)
check "without Nyxt, xdg-open, one at a time" grep -qx "xdg-open file://$t/docs/index.html" <<<"$out"
check "without Nyxt, xdg-open has the URL too" grep -qx "xdg-open https://vikix.dev" <<<"$out"

printf '# the browser for guides\n  firefox\n' > "$HOME/.config/vikix/docs-browser"
open "$t/docs/index.html"
out=$(calls)
check "docs-browser names another browser" grep -qx "firefox file://$t/docs/index.html" <<<"$out"

echo nosuchbrowser > "$HOME/.config/vikix/docs-browser"
check "a browser that isn't installed is an error" bash -c "! PATH='$t/bin:$t/sys' '$here/bin/vikix-docs-open' '$t/docs/index.html' 2>/dev/null"

check "no arguments is a usage error" bash -c "! PATH='$t/bin:$t/sys' '$here/bin/vikix-docs-open' 2>/dev/null"

# The menu opens the guide and the docs through it, not xdg-open.
check "the menu's guide entry uses vikix-docs-open" grep -q ':run "exec vikix-docs-open ~/.local/share/vikix/guide/index.html"' "$here/config/stumpwm/vikix/registry.lisp"
check "the menu's docs entry uses vikix-docs-open" grep -q ':run "exec vikix-docs-open ~/dev/index.html"' "$here/config/stumpwm/vikix/registry.lisp"
check "the docs alias uses vikix-docs-open" grep -q "^alias docs='vikix-docs-open " "$here/config/bash/vikix.bash"

[ "$fail" = 0 ] && echo "docs-open: ok"
exit "$fail"
