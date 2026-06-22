# CLAUDE.md — dotfiles-MacBook

Project memory for Claude Code, auto-loaded every session. For the shared Core
rules see `core/CLAUDE.md` and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-MacBook` is the **OS-native layer for macOS** in a ten-repo, three-layer
dotfiles fleet (Core → OS-native → Role → Showcase). It is its own lineage — built
directly on **Homebrew**, not stamped from the Fedora template — and also owns the
macOS desktop tooling (aerospace, sketchybar, karabiner, ghostty).

## The rule that bites

`core/` is a **vendored `git subtree` copy of [dotfiles-core](https://github.com/Gerrrt/dotfiles-core)** — *not*
editable here; changes under `core/` are overwritten on the next sync. Edit shared
Core config **in dotfiles-core**, `make audit`, then `make sync`.

macOS specifics:

- Packages live in the **`Brewfile`** (`brew bundle`), not `install/packages.txt`.
- Core targets macOS's stock **bash 3.2** in places — keep that in mind upstream.

## Where things are

- `Brewfile` — Homebrew package list
- `os/macos.zsh`, `os/macos.conf`, `os/macos.gitconfig` — OS overlays
- `aerospace/`, `sketchybar/`, `karabiner/`, `ghostty/` — macOS desktop tooling
- `bootstrap.sh`, `Makefile` — install + dev entry points
- `core/` — vendored Core (read-only here; edit upstream in dotfiles-core)
