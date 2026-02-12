require("telescope").setup({
    defaults = {
        file_ignore_patterns = {
            "node_modules", "deps", ".git", "_build", ".elixir_ls", ".cache", "core.*.*.*"
        }
    },
    pickers = {
        find_files = {
            find_command = {'rg', '--files', '--no-ignore', '--hidden'}
        }
    }
})
