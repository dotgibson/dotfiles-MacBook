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

# ── Terminal & Shell ───────────────────────────────────────────────────────────
cask "ghostty"
brew "zsh"
brew "starship"
brew "zoxide"
brew "atuin"
brew "direnv"
brew "carapace"      # multi-shell completion engine (feeds fzf-tab in zsh; tools.zsh inits it)

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
brew "bottom"        # top  (binary: btm — kept; no alias points here)
brew "btop"          # top  (core aliases top/htop → btop expect this binary)
brew "procs"         # ps
brew "viddy"         # watch (core aliases watch → viddy; tools.zsh probes HAVE_VIDDY)
brew "sd"            # sed
brew "jq"            # JSON
brew "yq"            # YAML
brew "gron"          # greppable JSON (zsh helper expects it)
brew "xan"           # fast CSV slicing (maintained successor to the archived xsv)
brew "gnu-sed"       # GNU sed (`gsed`) — nvim-spectre + scripts expect it

# ── Network — HTTP & DNS ───────────────────────────────────────────────────────
brew "xh"            # HTTP client  (zsh aliases http/https → xh)
brew "doggo"         # DNS client   (zsh alias dns → doggo)
brew "gping"         # ping w/ graph (core alias ping → gping; tools.zsh probes HAVE_GPING)

# ── File management ────────────────────────────────────────────────────────────
brew "yazi"

# ── Editor & multiplexer ───────────────────────────────────────────────────────
brew "neovim"
brew "tmux"
brew "sesh"          # tmux session manager (prefix+f / Ctrl+G picker; tmux + fzf widgets use it)
brew "tree-sitter-cli"

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
brew "tealdeer"      # fast tldr client (core alias help → tldr; tools.zsh probes HAVE_TLDR)
brew "mas"           # Mac App Store CLI (os/macos.zsh adds masup/masls aliases)
brew "trash"         # send files to macOS Trash (os/macos.zsh aliases rm -> trash)

# ── 1Password ─────────────────────────────────────────────────────────────────
cask "1password"
cask "1password-cli"

# ── Fonts ─────────────────────────────────────────────────────────────────────
cask "font-caskaydia-cove-nerd-font"
cask "font-jetbrains-mono-nerd-font"
