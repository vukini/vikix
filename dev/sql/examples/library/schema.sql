-- schema.sql — a small library: authors, their books, and who borrowed what.
-- Each table has a key, and the others point at it: that is what joins use.

CREATE TABLE authors (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL,
  born  INTEGER
);

CREATE TABLE books (
  id        INTEGER PRIMARY KEY,
  title     TEXT NOT NULL,
  year      INTEGER,
  author_id INTEGER NOT NULL REFERENCES authors(id)
);

CREATE TABLE loans (
  book_id   INTEGER NOT NULL REFERENCES books(id),
  borrower  TEXT NOT NULL,
  out       DATE NOT NULL,
  back      DATE              -- NULL: not back yet
);

INSERT INTO authors (id, name, born) VALUES
  (1, 'Ursula K. Le Guin', 1929), (2, 'Terry Pratchett', 1948), (3, 'Italo Calvino', 1923);

INSERT INTO books (id, title, year, author_id) VALUES
  (1, 'A Wizard of Earthsea', 1968, 1), (2, 'The Dispossessed', 1974, 1),
  (3, 'Small Gods', 1992, 2), (4, 'Guards! Guards!', 1989, 2), (5, 'Mort', 1987, 2),
  (6, 'Invisible Cities', 1972, 3);

INSERT INTO loans (book_id, borrower, out, back) VALUES
  (1, 'Ada', '2026-08-01', '2026-08-20'), (3, 'Ada', '2026-09-02', NULL),
  (6, 'Grace', '2026-09-10', NULL), (3, 'Alan', '2026-07-01', '2026-07-15'),
  (5, 'Grace', '2026-06-01', '2026-06-30');
