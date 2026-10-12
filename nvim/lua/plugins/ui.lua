-- Extremos redondeados de la barra de estado (glifos de la Nerd Font)
local pill_left = vim.fn.nr2char(0xe0b6)
local pill_right = vim.fn.nr2char(0xe0b4)

return {
  { "nvim-tree/nvim-web-devicons", lazy = true },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        component_separators = "",
        section_separators = { left = pill_right, right = pill_left },
        disabled_filetypes = { statusline = { "alpha" } },
      },
      sections = {
        lualine_a = { { "mode", separator = { left = pill_left, right = pill_right } } },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "filetype" },
        lualine_z = { { "location", separator = { left = pill_left, right = pill_right } } },
      },
      extensions = { "neo-tree", "lazy", "trouble" },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>b", group = "buffers" },
        { "<leader>c", group = "código" },
        { "<leader>f", group = "buscar" },
        { "<leader>g", group = "git" },
        { "<leader>u", group = "interfaz" },
        { "<leader>x", group = "diagnósticos" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Atajos del buffer",
      },
    },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = false },
    },
  },

  -- Resalta el bloque de indentación donde está el cursor
  {
    "echasnovski/mini.indentscope",
    version = false,
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      symbol = "│",
      options = { try_as_border = true },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "alpha", "neo-tree", "Trouble", "trouble", "lazy", "mason", "notify" },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  -- Muestra los colores (#hex, rgb, nombres de Tailwind) junto al código
  {
    "brenoprata10/nvim-highlight-colors",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      render = "virtual",
      virtual_symbol = "■",
      virtual_symbol_position = "inline",
      enable_named_colors = true,
      enable_tailwind = true,
    },
  },

  -- Línea de comandos y mensajes flotantes. Si no te gusta, borra este bloque.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      {
        "rcarriga/nvim-notify",
        opts = { background_colour = "Normal", timeout = 3000 },
      },
    },
    opts = {
      cmdline = { view = "cmdline_popup" },
      messages = { view = "notify" },
      -- El completado del cmdline lo hace blink.cmp, no noice
      popupmenu = { enabled = false },
      lsp = {
        progress = { enabled = true },
        -- hover y signature ya los resuelven Neovim 0.11 y blink.cmp
        hover = { enabled = false },
        signature = { enabled = false },
      },
      presets = { command_palette = true, lsp_doc_border = true },
    },
  },
}
