# make        build with zig build
# make run    count the words in text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what zig built

build:
	zig build

run:
	zig build run -- text.txt

check: build
	./zig-out/bin/wordfreq text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -rf zig-out .zig-cache

.PHONY: build run check clean
