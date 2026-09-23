#!/bin/bash
# Launch Aether Crown: Ironspine (requires Godot 4.7 on PATH).
cd "$(dirname "$0")" || exit 1
if [ ! -d game/.godot/imported ]; then
  godot --headless --path game --import >/dev/null 2>&1
fi
exec godot --path game "$@"
