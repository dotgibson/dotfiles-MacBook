# 🍎 dotfiles-MacBook

**macOS, tiled and keyboard-driven.** The macOS layer — Homebrew, AeroSpace
tiling, and desktop tooling over the shared core.

`brew` · `aerospace` · `zsh` · `nvim`

[![showcase](https://img.shields.io/badge/showcase-live-7aa2f7?style=flat-square)](https://gerrrt.github.io/dotfiles-web/) ![macOS](https://img.shields.io/badge/macOS-ready-7aa2f7?style=flat-square)

---

macOS (Apple Silicon / Intel) terminal environment — the **OS-native layer** of a
ten-repo dotfiles system. The shared **Core** (zsh modules, tmux, Neovim, git,
mise, starship, clipboard) is vendored under `core/` as a git subtree from
[`dotfiles-core`](../dotfiles-core); this repo adds only what is specific to macOS.

> Identity of the _operator_ lives in Core. Identity of the _machine_ lives here.
> Offensive/engagement tooling lives in `dotfiles-Kali` — not here.

## Layout

```
bootstrap.sh        Homebrew + brew bundle + symlink wiring (idempotent)
Brewfile            macOS packages (CLI + casks + fonts)        ← you provide
core/               vendored Core subtree (do not edit here; edit dotfiles-core)
os/
  macos.zsh         interactive shell extras  → ~/.config/zsh/os.zsh
  macos.gitconfig   osxkeychain + excludes + gpg → ~/.config/git/os.gitconfig
  macos.gitignore   global git excludes        → ~/.config/git/ignore
  macos.conf        tmux en0 + battery bits     → ~/.config/tmux/os.conf
zsh/
  zshenv            → ~/.zshenv   (sets ZDOTDIR + XDG + universal env)
  zprofile          → ~/.config/zsh/.zprofile  (Homebrew, juliaup, 1Password agent)
  zshrc             → ~/.config/zsh/.zshrc      (history + completion + the loader)
macos/
  defaults.sh       `defaults write` system prefs (opt-in)       ← you provide
ghostty/
  config            Ghostty terminal config    → ~/.config/ghostty/config
ssh/
  config            SSH client config (keys never tracked)       ← you provide
```

## Install (fresh Mac)

```bash
git clone <your-remote>/dotfiles-MacBook ~/dotfiles-MacBook
cd ~/dotfiles-MacBook
# core/ is a vendored subtree and is ALREADY present in a clone — no extra step.
# (You only run `git subtree add --prefix=core …` when building this repo from scratch.)
./bootstrap.sh --links-only --dry-run   # preview the symlink plan (changes nothing)
./bootstrap.sh                 # Homebrew + brew bundle + symlinks
exec zsh
./bootstrap.sh --macos-defaults   # optional: apply system prefs (may need logout)
```

Flags: `--dry-run`/`-n` (print every planned action, change nothing),
`--links-only` (just symlinks), `--no-brew` (skip Homebrew/bundle),
`--set-shell` (make the Homebrew zsh your login shell), `--macos-defaults`
(also run `macos/defaults.sh`; that script takes its own `--dry-run` too).

## How the shell loads

`~/.zshenv` sets `ZDOTDIR=~/.config/zsh`, so the rest of zsh lives there.
`.zprofile` (login) sets Homebrew/PATH; `.zshrc` (interactive) sources the Core
modules + the macOS layer + your local overrides, in order:

```
tools → options → history → aliases → git → functions → fzf → bindings
      → plugins → op → maint → update → os → local
```

`options.zsh` owns `compinit` + setopts and `history.zsh` owns history config
(both run before `plugins.zsh`). `tools…update` are Core; `os` is
`os/macos.zsh`; `local` is your untracked `~/.config/zsh/local.zsh`. The order
is load-bearing — see the comments in `zshrc`.

## Updating Core

Edit in `dotfiles-core`, then from there run `./bin/sync-core.sh`, or here:

```bash
git subtree pull --prefix=core <your-remote>/dotfiles-core main --squash
./bootstrap.sh --links-only
```

## macOS specifics worth knowing

- **Homebrew** lives at `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel);
  `.zprofile` handles both.
- **Clipboard** is native — Core's `clip`/`clip-paste` shell out to `pbcopy`/`pbpaste`.
- **1Password SSH agent** — `.zprofile` points `SSH_AUTH_SOCK` at the 1Password
  socket; comment it out if you don't use it.
- **Credentials** — git uses the macOS keychain via `osxkeychain`.

## Development

Static analysis is the test suite here — dotfiles can't really be unit-tested, so
shellcheck + shfmt + `bash -n` are what guard every change. The same commands run
locally and in CI:

```bash
brew bundle            # installs the lint toolchain (see Brewfile "Dev: lint & format")
make lint              # shellcheck + shfmt -d + bash -n + zsh -n   (what CI gates)
make test-repo         # behavioral tests for THIS repo (bootstrap, zsh loader, defaults)
make test              # vendored Core load-order + function tests (needs zsh)
make test-all          # both of the above
make fmt               # auto-format repo-owned bash in place
make help              # list all targets (bootstrap, doctor, sync-core, …)
pre-commit install     # optional: run the same gate at commit time
```

`make test-repo` (in `test/test-repo.sh`) is hermetic and runs anywhere: it exercises
`bootstrap.sh` (arg-parse, did-you-mean, dry-run no-op, output hygiene), the
`zsh/zshrc` loader (sources in canonical order — not just `zsh -n`), the macOS
completion wiring, and `macos/defaults.sh`. Every mutation is sandboxed; no real
provision ever runs.

The repo-owned **zsh** modules (`zsh/zshenv`, `zsh/zprofile`, `zsh/zshrc`,
`os/macos.zsh`) have no `.sh` extension, so they're gated separately by
`make zsh-syntax` (`zsh -n`), folded into `make lint`.

- **CI** — `.github/workflows/ci.yml` runs the `shell lint` job
  (`make {shellcheck,fmt-check,syntax,zsh-syntax,test-repo}`), a `core regression` job
  (`make test`), a `macos smoke` job (clipboard round-trip, Brewfile parse, real-Darwin
  bootstrap/defaults dry-run, `make test-repo`), and `actionlint`. Triggers are
  de-duplicated (`push` on `main`/tags, `pull_request` elsewhere; docs-only changes skip
  the shell suite) and superseded runs cancel (`concurrency`). **All** linters —
  shellcheck, shfmt, actionlint — are version-pinned and cached. `pre-commit` mirrors
  every gate locally.
- **Reproducible installs** — the committed `Brewfile` is the source of truth (Homebrew
  6.x removed `Brewfile.lock.json`, so there's no lockfile to pin hashes). `make
  brew-check` verifies every entry is installed on a provisioned machine; the `macos
  smoke` job validates the `Brewfile` parses (`brew bundle list --all`).
- **Style** — repo-owned bash is 2-space (`shfmt -i 2`); `.editorconfig` is the
  source of truth and `shfmt`/editors both read it.
- **Scope** — `core/` is a vendored git-subtree from
  [`dotfiles-core`](../dotfiles-core); the lint targets and pre-commit hooks
  **exclude** it on purpose. Editing it here would diverge the subtree, so its
  Lua/shell is linted in _that_ repo's CI. `make core-advisory` surfaces any
  `core/` findings locally without gating.

### Upstream (`core/`) follow-ups

These were found during audit but belong to `dotfiles-core` (fix there, then
`git subtree pull` / `sync-core.sh` brings them down — don't hand-edit `core/`):

- `core/tmux/scripts/tmux-scratch.sh` — shebang is `#!/bin/bash`; every other
  script uses `#!/usr/bin/env bash`.
- `core/tmux/scripts/tmux-sessionizer.sh` — superseded by `tmux-sesh.sh` (per
  `core.manifest`); it's dead and should be removed upstream.
- `core/maint/dotfiles-maint.sh` — ShellCheck SC2015 (`A && B || C`) and SC2016.
- `core/tmux/scripts/tmux-menu.sh` — ShellCheck SC2016.
