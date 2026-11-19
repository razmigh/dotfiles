Inspired and based on https://github.com/tomkonidas/dotfiles

## Setup

Run `./setup.sh` and pick an option (`zsh`, `fzf`, `nvim`, `claude`, ...).
Tools that are already installed are skipped; `./setup.sh -u` upgrades them too.

No root needed: tools are installed under `~/.local` (binaries in `~/.local/bin`).
System packages (apt/dnf/yum) are only used when you are root or have passwordless sudo;
run `USE_SUDO=1 ./setup.sh` to allow a sudo password prompt.

`claude` links `claude/statusline-command.sh` to `~/.claude/` and sets `statusLine` in
`~/.claude/settings.json`. Run `claude` once first so `~/.claude` exists.
