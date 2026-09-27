-- queries.sql — questions for library.db, each one a join.

.mode column
.headers on

.print '-- every book, with its author (a JOIN matches books.author_id to authors.id)'
SELECT b.title, b.year, a.name AS author
FROM books b JOIN authors a ON a.id = b.author_id
ORDER BY b.year;

.print ''
.print '-- how many books each author has, and their first'
SELECT a.name, count(*) AS books, min(b.year) AS first
FROM authors a JOIN books b ON b.author_id = a.id
GROUP BY a.id ORDER BY books DESC;

.print ''
.print '-- out right now: loans not back yet (back IS NULL)'
SELECT l.borrower, b.title, l.out
FROM loans l JOIN books b ON b.id = l.book_id
WHERE l.back IS NULL;

.print ''
.print '-- books never borrowed (a LEFT JOIN keeps books with no loan at all)'
SELECT b.title
FROM books b LEFT JOIN loans l ON l.book_id = b.id
WHERE l.book_id IS NULL;
