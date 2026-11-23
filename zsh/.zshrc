# UTF-8 locale, set before p10k (zsh errors "character not in range" without one).
# Prefer an installed one; otherwise C.UTF-8 still works for zsh-bin, and perl's warning is silenced.
() {
  local l avail=(${(f)"$(locale -a 2>/dev/null)"})
  for l in en_US.utf8 en_US.UTF-8 C.utf8 C.UTF-8 ${(M)avail:#*.(utf8|UTF-8)}; do
    (( ${avail[(Ie)$l]} )) && { export LANG=$l LC_CTYPE=$l; return }
  done
  export LANG=C.UTF-8 LC_CTYPE=C.UTF-8 PERL_BADLANG=0
}

# user installs (setup.sh puts everything here when there is no root) win over system ones
export PATH="$HOME/.local/bin:$PATH"

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

plugins=(asdf docker git)
(( $+commands[direnv] )) && plugins+=(direnv)

# oh-my-zsh skips completions from group/other-writable dirs ("Insecure completion-dependent
# directories"). On shared hosts (umask 002, setgid group dirs) installs and omz updates come out
# group-writable, so fix our own dirs before omz audits them. Audit the fpath omz is about to build,
# and drop the compdump written while they were skipped: it has no completions and omz won't redo it.
() {
  autoload -Uz compaudit
  local custom=${ZSH_CUSTOM:-$ZSH/custom}
  # same dirs oh-my-zsh.sh adds to fpath (no comments inside $(...): it is parsed without interactive_comments)
  local -a insecure=(${(f)"$(
    fpath+=(${ZSH_CACHE_DIR:-$ZSH/cache}/completions $ZSH/{functions,completions}
            $custom/{functions,completions} {$ZSH,$custom}/plugins/${^plugins})
    compaudit 2>/dev/null)"})
  insecure=(${^insecure}(NU))  # only ones we own; chmod can't fix the rest
  (( $#insecure )) || return
  chmod g-w,o-w -- $insecure
  rm -f -- ${ZDOTDIR:-$HOME}/.zcompdump*(N)
}

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

# for asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# for GO
export PATH="$PATH:$HOME/go/bin"

# cmake: build with ninja, write compile_commands.json for clangd
(( $+commands[ninja] )) && export CMAKE_GENERATOR=Ninja
export CMAKE_EXPORT_COMPILE_COMMANDS=ON

# for tmuxp
export DISABLE_AUTO_TITLE='true'

# clean duplicates in path
export PATH=$(echo "$PATH" | awk -v RS=':' -v ORS=":" '!a[$1]++{if (NR > 1) printf ORS; printf $a[$1]}')

export PYTHONPATH="$PYTHONPATH:/home/linuxbrew/.linuxbrew/bin"
