#!/usr/bin/env bash
# Highlights the focused AeroSpace workspace. Item name is "space.<id>"; the focused id arrives
# as $FOCUSED_WORKSPACE from the aerospace_workspace_change event (see sketchybarrc / aerospace.toml).
# The --animate prefix eases the color swap so the highlight slides between numbers.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

sid="${NAME#space.}"

if [ "$sid" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --animate sin 15 --set "$NAME" \
    background.drawing=on \
    background.color="$ACCENT" \
    label.color="$BAR_COLOR"
else
  sketchybar --animate sin 15 --set "$NAME" \
    background.drawing=off \
    label.color="$GREY"
fi
