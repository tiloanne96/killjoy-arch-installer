local autocmd = vim.api.nvim_create_autocmd

local function augroup(name)
  return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

-- Resaltar brevemente el texto copiado
autocmd("TextYankPost", {
  group = augroup("yank"),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Volver a la última posición al reabrir un archivo
autocmd("BufReadPost", {
  group = augroup("last_position"),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lines = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lines then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Igualar el tamaño de las divisiones al redimensionar la terminal
autocmd("VimResized", {
  group = augroup("resize_splits"),
  command = "tabdo wincmd =",
})

-- Recargar archivos modificados fuera de Neovim
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  command = "checktime",
})

-- Cerrar con "q" ventanas de ayuda y similares
autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify", "startuptime" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Corrector ortográfico solo en texto, no en código
autocmd("FileType", {
  group = augroup("spell"),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Borrar los buffers vacíos "[No Name]" cuando se ocultan
autocmd("BufHidden", {
  group = augroup("wipe_empty_buffers"),
  callback = function(ev)
    local buf = ev.buf
    if
      vim.api.nvim_buf_get_name(buf) == ""
      and vim.bo[buf].buftype == ""
      and not vim.bo[buf].modified
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) and vim.fn.bufwinid(buf) == -1 then
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end)
    end
  end,
})

-- Indentación según el lenguaje
autocmd("FileType", {
  group = augroup("indent_go"),
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

autocmd("FileType", {
  group = augroup("indent_4"),
  pattern = { "python", "rust", "java" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})
