# make        check the syntax (ruby -c); Ruby has nothing to build
# make run    run wordfreq.rb on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove

build:
	ruby -c wordfreq.rb

run:
	ruby wordfreq.rb text.txt

check:
	ruby wordfreq.rb text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
