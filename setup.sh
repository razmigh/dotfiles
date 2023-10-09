#!/usr/bin/env bash

DOTFILES=~/.dotfiles
LANGUAGE_SERVERS=~/.language_servers

symlink() {
  rm -rf $2
  ln -fsv $1 $2
}

install_brew_packages() {
  local pkgs=("$@")

  for pkg in "${pkgs[@]}"; do
    brew install "$pkg"
  done
}

install_zsh() {
  echo '--Set up ZSH--'

  echo '-Install and set zsh as default shell-'
  brew install zsh &&
    chsh -s /usr/local/bin/zsh

  echo '-Install oh-my-zsh-'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  echo '-Download fonts for powerlevel10k-'
  cd ~/Library/Fonts && {
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf'
    cd -
  }

  echo '-Download powerlevel10k-'
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

  _setup_zsh_files
}

install_dev() {
  echo -e '\nChecking Homebrew...'
  if ! [[ -x "$(command -v brew)" ]]; then
    echo '[pkg] Homebrew is missing'
    echo 'Installing Homebrew...'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &&
      echo 'Homebrew ready!'
  fi

  echo "-Install Packages-"
  install_brew_packages asdf direnv fzf mosh tmux tmuxp

  FZF_PATH=`brew --prefix fzf`
  echo "Set up fzf" && "$FZF_PATH/install"

  # echo -e "\nDownload and launch docker installer"
  # https://docs.docker.com/desktop/install/mac-install/
  echo -e "\nOpen docker download page..."
  open https://www.docker.com/

  _setup_dev_files
}

install_nvim() {
  echo "--Install Neovim--"
  brew install neovim

  _setup_nvim_files

  echo "-Install Packer-"
  local packer=~/.local/share/nvim/site/pack/packer/start/packer.nvim
  rm -rf $packer
  git clone --depth 1 https://github.com/wbthomason/packer.nvim $packer

  echo "-Run PackerSync-"
  nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

  echo "-Install prettierd for vim formatting-"
  brew install fsouza/prettierd/prettierd

  echo "-Install Packages-"
  install_brew_packages ripgrep
}

#untested
install_python() {
  PYTHON_VERSION=3.12.0
  asdf plugin add python
  asdf install python $PYTHON_VERSION
  asdf global python $PYTHON_VERSION

  echo "-Install pip-"
  python3 -m ensurepip

  echo "-Install autopep for python formatting-"
  pip install --upgrade autopep8
}

install_nodejs() {
  NODEJS_VERSION=18.7.0
  asdf plugin add nodejs
  asdf install nodejs $NODEJS_VERSION
  asdf global nodejs $NODEJS_VERSION
}

install_elixir() {
  echo "--Install Elixir--"

  ERLANG_VERSION=25.3
  ELIXIR_VERSION=1.14.4-otp-25

  echo "-Install asdf packages-"
  asdf plugin add erlang
  asdf plugin add elixir

  KERL_BUILD_DOCS=yes asdf install erlang $ERLANG_VERSION
  asdf install elixir $ELIXIR_VERSION

  asdf global erlang $ERLANG_VERSION
  asdf global elixir $ELIXIR_VERSION

  echo "-Install Elixir LS-"

  # build yourself
  #local ls_path="$HOME/.local/share/language-servers"
  #local elixirls_path="${ls_path}/elixir-ls"
  #local bin_path="${elixirls_path}/release"
  #rm -rf $elixirls_path && mkdir -pv $elixirls_path
  #git clone https://github.com/elixir-lsp/elixir-ls.git $elixirls_path
  #cd $elixirls_path
  #mix deps.get && mix compile && mix elixir_ls.release -o release
  #chmod +x "${bin_path}/language_server.sh"
  #sudo ln -fsv "${bin_path}/language_server.sh" "/usr/local/bin/elixir-ls" &&
  #  echo 'elixir-ls installed!'

  local elixirls_path="${LANGUAGE_SERVERS}/elixir-ls"
  rm -rf $elixirls_path && mkdir -pv $elixirls_path
  cd $ls_path && (
    curl -fLO https://github.com/elixir-lsp/elixir-ls/releases/download/v0.16.0/elixir-ls-v0.16.0.zip
    unzip -o elixir-ls-v0.16.0.zip -d ./elixir-ls
    cd -
  ) && sudo ln -fsv "${elixirls_path}/language_server.sh" "/usr/local/bin/elixir-ls" &&
    echo 'elixir-ls installed!'
}

install_ssh_key() {
  echo "Setting up SSH key"
  echo "Enter your email"
  read -r email
  # ssh-keygen -t ed25519 -C "$email" -f '/var/www/.ssh/id_ed25519' -N 'psht'
  ssh-keygen -t ed25519 -C "$email"
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519

  echo "Here is public key, add to wherever needed (github etc)"
  cat ~/.ssh/id_ed25519.pub
}

install_gpg_key() {
  echo "Setting up GPG key"
  echo "Install gpg tooling"
  install_brew_packages gnupg

  echo "Generate key. (default-RSA & RSA, 4096, default-0)"
  gpg --full-generate-key
  gpg --list-secret-keys --keyid-format=long
  echo "Enter the ID after/under sec (8B42896FC8EC43CD)"
  read -r id

  echo "Here is generated key for your to put where needed (github etc)"
  gpg --armor --export "$id"
}

_setup_zsh_files () {
  cp -Rv ./zsh $DOTFILES

  symlink $DOTFILES/zsh/.p10k.zsh $HOME/.p10k.zsh
  symlink $DOTFILES/zsh/.zshrc $HOME/.zshrc
}

_setup_dev_files() {
  cp -Rv ./dev_files $DOTFILES

  echo "Enter your full name for git"
  read -r name
  echo "Enter your email for git"
  read -r email
  echo "Enter your username for git"
  read -r username

  local gitconfig=$DOTFILES/dev_files/.gitconfig

  cat $gitconfig |
    sed "s/raz@boblet.com/$email/" |
    sed "s/Raz Boblet/$name/" |
    sed "s/razboblet/$username/" | tee $gitconfig

  symlink $DOTFILES/dev_files/.tmux.conf $HOME/.tmux.conf
  symlink $DOTFILES/dev_files/.gitconfig $HOME/.gitconfig
}

_setup_nvim_files() {
  cp -Rv ./nvim $DOTFILES

  symlink $DOTFILES/nvim/init.vim $HOME/.config/nvim/init.vim
  symlink $DOTFILES/nvim/lua $HOME/.config/nvim/lua
}

setup_all_files() {
  mkdir -pv $DOTFILES

  _setup_zsh_files
  _setup_dev_files
  _setup_nvim_files
}

main() {
  OS=$(uname -s)
  KERNEL=$(uname -r)
  ARCH=$(uname -m)
  echo 'spot' 'OS:' "$OS $KERNEL ($ARCH)"

  clear
  local options=()
  options[0]='Install zsh'
  options[1]='Install base dev'
  options[2]='Install neovim'
  options[3]='Install python'
  options[4]='Install node'
  options[5]='Install elixir'
  options[6]='Install SSH key'
  options[7]='Install GPG key'
  options[8]='Setup all files'
  #options[1]='Install Development env'
  #options[2]='Install Elixir env'
  #options[3]='Install LAMP env'
  #options[4]='Setup SSH key'
  #options[5]='Setup GPG key'
  #options[6]='Place dev config files'
  #options[7]='Place git config files'

  echo 'Select one of the following options:'
  for i in "${!options[@]}"; do
    echo "$(($i + 1))" "${options[$i]}"
  done
  echo "q) Quit"

  echo -e "\nSelect an option (*): "
  read -r response
  case "$response" in
  1) install_zsh ;;
  2) install_dev ;;
  3) install_nvim ;;
  4) install_python ;;
  5) install_nodejs ;;
  6) install_elixir ;;
  7) install_ssh_key ;;
  8) install_gpg_key ;;
  9) setup_all_files ;;
  [Qq]) exit 0 ;;
  *) echo "'${response}' isn't a valid option" ;;
  esac

  readonly OS
  readonly KERNEL
  readonly ARCH
}

main "$@"
