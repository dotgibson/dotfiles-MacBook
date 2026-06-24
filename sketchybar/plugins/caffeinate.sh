#!/usr/bin/env bash
# Keep-awake toggle — a free Amphetamine. Click to start/stop a BAR-OWNED `caffeinate -di`, which
# prevents display sleep and system idle sleep; the icon reflects state (coffee = awake, moon =
# sleep allowed). No deps (caffeinate is built into macOS). Invoked two ways:
#   • script=        → render current state (on load + update_freq resync)
#   • click_script=  → "$0 toggle": flip the state, then render
#
# Only the caffeinate WE started is tracked and killed — via a pidfile, guarded against PID reuse
# by confirming the live process is actually caffeinate — so a caffeinate launched elsewhere (a
# long build, another script) is never touched.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

PIDFILE="${TMPDIR:-/tmp}/sketchybar_caffeinate.pid"

# Echo the live bar-owned caffeinate PID (exit 0), or prune a stale pidfile and fail (exit 1).
running_pid() {
  local pid
  [ -r "$PIDFILE" ] || return 1
  pid="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -p "$pid" -o comm= 2>/dev/null | grep -q caffeinate; then
    printf '%s' "$pid"
    return 0
  fi
  rm -f "$PIDFILE"
  return 1
}

if [ "${1:-}" = "toggle" ]; then
  if pid="$(running_pid)"; then
    kill "$pid" 2>/dev/null
    rm -f "$PIDFILE"
  else
    nohup caffeinate -di >/dev/null 2>&1 &
    printf '%s' "$!" >"$PIDFILE"
  fi
fi

if running_pid >/dev/null; then
  sketchybar --set "$NAME" icon="󰅶" icon.color="$YELLOW"
else
  sketchybar --set "$NAME" icon="󰒲" icon.color="$GREY"
fi
