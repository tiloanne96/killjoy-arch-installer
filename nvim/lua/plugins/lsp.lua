local function has(bin)
  return vim.fn.executable(bin) == 1
end

-- Solo se instalan los servidores cuyo toolchain existe en el sistema, así Mason
-- no falla ni llena de errores el arranque. Si instalas Go, Rust o Ruby después,
-- el servidor correspondiente se instalará en el siguiente arranque.
local function servers()
  local list = { "lua_ls", "taplo" }
  if has("npm") then
    vim.list_extend(list, {
      "bashls",
      "jsonls",
      "yamlls",
      "html",
      "cssls",
      "ts_ls",
      "pyright",
      "tailwindcss",
      "emmet_language_server",
    })
  end
  if has("go") then
    table.insert(list, "gopls")
  end
  if has("cargo") then
    table.insert(list, "rust_analyzer")
  end
  if has("gem") then
    table.insert(list, "ruby_lsp")
  end
  return list
end

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason.nvim", opts = { ui = { border = "rounded" } } },
    "mason-org/mason-lspconfig.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    -- Capacidades de completado para todos los servidores
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
          completion = { callSnippet = "Replace" },
          telemetry = { enable = false },
        },
      },
    })

    require("mason-lspconfig").setup({
      ensure_installed = servers(),
      automatic_enable = true,
    })

    vim.diagnostic.config({
      severity_sort = true,
      underline = { severity = vim.diagnostic.severity.ERROR },
      float = { border = "rounded", source = "if_many" },
      virtual_text = { source = "if_many", spacing = 2 },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "✘",
          [vim.diagnostic.severity.WARN] = "▲",
          [vim.diagnostic.severity.INFO] = "●",
          [vim.diagnostic.severity.HINT] = "◆",
        },
      },
    })

    -- Atajos de LSP. Neovim 0.11 ya trae por defecto: K (hover), grn (renombrar),
    -- gra (code action), grr (referencias), gri (implementación), gO (símbolos).
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
      callback = function(ev)
        local function map(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
        end
        local function telescope(name)
          return function()
            require("telescope.builtin")[name]()
          end
        end

        map("gd", telescope("lsp_definitions"), "Ir a la definición")
        map("gD", vim.lsp.buf.declaration, "Ir a la declaración")
        map("gy", telescope("lsp_type_definitions"), "Ir a la definición del tipo")
        map("<leader>ca", vim.lsp.buf.code_action, "Acciones de código")
        map("<leader>cr", telescope("lsp_references"), "Referencias")
        map("<leader>cs", telescope("lsp_document_symbols"), "Símbolos del documento")
        map("<leader>cS", telescope("lsp_dynamic_workspace_symbols"), "Símbolos del proyecto")

        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client:supports_method("textDocument/inlayHint", ev.buf) then
          map("<leader>ch", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
          end, "Alternar inlay hints")
        end
      end,
    })
  end,
}
