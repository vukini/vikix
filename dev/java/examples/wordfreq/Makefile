# make        build with Gradle (build/install/wordfreq/bin/wordfreq)
# make run    count the words in text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove what Gradle built
#
# The Makefile only calls Java's usual build tool: `gradle run --args=text.txt` does
# much the same. The first build starts Gradle's daemon, so it takes a while.

GRADLE ?= gradle --quiet --offline

build:
	$(GRADLE) installDist

run: build
	build/install/wordfreq/bin/wordfreq text.txt

check: build
	build/install/wordfreq/bin/wordfreq text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -rf build .gradle

.PHONY: build run check clean
