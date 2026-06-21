#!/usr/bin/env bash
# Output volume + a speaker glyph scaled to the level. Fired by the volume_change event, which
# delivers the new percentage in $INFO.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

VOLUME="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)}"

case "$VOLUME" in
'') ICON="󰖁" ;;
0) ICON="󰖁" ;;
[1-9] | [1-3][0-9]) ICON="󰕿" ;;
[4-6][0-9]) ICON="󰖀" ;;
*) ICON="󰕾" ;;
esac

sketchybar --set "$NAME" icon="$ICON" icon.color="$CYAN" label="${VOLUME}%"
