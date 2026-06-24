#!/usr/bin/env bash
# Network throughput (down/up) for the default interface, sampled between runs. Stores the last
# byte counters + timestamp in a cache file and divides the delta by elapsed time. No deps
# (route + netstat are built in).
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
if [ -z "$IF" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# First matching (Link#) row carries the cumulative byte counters: $7 = Ibytes, $10 = Obytes.
read -r RX TX < <(netstat -ib -I "$IF" 2>/dev/null | awk -v i="$IF" '$1==i {print $7, $10; exit}')
if [ -z "${RX:-}" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

NOW="$(date +%s)"
CACHE="${TMPDIR:-/tmp}/sketchybar_net_${IF}"
PRX=0
PTX=0
PT=0
[ -r "$CACHE" ] && read -r PRX PTX PT <"$CACHE"
printf '%s %s %s\n' "$RX" "$TX" "$NOW" >"$CACHE"

if [ "${PT:-0}" -gt 0 ]; then
  DT=$((NOW - PT))
  [ "$DT" -le 0 ] && DT=1
  dl=$(((RX - PRX) / DT))
  [ "$dl" -lt 0 ] && dl=0
  ul=$(((TX - PTX) / DT))
  [ "$ul" -lt 0 ] && ul=0
else
  dl=0
  ul=0
fi

human() { # bytes/sec -> compact human string
  local b=$1
  if [ "$b" -ge 1048576 ]; then
    awk -v b="$b" 'BEGIN{printf "%.1fM", b/1048576}'
  elif [ "$b" -ge 1024 ]; then
    awk -v b="$b" 'BEGIN{printf "%.0fK", b/1024}'
  else
    printf '%dB' "$b"
  fi
}

sketchybar --set "$NAME" drawing=on icon="󰓅" icon.color="$ACCENT" \
  label="↓$(human "$dl") ↑$(human "$ul")" label.color="$ACCENT"
