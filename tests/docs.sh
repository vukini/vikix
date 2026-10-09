#!/usr/bin/env bash
# tests/docs.sh — vikix docs, the catalogue, in a made-up home: Vikix's
# guides, a project in ~/src (its worktree left out, a Vikix checkout's
# guides not twice), a language guide in ~/dev, Org notes (the inbox
# plugin's folder); found by the start of a word, a phrase, OR; Vikix's
# guide first; read again only what changed, a file gone gone; read as text;
# opened in Emacs or the docs browser (stand-ins); the agents' docs_search and
# docs_read; tldr pages and the ArchWiki from stand-ins of wikiman's copies;
# your own documents (own= in ~/.config/vikix/docs, a made-up book here) read
# a section at a time, found and opened at the section, closed to agents
# until a folder is opened to them.
# Man pages and Info manuals are the system's: left out here
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
printf '#!/bin/sh\necho "browser $*" >> %s/opened\n' "$t" > "$t/bin/docs-open"
export VIKIX_DOCS_OPEN="$t/bin/docs-open"
# xbps-query, as Void's answers: two packages, one installed; and one's details.
cat > "$t/bin/xbps-query" <<'X'
#!/bin/sh
case "$*" in
  "-Rs ") printf '[-] ardour-9.7_1   Professional-grade digital audio workstation\n[*] ruff-0.6.9_1   An extremely fast Python linter\n' ;;
  "-R -S ardour") printf 'pkgver: ardour-9.7_1\nshort_desc: Professional-grade digital audio workstation\nlicense: GPL-2.0-or-later\nhomepage: http://ardour.org\n' ;;
esac
X
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

# Opening: Markdown as a page styled like the guide; Ctrl+Enter (--other) in Emacs.
d open "$id"; sleep 0.3
page=$(awk '/^browser/ {print $2}' "$t/opened" | tail -1)
if command -v pandoc >/dev/null || python3 -c 'import markdown' 2>/dev/null; then
  check "Markdown opens as a page: $page" grep -q 'guide.css' "$page"
  check "with its text" grep -q 'mypy' "$page"
fi
d open "$id" --other; sleep 0.3
check "--other opens it in Emacs: $(cat "$t/opened")" grep -q "emacsclient -c -n $HOME/dev/python/README.md" "$t/opened"

# Packages: every one there is, a page for one, installed or not.
VIKIX_DOCS_SOURCES="pkg" d index >/dev/null
check "a package is found" grep -q 'pkg .*ardour — Professional-grade' <<<"$(d find ardour)"
check "an installed one says so" grep -q 'ruff — .*(installed)' <<<"$(d find linter)"
: > "$t/opened"; d open pkg:ardour; sleep 0.3
card=$(awk '/^browser/ {print $2}' "$t/opened" | tail -1)
check "a package's page says how to add it: $card" grep -q 'vikix pkg add ardour' "$card"
check "and its website" grep -q 'http://ardour.org' "$card"

# tldr pages and the ArchWiki, as wikiman keeps them (stand-ins): a command's
# page named for it first; opened as a styled page, or in a terminal; a wiki
# page as the copy is, or on the web; both read as text.
mkdir -p "$t/tldr/common" "$t/tldr/linux" "$t/arch"
export VIKIX_DOCS_TLDR="$t/tldr" VIKIX_DOCS_ARCH="$t/arch"
cat > "$t/tldr/common/tar.html" <<'H'
<h1>tar</h1>

<blockquote><p>Archiving utility.
Often combined with a compression method, such as <code>gzip</code>.
More information: <a href="https://www.gnu.org/software/tar">https://www.gnu.org/software/tar</a>.</p></blockquote>

<ul>
<li>[c]reate an archive and write it to a [f]ile:</li>
</ul>

<p><code>tar cf {{path/to/target.tar}} {{path/to/file1 path/to/file2 ...}}</code></p>
H
printf '<h1>sv</h1>\n<blockquote><p>Control a running runsv service.</p></blockquote>\n<ul><li>Restart a service:</li></ul>\n<p><code>sv restart {{service}}</code></p>\n' > "$t/tldr/linux/sv.html"
printf '<h1>target</h1>\n<blockquote><p>Something else, with tar in every line: tar tar tar tar.</p></blockquote>\n' > "$t/tldr/common/target.html"
cat > "$t/arch/Bluetooth_headset.html" <<'H'
<!DOCTYPE html>
<html><head><title>Bluetooth headset - ArchWiki</title><script>var nav = "menu words";</script></head>
<body><div id="mw-navigation">Main page Recent changes</div>
<div id="bodyContent"><h1>Bluetooth headset</h1><p>Pair it with bluetoothctl, then PipeWire takes it as a sink.</p></div>
<div id="catlinks">Category: Sound</div><div id="footer">Privacy policy</div></body></html>
H
printf '<html><head><title>Main page (Deutsch) - ArchWiki</title></head><body>Hauptseite</body></html>\n' > "$t/arch/0123456789abcdef0123456789abcdef.html"
out=$(VIKIX_DOCS_SOURCES="tldr arch" d index)
check "the tldr pages and the wiki are read, the hash-named wiki pages left out: $out" grep -q 'Read 3 tldr, 1 arch' <<<"$out"
check "a tldr page is named for its command, with what it is: $(d find sv | head -3)" grep -q '^tldr  *sv — Control a running runsv service.' <<<"$(d find sv | head -3)"
check "the command's own page comes before one that says its name more, or starts with it: $(d find tar | head -1)" grep -q '^tldr  *tar — Archiving utility.' <<<"$(d find tar | head -1)"
check "a wiki page by its title, without the site's name" grep -q '^arch  *Bluetooth headset$' <<<"$(d find headset | head -1)"
check "a wiki page is found by its own words" grep -q 'Bluetooth headset' <<<"$(d find bluetoothctl)"
check "not by its menus or scripts" test "$(d find menu OR navigation OR words --source arch)" = "nothing found"
check "a tldr page as text, each command set in: $(d read "tldr:$t/tldr/common/tar.html" | tail -1)" grep -q '^    tar cf {{path/to/target.tar}}' <<<"$(d read "tldr:$t/tldr/common/tar.html")"
check "a wiki page as text, its body alone" test "$(d read "arch:$t/arch/Bluetooth_headset.html")" = "Bluetooth headset Pair it with bluetoothctl, then PipeWire takes it as a sink."
: > "$t/opened"; d open "tldr:$t/tldr/common/tar.html"; sleep 0.3
page=$(awk '/^browser/ {print $2}' "$t/opened" | tail -1)
check "a tldr page opens as a page styled like the guide: $page" grep -q 'guide.css' "$page"
check "saying when the copy is from" grep -q 'the copy of 20' "$page"
check "with its examples" grep -q 'tar cf' "$page"
printf '#!/bin/sh\necho "terminal $*" >> %s/opened\n' "$t" > "$t/bin/term"; chmod +x "$t/bin/term"
: > "$t/opened"; VIKIX_TERMINAL="$t/bin/term" d open "tldr:$t/tldr/common/tar.html" --other; sleep 0.3
check "--other shows a tldr page in a terminal, tealdeer's or the copy's words: $(cat "$t/opened")" grep -q "terminal -e sh -c tldr tar 2>/dev/null || less .*tldr/tar.txt" "$t/opened"
check "the copy's words are there for it" grep -q '^    tar cf' "$XDG_CACHE_HOME/vikix/docs/tldr/tar.txt"
: > "$t/opened"; d open "arch:$t/arch/Bluetooth_headset.html"; sleep 0.3
check "a wiki page opens as the copy is: $(cat "$t/opened")" grep -q "browser $t/arch/Bluetooth_headset.html" "$t/opened"
printf '#!/bin/sh\necho "xdg-open $*" >> %s/opened\n' "$t" > "$t/bin/xdg-open"; chmod +x "$t/bin/xdg-open"
: > "$t/opened"; d open "arch:$t/arch/Bluetooth_headset.html" --other; sleep 0.3
check "--other opens the page as it is today, on the web: $(cat "$t/opened")" grep -q "xdg-open https://wiki.archlinux.org/title/Bluetooth_headset" "$t/opened"

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

# Super+F2's menus, in a real rofi on a hidden screen: the words, then the
# hits; Enter opens one as a page, Ctrl+Enter in Emacs (once refused by
# rofi, which had Ctrl+Enter bound already).
if command -v Xvfb >/dev/null && command -v rofi >/dev/null && command -v xdotool >/dev/null; then
  n=$(( 100 + RANDOM % 400 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  Xvfb ":$n" -screen 0 1024x768x24 -nolisten tcp >/dev/null 2>&1 &
  xvfb=$!
  sleep 1
  printf '#!/bin/sh\necho "browser $*" >> %s/opened\n' "$t" > "$t/bin/notify-send"; chmod +x "$t/bin/notify-send"
  # rofi's process, not the clock: on a busy machine the menu isn't up when
  # the keys come. Not its window: asking X for it (xdotool search) beside
  # rofi's keyboard grab stalled the display until the pick's timeout. Each
  # rofi is known by its own words (the first's prompt, the second's), and a
  # second after it is seen its window has the keyboard.
  rofi_wait() { for _ in $(seq 1 150); do pgrep -f -- "$1" >/dev/null && return; sleep 0.1; done; }
  for way in Return ctrl+Return; do
    : > "$t/opened"
    ( rofi_wait "rofi -dmenu -p docs"; sleep 1
      DISPLAY=":$n" xdotool type mypy; DISPLAY=":$n" xdotool key Return
      rofi_wait "rofi -dmenu -i -p mypy"; sleep 1; DISPLAY=":$n" xdotool key "$way" ) &
    keys=$!
    DISPLAY=":$n" timeout 20 python3 "$here/bin/vikix-docs" pick || true
    wait "$keys" || true; sleep 0.5
    if [ "$way" = Return ]; then want='^browser .*/md/.*\.html'; else want="emacsclient -c -n .*dev/python/README.md"; fi
    check "Super+F2's menus: $way should open the hit its way: $(cat "$t/opened")" grep -q "$want" "$t/opened"
  done
  kill "$xvfb" 2>/dev/null || true
fi

# The page in Nyxt: the hits as id, source, title, excerpt; the page asked of
# a running Nyxt (a stand-in, on a socket that answers); with none (--remote
# exits 0 then, and says "No instance running" only on the terminal: from the
# desktop's menu nothing reaches the pipe, so the socket is what's asked),
# Nyxt started with the page's address, so it opens after the restored
# session rather than under it; and said when it can't. A Nyxt left
# running with no window and no socket is closed first, and said.
check "list: how many from each source" grep -qxP 'repo\t[0-9]+' <<<"$(d list)"
check "list --source: its documents by title, four fields: $(d list --source repo)" grep -qP '^repo:.*\trepo\tMusic sketchpad.*\t$' <<<"$(d list --source repo)"
tsv=$(d find websocket --tsv)
check "--tsv gives four fields a line: $tsv" test -n "$tsv" -a -z "$(awk -F'\t' 'NF != 4' <<<"$tsv")"
# A socket that answers for a few seconds, as a running Nyxt's does.
listen() { mkdir -p "$(dirname "$1")"; rm -f "$1"; python3 -c 'import os, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen()
if os.fork(): os._exit(0)
time.sleep(20)' "$1" >/dev/null 2>&1; }
printf '#!/bin/sh\necho "nyxt $*" >> %s/opened\n' "$t" > "$t/bin/nyxt"; chmod +x "$t/bin/nyxt"
listen "$t/run/nyxt/nyxt.socket"
: > "$t/opened"; XDG_RUNTIME_DIR="$t/run" d page 'say "hi"'
check "the page is asked for the words: $(cat "$t/opened")" grep -qxF 'nyxt --remote --quit --eval (nyxt-user::vikix-docs-show "say \"hi\"")' "$t/opened"
cat > "$t/bin/nyxt" <<X
#!/bin/sh
case "\$1" in
  --remote) echo "nyxt \$*" >> "$t/opened" ;;   # silent, exit 0: as from the desktop's menu
  *) echo "nyxt \$*" >> "$t/opened"; $(declare -f listen); listen "$t/run2/nyxt/nyxt.socket" ;;
esac
X
: > "$t/opened"; XDG_RUNTIME_DIR="$t/run2" d page 'say "hi"'
check "none running: Nyxt is started on the page, not asked: $(cat "$t/opened")" grep -qxF 'nyxt nyxt:nyxt-user::vikix-docs-page?query=say%20%22hi%22' "$t/opened"
check "none running: nothing is asked of a Nyxt that isn't there" test "$(wc -l < "$t/opened")" = 1
mkdir -p "$t/run3/nyxt"; : > "$t/run3/nyxt/nyxt.socket"   # a socket file left behind, nobody listening
: > "$t/opened"; out=$(XDG_RUNTIME_DIR="$t/run3" d page x 2>&1 || true)
check "a socket left behind isn't a Nyxt: one is started: $(cat "$t/opened")" grep -qxF 'nyxt nyxt:nyxt-user::vikix-docs-page?query=x' "$t/opened"
printf '#!/bin/sh\n:\n' > "$t/bin/nyxt"  # never starts
out=$(XDG_RUNTIME_DIR="$t/home" d page x 2>&1 || true)
check "a Nyxt that doesn't start is said: $out" grep -q "didn't start" <<<"$out"
# A Nyxt left running with no window and no socket is stuck: closed, and
# said. One with a window is left, and said. The "Nyxt" is a copy of sleep
# by that name, on a made-up screen and runtime folder, so the guard can't
# match a real one (it only takes yours on this screen, with this socket).
mkdir -p "$t/stuck" "$t/run4"; cp "$(command -v sleep)" "$t/stuck/nyxt"
fake_display=":$((7000 + RANDOM % 900))"
printf '#!/bin/sh\necho "notify $*" >> %s/notified\n' "$t" > "$t/bin/notify-send"
printf '#!/bin/sh\n[ "$1" = -root ] && echo "_NET_CLIENT_LIST(WINDOW): window id # 0x1"\n[ "$1" = -id ] && echo "_NET_WM_PID(CARDINAL) = $(cat %s/windowpid 2>/dev/null || echo 1)"\nexit 0\n' "$t" > "$t/bin/xprop"
chmod +x "$t/bin/notify-send" "$t/bin/xprop"
DISPLAY=$fake_display XDG_RUNTIME_DIR="$t/run4" "$t/stuck/nyxt" 300 &
stuck=$!
sleep 0.3
: > "$t/notified"
DISPLAY=$fake_display XDG_RUNTIME_DIR="$t/run4" d page x >/dev/null 2>&1 || true
sleep 0.3
check "a stuck Nyxt (no window, no socket) is closed" bash -c '! kill -0 "$1" 2>/dev/null' _ "$stuck"
check "and said: $(cat "$t/notified")" grep -q "A stuck Nyxt was closed" "$t/notified"
kill "$stuck" 2>/dev/null || true; wait "$stuck" 2>/dev/null || true
DISPLAY=$fake_display XDG_RUNTIME_DIR="$t/run4" "$t/stuck/nyxt" 300 &
inuse=$!
sleep 0.3
echo "$inuse" > "$t/windowpid"
: > "$t/notified"
DISPLAY=$fake_display XDG_RUNTIME_DIR="$t/run4" d page x >/dev/null 2>&1 || true
check "one with a window open is left running" kill -0 "$inuse"
check "and why a second opens is said: $(cat "$t/notified")" grep -q "Nyxt isn't answering" "$t/notified"
kill "$inuse" 2>/dev/null; wait "$inuse" 2>/dev/null || true
: > "$t/notified"
DISPLAY=:1 XDG_RUNTIME_DIR="$t/run4" "$t/stuck/nyxt" 300 &
other=$!
sleep 0.3
DISPLAY=$fake_display XDG_RUNTIME_DIR="$t/run4" d page x >/dev/null 2>&1 || true
check "one on another screen is never touched" kill -0 "$other"
kill "$other" 2>/dev/null; wait "$other" 2>/dev/null || true
rm -f "$t/bin/xprop" "$t/windowpid"
rm "$t/bin/nyxt"
# A file gone since the last index: said, not opened as nothing.
printf '# Gone soon\n\nephemeral words\n' > "$HOME/src/music/docs/gone.md"
d index >/dev/null; gone=$(d find ephemeral --source repo --tsv | cut -f1); rm "$HOME/src/music/docs/gone.md"
out=$(d open "$gone" 2>&1 || true)
check "a file gone since the index says so: $out" grep -q "gone since the last index" <<<"$out"

# Your own documents: a made-up book, a section a row.
mkdir -p "$HOME/books/unix-by-hand" "$HOME/books/site/out"
cat > "$HOME/books/unix-by-hand/ch04-processes.md" <<'M'
# 4. Processes

A chapter of a made-up book.

## A program that is running

Every process has a number: the quokka fact is here.

## What starts them

The first process starts the rest.

### Not a section

Too deep to be one.
M
printf '<html><head><title>Wires</title></head><body><h1 id="top">Wires</h1><p>Intro.</p><h2 id="bus">The shared bus</h2><p>One wire for all: the wombat fact.</p><h2>No id here</h2><p>x</p><h2 data-at="l1-latch:1">A latch</h2><p>The numbat fact.</p></body></html>\n' > "$HOME/books/site/out/page.html"
printf 'own=~/books\nown=~/books site/out/*.html\n' > "$XDG_CONFIG_HOME/vikix/docs"
out=$(d index)
check "the own= folders are read: $out" grep -q 'own' <<<"$out"
check "a Markdown file is a row, and each ## section one; a ### isn't: $(d list --source own | cut -f3 | tr '\n' '|')" \
  test "$(d list --source own | cut -f3 | tr '\n' '|')" = "4. Processes (unix-by-hand)|4. Processes › A program that is running (unix-by-hand)|4. Processes › What starts them (unix-by-hand)|Wires (site)|Wires › A latch (site)|Wires › The shared bus (site)|"
check "a search lands on the section: $(d find quokka | head -1)" grep -q '^yours .*4. Processes › A program that is running' <<<"$(d find quokka | head -1)"
check "an HTML page's section too, by its heading with an id" grep -q '^yours .*Wires › The shared bus' <<<"$(d find wombat | head -1)"
check "or with a data-at tag, which the page's own script routes to: $(d find numbat --tsv | head -1 | cut -f1)" grep -q '^own:.*page.html#A latch$' <<<"$(d find numbat --tsv | head -1 | cut -f1)"
: > "$t/opened"; d open "$(d find numbat --tsv | head -1 | cut -f1)"; sleep 0.3
check "and opens at the tag" grep -q '^browser file://.*page.html#l1-latch:1$' "$t/opened"
sect=$(d find quokka --tsv | head -1 | cut -f1)
check "read gives the section alone: $(d read "$sect" | head -1)" bash -c 'grep -q "^## A program that is running" <<<"$1" && ! grep -q "What starts them" <<<"$1"' _ "$(d read "$sect")"
: > "$t/opened"
d open "$sect"; sleep 0.3
check "it opens as a page, at the section: $(cat "$t/opened")" grep -qE '^browser file://.*\.html#a-program-that-is-running$' "$t/opened"
d open "$(d find wombat --tsv | head -1 | cut -f1)"; sleep 0.3
check "an HTML page opens itself, at the id: $(tail -1 "$t/opened")" grep -q '^browser file://.*site/out/page.html#bus$' "$t/opened"
: > "$t/opened"; d open "$sect" --other; sleep 0.3
check "the other way is the file in Emacs" grep -q '^emacsclient .*ch04-processes.md$' "$t/opened"

# The agents: docs_search and docs_read, read only; your own documents closed to them.
python3 - "$here/bin/vikix-mcp" "$HOME/books" "$XDG_CONFIG_HOME/vikix/docs" <<'PY' || fail=1
import importlib.machinery, importlib.util, json, sys
loader = importlib.machinery.SourceFileLoader("vikix_mcp", sys.argv[1])
spec = importlib.util.spec_from_loader("vikix_mcp", loader); m = importlib.util.module_from_spec(spec); loader.exec_module(m)
hits = json.loads(m.t_docs_search({"query": "websocket", "source": "repo"}))
assert hits and hits[0]["source"] == "repo" and "Music" in hits[0]["title"], hits
text = m.t_docs_read({"id": hits[0]["id"]})
assert "websocket" in text, text
tools = {t[0]: t for t in m.TOOLS}
assert tools["docs_search"][4]["readOnlyHint"] and tools["docs_read"][4]["readOnlyHint"]
# Yours: not found, and refused by id, until a folder is opened to agents.
assert json.loads(m.t_docs_search({"query": "quokka"})) == [], "an agent found the user's own document"
docs = m.docs_module()
own_id = docs.find(["quokka"])[0]["id"]
try:
    m.t_docs_read({"id": own_id}); raise SystemExit("an agent read the user's own document")
except m.ToolError as e:
    assert "closed to agents" in str(e), e
with open(sys.argv[3], "a") as f:
    f.write(f"agents={sys.argv[2]}/unix-by-hand\n")
hits = json.loads(m.t_docs_search({"query": "quokka"}))
assert hits and hits[0]["source"] == "own", hits
assert "quokka" in m.t_docs_read({"id": own_id})
assert json.loads(m.t_docs_search({"query": "wombat"})) == [], "a folder not opened to agents was found"
PY

[ "$fail" = 0 ] && echo "docs: guides, projects, ~/dev and notes found by words, phrases and OR, Vikix's first, the one named first, only what changed read again, opened, man pages styled, tldr pages, your own documents a section at a time and closed to agents until opened and the ArchWiki from wikiman's copies, the page in Nyxt asked for, and read-only tools for the agents"
exit "$fail"
