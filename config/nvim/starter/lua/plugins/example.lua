-- Plugin specs of your own. Every file in this folder is read, and each
-- returns a list of specs; they load after Vikix's, so yours win. Take the
-- -- off a line, save, and start Neovim again. More: https://lazy.folke.io/spec
-- and https://docs.astronvim.com for AstroNvim's settings.
return {
  -- One more plugin:
  -- { "folke/zen-mode.nvim", cmd = "ZenMode" },

  -- One of AstroNvim's settings:
  -- { "AstroNvim/astrocore", opts = { options = { opt = { relativenumber = false } } } },

  -- A key of your own (Space W saves):
  -- { "AstroNvim/astrocore", opts = { mappings = { n = { ["<Leader>W"] = { "<cmd>w<cr>", desc = "Save" } } } } },

  -- One of Vikix's plugins off:
  -- { "max397574/better-escape.nvim", enabled = false },

  -- Another colour scheme, from AstroCommunity (one of its packs works the same):
  -- { "AstroNvim/astrocommunity", { import = "astrocommunity.colorscheme.catppuccin" } },
  -- { "AstroNvim/astroui", opts = { colorscheme = "catppuccin" } },
}
