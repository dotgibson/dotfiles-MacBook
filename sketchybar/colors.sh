#!/usr/bin/env bash
# ================================================================================================
# Palette for sketchybar — tokyonight-storm.
#
# GENERATED from dotfiles-core's theme/palette.toml (dotgibson/dotfiles-core#857). The block
# below is written by Core's scripts/gen-theme.sh: change a colour in the palette and run
# `make gen-theme` there, never edit these lines. Core's audit §9d fails on a hand-edit.
#
# Until #857 this file hand-authored the same eleven values and was kept in step with Core by
# the comment "matched to core/starship + core/tmux" — a sentence, not a gate, which is the
# construction dotfiles-core#693 and #682 exist to end.
#
# Format is 0xAARRGGBB — alpha FIRST. BAR_COLOR is deliberately translucent (0xee ≈ 93%) over
# the storm black; every other generated entry is fully opaque.
#
# What each name is for:
#   BAR_COLOR  bar background        BG       item background
#   FG         foreground / labels   ACCENT   blue — active highlight
#   ORANGE     weather + warm        GREY     comment grey — inactive / dim
# ================================================================================================

# core:theme:gen sketchybar-colors
export BAR_COLOR=0xee1d202f
export BG=0xff24283b
export FG=0xffc0caf5
export ACCENT=0xff7aa2f7
export GREEN=0xff9ece6a
export YELLOW=0xffe0af68
export RED=0xfff7768e
export MAGENTA=0xffbb9af7
export CYAN=0xff7dcfff
export ORANGE=0xffff9e64
export GREY=0xff565f89
# core:theme:end sketchybar-colors

# NOT generated, and it must stay outside the markers: transparency is the absence of a
# colour, not one of them, so there is no token in palette.toml it could be derived from.
export TRANSPARENT=0x00000000
