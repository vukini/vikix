# make        check the syntax (luac5.4 -p); Lua has nothing to build
# make run    run hello.lua with Lua 5.4
# make clean  nothing to remove

build:
	luac5.4 -p hello.lua && echo "hello.lua: syntax is fine"

run:
	lua5.4 hello.lua


clean:

.PHONY: build run clean
