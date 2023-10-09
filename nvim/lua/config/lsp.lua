local lspconfig = require("lspconfig")

local on_attach = function()
    local opts = {buffer = 0}
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<Leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<Leader>f',
                   function() vim.lsp.buf.format {async = true} end, opts)

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

local config = {
    on_attach = on_attach,
    settings = {elixirLS = {dialyzerEnabled = false}, fetchDeps = false},
    cmd = {"elixir-ls"},
    capabilities = capabilities,
    fetchDeps = false
}

lspconfig.elixirls.setup(config)
