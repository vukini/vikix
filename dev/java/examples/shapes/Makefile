# make        build with Gradle (build/install/shapes/bin/shapes)
# make run    build, then run it
# make clean  remove what Gradle built
#
# The Makefile only calls Java's usual build tool: `gradle run` does
# much the same. The first build starts Gradle's daemon, so it takes a while.

GRADLE ?= gradle --quiet --offline

build:
	$(GRADLE) installDist

run: build
	build/install/shapes/bin/shapes

clean:
	rm -rf build .gradle

.PHONY: build run clean
