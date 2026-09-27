# words (Forth)

What Forth is known for: a language you extend until it speaks your
problem. `square` and `cube` are made from other words; `unit` is a
defining word that makes more words (`mm`, `cm`, `m`, `km`), so
`2 km 350 m +` is a Forth program that reads like the sentence.

    make run

Try: add `25400 unit inch` and `12 inch show-mm`; make a `mile`; type
`see unit` at the gforth prompt to see what create and does> built.
Docs: Starting Forth, chapter 11, "Extending the Compiler" (see ~/dev/forth/README.md).
