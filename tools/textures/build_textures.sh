#!/bin/bash
# Regenerate game textures with Material Maker (CLI export) + ImageMagick.
# Usage: tools/textures/build_textures.sh
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MM=${MATERIAL_MAKER:-/opt/material-maker-bin/material_maker.x86_64}
EX=${MM_EXAMPLES:-/opt/material-maker-bin/examples}
TMP=$(mktemp -d)
OUT="$ROOT/game/assets/textures"
mkdir -p "$OUT"

# Material Maker writes the textures but does not exit afterwards: wait, then stop it.
export_one() {
  local src="$1" name attempt
  name=$(basename "$src" .ptex)
  for attempt in 1 2 3; do
    "$MM" --export-material --target "Godot/Godot 4 Standard" -o "$TMP" "$src" > "$TMP/$name.log" 2>&1 &
    local pid=$!
    for _ in $(seq 1 240); do
      if [ -f "$TMP/$name.tres" ] && [ -f "$TMP/${name}_albedo.png" ]; then sleep 6; break; fi
      kill -0 $pid 2>/dev/null || break
      sleep 1
    done
    kill $pid 2>/dev/null; wait $pid 2>/dev/null
    [ -f "$TMP/${name}_albedo.png" ] && break
    sleep 2
  done
  echo "exported $name: $(ls "$TMP" | grep -c "^${name}_") maps"
}

for src in "$EX/rock.ptex" "$EX/dry_earth.ptex" "$EX/stone_wall.ptex" "$EX/tiles.ptex" "$EX/metal_pattern.ptex" \
           "$EX/wood.ptex" "$EX/improved_brick.ptex" "$ROOT/tools/textures/terrain_grass.ptex" "$ROOT/tools/textures/terrain_gravel.ptex"; do
  export_one "$src"
done

# copy <mm name> <game name> [albedo magick ops...]
copy() {
  local src=$1 dst=$2; shift 2
  for ch in albedo normal orm; do
    local f="$TMP/${src}_$ch.png"
    [ -f "$f" ] || continue
    if [ "$ch" = albedo ] && [ $# -gt 0 ]; then
      magick "$f" -resize 1024x1024 "$@" "$OUT/${dst}_$ch.png"
    else
      magick "$f" -resize 1024x1024 "$OUT/${dst}_$ch.png"
    fi
  done
}
copy rock terrain_cliff -modulate 100,55
copy dry_earth terrain_dirt -modulate 105,45
copy terrain_grass terrain_grass
copy terrain_gravel terrain_rock
copy stone_wall stone -modulate 100,40
copy tiles roof -colorspace gray -colorspace sRGB -level 10%,90%
copy metal_pattern metal -modulate 100,45
copy wood wood
copy improved_brick plaster -modulate 110,35
copy rock rock -modulate 100,40
rm -rf "$TMP"
ls "$OUT"
