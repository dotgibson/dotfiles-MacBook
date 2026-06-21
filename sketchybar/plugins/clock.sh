#!/usr/bin/env bash
# Date + time, e.g. "Sat 21 Jun 14:09".
# shellcheck disable=SC2154  # $NAME is injected by sketchybar at runtime
sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')"
