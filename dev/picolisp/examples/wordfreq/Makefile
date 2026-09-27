# make        check that wordfreq.l reads (PicoLisp has nothing to compile: it runs as it reads)
# make run    run it on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove: PicoLisp keeps no files here

build:
	pil -'in "wordfreq.l" (while (read))' -'prinl "wordfreq.l reads"' -bye

run:
	pil wordfreq.l text.txt

check:
	pil wordfreq.l text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
