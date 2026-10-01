#!/usr/bin/env python3
"""md2texi.py DOCS_DIR — the guides in docs/ as one Texinfo manual, on stdout.

40-config runs it and makeinfo on the result, so the guides can be read
in Emacs (C-h i, Vikix) and with `info vikix`. The Markdown stays the
only source; this knows just the Markdown the guides use: headings,
paragraphs, lists (one level of nesting), tables, fenced code, `code`,
**strong**, *emphasis*, links, diagrams: a line of its own that is
just `![What it shows](diagrams/NAME.svg)`, and screenshots, the same with
`shots/NAME.png`.

A diagram is three files in docs/diagrams/: NAME.mmd (the Mermaid
source), NAME.svg (drawn from it by docs/diagrams/render.sh, and what
GitHub and the HTML guide show) and NAME.txt (the same picture in plain
text, which makeinfo puts in the Info manual in its place). A missing
.svg or .txt is an error.

A screenshot is docs/shots/NAME.png: a picture in the web pages, and in
the Info manual, which can't show it, the words in its brackets.

The pages come in the order docs/README.md's table links them, and that
page is the manual's Top node. A link to another guide, or to a heading
in one, becomes a cross-reference; a link anywhere else goes to GitHub.
A link to a heading that isn't there is an error, so a broken link shows
up in tests/info.sh, not in the manual.
"""

import os
import re
import sys

REPO_URL = "https://github.com/vukini/vikix/blob/main/"


def die(msg):
    sys.stderr.write("md2texi: " + msg + "\n")
    sys.exit(1)


def escape(text):
    return text.replace("@", "@@").replace("{", "@{").replace("}", "@}")


def plain(text):
    """Heading text without Markdown marks: for node names and slugs."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return text.replace("`", "").replace("**", "").replace("*", "")


def slug(text):
    """The anchor GitHub gives a heading."""
    s = plain(text).strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def node_name(text):
    """Info node names can't hold : , . ( ), and paths read badly as names.
    "The desktop: `~/.stumpwm.d/user.lisp`" is "The desktop"; a path
    before the colon gives way to the words after it."""
    s = plain(text)
    if ":" in s:
        before, after = (p.strip() for p in s.split(":", 1))
        s = before if re.search(r"[A-Za-z]", before) and not re.search(r"[/.]", before) else after
        s = s[:1].upper() + s[1:]
    s = re.sub(r"[:,.()]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


class Manual:
    def __init__(self, docs):
        self.docs = docs
        self.pages = self.page_order()
        self.nodes = {}      # (page, slug) -> node name; slug "" is the page itself
        self.used = set()
        self.tree = {}       # node -> child nodes, for the menus
        for page in self.pages:
            self.collect(page)

    def page_order(self):
        text = self.read("README.md")
        pages = ["README.md"]
        for target in re.findall(r"\]\(([\w-]+\.md)\)", text):
            if target not in pages:
                pages.append(target)
        for name in sorted(os.listdir(self.docs)):
            if name.endswith(".md") and name not in pages:
                die(f"docs/{name} isn't linked from docs/README.md's table")
        return pages

    def read(self, page):
        path = os.path.join(self.docs, page)
        if not os.path.exists(path):
            die(f"docs/{page} is linked but doesn't exist")
        with open(path, encoding="utf-8") as f:
            return f.read()

    def unique(self, name, page):
        if name in self.used:
            name = f"{name} ({page[:-3]})".replace("(", "- ").replace(")", "")
        if name in self.used:
            die(f"two headings make the node '{name}'")
        self.used.add(name)
        return name

    def collect(self, page):
        """Give every heading a node name, and work out which is whose child."""
        top = page == "README.md"
        stack = []           # (level, node)
        in_code = False
        for line in self.read(page).splitlines():
            if line.startswith("```"):
                in_code = not in_code
                continue
            m = re.match(r"(#{1,3}) (.*)", line)
            if in_code or not m:
                continue
            level, title = len(m.group(1)), m.group(2)
            if top and level > 1:
                continue     # Top's own headings stay in the Top node
            name = "Top" if top else self.unique(node_name(title), page)
            self.nodes[(page, "" if level == 1 else slug(title))] = name
            self.tree[name] = []
            while stack and stack[-1][0] >= level:
                stack.pop()
            if stack:
                self.tree[stack[-1][1]].append(name)
            elif not top:
                self.tree["Top"].append(name)
            stack.append((level, name))
        if (page, "") not in self.nodes:
            die(f"docs/{page} has no '# Title' line")

    # --- inline text ------------------------------------------------------

    def inline(self, text, page):
        keep = []

        def hold(texi):
            keep.append(texi)
            return f"\0{len(keep) - 1}\0"

        def link(m):
            label, target = m.group(1), m.group(2)
            return hold(self.link(self.inline(label, page), target, page))

        text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, text)
        text = re.sub(r"`([^`]+)`", lambda m: hold("@code{" + escape(m.group(1)) + "}"), text)
        text = escape(text)
        text = re.sub(r"\*\*(.+?)\*\*", r"@strong{\1}", text)
        text = re.sub(r"(?<![\w*])\*(?=\S)(.+?)(?<=\S)\*(?![\w*])", r"@emph{\1}", text)
        return re.sub(r"\0(\d+)\0", lambda m: keep[int(m.group(1))], text)

    def link(self, label, target, page):
        arg = label.replace(",", "@comma{}")
        if re.match(r"https?://", target):
            return f"@uref{{{escape(target)},{arg}}}"
        file, _, anchor = target.partition("#")
        file = file or page
        if "/" not in file and file.endswith(".md") and file in self.pages:
            node = self.nodes.get((file, anchor))
            if node is None:
                die(f"docs/{page}: the link '{target}' goes to no heading")
            return f"@ref{{{node}}}" if plain(label) == node else f"@ref{{{node},,{arg}}}"
        path = os.path.normpath(os.path.join("docs", file))
        if not os.path.exists(os.path.join(self.docs, "..", path)):
            die(f"docs/{page}: the link '{target}' goes to no file")
        url = REPO_URL + path + ("#" + anchor if anchor else "")
        return f"@uref{{{escape(url)},{arg}}}"

    # --- blocks -----------------------------------------------------------

    def table(self, rows, page):
        """A two-column table reads best in Info as a list of terms, each
        with its text below. With more columns, each follows as "Header:
        value", the second too, or a row wouldn't say which is which."""
        cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
        head, body = cells[0], cells[2:]
        out = ["@table @asis"]
        for r in body:
            out.append("@item " + self.inline(r[0], page))
            text = self.inline(r[1], page) if len(r) > 1 else ""
            if len(head) > 2 and head[1] and text:
                text = f"{self.inline(head[1], page)}: {text}"
            for h, c in zip(head[2:], r[2:]):
                text += f"@*\n{self.inline(h, page)}: {self.inline(c, page)}"
            out.append(text)
        out.append("@end table")
        return out

    def diagram(self, name, alt, page):
        for ext in ("mmd", "svg", "txt"):
            if not os.path.exists(os.path.join(self.docs, "diagrams", f"{name}.{ext}")):
                die(f"docs/{page}: the diagram '{name}' has no docs/diagrams/{name}.{ext}")
        alt = escape(plain(alt)).replace(",", "@comma{}")
        return [f"@image{{diagrams/{name},,,{alt},svg}}"]

    def shot(self, name, alt, page):
        if not os.path.exists(os.path.join(self.docs, "shots", f"{name}.png")):
            die(f"docs/{page}: the screenshot docs/shots/{name}.png isn't there")
        words = escape(plain(alt))
        return ["@ifinfo", f"[Screenshot: {words}]", "@end ifinfo",
                "@ifnotinfo", f"@image{{shots/{name},,,{words.replace(',', '@comma{}')},png}}", "@end ifnotinfo"]

    def lists(self, items, page):
        """items: (indent, ordered, text). Nested by indentation."""
        out, stack = [], []   # stack of (indent, kind)
        for indent, ordered, text in items:
            while stack and indent < stack[-1][0]:
                out.append(f"@end {stack.pop()[1]}")
            if not stack or indent > stack[-1][0]:
                kind = "enumerate" if ordered else "itemize"
                out.append("@enumerate" if ordered else "@itemize @bullet")
                stack.append((indent, kind))
            out.append("@item")
            out.append(self.inline(text, page))
        while stack:
            out.append(f"@end {stack.pop()[1]}")
        return out

    def page(self, page):
        lines = self.read(page).splitlines()
        top = page == "README.md"
        out = []
        i = 0
        para = []

        def flush():
            if para:
                out.append(self.inline(" ".join(para), page))
                out.append("")
                para.clear()

        while i < len(lines):
            line = lines[i]
            if line.startswith("```"):
                flush()
                i += 1
                out.append("@example")
                while i < len(lines) and not lines[i].startswith("```"):
                    out.append(escape(lines[i]))
                    i += 1
                out.append("@end example")
                out.append("")
                i += 1
                continue
            m = re.fullmatch(r"!\[([^\]]+)\]\(diagrams/([\w-]+)\.svg\)", line.strip())
            if m:
                flush()
                out += self.diagram(m.group(2), m.group(1), page)
                out.append("")
                i += 1
                continue
            m = re.fullmatch(r"!\[([^\]]+)\]\(shots/([\w-]+)\.png\)", line.strip())
            if m:
                flush()
                out += self.shot(m.group(2), m.group(1), page)
                out.append("")
                i += 1
                continue
            m = re.match(r"(#{1,3}) (.*)", line)
            if m:
                flush()
                level, title = len(m.group(1)), m.group(2)
                if top:
                    out.append(("@top " if level == 1 else "@heading ") + self.inline(title, page))
                    if level == 1:
                        out.append("")
                        out.append(f"For Vikix {self.version()}.")
                else:
                    self.menu_before(out)
                    node = self.nodes[(page, "" if level == 1 else slug(title))]
                    out.append(f"@node {node}")
                    cmd = {1: "@chapter", 2: "@section", 3: "@subsection"}[level]
                    out.append(f"{cmd} {self.inline(title, page)}")
                    self.pending = node
                out.append("")
                i += 1
                continue
            if line.startswith("|"):
                flush()
                rows = []
                while i < len(lines) and lines[i].startswith("|"):
                    rows.append(lines[i])
                    i += 1
                out += self.table(rows, page)
                out.append("")
                continue
            if re.match(r"\s*([-*]|\d+\.) ", line):
                flush()
                items = []
                while i < len(lines):
                    m = re.match(r"(\s*)([-*]|\d+\.) (.*)", lines[i])
                    if m:
                        items.append((len(m.group(1)), m.group(2)[0].isdigit(), m.group(3)))
                    elif lines[i].strip() and items and lines[i].startswith(" "):
                        indent, ordered, text = items[-1]
                        items[-1] = (indent, ordered, text + " " + lines[i].strip())
                    else:
                        break
                    i += 1
                out += self.lists(items, page)
                out.append("")
                continue
            if not line.strip():
                flush()
            else:
                para.append(line.strip())
            i += 1
        flush()
        return out

    def menu_before(self, out):
        """The menu of the node just finished, before the next node starts."""
        children = self.tree.get(self.pending, [])
        if children:
            out.append("@menu")
            out += [f"* {c}::" for c in children]
            out.append("@end menu")
            out.append("")
        self.pending = None

    def version(self):
        try:
            with open(os.path.join(self.docs, "..", "VERSION")) as f:
                return f.read().strip()
        except OSError:
            return "(version unknown)"

    def texinfo(self):
        out = [
            "\\input texinfo",
            "@setfilename vikix.info",
            "@documentencoding UTF-8",
            "@settitle Vikix",
            "",
            "@dircategory Vikix",
            "@direntry",
            "* Vikix: (vikix).               Where things are, making it yours, fixing it.",
            "@end direntry",
            "",
            "@node Top",
        ]
        self.pending = None
        for page in self.pages:
            if page == "README.md":
                out += self.page(page)
                self.pending = "Top"
            else:
                out += self.page(page)
        self.menu_before(out)
        out.append("@bye")
        return "\n".join(out) + "\n"


def main():
    if len(sys.argv) != 2:
        die("usage: md2texi.py DOCS_DIR")
    sys.stdout.write(Manual(sys.argv[1]).texinfo())


if __name__ == "__main__":
    main()
