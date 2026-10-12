return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = true,
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end

        map("]h", function()
          gs.nav_hunk("next")
        end, "Siguiente cambio")
        map("[h", function()
          gs.nav_hunk("prev")
        end, "Cambio anterior")
        map("<leader>gs", gs.stage_hunk, "Stage del cambio")
        map("<leader>gr", gs.reset_hunk, "Descartar cambio")
        map("<leader>gp", gs.preview_hunk, "Previsualizar cambio")
        map("<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame de la línea")
      end,
    },
  },

  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = { { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" } },
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  -- Cerrar y renombrar etiquetas HTML/JSX/ERB automáticamente
  {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    opts = {
      opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false },
    },
  },

  -- ys{motion}{char} añade, ds{char} borra y cs{old}{new} cambia delimitadores
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Siguiente TODO",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "TODO anterior",
      },
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Buscar TODOs" },
    },
  },

  -- Cierra el buffer sin romper la disposición de las ventanas
  {
    "famiu/bufdelete.nvim",
    keys = { { "<leader>bd", "<cmd>Bdelete<cr>", desc = "Cerrar buffer" } },
  },
}
