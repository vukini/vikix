#!/usr/bin/env python3
"""
Post-process a pandoc-generated EPUB (already unzipped) to work around two
recurring e-ink reader rendering bugs:

1. docx tables where Word's "repeat header row" was applied to every row,
   so pandoc emits all rows as <th> inside one <thead> with an empty
   <tbody>. Many e-ink reader apps render these as a collapsed, illegible
   block even though the markup is technically valid EPUB.

2. Even correctly-structured <table> markup fails to render usably on
   several e-ink reader apps (confirmed: xReaderPro on a BigMe 7" device).
   The reliable fix is to avoid <table> entirely for data grids.

This script converts every <table> found under EPUB/text/*.xhtml into
either:
  - a single "aside" box (<div class="aside">) if the table is a
    one-column "callout" box (colgroup has exactly one <col
    style="width: 100%">), or
  - a stack of "row cards" (<div class="table-cards"><div
    class="row-card">...) if the table has multiple columns of real data.

Usage:
    python3 fix_tables.py /path/to/unzipped/epub/build/dir

The dir should contain EPUB/text/*.xhtml (i.e. point it at the epub root,
not the text/ subfolder directly).

Requires: beautifulsoup4 (pip install --break-system-packages beautifulsoup4)

After running this, add the .aside / .table-cards / .row-card / .field-label
CSS rules from references/epub.css to the epub's stylesheet, then rezip:

    cd build
    rm -f ../OUTPUT.epub
    zip -X -q ../OUTPUT.epub mimetype
    zip -X -rq ../OUTPUT.epub META-INF EPUB -x mimetype

...and validate with epubcheck before delivering.
"""
import sys
import glob
from pathlib import Path
from bs4 import BeautifulSoup


def is_single_column_box(table):
    colgroup = table.find("colgroup")
    cols = colgroup.find_all("col") if colgroup else []
    if len(cols) != 1:
        return False
    style = cols[0].get("style", "").replace(" ", "")
    return style == "width:100%"


def normalize_thead_tbody(soup, table):
    """Fix the 'every row landed in <thead>' bug in place. Returns True if
    a fix was applied."""
    thead = table.find("thead")
    if not thead:
        return False
    rows = thead.find_all("tr", recursive=False)
    if len(rows) <= 1:
        return False
    header_row, data_rows = rows[0], rows[1:]
    tbody = table.find("tbody")
    if tbody is None:
        tbody = soup.new_tag("tbody")
        thead.insert_after(tbody)
    for row in data_rows:
        row.extract()
        for th in row.find_all("th"):
            th.name = "td"
        tbody.append(row)
    return True


def convert_to_aside(soup, table):
    cells = table.find_all(["th", "td"])
    div = soup.new_tag("div")
    div["class"] = "aside"
    for cell in cells:
        for child in list(cell.children):
            div.append(child.extract())
    table.replace_with(div)


def convert_to_row_cards(soup, table):
    thead = table.find("thead")
    tbody = table.find("tbody")
    if thead is None:
        return False
    headers = [c.get_text(strip=True) for c in thead.find_all(["th", "td"])]
    data_rows = tbody.find_all("tr") if tbody else []
    if not data_rows:
        return False

    wrapper = soup.new_tag("div")
    wrapper["class"] = "table-cards"
    for row in data_rows:
        cells = row.find_all(["td", "th"])
        card = soup.new_tag("div")
        card["class"] = "row-card"
        for i, cell in enumerate(cells):
            label = headers[i] if i < len(headers) else ""
            field = soup.new_tag("p")
            field["class"] = "field"
            if label:
                lbl = soup.new_tag("span")
                lbl["class"] = "field-label"
                lbl.string = label
                field.append(lbl)
            for child in list(cell.children):
                field.append(child.extract())
            card.append(field)
        wrapper.append(card)
    table.replace_with(wrapper)
    return True


def process_file(fp):
    with open(fp, "r", encoding="utf-8") as f:
        content = f.read()
    soup = BeautifulSoup(content, "xml")
    changed = False
    for table in soup.find_all("table"):
        if is_single_column_box(table):
            convert_to_aside(soup, table)
            changed = True
            continue
        normalize_thead_tbody(soup, table)  # fix structure first
        if convert_to_row_cards(soup, table):
            changed = True
    if changed:
        with open(fp, "w", encoding="utf-8") as f:
            f.write(str(soup))
    return changed


def main():
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} /path/to/unzipped/epub/dir", file=sys.stderr)
        sys.exit(1)
    root = Path(sys.argv[1])
    files = glob.glob(str(root / "EPUB" / "text" / "*.xhtml"))
    if not files:
        print("no EPUB/text/*.xhtml files found under", root, file=sys.stderr)
        sys.exit(1)
    total = 0
    for fp in files:
        if process_file(fp):
            total += 1
    print(f"tables converted in {total}/{len(files)} files")


if __name__ == "__main__":
    main()
