# make        build library.db from schema.sql (the tables and their rows)
# make run    ask it the questions in queries.sql
# make clean  remove library.db

library.db: schema.sql
	rm -f library.db
	sqlite3 library.db < schema.sql

run: library.db
	sqlite3 library.db < queries.sql

clean:
	rm -f library.db

.PHONY: run clean
