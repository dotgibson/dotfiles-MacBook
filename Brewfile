# ════════════════════════════════════════════════════════════════════════════
# Brewfile — dotfiles-MacBook
# Apply with:  brew bundle --file=~/dotfiles-MacBook/Brewfile   (bootstrap.sh does this)
#
# Language runtimes (node, python, ruby, go, rust, java, lua) are NOT installed
# here — they're managed by mise (see core/mise/config.toml). mise's shims
# provide cargo/go/python/etc. on PATH.
#
# Offensive / pentest tooling intentionally does NOT live here — it lives in
# dotfiles-Kali. Keep this box a clean dev/security-engineering environment.
# ════════════════════════════════════════════════════════════════════════════

# ── Taps ──────────────────────────────────────────────────────────────────────
tap "homebrew/bundle"

# ── Terminal & Shell ───────────────────────────────────────────────────────────
cask "ghostty"
brew "zsh"
brew "starship"
brew "zoxide"
brew "atuin"
brew "direnv"
brew "stow"

# ── Runtime / tooling managers ─────────────────────────────────────────────────
brew "mise"                  # node/python/ruby/go/rust/java/lua — one manager
brew "pipx"                  # isolated installs for Python CLIs
brew "uv"                    # fast Python package/venv manager (Astral)

# ── Modern CLI replacements ────────────────────────────────────────────────────
brew "eza"           # ls
brew "bat"           # cat
brew "ripgrep"       # grep
brew "fd"            # find
brew "delta"         # git diff
brew "dust"          # du
brew "bottom"        # top
brew "procs"         # ps
brew "sd"            # sed
brew "jq"            # JSON
brew "yq"            # YAML
brew "xsv"           # fast CSV slicing
brew "gnu-sed"       # GNU sed (`gsed`) — nvim-spectre + scripts expect it

# ── File management ────────────────────────────────────────────────────────────
brew "yazi"

# ── Editor & multiplexer ───────────────────────────────────────────────────────
brew "neovim"
brew "tmux"

# ── Git ────────────────────────────────────────────────────────────────────────
brew "git"
brew "git-lfs"
brew "lazygit"
brew "gh"            # GitHub CLI
brew "git-absorb"    # smart commit absorb
brew "gnupg"         # commit signing
brew "pinentry-mac"  # GUI pinentry for gpg on macOS

# ── Productivity ──────────────────────────────────────────────────────────────
brew "fzf"
brew "gum"
brew "glow"          # markdown rendering

# ── 1Password ─────────────────────────────────────────────────────────────────
cask "1password"
cask "1password-cli"

# ── Fonts ─────────────────────────────────────────────────────────────────────
cask "font-caskaydia-cove-nerd-font"
cask "font-jetbrains-mono-nerd-font"

