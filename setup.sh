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

# -u: also upgrade tools that are already installed (otherwise they are skipped)
UPGRADE=0
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

# Command provided by a package, to tell whether it is already installed.
pkg_cmd() {
  case "$1" in
    build-essential) echo gcc ;;
    procps) echo ps ;;
    ripgrep) echo rg ;;
    neovim) echo nvim ;;
    gnupg) echo gpg ;;
    golang) echo go ;;
    inotify-tools) echo inotifywait ;;
    wl-clipboard) echo wl-copy ;;
    ssh) echo sshd ;;
    tree-sitter-cli) echo tree-sitter ;;
    ninja-build) echo ninja ;;
    *) echo "$1" ;;
  esac
}

# 0 when command $1 should be installed: it is missing, or -u was given.
need_cmd() {
  has "$1" || return 0
  [ $UPGRADE = 1 ] && return 0
  echo "$1 already installed ($(command -v "$1")), skipping (-u to upgrade)"
  return 1
}

is_local() { case "$(command -v "$1")" in $BIN/*) return 0 ;; esac; return 1; }

# How to install/upgrade a tool we can also download into ~/.local: skip, pkg or local.
# A system copy is only upgraded through its package manager, never shadowed by a download.
# $2=local: download even when root is available (newer than distro packages).
install_method() {
  if ! need_cmd "$1" >&2; then echo skip
  elif is_local "$1"; then echo local
  elif has "$1" || [ "$OS" = "$OS_MAC" ]; then echo pkg
  elif [ "$2" != local ] && can_sudo; then echo pkg
  else echo local
  fi
}

# Install packages with brew (macOS) or apt/dnf/yum (Linux, needs root); already installed ones
# are skipped unless -u. Returns 1 when skipped for lack of root.
pkg_install() {
  local pkgs=() pkg
  for pkg in "$@"; do
    need_cmd "$(pkg_cmd $pkg)" && pkgs+=("$pkg")
  done
  [ ${#pkgs[@]} = 0 ] && return 0

  if [ "$OS" = "$OS_MAC" ]; then
    ensure_brew && brew install "${pkgs[@]}"
    return
  fi
  if ! can_sudo; then
    echo "[skip] no root, install yourself if needed: ${pkgs[*]}"
    return 1
  fi
  local sudo=sudo pm
  [ "$(id -u)" = 0 ] && sudo=
  for pm in apt-get dnf yum; do
    has $pm && break
  done
  has $pm || { echo "[skip] no apt/dnf/yum, install yourself: ${pkgs[*]}"; return 1; }
  for pkg in "${pkgs[@]}"; do
    # apt-get install upgrades an installed package, dnf/yum need upgrade
    if [ $pm != apt-get ] && has "$(pkg_cmd $pkg)"; then
      $sudo $pm upgrade -y "$pkg"
    else
      $sudo $pm install -y "$pkg"
    fi
  done
}

# Clone a repo if missing, pull it with -u. Returns 1 when skipped.
git_get() {
  local url=$1 dir=$2
  shift 2
  if ! [ -d "$dir" ]; then
    git clone "$@" "$url" "$dir"
  elif [ $UPGRADE = 1 ]; then
    git -C "$dir" pull --ff-only
  else
    echo "$(basename "$dir") already installed, skipping (-u to upgrade)"
    return 1
  fi
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
  local method=$(install_method zsh)
  # fall back to a download only when there is no zsh at all
  [ "$method" = pkg ] && { pkg_install zsh || has zsh || method=local; }
  # static build (romkatv/zsh-bin) in ~/.local, no root needed
  [ "$method" = local ] &&
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" -- -q -d ~/.local -e no
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
  if ! [ -d ~/.oh-my-zsh ]; then
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    git_get https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  fi

  echo '-Download fonts for powerlevel10k-'
  mkdir -pv $FONTS_FOLDER
  local font
  for font in Regular Bold Italic 'Bold Italic'; do
    [ -f "$FONTS_FOLDER/MesloLGS NF $font.ttf" ] && [ $UPGRADE = 0 ] && continue
    curl -fsSL -o "$FONTS_FOLDER/MesloLGS NF $font.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${font// /%20}.ttf"
  done
  has fc-cache && fc-cache -f $FONTS_FOLDER

  echo '-Download powerlevel10k-'
  git_get https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k --depth=1

  install_fzf

  _setup_zsh_files
}

install_fzf() {
  echo "-Install fzf-"
  # .zshrc uses this clone's binary and key bindings, so a system fzf doesn't count
  if git_get https://github.com/junegunn/fzf.git $LIBS/fzf --depth 1 || ! [ -x $LIBS/fzf/bin/fzf ]; then
    # --bin: only fetch the binary; .zshrc sources the shell integration from this clone
    $LIBS/fzf/install --bin
  fi
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
  pkg_install mosh tmux tmuxp tree

  echo '-Install direnv-'
  local method=$(install_method direnv)
  [ "$method" = pkg ] && { pkg_install direnv || has direnv || method=local; }
  [ "$method" = local ] && curl -fsSL https://direnv.net/install.sh | bin_path=$BIN bash

  install_go

  install_asdf

  install_clipboard

  _setup_dev_files

  echo -e "\nInstall docker yourself: https://docs.docker.com/engine/install/"
}

install_go() {
  echo '-Install go-'
  case "$(install_method go local)" in
    skip) return ;;
    pkg) pkg_install golang; return ;;
  esac
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
  if [ $UPGRADE = 0 ] && { has xsel || has xclip || has wl-copy; }; then
    echo 'Clipboard tool already installed, skipping (-u to upgrade)'
    return
  fi
  local method=$(install_method $(pkg_cmd $pkg))
  if [ "$method" = pkg ]; then
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
  case "$(install_method asdf local)" in
    skip) return ;;
    pkg) pkg_install asdf; return ;;
  esac
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
  install_nvim_bin

  install_ripgrep

  _setup_nvim_files

  install_tree_sitter

  echo "-Install Packer-"
  rm -f ~/.config/nvim/plugin/packer_compiled.lua
  local packer=~/.local/share/nvim/site/pack/packer/start/packer.nvim
  # packer updates itself during PackerSync
  [ -d $packer ] || git clone --depth 1 https://github.com/wbthomason/packer.nvim $packer

  echo "-Run PackerSync-"
  nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'; echo

  echo "-Run TSUpdate-"
  if has cc || has gcc || has clang || has zig; then
    nvim --headless -c 'TSUpdate' -c q; echo
  else
    echo "[skip] no C compiler for treesitter parsers (install gcc, then :TSUpdate)"
  fi
}

# Official prebuilt release on Linux; built from source in ~/.local if it can't run here (old glibc).
install_nvim_bin() {
  case "$(install_method nvim local)" in
    skip) return ;;
    pkg) pkg_install neovim; return ;;
  esac
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
}

install_tree_sitter() {
  echo '-Install tree-sitter-cli for latex-'
  case "$(install_method tree-sitter local)" in
    skip) return ;;
    pkg) pkg_install tree-sitter-cli; return ;;
  esac
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
}

# ripgrep is used by telescope; static musl build on Linux when there is no root
install_ripgrep() {
  echo "-Install ripgrep-"
  case "$(install_method rg)" in
    skip) return ;;
    # download only when there is no rg at all (and the release assets below are for Linux)
    pkg) pkg_install ripgrep || has rg || [ "$OS" = "$OS_MAC" ] && return ;;
  esac
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

  need_cmd elixir-ls || return 0
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
  pkg_install gnupg || has gpg || return 1

  echo "Generate key. (default-RSA & RSA, 4096, default-0)"
  gpg --full-generate-key
  gpg --list-secret-keys --keyid-format=long
  echo "Enter the ID after/under sec (8B42896FC8EC43CD)"
  read -r id

  echo "Here is generated key for your to put where needed (github etc)"
  gpg --armor --export "$id"
}

install_cpp() {
  install_cmake
  install_ninja
  # cmake picks this up for the llvm source build below
  has ninja && export CMAKE_GENERATOR=Ninja
  if [ "$OS" = "$OS_MAC" ]; then
    pkg_install llvm
  else
    install_llvm
  fi
  _setup_cpp_files
}

# Kitware's prebuilt release (runs on old glibc); distro cmake can be too old for llvm.
install_cmake() {
  echo '-Install cmake-'
  case "$(install_method cmake local)" in
    skip) return ;;
    pkg) pkg_install cmake; return ;;
  esac
  local tag=$(gh_latest_tag Kitware/CMake) arch=x86_64
  [ "$(release_arch)" = arm64 ] && arch=aarch64
  local name=cmake-${tag#v}-linux-$arch cmake=$LIBS/cmake
  (
    cd $TMP &&
    curl -fL https://github.com/Kitware/CMake/releases/download/$tag/$name.tar.gz | tar -xz &&
    rm -rf $cmake && mv $name $cmake
  ) || return 1
  local b
  for b in cmake ctest cpack; do
    symlink $cmake/bin/$b $BIN/$b
  done
}

# Single static binary from the release.
install_ninja() {
  echo '-Install ninja-'
  case "$(install_method ninja local)" in
    skip) return ;;
    pkg) pkg_install "$([ "$OS" = "$OS_MAC" ] && echo ninja || echo ninja-build)"; return ;;
  esac
  local name=ninja-linux
  [ "$(release_arch)" = arm64 ] && name=ninja-linux-aarch64
  curl -fL -o $TMP/ninja.zip https://github.com/ninja-build/ninja/releases/latest/download/$name.zip &&
  { unzip -oq $TMP/ninja.zip -d $TMP 2>/dev/null || python3 -m zipfile -e $TMP/ninja.zip $TMP; } &&
  chmod +x $TMP/ninja && mv -f $TMP/ninja $BIN/ninja
  rm -f $TMP/ninja.zip
}

# Prebuilt llvm release (clang, clangd, clang-format) in ~/.local;
# builds the release source there instead if the prebuilt can't run here (old glibc).
install_llvm() {
  echo '-Install llvm-'
  local llvm=$LIBS/llvm
  if [ -x $llvm/bin/clang ] && [ $UPGRADE = 0 ]; then
    echo "llvm already installed ($llvm), skipping (-u to upgrade)"
    return
  fi
  local tag=$(gh_latest_tag llvm/llvm-project)
  local ver=${tag#llvmorg-} url=https://github.com/llvm/llvm-project/releases/download/$tag
  local arch=X64 new=$llvm.new src=$LIBS/llvm-src
  [ "$(release_arch)" = arm64 ] && arch=ARM64

  rm -rf $new && mkdir -p $new
  if ! { llvm_prebuilt_ok && curl -fL $url/LLVM-$ver-Linux-$arch.tar.xz | tar -xJ --strip-components=1 -C $new &&
         $new/bin/clang --version >/dev/null 2>&1; }; then
    echo "prebuilt llvm $ver can't run here, building it from source (takes a while)"
    rm -rf $new $src && mkdir -p $src
    curl -fL $url/llvm-project-$ver.src.tar.xz | tar -xJ --strip-components=1 -C $src &&
    cmake -S $src/llvm -B $src/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$new \
      -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" -DLLVM_TARGETS_TO_BUILD=host -DLLVM_PARALLEL_LINK_JOBS=2 &&
    cmake --build $src/build -j "$(nproc)" && cmake --install $src/build || return 1
    rm -rf $src
  fi
  rm -rf $llvm && mv $new $llvm

  # never shadow a system copy
  local b
  for b in clang clang++ clangd clang-format; do
    has $b && ! is_local $b || symlink $llvm/bin/$b $BIN/$b
  done
}

# Release binaries need gcc 12+ libstdc++ (GLIBCXX_3.4.30, e.g. not RHEL 9): saves a 2GB download.
llvm_prebuilt_ok() {
  local so=$(ldconfig -p 2>/dev/null | grep -E 'libstdc\+\+\.so\.6 .*(x86-64|AArch64)' | sed 's/.*=> //' | head -1)
  [ -z "$so" ] || grep -qa GLIBCXX_3.4.30 "$so"
}

_setup_cpp_files() {
  mkdir -pv $HOME/.config/clangd
  symlink $DOTFILES/cpp/config.yaml $HOME/.config/clangd/config.yaml
}

install_lua() {
  echo "-Install LuaFormatter-"
  local lua_fmt=$LIBS/LuaFormatter
  if need_cmd lua-format; then
    rm -rf $lua_fmt
    git clone --recurse-submodules https://github.com/Koihik/LuaFormatter.git $lua_fmt
    cd $lua_fmt && {
      cmake .
      make
      cd -
    }
  fi

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
  local opt
  while getopts u opt; do
    case $opt in
      u) UPGRADE=1 ;;
      *) echo "Usage: $0 [-u]  (-u: also upgrade already installed tools)"; exit 1 ;;
    esac
  done

  clear
  echo 'OS:' "$OS $KERNEL ($ARCH)"
  can_sudo >/dev/null 2>&1 || echo 'No root/sudo: installing into ~/.local'
  if [ $UPGRADE = 1 ]; then
    echo 'Upgrade mode: installed tools are upgraded'
  else
    echo 'Installed tools are skipped (-u to upgrade)'
  fi
  echo

  local options=()
  options+=('zsh:       zsh, oh-my-zsh, p10k, fzf')
  options+=('dev:       go, asdf, direnv, tmux, git config')
  options+=('fzf:       fzf + key bindings')
  options+=('nvim:      neovim, ripgrep, plugins')
  options+=('ssh:       new SSH key')
  options+=('git:       git identity for a host')
  options+=('clip:      clipboard tool (xsel)')
  options+=('setupall:  re-link config files only')
  options+=('')
  options+=('claude:    Claude Code status line')
  options+=('asdf:      asdf version manager')
  options+=('gpg:       new GPG key')
  options+=('')
  options+=('js:        node + LSPs, prettierd')
  options+=('py:        python + LSP')
  options+=('cpp:       cmake, ninja, llvm/clang')
  options+=('ex:        elixir, erlang, elixir-ls')
  options+=('lua:       lua-format')
  options+=('sh:        beautysh formatter')
  options+=('')
  options+=('sshd:      SSH/mosh server (root)')

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
    fzf) install_fzf ;;
    nvim) install_nvim ;;
    ssh) install_ssh_key ;;
    git) add_git_profile ;;
    clip) install_clipboard ;;
    setupall) setup_all_files ;;

    claude) install_claude ;;
    asdf) install_asdf ;;
    gpg) install_gpg_key ;;

    js) install_js ;;
    py) install_python ;;
    cpp) install_cpp ;;
    ex) install_elixir ;;
    lua) install_lua ;;
    sh) install_bash ;;

    sshd) install_ssh_mosh_server ;;
    [Qq]) exit 0 ;;
    *) echo "'${response}' isn't a valid option" ;;
  esac
}

main "$@"
