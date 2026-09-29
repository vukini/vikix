-- vikix — Vikix's Neovim: AstroNvim, and the few choices Vikix makes on top.
--
-- This folder is Vikix's: ~/.local/share/vikix/nvim is a link to it in the
-- checkout, so `vikix update` keeps it current. ~/.config/nvim is yours: its
-- init.lua calls setup() here, and the plugin specs in your lua/plugins/
-- load after Vikix's, so yours win.

local M = {}

-- The layer's root (this file is lua/vikix/init.lua in it), so lazy.nvim can
-- load it as a local plugin and find vikix.plugins there.
M.dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

-- setup { spec = { ... } } — lazy.nvim with AstroNvim, Vikix's plugins,
-- then the given specs (yours).
function M.setup(opts)
  opts = opts or {}
  local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
  if not (vim.env.LAZY or vim.uv.fs_stat(lazypath)) then
    local out = vim.fn.system {
      "git", "clone", "--filter=blob:none", "--branch=stable",
      "https://github.com/folke/lazy.nvim.git", lazypath,
    }
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({ { "Could not install lazy.nvim:\n" .. out, "ErrorMsg" } }, true, {})
      return
    end
  end
  vim.opt.rtp:prepend(lazypath)

  local spec = {
    {
      "AstroNvim/AstroNvim",
      -- A new major version can need changes here: Vikix moves it, after testing.
      version = "^6",
      import = "astronvim.plugins",
      opts = { -- AstroNvim's own options go here, next to its import
        mapleader = " ",
        maplocalleader = ",",
        icons_enabled = true, -- the glyphs come from nerd-fonts-symbols-ttf (desktop.list)
        update_notifications = true,
      },
    },
    { dir = M.dir, name = "vikix", import = "vikix.plugins" },
  }
  vim.list_extend(spec, opts.spec or {})

  require("lazy").setup(spec, {
    install = { colorscheme = { "astrotheme", "habamax" } },
    ui = { backdrop = 100 },
    performance = {
      rtp = {
        disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "zipPlugin" },
      },
    },
  })
end

return M
