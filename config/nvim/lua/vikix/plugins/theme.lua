-- Neovim follows `vikix theme` (lua/vikix/theme.lua): the colour schemes of
-- the built-in themes, mini.base16 for the rest, and AstroNvim told which
-- one to use. All load only when their scheme is asked for.
return {
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "ellisonleao/gruvbox.nvim", lazy = true },
  { "gbprod/nord.nvim", lazy = true },
  { "folke/tokyonight.nvim", lazy = true },
  { "nvim-mini/mini.base16", lazy = true },
  {
    "AstroNvim/astroui",
    opts = function(_, opts) opts.colorscheme = require("vikix.theme").colorscheme() end,
  },
}
