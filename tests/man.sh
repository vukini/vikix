#!/usr/bin/env bash
# tests/man.sh — every vikix command has a man page, made from its header:
#
#   - lib/man.py --check passes on the real scripts, and a page comes out
#     for each of them, with the sections a page has; mandoc's lint (when
#     mandoc is here) finds nothing to warn about, and man shows one
#   - on made-up scripts: the forms, their descriptions, a table kept as it
#     is, prose, an example block, the files and the other commands named
#     land in the right sections, and what roff would misread is escaped
#   - a header out of shape fails --check with its reason (no title, no
#     usage line, a description run into its form), and costs only its own
#     page when the pages are written
#   - a page made earlier for a command that's gone is removed; a page of
#     the user's with a vikix name is not; a second run writes nothing
#   - the commands of the plugins in the user's list get pages too, one
#     switched off included; a command that only starts lib/NAME.py takes
#     its forms from there; a plugin's header out of shape costs that
#     page and nothing else; a plugin taken off the list loses its pages;
#     a page that isn't Vikix's is never written over
#   - docs/commands.md is what lib/man.py --guide prints: the same
#     headers as a page of the guides (tests/info.sh makes the manual)
#   - 40-config, in a made-up home, installs them where MANPATH points,
#     man finds one there, and a dry run writes nothing
#   - vikix.bash puts that folder on MANPATH, keeping the system's pages

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME MANPATH
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has() { grep -qF -- "$2" "$1"; }

# --- the real scripts ---------------------------------------------------------
export HOME="$t/nobody"   # no plugins of the real home's: lib/man.py reads its list
mkdir -p "$HOME"
python3 "$here/lib/man.py" --check > "$t/check" 2>&1 || { echo "FAIL: headers out of shape:"; sed 's/^/  /' "$t/check"; fail=1; }
python3 "$here/lib/man.py" "$t/real/man1" > "$t/out" 2>&1 || { echo "FAIL: lib/man.py failed:"; sed 's/^/  /' "$t/out"; exit 1; }
for f in "$here"/bin/vikix*; do
  page="$t/real/man1/${f##*/}.1"
  check "no page for ${f##*/}" test -s "$page"
  [ -s "$page" ] || continue
  for section in NAME SYNOPSIS 'SEE ALSO'; do
    check "${f##*/}.1 has no $section" grep -qx ".SH $section" "$page"
  done
  # whatis reads this line: the name, " \- ", one line of plain words.
  check "${f##*/}.1: NAME isn't 'name \\- summary'" bash -c "grep -A1 -x '.SH NAME' '$page' | tail -1 | grep -qE '^vikix[a-z\\\\-]* \\\\- [^ ].*\$'"
done
check "pages for something that isn't a script" test "$(find "$t/real/man1" -name '*.1' | wc -l)" = "$(find "$here/bin" -maxdepth 1 -name 'vikix*' | wc -l)"
check "vikix.1 doesn't list the other pages" has "$t/real/man1/vikix.1" 'vikix\-backup\fR(1)'
check "vikix-backup.1 has no restore form" has "$t/real/man1/vikix-backup.1" 'vikix backup restore'
check "vikix-backup.1 doesn't name its password file" has "$t/real/man1/vikix-backup.1" '\(ti/.config/vikix/backup\-password'
check "vikix-idle.1 doesn't point to vikix-lock(1)" has "$t/real/man1/vikix-idle.1" 'vikix\-lock\fR(1)'
if command -v mandoc >/dev/null; then
  mandoc -T lint -W warning "$t"/real/man1/*.1 > "$t/lint" 2>&1 || true
  [ -s "$t/lint" ] && { echo "FAIL: mandoc's lint warned:"; sed "s|$t/real/man1/||; s/^/  /" "$t/lint" | head -20; fail=1; }
else
  echo "(mandoc isn't here: its lint left out)"
fi
if command -v man >/dev/null; then
  shown=$(MANWIDTH=80 man -M "$t/real" vikix-backup 2>/dev/null | col -b || true)
  check "man doesn't show vikix-backup's forms" grep -q 'vikix backup restore PATH \[ID\]' <<<"$shown"
  check "man doesn't show vikix-backup's prose" grep -q 'Every backup is encrypted' <<<"$shown"
else
  echo "(man isn't here: showing a page left out)"
fi

# --- made-up scripts: what goes where -------------------------------------------
v="$t/v"
mkdir -p "$v/bin" "$v/lib"
cp "$here/lib/man.py" "$v/lib/"
echo 9.9.9 > "$v/VERSION"
cat > "$v/bin/vikix" <<'EOF'
#!/usr/bin/env bash
# vikix — the everyday command.
#
#   vikix good FILE   see vikix-good
EOF
cat > "$v/bin/vikix-good" <<'EOF'
#!/usr/bin/env bash
# vikix-good — a good header (`vikix good`): it has every part there is.
# Its short name is `gd`.
#
#   vikix good FILE [--force]   read FILE, a second
#                               line of it
#   vikix good table
#                       ONE   the first   (a)
#                       TWO   the second  (b)
#   gd alone
#   vikix-good pipe | other    with a pipe
#
# Prose about ~/.config/vikix/good and C:\path, kept in
# ~/.local/state/vikix/good/.
# .a line starting with a dot
#
#   output   one
#   more     two
#
# See vikix other, and vikix-py.
EOF
cat > "$v/bin/vikix-other" <<'EOF'
#!/bin/sh
# vikix-other — another one.
#
#   vikix other   do it
EOF
cat > "$v/bin/vikix-py" <<'EOF'
#!/usr/bin/env python3
"""vikix-py — a Python one, by its docstring.

  vikix py run NAME   run NAME

Prose here.
"""
EOF
python3 "$v/lib/man.py" --check > "$t/check" 2>&1 || { echo "FAIL: good headers refused:"; sed 's/^/  /' "$t/check"; fail=1; }
python3 "$v/lib/man.py" "$t/made/man1" >/dev/null 2>&1 || { echo "FAIL: lib/man.py failed on the made-up scripts"; fail=1; }
g="$t/made/man1/vikix-good.1"
check "the title line" has "$g" '.TH "VIKIX-GOOD" 1 '
check "the version in the footer" has "$g" '"Vikix 9.9.9"'
check "NAME: the first sentence, without the (\`vikix good\`) aside" grep -qxF 'vikix\-good \- a good header: it has every part there is' "$g"
check "the rest of the title paragraph isn't in DESCRIPTION" has "$g" 'Its short name is \(gagd\(ga.'
check "a form: bold, its FILE underlined, its hyphens real" has "$g" '\fBvikix good \fR\fIFILE\fR\fB [\-\-force]\fR'
check "a description on two lines isn't joined to its form" bash -c "grep -A2 -F 'vikix good \\fR\\fIFILE' '$g' | grep -qx 'line of it'"
check "a table under a form isn't kept as it is" bash -c "grep -A3 -F 'vikix good table' '$g' | grep -qxF 'ONE   the first   (a)'"
check "a short name from the title (gd) isn't a form" has "$g" '\fBgd alone\fR'
check "a form with no description leaves the next one without its tag" bash -c "grep -A1 -F 'gd alone' '$g' | grep -qxF '\\&'"
check "the prose isn't under DESCRIPTION" bash -c "sed -n '/^\\.SH DESCRIPTION/,/^\\.SH FILES/p' '$g' | grep -qF 'Prose about'"
check "a backslash isn't escaped" has "$g" 'C:\epath'
check "a ~ would come out as an accent in groff" bash -c "! grep -v '^\.\\\\\"' '$g' | grep -q '~'"
check "a line starting with a dot isn't escaped" grep -qxF '\&.a line starting with a dot' "$g"
check "an example block isn't kept as it is" bash -c "grep -B1 -xF 'output   one' '$g' | grep -qx '.nf'"
check "FILES misses a path" bash -c "sed -n '/^\\.SH FILES/,/^\\.SH SEE/p' '$g' | grep -qxF '\(ti/.local/state/vikix/good/'"
check "FILES has something that isn't a path" test "$(sed -n '/^\.SH FILES/,/^\.SH SEE/p' "$g" | grep -c '^\\(ti/')" = 2
check "SEE ALSO misses a command it names" has "$g" '\fBvikix\fR(1), \fBvikix\-other\fR(1), \fBvikix\-py\fR(1)'
check "a Python script's docstring isn't read" has "$t/made/man1/vikix-py.1" '\fBvikix py run \fR\fINAME\fR'
check "vikix.1 doesn't list vikix-py with its summary" bash -c "grep -A1 -F 'vikix\\-py\\fR(1)' '$t/made/man1/vikix.1' | grep -qxF 'a Python one, by its docstring'"
if command -v mandoc >/dev/null; then
  mandoc -T lint -W warning "$t"/made/man1/*.1 > "$t/lint" 2>&1 || true
  [ -s "$t/lint" ] && { echo "FAIL: mandoc's lint warned about the made-up pages:"; sed 's/^/  /' "$t/lint" | head; fail=1; }
fi

# --- a second run, a command gone, a page of yours -------------------------------
check "a second run wrote pages again" bash -c "python3 '$v/lib/man.py' '$t/made/man1' | grep -q '(0 changed)'"
printf '.TH MINE 1\n.SH NAME\nvikix-mine \\- my own page\n' > "$t/made/man1/vikix-mine.1"
rm "$v/bin/vikix-other"
python3 "$v/lib/man.py" "$t/made/man1" >/dev/null 2>&1 || true
check "the page of a command that's gone was left" test ! -e "$t/made/man1/vikix-other.1"
check "a page of yours was removed" test -s "$t/made/man1/vikix-mine.1"
check "SEE ALSO still names the command that's gone" bash -c "! grep -qF 'vikix\\-other' '$g'"

# --- headers out of shape -------------------------------------------------------
printf '#!/bin/sh\n# vikix-title — a title and nothing else.\necho\n' > "$v/bin/vikix-title"
printf '#!/bin/sh\n# vikix-wrong — the name of another script.\n#\n#   vikix named   do it\n' > "$v/bin/vikix-named"
printf '#!/bin/sh\n# vikix-run — a description run into its form.\n#\n#   vikix run [NAME] does the thing, at once\n' > "$v/bin/vikix-run"
printf '#!/bin/sh\n# vikix-words — the same, with nothing but words.\n#\n#   vikix words [on|off] this one says what it does\n' > "$v/bin/vikix-words"
printf '#!/bin/sh\necho no header at all\n' > "$v/bin/vikix-bare"
python3 "$v/lib/man.py" --check > "$t/check" 2>&1 && { echo "FAIL: headers out of shape passed --check"; fail=1; }
check "--check doesn't say vikix-title has no usage line" grep -q '^bin/vikix-title: no usage line' "$t/check"
check "--check doesn't say vikix-named's first line is wrong" grep -q "^bin/vikix-named: the header's first line isn't 'vikix-named — one line'" "$t/check"
check "--check doesn't catch a description run into its form" grep -q '^bin/vikix-run: a form with its description run into it' "$t/check"
check "--check doesn't catch one made of plain words" grep -q '^bin/vikix-words: a form with its description run into it' "$t/check"
check "--check doesn't say vikix-bare has no header" grep -q '^bin/vikix-bare: no header' "$t/check"
check "--check blames a good header" bash -c "! grep -q '^bin/vikix-good' '$t/check'"
python3 "$v/lib/man.py" "$t/broken/man1" > "$t/out" 2>&1 && { echo "FAIL: writing pages from broken headers said all was well"; fail=1; }
check "a broken header cost another script its page" test -s "$t/broken/man1/vikix-good.1"
check "a broken header got a page" test ! -e "$t/broken/man1/vikix-title.1"
check "writing doesn't say which pages are missing" grep -q 'no man page for .*vikix-title' "$t/out"

# --- the plugins' commands -------------------------------------------------------
ph="$t/phome"   # a home with plugins added: man.py reads its list and their folder
w="$t/w"        # and a Vikix of three commands, all in shape
mkdir -p "$w/bin" "$w/lib"
cp "$here/lib/man.py" "$w/lib/"
cp "$v/VERSION" "$w/"
cp "$v/bin/vikix" "$v/bin/vikix-good" "$w/bin/"
printf '#!/bin/sh\n# vikix-plugin — small additions.\n#\n#   vikix plugin list   the plugins\n' > "$w/bin/vikix-plugin"
pl="$ph/.local/share/vikix/plugins"
mkdir -p "$ph/.config/vikix" "$pl/notes/bin" "$pl/notes/lib" "$pl/off/bin" "$pl/unlisted/bin" "$pl/bad/bin"
printf 'notes\n#off off\nbad\n# a comment\n' > "$ph/.config/vikix/plugins.list"
cat > "$pl/notes/bin/jot" <<'EOF'
#!/usr/bin/env python3
"""jot — a note from anywhere.

  jot add "TEXT, with a comma"   keep TEXT
  jot open                       the notes, see jot-sync and vikix good

Kept in ~/.config/vikix/plugins/notes/settings.
"""
EOF
printf '#!/bin/sh\n# jot-sync — the notes up to the cloud.\n#\n#   jot-sync   what jot does, by another name\n' > "$pl/notes/bin/jot-sync"
printf '#!/bin/sh\n# wrapped — starts the program beside it.\nexec python3 ../lib/wrapped.py\n' > "$pl/notes/bin/wrapped"
printf '"""wrapped — a program with its forms in lib.\n\n  wrapped go   do it\n\nAnd a line about it.\n"""\n' > "$pl/notes/lib/wrapped.py"
printf '#!/bin/sh\n# offcmd — of a plugin switched off.\n#\n#   offcmd   still linked, so still a page\n' > "$pl/off/bin/offcmd"
printf '#!/bin/sh\n# stray — of a plugin not in the list.\n#\n#   stray   no page\n' > "$pl/unlisted/bin/stray"
printf '#!/bin/sh\n# badcmd: no dash, no forms.\n' > "$pl/bad/bin/badcmd"
# First into a folder where another program's page has one of the names.
pw="$ph/taken/man1"
mkdir -p "$pw"
printf '.TH WRAPPED 1\n.SH NAME\nwrapped \\- another program of that name\n' > "$pw/wrapped.1"
HOME="$ph" python3 "$w/lib/man.py" "$pw" > "$t/out" 2>&1 || { echo "FAIL: a plugin's broken header failed the lot (Vikix's own were fine):"; sed 's/^/  /' "$t/out"; fail=1; }
check "a page that isn't Vikix's was written over" has "$pw/wrapped.1" 'another program of that name'
check "nothing said about the page in the way" grep -q "wrapped.1 isn't Vikix's" "$t/out"
# Then into an empty one.
pm="$ph/man/man1"
HOME="$ph" python3 "$w/lib/man.py" "$pm" >/dev/null 2>&1 || true
check "no page for a plugin's command" test -s "$pm/jot.1"
check "a plugin's page doesn't say which plugin" has "$pm/jot.1" '"Vikix plugin notes"'
check "a plugin's page: its first line doesn't say where it's from" bash -c "head -1 '$pm/jot.1' | grep -qF 'plugins/notes/bin/jot'"
check "a quoted argument with a comma was taken for prose" has "$pm/jot.1" 'jot add "'
check "a plugin's page doesn't point to vikix-plugin, its plugin's other command and Vikix's" has "$pm/jot.1" '\fBvikix\fR(1), \fBjot\-sync\fR(1), \fBvikix\-good\fR(1), \fBvikix\-plugin\fR(1)'
check "no page for a command of a plugin switched off" test -s "$pm/offcmd.1"
check "a page for a plugin that isn't in the list" test ! -e "$pm/stray.1"
check "a page from a plugin's broken header" test ! -e "$pm/badcmd.1"
check "a command that starts lib/NAME.py didn't take its forms from there" has "$pm/wrapped.1" '\fBwrapped go\fR'
check "vikix.1 doesn't list the plugins' commands" bash -c "sed -n '/commands of your plugins/,\$p' '$pm/vikix.1' | grep -qF 'jot\\-sync\\fR(1)'"
check "Vikix's pages aren't beside the plugins'" test -s "$pm/vikix-good.1"
if command -v mandoc >/dev/null; then
  mandoc -T lint -W warning "$pm"/*.1 > "$t/lint" 2>&1 || true
  [ -s "$t/lint" ] && { echo "FAIL: mandoc's lint warned about the plugins' pages:"; sed 's/^/  /' "$t/lint" | head; fail=1; }
fi
printf '#off off\n' > "$ph/.config/vikix/plugins.list"
HOME="$ph" python3 "$w/lib/man.py" "$pm" >/dev/null 2>&1 || true
check "a plugin off the list kept its pages" test ! -e "$pm/jot.1" -a ! -e "$pm/jot-sync.1"
check "the plugin still listed lost its page" test -s "$pm/offcmd.1"
python3 "$w/lib/man.py" --check "$pl/notes/bin" "$pl/off/bin" > "$t/check" 2>&1 || { echo "FAIL: --check refused good plugin headers:"; sed 's/^/  /' "$t/check"; fail=1; }
python3 "$w/lib/man.py" --check "$pl/bad/bin" > "$t/check" 2>&1 && { echo "FAIL: --check passed a plugin's broken header"; fail=1; }
check "--check doesn't name the plugin's script" grep -q "^plugins/bad/bin/badcmd: the header's first line isn't 'badcmd — one line'" "$t/check"

# --- the same headers as a page of the guides ------------------------------------
python3 "$here/lib/man.py" --guide > "$t/commands.md" 2>"$t/out" || { echo "FAIL: lib/man.py --guide failed:"; sed 's/^/  /' "$t/out"; fail=1; }
cmp -s "$t/commands.md" "$here/docs/commands.md" ||
  { echo "FAIL: docs/commands.md isn't what the headers say now: python3 lib/man.py --guide > docs/commands.md"; fail=1; }
python3 "$v/lib/man.py" --guide > "$t/guide.md"
check "the guide page has no section for a command" grep -qx '## vikix-good' "$t/guide.md"
check "the guide page doesn't list the commands first" grep -qxF -- '- [vikix-good](#vikix-good): a good header: it has every part there is' "$t/guide.md"
check "a form isn't code in the guide page" grep -qF -- '- `vikix good FILE [--force]` — read FILE, a second line of it' "$t/guide.md"
check "a table under a form isn't a code block" bash -c "grep -B1 -xF 'ONE   the first   (a)' '$t/guide.md' | grep -qxF '\`\`\`'"
check "a path in prose isn't code (Markdown would eat <this> and A_NAME)" grep -qF 'Prose about `~/.config/vikix/good` and `C:\path`, kept in `~/.local/state/vikix/good/`.' "$t/guide.md"
check "the guide page has a broken header's command" bash -c "! grep -q 'vikix-title' '$t/guide.md'"
check "a plugin's command is in Vikix's guide page" bash -c "! HOME='$ph' python3 '$w/lib/man.py' --guide | grep -q offcmd"

# --- installed by 40-config -----------------------------------------------------
export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_DIR="$here"   # this checkout, not the installed ~/vikix
mkdir -p "$HOME"
man1="$HOME/.local/share/man/man1"
DRY_RUN=1 bash "$here/install/40-config.sh" > "$t/dry" 2>&1 || { echo "FAIL: 40-config's dry run failed:"; tail -5 "$t/dry"; fail=1; }
check "a dry run wrote man pages" test ! -e "$man1"
check "a dry run doesn't say it would write them" grep -q 'would run: write the vikix man pages' "$t/dry"
bash "$here/install/40-config.sh" >/dev/null 2>"$t/stage-errors" || { echo "FAIL: 40-config failed:"; cat "$t/stage-errors"; exit 1; }
check "40-config didn't install vikix.1" test -s "$man1/vikix.1"
check "40-config didn't install vikix-backup.1" test -s "$man1/vikix-backup.1"
first=$(stat -c %Y "$man1/vikix.1")
sleep 1
bash "$here/install/40-config.sh" >/dev/null 2>&1
check "a second 40-config wrote the pages again" test "$first" = "$(stat -c %Y "$man1/vikix.1")"

# vikix.bash puts them on MANPATH; the empty entry keeps the system's pages.
got=$(HOME="$HOME" bash --norc -ic "unset MANPATH; . '$here/config/bash/vikix.bash' 2>/dev/null; . '$here/config/bash/vikix.bash' 2>/dev/null; echo \"\$MANPATH\"" 2>/dev/null)
check "MANPATH after vikix.bash, twice, is '$got'" test "$got" = "$HOME/.local/share/man:"
got=$(HOME="$HOME" MANPATH=':/opt/x/man' bash --norc -ic ". '$here/config/bash/vikix.bash' 2>/dev/null; echo \"\$MANPATH\"" 2>/dev/null)
check "MANPATH beside one already set is '$got'" test "$got" = "$HOME/.local/share/man::/opt/x/man"
check "vikix-session doesn't set MANPATH" grep -q 'MANPATH="$HOME/.local/share/man:${MANPATH:-}"; export MANPATH' "$here/bin/vikix-session"
if command -v man >/dev/null; then
  found=$(MANPATH="$HOME/.local/share/man:" man -w vikix-backup 2>/dev/null || true)
  check "man doesn't find vikix-backup through MANPATH (got '$found')" test "$found" = "$man1/vikix-backup.1"
  # The system's pages still answer: the empty entry.
  if man -w ls >/dev/null 2>&1; then
    check "MANPATH hides the system's pages" bash -c "MANPATH='$HOME/.local/share/man:' man -w ls >/dev/null 2>&1"
  fi
  if command -v makewhatis >/dev/null; then
    check "man says its index lacks the page (makewhatis not run)" bash -c "! MANPATH='$HOME/.local/share/man:' man -w vikix-backup 2>&1 | grep -q 'outdated'"
  fi
fi

[ "$fail" = 0 ] && echo "man: a page for each of $(find "$here/bin" -maxdepth 1 -name 'vikix*' | wc -l) commands, from its header"
exit "$fail"
