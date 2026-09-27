# make        nothing to build: sqlite3 runs the SQL as it reads it
# make run    count the words in text.txt, in SQL
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove

build:
	@echo "nothing to build: sqlite3 runs wordfreq.sql as it reads it (make run)"

run:
	sqlite3 < wordfreq.sql

check:
	sqlite3 < wordfreq.sql | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
