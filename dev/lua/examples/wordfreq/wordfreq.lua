-- wordfreq.lua — the ten most common words in a text file.
--
-- A word is a run of letters, compared in lower case. gmatch walks over
-- them; a table (Lua's only data structure) counts them, and another,
-- sorted with a two-part test, puts the most common first.
--
--   lua5.4 wordfreq.lua text.txt

local path = arg[1]
if not path then
  io.stderr:write("usage: lua5.4 wordfreq.lua FILE\n")
  os.exit(2)
end

local file = assert(io.open(path))
local text = file:read("a"):lower()
file:close()

local counts = {}
for word in text:gmatch("%a+") do
  counts[word] = (counts[word] or 0) + 1
end

local entries = {}
for word, count in pairs(counts) do
  entries[#entries + 1] = { word = word, count = count }
end
-- The higher count first; the same count in alphabetical order.
table.sort(entries, function(a, b)
  if a.count ~= b.count then return a.count > b.count end
  return a.word < b.word
end)

for i = 1, math.min(10, #entries) do
  print(string.format("%4d %s", entries[i].count, entries[i].word))
end
