-- The colour scheme "vikix": the current Vikix theme's own colours, as
-- base16 (mini.base16). Used for the themes Neovim has no scheme of its own
-- for: contrast, and the ones you make or import (lua/vikix/theme.lua).
local p = require("vikix.theme").palette()
if not (p.bg and p.fg) then
  error "no Vikix palette yet: vikix theme NAME writes it"
end
local function pick(...)
  for _, v in ipairs { ... } do
    if v then return v end
  end
end
-- base16's slots: 00-07 from the background to the text, 08-0F the accents.
require("mini.base16").setup {
  palette = {
    base00 = p.bg,
    base01 = pick(p.color0, p.sel), -- status line, line numbers' background
    base02 = pick(p.sel, p.color0), -- selection
    base03 = pick(p.color8, p.subtle), -- comments
    base04 = pick(p.subtle, p.fg), -- quieter text
    base05 = p.fg,
    base06 = pick(p.color7, p.fg),
    base07 = pick(p.color15, p.fg),
    base08 = pick(p.color1, p.alert), -- red: variables, errors
    base09 = pick(p.color9, p.color1), -- numbers, constants
    base0A = pick(p.color3, p.accent), -- yellow: types, search
    base0B = pick(p.color2, p.fg), -- green: strings
    base0C = pick(p.color6, p.accent), -- cyan: escapes, regexps
    base0D = pick(p.color4, p.accent), -- blue: functions
    base0E = pick(p.color5, p.accent), -- magenta: keywords
    base0F = pick(p.alert, p.color1), -- deprecated, embedded
  },
}
vim.g.colors_name = "vikix"
