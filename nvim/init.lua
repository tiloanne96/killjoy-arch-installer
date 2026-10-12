-- Esta configuración usa vim.lsp.config / vim.lsp.enable (Neovim >= 0.11)
if vim.fn.has("nvim-0.11") == 0 then
  vim.api.nvim_echo({ { "Esta configuración requiere Neovim 0.11 o superior.\n", "ErrorMsg" } }, true, {})
  return
end

-- El leader debe definirse antes de cargar lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
