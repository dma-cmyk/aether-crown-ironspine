#!/bin/bash
# Regenerate every asset from source scripts, then re-import into Godot.
#   tools/build_all.sh            # everything
#   tools/build_all.sh models     # one stage: terrain | models | textures | fx | icons | audio | import
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
stage() { [ -z "$1" ] || [ "$1" = "$2" ]; }
BL="blender --background --factory-startup --python"
if stage "$1" textures; then tools/textures/build_textures.sh; uv run tools/textures/creature_textures.py; fi
if stage "$1" fx; then tools/textures/build_fx.sh; fi
if stage "$1" terrain; then $BL tools/blender/terrain/build_terrain.py; fi
if stage "$1" models; then
  $BL tools/blender/models/env_props.py
  $BL tools/blender/models/buildings.py
  $BL tools/blender/models/units.py
  $BL tools/blender/models/creatures.py
  $BL tools/blender/gearforge/build.py
fi
if stage "$1" icons; then python3 tools/ui/make_icons.py; fi
if stage "$1" audio; then uv run tools/audio/gen_audio.py; fi
if stage "$1" import; then
  godot --headless --path game --import
  python3 tools/godot/tune_imports.py
  godot --headless --path game --import
fi
echo "build_all: done"
