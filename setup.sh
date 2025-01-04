#!/usr/bin/env bash

OS=$(uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)

OS_LINUX="Linux"
OS_MAC="Darwin"

DOTFILES=$(pwd)

INSTALLS=~/.local/install
LANGUAGE_SERVERS=$INSTALLS/language_servers
LIBS=$INSTALLS/libs
TMP=$INSTALLS/.raztmp

FONTS_FOLDER=~/.local/share/fonts

symlink() {
  rm -rf $2
  ln -fsv $1 $2
}

install_brew_packages() {
  local pkgs=("$@")

  for pkg in "${pkgs[@]}"; do
    brew reinstall "$pkg"
  done
}

install_zsh() {
  echo '--Set up ZSH--'

  echo '-Install and set zsh as default shell-'
  if [ "$OS" = "$OS_MAC" ]; then
    brew reinstall zsh &&
    chsh -s /usr/local/bin/zsh
  fi
  if [ "$OS" = "$OS_LINUX" ]; then
    echo 'SKIP ZSH install, install yourself'
  fi

  echo '-Install oh-my-zsh-'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  echo '-Download fonts for powerlevel10k-'
  mkdir -pv $FONTS_FOLDER
  echo $FONTS_FOLDER
  cd $FONTS_FOLDER && {
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

_setup_zsh_files () {
  local zshrc=$DOTFILES/zsh/.zshrc.local
  if ! [ -f $zshrc ]; then
    echo -e "source $DOTFILES/zsh/.zshrc\n" >> $zshrc
  fi

  symlink $DOTFILES/zsh/.p10k.zsh $HOME/.p10k.zsh
  symlink $zshrc $HOME/.zshrc
}

install_dev() {
  if [ "$OS" = "$OS_MAC" ]; then
    echo -e '\nChecking Homebrew...'
    if ! [[ -x "$(command -v brew)" ]]; then
      echo '[pkg] Homebrew is missing'
      echo 'Installing Homebrew...'
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &&
      echo 'Homebrew ready!'
    fi

    echo "-Install Packages-"
    install_brew_packages direnv mosh postgres tmux tmuxp tree
  fi
  if [ "$OS" = "$OS_LINUX" ]; then
    echo "SKIP dev packages, install yourself (direnv mosh postgres tmux tmuxp tree)"
    exit 0
  fi

  echo "-Install asdf-"
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

  echo "-Install asdf direnv-"
  asdf plugin-add direnv
  asdf global direnv 2.33.0

  echo "-Install fzf-"
  git clone --depth 1 https://github.com/junegunn/fzf.git $LIBS/fzf
  $LIBS/fzf/install

  # echo -e "\nDownload and launch docker installer"
  # https://docs.docker.com/desktop/install/mac-install/
  echo -e "\nOpen docker download page..."
  open https://www.docker.com/

  _setup_dev_files
}

_setup_dev_files() {
  local gitconfig=$DOTFILES/dev_files/.gitconfig.local

  if ! [ -f $gitconfig ]; then
    echo "Enter your full name for git"
    read -r name
    echo "Enter your email for git"
    read -r email
    echo "Enter your username for git"
    read -r username

    cp $DOTFILES/dev_files/.gitconfig $gitconfig

    cat $gitconfig |
    sed "s/raz@boblet.com/$email/" |
    sed "s/Raz Boblet/$name/" |
    sed "s/razboblet/$username/" | tee $gitconfig
  fi

  symlink $DOTFILES/dev_files/.tmux.conf $HOME/.tmux.conf
  symlink $gitconfig $HOME/.gitconfig
}

install_nvim() {
  echo "--Install Neovim--"
  if [ "$OS" = "$OS_MAC" ]; then
    brew reinstall neovim
  fi
  if [ "$OS" = "$OS_LINUX" ]; then
    echo "SKIP neovim install, install yourself"
  fi

  _setup_nvim_files

  echo "-Install Packer-"
  local packer=~/.local/share/nvim/site/pack/packer/start/packer.nvim
  rm -rf $packer
  git clone --depth 1 https://github.com/wbthomason/packer.nvim $packer

  echo "-Run PackerSync-"
  nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

  echo "-Run TSUpdate-"
  nvim --headless -c 'TSUpdate' -c q

  echo "-Install Packages-"
  if [ "$OS" = "$OS_MAC" ]; then
    install_brew_packages ripgrep
  fi
  if [ "$OS" = "$OS_LINUX" ]; then
    echo "SKIP nvim package install, install yourself (ripgrep)"
  fi
}

_setup_nvim_files() {
  symlink $DOTFILES/nvim/init.vim $HOME/.config/nvim/init.vim
  symlink $DOTFILES/nvim/lua $HOME/.config/nvim/lua
}

install_python() {
  PYTHON_VERSION=3.9.16
  asdf plugin add python
  #asdf install python $PYTHON_VERSION
  asdf global python $PYTHON_VERSION

  echo "-Install pip-"
  python3 -m ensurepip

  #pip install python-lsp-server
  pip install python-lsp-server[pylint]
  #echo "-Install autopep for python formatting-"
  #pip install --upgrade autopep8
  pip install requests lxml
}

install_js() {
  echo "--Install JS & Node--"
  #NODEJS_VERSION=18.7.0
  #asdf plugin add nodejs
  #asdf install nodejs $NODEJS_VERSION
  #asdf global nodejs $NODEJS_VERSION

  echo -e "-Install vscode-langservers for eslint-"
  npm i -g vscode-langservers-extracted

  echo -e "\n-Install prettierd for vim formatting-"
  npm install -g @fsouza/prettierd
  #brew reinstall fsouza/prettierd/prettierd

  echo -e "-Install tsserver for js lsp-"
  npm install -g typescript typescript-language-server @vue/typescript-plugin

  echo -e "-Install volar-"
  npm install -g @vue/language-server
}

install_elixir() {
  echo "--Install Elixir--"

  ERLANG_VERSION=26.2.2
  ELIXIR_VERSION=1.16.1-otp-26

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
  cd $LANGUAGE_SERVERS && (
    curl -fLO https://github.com/elixir-lsp/elixir-ls/releases/download/v0.20.0/elixir-ls-v0.20.0.zip
    unzip -o elixir-ls-v0.20.0.zip -d ./elixir-ls
    cd -
  ) && sudo ln -fsv "${elixirls_path}/language_server.sh" "$HOME/.local/bin/elixir-ls" &&
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
  if [ "$OS" = "$OS_MAC" ]; then
    install_brew_packages gnupg
  fi
  if [ "$OS" = "$OS_LINUX" ]; then
    echo "SKIP gpg lib install, install yourself (gnupg)"
  fi

  echo "Generate key. (default-RSA & RSA, 4096, default-0)"
  gpg --full-generate-key
  gpg --list-secret-keys --keyid-format=long
  echo "Enter the ID after/under sec (8B42896FC8EC43CD)"
  read -r id

  echo "Here is generated key for your to put where needed (github etc)"
  gpg --armor --export "$id"
}

install_cpp() {
  install_brew_packages cmake cmake-docs

  # llvm
  # run build a few times if it fails... try with different -j 8
  local llvm=$LIBS/llvm-project
  git clone https://github.com/llvm/llvm-project.git $llvm
  mkdir -p $llvm/build
  cd $llvm/build
  cmake -G "Unix Makefiles" -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" -DCMAKE_INSTALL_PREFIX=$LIBS/llvm -DCMAKE_BUILD_TYPE=Release ../llvm
  make -j 16

  # ccls
  #
  # IF src/utils.hh:18:20: fatal error: optional: No such file or director
  # missing optional header files, install gcc 7 or newer
  #
  # IF /usr/bin/ld: cannot find -ltinfo
  # sudo apt install libtinfo-dev
  local ccls=$LIBS/ccls
  git clone --depth=1 --recursive https://github.com/MaskRay/ccls $ccls
  cd $ccls
  cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$llvm/build/bin
  cmake --build Release
  symlink $ccls/Release/ccls $HOME/.local/bin/ccls
  
  _setup_cpp_files
}

_setup_cpp_files() {
  mkdir -pv $HOME/.config/clangd
  symlink $DOTFILES/cpp/config.yaml $HOME/.config/clangd/config.yaml
}

install_lua() {
  echo "-Install LuaFormatter-"
  local lua_fmt=$LIBS/LuaFormatter
  git clone --recurse-submodules https://github.com/Koihik/LuaFormatter.git $lua_fmt
  cd $lua_fmt && {
    cmake .
    make
    make install
    cd -
  }

  _setup_lua_files
}

_setup_lua_files() {
  mkdir -pv $HOME/.local/bin
  symlink $LIBS/LuaFormatter/lua-format $HOME/.local/bin/lua-format
}

install_bash() {
  echo "-Install beautysh-"
  pip install setuptools beautysh
}

# untested
# https://gist.github.com/kuntau/37698a5159ceac40982b1f7ae96b7db8#file-mosh-md
install_mosh() {

  # sudo apt install perl protobuf-compiler libprotobuf-dev \
    # libncurses5-dev zlib1g-dev libutempter-dev libssl-dev
  brew reinstall pkg-config

  mkdir -pv $TMP
  cd $TMP && git clone --depth=1 https://github.com/mobile-shell/mosh.git &&\
    cd mosh && ./autogen.sh && ./configure && make && sudo make install && cd -


  # if you get protobuf issues
  # sudo find / -name "libprotobuf.so*"
  # make sure theres only 1 install and u rebuild with it

  # if mosh cant find it (shared module blabla), make sure it exists here
  # /usr/lib/x86_64-linux-gnu/libprotobuf.so.24.4.0
}

setup_all_files() {
  _setup_zsh_files
  _setup_dev_files
  _setup_nvim_files
  _setup_cpp_files
  _setup_lua_files
}

main() {
  echo 'OS:' "$OS $KERNEL ($ARCH)"

  clear
  local options=()
  options+=('zsh:       Install zsh')
  options+=('dev:       Install base dev')
  options+=('nvim:      Install neovim')
  options+=('')
  options+=('ssh:       Install SSH key')
  options+=('gpg:       Install GPG key')
  options+=('setupall:  Setup all files')
  options+=('')
  options+=('py:        Install python')
  options+=('js:        Install js/node')
  options+=('ex:        Install elixir')
  options+=('cpp:       Install C++')
  options+=('lua:       Install lua')
  options+=('sh:        Install bash')

  echo 'Select one of the following options:'
  for i in "${!options[@]}"; do
    echo "${options[$i]}"
  done
  echo "q) Quit"

  echo -e "\nSelect an option (*): "
  read -r response
  case "$response" in
    zsh) install_zsh ;;
    dev) install_dev ;;
    nvim) install_nvim ;;

    ssh) install_ssh_key ;;
    gpg) install_gpg_key ;;
    setupall) setup_all_files ;;

    py) install_python ;;
    js) install_js ;;
    ex) install_elixir ;;
    cpp) install_cpp ;;
    lua) install_lua ;;
    sh) install_bash ;;
    temp) _setup_lua_files ;;
    [Qq]) exit 0 ;;
    *) echo "'${response}' isn't a valid option" ;;
  esac

  readonly OS
  readonly KERNEL
  readonly ARCH
}

main "$@"
