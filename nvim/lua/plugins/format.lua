-- Formateo al guardar. Los formateadores los instala install.sh (stylua, shfmt,
-- prettier, ruff). Para los lenguajes sin formateador propio (Go, Rust, Ruby,
-- Java…) se usa el formateo del servidor LSP.
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Formatear",
    },
    {
      "<leader>cF",
      function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Formatear al guardar: " .. (vim.g.disable_autoformat and "desactivado" or "activado"))
      end,
      desc = "Alternar formateo al guardar",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      python = { "ruff_format" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      markdown = { "prettier" },
    },
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end
      return { timeout_ms = 1000, lsp_format = "fallback" }
    end,
  },
}
