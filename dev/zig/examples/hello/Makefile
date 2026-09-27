# make        build with zig build (zig-out/bin/hello)
# make run    build, then run it
# make clean  remove what zig built
#
# The Makefile only calls Zig's own tool: `zig build run` does the same.

build:
	zig build

run:
	zig build run

clean:
	rm -rf zig-out .zig-cache

.PHONY: build run clean
