# make        build ./wordfreq
# make run    count the words in text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what make built

wordfreq: main.go go.mod
	go build -o wordfreq .

run: wordfreq
	./wordfreq text.txt

check: wordfreq
	./wordfreq text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -f wordfreq

.PHONY: run check clean
