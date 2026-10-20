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
# until a folder is opened to them; the Cuis image's classes from the
# package files (Vikix's in the checkout, a made-up one of yours), a row a
# package and a row a class, opened in Emacs at the class while no image
# answers (the Browser in the image is tests/cuis.sh's).
# Man pages and Info manuals are the system's: left out here
# (VIKIX_DOCS_SOURCES), but a man page is read and opened when there is man.
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
# A release inherits the user's shell: the no-key case must really have no
# key, and even an unexpected cloud request must stay on loopback.
unset ANTHROPIC_API_KEY
export ANTHROPIC_BASE_URL=http://127.0.0.1:9
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
ui_pids=()
cleanup_ui() {
  local pid
  for pid in "${ui_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${ui_pids[@]}"; do wait "$pid" 2>/dev/null || true; done
  ui_pids=()
}
trap 'cleanup_ui; rm -rf "$t"' EXIT
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_DATA_HOME="$t/home/.local/share" XDG_CACHE_HOME="$t/home/.cache"
export VIKIX_DOCS_SOURCES="" VIKIX_DIR="$here" VIKIX_DOCS_CUIS="$t/home/cuis"
mkdir -p "$HOME/src/music/.git" "$HOME/src/music/docs" "$HOME/src/music-wt" "$HOME/dev/python" "$HOME/notes/vault/Books" "$t/bin"
echo "gitdir: x" > "$HOME/src/music-wt/.git"
printf '# Music sketchpad\n\nPatterns as Lisp, sent over a websocket to the DAW.\n' > "$HOME/src/music/DESIGN.md"
printf '# Notes on the bridge\n\nOSC transport.\n' > "$HOME/src/music/docs/bridge.md"
mkdir -p "$HOME/src/music/plans"; printf '# Cloud nodes\n\nThe sketchpad on a quorumless server.\n' > "$HOME/src/music/plans/DESIGN-cloud.md"
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

# Random guides need no catalogue: a complete deck, the normal opener and
# day log, Emacs on --other, and state that may be stale or unwritable.
python3 - "$here/bin/vikix-docs" "$t/opened" <<'PYTEST' || fail=1
import hashlib, importlib.machinery, importlib.util, os, pathlib, subprocess, sys, time
loader = importlib.machinery.SourceFileLoader("random_docs", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)
opened = pathlib.Path(sys.argv[2])
state = pathlib.Path(os.environ["HOME"]) / ".local/state/vikix"
deck = state / "docs/random-deck"
guides = {p.name: p for p in pathlib.Path(m.vikix_dir(), "docs").glob("*.md")
          if p.name not in ("README.md", "commands.md")}
titles = {m.md_title(p.read_text(), str(p)) for p in guides.values()}
assert not pathlib.Path(m.DB).exists(), "random must work before the first index"

def draw(*args, env=None):
    opened.write_text("")
    result = subprocess.run([sys.executable, sys.argv[1], "random", *args],
                            capture_output=True, text=True, timeout=20, env=env)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() in titles, result.stdout
    for _ in range(100):
        lines = opened.read_text().splitlines()
        if lines:
            assert len(lines) == 1, lines
            return lines[0]
        time.sleep(.02)
    raise AssertionError("the opener was not called")

seen = []
for _ in guides:
    line = draw()
    assert line.startswith("browser "), line
    seen.append(line.removeprefix("browser "))
assert len(set(seen)) == len(guides), "a page repeated within the round"
if m.shutil.which("pandoc") or importlib.util.find_spec("markdown"):
    expected = {str(pathlib.Path(m.CACHE, "md", hashlib.sha1(
        f"{p}:{p.stat().st_mtime}".encode()).hexdigest()[:16] + ".html"))
        for p in guides.values()}
    assert set(seen) == expected, (seen, expected)
    assert all("guide.css" in pathlib.Path(p).read_text() for p in seen)
else:
    assert set(seen) == {str(p) for p in guides.values()}, seen
assert deck.read_text() == "", "the round did not empty the deck"
assert deck.stat().st_mode & 0o777 == 0o600, "deck is not private"
assert not pathlib.Path(m.DB).exists(), "random created a catalogue"
rows = (state / "day/docs.log").read_text().splitlines()
assert {row.split("\t")[1] for row in rows} == {f"vikix:{p}" for p in guides.values()}
draw()
assert len(deck.read_text().splitlines()) == len(guides) - 1
line = draw("--other")
assert line.startswith("emacsclient -c -n "), line
assert line.removeprefix("emacsclient -c -n ") in {str(p) for p in guides.values()}, line
# Drop removed pages without losing the remaining live card.
last = next(iter(guides))
deck.write_text("gone-guide.md\n" + last + "\n")
assert draw("--other") == "emacsclient -c -n " + str(guides[last])
assert deck.read_text() == ""
deck.write_text("gone-guide.md\n")
draw()
assert "gone-guide.md" not in deck.read_text()
# A file in place of the state directory is unwritable even under root.
blocked = state / "blocked"
blocked.write_text("keep me")
draw(env=dict(os.environ, VIKIX_STATE=str(blocked)))
assert blocked.read_text() == "keep me"
custom = state / "elsewhere"
draw(env=dict(os.environ, VIKIX_STATE=str(custom)))
assert (custom / "docs/random-deck").exists()
assert (custom / "day/docs.log").exists()
print("docs random: complete rounds, openers, day log, stale and unwritable state")
PYTEST

# A Cuis package of yours, in the chunk format vikix cuis rebuild reads.
mkdir -p "$HOME/cuis/NewPackages"
cat > "$HOME/cuis/NewPackages/Mine.pck.st" <<'ST'
'From Cuis7.7 [latest update: #7977] on 10 October 2026 at 12:00:00 pm'!
'Description A package of my own: one class that counts.'!
!provides: 'Mine' 1 0!
SystemOrganization addCategory: #'Mine'!

!classDefinition: #Counter category: #'Mine'!
Object subclass: #Counter
	instanceVariableNames: 'count'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Mine'!

!Counter commentStamp: '<historical>' prior: 0!
Counts up, one at a time; it's mine. A bang inside: !! there.!

!Counter methodsFor: 'counting' stamp: 'me 10/10/2026 12:00'!
up
	count := (count ifNil: [ 0 ]) + 1! !

!Counter methodsFor: 'counting' stamp: 'me 10/10/2026 12:00'!
up: aNumber by: aStep
	count := count + (aNumber * aStep)! !

!Counter methodsFor: 'accessing' stamp: 'me 10/10/2026 12:00'!
count
	^ count! !

!Counter class methodsFor: 'instance creation' stamp: 'me 10/10/2026 12:00'!
new
	^ super new up! !

!String methodsFor: '*Mine' stamp: 'me 10/10/2026 12:00'!
, aCounter
	^ self! !
ST
out=$(d index)
check "the first index should read each source: $out" grep -qE 'Read .*vikix.*repo.*dev.*note.*cuis' <<<"$out"
check "a second index should read nothing new" grep -q 'nothing new' <<<"$(d index)"
check "the start of a word finds it" grep -q 'Music sketchpad' <<<"$(d find webso)"
check "a worktree isn't a project" bash -c "! grep -q 'Worktree copy' <<<\"\$1\"" _ "$(d find websocket)"
check "a note is found" grep -q 'note .*Inbox' <<<"$(d find websocket)"
check "a plan in a project's plans/ folder is a design page: $(d find quorumless | head -1)" grep -q '^repo .*Cloud nodes' <<<"$(d find quorumless)"
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

# The Cuis image's classes: a row a package (whose it is), a row a class with
# its comment and categories; read as text; opened in Emacs at the class
# while no image answers (VIKIX_SWANK_PORT=9 and no Cuis port: the door
# isn't tried), --other in Emacs outright.
check "a class of Vikix's package is found, named for its package: $(d find VikixSwank | head -1)" grep -q '^cuis .*VikixSwank (VikixDesktop)' <<<"$(d find VikixSwank | head -1)"
check "found by its comment's words" grep -q 'VikixSwank (VikixDesktop)' <<<"$(d find '"client of StumpWM"')"
check "a package of yours is a row, said yours: $(d find 'counts' --source cuis)" grep -q "^cuis .*Mine (Cuis package, yours)" <<<"$(d find 'package of my own' --source cuis)"
check "a class of yours, found by a category's selector" grep -q '^cuis .*Counter (Mine)' <<<"$(d find 'up:by:' --source cuis)"
cls=$(d find Counter --source cuis --json | python3 -c 'import json,sys; print([h["id"] for h in json.load(sys.stdin) if h["id"].endswith("#Counter")][0])')
text=$(d read "$cls")
check "a class reads as its comment, bangs and quotes unescaped: $text" grep -q "it's mine. A bang inside: ! there." <<<"$text"
check "then a line a category with its selectors, class-side ones marked: $text" bash -c "grep -q '^counting: up, up:by:$' <<<\"\$1\" && grep -q '^accessing: count$' <<<\"\$1\" && grep -q '^instance creation: new (class side)$' <<<\"\$1\"" _ "$text"
check "a package reads as its description, classes and what it extends: $(d read "cuis:$HOME/cuis/NewPackages/Mine.pck.st")" bash -c "grep -q 'classes: Counter' <<<\"\$1\" && grep -q 'extends: String (,)' <<<\"\$1\"" _ "$(d read "cuis:$HOME/cuis/NewPackages/Mine.pck.st")"
: > "$t/opened"; d open "$cls" 2> "$t/err"; sleep 0.3
check "with no image answering, a class opens in Emacs at its definition, and says why: $(cat "$t/opened") $(cat "$t/err")" grep -q "emacsclient -c -n +6 $HOME/cuis/NewPackages/Mine.pck.st" "$t/opened"
check "and says the image wasn't there: $(cat "$t/err")" grep -q "Cuis isn't running" "$t/err"
: > "$t/opened"; d open "$cls" --other; sleep 0.3
check "--other opens the package file in Emacs outright: $(cat "$t/opened")" grep -q "emacsclient -c -n +6 $HOME/cuis/NewPackages/Mine.pck.st" "$t/opened"
check "docs_search's enum should offer cuis" grep -q '"cuis"' "$here/bin/vikix-mcp"

# Changed, and gone.
sleep 1; printf '# Python\n\nNow with mypy too.\n' > "$HOME/dev/python/README.md"
out=$(d index)
check "only what changed is read again: $out" grep -q 'Read 1 dev' <<<"$out"
check "and found by its new words" grep -q Python <<<"$(d find mypy)"
rm "$HOME/src/music/docs/bridge.md"
d index >/dev/null
check "a file gone is gone" test "$(d find transport)" = "nothing found"
sleep 1; sed -i 's/one class that counts/one class that tallies/' "$HOME/cuis/NewPackages/Mine.pck.st"
out=$(d index)
check "a changed package is read again, by itself: $out" grep -q 'Read 1 cuis' <<<"$out"
check "and its rows made anew" grep -q 'Mine (Cuis package, yours)' <<<"$(d find tallies --source cuis)"
rm "$HOME/cuis/NewPackages/Mine.pck.st"
d index >/dev/null
check "a package gone takes its classes with it" test "$(d find Counter --source cuis)" = "nothing found"

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
  ui_pids+=("$xvfb")
  for _ in $(seq 1 50); do
    xdpyinfo -display ":$n" >/dev/null 2>&1 && break
    sleep .1
  done
  printf '#!/bin/sh\necho "browser $*" >> %s/opened\n' "$t" > "$t/bin/notify-send"; chmod +x "$t/bin/notify-send"
  # Other desks can have the same rofi prompt open. Only this pick's child
  # counts as ready; a machine-wide pgrep sent keys before our menu existed.
  # Stay off X while rofi grabs the keyboard: window searches stalled it.
  rofi_wait() {
    python3 - "$pick" "$@" <<'PYROFI'
from pathlib import Path
import os
import sys
import time
root, wanted = int(sys.argv[1]), sys.argv[2:]
def parent(pid):
    text = (Path("/proc") / str(pid) / "stat").read_text()
    return int(text[text.rindex(")") + 2:].split()[1])
def ours(pid):
    seen = set()
    while pid > 1 and pid not in seen:
        if pid == root:
            return True
        seen.add(pid)
        pid = parent(pid)
    return False
end = time.monotonic() + 15
while time.monotonic() < end:
    for path in Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            args = [os.fsdecode(a) for a in (path / "cmdline").read_bytes().split(b"\0") if a]
            if args:
                args[0] = os.path.basename(args[0])
            if args[:len(wanted)] == wanted and ours(int(path.name)):
                sys.exit(0)
        except (OSError, ValueError):
            continue
    time.sleep(.1)
sys.exit("this document pick did not open its expected rofi prompt")
PYROFI
  }
  for way in Return ctrl+Return; do
    : > "$t/opened"
    DISPLAY=":$n" timeout --kill-after=3s 30s python3 "$here/bin/vikix-docs" pick >"$t/pick-out" 2>"$t/pick-errors" &
    pick=$!
    ui_pids+=("$pick")
    if rofi_wait rofi -dmenu -p docs; then
      sleep 1
      DISPLAY=":$n" xdotool type mypy
      DISPLAY=":$n" xdotool key Return
      if rofi_wait rofi -dmenu -i -p mypy; then
        sleep 1
        DISPLAY=":$n" xdotool key "$way"
      else
        fail=1
      fi
    else
      fail=1
    fi
    wait "$pick" || { cat "$t/pick-errors"; fail=1; }
    ui_pids=("$xvfb")
    sleep .5
    if [ "$way" = Return ]; then want='^browser .*/md/.*\.html'; else want="emacsclient -c -n .*dev/python/README.md"; fi
    check "Super+F2's menus: $way should open the hit its way: $(cat "$t/opened")" grep -q "$want" "$t/opened"
  done
  cleanup_ui
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


# Zeal's docsets, read in place: a made-up docset whose pages are files here
# (an entry found by its name, by a member's name, read at its anchor or at
# the id the page gives its name, opened as a page there) and one kept
# compressed (opened in Zeal, a stand-in); the entry named by the words
# first; nothing of them copied into the catalogue.
export VIKIX_DOCS_ZEAL="$t/docsets"
python3 - "$t/docsets" <<'PY'
import os, sqlite3, sys
root = sys.argv[1]
def docset(name, key, entries, pages):
    d = os.path.join(root, name + ".docset", "Contents", "Resources"); os.makedirs(d)
    with open(os.path.join(root, name + ".docset", "Contents", "Info.plist"), "w") as f:
        f.write(f'<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>{key}</string>'
                f'<key>CFBundleName</key><string>{name}</string><key>DocSetPlatformFamily</key><string>{key}</string></dict></plist>\n')
    db = sqlite3.connect(os.path.join(d, "docSet.dsidx"))
    db.execute("CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)")
    db.execute("CREATE INDEX __zi_name0001 ON searchIndex (name COLLATE NOCASE)")
    db.executemany("INSERT INTO searchIndex (name, type, path) VALUES (?, ?, ?)", entries); db.commit()
    for path, text in pages.items():
        full = os.path.join(d, "Documents", path); os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f: f.write(text)
docset("Quokka", "quokka",
       [("str.split", "Method", "lib/strings.html#//apple_ref/Method/str.split"), ("wombatify", "Function", "lib/strings.html"),
        ("split", "Function", "lib/misc.html#//apple_ref/Function/split"), ("Splitter", "Class", "lib/misc.html"),
        ("Walrus.tusk", "Method", "lib/misc.html"), ("Audio.daw", "Class", "lib/misc.html"), ("Cal.2026", "Constant", "lib/misc.html")],
       {"lib/strings.html": '<html><body><p>Strings, an intro: the pelican words.</p>'
                            '<a name="//apple_ref/Method/str.split"></a><dt id="str.split">str.split(sep)</dt><dd>Splits: the quoll fact.</dd>'
                            '<dt id="wombatify">wombatify(s)</dt><dd>Makes it a wombat: the wombatify fact.</dd></body></html>',
        "lib/misc.html": '<html><body><a name="//apple_ref/Function/split"></a><p>split: the echidna fact.</p></body></html>'})
docset("Numbat", "numbat", [("alias", "Builtin", "x.html"), ("splitfoo", "Builtin", "y.html"), ("websocket", "Builtin", "z.html")], {})
PY
printf '#!/bin/sh\necho "zeal $*" >> %s/opened\n' "$t" > "$t/bin/zeal"; chmod +x "$t/bin/zeal"
check "an entry named by the words comes first, with its kind and docset: $(d find str.split | head -1)" grep -q '^zeal  *str.split — Method, Quokka$' <<<"$(d find str.split | head -1)"
check "the entry that is the word before the ones starting with it: $(d find split --source zeal | grep '^zeal' | head -3 | tr '\n' '|')" bash -c 'test "$(head -1 <<<"$1")" = "zeal   split — Function, Quokka" && grep -q "Splitter — Class, Quokka" <<<"$1" && grep -q "splitfoo — Builtin, Numbat" <<<"$1"' _ "$(d find split --source zeal | grep '^zeal' | head -3)"
check "a member is found by its own name, when no name starts with the word: $(d find tusk --source zeal)" grep -q 'Walrus.tusk — Method, Quokka' <<<"$(d find TUSK --source zeal)"
check "but not while names start with it (that scan is the slow part)" test "$(d find split --source zeal --limit 20 | grep -c 'str.split')" = 0
check "a search lists the docsets' entries among the catalogue's, a share of the list" grep -q '^zeal' <<<"$(d find split --limit 8)"
check "an entry reads as its own part of the page, from its anchor: $(d read zeal:quokka:Method:str.split)" bash -c 'grep -q "the quoll fact" <<<"$1" && ! grep -q "pelican\|wombatify fact" <<<"$1"' _ "$(d read zeal:quokka:Method:str.split)"
check "or from the id the page gives its name" bash -c 'grep -q "the wombatify fact" <<<"$1" && ! grep -q "quoll" <<<"$1"' _ "$(d read zeal:quokka:Function:wombatify)"
check "one kept compressed says Zeal shows it" grep -q 'kept compressed by Zeal' <<<"$(d read zeal:numbat:Builtin:alias)"
: > "$t/opened"; d open zeal:quokka:Method:str.split; d open zeal:quokka:Function:wombatify; sleep 0.3
check "an entry opens as its page in the docs browser, at its anchor: $(cat "$t/opened")" grep -q '^browser file://.*/Quokka.docset/Contents/Resources/Documents/lib/strings.html#//apple_ref/Method/str.split$' "$t/opened"
check "or at the id its name has on the page" grep -q '^browser file://.*lib/strings.html#wombatify$' "$t/opened"
: > "$t/opened"; d open zeal:numbat:Builtin:alias; d open zeal:quokka:Method:str.split --other; sleep 0.3
check "one kept compressed opens in Zeal at the entry, and --other always does: $(cat "$t/opened")" bash -c 'grep -q "^zeal dash-plugin://keys=numbat&query=alias$" "$1" && grep -q "^zeal dash-plugin://keys=quokka&query=str.split$" "$1"' _ "$t/opened"
check "status counts the docsets, read in place: $(d status | grep zeal)" grep -q '^  zeal  *10  in 2 docsets, read in place' <<<"$(d status)"
check "list counts their entries" grep -qxP 'zeal\t10' <<<"$(d list)"
check "nothing of a docset is copied into the catalogue" test -z "$(d list --source zeal)"
check "a gone entry is said: $(d read zeal:quokka:Method:nothing 2>&1)" grep -q 'no document' <<<"$(d read zeal:quokka:Method:nothing 2>&1)"
# The scan for a member is the slow part (half a second over the real
# docsets), so a search over every source asks for it only when the words
# look like code or the catalogue had fewer hits than the list holds.
check "a plain word the catalogue has pages for isn't scanned for as a member: $(d find daw --limit 1)" bash -c '! grep -q "Audio.daw" <<<"$(d find daw --limit 1)"'
check "but it is when the list has room: $(d find daw --limit 20 | grep '^zeal')" grep -q 'Audio.daw — Class, Quokka' <<<"$(d find daw --limit 20)"
check "an entry named by a plain word comes after the catalogue's own, not before: $(d find websocket --limit 2 | grep -v '^   ')" bash -c 'test "$(head -1 <<<"$1" | cut -c1-5)" != "zeal " && grep -q "websocket — Builtin, Numbat" <<<"$1"' _ "$(d find websocket --limit 2)"
check "and a word written as code always is: $(d find 2026 --limit 1)" grep -q 'Cal.2026 — Constant, Quokka' <<<"$(d find 2026 --limit 1)"
check "--source zeal always scans" grep -q 'Audio.daw' <<<"$(d find daw --source zeal --limit 2)"

# Links to the web: the websites of the packages installed (xbps's answer),
# the links the language guides list, your own file of links; marked, opened
# in the browser, never fetched (a proxy nothing can reach stands guard).
cat > "$t/bin/xbps-query" <<'X'
#!/bin/sh
case "$*" in
  "-Rs ") printf '[-] ardour-9.7_1   Professional-grade digital audio workstation\n[*] ruff-0.6.9_1   An extremely fast Python linter\n' ;;
  "-R -S ardour") printf 'pkgver: ardour-9.7_1\nshort_desc: Professional-grade digital audio workstation\nlicense: GPL-2.0-or-later\nhomepage: http://ardour.org\n' ;;
  "-l") printf 'ii ruff-0.6.9_1   An extremely fast Python linter\n' ;;
  "-R -p homepage -s ") printf 'ardour-9.7_1: http://ardour.org (https://mirror/current)\nruff-0.6.9_1: https://docs.astral.sh/ruff (https://mirror/current)\n' ;;
esac
X
sleep 1
printf '# Python\n\nNow with mypy too.\n\n- The tutorial: https://docs.python.org/3/tutorial/\n- ruff: https://docs.astral.sh/ruff/ · pytest: https://docs.pytest.org/\n' > "$HOME/dev/python/README.md"
printf '# mine\nhttps://example.org/runit-book The runit book\nnot a link at all\nA page about sv https://example.org/sv  # title first works too\n' > "$XDG_CONFIG_HOME/vikix/docs-links"
out=$(http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 VIKIX_DOCS_SOURCES="pkg web" d index)
check "the links are read, fetching nothing: $out" grep -q 'Read .*6 web' <<<"$out"
check "a link of yours, marked as the web's: $(d find 'runit book' | head -1)" grep -q '^web  *🌐 The runit book — https://example.org/runit-book$' <<<"$(d find 'runit book' | head -1)"
check "the title before the URL too" grep -q 'A page about sv — https://example.org/sv' <<<"$(d find 'page about' --source web)"
check "a language guide's link, named for the language: $(d find pytest --source web)" grep -q 'pytest (python) — https://docs.pytest.org/' <<<"$(d find pytest --source web)"
check "an installed package's website" grep -q 'ruff: its website — https://docs.astral.sh/ruff' <<<"$(d find ruff --source web)"
check "not one that isn't installed (its card has the link)" test "$(d find ardour --source web)" = "nothing found"
check "a link reads as a word that it isn't here" grep -q 'never fetches' <<<"$(d read web:own:https://example.org/runit-book)"
: > "$t/opened"; http_proxy=http://127.0.0.1:9 d open web:own:https://example.org/runit-book; d open web:own:https://example.org/runit-book --other; sleep 0.3
check "a link opens in the default browser, both ways: $(cat "$t/opened")" test "$(grep -c '^xdg-open https://example.org/runit-book$' "$t/opened")" = 2
check "the web can't be asked" grep -q 'never fetched' <<<"$(d ask "what is runit" --source web 2>&1)"

# PDFs: by the text they carry, a row a page within the first twenty, opened
# at the page; a scanned one by its name alone; no pdftotext said plainly.
if command -v pdftotext >/dev/null; then
  python3 - "$HOME/src/music" <<'PY'
import os, sys
def pdf(path, pages):
    """A PDF by hand: a page a text, "" for a page with no text (a scan's)."""
    objs = []
    def add(body): objs.append(body); return len(objs)
    font = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    kids = []
    for text in pages:
        stream = f"BT /F1 12 Tf 72 720 Td ({text}) Tj ET" if text else ""
        content = add(f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream")
        kids.append(add(f"<< /Type /Page /Parent PAGES /MediaBox [0 0 612 792] /Contents {content} 0 R /Resources << /Font << /F1 {font} 0 R >> >> >>"))
    pages_obj = add(f"<< /Type /Pages /Kids [{' '.join(f'{k} 0 R' for k in kids)}] /Count {len(kids)} >>")
    objs[:] = [o.replace("PAGES", f"{pages_obj} 0 R") for o in objs]
    catalog = add(f"<< /Type /Catalog /Pages {pages_obj} 0 R >>")
    out = "%PDF-1.4\n"; offsets = []
    for n, body in enumerate(objs, 1):
        offsets.append(len(out)); out += f"{n} 0 obj\n{body}\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n" + "".join(f"{o:010d} 00000 n \n" for o in offsets)
    out += f"trailer\n<< /Size {len(objs) + 1} /Root {catalog} 0 R >>\nstartxref\n{xref}\n%%EOF\n"
    with open(path, "w") as f: f.write(out)
pdf(os.path.join(sys.argv[1], "docs", "manual.pdf"), ["the pelican fact, page one", "the kakapo fact, page two"] + [f"page {n}" for n in range(3, 23)] + ["the tuatara fact, past the bound", "page 24", "page 25"])
pdf(os.path.join(sys.argv[1], "scan.pdf"), ["", ""])
PY
  out=$(d index)
  check "a project's PDFs are read: $out" grep -q 'Read 2 repo' <<<"$out"
  check "a page is a row, found by its words: $(d find kakapo | head -1)" grep -q '^repo .*manual (music/docs/manual.pdf) › page 2$' <<<"$(d find kakapo | head -1)"
  check "the whole is a row too" grep -q '^repo .*manual (music/docs/manual.pdf)$' <<<"$(d find pelican --limit 5)"
  check "only the first twenty pages are read" test "$(d find tuatara)" = "nothing found"
  page=$(d find kakapo --tsv | head -1 | cut -f1)
  check "a page reads as its text alone: $(d read "$page")" bash -c 'grep -q "the kakapo fact" <<<"$1" && ! grep -q pelican <<<"$1"' _ "$(d read "$page")"
  check "a scanned PDF is a row by its name, saying so: $(d find scan.pdf --tsv | cut -f3-)" grep -q 'scanned PDF: no text' <<<"$(d find scan --source repo --tsv)"
  printf '#!/bin/sh\necho "zathura $*" >> %s/opened\n' "$t" > "$t/bin/zathura"; chmod +x "$t/bin/zathura"
  : > "$t/opened"; d open "$page"; VIKIX_TERMINAL="$t/bin/term" d open "$page" --other; sleep 0.3
  check "a page opens in the viewer at that page: $(cat "$t/opened")" grep -q "^zathura --page=2 $HOME/src/music/docs/manual.pdf$" "$t/opened"
  check "--other shows its text in a terminal" grep -q "^terminal -e sh -c pdftotext -l 20 .*manual.pdf - | less$" "$t/opened"
  rm "$t/bin/zathura"
  out=$(VIKIX_DOCS_PDFTOTEXT=no-such-pdftotext d index --full)
  check "without pdftotext a PDF is a row by its name, saying what to install: $(d find manual.pdf --source repo --tsv | head -1)" grep -q 'pdftotext (vikix pkg add poppler-utils)' <<<"$(d find manual --source repo --tsv | head -1)"
  check "and no page" test "$(d find kakapo)" = "nothing found"
  check "read says it too" grep -q "pdftotext isn't installed" <<<"$(VIKIX_DOCS_PDFTOTEXT=no-such-pdftotext d read "repo:$HOME/src/music/docs/manual.pdf")"
  d index --full >/dev/null
  check "pages are back with pdftotext" grep -q 'page 2' <<<"$(d find kakapo | head -1)"
  rm "$HOME/src/music/scan.pdf"; d index >/dev/null
  check "a PDF gone is gone" test "$(d find scan --source repo)" = "nothing found"
else
  echo "(no pdftotext here: the PDF part is skipped)"
fi

# Asking: the documents found for the question go to the model, local
# (Ollama, a stand-in on a port) unless --claude; the answer names them; no
# key, no local AI: said, nothing sent; your own documents closed to an agent.
log="$t/ai-requests"; : > "$log"
python3 "$here/tests/fake-ai.py" "$log" > "$t/ai-port" &
ai=$!
for _ in $(seq 50); do [ -s "$t/ai-port" ] && break; sleep 0.1; done
port=$(cat "$t/ai-port")
if [ -n "$port" ]; then
  export OLLAMA_HOST="127.0.0.1:$port"
  # This test may itself run under an agent (a session's shell, the tester):
  # VIKIX_EVAL_PARENT=1 is vikix-eval's "nobody above", so these are the user's.
  export VIKIX_EVAL_PARENT=1
  out=$(d ask "patterns sent over a websocket to the DAW" 2> "$t/err")
  check "a local model answers, and the documents are named: $out $(cat "$t/err")" bash -c 'grep -q "^fake local answer" <<<"$1" && grep -q "^  \[1\] repo:.*DESIGN.md — Music sketchpad" <<<"$1"' _ "$out"
  check "said to be on this laptop: $(cat "$t/err")" grep -q 'on this laptop; from vikix, repo, dev, note' "$t/err"
  check "the documents went to the local model, in order: $(tail -1 "$log" | cut -c1-200)" bash -c 'grep -q "/api/chat" <<<"$(tail -1 "$1")" && grep -qF "n=\\\"1\\\" id=\\\"repo:" <<<"$(tail -1 "$1")" && grep -q "Patterns as Lisp" <<<"$(tail -1 "$1")"' _ "$log"
  check "nothing went to Anthropic" bash -c '! grep -q /v1/messages "$1"' _ "$log"
  n=$(wc -l < "$log")
  check "no key, --claude says so and sends nothing" grep -q 'needs your key' <<<"$(d ask "websocket" --claude 2>&1)"
  check "local AI down: said, nothing sent, no cloud instead" grep -q "isn't answering.*Nothing was sent" <<<"$(OLLAMA_HOST=127.0.0.1:9 d ask "websocket" 2>&1)"
  check "no request was made" test "$(wc -l < "$log")" = "$n"
  out=$(ANTHROPIC_API_KEY=test-key-123 ANTHROPIC_BASE_URL="http://127.0.0.1:$port" d ask "websocket DAW" --claude 2> "$t/err")
  check "--claude sends the passages to Anthropic and says so: $out $(cat "$t/err")" bash -c 'grep -q "^fake claude answer" <<<"$1" && grep -q "passages go to Anthropic" "$2" && grep -q /v1/messages <<<"$(tail -1 "$3")"' _ "$out" "$t/err" "$log"
  mkdir -p "$HOME/.config/vikix"; printf 'cloud_url=http://127.0.0.1:%s/v1\n' "$port" >> "$HOME/.config/vikix/ai"
  check "no key, --cloud says so and sends nothing" grep -q 'vikix ai key set openrouter' <<<"$(OPENROUTER_API_KEY='' d ask "websocket" --cloud 2>&1)"
  out=$(OPENROUTER_API_KEY=or-key d ask "websocket DAW" --cloud 2> "$t/err")
  check "--cloud sends the passages to the service and says so: $out $(cat "$t/err")" bash -c 'grep -q "^fake cloud answer" <<<"$1" && grep -q "passages go to 127.0.0.1" "$2" && grep -q "/v1/chat/completions" <<<"$(tail -1 "$3")" && grep -q "Bearer or-key" <<<"$(tail -1 "$3")"' _ "$out" "$t/err" "$log"
  sed -i '/^cloud_url=/d' "$HOME/.config/vikix/ai"
  check "--source picks the sources: $(d ask "wombat shared bus" --source own 2>&1 | tail -2)" grep -q '^  \[1\] own:.*page.html' <<<"$(d ask "wombat shared bus" --source own 2>/dev/null)"
  n=$(wc -l < "$log")
  check "--show prints what would be sent, sending nothing" grep -q '<document n="1"' <<<"$(d ask "wombat shared bus" --source own --show)"
  check "nothing was sent for it" test "$(wc -l < "$log")" = "$n"
  unset VIKIX_EVAL_PARENT
  printf '#!/bin/sh\npython3 "$@"\n' > "$t/bin/claude"; chmod +x "$t/bin/claude"   # an agent above the command, by name
  out=$("$t/bin/claude" "$here/bin/vikix-docs" ask "wombat shared bus" --source own 2>&1 || true)
  check "under an agent, your own documents stay closed (a folder not opened): $out" grep -q 'closed to agents' <<<"$out"
  out=$("$t/bin/claude" "$here/bin/vikix-docs" ask "quokka process number" --source own 2>/dev/null)
  check "but an opened folder's are read: $out" grep -q '^  \[1\] own:.*ch04-processes.md' <<<"$out"
  unset OLLAMA_HOST
fi
kill "$ai" 2>/dev/null; wait "$ai" 2>/dev/null || true

# The watch on ~/src: inotifywait (a stand-in reading a file of events)
# started and stopped by hand, its state said; a document that changes is
# read on its own, one gone dropped; not started twice; said when missing.
: > "$t/events"
printf '#!/bin/sh\nexec tail -n0 -f %s\n' "$t/events" > "$t/bin/inotifywait"; chmod +x "$t/bin/inotifywait"
check "with no watch, status says so: $(d watch status)" grep -q '^off' <<<"$(d watch status)"
out=$(d watch on)
check "the watch starts and says what it does: $out" grep -q "^watching $HOME/src" <<<"$out"
check "on again says it's there" grep -q 'already watching' <<<"$(d watch on)"
check "status says on, with the pid: $(d watch status)" grep -q "^on $HOME/src since .*(pid [0-9]*)" <<<"$(d watch status)"
pid=$(cat "$HOME/.local/state/vikix/docs/watch.pid")
printf '# Fresh\n\nthe axolotl fact\n' > "$HOME/src/music/docs/fresh.md"
echo "$HOME/src/music/docs/fresh.md" >> "$t/events"
for _ in $(seq 60); do grep -q Fresh <<<"$(d find axolotl --source repo)" && break; sleep 0.1; done
check "a document written is read within seconds: $(d find axolotl)" grep -q '^repo .*Fresh' <<<"$(d find axolotl --source repo)"
rm "$HOME/src/music/docs/fresh.md"; echo "$HOME/src/music/docs/fresh.md" >> "$t/events"
for _ in $(seq 60); do [ "$(d find axolotl --source repo)" = "nothing found" ] && break; sleep 0.1; done
check "one deleted is dropped" test "$(d find axolotl --source repo)" = "nothing found"
check "status says when a change was last read: $(d watch status)" grep -q 'last change read' <<<"$(d watch status)"
out=$(d watch off)
check "off stops it and says so: $out" grep -q 'is off' <<<"$out"
sleep 0.3
check "the watcher is gone" bash -c '! kill -0 "$1" 2>/dev/null' _ "$pid"
check "and its inotifywait with it" bash -c '! pgrep -f "tail -n0 -f $1" >/dev/null' _ "$t/events"
check "off again says there was none" grep -q '^not watching' <<<"$(d watch off)"
mv "$t/bin/inotifywait" "$t/bin/inotifywait.away"
check "without inotifywait, on says what to install: $(d watch on 2>&1)" grep -q 'inotify-tools' <<<"$(d watch on 2>&1)"
check "the MCP tools offer zeal and web" bash -c 'grep -q "\"zeal\"" "$1" && grep -q "\"web\"" "$1"' _ "$here/bin/vikix-mcp"

[ "$fail" = 0 ] && echo "docs: guides, projects, ~/dev and notes found by words, phrases and OR, Vikix's first, the one named first, only what changed read again, opened, man pages styled, tldr pages, your own documents a section at a time and closed to agents until opened and the ArchWiki from wikiman's copies, the page in Nyxt asked for, read-only tools for the agents, Zeal's docsets read in place, links to the web marked and never fetched, PDFs a page a row opened at the page, a question answered locally from chosen documents, and the watch on ~/src"
exit "$fail"
