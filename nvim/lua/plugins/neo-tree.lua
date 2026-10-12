return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- necesario para que reemplace a netrw al abrir `nvim .`
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorador de archivos" },
    { "<leader>E", "<cmd>Neotree reveal<cr>", desc = "Mostrar archivo actual en el árbol" },
  },
  opts = {
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
    },
    window = {
      width = 32,
      mappings = {
        ["<space>"] = "none", -- el espacio es el leader
      },
    },
  },
}
