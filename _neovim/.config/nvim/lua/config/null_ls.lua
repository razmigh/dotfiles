local null_ls = require("null-ls")

local sources = {
    null_ls.builtins.formatting.autopep8, 
    null_ls.builtins.formatting.prettierd,
    null_ls.builtins.formatting.lua_format
}

local config = {sources = sources}
null_ls.setup(config)
