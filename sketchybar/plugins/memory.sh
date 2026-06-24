#!/usr/bin/env bash
# RAM pressure — percentage of memory in use, colored green→yellow→red by load. Reads macOS
# `memory_pressure` (no deps); pairs with the CPU widget as an at-a-glance system-load read.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

FREE="$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/ {gsub(/%/,"",$2); print $2; exit}')"
if [ -z "$FREE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi
USED=$((100 - FREE))

if [ "$USED" -lt 70 ]; then
  COLOR="$GREEN"
elif [ "$USED" -lt 88 ]; then
  COLOR="$YELLOW"
else
  COLOR="$RED"
fi

sketchybar --set "$NAME" drawing=on icon="󰍛" icon.color="$COLOR" label="${USED}%" label.color="$COLOR"
