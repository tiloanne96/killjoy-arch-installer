return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "mocha", -- latte | frappe | macchiato | mocha
    transparent_background = false,
    integrations = {
      alpha = true,
      blink_cmp = true,
      gitsigns = true,
      indent_blankline = { enabled = true },
      lsp_trouble = true,
      mason = true,
      mini = { enabled = true },
      native_lsp = { enabled = true },
      neotree = true,
      noice = true,
      notify = true,
      telescope = { enabled = true },
      treesitter = true,
      which_key = true,
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
