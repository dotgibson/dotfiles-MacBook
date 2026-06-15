#!/usr/bin/env bash
# dotfiles-MacBook/bootstrap.sh
# ──────────────────────────────────────────────────────────────────────────────
# Idempotent macOS provision + symlink wiring. Safe to re-run.
#
#   ./bootstrap.sh                  # full: Homebrew + brew bundle + symlinks
#   ./bootstrap.sh --links-only     # just (re)create symlinks, no installs
#   ./bootstrap.sh --no-brew        # symlinks + mise, skip Homebrew/brew bundle
#   ./bootstrap.sh --macos-defaults # also run macos/defaults.sh (system prefs)
#   ./bootstrap.sh --set-shell      # make Homebrew zsh the login shell (chsh)
#   ./bootstrap.sh --dry-run        # print every planned action; change nothing
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
SET_SHELL=0
DRY=0

# usage() is a real function (heredoc) rather than `sed -n '2,18p' "$0"`: the old
# form was coupled to header line numbers, so editing the banner silently drifted
# `--help`. This stays correct no matter how the file above moves.
usage() {
  cat <<'EOF'
bootstrap.sh — idempotent macOS provision + symlink wiring. Safe to re-run.

  ./bootstrap.sh                  full: Homebrew + brew bundle + symlinks
  ./bootstrap.sh --links-only     just (re)create symlinks, no installs
  ./bootstrap.sh --no-brew        symlinks + mise, skip Homebrew/brew bundle
  ./bootstrap.sh --macos-defaults also run macos/defaults.sh (system prefs)
  ./bootstrap.sh --set-shell      make Homebrew zsh the login shell (chsh)
  ./bootstrap.sh --dry-run, -n    print every planned action; change nothing
  ./bootstrap.sh -h, --help       show this help

Flags combine: `./bootstrap.sh --links-only --dry-run` previews the symlink
plan without touching your home directory.
EOF
}

for a in "$@"; do case "$a" in
  --links-only) LINKS_ONLY=1 ;;
  --no-brew) NO_BREW=1 ;;
  --macos-defaults) RUN_DEFAULTS=1 ;;
  --set-shell) SET_SHELL=1 ;;
  --dry-run | -n) DRY=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown flag: $a" >&2
    usage >&2
    exit 2 # usage error (the convention the lint scripts use; 1 stays for real failures)
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

# Run-summary counters. NB: bump with `n=$((n+1))`, never `((n++))` — under
# `set -e`, a standalone `((n++))` evaluates to the OLD value and, when that's 0,
# returns exit 1 and ABORTS the whole script. The assignment form is always 0.
n_linked=0
n_backed=0
n_skipped=0
n_seeded=0

# run <cmd...> — execute, or (in --dry-run) just announce the mutation. For plain
# commands only; pipes/redirections are guarded inline at their call site instead.
run() {
  if ((DRY)); then
    info "would run: $*"
  else
    "$@"
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || {
  err "this bootstrap is macOS-only"
  exit 1
}
[[ -d "$REPO/core" ]] || {
  err "core/ subtree missing — run: git subtree add --prefix=core <dotfiles-core-url> main --squash"
  exit 1
}

((DRY)) && say "DRY RUN — no changes will be made; printing the plan only"

# ── link helper: back up a real file once, then symlink ──────────────────────
link() { # link <src> <dest>
  local src="$1" dest="$2"
  [[ -e "$src" ]] || {
    info "skip (missing): ${src#"$REPO"/}"
    n_skipped=$((n_skipped + 1))
    return 0
  }
  # Idempotent fast path: already the correct symlink → report and move on. Makes
  # a re-run (and a --dry-run) honest about what's actually already wired.
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    ok "${dest/#"$HOME"/\~} (already linked)"
    n_linked=$((n_linked + 1))
    return 0
  fi
  if ((DRY)); then
    if [[ -L "$dest" ]]; then
      info "would relink: ${dest/#"$HOME"/\~} → ${src#"$REPO"/}"
    elif [[ -e "$dest" ]]; then
      info "would back up real file, then link: ${dest/#"$HOME"/\~}"
      n_backed=$((n_backed + 1))
    else
      info "would link: ${dest/#"$HOME"/\~} → ${src#"$REPO"/}"
    fi
    n_linked=$((n_linked + 1))
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles.$(date +%Y%m%d-%H%M%S)"
    info "backed up existing $dest"
    n_backed=$((n_backed + 1))
  fi
  ln -s "$src" "$dest"
  ok "${dest/#"$HOME"/\~}"
  n_linked=$((n_linked + 1))
}

# seed <src> <dest> <note> — copy (don't symlink) a starter file when the dest is
# absent. Used for files the user is meant to EDIT locally (git identity, sesh).
seed() {
  local src="$1" dest="$2" note="$3"
  [[ -f "$src" && ! -e "$dest" ]] || {
    ok "${dest/#"$HOME"/\~} present (or example missing) — left as-is"
    return 0
  }
  if ((DRY)); then
    info "would seed: ${dest/#"$HOME"/\~}  ($note)"
    n_seeded=$((n_seeded + 1))
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  info "seeded ${dest/#"$HOME"/\~} — $note"
  n_seeded=$((n_seeded + 1))
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
  if ((!NO_BREW)) && [[ -f "$REPO/Brewfile" ]]; then
    say "brew bundle (this can take a while)"
    brew bundle --file="$REPO/Brewfile"
  else
    info "skipping brew bundle (--no-brew or no Brewfile yet)"
  fi
}

# verify_tools — after a provision, confirm the headline tools actually landed on
# PATH so a half-finished bundle is reported, not silently assumed-good. Read-only.
verify_tools() {
  local missing=() t
  for t in zsh starship mise fzf nvim tmux git; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if ((${#missing[@]})); then
    info "not yet on PATH: ${missing[*]} — open a new shell, or re-run after brew bundle finishes"
  else
    ok "core tools present (zsh starship mise fzf nvim tmux git)"
  fi
}

# set_login_shell — opt-in (--set-shell). Make the Homebrew zsh the login shell,
# idempotently: skip if it's already $SHELL, and only append to /etc/shells if the
# path isn't already listed (chsh refuses a shell that isn't in there).
set_login_shell() {
  local brew_zsh=""
  if [[ -x /opt/homebrew/bin/zsh ]]; then
    brew_zsh=/opt/homebrew/bin/zsh
  elif [[ -x /usr/local/bin/zsh ]]; then
    brew_zsh=/usr/local/bin/zsh
  fi
  [[ -n "$brew_zsh" ]] || {
    info "Homebrew zsh not found — skipping login-shell change (run brew bundle first)"
    return 0
  }
  if [[ "${SHELL:-}" == "$brew_zsh" ]]; then
    ok "login shell already $brew_zsh"
    return 0
  fi
  say "login shell → $brew_zsh"
  if ((DRY)); then
    info "would add $brew_zsh to /etc/shells (if absent), then: chsh -s $brew_zsh"
    return 0
  fi
  grep -qxF "$brew_zsh" /etc/shells 2>/dev/null || echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
  if chsh -s "$brew_zsh"; then
    ok "login shell set — open a new terminal to use it"
  else
    info "chsh failed — set it manually: chsh -s $brew_zsh"
  fi
}

# ── symlinks ──────────────────────────────────────────────────────────────────
wire_links() {
  local CFG="$HOME/.config"
  say "Core helper scripts -> ~/.local/bin"
  link "$REPO/core/bin/clip" "$HOME/.local/bin/clip"
  link "$REPO/core/bin/clip-paste" "$HOME/.local/bin/clip-paste"
  run chmod +x "$REPO/core/bin/clip" "$REPO/core/bin/clip-paste"

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
  link "$REPO/core/tmux/scripts" "$CFG/tmux/scripts" # popup + status scripts
  run chmod +x "$REPO"/core/tmux/scripts/*.sh        # ensure they're runnable
  link "$REPO/os/macos.conf" "$CFG/tmux/os.conf"     # @status_right_os bits (sourced by tmux.conf)
  # tmux plugin manager (tpm) — clone once so the theme + resurrect/continuum
  # load on first run. Plugins still need one install pass after tmux starts:
  # `prefix+I` inside tmux, or headless: ~/.config/tmux/plugins/tpm/bin/install_plugins
  local TPM_DIR="$CFG/tmux/plugins/tpm"
  if [[ ! -d "$TPM_DIR" ]]; then
    if ((DRY)); then
      info "would clone tpm → ${TPM_DIR/#"$HOME"/\~}"
    # if/then/else (not A && B || C): a failed `ok` must not trigger the clone-failed note
    elif git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
      ok "tpm cloned"
    else
      info "tpm clone failed — clone it manually, then run prefix+I in tmux"
    fi
  else
    ok "tpm present"
  fi

  say "neovim"
  link "$REPO/core/nvim" "$CFG/nvim"

  say "git"
  link "$REPO/core/git/gitconfig" "$HOME/.gitconfig"
  link "$REPO/os/macos.gitconfig" "$CFG/git/os.gitconfig"
  link "$REPO/os/macos.gitignore" "$CFG/git/ignore"
  seed "$REPO/core/git/local.gitconfig.example" "$CFG/git/local.gitconfig" \
    "set your name/email there (never tracked)"

  say "mise"
  link "$REPO/core/mise/config.toml" "$CFG/mise/config.toml"

  say "sesh"
  # seed (don't symlink) the portable sesh config; engagement layouts live in Kali.
  seed "$REPO/core/sesh/sesh.toml.example" "$CFG/sesh/sesh.toml" \
    "edit freely; not tracked from here"

  say "ghostty"
  link "$REPO/ghostty/config" "$CFG/ghostty/config"

  say "ssh"
  if [[ -f "$REPO/ssh/config" ]]; then
    link "$REPO/ssh/config" "$HOME/.ssh/config"
    run chmod 600 "$REPO/ssh/config"
    # ssh/config uses ControlMaster with ControlPath ~/.ssh/sockets/%r@%h:%p, but ssh won't
    # create that socket directory itself — without it the first connection fails with
    # "ControlPath ... cannot create: No such file or directory" and multiplexing silently
    # never works. Create it (700; control sockets must not be group/world-accessible).
    run mkdir -p "$HOME/.ssh/sockets"
    run chmod 700 "$HOME/.ssh/sockets"
  else
    info "no ssh/config in repo yet — skipping"
  fi
}

# ── provision (unless --links-only); dry-run announces but installs nothing ──
if ((LINKS_ONLY)); then
  : # symlinks only
elif ((DRY)); then
  say "would provision: Homebrew + brew bundle (skipped in dry-run)"
else
  provision
  verify_tools
fi

wire_links

# mise tools
if command -v mise >/dev/null 2>&1; then
  say "mise install"
  if ((DRY)); then
    info "would run: mise install"
  else
    mise install || info "mise install hit an issue — run it manually later"
  fi
fi

# login shell (opt-in: changes your default shell)
((SET_SHELL)) && set_login_shell

# macOS system defaults (opt-in: changes system prefs, may need logout)
if ((RUN_DEFAULTS)) && [[ -f "$REPO/macos/defaults.sh" ]]; then
  say "macos/defaults.sh"
  if ((DRY)); then
    info "would run: bash macos/defaults.sh (pass --dry-run to preview its keys)"
  else
    bash "$REPO/macos/defaults.sh" || info "defaults.sh hit an issue"
  fi
elif [[ -f "$REPO/macos/defaults.sh" ]]; then
  info "system defaults available — apply with: ./bootstrap.sh --macos-defaults  (or: bash macos/defaults.sh)"
fi

# ── run summary ───────────────────────────────────────────────────────────────
say "summary"
ok "$n_linked linked · $n_backed backed up · $n_seeded seeded · $n_skipped skipped"
if ((DRY)); then
  info "dry run — nothing above was actually changed; re-run without --dry-run to apply"
else
  ok "macOS bootstrap complete — open a new shell or: exec zsh"
fi
