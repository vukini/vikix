-- metatables.lua — metatables: teaching tables new tricks.
--
-- Lua has one data structure, the table. A metatable attached to a table
-- says what it does when it meets an operator: + calls __add, tostring
-- calls __tostring, a missing field is looked up in __index. With that,
-- a table becomes a value with its own arithmetic, and objects and
-- classes are a few lines rather than part of the language.

local Vector = {}
Vector.__index = Vector          -- fields a vector lacks are found in Vector

function Vector.new(x, y)
  return setmetatable({ x = x, y = y }, Vector)
end

function Vector.__add(a, b) return Vector.new(a.x + b.x, a.y + b.y) end
function Vector.__mul(a, k) return Vector.new(a.x * k, a.y * k) end
function Vector.__eq(a, b) return a.x == b.x and a.y == b.y end
function Vector.__tostring(v) return string.format("(%g, %g)", v.x, v.y) end

-- A method: called as v:length(), which passes v as `self`.
function Vector:length() return math.sqrt(self.x ^ 2 + self.y ^ 2) end

local a, b = Vector.new(3, 4), Vector.new(1, -2)
print("a = " .. tostring(a) .. ", b = " .. tostring(b))
print("a + b = " .. tostring(a + b))
print("a * 2 = " .. tostring(a * 2))
print("length of a = " .. a:length())
print("a + b == (4, 2)? " .. tostring(a + b == Vector.new(4, 2)))
