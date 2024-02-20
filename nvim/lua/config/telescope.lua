require("telescope").setup({
    defaults = {
        file_ignore_patterns = {
            "node_modules", "deps", ".git", "_build", ".elixir_ls"
        }
    },
    pickers = {
        find_files = {
            find_command = {'rg', '--files', '--no-ignore', '--hidden'}
        }
    }
})
