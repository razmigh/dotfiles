# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# aliases
alias c="clear"
alias gs="git status"
alias vim="nvim"

alias dcup="docker compose up -d"
alias dcd="docker compose down"

alias ips="iex -S mix phx.server"
alias ers="mix ecto.reset && mix ecto.seed"

alias apachestart="sudo service apache2 start"
alias apachestop="sudo service apache2 stop"
alias apacherestart="sudo service apache2 restart"
alias mysqlstart="brew services start mysql"
alias mysqlstop="brew services stop mysql"
alias mysqlrestart="brew services restart mysql"

alias tks="tmux kill-server"

# for fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# for p10k - To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# for asdf
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# for tmuxp
export DISABLE_AUTO_TITLE='true'

# for GPG
export GPG_TTY=$(tty)

# for mosh
export LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

# for kubectl
source <(kubectl completion zsh)

# for direnv
eval "$(direnv hook zsh)"
