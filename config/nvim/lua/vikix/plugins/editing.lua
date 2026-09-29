-- Small things for writing code, on top of AstroNvim's own.
return {
  -- A function's signature while typing its arguments.
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },
  -- jk or jj leaves insert mode.
  { "max397574/better-escape.nvim", enabled = true },
  -- JavaScript's snippets in JSX files too.
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- AstroNvim's setup first
      require("luasnip").filetype_extend("javascript", { "javascriptreact" })
    end,
  },
  -- $ pairs with $ in TeX, for inline maths.
  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- AstroNvim's setup first
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      require("nvim-autopairs").add_rules {
        Rule("$", "$", { "tex", "latex" })
          :with_pair(cond.not_after_regex "%%")
          :with_pair(cond.not_before_regex("xxx", 3))
          :with_move(cond.none())
          :with_del(cond.not_after_regex "xx")
          :with_cr(cond.none()),
      }
    end,
  },
}
