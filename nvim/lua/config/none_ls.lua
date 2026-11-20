local null_ls = require("null-ls")

local sources = {
    null_ls.builtins.formatting.prettierd,
    null_ls.builtins.formatting.clang_format,
    -- settings in ~/.config/stylua/stylua.toml (lua/stylua.toml), a project stylua.toml wins
    null_ls.builtins.formatting.stylua,
    -- 2-space indent, indented case items (flags make shfmt ignore .editorconfig)
    null_ls.builtins.formatting.shfmt.with({extra_args = {"-i", "2", "-ci"}}),
}

local config = {sources = sources}
null_ls.setup(config)
