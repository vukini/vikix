# make        check the syntax (luac5.4 -p); Lua has nothing to build
# make run    run metatables.lua with Lua 5.4
# make clean  nothing to remove

build:
	luac5.4 -p metatables.lua && echo "metatables.lua: syntax is fine"

run:
	lua5.4 metatables.lua


clean:

.PHONY: build run clean
