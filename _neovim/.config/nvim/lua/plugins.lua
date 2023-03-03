return require('packer').startup(function()
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    use 'wakatime/vim-wakatime'

    use {"neovim/nvim-lspconfig", config = [[require('config.lsp')]]}

    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
    use 'L3MON4D3/LuaSnip' -- Snippets plugin

    use {
        "jose-elias-alvarez/null-ls.nvim",
        config = [[require('config.null_ls')]],
        requires = {"nvim-lua/plenary.nvim"}
    }

    use {
        'nvim-treesitter/nvim-treesitter',
        event = "BufEnter",
        run = ':TSUpdate',
        config = [[require('config.treesitter')]]
    }

    use {"rrethy/nvim-base16", event = "VimEnter"}

    use {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.1',
        requires = {{'nvim-lua/plenary.nvim'}},
        event = "BufEnter",
        config = [[require('config.telescope')]]
    }
end)
