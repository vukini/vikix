#!/usr/bin/env bash
# tests/docs.sh — vikix docs, the catalogue, in a made-up home: Vikix's
# guides, a project in ~/src (its worktree left out, a Vikix checkout's
# guides not twice), a language guide in ~/dev, Org notes (the inbox
# plugin's folder); found by the start of a word, a phrase, OR; Vikix's
# guide first; read again only what changed, a file gone gone; read as text;
# opened in Emacs or the docs browser (stand-ins); the agents' docs_search and
# docs_read. Man pages and Info manuals are the system's: left out here
# (VIKIX_DOCS_SOURCES), but a man page is read and opened when there is man.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_DATA_HOME="$t/home/.local/share" XDG_CACHE_HOME="$t/home/.cache"
export VIKIX_DOCS_SOURCES="" VIKIX_DIR="$here"
mkdir -p "$HOME/src/music/.git" "$HOME/src/music/docs" "$HOME/src/music-wt" "$HOME/dev/python" "$HOME/notes/vault/Books" "$t/bin"
echo "gitdir: x" > "$HOME/src/music-wt/.git"
printf '# Music sketchpad\n\nPatterns as Lisp, sent over a websocket to the DAW.\n' > "$HOME/src/music/DESIGN.md"
printf '# Notes on the bridge\n\nOSC transport.\n' > "$HOME/src/music/docs/bridge.md"
printf '# Worktree copy\n\nwebsocket\n' > "$HOME/src/music-wt/README.md"
printf '# Python\n\nThe tools for python on this machine: uv, ruff.\n' > "$HOME/dev/python/README.md"
printf '#+title: Inbox\n\n* Buy a websocket book\n:PROPERTIES:\n:CREATED:  [2026-10-03 Sat 10:00]\n:END:\n' > "$HOME/notes/inbox.org"
printf ':PROPERTIES:\n:ID: x\n:END:\n#+title: The service manager\n\nsv down NAME stops a service, in runit.\n' > "$HOME/notes/vault/Books/runit.org"
mkdir -p "$XDG_CONFIG_HOME/vikix/plugins/inbox"
echo "file = $HOME/notes/inbox.org" > "$XDG_CONFIG_HOME/vikix/plugins/inbox/settings"
printf '#!/bin/sh\necho "emacsclient $*" >> %s/opened\n' "$t" > "$t/bin/emacsclient"
mkdir -p "$t/vikix/bin"; printf '#!/bin/sh\necho "browser $*" >> %s/opened\n' "$t" > "$t/bin/fake-docs-open"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
d() { python3 "$here/bin/vikix-docs" "$@"; }

out=$(d index)
check "the first index should read each source: $out" grep -qE 'Read .*vikix.*repo.*dev.*note' <<<"$out"
check "a second index should read nothing new" grep -q 'nothing new' <<<"$(d index)"
check "the start of a word finds it" grep -q 'Music sketchpad' <<<"$(d find webso)"
check "a worktree isn't a project" bash -c "! grep -q 'Worktree copy' <<<\"\$1\"" _ "$(d find websocket)"
check "a note is found" grep -q 'note .*Inbox' <<<"$(d find websocket)"
check "a project's docs/ too" grep -q 'Notes on the bridge' <<<"$(d find transport)"
check "a language guide" grep -q 'dev .*Python' <<<"$(d find ruff)"
check "a phrase" grep -q 'service manager' <<<"$(d find '"sv down"')"
check "OR" test "$(d find ruff OR transport | grep -c '^[a-z]')" = 2
check "Vikix's guide should come first for a word it shares: $(d find runit | head -1)" grep -q '^vikix ' <<<"$(d find runit | head -1)"
check "a Vikix checkout's guides aren't counted twice" bash -c "! grep -q '^repo .*vikix/docs' <<<\"\$1\"" _ "$(d find runit --limit 40)"
check "--source keeps to one" bash -c "! grep -qv '^note\\|^  ' <<<\"\$1\"" _ "$(d find websocket --source note)"
check "punctuation alone finds nothing, without an error" test "$(d find '***')" = "nothing found"
id=$(d find ruff --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
check "read gives the text" grep -q 'uv, ruff' <<<"$(d read "$id")"

# Changed, and gone.
sleep 1; printf '# Python\n\nNow with mypy too.\n' > "$HOME/dev/python/README.md"
out=$(d index)
check "only what changed is read again: $out" grep -q 'Read 1 dev' <<<"$out"
check "and found by its new words" grep -q Python <<<"$(d find mypy)"
rm "$HOME/src/music/docs/bridge.md"
d index >/dev/null
check "a file gone is gone" test "$(d find transport)" = "nothing found"

# Opening: Markdown and notes in Emacs.
d open "$id"; sleep 0.3
check "a language guide opens in Emacs: $(cat "$t/opened" 2>/dev/null)" grep -q "emacsclient -c -n $HOME/dev/python/README.md" "$t/opened"

# A man page, when there is man: read as text, opened as a styled page.
if command -v man >/dev/null && command -v mandoc >/dev/null && man -w 1 ls >/dev/null 2>&1; then
  VIKIX_DOCS_SOURCES="man" d index --full >/dev/null
  check "a man page is read as text" grep -qi 'list directory' <<<"$(d read 'man:ls(1)')"
  python3 - "$here/bin/vikix-docs" <<'PY' || fail=1
import importlib.util, sys
spec = importlib.util.spec_from_loader("d", loader=None); m = importlib.util.module_from_spec(spec)
exec(compile(open(sys.argv[1]).read(), "vikix-docs", "exec"), m.__dict__)
page = m.man_html(m.get("man:ls(1)"))
assert page and "guide.css" in open(page).read(), page
PY
fi

# The agents: docs_search and docs_read, read only.
python3 - "$here/bin/vikix-mcp" <<'PY' || fail=1
import importlib.machinery, importlib.util, json, sys
loader = importlib.machinery.SourceFileLoader("vikix_mcp", sys.argv[1])
spec = importlib.util.spec_from_loader("vikix_mcp", loader); m = importlib.util.module_from_spec(spec); loader.exec_module(m)
hits = json.loads(m.t_docs_search({"query": "websocket", "source": "repo"}))
assert hits and hits[0]["source"] == "repo" and "Music" in hits[0]["title"], hits
text = m.t_docs_read({"id": hits[0]["id"]})
assert "websocket" in text, text
tools = {t[0]: t for t in m.TOOLS}
assert tools["docs_search"][4]["readOnlyHint"] and tools["docs_read"][4]["readOnlyHint"]
PY

[ "$fail" = 0 ] && echo "docs: guides, projects, ~/dev and notes found by words, phrases and OR, Vikix's first, only what changed read again, opened, man pages styled, and read-only tools for the agents"
exit "$fail"
