# Books from Markdown

You have a text in Markdown and you want a book out of it: an EPUB that reads well on an e-ink reader, and a PDF for print or the screen. `vikix publish` makes both from one folder, checks them before it calls them done, and puts the EPUB on your reader when you plug it in. It comes with the feature `publish` (`vikix add publish`), and every book you make builds the same way, so "is this one finished?" has one answer.

## What a book is

A book is a folder. Its text is Markdown, in one of three shapes:

- `chapters/*.md`, one file a chapter, taken in name order (`01-start.md`, `02-next.md`, and so on);
- or one file, `book.md`;
- or the files you list under `chapters:` in `publish.yml`, in that order.

Beside the text sits `publish.yml`. It is pandoc's metadata file, so pandoc reads it as it is: `title`, `author`, `lang`, and anything else pandoc knows. Three keys are Vikix's own: `name` (what the built files are called; the folder's name when you leave it out), `chapters` (the order above) and `mainfont` (the PDF's face, see below). A `words.txt` beside it holds the book's own words for the spell check, one a line.

```yaml
title: "Living in Lisp"
author: "A. Writer"
lang: en-GB
name: a-small-book
```

To start one:

```sh
vikix publish new ~/src/a-small-book --title "Living in Lisp"
```

`--lang LANG` sets the language (`en-GB` if you don't). `new` writes `publish.yml`, a first chapter (`chapters/01-start.md`), an empty `words.txt`, puts `out/` in `.gitignore`, and adds the make targets line to the folder's `Makefile` (added to one that is there, see *From a Makefile*). It never writes over a book that is there: a folder with a `publish.yml` is left as it is. In a git repository it commits what it wrote, those files alone; `--no-commit` leaves git alone.

## Building a book

```sh
vikix publish a-small-book        # the EPUB and the PDF
vikix publish a-small-book epub   # the EPUB alone
vikix publish a-small-book pdf    # the PDF alone
```

The book is found three ways: by its folder's name in `~/src` (one level down too, so a book inside a collection is found), by the `name` in its `publish.yml`, or you run `vikix publish` inside the folder with no name at all. A path to the folder works as well.

The files land in the book's `out/`: `out/NAME.epub` and `out/NAME.pdf`, where `NAME` is the `name` from `publish.yml`. Each is checked on the way (the next two sections say how), and a file that fails its check is never given the book's name. A build that went well ends like this:

```
out/a-small-book.epub  (96 KB, epubcheck: no errors)
out/a-small-book.pdf  (240 KB, Typst: no warnings)
:: noted in /home/you/src/a-small-book/log.md
```

If the book is a project, the one `vikix project` knows (see [Projects](customize.md#projects)), a build into `out/` writes a dated entry, `published`, in its `log.md`, with the files and their sizes, and commits it. A book that is no project gets no entry. `--no-log` (or `VIKIX_PUBLISH_LOG=0` in the environment) leaves the log alone; `--no-commit` (or `VIKIX_PUBLISH_COMMIT=0`) leaves git alone. A file that had changes of yours waiting is never committed under you: it is left to you, and said.

## The EPUB, for e-ink readers

pandoc writes the EPUB. Then Vikix fixes it for small screens: every table becomes a stack of row cards, and every one-cell box becomes an aside. Why: the reading apps of 7-inch e-ink screens collapse tables, and a table of three columns comes out as a smear. The fix is `lib/publish/fix-tables.py`, the same file the `doc-to-epub` skill uses on claude.ai, so the laptop and the cloud make the same book.

Code is left unhighlighted and keeps its spaces. pandoc's colouring wraps each word of code in its own tag, and e-ink readers drop the spaces between the tags, so a listing loses its indentation and its columns. A build where that would happen is refused, with the pages named.

Last, W3C's epubcheck reads the file. One it rejects is kept as `out/NAME.epub.rejected`, and you see epubcheck's report; it is never kept as the book. epubcheck is a Java program, not in Void, so Vikix fetches it as a pinned release and checks it against its checksum (`vikix publish setup` does that, and `vikix add publish` runs it).

## The PDF

The PDF goes through pandoc's Typst writer. The face is IBM Plex Serif, with Arabic set in Amiri: an Arabic book (`lang: ar`) is in Amiri throughout, and Arabic inside any other book is in Amiri too. Text runs right to left where you say so, with pandoc's own marking:

```markdown
::: {dir=rtl lang=ar}
...
:::
```

`mainfont` in `publish.yml` chooses another face for the whole book. One Typst warned about (a face that isn't installed, say) is kept as `out/NAME.pdf.rejected`, with the warnings shown, never as the book.

## Checking the book: spelling, links, builds

```sh
vikix publish a-small-book check
```

`check` does the spelling, then the links, then builds both formats into a scratch folder and keeps nothing: it says whether the book would build, and nothing in `out/` changes. It is the question to ask before you call a draft done. The text is checked first on purpose: a heading that isn't there would stop Typst with a message of its own, while the link check names the chapter. When all is well, the last line is:

```
check: a-small-book builds, passes epubcheck and Typst, its spelling and its links (3 files of text)
```

**Spelling.** The book's `lang` is checked against LibreOffice's dictionary: any English as British (`en_GB`), Esperanto (`eo`) and Arabic (`ar`). A passage in another language is checked in its own when you mark it, `::: {lang=eo}` around a block or `[libro]{lang=eo}` on a word. Code, raw HTML and maths aren't prose, so they are left out. Words with a digit in them (`FTS5`, `0x1000`) and words of one letter aren't checked either. The book's own words, its names and terms, go in `words.txt`, one a line.

```sh
vikix publish a-small-book spell          # the unknown words, by chapter
vikix publish a-small-book spell --keep   # and all of them into words.txt
```

`spell` lists the unknown words by chapter, each with the first chapter it is in:

```
spelling, en_GB: 2 words not in the dictionary or words.txt
  defun                    chapters/01-start.md and 3 more
  teh                      chapters/02-next.md
```

Here `defun` is a word of the book's and `teh` a typo. `spell --keep` adds every unknown word to `words.txt` for you to read through: take out what is really a typo, and the rest stay as the book's words. In a git repository it then commits `words.txt`, that file alone; `--no-commit` leaves git alone. When nothing is unknown, it says so: `spelling: every word is known (en_GB, and words.txt)`.

**Links.** `vikix publish a-small-book links` runs this part alone. A link to `#a-heading` must find that heading in the book. A file or an image beside the text must be there. An address on the web must answer: each is asked once, and the answer is kept a week in `~/.cache/vikix/publish-links.json`, so a check a day doesn't knock on every site. A page that says 403 to a script is still there; one that says 404 or doesn't answer isn't. With no network, the web's links are left for next time, and the check says so rather than failing:

```
links: 14 in the text, all found (2 on the web, 9 to headings, 3 to files)
links: no network, so 3 on the web are left for next time
```

A link that isn't found is listed with its chapter and why, and the check fails.

## Onto the reader

```sh
vikix publish a-small-book --send
```

`--send` builds the EPUB and puts it on the reader plugged in. It knows a Kindle mounted as a drive (the file goes into `documents/`), a Kobo (at the top of the drive), any drive with a `Books` folder, an Android reader such as a BOOX in file transfer mode (over MTP, into its storage's `Books`), and one with USB debugging on (adb, into `/sdcard/Books`). It tries them in that order and says where the book went:

```
:: sent: adb:/sdcard/Books/a-small-book.epub
```

With no reader found it stops and says so: plug one in, or on an Android reader choose file transfer. `--to FOLDER` names the place yourself instead, any folder, and nothing is looked for.

## From a Makefile

A book's `Makefile` ends with one line:

```makefile
-include $(HOME)/.local/share/vikix/publish/publish.mk
```

That gives `make epub`, `make pdf` and `make check`, the same three as the command, from inside the folder. The dash in `-include` is what keeps the project's other targets working on a machine where `publish` isn't installed: make skips a file it can't find rather than stop. `vikix publish new` writes the line for you; in a Makefile you already have, put it last.

For the curious: the targets only call `lib/publish/build`, the script behind `vikix publish` too. One thing is different. `make epub` doesn't write the entry in the project's log: only `vikix publish` knows the project.

A Word document can be the book's text. Name it under `chapters:` in `publish.yml`, and pandoc reads it directly, tables and all:

```yaml
title: "Living in Lisp"
lang: en-GB
chapters: [../a-small-book.docx]
```

## The doc-to-epub skill

The `doc-to-epub` skill on claude.ai is made from the same files as the laptop's build: `lib/publish/skill/SKILL.md`, `fix-tables.py` and `epub.css`. `vikix publish skill` zips them as `~/Downloads/doc-to-epub.zip` (`vikix publish skill ZIP` names another path), ready to upload in claude.ai under Settings, Capabilities, Skills, in place of the one there. So a fix to the e-ink pipeline here reaches the cloud at the next upload, and nothing is kept twice.

## When a book doesn't build

Start with what is here:

```sh
vikix publish status
```

It lists the tools (pandoc, typst, java), epubcheck, the three dictionaries, the Python libraries, the two fonts (IBM Plex Serif, Amiri) and the shared make targets, and says `missing` by each that isn't, with the command that brings it. `vikix publish setup` fetches epubcheck and the dictionaries and puts the shared make targets in place; it is what `vikix add publish` runs for you, and it is safe to run again.

- **No java** means epubcheck can't run, so no EPUB passes. The feature `publish` needs the feature `java`, so `vikix add publish` brings it; if it is gone, `vikix add java`.
- **A dictionary missing** doesn't stop the build: the spelling in that language is said to be not checked, and `vikix publish setup` fetches the dictionaries.
- **A face that isn't there** is a Typst warning, so the PDF comes out as `NAME.pdf.rejected`. `status` says which of the two fonts is missing; a `mainfont` of your own must be installed on the machine.
- **An EPUB rejected** comes with epubcheck's report in the terminal, and the file as `NAME.epub.rejected` to open and look at.

`vikix add publish` installs the feature. `vikix remove publish` removes epubcheck, the dictionaries and the shared make targets; your books and their `out/` folders stay where they are.
