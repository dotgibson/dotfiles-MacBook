# CLAUDE.md — dotfiles-MacBook

Project memory for Claude Code, auto-loaded every session. For the shared Core
rules (the load order, the "is it Core?" test, the manifest contract) see
`core/README.md` and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-MacBook` is the **OS-native layer for macOS** in a **ten-repo dotfiles system** built on a three-layer
model (Core → OS-native → Role). Its own lineage — built directly on **Homebrew**, not stamped from the Fedora template — and it also owns the macOS desktop tooling (aerospace, sketchybar, karabiner, ghostty). Packages live in the **`Brewfile`** (`brew bundle`), not `install/packages.txt`; Core targets macOS's stock **bash 3.2** in places.

## The rule that bites

`core/` is a **vendored `git subtree` copy of [dotfiles-core](https://github.com/dotgibson/dotfiles-core)** — it
is *not* editable here. Anything you change under `core/` is overwritten on the
next sync. To change shared Core config, edit it **in dotfiles-core**, run
`make audit` there, then `make sync` to fan it out to every OS repo.

What belongs **here** is only the OS-native layer: the `Brewfile`, OS overlays, desktop tooling, and the bootstrap.

## Where things are

- `Brewfile` — Homebrew package list
- `zsh/zshenv`, `zsh/zprofile`, `zsh/zshrc` — the loader entry points (symlinked to `~/.zshenv`/`~/.config/zsh/`)
- `os/macos.zsh`, `os/macos.conf`, `os/macos.gitconfig` — OS overlays
- `macos/defaults.sh` — `defaults write` system-preferences script (`bootstrap.sh --macos-defaults`)
- `aerospace/`, `sketchybar/`, `karabiner/`, `ghostty/` — macOS desktop tooling
- `completions/` — shell completion files
- `bootstrap.sh`, `Makefile` — install + dev entry points
- `core/` — vendored Core (read-only here; edit upstream in dotfiles-core)
