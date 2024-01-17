local lspconfig = require("lspconfig")

local on_attach = function()
    local opts = {buffer = 0}
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<Leader>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set("n", "<Leader>v", vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<Leader>f',
                   function() vim.lsp.buf.format {async = true} end, opts)
    vim.keymap.set("n", "<Leader>O", vim.diagnostic.open_float, opts)

    require("vim.lsp.protocol").CompletionItemKind = {
        "", -- Text
        "", -- Method
        "", -- Function
        "", -- Constructor
        "", -- Field
        "", -- Variable
        "", -- Class
        "ﰮ", -- Interface
        "", -- Module
        "", -- Property
        "", -- Unit
        "", -- Value
        "", -- Enum
        "", -- Keyword
        "﬌", -- Snippet
        "", -- Color
        "", -- File
        "", -- Reference
        "", -- Folder
        "", -- EnumMember
        "", -- Constant
        "", -- Struct
        "", -- Event
        "ﬦ", -- Operator
        "" -- TypeParameter
    }
end

-- Add additional capabilities supported by nvim-cmp
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- luasnip setup
local luasnip = require 'luasnip'

-- nvim-cmp setup
local cmp = require 'cmp'
cmp.setup {
    snippet = {expand = function(args) luasnip.lsp_expand(args.body) end},
    sources = {{name = 'nvim_lsp'}, {name = 'luasnip'}}
}

-- elixir
local config = {
    on_attach = on_attach,
    settings = {elixirLS = {dialyzerEnabled = false}, fetchDeps = false},
    cmd = {"elixir-ls"},
    capabilities = capabilities,
    fetchDeps = false
}
lspconfig.elixirls.setup(config)

-- cpp
lspconfig.clangd.setup({ on_attach = on_attach })

-- py
-- if not working, try running pylsp, if error: no preset version, uninstall and reinstall with current py version
lspconfig.pylsp.setup({
  on_attach = on_attach,
  settings = {
    pylsp = {
      plugins = {
        pylint = { 
          enabled = true,
          args = {'--disable=R,C,E0401'}
        },
      }
    }
  }
})
