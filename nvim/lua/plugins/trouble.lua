return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {},
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnósticos del proyecto" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnósticos del buffer" },
    { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Símbolos" },
    {
      "<leader>xl",
      "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
      desc = "LSP: definiciones y referencias",
    },
    { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Lista de ubicaciones" },
    { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Lista quickfix" },
  },
}
