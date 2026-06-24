#!/usr/bin/env bash
# Total CPU load as a percentage, colored green → yellow → red by pressure. Dependency-free:
# parses macOS `top` (one sample). Fired on a fixed cycle (update_freq in sketchybarrc).
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

# `top -l 1` prints e.g. "CPU usage: 7.4% user, 12.1% sys, 80.5% idle"; load = 100 - idle.
# Compute it entirely in awk (no bc dependency); strip % then read the value before "idle".
LOAD="$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {gsub(/%/,""); for (i=1;i<=NF;i++) if ($i=="idle") printf "%d", 100-$(i-1)}')"
if [ -z "$LOAD" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

case "$LOAD" in
[0-9] | [1-4][0-9]) COLOR="$GREEN" ;;
[5-7][0-9]) COLOR="$YELLOW" ;;
*) COLOR="$RED" ;;
esac

# Color glyph + percentage together (single-accent pill, matching the tmux-style segments).
sketchybar --set "$NAME" drawing=on icon.color="$COLOR" label.color="$COLOR" label="${LOAD}%"
