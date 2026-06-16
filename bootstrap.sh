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
UNINSTALL=0
DRY=0
QUIET=0

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
  ./bootstrap.sh --uninstall      remove Core symlinks + restore backed-up files
  ./bootstrap.sh --dry-run, -n    print every planned action; change nothing
  ./bootstrap.sh --quiet, -q      show only CHANGES + the summary (quiet re-runs)
  ./bootstrap.sh -h, --help       show this help

Flags combine: `./bootstrap.sh --links-only --dry-run` previews the symlink
plan without touching your home directory. `--quiet` suppresses section headers
and the per-file "already linked" lines, so a re-run prints only what actually
changed — handy once you're set up and just re-syncing. `--uninstall --dry-run`
previews exactly what an uninstall would remove and restore, changing nothing.
EOF
}

# suggest <bad-flag> — print the nearest known flag as a "did you mean" hint, so a
# typo (`--dryrun`, `--link-only`) gets the same contextual nudge Core's verbs give
# via _core_suggest, instead of a bare usage dump. Heuristic, no external deps:
# compare HYPHEN-NORMALISED forms (so `--dryrun` ≈ `--dry-run`) and accept an exact
# match, a prefix either way, or a shared 4+ char stem. Silent when nothing's close.
KNOWN_FLAGS=(--links-only --no-brew --macos-defaults --set-shell --uninstall --dry-run -n --quiet -q -h --help)
suggest() {
  local in="${1#--}" f cand n=0
  [[ -z "$in" || "$in" == "$1" ]] && return 0 # only guess for --long typos
  in="${in//-/}"                              # normalise away hyphen placement (the usual slip)
  for f in "${KNOWN_FLAGS[@]}"; do
    [[ "$f" == --* ]] || continue
    cand="${f#--}"
    cand="${cand//-/}"
    # shared leading-char count between the two normalised stems
    n=0
    while [[ "${in:n:1}" == "${cand:n:1}" && -n "${in:n:1}" ]]; do n=$((n + 1)); done
    if [[ "$in" == "$cand" || "$in" == "$cand"* || "$cand" == "$in"* ]] || ((n >= 4)); then
      printf '%s' "$f"
      return 0
    fi
  done
}

for a in "$@"; do case "$a" in
  --links-only) LINKS_ONLY=1 ;;
  --no-brew) NO_BREW=1 ;;
  --macos-defaults) RUN_DEFAULTS=1 ;;
  --set-shell) SET_SHELL=1 ;;
  --uninstall) UNINSTALL=1 ;;
  --dry-run | -n) DRY=1 ;;
  --quiet | -q) QUIET=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown flag: $a" >&2
    s="$(suggest "$a")"
    [[ -n "$s" ]] && echo "did you mean $s?" >&2
    usage >&2
    exit 2 # usage error (the convention the lint scripts use; 1 stays for real failures)
    ;;
  esac done

# Palette + glyphs now come from the VENDORED shared bash UX lib (core/lib/ux.sh) — ONE
# definition across Core's bash layer instead of a hand-rolled copy here (B5). It's present
# after a Core sync; until then (or if it's ever absent) fall back to the inline copy below,
# which applies the SAME rule, so behaviour is byte-identical either way. Colour only on a
# real TTY with NO_COLOR unset; glyphs degrade to ASCII off a UTF-8 locale (a recovery boot
# / stripped SSH env would otherwise render the braille spinner + ✓/✗ as mojibake).
if [[ -r "$REPO/core/lib/ux.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/core/lib/ux.sh"
  c_b=$UX_BLU c_g=$UX_GRN c_y=$UX_YEL c_r=$UX_RED c_0=$UX_RST
  G_OK=$UX_OK G_INFO=$UX_INFO G_ERR=$UX_ERR SPIN_FRAMES=$UX_SPIN_FRAMES
else
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    c_b=$'\e[34m'
    c_g=$'\e[32m'
    c_y=$'\e[33m'
    c_r=$'\e[31m'
    c_0=$'\e[0m'
  else
    c_b='' c_g='' c_y='' c_r='' c_0=''
  fi
  # bash 3.2-safe lowercasing via `tr` (no ${x,,}); mirrors Core's ui.zsh/ux.sh.
  _lc="$(printf '%s' "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" | tr '[:upper:]' '[:lower:]')"
  case "$_lc" in
  *utf-8* | *utf8*) G_OK='✓' G_INFO='•' G_ERR='✗' SPIN_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' ;;
  *) G_OK='ok' G_INFO='-' G_ERR='x' SPIN_FRAMES='-\|/' ;;
  esac
fi
# Under --quiet, say() (section headers) and noop() (idempotent "already linked / present"
# confirmations) fall silent, so a re-run prints only the CHANGES (info: linked/backed
# up/seeded) + the summary. ok()/info()/err() — actual results, changes, and errors —
# always print. The summary (print_summary) prints unconditionally regardless of --quiet.
say() { ((QUIET)) || printf '%s==>%s %s\n' "$c_b" "$c_0" "$*"; }
ok() { printf '  %s%s%s %s\n' "$c_g" "$G_OK" "$c_0" "$*"; }
noop() { ((QUIET)) || ok "$@"; }
info() { printf '  %s%s%s %s\n' "$c_y" "$G_INFO" "$c_0" "$*"; }
err() { printf '  %s%s%s %s\n' "$c_r" "$G_ERR" "$c_0" "$*" >&2; }

# Run-summary counters. NB: bump with `n=$((n+1))`, never `((n++))` — under
# `set -e`, a standalone `((n++))` evaluates to the OLD value and, when that's 0,
# returns exit 1 and ABORTS the whole script. The assignment form is always 0.
n_linked=0
n_backed=0
n_skipped=0
n_seeded=0
n_removed=0  # --uninstall: Core symlinks removed
n_restored=0 # --uninstall: backups restored over the removed link

# print_summary — the run tally, factored out so the INT/TERM trap can show what was
# already done if you Ctrl-C mid-run (a long brew bundle, say). Without this, an
# interrupt left you with no record of the partial state and no reminder that re-running
# is safe. `$1` is an optional headline (e.g. "interrupted").
print_summary() {
  # Always prints (bypasses the --quiet say() gate via a direct printf) — the tally is
  # the whole point of a quiet run, so it must never be suppressed.
  printf '%s==>%s %s\n' "$c_b" "$c_0" "${1:-summary}"
  ok "$n_linked linked · $n_backed backed up · $n_seeded seeded · $n_skipped skipped"
}

# Graceful interrupt: report the partial run + reassure that bootstrap is idempotent
# (so the fix is simply to re-run), then exit 130 (128+SIGINT) — the conventional code.
on_interrupt() {
  printf '\n' >&2
  err "interrupted"
  print_summary "partial summary (interrupted)" >&2
  info "bootstrap is idempotent — re-run to finish where it left off" >&2
  exit 130
}
trap on_interrupt INT TERM

# run <cmd...> — execute, or (in --dry-run) just announce the mutation. For plain
# commands only; pipes/redirections are guarded inline at their call site instead.
run() {
  if ((DRY)); then
    info "would run: $*"
  else
    "$@"
  fi
}

# spin <label> <cmd...> — run an OPAQUE long step with a live spinner so the terminal
# reads as progress, not a hang. Output is captured and shown ONLY on failure (a clean
# run stays quiet; a broken one prints what went wrong). On a non-TTY (CI, piped) or in
# --dry-run there's no animation: it just runs the command with output passing through,
# so logs and the dry-run plan are unchanged. Returns the command's own exit status.
spin() {
  local label="$1"
  shift
  if ((DRY)); then
    info "would run: $*"
    return 0
  fi
  # No TTY (CI, piped) → run plainly, output passes through; then emit a scannable
  # done/failed marker so a log reads as discrete steps with outcomes, not a bare
  # "label…" with no resolution (the TTY path below ends each step with ✓/✗ too).
  if [[ ! -t 1 ]]; then
    info "$label…"
    # Run inside `||` so a non-zero exit can't trip `set -e` before we capture rc and emit
    # the marker — spin() may be called without an `|| handler` guard at the call site.
    local rc=0
    "$@" || rc=$?
    if ((rc == 0)); then ok "$label"; else err "$label — failed (exit $rc)"; fi
    return "$rc"
  fi
  local out rc
  out="$(mktemp -t bootstrap-spin.XXXXXX)" || {
    "$@"
    return $?
  }
  "$@" >"$out" 2>&1 &
  local pid=$! frames="$SPIN_FRAMES" i=0
  # A signal during a spin: FORWARD it to the child (so a child that only traps ^C actually
  # stops) and REAP with `wait` before handing off, so the work really halts instead of
  # lingering; then restore the cursor and hand off to the global handler (partial summary
  # + exit 130). We trap BOTH INT and TERM: the global trap handles TERM too, but it knows
  # nothing about $pid and never restores the cursor — so a SIGTERM mid-spin (e.g. CI
  # cancellation) would otherwise orphan the child and leave the cursor hidden. Mirrors
  # Core's ui.zsh _core_spin (SIGINT-forward + wait).
  trap 'kill -INT  "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; printf "\e[?25h"; on_interrupt' INT
  trap 'kill -TERM "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; printf "\e[?25h"; on_interrupt' TERM
  printf '\e[?25l' # hide cursor while spinning
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s%s%s %s' "$c_y" "${frames:i++%${#frames}:1}" "$c_0" "$label"
    sleep 0.1
  done
  printf '\e[?25h\r\033[K'   # restore cursor, return to col 0, clear the line
  trap on_interrupt INT TERM # re-arm the normal interrupt handlers
  if wait "$pid"; then
    rc=0
    ok "$label"
  else
    rc=$?
    err "$label — failed (exit $rc)"
    sed 's/^/    /' "$out" >&2 # indent the captured output under the failure
  fi
  rm -f "$out"
  return "$rc"
}

[[ "$(uname -s)" == "Darwin" || -n "${BOOTSTRAP_ALLOW_NON_DARWIN:-}" ]] || {
  err "this bootstrap is macOS-only"
  info "set BOOTSTRAP_ALLOW_NON_DARWIN=1 to preview the plan elsewhere (with --dry-run)"
  exit 1
}
# A normal clone already CONTAINS core/ (it's a tracked subtree), so this only fires
# when building the repo from scratch — say exactly what to run, don't just abort.
[[ -d "$REPO/core" ]] || {
  err "core/ subtree missing — this should be present in a clone; if building fresh, run:"
  info "git subtree add --prefix=core <dotfiles-core-url> main --squash"
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
    noop "${dest/#"$HOME"/\~} (already linked)"
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
    noop "${dest/#"$HOME"/\~} present (or example missing) — left as-is"
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
    # Up-front scope so the longest, mostly-opaque step reads as BOUNDED work, not an
    # open-ended hang: count the Brewfile entries (best-effort; falls back to "?" if the
    # list query fails) and name the number before handing off to brew's own streaming
    # output. `brew bundle list --all` enumerates every tap/brew/cask/mas line.
    local n_pkgs
    n_pkgs="$(brew bundle list --file="$REPO/Brewfile" --all 2>/dev/null | wc -l | tr -d ' ')"
    say "brew bundle (${n_pkgs:-?} formulae/casks — this can take a while)"
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
    noop "tpm present"
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

# ── uninstall: reverse the symlink wiring + restore backups (B4) ──────────────
# bootstrap backs a real file up to <dest>.pre-dotfiles.<ts> before linking, but there was
# no way BACK. This reverses it, idempotently and safely: it removes a dest ONLY when it's a
# symlink pointing INTO this repo (never a real file or a foreign link), then restores the
# most recent .pre-dotfiles.* backup if one exists. --dry-run previews every action. It does
# NOT uninstall Homebrew/packages or revert the login shell — just the symlinks this script
# created (the destructive, hard-to-remember half).
unlink_dest() { # unlink_dest <dest>
  local dest="$1"
  if [[ -L "$dest" ]]; then
    local tgt
    tgt="$(readlink "$dest")"
    if [[ "$tgt" == "$REPO"/* ]]; then
      if ((DRY)); then
        info "would remove symlink: ${dest/#"$HOME"/\~}"
      else
        rm -f "$dest"
        ok "removed ${dest/#"$HOME"/\~}"
      fi
      n_removed=$((n_removed + 1))
    else
      noop "skip (not ours): ${dest/#"$HOME"/\~}"
      return 0
    fi
  fi
  # Never restore a backup OVER an existing real file/dir. We only restore into a slot we
  # just emptied (our symlink was removed above) or one that's now absent — if a REAL file
  # sits at $dest, it's the user's own (they may have replaced our link with it), so leave
  # it untouched rather than clobber it with a stale backup. (In --dry-run our symlink isn't
  # actually removed, so $dest is still a symlink here and this guard correctly lets the
  # restore PREVIEW through.)
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    noop "skip restore (real file present, not ours): ${dest/#"$HOME"/\~}"
    return 0
  fi
  # Restore the most recent backup, if any. The backup suffix is a zero-padded
  # YYYYMMDD-HHMMSS stamp, so a lexical sort IS chronological — the LAST glob match is the
  # newest. nullglob makes a no-match yield an empty array (not the literal pattern).
  local newest=""
  local -a baks
  shopt -s nullglob
  baks=("$dest".pre-dotfiles.*)
  shopt -u nullglob
  ((${#baks[@]})) && newest="${baks[${#baks[@]} - 1]}"
  if [[ -n "$newest" && -e "$newest" ]]; then
    if ((DRY)); then
      info "would restore backup: ${newest/#"$HOME"/\~} → ${dest/#"$HOME"/\~}"
    else
      mv "$newest" "$dest"
      info "restored ${dest/#"$HOME"/\~} from backup"
    fi
    n_restored=$((n_restored + 1))
  fi
}
uninstall() {
  local CFG="$HOME/.config"
  say "Uninstall — removing Core symlinks + restoring backups (Homebrew/packages untouched)"
  ((DRY)) && say "DRY RUN — nothing will be changed; printing the plan only"
  # The same destinations wire_links creates — the per-module Core zsh links plus the
  # fixed set. Kept in one list here so an uninstall mirrors the install exactly.
  local -a dests=(
    "$HOME/.local/bin/clip" "$HOME/.local/bin/clip-paste"
    "$CFG/zsh/os.zsh" "$HOME/.zshenv" "$CFG/zsh/.zprofile" "$CFG/zsh/.zshrc"
    "$CFG/starship.toml"
    "$CFG/tmux/tmux.conf" "$CFG/tmux/tmux.reset.conf" "$CFG/tmux/scripts" "$CFG/tmux/os.conf"
    "$CFG/nvim"
    "$HOME/.gitconfig" "$CFG/git/os.gitconfig" "$CFG/git/ignore"
    "$CFG/mise/config.toml" "$CFG/ghostty/config" "$HOME/.ssh/config"
  )
  local f
  for f in "$REPO"/core/zsh/*.zsh; do dests+=("$CFG/zsh/$(basename "$f")"); done
  local d
  for d in "${dests[@]}"; do unlink_dest "$d"; done
  printf '%s==>%s %s\n' "$c_b" "$c_0" "uninstall summary"
  ok "$n_removed removed · $n_restored restored"
  ((DRY)) && info "dry run — nothing was changed; re-run without --dry-run to apply"
  info "left in place: Homebrew + packages, your login shell, and ~/.config/{zsh/local.zsh,git/local.gitconfig}"
}

# --uninstall short-circuits the whole install path (it's the reverse operation).
if ((UNINSTALL)); then
  uninstall
  exit 0
fi

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

# mise tools — install behind a spinner: it can churn for a while pulling runtimes,
# and its raw output is noise unless it fails (spin shows the captured log only then).
if command -v mise >/dev/null 2>&1; then
  say "mise install"
  spin "installing mise-managed tools" mise install ||
    info "mise install hit an issue — run it manually later"
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
print_summary "summary"
if ((DRY)); then
  info "dry run — nothing above was actually changed; re-run without --dry-run to apply"
else
  ok "macOS bootstrap complete — open a new shell or: exec zsh"
fi
