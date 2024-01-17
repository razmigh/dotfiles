return require('packer').startup(function()
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    use 'wakatime/vim-wakatime'

    use {"neovim/nvim-lspconfig", config = [[require('config.lsp')]]}

    use {"rhysd/git-messenger.vim"} -- git browser
    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
    use 'L3MON4D3/LuaSnip' -- Snippets plugin

    use {
        'nvim-treesitter/nvim-treesitter',
        event = "BufEnter",
        run = ':TSUpdate',
        config = [[require('config.treesitter')]]
    }

    use {"rrethy/nvim-base16", event = "VimEnter"}

    use {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.4',
        requires = {{'nvim-lua/plenary.nvim'}},
        event = "BufEnter",
        config = [[require('config.telescope')]]
    }
end)
