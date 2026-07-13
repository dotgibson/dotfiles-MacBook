#!/usr/bin/env bash
# Battery charge + charging state, colored by level (green >40 / yellow 21-40 / red <=20), with a
# fa-battery fill glyph that mirrors Zebar's getBatteryIcon. When charging, show the power-plug bolt
# in the accent color instead. Dependency-free (`pmset`). Shown here for parity with Zebar even
# though the tmux status bar also carries battery (see PARITY.md).
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

BATT="$(pmset -g batt 2>/dev/null)"
PCT="$(printf '%s' "$BATT" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
if [ -z "$PCT" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# "AC Power" + "charging"/"charged" ⇒ on the charger. "Battery Power" ⇒ discharging.
CHARGING=0
case "$BATT" in
*"AC Power"*) CHARGING=1 ;;
esac

if [ "$CHARGING" -eq 1 ]; then
  # Power-plug bolt (nf-md-power_plug), accent blue — matches Zebar's charging indicator.
  sketchybar --set "$NAME" drawing=on icon="󰚥" icon.color="$ACCENT" label="${PCT}%" label.color="$ACCENT"
  exit 0
fi

# Discharging: fill glyph + threshold color (fa-battery-4..0, same set Zebar uses).
if [ "$PCT" -gt 90 ]; then
  ICON=""
elif [ "$PCT" -gt 70 ]; then
  ICON=""
elif [ "$PCT" -gt 40 ]; then
  ICON=""
elif [ "$PCT" -gt 20 ]; then
  ICON=""
else
  ICON=""
fi

if [ "$PCT" -gt 40 ]; then
  COLOR="$GREEN"
elif [ "$PCT" -gt 20 ]; then
  COLOR="$YELLOW"
else
  COLOR="$RED"
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COLOR" label="${PCT}%" label.color="$COLOR"
