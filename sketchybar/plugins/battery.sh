#!/usr/bin/env bash
# Battery percentage + a charge-aware Nerd Font glyph, colored by level. Self-hides on desktop
# Macs (Mac mini / Studio / iMac) that report no battery.
#
# Kept in lockstep with the tmux status bar (core/tmux/scripts/tmux-battery.sh): same three-tier
# thresholds (>=60 green / >=20 yellow / <20 red), same glyphs (󰂁/󰁾/󰁻, charging 󰂄 keeping the
# level color), so a given charge looks identical in both bars.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

PERCENT="$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ -z "$PERCENT" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Color + glyph by level (numeric compare, matching tmux-battery.sh).
if [ "$PERCENT" -ge 60 ]; then
  COLOR="$GREEN"
  ICON="󰂁"
elif [ "$PERCENT" -ge 20 ]; then
  COLOR="$YELLOW"
  ICON="󰁾"
else
  COLOR="$RED"
  ICON="󰁻"
fi

# Charging swaps only the glyph; the level color carries through (as in tmux).
[ -n "$CHARGING" ] && ICON="󰂄"

# Color both the glyph and the percentage, like the tmux pill's single-accent text.
sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" label="${PERCENT}%" label.color="$COLOR"
