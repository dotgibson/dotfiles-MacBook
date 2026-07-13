#!/usr/bin/env bash
# 25/5 work-break Pomodoro, the bash twin of Zebar's <Pomodoro/> widget. Left-click start/pause,
# right-click reset. State (mode/running/remaining/last-tick) persists in a $TMPDIR file and the
# countdown is driven by epoch deltas, so it stays accurate regardless of update_freq jitter.
# Colors: green = work, blue = break, grey = paused (matches the Zebar states). Invoked two ways:
#   • script=       → tick + render (on the update_freq cycle)
#   • click_script= → "$0 click": left = toggle run/pause, right = reset, then render.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

WORK=1500 # 25 min
BREAK=300 # 5 min
STATE="${TMPDIR:-/tmp}/sketchybar_pomodoro"

# Load state (mode running remaining last) or seed a fresh paused work session.
if [ -r "$STATE" ]; then
  read -r MODE RUNNING REMAINING LAST <"$STATE"
fi
[ -z "$MODE" ] && MODE="work"
[ -z "$RUNNING" ] && RUNNING=0
[ -z "$REMAINING" ] && REMAINING=$WORK
[ -z "$LAST" ] && LAST=0

NOW="$(date +%s)"

case "${1:-tick}" in
click)
  # sketchybar injects $BUTTON for click_script (left/right).
  if [ "${BUTTON:-left}" = "right" ]; then
    MODE="work"
    RUNNING=0
    REMAINING=$WORK
    LAST=0
  elif [ "$RUNNING" -eq 1 ]; then
    RUNNING=0
    LAST=0 # pause
  else
    RUNNING=1
    LAST=$NOW # start / resume
  fi
  ;;
*)
  # Normal tick: advance the countdown only while running.
  if [ "$RUNNING" -eq 1 ]; then
    if [ "$LAST" -gt 0 ]; then
      ELAPSED=$((NOW - LAST))
      [ "$ELAPSED" -lt 0 ] && ELAPSED=0
      REMAINING=$((REMAINING - ELAPSED))
    fi
    LAST=$NOW
    # Roll over across as many completed sessions as elapsed (usually one).
    while [ "$REMAINING" -le 0 ]; do
      if [ "$MODE" = "work" ]; then
        MODE="break"
        REMAINING=$((REMAINING + BREAK))
      else
        MODE="work"
        REMAINING=$((REMAINING + WORK))
      fi
    done
  fi
  ;;
esac

printf '%s %s %s %s\n' "$MODE" "$RUNNING" "$REMAINING" "$LAST" >"$STATE"

MM=$(printf '%02d' $((REMAINING / 60)))
SS=$(printf '%02d' $((REMAINING % 60)))
if [ "$RUNNING" -eq 0 ]; then
  COLOR="$GREY"
elif [ "$MODE" = "work" ]; then
  COLOR="$GREEN"
else
  COLOR="$ACCENT"
fi

sketchybar --set "$NAME" icon="󰔛" icon.color="$COLOR" label="${MM}:${SS}" label.color="$COLOR"
