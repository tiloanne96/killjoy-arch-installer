return {
  "saghen/blink.cmp",
  version = "1.*", -- descarga el binario precompilado del fuzzy matcher
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    -- Tab acepta la sugerencia; <C-space> abre el menú; <C-e> lo cierra
    keymap = { preset = "super-tab" },
    appearance = { nerd_font_variant = "mono" },
    completion = {
      menu = { border = "rounded" },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded" },
      },
    },
    signature = { enabled = true, window = { border = "rounded" } },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    fuzzy = { implementation = "prefer_rust" },
  },
  opts_extend = { "sources.default" },
}
