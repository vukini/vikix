-- Your Neovim. Vikix copied this folder here once and never changes it.
--
-- Vikix's part, AstroNvim and a few plugins of Vikix's, is in
-- ~/.local/share/vikix/nvim, and `vikix update` keeps it current. Yours goes
-- in lua/plugins/: each file there returns plugin specs, loaded after
-- Vikix's, so yours win (lua/plugins/example.lua shows how). The plugins'
-- versions are in lazy-lock.json; :Lazy update moves them on.

local vikix = (vim.env.XDG_DATA_HOME or vim.env.HOME .. "/.local/share") .. "/vikix/nvim"
vim.opt.rtp:prepend(vikix)
local ok, layer = pcall(require, "vikix")
if not ok then
  vim.api.nvim_echo({
    { "Vikix's part of Neovim isn't in " .. vikix .. " (vikix update puts it back):\n" .. layer, "WarningMsg" },
  }, true, {})
  return
end
layer.setup { spec = { { import = "plugins" } } }
