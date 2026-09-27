# make        check the syntax (luac5.4 -p); Lua has nothing to build
# make run    run wordfreq.lua with Lua 5.4 on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove

build:
	luac5.4 -p wordfreq.lua && echo "wordfreq.lua: syntax is fine"

run:
	lua5.4 wordfreq.lua text.txt

check:
	lua5.4 wordfreq.lua text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
