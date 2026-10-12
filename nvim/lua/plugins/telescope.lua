local function builtin(name, opts)
  return function()
    require("telescope.builtin")[name](opts)
  end
end

return {
  "nvim-telescope/telescope.nvim",
  branch = "master",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
    "nvim-telescope/telescope-ui-select.nvim",
  },
  keys = {
    { "<leader>ff", builtin("find_files"), desc = "Archivos" },
    { "<leader><leader>", builtin("find_files"), desc = "Archivos" },
    { "<leader>fg", builtin("live_grep"), desc = "Buscar texto (grep)" },
    { "<leader>fw", builtin("grep_string"), desc = "Buscar palabra bajo el cursor" },
    { "<leader>fb", builtin("buffers"), desc = "Buffers abiertos" },
    { "<leader>fr", builtin("oldfiles"), desc = "Archivos recientes" },
    { "<leader>fh", builtin("help_tags"), desc = "Ayuda" },
    { "<leader>fk", builtin("keymaps"), desc = "Atajos" },
    { "<leader>fd", builtin("diagnostics"), desc = "Diagnósticos" },
    { "<leader>/", builtin("current_buffer_fuzzy_find"), desc = "Buscar en el buffer" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        prompt_prefix = "> ",
        selection_caret = "> ",
        sorting_strategy = "ascending",
        layout_config = {
          prompt_position = "top",
          horizontal = { preview_width = 0.55 },
        },
        file_ignore_patterns = { "^%.git/", "node_modules/", "^target/" },
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<Esc>"] = actions.close,
          },
        },
      },
      pickers = {
        find_files = { hidden = true },
      },
      extensions = {
        ["ui-select"] = { require("telescope.themes").get_dropdown() },
      },
    })

    pcall(telescope.load_extension, "fzf")
    pcall(telescope.load_extension, "ui-select")
  end,
}
