#!/usr/bin/env python3
"""lib/man.py — a man page for every vikix command, made from its header.

  lib/man.py DIR           write vikix.1 and a vikix-NAME.1 for every
                           bin/vikix-* into DIR (40-config: ~/.local/share/
                           man/man1), and remove the pages it made earlier
                           for commands that are gone
  lib/man.py --page FILE   one script's page, on stdout
  lib/man.py --check       say which headers aren't in the standard shape,
                           and fail if any (tests/lint.sh runs this)

Nothing is written by hand: the header every bin/vikix-* starts with (the
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
SEE ALSO. A form is known by its first word: vikix, vikix-NAME, or a short
name the first paragraph gives in `backticks` (`note`).
"""
import ast
import datetime
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
BIN = os.path.join(HERE, "bin")
MARK = '.\\" Made by Vikix (lib/man.py) from the header of bin/'
TITLE = re.compile(r"^(vikix(?:-[a-z0-9-]+)?) — (\S.*)$")
GAP = re.compile(r" {2,}")
PATH = re.compile(r"~/[\w.<>/+-]*[\w>/]")
# A form that swallowed its description: these never belong in one.
PROSE = re.compile(r", |; |: | \(|[a-z]\. ")


def scripts():
    """bin/vikix and every bin/vikix-*, by name."""
    return sorted(f for f in os.listdir(BIN) if f == "vikix" or f.startswith("vikix-"))


def header(path):
    """The header's lines: the comment block under the #! line, or the docstring."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    if "python" in lines[0]:
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

    def __init__(self, name, lines):
        self.name = name
        self.problems = []
        self.entries = []   # (form, its description's lines, lines of it kept as they are)
        self.body = []      # ("text", lines) or ("pre", lines), in order
        self.summary = ""
        self.words = {"vikix"}   # what a form starts with, besides vikix-NAME
        paragraphs, now = [], []
        for line in lines + [""]:
            line = line.rstrip()
            if line:
                now.append(line)
            elif now:
                paragraphs.append(now)
                now = []
        if not paragraphs:
            self.problems.append("no header: a comment under the #! line (or a docstring) starting 'vikix-NAME — one line'")
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
            self.problems.append("no usage line: an indented 'vikix NAME ...   what it does'")

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
            if PROSE.search(form) or wordy(form):
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

    def see_also(self, names):
        text = self.texts() + "\n" + "\n".join(entry[0] for entry in self.entries)
        found = set()
        for other in names:
            if other in (self.name, "vikix"):
                continue
            spaced = "vikix " + other[len("vikix-"):]
            if re.search(rf"(?<![\w-]){re.escape(other)}(?![\w-])|(?<![\w-]){re.escape(spaced)}(?![\w-])", text):
                found.add(other)
        return sorted(found)


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


def roff(page, version, date, names, summaries):
    out = [MARK + page.name,
           f'.TH "{page.name.upper()}" 1 "{date}" "Vikix {version}" "Vikix"',
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
        for other in names:
            if other != "vikix":
                out += [".TP", f"\\fB{esc(other)}\\fR(1)", esc(summaries[other])]
    else:
        out.append(", ".join(f"\\fB{esc(n)}\\fR(1)" for n in ["vikix"] + page.see_also(names)))
    return "\n".join(out) + "\n"


def version_and_date():
    with open(os.path.join(HERE, "VERSION")) as f:
        version = f.read().strip()
    # The date of the commit the checkout is at: the same pages from the same Vikix.
    try:
        date = subprocess.run(["git", "-C", HERE, "log", "-1", "--format=%cs"], capture_output=True,
                              text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        date = ""
    return version, date or datetime.date.today().isoformat()


def pages():
    return {name: Page(name, header(os.path.join(BIN, name))) for name in scripts()}


def check():
    bad = 0
    for name, page in pages().items():
        for problem in page.problems:
            print(f"bin/{name}: {problem}")
            bad += 1
    if bad:
        print(f"{bad} header(s) not in the standard shape (lib/man.py's own header says what it is)")
    return 1 if bad else 0


def write(directory):
    all_pages = pages()
    broken = [name for name, page in all_pages.items() if page.problems]
    if broken:
        # A header man can't be made from costs its own page, not the others.
        print("no man page for " + ", ".join(broken) + " (lib/man.py --check says why)", file=sys.stderr)
    good = {name: page for name, page in all_pages.items() if not page.problems}
    names = sorted(good)
    summaries = {name: page.summary for name, page in good.items()}
    version, date = version_and_date()
    os.makedirs(directory, exist_ok=True)
    changed = 0
    for name, page in good.items():
        text = roff(page, version, date, names, summaries)
        path = os.path.join(directory, name + ".1")
        try:
            with open(path, encoding="utf-8") as f:
                if f.read() == text:
                    continue
        except (OSError, UnicodeDecodeError):
            pass
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        changed += 1
    # Pages made here earlier for commands that are gone; never a page of yours.
    for file in os.listdir(directory):
        if file.endswith(".1") and file[:-2] not in good and file.startswith("vikix"):
            path = os.path.join(directory, file)
            try:
                with open(path, encoding="utf-8") as f:
                    ours = f.readline().startswith(MARK)
            except (OSError, UnicodeDecodeError):
                ours = False
            if ours:
                os.remove(path)
                changed += 1
    print(f"{len(good)} man pages in {directory} ({changed} changed)")
    return 1 if broken else 0


def main(args):
    if args == ["--check"]:
        return check()
    if len(args) == 2 and args[0] == "--page":
        name = os.path.basename(args[1])
        page = Page(name, header(args[1]))
        if page.problems:
            sys.exit("\n".join(f"{args[1]}: {p}" for p in page.problems))
        all_pages = {n: p for n, p in pages().items() if not p.problems}
        version, date = version_and_date()
        sys.stdout.write(roff(page, version, date, sorted(all_pages), {n: p.summary for n, p in all_pages.items()}))
        return 0
    if len(args) == 1 and not args[0].startswith("-"):
        return write(args[0])
    print((__doc__ or "").split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
