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

# clipboard: same scripts as tmux/nvim (overrides oh-my-zsh's clipcopy/clippaste)
if [ -x ~/.local/bin/clip-copy ]; then
  clipcopy() { ~/.local/bin/clip-copy "$@"; }
  clippaste() { ~/.local/bin/clip-paste; }
fi

# for fzf (binary and key bindings from the same clone; re-run setup.sh dev to update)
if [ -d ~/.local/install/libs/fzf ]; then
  export PATH="$HOME/.local/install/libs/fzf/bin:$PATH"
  source ~/.local/install/libs/fzf/shell/key-bindings.zsh
fi

# for p10k - To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# user installs (setup.sh puts everything here when there is no root) win over system ones
export PATH="$HOME/.local/bin:$PATH"

# for asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# for GO
export PATH="$PATH:$HOME/go/bin"

# cmake: build with ninja, write compile_commands.json for clangd
(( $+commands[ninja] )) && export CMAKE_GENERATOR=Ninja
export CMAKE_EXPORT_COMPILE_COMMANDS=ON

# for tmuxp
export DISABLE_AUTO_TITLE='true'

# UTF-8 locale for mosh; use an installed one (minimal containers lack en_US, perl/fzf then warn)
() {
  local l avail=(${(f)"$(locale -a 2>/dev/null)"})
  for l in en_US.utf8 en_US.UTF-8 C.utf8 C.UTF-8 ${(M)avail:#*.(utf8|UTF-8)} C; do
    (( ${avail[(Ie)$l]} )) && { export LANG=$l LC_CTYPE=$l; return }
  done
}

# for direnv
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# clean duplicates in path
export PATH=$(echo "$PATH" | awk -v RS=':' -v ORS=":" '!a[$1]++{if (NR > 1) printf ORS; printf $a[$1]}')

export PYTHONPATH="$PYTHONPATH:/home/linuxbrew/.linuxbrew/bin"
