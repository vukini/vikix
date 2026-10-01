-- vikix.theme — Neovim follows `vikix theme`.
--
-- The built-in themes have a colour scheme made for them (void and paper
-- are Catppuccin's Mocha and Latte, ...); any other theme, contrast and
-- yours included, becomes the colour scheme "vikix": base16, built by
-- mini.base16 from the theme's own colours, which `vikix theme` writes to
-- ~/.config/vikix/theme/palette. `vikix theme NAME` calls apply() in every
-- running Neovim, so they change at once.

local M = {}

local dir = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/vikix/theme"

-- Vikix's theme → Neovim's colour scheme (the plugins are in plugins/theme.lua).
M.schemes = {
  void = "catppuccin-mocha",
  paper = "catppuccin-latte",
  gruvbox = "gruvbox",
  nord = "nord",
  ["tokyo-night"] = "tokyonight-night",
}

local function read(file)
  local f = io.open(file, "r")
  if not f then return nil end
  local text = f:read "*a"
  f:close()
  return text
end

-- The current theme's name, as `vikix theme` saved it; void when there's none.
function M.current()
  local name = vim.trim(read(dir .. "/current") or "")
  return name:match "^[%w_-]+$" and name or "void"
end

-- The current theme's colours: { bg = "#1e1e2e", fg = ..., color0 = ... }.
function M.palette()
  local p = {}
  for k, v in (read(dir .. "/palette") or ""):gmatch "([%w_]+)=(#%x%x%x%x%x%x)" do
    p[k] = v
  end
  return p
end

-- The colour scheme for the current theme: its own, or "vikix" from the
-- palette (also when the palette is all there is to go on).
function M.colorscheme()
  return M.schemes[M.current()] or "vikix"
end

-- Switch to the current theme's colour scheme; "vikix" if that one fails
-- (its plugin not installed yet, say), and habamax, which comes with
-- Neovim, if even that fails.
function M.apply()
  for _, name in ipairs { M.colorscheme(), "vikix", "habamax" } do
    if pcall(vim.cmd.colorscheme, name) then return name end
  end
end

return M
