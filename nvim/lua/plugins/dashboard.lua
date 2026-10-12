return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "",
      "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
      "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
      "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
      "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
      "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
      "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
      "",
    }
    dashboard.section.header.opts.hl = "AlphaHeader"

    dashboard.section.buttons.val = {
      dashboard.button("f", "Buscar archivo", ":Telescope find_files <CR>"),
      dashboard.button("n", "Archivo nuevo", ":ene <BAR> startinsert <CR>"),
      dashboard.button("r", "Archivos recientes", ":Telescope oldfiles <CR>"),
      dashboard.button("g", "Buscar texto", ":Telescope live_grep <CR>"),
      dashboard.button("c", "Configuración", ":e $MYVIMRC <CR>"),
      dashboard.button("l", "Lazy", ":Lazy<CR>"),
      dashboard.button("q", "Salir", ":qa<CR>"),
    }

    alpha.setup(dashboard.config)
  end,
}
