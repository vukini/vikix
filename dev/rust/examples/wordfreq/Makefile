# make        build with cargo
# make run    count the words in text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what cargo built

build:
	cargo build --quiet

run:
	cargo run --quiet -- text.txt

check: build
	cargo run --quiet -- text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	cargo clean --quiet

.PHONY: build run check clean
