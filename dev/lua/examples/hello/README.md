# hello (Lua)

The smallest Lua program. There is nothing to build: `make` only checks
the syntax.

    make run        # or: lua5.4 hello.lua

Try: `lua5.4` for a prompt: `for i = 1, 3 do print(i) end`,
`t = {1, 2, 3}; print(#t)`; `luajit hello.lua` runs it with LuaJIT, a very fast Lua.
Docs: the manual, `~/dev/lua/docs/manual.html`.
