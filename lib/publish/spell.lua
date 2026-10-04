-- spell.lua — a book's prose in one language, for hunspell (vikix publish
-- spell). pandoc runs it with the metadata spell_lang (the language to
-- keep, as hunspell names it: en_GB, eo, ar) and the book's lang:
--
--   pandoc chapter.md --lua-filter spell.lua -M spell_lang=eo -t plain
--
-- Code, raw HTML and maths are never prose. A passage marked with a
-- language of its own (::: {lang=eo} or [vorto]{lang=eo}) belongs to that
-- language; the rest is the book's. So an English book's Esperanto
-- paragraph is checked against Esperanto, not counted as English typos.

local function dict(lang)
  lang = (lang or ""):lower():gsub("_", "-")
  if lang:match("^en") then return "en_GB" end
  if lang:match("^eo") then return "eo" end
  if lang:match("^ar") then return "ar" end
  return lang
end

local target, book

local function strip_code()
  return {
    CodeBlock = function() return {} end,
    Code = function() return {} end,
    RawBlock = function() return {} end,
    RawInline = function() return {} end,
    Math = function() return {} end,
  }
end

-- In the book's own language: everything except passages in another.
local function own()
  return {
    Div = function(el)
      local l = el.attributes.lang
      if l and dict(l) ~= target then return {} end
    end,
    Span = function(el)
      local l = el.attributes.lang
      if l and dict(l) ~= target then return {} end
    end,
  }
end

-- In another language: only the passages marked as it.
local function only_marked(blocks)
  local kept = {}
  local function visit(el)
    local l = el.attributes and el.attributes.lang
    if l and dict(l) == target then
      if el.t == "Div" then
        for _, b in ipairs(el.content) do kept[#kept + 1] = b end
      else
        kept[#kept + 1] = pandoc.Plain(el.content)
      end
      return el, false   -- its insides are kept already
    end
  end
  pandoc.Blocks(blocks):walk({ Div = visit, Span = visit, traverse = "topdown" })
  return kept
end

function Pandoc(doc)
  target = dict(pandoc.utils.stringify(doc.meta.spell_lang or ""))
  book = dict(pandoc.utils.stringify(doc.meta.lang or "en"))
  local blocks = doc.blocks:walk(strip_code())
  if target == book then
    blocks = blocks:walk(own())
  else
    blocks = pandoc.Blocks(only_marked(blocks))
  end
  return pandoc.Pandoc(blocks, doc.meta)
end
