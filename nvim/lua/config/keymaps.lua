local map = vim.keymap.set

-- Limpiar el resaltado de búsqueda
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Limpiar búsqueda" })

-- Guardar / salir
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Guardar" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Cerrar ventana" })
map("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Salir de todo" })

-- Moverse entre ventanas
map("n", "<C-h>", "<C-w>h", { desc = "Ventana a la izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Ventana de abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Ventana de arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Ventana a la derecha" })

-- Redimensionar ventanas
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Más alto" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Menos alto" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Menos ancho" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Más ancho" })

-- Dividir ventanas
map("n", "<leader>-", "<cmd>split<cr>", { desc = "División horizontal" })
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "División vertical" })

-- Buffers (<leader>bd, para cerrar sin romper la disposición, está en plugins/editor.lua)
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Buffer anterior" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Buffer siguiente" })

-- Mover líneas con Alt+j / Alt+k
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Mover línea abajo" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Mover línea arriba" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Mover línea abajo" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Mover línea arriba" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Mover selección abajo", silent = true })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Mover selección arriba", silent = true })
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Mover selección abajo", silent = true })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Mover selección arriba", silent = true })

-- Mantener la selección al indentar
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Mantener el cursor centrado al desplazarse o buscar
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Pegar sin sobrescribir el registro
map("x", "<leader>p", [["_dP]], { desc = "Pegar sin perder el registro" })

-- Diagnósticos (]d y [d ya vienen por defecto en Neovim 0.11)
map("n", "gl", vim.diagnostic.open_float, { desc = "Diagnóstico de la línea" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnóstico de la línea" })

-- Alternar opciones de interfaz
map("n", "<leader>un", "<cmd>set number!<cr>", { desc = "Números de línea" })
map("n", "<leader>ur", "<cmd>set relativenumber!<cr>", { desc = "Números relativos" })
map("n", "<leader>us", "<cmd>set spell!<cr>", { desc = "Corrector ortográfico" })
map("n", "<leader>uw", "<cmd>set wrap!<cr>", { desc = "Ajuste de línea" })
map("n", "<leader>ud", function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Diagnósticos" })

-- Terminal integrada
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Salir del modo terminal" })
