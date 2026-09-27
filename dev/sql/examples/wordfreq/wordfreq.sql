-- wordfreq.sql — the ten most common words in a text file, in SQL alone.
--
-- A word is a run of letters, compared in lower case. SQL has no loops,
-- so a recursive query walks the text one character at a time; a running
-- count of the non-letters gives every word its own number; grouping by
-- that number joins each word's letters back together; then it's an
-- ordinary GROUP BY and ORDER BY.
--
--   sqlite3 < wordfreq.sql       (readfile is part of the sqlite3 program)

WITH RECURSIVE
  text(t) AS (SELECT lower(CAST(readfile('text.txt') AS TEXT))),
  -- every character, with its position
  chars(i, c) AS (
    SELECT 1, substr(t, 1, 1) FROM text
    UNION ALL
    SELECT i + 1, substr(t, i + 1, 1) FROM chars, text WHERE i < length(t)
  ),
  -- letters, numbered by how many non-letters came before them
  letters(i, c, word_no) AS (
    SELECT i, c, sum(c NOT BETWEEN 'a' AND 'z') OVER (ORDER BY i)
    FROM chars
  ),
  words(word) AS (
    SELECT group_concat(c, '' ORDER BY i)
    FROM letters WHERE c BETWEEN 'a' AND 'z'
    GROUP BY word_no
  )
SELECT printf('%4d %s', count(*), word)
FROM words
GROUP BY word
ORDER BY count(*) DESC, word      -- the higher count first, then alphabetical
LIMIT 10;
