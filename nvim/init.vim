filetype plugin on

let mapleader = " "

set shell=~/.local/bin/zsh
set shiftwidth=2
set tabstop=2
set softtabstop=2
set expandtab
set smartindent
set number
" set cursorline
set clipboard^=unnamedplus
lua require('config.clipboard')

lua require('plugins')

" Color scheme
set termguicolors

packadd! nvim-base16
colorscheme base16-onedark

" File Navigation
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>
nnoremap <silent> <leader>e :Explore<CR>
nnoremap <silent> <leader><Space> :call ProjectFiles()<CR>
nnoremap <silent> <Leader>, :Telescope buffers<CR>
nnoremap <silent> <Leader>/ :Telescope live_grep<CR>
nnoremap <silent> <Leader>q :bdelete<CR>
nnoremap <silent> <Leader>Q :bdelete!<CR>
nnoremap <silent> <Leader>- :LspClangdSwitchSourceHeader<CR>

" Clear highlighted search
nmap <silent> <C-\> :nohlsearch<CR>

" Format
" nnoremap <silent> FJ :%!js-beautify --indent-size=2<CR>
function! FormatDocument() abort
  if &filetype ==# 'xml'
    call CocActionAsync('format')
  else
    " Prefer null-ls (prettierd/clang-format) when it can format the buffer, so servers don't format twice
    lua << trim EOF
      local use_null_ls = #vim.lsp.get_clients({ bufnr = 0, name = "null-ls", method = "textDocument/formatting" }) > 0
      vim.lsp.buf.format({ async = true, filter = function(client)
        if use_null_ls then return client.name == "null-ls" end
        return not vim.tbl_contains({ "volar", "vue_ls", "ts_ls" }, client.name)
      end })
    EOF
  endif
endfunction
nnoremap <silent> <Leader>f <Cmd>call FormatDocument()<CR>

" Set ripgrep as the grep command
if executable("rg")
  set grepprg=rg\ -F\ --vimgrep\ --no-heading\ --hidden\ --no-ignore-vcs 
  set grepformat=%f:%l:%c:%m,%f:%l:%m
endif

function ProjectFiles()
  "silent! !git rev-parse --is-inside-work-tree
  "if v:shell_error == 0
  "  :Telescope git_files
  "else
    :Telescope find_files
  "endif
endfunction

" Automatically source vimrc on save.
autocmd! BufWritePost $MYVIMRC source $MYVIMRC | echom "Sourced " . $MYVIMRC

autocmd! FileType cpp setlocal shiftwidth=3 tabstop=3 softtabstop=3
autocmd! FileType xml setlocal shiftwidth=3 tabstop=3 softtabstop=3
