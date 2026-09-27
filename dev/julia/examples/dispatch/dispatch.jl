# dispatch.jl — multiple dispatch: Julia picks the method by every argument's type.
#
# A function in Julia is a name with many methods. Calling it runs the
# method whose argument types fit best, looking at all the arguments, not
# only the first as in most languages. So behaviour for a new pair of
# types is just one more method, added from outside.

abstract type Shape end
struct Circle <: Shape; r::Float64; end
struct Square <: Shape; side::Float64; end

area(c::Circle) = π * c.r^2
area(s::Square) = s.side^2

# What happens when two shapes meet depends on both.
meet(a::Circle, b::Circle) = "two circles roll past each other"
meet(a::Square, b::Square) = "two squares stack neatly"
meet(a::Shape, b::Shape)   = "a $(nameof(typeof(a))) and a $(nameof(typeof(b))) don't fit together"

shapes = [Circle(1), Square(2), Circle(0.5)]
for s in shapes
    println(rpad(string(s), 20), " area ", round(area(s), digits = 2))
end
for (a, b) in [(shapes[1], shapes[3]), (shapes[2], shapes[2]), (shapes[1], shapes[2])]
    println(meet(a, b))
end

# The same generic code runs on any number type; Julia compiles a fast
# version for each one it meets.
double(x) = 2x
println(double(21), "  ", double(1.5), "  ", double(2//3), "  ", double(big(2)^100))
