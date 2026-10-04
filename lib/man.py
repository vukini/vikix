#!/usr/bin/env python3
"""lib/man.py — a man page for every vikix command, made from its header.

  lib/man.py DIR           write vikix.1 and a vikix-NAME.1 for every
                           bin/vikix-* into DIR (40-config: ~/.local/share/
                           man/man1), a page for each command of the plugins
                           you've added, and remove the pages it made earlier
                           for commands that are gone
  lib/man.py --page FILE   one script's page, on stdout
  lib/man.py --guide       the same headers as a page of the guides, on
                           stdout: docs/commands.md is this, and tests/man.sh
                           fails when it isn't
  lib/man.py --check [BIN...]
                           say which headers aren't in the standard shape,
                           and fail if any: bin/vikix* (tests/lint.sh runs
                           this), or every script in the folders named (a
                           plugin's bin)

Nothing is written by hand: the header every command starts with (the
comment under the #! line, or a Python script's docstring), which
`vikix help` and each -h print, is the one source. Its standard shape:

  vikix-NAME — one line saying what it is, then perhaps more.

    vikix NAME sub ARGS   what it does: two spaces or more between the
                          form and its description, more lines further in
    vikix NAME other
                          or the description on the lines after

  Prose, in paragraphs. An indented block that doesn't start with the
  command (output, a settings file) is shown as it is.

The first line gives NAME; the forms and their descriptions SYNOPSIS; the
rest DESCRIPTION; the ~/ paths it names FILES; the other commands it names
SEE ALSO. A form is known by its first word: the command's own name, vikix,
vikix-NAME, or a short name the first paragraph gives in `backticks`
(`note`). A command that only starts a program beside it (bin/flights, for
lib/flights.py) may leave its forms to that program's docstring.

The plugins' commands are those of ~/.config/vikix/plugins.list, in
~/.local/share/vikix/plugins/NAME/bin: vikix plugin runs this again when
one is added, removed, or the pin moves.
"""
import ast
import datetime
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
BIN = os.path.join(HERE, "bin")
MARK = '.\\" Made by Vikix (lib/man.py) from the header of '
TITLE = re.compile(r"^(\S+) — (\S.*)$")
# The plugins: where vikix plugin keeps them, and the user's list of them.
PLUGINS = os.path.join(os.path.expanduser("~"), ".local", "share", "vikix", "plugins")
PLUGINS_LIST = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config"),
                            "vikix", "plugins.list")
GAP = re.compile(r" {2,}")
PATH = re.compile(r"~/[\w.<>/+-]*[\w>/]")
# A form that swallowed its description: these never belong in one.
PROSE = re.compile(r", |; |: | \(|[a-z]\. ")


def scripts():
    """bin/vikix and every bin/vikix-*, by name."""
    return sorted(f for f in os.listdir(BIN) if f == "vikix" or f.startswith("vikix-"))


def folder(path):
    """The scripts of a bin folder, by name."""
    try:
        return sorted(f for f in os.listdir(path) if os.path.isfile(os.path.join(path, f)))
    except OSError:
        return []


def plugins():
    """The user's plugins, switched off or not (as vikix-plugin's own list
    of them: their commands stay linked), each with its bin folder."""
    out = []
    try:
        with open(PLUGINS_LIST, encoding="utf-8") as f:
            for entry in f:
                found = re.fullmatch(r"(?:#off )?([a-z][a-z0-9-]*)", entry.strip())
                if found and found.group(1) not in [name for name, _ in out]:
                    out.append((found.group(1), os.path.join(PLUGINS, found.group(1), "bin")))
    except OSError:
        pass
    return out


def header(path):
    """The header's lines: the comment block under the #! line, or the docstring."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    if "python" in lines[0] or path.endswith(".py"):
        try:
            doc = ast.get_docstring(ast.parse(text))
        except SyntaxError:   # lint's to report; here it is a script without a header
            doc = None
        return doc.split("\n") if doc else []
    out = []
    for line in lines[1:]:
        if not line.startswith("#"):
            break
        out.append(line[2:] if line.startswith("# ") else line[1:])
    return out


def indent(line):
    return len(line) - len(line.lstrip(" "))


def wordy(form):
    """Plain words in a row, as prose has and a form hasn't: its description, a space too near."""
    run, seen_other = 0, False
    for word in form.split():
        if re.fullmatch(r"[a-z]+", word):
            run += 1
            if run >= (3 if seen_other else 5):
                return True
        else:
            run, seen_other = 0, True
    return False


def summary(title):
    """The title paragraph as one short line: what whatis and vikix(1) show."""
    text = re.sub(r" \((?:`[^`]*`(?:, )?)+\)", "", title)   # "(`vikix backup`)": the forms say it
    text = re.split(r"(?<=[a-z)])\. ", text)[0].rstrip(".")   # its first sentence
    if len(text) > 75:
        # Too long for a line: up to its first aside, when that leaves something said.
        for cut in re.finditer(r": | \(|; ", text):
            if len(text[:cut.start()].split()) >= 3:
                return text[:cut.start()]
    return text


class Page:
    """A header, read into the parts of a man page."""

    def __init__(self, name, lines, origin=None, plugin=None):
        self.name = name
        self.origin = origin or "bin/" + name   # said in the page's first line, and by --check
        self.plugin = plugin                    # the plugin a command comes with, or None: Vikix's own
        self.problems = []
        self.entries = []   # (form, its description's lines, lines of it kept as they are)
        self.body = []      # ("text", lines) or ("pre", lines), in order
        self.summary = ""
        self.words = {"vikix", name}   # what a form starts with, besides vikix-NAME
        paragraphs, now = [], []
        for line in lines + [""]:
            line = line.rstrip()
            if line:
                now.append(line)
            elif now:
                paragraphs.append(now)
                now = []
        if not paragraphs:
            self.problems.append(f"no header: a comment under the #! line (or a docstring) starting '{name} — one line'")
            return
        first = TITLE.match(paragraphs[0][0])
        if not first or first.group(1) != name:
            self.problems.append(f"the header's first line isn't '{name} — one line'")
            return
        # The title paragraph ends where an indented block begins.
        title = [first.group(2)]
        rest = paragraphs[0][1:]
        while rest and indent(rest[0]) < 2:
            title.append(rest.pop(0).strip())
        title = " ".join(title)
        self.summary = summary(title)
        self.words |= set(re.findall(r"`([a-z][a-z0-9-]*)`", title))
        if len(title.split()) - len(self.summary.split()) > 3:
            self.body.append(("text", [title[0].upper() + title[1:]]))
        for paragraph in ([rest] if rest else []) + paragraphs[1:]:
            self.paragraph(paragraph)
        if not self.entries:
            self.problems.append(f"no usage line: an indented '{name.replace('vikix-', 'vikix ')} ...   what it does'")

    def command(self, line):
        """Does this line start with the command (so: a form)?"""
        word = line.split()[0]
        return word in self.words or word.startswith("vikix-")

    def paragraph(self, lines):
        """Runs of prose and of indented lines; an indented run is usage, or shown as it is."""
        runs = []
        for line in lines:
            if not runs or (indent(line) >= 2) != (indent(runs[-1][0]) >= 2):
                runs.append([])
            runs[-1].append(line)
        for run in runs:
            if indent(run[0]) < 2:
                self.body.append(("text", run))
            elif self.command(run[0]):
                self.usage(run)
            else:
                base = min(indent(line) for line in run)
                self.body.append(("pre", [line[base:] for line in run]))

    def usage(self, run):
        """A usage block: forms at its own indent, their descriptions beside and under them."""
        base = indent(run[0])
        raw = []   # [form, the description beside it, the lines under it]
        for line in run:
            if indent(line) > base and raw:
                raw[-1][2].append(line)
                continue
            line = line.strip()
            if not self.command(line):
                self.problems.append(f"in a usage block, a line that is neither a form nor further in: '{line[:50]}'")
                continue
            form, beside = (GAP.split(line, maxsplit=1) + [""])[:2]
            bare = re.sub(r"\"[^\"]*\"|'[^']*'", "X", form)   # what's quoted is an argument, whatever it holds
            if PROSE.search(bare) or wordy(bare):
                self.problems.append(f"a form with its description run into it (two spaces between them): '{form[:60]}'")
            raw.append([form, beside, []])
        for form, beside, under in raw:
            # Columns in the lines underneath: a table, kept as it is.
            if sum(1 for line in under if GAP.search(line.strip())) >= 2:
                depth = min(indent(line) for line in under)
                self.entries.append((form, [beside] if beside else [], [line[depth:] for line in under]))
            else:
                filled = [" ".join(line.split()) for line in [beside] + under if line]
                self.entries.append((form, filled, []))

    def texts(self):
        """Everything but the forms, for the paths and commands it names."""
        out = [self.summary]
        for _, filled, pre in self.entries:
            out += filled + pre
        for _, lines in self.body:
            out += lines
        return "\n".join(out)

    def files(self):
        text = re.sub(r"(~/\S*/)\n\s*(?=[\w.-]+\.\w)", r"\1", self.texts())   # a path cut by the line's end
        seen = []
        for path in PATH.findall(text):
            if path not in seen:
                seen.append(path)
        return seen

    def see_also(self, pages):
        """The other commands this one names: Vikix's as vikix-NAME or
        vikix NAME, and for a plugin's command, the others of its plugin."""
        text = self.texts() + "\n" + "\n".join(entry[0] for entry in self.entries)
        found = {"vikix-plugin"} if self.plugin else set()
        for other in pages.values():
            if other.name in (self.name, "vikix"):
                continue
            spellings = []
            if not other.plugin:
                spellings = [other.name, "vikix " + other.name[len("vikix-"):]]
            elif other.plugin == self.plugin:
                spellings = [other.name]
            if any(re.search(rf"(?<![\w-]){re.escape(word)}(?![\w-])", text) for word in spellings):
                found.add(other.name)
        return sorted(found & set(pages))


def esc(text):
    """TEXT as roff sees plain words: no escapes, and the characters groff
    would turn into typographic ones (a hyphen, ~ ` ' ^) kept as typed, so a
    path or a command copied from the page still works."""
    text = text.replace("\\", "\\e")
    for char, name in (("-", "\\-"), ("~", "\\(ti"), ("`", "\\(ga"), ("'", "\\(aq"), ("^", "\\(ha")):
        text = text.replace(char, name)
    return text


def plain(text):
    """A whole line of text: one starting with . or ' would be a request."""
    return ("\\&" if text[:1] in (".", "'") else "") + esc(text)


def form_roff(form):
    """A form: bold as typed, the words you replace (NAME, FILE) underlined."""
    parts = re.split(r"(\b[A-Z][A-Z0-9_]*\b)", form)
    return "".join(("\\fI%s\\fR" if i % 2 else "\\fB%s\\fR") % esc(p) for i, p in enumerate(parts) if p)


def pre_roff(lines):
    return [".nf"] + [plain(text) for text in lines] + [".fi"]


def roff(page, pages, version, date):
    """PAGE as a man page; PAGES, all of them by name, are what it may point to."""
    source = f"Vikix plugin {page.plugin}" if page.plugin else f"Vikix {version}"
    out = [MARK + page.origin,
           f'.TH "{page.name.upper()}" 1 "{date}" "{source}" "Vikix"',
           ".SH NAME",
           f"{esc(page.name)} \\- {esc(page.summary)}",
           ".SH SYNOPSIS"]
    for form, filled, pre in page.entries:
        out += [".TP", form_roff(form)]
        out += [plain(text) for text in filled]
        if pre:
            out += ([".br"] if filled else []) + pre_roff(pre)
        if not filled and not pre:
            out.append("\\&")
    if page.body:
        out.append(".SH DESCRIPTION")
        for i, (kind, lines) in enumerate(page.body):
            if kind == "text":
                out += ([".PP"] if i else []) + [plain(text.strip()) for text in lines]
            else:
                out += ([".PP"] if i else []) + [".RS 4"] + pre_roff(lines) + [".RE"]
    files = page.files()
    if files:
        out.append(".SH FILES")
        for path in files:
            out += [plain(path), ".br"]
        out.pop()
    out.append(".SH SEE ALSO")
    if page.name == "vikix":
        out.append("Each of these has a page of its own:")
        own = [p for p in pages.values() if not p.plugin and p.name != "vikix"]
        added = [p for p in pages.values() if p.plugin]
        for other in sorted(own, key=lambda p: p.name):
            out += [".TP", f"\\fB{esc(other.name)}\\fR(1)", esc(other.summary)]
        if added:
            out += [".PP", "And the commands of your plugins:"]
            for other in sorted(added, key=lambda p: p.name):
                out += [".TP", f"\\fB{esc(other.name)}\\fR(1)", esc(other.summary)]
    else:
        out.append(", ".join(f"\\fB{esc(n)}\\fR(1)" for n in ["vikix"] + page.see_also(pages)))
    return "\n".join(out) + "\n"


def commit_date(repo):
    """The date of the commit REPO is at: the same pages from the same commit."""
    try:
        date = subprocess.run(["git", "-C", repo, "log", "-1", "--format=%cs"], capture_output=True,
                              text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        date = ""
    return date or datetime.date.today().isoformat()


def version():
    with open(os.path.join(HERE, "VERSION")) as f:
        return f.read().strip()


def read(name, path, origin=None, plugin=None):
    """PATH's page. A command that only starts the program beside it
    (bin/NAME for lib/NAME.py) may leave its forms to that program's header."""
    page = Page(name, header(path), origin, plugin)
    beside = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(path))), "lib", name + ".py")
    if page.problems and not page.entries and os.path.isfile(beside):
        other = Page(name, header(beside), origin, plugin)
        if not other.problems:
            return other
    return page


def pages():
    """Vikix's own commands, by name."""
    return {name: read(name, os.path.join(BIN, name)) for name in scripts()}


def plugin_pages(folders):
    """The commands in FOLDERS, (plugin, its bin folder) pairs, by name."""
    out = {}
    for plugin, path in folders:
        for name in folder(path):
            out.setdefault(name, read(name, os.path.join(path, name), f"plugins/{plugin}/bin/{name}", plugin))
    return out


def check(folders):
    found = plugin_pages([(os.path.basename(os.path.dirname(os.path.abspath(f))), f) for f in folders]) if folders else pages()
    bad = 0
    for page in found.values():
        for problem in page.problems:
            print(f"{page.origin}: {problem}")
            bad += 1
    if bad:
        print(f"{bad} header(s) not in the standard shape (lib/man.py's own header says what it is)")
    return 1 if bad else 0


def ours(path):
    """Is the page at PATH one this made (and so one it may write over or remove)?"""
    try:
        with open(path, encoding="utf-8") as f:
            return f.readline().startswith(MARK)
    except (OSError, UnicodeDecodeError):
        return False


def write(directory):
    found = pages()
    for name, page in plugin_pages(plugins()).items():
        found.setdefault(name, page)   # a plugin's command never takes the place of Vikix's
    # A header man can't be made from costs its own page, not the others. One
    # of Vikix's is said, and fails; a plugin's is its own repo's to check
    # (lib/man.py --check on its bin says why), and only goes without a page.
    broken = sorted(name for name, page in found.items() if page.problems and not page.plugin)
    if broken:
        print("no man page for " + ", ".join(broken) + " (lib/man.py --check says why)", file=sys.stderr)
    good = {name: page for name, page in found.items() if not page.problems}
    dates = {None: commit_date(HERE), "plugin": commit_date(PLUGINS)}
    os.makedirs(directory, exist_ok=True)
    changed = 0
    for name, page in good.items():
        text = roff(page, good, version(), dates["plugin" if page.plugin else None])
        path = os.path.join(directory, name + ".1")
        if os.path.exists(path) and not ours(path):
            # A page of the user's, or of another program with the same name: theirs.
            print(f"{path} isn't Vikix's: left as it is", file=sys.stderr)
            continue
        try:
            with open(path, encoding="utf-8") as f:
                if f.read() == text:
                    continue
        except OSError:
            pass
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        changed += 1
    # Pages made here earlier for commands that are gone; never a page of yours.
    for file in os.listdir(directory):
        path = os.path.join(directory, file)
        if file.endswith(".1") and file[:-2] not in good and ours(path):
            os.remove(path)
            changed += 1
    print(f"{len(good)} man pages in {directory} ({changed} changed)")
    return 1 if broken else 0


# --- the same headers as a page of the guides ---------------------------------

def md(text):
    """TEXT as Markdown that says what it said: outside the `code` it already
    has, a word Markdown would read as markup (a path, <this>, A_NAME, a *) is
    code too."""
    def word(found):
        token = found.group(0)
        if not re.search(r"[*_\\]|~/|<[A-Za-z/]", token):
            return token
        core = token.rstrip(".,;:)")
        opened = "(" if core.startswith("(") else ""
        return f"{opened}`{core[len(opened):]}`{token[len(core):]}"
    parts = text.split("`")
    if len(parts) % 2 == 0:   # a ` without its pair: all of it plain words
        return re.sub(r"\S+", word, text.replace("`", "'"))
    return "`".join(part if i % 2 else re.sub(r"\S+", word, part) for i, part in enumerate(parts))


def fenced(lines):
    return ["```"] + lines + ["```", ""]


def guide():
    found = {name: page for name, page in pages().items() if not page.problems}
    out = ["# The commands",
           "",
           "Every `vikix` command: its forms, what each does, and the files it keeps. "
           "This page is made from the header each command's script starts with (`lib/man.py --guide`): "
           "the lines its `-h` prints, and the ones its man page is made from (`man vikix-backup`), "
           "so the three always say the same. Nobody edits it by hand.",
           "",
           "`vikix` is the one you type, and most of the others are reached through it: "
           "`vikix backup` runs `vikix-backup`. A few are what the desktop itself runs: "
           "the bar's fields, the session, the lock.",
           ""]
    out += [f"- [{name}](#{name}): {md(page.summary)}" for name, page in found.items()] + [""]
    for name, page in found.items():
        out += [f"## {name}", "", md(page.summary[0].upper() + page.summary[1:]) + ".", ""]
        listed = False
        for form, filled, pre in page.entries:
            code = f"`{form}`" if "`" not in form else form
            out.append(f"- {code}" + (" — " + md(" ".join(filled)) if filled else ""))
            listed = True
            if pre:
                out += [""] + fenced(pre)
                listed = False
        if listed:
            out.append("")
        for kind, lines in page.body:
            out += [md(" ".join(line.strip() for line in lines)), ""] if kind == "text" else fenced(lines)
    return "\n".join(out).rstrip("\n") + "\n"


def main(args):
    if args[:1] == ["--check"] and not any(arg.startswith("-") for arg in args[1:]):
        return check(args[1:])
    if args == ["--guide"]:
        sys.stdout.write(guide())
        return 0
    if len(args) == 2 and args[0] == "--page":
        name = os.path.basename(args[1])
        page = read(name, args[1])
        if page.problems:
            sys.exit("\n".join(f"{args[1]}: {p}" for p in page.problems))
        found = {n: p for n, p in pages().items() if not p.problems}
        found.setdefault(name, page)
        sys.stdout.write(roff(page, found, version(), commit_date(HERE)))
        return 0
    if len(args) == 1 and not args[0].startswith("-"):
        return write(args[0])
    print((__doc__ or "").split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
