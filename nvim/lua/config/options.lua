local opt = vim.opt

-- Interfaz
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.showmode = false -- lualine ya muestra el modo
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.splitright = true
opt.splitbelow = true
opt.inccommand = "split"
opt.winborder = "rounded"
opt.pumheight = 12
opt.confirm = true
opt.fillchars = { eob = " " } -- ocultar los "~" al final del buffer

-- Ortografía en inglés y español. Solo se activa en texto (ver autocmds.lua);
-- las palabras añadidas con `zg` se guardan en nvim/spell/ y se versionan.
opt.spelllang = { "en", "es" }
opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- Edición
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.breakindent = true
opt.ignorecase = true
opt.smartcase = true

-- Comportamiento
opt.mouse = "a"
opt.undofile = true
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 300
opt.completeopt = { "menu", "menuone", "noselect" }

-- Portapapeles del sistema (diferido para no retrasar el arranque).
-- Requiere wl-clipboard (Wayland) o xclip (X11).
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)
