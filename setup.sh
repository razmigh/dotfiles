#!/usr/bin/env bash

install_terminal() {
  echo 'Setting up terminal...'

  echo 'Install and set zsh as default shell...'
  brew install zsh &&
    chsh -s /usr/local/bin/zsh

  echo 'Install oh-my-zsh...'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  echo 'Install Powerlevel10k theme...'
  echo 'Downloading fonts for p10k...'
  cd ~/Library/Fonts && {
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf'
    curl -fLO 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf'
    cd -
  }

  echo 'Download powerlevel10k'
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

  echo 'Copy configs'
  cp -Rv ./terminal/. ~
}

install_dev_env() {
  OS=$(uname -s)
  KERNEL=$(uname -r)
  ARCH=$(uname -m)
  echo 'spot' 'OS:' "$OS $KERNEL ($ARCH)"

    echo -e '\nChecking Homebrew...'
    if ! [[ -x "$(command -v brew)" ]]; then
      echo '[pkg] Homebrew is missing'
      echo 'Installing Homebrew...'
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &&
        echo 'Homebrew ready!'
    fi

    echo -e "\nInstall brew packages..."
    # fd lazygit lazydocker
    local cli_packages=(asdf direnv fzf mosh ripgrep)
    for pkg in "${cli_packages[@]}"; do
      brew install "$pkg"
    done

    echo -e "\nSetup nvim"
    _setup_nvim

    echo -e "\nSetup tmux"
    _setup_tmux

    echo -e "\nSetting up brew packages..."
    echo "Set up fzf" && /opt/homebrew/opt/fzf/install

    # echo -e "\nDownload and launch docker installer"
    # https://docs.docker.com/desktop/install/mac-install/
    echo -e "\nOpen docker download page..."
    open https://www.docker.com/
    
  

  readonly OS
  readonly KERNEL
  readonly ARCH
}

_setup_nvim() {
  echo "Install Neovim"
  brew install neovim

  echo "Install Packer"
  git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

  echo "Copy files used by nvim"
  cp -Rv ./_neovim/. ~

  echo "run PackerSync"
  nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
}

_setup_tmux() {
  echo "Install tmux"
  brew install tmux
  brew install tmuxp

  echo "Copy files used by tmux"
  cp -Rv ./_tmux/. ~
}

_setup_git() {
  echo "Copy files used by git"
  cp -Rv ./_git/. ~
}

install_elixir_env() {
  ERLANG_VERSION=24.3.4.8
  ELIXIR_VERSION=1.14.3-otp-24
  NODEJS_VERSION=18.7.0

  echo -e "\nInstall asdf packages..."
  asdf plugin add erlang && asdf install erlang $ERLANG_VERSION
  asdf plugin add elixir && asdf install elixir $ELIXIR_VERSION
  asdf plugin add nodejs && asdf install nodejs $NODEJS_VERSION

  asdf global erlang $ERLANG_VERSION
  asdf global elixir $ELIXIR_VERSION
  asdf global nodejs $NODEJS_VERSION

  local ls_path="$HOME/.local/share/language-servers"
  mkdir -pv $ls_path
  cd $ls_path && (
    curl -fLO https://github.com/elixir-lsp/elixir-ls/releases/latest/download/elixir-ls.zip
    unzip -o elixir-ls.zip -d ./elixir-ls
    cd -
  ) && sudo ln -fsv "${ls_path}/elixir-ls/language_server.sh" "/usr/local/bin/elixir-ls" &&
    echo 'elixir-ls installed!'
}

install_lamp_env() {
  brew install php
  brew install mysql
  #mysql -u root
  #CREATE USER 'root'@'localhost' IDENTIFIED BY 'password';
  #GRANT ALL PRIVILEGES ON DBNAME.* TO 'raz'@'localhost';
  brew services restart mysql
  # php -S localhost:4000
}

setup_ssh_key() {
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

setup_gpg_key() {
  echo "Setting up GPG key"
  echo "Install gpg tooling"
  brew install gnupg

  echo "Generate key. (default-RSA & RSA, 4096, default-0)"
  gpg --full-generate-key
  gpg --list-secret-keys --keyid-format=long
  echo "Enter the ID after/under sec (8B42896FC8EC43CD)"
  read -r id

  echo "Here is generated key for your to put where needed (github etc)"
  gpg --armor --export "$id"
}

place_dev_files() {
  local folders=(_tmux _neovim terminal)
  for fld in "${folders[@]}"; do
    cp -Rv ./$fld/. ~
  done
}

place_git_files() {
  local folders=(_git)
  for fld in "${folders[@]}"; do
    cp -Rv ./$fld/. ~
  done
}

main() {
  clear
  local options=()
  options[0]='Install Terminal'
  options[1]='Install Development env'
  options[2]='Install Elixir env'
  options[3]='Install LAMP env'
  options[4]='Setup SSH key'
  options[5]='Setup GPG key'
  options[6]='Place dev config files'
  options[7]='Place git config files'

  echo 'Select one of the following options:'
  for i in "${!options[@]}"; do
    echo "$(($i + 1))" "${options[$i]}"
  done
  echo "q) Quit"

  echo -e "\nSelect an option (*): "
  read -r response
  case "$response" in
  1) install_terminal ;;
  2) install_dev_env ;;
  3) install_elixir_env ;;
  4) install_lamp_env ;;
  5) setup_ssh_key ;;
  6) setup_gpg_key ;;
  7) place_dev_files ;;
  8) place_git_files ;;
  [Qq]) exit 0 ;;
  *) echo "'${response}' isn't a valid option" ;;
  esac
}

main "$@"
