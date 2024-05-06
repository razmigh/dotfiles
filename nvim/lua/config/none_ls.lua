local null_ls = require("null-ls")

local sources = {
     null_ls.builtins.formatting.prettierd,
     null_ls.builtins.formatting.clang_format,
  -- null_ls.builtins.formatting.lua_format,
  -- null_ls.builtins.formatting.beautysh.with({
  --      args = {"--indent-size", "2", "$FILENAME"}
  --  })
}

local config = {sources = sources}
null_ls.setup(config)
