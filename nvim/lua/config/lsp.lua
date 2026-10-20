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
    mapping = cmp.mapping.preset.insert({
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<CR>'] = cmp.mapping.confirm({select = true})
    }),
    sources = cmp.config.sources(
        {{name = 'nvim_lsp'}, {name = 'luasnip'}},
        {{name = 'buffer'}}
    )
}

-- elixir
vim.lsp.enable('elixirls')
vim.lsp.config('elixirls', {
    on_attach = on_attach,
    settings = {elixirLS = {dialyzerEnabled = false}, fetchDeps = false},
    cmd = {"elixir-ls"},
    capabilities = capabilities,
    fetchDeps = false
})

-- cpp
vim.lsp.enable('clangd')
-- Keep lspconfig's default on_attach, which defines :LspClangdSwitchSourceHeader
local clangd_default_on_attach = vim.lsp.config.clangd.on_attach
vim.lsp.config('clangd', {
    on_attach = function(client, bufnr)
        if clangd_default_on_attach then clangd_default_on_attach(client, bufnr) end
        on_attach(client, bufnr)
    end,
    -- utf-16 to match null-ls and avoid mixed offset encodings in the same buffer
    capabilities = vim.tbl_deep_extend('force', capabilities, {offsetEncoding = { 'utf-16' }})
})

-- py
-- if not working, try running pylsp, if error: no preset version, uninstall and reinstall with current py version
vim.lsp.enable('pylsp')
vim.lsp.config('pylsp', {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
        pylsp = {
            plugins = {
                pylint = {enabled = true, args = {'--disable=R,C,E0401'}}
            }
        }
    }
})

-- js
local node_dir = vim.fn.system("npm root -g"):gsub("[\n\r]", "")
-- Global typescript is v7 (native, no tsserver), so fall back to a v5 install when the project has none
local fallback_tsdk = node_dir .. '/@fsouza/prettierd/node_modules/typescript/lib'

vim.lsp.enable('eslint')
vim.lsp.config('eslint', {on_attach = on_attach, capabilities = capabilities, settings = {}})

-- vue_ls (v3) only handles HTML/CSS in .vue files; ts_ls handles the script via @vue/typescript-plugin
vim.lsp.enable('vue_ls')
vim.lsp.config('vue_ls', {
    on_attach = on_attach,
    capabilities = capabilities,
    cmd = function(dispatchers, config)
        local tsdk = config.root_dir and vim.fs.joinpath(config.root_dir, 'node_modules/typescript/lib')
        if not (tsdk and vim.uv.fs_stat(tsdk)) then tsdk = fallback_tsdk end
        return vim.lsp.rpc.start({'vue-language-server', '--stdio', '--tsdk=' .. tsdk}, dispatchers)
    end,
})

vim.lsp.enable('ts_ls')
vim.lsp.config('ts_ls', {
  on_attach = on_attach,
  capabilities = capabilities,
  init_options = {
    tsserver = {fallbackPath = fallback_tsdk},
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = node_dir .. "/@vue/typescript-plugin",
        languages = {"vue"},
      },
    },
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
  },
})

-- Only enable where svelteserver is installed, to avoid spawn errors on other machines
if vim.fn.executable('svelteserver') == 1 then
    vim.lsp.enable('svelte')
end
vim.lsp.config('svelte', {
    on_attach = on_attach,
    capabilities = capabilities,
})
