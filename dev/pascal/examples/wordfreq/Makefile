# make        build ./wordfreq with fpc
# make run    count the words in text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what make built

wordfreq: wordfreq.pas
	fpc -v0 -l- wordfreq.pas

run: wordfreq
	./wordfreq text.txt

check: wordfreq
	./wordfreq text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -f wordfreq wordfreq.o

.PHONY: run check clean
