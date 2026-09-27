# make        check the syntax (node --check); JavaScript has nothing to build
# make run    run wordfreq.js with Node on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove

build:
	node --check wordfreq.js && echo "wordfreq.js: syntax is fine"

run:
	node wordfreq.js text.txt

check:
	node wordfreq.js text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
