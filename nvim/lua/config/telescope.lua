require("telescope").setup({
    defaults = {file_ignore_patterns = {"node_modules", "deps", ".git"}},
    pickers = {
        find_files = {
            find_command = {
                'rg', '--files', '--no-ignore', '--hidden'
            }
        }
    }
})
