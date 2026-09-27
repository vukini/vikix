# dispatch (Julia)

What Julia is known for: multiple dispatch, and generic code that is still
fast. `meet` has a method per pair of shapes, and Julia picks by both
arguments; `double` is one line that works for integers, floats,
fractions (`2//3`) and big numbers.

    make run

Try: add `struct Triangle <: Shape` with its own `area`, and a
`meet(a::Circle, b::Square)` method; `methods(meet)` lists them all;
`@code_native double(3)` shows the machine code for one type.
Docs: https://docs.julialang.org, "Methods".
