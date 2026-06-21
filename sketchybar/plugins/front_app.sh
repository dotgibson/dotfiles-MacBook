#!/usr/bin/env bash
# Shows the name of the frontmost app. Fired by the front_app_switched event, which delivers the
# app name in $INFO.
# shellcheck disable=SC2154  # $SENDER/$INFO are injected by sketchybar at runtime
if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set front_app label="$INFO"
fi
