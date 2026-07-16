# dotfiles-MacBook/os/macos.zsh  →  ~/.config/zsh/os.zsh
# ──────────────────────────────────────────────────────────────────────────────
# macOS-only INTERACTIVE shell extras. Sourced near the end of .zshrc (after the
# Core modules), so it can override Core. PATH/env that must exist in every shell
# lives in .zprofile/.zshenv, not here. Nothing offensive here — that's Kali.
# ──────────────────────────────────────────────────────────────────────────────

# Native clipboard already works: Core's `clip`/`clip-paste` detect Darwin and
# shell out to pbcopy/pbpaste, so no aliases are needed here.

# ── tool completions (Homebrew-installed CLIs that ship zsh completions) ─────
# direnv/gh/uv/ty all emit DETERMINISTIC scripts: `direnv hook zsh` installs a precmd
# whose per-directory behavior runs at RUNTIME, but the generated hook TEXT is static
# for a given binary — exactly like mise/zoxide in tools.zsh, which Core already caches.
# So route all four through Core's _cache_eval (from tools.zsh) — one cheap `source`
# instead of spawning each generator every shell. _cache_eval self-guards on the binary
# being present and regenerates only when the binary is newer than the cache.
if (( $+functions[_cache_eval] )); then
  _cache_eval direnv direnv hook zsh
  _cache_eval gh gh completion -s zsh
  _cache_eval uv uv generate-shell-completion zsh
  _cache_eval ty ty generate-shell-completion zsh
else  # bare fallback if os.zsh is sourced without Core's tools.zsh
  command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh 2>/dev/null)"
  command -v gh >/dev/null 2>&1 && eval "$(gh completion -s zsh 2>/dev/null)"
  command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion zsh 2>/dev/null)"
  command -v ty >/dev/null 2>&1 && eval "$(ty generate-shell-completion zsh 2>/dev/null)"
fi

# ── repo-owned completions (bootstrap.sh) ─────────────────────────────────────
# Core adds its completions dir to fpath BEFORE compinit (options.zsh), so compinit
# auto-registers them. This macOS layer loads AFTER compinit, so add the repo's
# completions dir to fpath and then explicitly autoload + compdef — compinit won't
# re-scan fpath on its own. Resolve the dir relative to THIS file: %x = the sourced
# path, :A follows the bootstrap symlink back to <repo>/os/macos.zsh, :h:h climbs to
# the repo root, then /completions (the proven pattern from Core's options.zsh).
_macos_compdir="${${(%):-%x}:A:h:h}/completions"
if [[ -d "$_macos_compdir" ]] && (($+functions[compdef])); then
  fpath=("$_macos_compdir" $fpath)
  autoload -Uz _bootstrap 2>/dev/null && compdef _bootstrap bootstrap.sh ./bootstrap.sh
fi
unset _macos_compdir

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

# navi: interactive, fzf-driven cheatsheets. Complements tealdeer (`help`, static
# man-style) with runnable, arg-templated snippets. Bound to its OWN verb `cheats`
# (plural) so it does NOT shadow Core's `cheat` alias → `core-help`: the first-run
# welcome banner and `core-doctor` both point users at `core-help`, so keeping
# `cheat` resolving there avoids a confusing collision. `cheats` launches navi.
# (No Ctrl-G widget — that key is owned by sesh in Core's bindings.zsh.)
command -v navi >/dev/null 2>&1 && alias cheats='navi'

# croc / onefetch are invoked directly (no alias): `croc send <file>` to ship a
# file e2e-encrypted to another box; `onefetch` in a repo for an at-a-glance summary.

# fastfetch: system/host banner (config: fastfetch/config.jsonc, themed to match
# the rice). Short `ff` verb — the host-info twin of `onefetch`'s repo summary.
command -v fastfetch >/dev/null 2>&1 && alias ff='fastfetch'

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
# Skip inside an existing tmux, VS Code's integrated terminal, non-TTYs, and when
# DOTFILES_NO_AUTOTMUX is set (export it in ~/.config/zsh/local.zsh to opt out on a
# given box). `exec` REPLACES this login shell with tmux, so detaching exits the
# terminal cleanly instead of dropping you back into a bare, tmux-less login shell
# (the old non-exec form left a confusing second shell behind). `new-session -A`
# attaches to the target session if it exists, else creates it — one exec-safe
# command, so the old `attach || new-session` fallback (which `exec` would have
# broken, since exec replaces the shell before the `||` could run) is no longer
# needed.
#
# Session NAME is a knob: DOTFILES_TMUX_SESSION (default `main`). Set it in
# ~/.config/zsh/local.zsh to pin the session this attaches to — e.g. when
# tmux-continuum (@continuum-restore in core/tmux/tmux.conf) restores a session under a
# different name, matching the name here lets `-A` attach to that restored session
# instead of spawning a second `main` alongside it.
if command -v tmux >/dev/null 2>&1 \
  && [[ -z "$TMUX" && -t 1 && "$TERM_PROGRAM" != "vscode" && -z "${DOTFILES_NO_AUTOTMUX:-}" ]]; then
  exec tmux new-session -A -s "${DOTFILES_TMUX_SESSION:-main}"
fi
