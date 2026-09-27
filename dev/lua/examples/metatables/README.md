# metatables (Lua)

What Lua is known for: a tiny language that bends to fit. A Vector made
from a plain table and a metatable, with its own `+`, `*`, `==` and
printing, and a method called with `:`. Lua is small enough to live
inside other programs; Neovim's config is written in it.

    make run

Try: add `__sub` and `__unm` (minus); give Vector a `__call` so
`Vector(1, 2)` works; look at `~/.config/nvim` for Lua in real use.
Docs: the manual, "Metatables and Metamethods" (2.4).
