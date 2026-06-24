#!/usr/bin/env bash
# Keep-awake toggle — a free Amphetamine. Click to start/stop `caffeinate -d`, which blocks
# display + system sleep; the icon reflects state (coffee = awake, moon = sleep allowed). No deps
# (caffeinate is built into macOS). Invoked two ways:
#   • script=        → render current state (on load + update_freq resync)
#   • click_script=  → "$0 toggle": flip the state, then render
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

if [ "${1:-}" = "toggle" ]; then
  if pgrep -x caffeinate >/dev/null 2>&1; then
    pkill -x caffeinate
  else
    nohup caffeinate -d >/dev/null 2>&1 &
    disown
  fi
fi

if pgrep -x caffeinate >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="󰅶" icon.color="$YELLOW"
else
  sketchybar --set "$NAME" icon="󰒲" icon.color="$GREY"
fi
