#!/usr/bin/env bash
# dotfiles-MacBook/bootstrap.sh
# ──────────────────────────────────────────────────────────────────────────────
# Idempotent macOS provision + symlink wiring. Safe to re-run.
#
#   ./bootstrap.sh                 # full: Homebrew + brew bundle + symlinks
#   ./bootstrap.sh --links-only    # just (re)create symlinks, no installs
#   ./bootstrap.sh --no-brew       # symlinks + mise, skip Homebrew/brew bundle
#   ./bootstrap.sh --macos-defaults# also run macos/defaults.sh (system prefs)
#
# This repo vendors Core under core/ (git subtree). bootstrap symlinks the Core
# files + the macOS os/ layer into ~/.config and ~. Your identity lives in
# ~/.config/git/local.gitconfig (never tracked); machine-only shell tweaks in
# ~/.config/zsh/local.zsh (never tracked).
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINKS_ONLY=0
NO_BREW=0
RUN_DEFAULTS=0
for a in "$@"; do case "$a" in
    --links-only) LINKS_ONLY=1 ;;
    --no-brew) NO_BREW=1 ;;
    --macos-defaults) RUN_DEFAULTS=1 ;;
    -h | --help)
        sed -n '2,18p' "$0"
        exit 0
        ;;
    *)
        echo "unknown flag: $a" >&2
        exit 1
        ;;
    esac done

c_b=$'\e[34m'
c_g=$'\e[32m'
c_y=$'\e[33m'
c_r=$'\e[31m'
c_0=$'\e[0m'
say() { printf '%s==>%s %s\n' "$c_b" "$c_0" "$*"; }
ok() { printf '  %s✓%s %s\n' "$c_g" "$c_0" "$*"; }
info() { printf '  %s•%s %s\n' "$c_y" "$c_0" "$*"; }
err() { printf '  %s✗%s %s\n' "$c_r" "$c_0" "$*" >&2; }

[[ "$(uname -s)" == "Darwin" ]] || {
    err "this bootstrap is macOS-only"
    exit 1
}
[[ -d "$REPO/core" ]] || {
    err "core/ subtree missing — run: git subtree add --prefix=core <dotfiles-core-url> main --squash"
    exit 1
}

# ── link helper: back up a real file once, then symlink ──────────────────────
link() { # link <src> <dest>
    local src="$1" dest="$2"
    [[ -e "$src" ]] || {
        info "skip (missing): ${src#$REPO/}"
        return 0
    }
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" ]]; then
        rm -f "$dest"
    elif [[ -e "$dest" ]]; then
        mv "$dest" "$dest.pre-dotfiles.$(date +%Y%m%d-%H%M%S)"
        info "backed up existing $dest"
    fi
    ln -s "$src" "$dest"
    ok "${dest/#$HOME/~}"
}

# ── provision (Homebrew + packages) ──────────────────────────────────────────
provision() {
    if ! xcode-select -p >/dev/null 2>&1; then
        say "Xcode Command Line Tools"
        xcode-select --install 2>/dev/null || true
        info "finish the CLT GUI installer if it popped up, then re-run"
    fi
    if ! command -v brew >/dev/null 2>&1; then
        say "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # put brew on PATH for the rest of this run (Apple Silicon, then Intel)
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    if [[ "$NO_BREW" == 0 && -f "$REPO/Brewfile" ]]; then
        say "brew bundle (this can take a while)"
        brew bundle --file="$REPO/Brewfile"
    else
        info "skipping brew bundle (--no-brew or no Brewfile yet)"
    fi
}

# ── symlinks ──────────────────────────────────────────────────────────────────
wire_links() {
    local CFG="$HOME/.config"
    say "Core helper scripts -> ~/.local/bin"
    link "$REPO/core/bin/clip" "$HOME/.local/bin/clip"
    link "$REPO/core/bin/clip-paste" "$HOME/.local/bin/clip-paste"
    chmod +x "$REPO/core/bin/clip" "$REPO/core/bin/clip-paste" 2>/dev/null || true

    say "zsh modules"
    for f in "$REPO"/core/zsh/*.zsh; do link "$f" "$CFG/zsh/$(basename "$f")"; done
    link "$REPO/os/macos.zsh" "$CFG/zsh/os.zsh" # the macOS interactive layer
    # entry layer (ZDOTDIR model): ~/.zshenv sets ZDOTDIR; .zprofile/.zshrc live in $ZDOTDIR
    link "$REPO/zsh/zshenv" "$HOME/.zshenv"
    link "$REPO/zsh/zprofile" "$CFG/zsh/.zprofile"
    link "$REPO/zsh/zshrc" "$CFG/zsh/.zshrc"

    say "starship"
    link "$REPO/core/starship/starship.toml" "$CFG/starship.toml" # starship's default path

    say "tmux"
    link "$REPO/core/tmux/tmux.conf" "$CFG/tmux/tmux.conf"
    # FIX: tmux.conf's first line `source-file ~/.config/tmux/tmux.reset.conf` needs
    # this link to exist. Without it, tmux errors on every start AND the prefix
    # (set -g prefix C-a, which lives in reset.conf) silently stays at the default
    # C-b — i.e. "prefix not working". This link was the missing piece.
    link "$REPO/core/tmux/tmux.reset.conf" "$CFG/tmux/tmux.reset.conf"
    link "$REPO/core/tmux/scripts" "$CFG/tmux/scripts"          # popup + status scripts
    chmod +x "$REPO"/core/tmux/scripts/*.sh 2>/dev/null || true # ensure they're runnable
    link "$REPO/os/macos.conf" "$CFG/tmux/os.conf"              # @status_right_os bits (sourced by tmux.conf)
    # tmux plugin manager (tpm) — clone once so the theme + resurrect/continuum
    # load on first run. Plugins still need one install pass after tmux starts:
    # `prefix+I` inside tmux, or headless: ~/.config/tmux/plugins/tpm/bin/install_plugins
    local TPM_DIR="$CFG/tmux/plugins/tpm"
    if [[ ! -d "$TPM_DIR" ]]; then
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR" &&
            ok "tpm cloned" ||
            info "tpm clone failed — clone it manually, then run prefix+I in tmux"
    else
        ok "tpm present"
    fi

    say "neovim"
    link "$REPO/core/nvim" "$CFG/nvim"

    say "git"
    link "$REPO/core/git/gitconfig" "$HOME/.gitconfig"
    link "$REPO/os/macos.gitconfig" "$CFG/git/os.gitconfig"
    link "$REPO/os/macos.gitignore" "$CFG/git/ignore"
    if [[ ! -e "$CFG/git/local.gitconfig" ]]; then
        mkdir -p "$CFG/git"
        cp "$REPO/core/git/local.gitconfig.example" "$CFG/git/local.gitconfig"
        info "seeded ~/.config/git/local.gitconfig — set your name/email there (never tracked)"
    fi

    say "mise"
    link "$REPO/core/mise/config.toml" "$CFG/mise/config.toml"

    say "sesh"
    # seed (don't symlink) the portable sesh config; engagement layouts live in Kali.
    if [[ -f "$REPO/core/sesh/sesh.toml.example" && ! -e "$CFG/sesh/sesh.toml" ]]; then
        mkdir -p "$CFG/sesh"
        cp "$REPO/core/sesh/sesh.toml.example" "$CFG/sesh/sesh.toml"
        info "seeded ~/.config/sesh/sesh.toml (edit freely; not tracked from here)"
    else
        ok "sesh.toml present (or example missing)"
    fi

    say "ghostty"
    link "$REPO/ghostty/config" "$CFG/ghostty/config"

    say "ssh"
    if [[ -f "$REPO/ssh/config" ]]; then
        link "$REPO/ssh/config" "$HOME/.ssh/config"
        chmod 600 "$REPO/ssh/config" 2>/dev/null || true
        # ssh/config uses ControlMaster with ControlPath ~/.ssh/sockets/%r@%h:%p, but ssh won't
        # create that socket directory itself — without it the first connection fails with
        # "ControlPath ... cannot create: No such file or directory" and multiplexing silently
        # never works. Create it (700; control sockets must not be group/world-accessible).
        mkdir -p "$HOME/.ssh/sockets"
        chmod 700 "$HOME/.ssh/sockets" 2>/dev/null || true
    else
        info "no ssh/config in repo yet — skipping"
    fi
}

((LINKS_ONLY)) || provision
wire_links

# mise tools
if command -v mise >/dev/null 2>&1; then
    say "mise install"
    mise install || info "mise install hit an issue — run it manually later"
fi

# macОS system defaults (opt-in: changes system prefs, may need logout)
if ((RUN_DEFAULTS)) && [[ -f "$REPO/macos/defaults.sh" ]]; then
    say "macos/defaults.sh"
    bash "$REPO/macos/defaults.sh" || info "defaults.sh hit an issue"
elif [[ -f "$REPO/macos/defaults.sh" ]]; then
    info "system defaults available — apply with: ./bootstrap.sh --macos-defaults  (or: bash macos/defaults.sh)"
fi

ok "macOS bootstrap complete — open a new shell or: exec zsh"
