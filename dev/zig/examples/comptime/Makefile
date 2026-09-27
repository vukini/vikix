# make        build with zig build
# make run    run it
# make check  run the tests beside the code (zig build test)
# make clean  remove what zig built

build:
	zig build

run:
	zig build run

check:
	zig build test --summary all

clean:
	rm -rf zig-out .zig-cache

.PHONY: build run check clean
