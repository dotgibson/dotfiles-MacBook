# macOS Aliases Cheat Sheet

macOS-specific aliases from `os/macos.zsh`, layered on top of Core.
See `core/` for the full Core alias reference (modern CLI, git, safety nets).

> **Note:** On macOS the Core `rm='rm -i'` safety net is overridden by
> `rm='trash'` (if the `trash` CLI is installed), which moves files to the
> Trash instead of deleting them.

## macOS Specific

| Alias | Expands To |
|-------|------------|
| `localip` | `ipconfig getifaddr en0` (LAN IP on primary interface) |
| `flushdns` | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` |
| `showfiles` | Enable hidden files in Finder and relaunch |
| `hidefiles` | Disable hidden files in Finder and relaunch |
| `o` | `open` — `o .` opens the current directory in Finder |
| `dotsync` | `cd ~/dotfiles-MacBook` |

## Conditional (activated only when the tool is installed)

| Alias | Expands To | Requires |
|-------|-----------|----------|
| `rm` | `trash` (moves to macOS Trash) | `trash` CLI |
| `cheats` | `navi` (interactive cheat sheet) | navi |
| `masup` | `mas upgrade` (upgrade all App Store apps) | mas |
| `masls` | `mas list` (list installed App Store apps) | mas |
| `opsignin` | `eval "$(op signin)"` | 1Password CLI |

## Desktop Tooling

This repo also owns the macOS desktop layer. Key config locations:

| Tool | Config Path |
|------|------------|
| Aerospace (tiling WM) | `aerospace/` |
| Sketchybar (status bar) | `sketchybar/` |
| Karabiner (key remapping) | `karabiner/` |
| Ghostty (terminal) | `ghostty/` |
