-- Parsers are compiled locally; skip auto-install when no C compiler exists
local has_cc = false
for _, cc in ipairs({"cc", "gcc", "clang", "zig"}) do
    if vim.fn.executable(cc) == 1 then has_cc = true break end
end

require("nvim-treesitter.configs").setup({
    ensure_installed = has_cc and {
        "bash", "c", "cpp", "css", "dockerfile", "eex", "elixir", "erlang",
        "graphql", "heex", "html", "javascript", "json", "latex", "lua", "make",
        "python", "regex", "scss", "surface", "svelte", "toml", "typescript",
        "vim", "vue", "zig", "yaml"
    } or {},
    ignore_install = {}, -- List of parsers to ignore installing
    highlight = {
        enable = true, -- false will disable the whole extension
        disable = {} -- list of language that will be disabled
    },
    indent = {
        -- indentation based on treesitter for the = operator
        enable = true
    }
})
