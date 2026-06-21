#!/usr/bin/env bash
# Battery percentage + a charge-aware Nerd Font glyph, colored by level. Self-hides on desktop
# Macs (Mac mini / Studio / iMac) that report no battery.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

PERCENT="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ -z "$PERCENT" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ -n "$CHARGING" ]; then
  ICON="󰂄"
  COLOR="$GREEN"
else
  case "$PERCENT" in
  100 | 9[0-9]) ICON="󰁹" COLOR="$GREEN" ;;
  8[0-9] | 7[0-9] | 6[0-9]) ICON="󰂁" COLOR="$FG" ;;
  5[0-9] | 4[0-9] | 3[0-9]) ICON="󰁾" COLOR="$YELLOW" ;;
  2[0-9]) ICON="󰁻" COLOR="$YELLOW" ;;
  *) ICON="󰁺" COLOR="$RED" ;;
  esac
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" label="${PERCENT}%"
