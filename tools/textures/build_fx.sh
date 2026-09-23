#!/bin/bash
# Particle and decal sprites (ImageMagick). Output: game/assets/fx/*.png
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="$ROOT/game/assets/fx"
T=$(mktemp -d)
mkdir -p "$OUT"
S=128
# soft round mask
magick -size ${S}x${S} radial-gradient:white-black -level 0%,100% -evaluate pow 1.1 "$T/round.png"
# smoke puff: billowy noise inside the round mask
magick -size ${S}x${S} xc: -seed 11 +noise Random -channel G -separate +channel -virtual-pixel tile -blur 0x7 -auto-level "$T/n1.png"
magick -size ${S}x${S} xc: -seed 29 +noise Random -channel G -separate +channel -virtual-pixel tile -blur 0x3 -auto-level "$T/n2.png"
magick "$T/n1.png" "$T/n2.png" -compose multiply -composite -auto-level "$T/noise.png"
magick "$T/noise.png" "$T/round.png" -compose multiply -composite -level 2%,36% "$T/smoke_a.png"
magick "$T/noise.png" -level 0%,140% -fill white -colorize 35% "$T/smoke_rgb.png"
magick "$T/smoke_rgb.png" "$T/smoke_a.png" -alpha off -compose CopyOpacity -composite "$OUT/fx_smoke.png"
# glow: bright core + wide falloff
magick -size ${S}x${S} radial-gradient:white-black -evaluate pow 3.2 "$T/glow_a.png"
magick -size ${S}x${S} xc:white "$T/glow_a.png" -alpha off -compose CopyOpacity -composite "$OUT/fx_glow.png"
# flash star: glow + 4 spikes
magick -size ${S}x${S} xc:black -fill white -draw "polygon 64,0 68,60 128,64 68,68 64,128 60,68 0,64 60,60" -blur 0x2 "$T/star.png"
magick "$T/star.png" "$T/glow_a.png" -compose lighten -composite "$T/flash_a.png"
magick -size ${S}x${S} xc:white "$T/flash_a.png" -alpha off -compose CopyOpacity -composite "$OUT/fx_flash.png"
# fire: noisy flame blob
magick "$T/n2.png" "$T/round.png" -compose multiply -composite -level 10%,55% "$T/fire_a.png"
magick -size ${S}x${S} xc:white "$T/fire_a.png" -alpha off -compose CopyOpacity -composite "$OUT/fx_fire.png"
# scorch decal (dark, ragged edge)
magick -size 256x256 radial-gradient:white-black -evaluate pow 1.3 "$T/sc_round.png"
magick -size 256x256 xc: -seed 5 +noise Random -channel G -separate +channel -blur 0x4 -auto-level "$T/sc_noise.png"
magick "$T/sc_round.png" "$T/sc_noise.png" -compose multiply -composite -level 8%,45% "$T/sc_a.png"
magick -size 256x256 xc:"#1a1612" "$T/sc_a.png" -alpha off -compose CopyOpacity -composite "$OUT/fx_scorch.png"
rm -rf "$T"
ls -la "$OUT"
