-- Route the + and * registers through bin/clip-copy and bin/clip-paste, the same scripts tmux uses.
local copy = vim.fn.expand('~/.local/bin/clip-copy')
local paste = vim.fn.expand('~/.local/bin/clip-paste')

local function last_yank()
  return { vim.fn.split(vim.fn.getreg('"'), '\n'), vim.fn.getregtype('"') }
end

local over_ssh = (vim.env.SSH_CONNECTION or vim.env.SSH_TTY) and not vim.env.TMUX

if over_ssh and vim.fn.has('nvim-0.10') == 1 then
  -- Over plain SSH the scripts can't reach the terminal from nvim's server process,
  -- so use nvim's own OSC 52. Most terminals refuse OSC 52 reads, so paste the last yank.
  local osc52 = require('vim.ui.clipboard.osc52')
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = last_yank, ['*'] = last_yank },
  }
elseif vim.fn.executable(copy) == 1 and vim.fn.executable(paste) == 1 then
  vim.g.clipboard = {
    name = 'clip-copy',
    copy = { ['+'] = { copy }, ['*'] = { copy } },
    paste = { ['+'] = { paste }, ['*'] = { paste } },
    cache_enabled = 1,
  }
end

-- Ctrl+C copies a visual / mouse selection, like the tmux binding.
vim.keymap.set('x', '<C-c>', '"+y', { desc = 'Copy selection to system clipboard' })
