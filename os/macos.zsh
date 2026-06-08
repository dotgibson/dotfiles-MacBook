# dotfiles-MacBook/os/macos.zsh  →  ~/.config/zsh/os.zsh
# ──────────────────────────────────────────────────────────────────────────────
# macOS-only INTERACTIVE shell extras. Sourced near the end of .zshrc (after the
# Core modules), so it can override Core. PATH/env that must exist in every shell
# lives in .zprofile/.zshenv, not here. Nothing offensive here — that's Kali.
# ──────────────────────────────────────────────────────────────────────────────

# Native clipboard already works: Core's `clip`/`clip-paste` detect Darwin and
# shell out to pbcopy/pbpaste, so no aliases are needed here.

# ── tool completions (Homebrew-installed CLIs that ship zsh completions) ─────
# direnv must hook live (it injects a precmd that varies per dir). gh/uv/ty emit
# deterministic completion scripts, so cache them via Core's _cache_eval (from
# tools.zsh) — one cheap `source` instead of spawning the generator every shell.
# _cache_eval self-guards on the binary being present and regenerates only when
# the binary is newer than the cache.
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
if (( $+functions[_cache_eval] )); then
  _cache_eval gh gh completion -s zsh
  _cache_eval uv uv generate-shell-completion zsh
  _cache_eval ty ty generate-shell-completion zsh
else  # bare fallback if os.zsh is sourced without Core's tools.zsh
  command -v gh >/dev/null 2>&1 && eval "$(gh completion -s zsh 2>/dev/null)"
  command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion zsh 2>/dev/null)"
  command -v ty >/dev/null 2>&1 && eval "$(ty generate-shell-completion zsh 2>/dev/null)"
fi

# ── macOS conveniences ────────────────────────────────────────────────────────
alias localip='ipconfig getifaddr en0'                 # LAN IP on the primary interface
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias showfiles='defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder'
alias o='open'                                          # `o .` to open in Finder

# trash(1): send files to macOS Trash instead of permanently deleting them.
# Overrides the Core `rm='rm -i'` safety net with something even safer.
# `rm -f` / `command rm` still bypass this when you need the real thing.
command -v trash >/dev/null 2>&1 && alias rm='trash'

# mas: Mac App Store CLI convenience helpers
command -v mas >/dev/null 2>&1 && {
  alias masup='mas upgrade'                            # upgrade all App Store apps
  alias masls='mas list'                               # list installed App Store apps
}

# ── dotfiles maintenance: jump to this repo ──────────────────────────────────
alias dotsync='cd "$HOME/dotfiles-MacBook"'

# ── 1Password CLI sign-in convenience (op.zsh in Core has the helpers) ───────
command -v op >/dev/null 2>&1 && alias opsignin='eval "$(op signin)"'

# ── auto-start/attach tmux for interactive terminals ─────────────────────────
# Skip inside an existing tmux, VS Code's integrated terminal, and non-TTYs.
if command -v tmux >/dev/null 2>&1 \
   && [[ -z "$TMUX" && -t 1 && "$TERM_PROGRAM" != "vscode" ]]; then
  tmux attach -t main 2>/dev/null || tmux new-session -s main
fi
