# dotfiles-MacBook

macOS (Apple Silicon / Intel) terminal environment — the **OS-native layer** of a
nine-repo dotfiles system. The shared **Core** (zsh modules, tmux, Neovim, git,
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
git subtree add --prefix=core <your-remote>/dotfiles-core main --squash   # one-time
./bootstrap.sh                 # Homebrew + brew bundle + symlinks
exec zsh
./bootstrap.sh --macos-defaults   # optional: apply system prefs (may need logout)
```

Flags: `--links-only` (just symlinks), `--no-brew` (skip Homebrew/bundle),
`--macos-defaults` (also run `macos/defaults.sh`).

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
