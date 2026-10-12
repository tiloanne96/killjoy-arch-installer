-- Usa la rama `main` de nvim-treesitter (requiere Neovim 0.11+, un compilador C
-- y el paquete `tree-sitter-cli`; install.sh los instala).
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local parsers = {
      "bash", "c", "css", "diff", "dockerfile", "embedded_template", "gitcommit",
      "go", "gomod", "html", "java", "javascript", "json", "lua", "luadoc",
      "markdown", "markdown_inline", "python", "query", "regex", "ruby", "rust",
      "sql", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
    }

    if vim.fn.executable("tree-sitter") == 1 then
      require("nvim-treesitter").install(parsers)
    else
      vim.notify("nvim-treesitter: falta `tree-sitter-cli`, no se instalarán parsers", vim.log.levels.WARN)
    end

    -- Activar el resaltado de treesitter cuando exista parser para el filetype
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user_treesitter_start", { clear = true }),
      callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
      end,
    })
  end,
}
