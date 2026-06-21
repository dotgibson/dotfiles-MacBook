#!/usr/bin/env bash
# Highlights the focused AeroSpace workspace. Item name is "space.<id>"; the focused id arrives
# as $FOCUSED_WORKSPACE from the aerospace_workspace_change event (see sketchybarrc / aerospace.toml).
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

sid="${NAME#space.}"

if [ "$sid" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    background.color="$ACCENT" \
    label.color="$BAR_COLOR"
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    label.color="$GREY"
fi
