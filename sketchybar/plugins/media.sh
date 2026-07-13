#!/usr/bin/env bash
# Now-playing — the bash twin of Zebar's <Media/> widget: prev · play/pause · next transport plus a
# "title — artist" label (purple), hidden entirely when nothing is playing. This driver runs on the
# `media` (play/pause) item and also drives its siblings media.prev / media.next / media.info. The
# transport click_scripts live in sketchybarrc and call `media-control` directly.
#
# Deps: `media-control` (ungive/media-control, in the Brewfile) for the now-playing session, and
# `jq` to read its JSON. Now-playing depends on macOS exposing MediaRemote to media-control.
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

hide() { sketchybar --set media drawing=off --set media.prev drawing=off \
  --set media.next drawing=off --set media.info drawing=off; }

command -v media-control >/dev/null 2>&1 || {
  hide
  exit 0
}
JSON="$(media-control get 2>/dev/null)"
[ -z "$JSON" ] && {
  hide
  exit 0
}

TITLE="$(printf '%s' "$JSON" | jq -r '.title // empty' 2>/dev/null)"
ARTIST="$(printf '%s' "$JSON" | jq -r '.artist // empty' 2>/dev/null)"
PLAYING="$(printf '%s' "$JSON" | jq -r '.playing // false' 2>/dev/null)"

if [ -z "$TITLE" ] && [ -z "$ARTIST" ]; then
  hide
  exit 0
fi

# "title — artist" (em dash), matching the Zebar label join; trim to keep the bar tidy.
if [ -n "$TITLE" ] && [ -n "$ARTIST" ]; then LABEL="$TITLE — $ARTIST"; else LABEL="${TITLE}${ARTIST}"; fi
[ "${#LABEL}" -gt 40 ] && LABEL="$(printf '%.37s…' "$LABEL")"

if [ "$PLAYING" = "true" ]; then PP="󰏤"; else PP="󰐊"; fi # pause when playing, play when paused

sketchybar --set media drawing=on icon="$PP" icon.color="$FG" \
  --set media.prev drawing=on icon="󰒮" icon.color="$FG" \
  --set media.next drawing=on icon="󰒭" icon.color="$FG" \
  --set media.info drawing=on label="$LABEL" label.color="$MAGENTA"
