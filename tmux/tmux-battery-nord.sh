#!/usr/bin/env bash
# tmux-battery-nord.sh — local Nord copy of Core's battery pill.
# The vendored core/tmux/scripts/tmux-battery.sh hardcodes Everforest colours;
# os/macos.conf calls this one instead. Logic is otherwise identical.

set -u

BGDA="#2e3440"
GREEN="#a3be8c"
YELLOW="#ebcb8b"
RED="#bf616a"
CAP_L=""
CAP_R=""

pct=""
state=""

if command -v pmset >/dev/null 2>&1; then
  read -r pct state < <(pmset -g batt | awk '
        /InternalBattery/ {
            for (i = 1; i <= NF; i++) if ($i ~ /%/) p = $i + 0
            st = /discharging/ ? "dis" : (/charging|charged/ ? "chg" : "unk")
            print p, st; exit
        }')
elif ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
  for d in /sys/class/power_supply/BAT*; do
    [ -r "$d/capacity" ] || continue
    pct=$(cat "$d/capacity")
    state=$(cat "$d/status" 2>/dev/null || echo Unknown)
    break
  done
fi

[ -n "${pct:-}" ] || exit 0

charging=0
case "$state" in
chg | Charging* | Full*) charging=1 ;;
esac

if [ "$pct" -ge 60 ]; then
  color="$GREEN"
  glyph="󰂁"
elif [ "$pct" -ge 20 ]; then
  color="$YELLOW"
  glyph="󰁾"
else
  color="$RED"
  glyph="󰁻"
fi
[ "$charging" -eq 1 ] && glyph="󰂄"

printf '#[fg=%s,bg=default]%s#[fg=%s,bg=%s,bold]%s %d%%#[fg=%s,bg=default]%s' \
  "$BGDA" "$CAP_L" "$color" "$BGDA" "$glyph" "$pct" "$BGDA" "$CAP_R"
