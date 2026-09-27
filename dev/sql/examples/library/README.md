# library (SQL)

What SQL is known for: asking questions of data that lives in tables. A
small library database (authors, books, loans), built by `make` from
`schema.sql`, and four questions, each a join, in `queries.sql`.

    make run

Try: `sqlitebrowser library.db` to see the tables in a window; add a
book and borrow it; ask "who has borrowed a Pratchett?"; `EXPLAIN QUERY
PLAN` in front of a SELECT shows how SQLite will answer it.
Docs: the SQLite docs, "SELECT" (offline, ~/dev/sql/docs); SQLBolt (see ~/dev/sql/README.md).
