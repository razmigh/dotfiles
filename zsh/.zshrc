# for GPG
export GPG_TTY=$(tty)

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(asdf docker git direnv)

source $ZSH/oh-my-zsh.sh

# aliases
alias c="clear"
alias gs="git status"
alias vim="nvim"

alias dcup="docker compose up -d"
alias dcd="docker compose down"

alias ips="iex -S mix phx.server"
alias ers="mix ecto.reset && mix ecto.seed"

alias tks="tmux kill-server"

# for fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# for p10k - To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# for asdf
#export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="$ASDF_DATA_DIR/shims:$PATH"
#. $HOME/.asdf/asdf.sh
#ASDF_PATH=`brew --prefix asdf`
#. "$ASDF_PATH/libexec/asdf.sh"
#
export PATH="$PATH:$HOME/.local/bin"

# for GO
export PATH="$PATH:$HOME/go/bin"

# for tmuxp
export DISABLE_AUTO_TITLE='true'

# for mosh
export LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

# for direnv
eval "$(direnv hook zsh)"

# clean duplicates in path
export PATH=$(echo "$PATH" | awk -v RS=':' -v ORS=":" '!a[$1]++{if (NR > 1) printf ORS; printf $a[$1]}')

export PYTHONPATH="$PYTHONPATH:/home/linuxbrew/.linuxbrew/bin"
