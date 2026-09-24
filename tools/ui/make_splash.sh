#!/bin/bash
# Boot splash (desktop start-up and the browser build's loading screen): the crest and the
# name on the dark UI background. Needs ImageMagick and the Noto Serif Display font.
# Run: tools/ui/make_splash.sh   ->  game/assets/ui/splash.png
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=game/assets/ui/splash.png
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FONT=/usr/share/fonts/noto/NotoSerifDisplay-SemiBold.ttf
BG="#12141a"

# a soft lighter pool in the middle of the dark ground
magick -size 1280x720 radial-gradient:"#1f2430"-"$BG" "$TMP/bg.png"
magick -background none -density 300 game/assets/ui/icons/crest.svg -resize 168x168 "$TMP/crest.png"
# gold rule fading out at both ends
magick \( -size 2x260 gradient:white-black -rotate 90 \) \( +clone -flop \) +append "$TMP/mask.png"
magick -size 520x2 xc:"#d0a85c" "$TMP/mask.png" -alpha off -compose CopyOpacity -composite "$TMP/rule.png"
magick "$TMP/bg.png" \
  "$TMP/crest.png" -gravity north -geometry +0+150 -composite \
  -font "$FONT" -fill "#efe6d2" -pointsize 96 -kerning 4 -gravity north -annotate +0+338 "AETHER CROWN" \
  "$TMP/rule.png" -gravity north -geometry +0+470 -composite \
  -fill "#d0a85c" -pointsize 30 -kerning 14 -gravity north -annotate +0+492 "IRONSPINE" \
  -depth 8 "$OUT"
echo "wrote $OUT"
