# make        check that database.l reads (PicoLisp has nothing to compile: it runs as it reads)
# make run    run it: the first run creates people.db, later runs find it
# make clean  remove people.db

build:
	pil -'in "database.l" (while (read))' -'prinl "database.l reads"' -bye

run:
	pil database.l

clean:
	rm -f people.db

.PHONY: build run clean
