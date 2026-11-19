#!/usr/bin/env bash

OS=$(uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)

OS_LINUX="Linux"
OS_MAC="Darwin"

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

INSTALLS=~/.local/install
LANGUAGE_SERVERS=$INSTALLS/language_servers
LIBS=$INSTALLS/libs
TMP=$INSTALLS/.raztmp

BIN=~/.local/bin
FONTS_FOLDER=~/.local/share/fonts
[ "$OS" = "$OS_MAC" ] && FONTS_FOLDER=~/Library/Fonts

mkdir -pv $LANGUAGE_SERVERS
mkdir -pv $LIBS
mkdir -pv $TMP

mkdir -pv $BIN
# so tools installed by this run are found right away
export PATH="$BIN:$PATH"

symlink() {
  rm -rf "$2"
  ln -fsv "$1" "$2"
}

has() { command -v "$1" >/dev/null 2>&1; }

# Root is optional: system packages are only installed when we are root or sudo works without a
# password prompt (USE_SUDO=1 ./setup.sh allows the prompt). Otherwise tools go to ~/.local.
can_sudo() {
  [ "$(id -u)" = 0 ] && return 0
  has sudo || return 1
  sudo -n true 2>/dev/null || { [ "$USE_SUDO" = 1 ] && sudo -v; }
}

ensure_brew() {
  has brew && return
  echo 'Installing Homebrew...'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# Install packages with brew (macOS) or apt/dnf/yum (Linux, needs root). Returns 1 when skipped.
pkg_install() {
  if [ "$OS" = "$OS_MAC" ]; then
    ensure_brew && brew install "$@"
    return
  fi
  if ! can_sudo; then
    echo "[skip] no root, install yourself if needed: $*"
    return 1
  fi
  local sudo=sudo pm
  [ "$(id -u)" = 0 ] && sudo=
  for pm in apt-get dnf yum; do
    has $pm && break
  done
  has $pm || { echo "[skip] no apt/dnf/yum, install yourself: $*"; return 1; }
  local pkg
  for pkg in "$@"; do
    $sudo $pm install -y "$pkg"
  done
}

# Latest release tag of a GitHub repo (follows the redirect, no rate-limited API call).
gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/##'
}

# arch naming used by most release assets: x86_64 or arm64
release_arch() {
  case "$ARCH" in
    aarch64|arm64) echo arm64 ;;
    *) echo x86_64 ;;
  esac
}

# Append a line to a file once.
add_line() {
  grep -qxF "$2" "$1" 2>/dev/null || echo "$2" >> "$1"
}

install_zsh() {
  echo '--Set up ZSH--'

  echo '-Install zsh-'
  if ! has zsh && ! [ -x $BIN/zsh ]; then
    if [ "$OS" = "$OS_MAC" ] || can_sudo; then
      pkg_install zsh
    else
      # static build (romkatv/zsh-bin) in ~/.local, no root needed
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" -- -q -d ~/.local -e no
    fi
  fi
  # nvim's init.vim uses ~/.local/bin/zsh as its shell
  [ -e $BIN/zsh ] || symlink "$(command -v zsh)" $BIN/zsh
  local zsh_path=$(command -v zsh || echo $BIN/zsh)
  echo "zsh: $zsh_path ($($zsh_path --version))"

  echo '-Set zsh as default shell-'
  if [ "$(basename "${SHELL:-}")" = zsh ]; then
    echo 'Already the default shell'
  elif grep -qxF "$zsh_path" /etc/shells 2>/dev/null && chsh -s "$zsh_path"; then
    echo "Default shell set to $zsh_path"
  elif grep -qE '^[[:space:]]*(exec[[:space:]]+)?[^[:space:]#]*zsh([[:space:]]|$)|exec[[:space:]]+"?[^[:space:]#"]*zsh' ~/.bash_profile 2>/dev/null; then
    echo '~/.bash_profile already starts zsh'
  else
    # chsh needs zsh in /etc/shells (root), so switch to zsh from interactive bash logins instead
    add_line ~/.bash_profile "[[ \$- == *i* ]] && [ -x \"$zsh_path\" ] && exec \"$zsh_path\" -l"
    echo "chsh unavailable, ~/.bash_profile now starts $zsh_path"
  fi

  echo '-Install oh-my-zsh-'
  if [ -d ~/.oh-my-zsh ]; then
    git -C ~/.oh-my-zsh pull --ff-only
  else
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  echo '-Download fonts for powerlevel10k-'
  mkdir -pv $FONTS_FOLDER
  local font
  for font in Regular Bold Italic 'Bold Italic'; do
    curl -fsSL -o "$FONTS_FOLDER/MesloLGS NF $font.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${font// /%20}.ttf"
  done
  has fc-cache && fc-cache -f $FONTS_FOLDER

  echo '-Download powerlevel10k-'
  local p10k=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  if [ -d $p10k ]; then
    git -C $p10k pull --ff-only
  else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $p10k
  fi

  install_fzf

  _setup_zsh_files
}

install_fzf() {
  echo "-Install fzf-"
  if [ -d $LIBS/fzf ]; then
    git -C $LIBS/fzf pull --ff-only
  else
    git clone --depth 1 https://github.com/junegunn/fzf.git $LIBS/fzf
  fi
  # --bin: only fetch the binary; .zshrc sources the shell integration from this clone
  $LIBS/fzf/install --bin
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
  echo "-Install Packages-"
  [ "$OS" = "$OS_LINUX" ] && pkg_install build-essential procps curl file git
  pkg_install direnv mosh tmux tmuxp tree
  if ! has direnv; then
    echo '-Install direnv in ~/.local/bin-'
    curl -fsSL https://direnv.net/install.sh | bin_path=$BIN bash
  fi

  echo '-Install go-'
  local go=$LIBS/go
  local go_os=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
  local go_arch=amd64
  [ "$(release_arch)" = arm64 ] && go_arch=arm64
  local go_version=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
  (
    cd $TMP &&
    curl -fL -o go.tar.gz "https://go.dev/dl/$go_version.$go_os-$go_arch.tar.gz" &&
    rm -rf go && tar -xzf go.tar.gz &&
    rm -rf $go && mv go $go
  ) && symlink $go/bin/go $BIN/go

  install_asdf

  install_clipboard

  _setup_dev_files

  echo -e "\nInstall docker yourself: https://docs.docker.com/engine/install/"
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

    sed -e "s/raz@boblet.com/$email/" \
        -e "s/Raz Boblet/$name/" \
        -e "s/razboblet/$username/" \
        $DOTFILES/dev_files/.gitconfig | tee $gitconfig

    echo "Add a git profile per host (e.g. github.com, your Bitbucket host)? [y/N]"
    read -r add_profiles
    while [[ "$add_profiles" =~ ^[Yy] ]]; do
      add_git_profile
      echo "Add another git profile? [y/N]"
      read -r add_profiles
    done
  fi

  symlink $DOTFILES/dev_files/.tmux.conf $HOME/.tmux.conf
  for script in $DOTFILES/bin/*; do
    symlink $script $BIN/$(basename $script)
  done
  symlink $gitconfig $HOME/.gitconfig
  for profile_gitconfig in $DOTFILES/dev_files/.gitconfig.*; do
    if [ -f "$profile_gitconfig" ] && [ "$profile_gitconfig" != "$gitconfig" ]; then
      symlink $profile_gitconfig $HOME/$(basename $profile_gitconfig)
    fi
  done
}

# Git identity used for repos with a remote on a given host; other repos keep the [user] in .gitconfig.local.
# If a repo has remotes on several profiled hosts, the profile added last wins.
add_git_profile() {
  local gitconfig=$DOTFILES/dev_files/.gitconfig.local

  if ! [ -f $gitconfig ]; then
    echo "Run 'dev' or 'setupall' first to create $gitconfig"
    return 1
  fi

  echo "Enter the git host for this profile (e.g. github.com, bitbucket.org)"
  read -r host
  echo "Enter a name for this profile (e.g. github, bitbucket)"
  read -r profile
  if ! [[ "$host" =~ ^[A-Za-z0-9.-]+$ && "$profile" =~ ^[A-Za-z0-9_-]+$ && "$profile" != "local" ]]; then
    echo "Invalid host or profile name"
    return 1
  fi
  echo "Enter your full name for $host"
  read -r name
  echo "Enter your email for $host (on GitHub, ID+username@users.noreply.github.com keeps it private)"
  read -r email

  local profile_gitconfig=$DOTFILES/dev_files/.gitconfig.$profile
  sed -e "s/raz@boblet.com/$email/" \
      -e "s/Raz Boblet/$name/" \
      $DOTFILES/dev_files/.gitconfig-profile > $profile_gitconfig

  if ! grep -qF "hasconfig:remote.*.url:https://$host/**" $gitconfig; then
    {
      echo ""
      echo "# $profile profile: repos with a remote on $host"
      for pattern in "git@$host:*" "git@$host:*/**" "ssh://*@$host/**" "ssh://*@$host:*/**" "https://$host/**" "https://*@$host/**"; do
        echo "[includeIf \"hasconfig:remote.*.url:$pattern\"]"
        echo "	path = ~/.gitconfig.$profile"
      done
    } >> $gitconfig
  fi

  symlink $profile_gitconfig $HOME/.gitconfig.$profile
  echo "Added git profile '$profile' for $host"
}

# Clipboard tool used by bin/clip-copy and bin/clip-paste (macOS and WSL have one built in).
install_clipboard() {
  echo '-Install clipboard tool-'
  if [ "$OS" != "$OS_LINUX" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    echo 'Built in (pbcopy / clip.exe), nothing to install'
    return
  fi

  local pkg=xsel
  [ -n "$WAYLAND_DISPLAY" ] && pkg=wl-clipboard
  if can_sudo; then
    pkg_install $pkg
    return
  fi
  if [ "$pkg" != xsel ]; then
    echo "-INSTALL $pkg YOURSELF-"
    return
  fi

  echo 'No apt/sudo: building xsel from source (needs gcc and libX11 headers)'
  local xsel=$LIBS/xsel
  (
    cd $TMP &&
    curl -fsSL -o xsel.tar.gz https://github.com/kfish/xsel/archive/refs/tags/1.2.1.tar.gz &&
    rm -rf xsel-1.2.1 && tar -xf xsel.tar.gz &&
    rm -rf $xsel && mv xsel-1.2.1 $xsel &&
    gcc -O2 -DVERSION='"1.2.1"' -o $xsel/xsel $xsel/xsel.c -lX11
  ) && symlink $xsel/xsel $BIN/xsel
}

# Prebuilt asdf (v0.16+ is a single Go binary).
install_asdf() {
  echo "-Install asdf-"
  local asdf_dir=$LIBS/asdf
  local os=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
  local arch=amd64
  [ "$(release_arch)" = arm64 ] && arch=arm64
  local tag=$(gh_latest_tag asdf-vm/asdf)
  mkdir -p $asdf_dir &&
  curl -fL "https://github.com/asdf-vm/asdf/releases/download/$tag/asdf-$tag-$os-$arch.tar.gz" | tar -xz -C $asdf_dir &&
  symlink $asdf_dir/asdf $BIN/asdf
}

# Global npm packages; falls back to ~/.local when the global prefix isn't writable (system node).
npm_global() {
  has npm || { echo "[skip] npm missing (run 'js' first): $*"; return 1; }
  if [ -w "$(npm prefix -g)" ]; then
    npm install -g "$@"
  else
    npm install -g --prefix ~/.local "$@"
  fi
}

install_nvim() {
  echo "--Install Neovim--"
  if [ "$OS" = "$OS_MAC" ]; then
    pkg_install neovim
  else
    # official prebuilt release; build from source in ~/.local if it can't run here (old glibc)
    local nvim=$LIBS/nvim
    local name=nvim-linux-$(release_arch)
    (
      cd $TMP &&
      curl -fL -o nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/$name.tar.gz &&
      rm -rf $name && tar -xzf nvim.tar.gz &&
      rm -rf $nvim && mv $name $nvim
    )
    if ! $nvim/bin/nvim --version >/dev/null 2>&1; then
      echo '-Prebuilt nvim failed, building from source (needs cmake, gettext, gcc)-'
      local src=$LIBS/neovim
      rm -rf $src $nvim &&
      git clone --depth 1 --branch stable https://github.com/neovim/neovim $src &&
      make -C $src CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=$nvim install
    fi
    symlink $nvim/bin/nvim $BIN/nvim
  fi

  install_ripgrep

  _setup_nvim_files

  echo '-Install tree-sitter-cli for latex-'
  if [ "$OS" = "$OS_MAC" ]; then
    pkg_install tree-sitter-cli
  else
    local ts_arch=x64
    [ "$(release_arch)" = arm64 ] && ts_arch=arm64
    local cargo=$(command -v cargo || echo ~/.cargo/bin/cargo)
    # latest first, then v0.25.10 (last release built against an older glibc, e.g. RHEL 9)
    local ts_url ts_ok=0
    for ts_url in latest/download download/v0.25.10; do
      curl -fL https://github.com/tree-sitter/tree-sitter/releases/$ts_url/tree-sitter-linux-$ts_arch.gz |
        gunzip > $TMP/tree-sitter && chmod +x $TMP/tree-sitter &&
        $TMP/tree-sitter --version >/dev/null 2>&1 && ts_ok=1 && break
    done
    if [ $ts_ok = 1 ]; then
      mv -f $TMP/tree-sitter $BIN/tree-sitter
    elif [ -x "$cargo" ]; then
      echo '-Prebuilt tree-sitter needs a newer glibc, building it with cargo-'
      $cargo install --locked --root ~/.local tree-sitter-cli
    else
      echo '[skip] prebuilt tree-sitter needs a newer glibc; install rust (cargo) and rerun for latex'
    fi
    rm -f $TMP/tree-sitter
  fi

  echo "-Install Packer-"
  rm -f ~/.config/nvim/plugin/packer_compiled.lua
  local packer=~/.local/share/nvim/site/pack/packer/start/packer.nvim
  rm -rf $packer
  git clone --depth 1 https://github.com/wbthomason/packer.nvim $packer

  echo "-Run PackerSync-"
  nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

  echo "-Run TSUpdate-"
  nvim --headless -c 'TSUpdate' -c q
}

# ripgrep is used by telescope; static musl build on Linux when there is no root
install_ripgrep() {
  echo "-Install ripgrep-"
  has rg && { echo "Already installed: $(command -v rg)"; return; }
  if [ "$OS" = "$OS_MAC" ] || can_sudo; then
    pkg_install ripgrep && return
  fi
  local target=x86_64-unknown-linux-musl
  [ "$(release_arch)" = arm64 ] && target=aarch64-unknown-linux-gnu
  local tag=$(gh_latest_tag BurntSushi/ripgrep)
  local name=ripgrep-$tag-$target
  local rg=$LIBS/ripgrep
  (
    cd $TMP &&
    curl -fL -o rg.tar.gz https://github.com/BurntSushi/ripgrep/releases/download/$tag/$name.tar.gz &&
    rm -rf $name && tar -xzf rg.tar.gz &&
    rm -rf $rg && mv $name $rg
  ) && symlink $rg/rg $BIN/rg
}

_setup_nvim_files() {
  mkdir -pv $HOME/.config/nvim
  symlink $DOTFILES/nvim/init.vim $HOME/.config/nvim/init.vim
  symlink $DOTFILES/nvim/lua $HOME/.config/nvim/lua
  symlink $DOTFILES/nvim/coc-settings.json $HOME/.config/nvim/coc-settings.json
}

install_python() {
  asdf plugin add python
  asdf install python latest
  asdf set -u python latest

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
  asdf plugin add nodejs
  asdf install nodejs latest
  asdf set -u nodejs latest

  echo -e "-Install vscode-langservers for eslint-"
  npm_global vscode-langservers-extracted

  echo -e "\n-Install prettierd for vim formatting-"
  npm_global @fsouza/prettierd

  echo -e "-Install tsserver for js lsp-"
  npm_global typescript typescript-language-server @vue/typescript-plugin

  echo -e "-Install volar-"
  npm_global @vue/language-server

  echo -e "-Install svelte-"
  npm_global svelte-language-server
  local npm_bin=$(npm prefix -g)/bin
  [ -x $npm_bin/svelteserver ] && [ "$npm_bin" != "$BIN" ] && symlink $npm_bin/svelteserver $BIN/svelteserver
}

install_elixir() {
  echo "--Install Elixir--"

  echo '-Install inotify-tools-'
  [ "$OS" = "$OS_LINUX" ] && pkg_install inotify-tools

  echo "-Install asdf packages-"
  asdf plugin add erlang
  asdf plugin add elixir

  KERL_BUILD_DOCS=yes asdf install erlang latest
  asdf install elixir latest

  asdf set -u erlang 27.3.4
  asdf set -u elixir 1.18.3-otp-27

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
  #symlink "${bin_path}/language_server.sh" "/usr/local/bin/elixir-ls" &&
  #  echo 'elixir-ls installed!'

  local elixirls_path="${LANGUAGE_SERVERS}/elixir-ls"
  rm -rf $elixirls_path && mkdir -pv $elixirls_path
  cd $LANGUAGE_SERVERS && (
    curl -fLO https://github.com/elixir-lsp/elixir-ls/releases/download/v0.27.2/elixir-ls-v0.27.2.zip -C -
    unzip -o elixir-ls-v0.27.2.zip -d ./elixir-ls
    cd -
  ) && symlink "${elixirls_path}/language_server.sh" "$BIN/elixir-ls" &&
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
  has gpg || pkg_install gnupg || return 1

  echo "Generate key. (default-RSA & RSA, 4096, default-0)"
  gpg --full-generate-key
  gpg --list-secret-keys --keyid-format=long
  echo "Enter the ID after/under sec (8B42896FC8EC43CD)"
  read -r id

  echo "Here is generated key for your to put where needed (github etc)"
  gpg --armor --export "$id"
}

install_cpp() {
  has cmake || pkg_install cmake

  # llvm
  # run build a few times if it fails... try with different -j 8
  local llvm=$LIBS/llvm-project
  rm -rf $llvm
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
  #
  # IF can't find ClangConfig.cmake
  # cp $llvm/build/lib/cmake/clang/ClangConfig.cmake $llvm/build/bin/

  local ccls=$LIBS/ccls
  rm -rf $ccls
  git clone --depth=1 --recursive https://github.com/MaskRay/ccls $ccls
  cd $ccls
  cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$llvm/build/bin
  cmake --build Release
  symlink $ccls/Release/ccls $BIN/ccls
  
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
    cd -
  }

  _setup_lua_files
}

_setup_lua_files() {
  symlink $LIBS/LuaFormatter/lua-format $BIN/lua-format
}

install_bash() {
  echo "-Install beautysh-"
  pip install setuptools beautysh
}

# untested
# https://gist.github.com/kuntau/37698a5159ceac40982b1f7ae96b7db8#file-mosh-md
install_ssh_mosh_server() {
  can_sudo || { echo 'sshd needs root (system service, /etc/ssh, ufw)'; return 1; }
  echo '-Install ssh-'
  pkg_install ssh
  sudo sed -i 's/#Port 22/Port 22222/g' /etc/ssh/sshd_config

  echo '-Install mosh-'
  sudo apt install perl protobuf-compiler libprotobuf-dev \
    libncurses5-dev zlib1g-dev libutempter-dev libssl-dev \
    pkg-config autoconf

  cd $TMP && git clone --depth=1 https://github.com/mobile-shell/mosh.git
  cd $TMP/mosh && ./autogen.sh && ./configure && make && sudo make install && cd -

  # if you get protobuf issues
  # sudo find / -name "libprotobuf.so*"
  # make sure theres only 1 install and u rebuild with it

  # if mosh cant find it (shared module blabla), make sure it exists here
  # /usr/lib/x86_64-linux-gnu/libprotobuf.so.24.4.0

  echo '-Install fail2ban-'
  sudo apt install fail2ban
  # (config file /etc/fail2ban/jail.conf)
  sudo systemctl restart fail2ban
  sudo systemctl enable fail2ban
  # sudo systemctl status fail2ban

  echo '-Configure ufw-'
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  sudo ufw allow 22222
  sudo systemctl restart ssh

  sudo ufw allow 60000:60009/udp

  sudo ufw enable

  echo 'SSH & MOSH SERVER READY - double-check /etc/ssh/sshd_config & configure port forwarding'
}

# Claude Code status line (claude/statusline-command.sh) + its entry in ~/.claude/settings.json
install_claude() {
  echo '-Set up Claude Code status line-'
  _setup_claude_files
}

_setup_claude_files() {
  local dir=$HOME/.claude
  if ! [ -d $dir ]; then
    echo "[skip] $dir not found: install Claude Code and run 'claude' once, then rerun ./setup.sh (claude)"
    return 1
  fi

  local script=$dir/statusline-command.sh
  chmod +x $DOTFILES/claude/statusline-command.sh
  symlink $DOTFILES/claude/statusline-command.sh $script

  local settings=$dir/settings.json
  local cmd="bash $script"
  [ -s $settings ] || echo '{}' > $settings
  local tmp=$TMP/claude-settings.json
  if has jq; then
    jq --arg cmd "$cmd" '.statusLine = {type: "command", command: $cmd}' $settings > $tmp
  elif has python3; then
    python3 - "$settings" "$cmd" > $tmp <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
d["statusLine"] = {"type": "command", "command": sys.argv[2]}
print(json.dumps(d, indent=2))
PY
  else
    false
  fi
  if [ $? = 0 ] && [ -s $tmp ]; then
    # cat instead of mv keeps settings.json in place if it is itself a symlink
    cat $tmp > $settings && rm -f $tmp
    echo "statusLine set in $settings"
  else
    rm -f $tmp
    echo "Could not update $settings (needs jq or python3, and valid JSON). Add this yourself:"
    echo "  \"statusLine\": { \"type\": \"command\", \"command\": \"$cmd\" }"
    return 1
  fi
}

setup_all_files() {
  _setup_zsh_files
  _setup_dev_files
  _setup_nvim_files
  _setup_cpp_files
  _setup_lua_files
  _setup_claude_files
}

main() {
  clear
  echo 'OS:' "$OS $KERNEL ($ARCH)"
  can_sudo >/dev/null 2>&1 || echo 'No root/sudo: installing into ~/.local'
  echo

  local options=()
  options+=('zsh:       Install zsh, oh-my-zsh, p10k, fzf')
  options+=('fzf:       Install/update fzf')
  options+=('nvim:      Install neovim, ripgrep, tree-sitter')
  options+=('claude:    Set up Claude Code status line')
  options+=('dev:       Install base dev')
  options+=('asdf:      Install asdf')
  options+=('')
  options+=('ssh:       Install SSH key')
  options+=('gpg:       Install GPG key')
  options+=('sshd:      Setup SSH/mosh server')
  options+=('setupall:  Setup all files')
  options+=('git:       Add a git profile for a host')
  options+=('clip:      Install clipboard tool (xsel / wl-clipboard)')
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
    fzf) install_fzf ;;
    nvim) install_nvim ;;
    claude) install_claude ;;
    dev) install_dev ;;
    asdf) install_asdf ;;

    ssh) install_ssh_key ;;
    gpg) install_gpg_key ;;
    sshd) install_ssh_mosh_server ;;
    setupall) setup_all_files ;;
    git) add_git_profile ;;
    clip) install_clipboard ;;

    py) install_python ;;
    js) install_js ;;
    ex) install_elixir ;;
    cpp) install_cpp ;;
    lua) install_lua ;;
    sh) install_bash ;;
    [Qq]) exit 0 ;;
    *) echo "'${response}' isn't a valid option" ;;
  esac
}

main "$@"
