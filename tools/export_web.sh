#!/usr/bin/env bash
# Build the browser version into build/web/ (GitHub Pages serves it as is: .github/workflows/web.yml).
# Needs Godot 4.7.2 and its Web template (web_nothreads_release.zip) in
# ~/.local/share/godot/export_templates/4.7.2.stable/.
# Try it locally: tools/export_web.sh && python3 -m http.server -d build/web
set -euo pipefail
cd "$(dirname "$0")/.."
out="$PWD/build/web"
rm -rf "$out"
mkdir -p "$out"
godot --headless --path game --import >/dev/null 2>&1
godot --headless --path game --script res://scripts/dev/check_glyphs.gd
godot --headless --path game --export-release "Web" "$out/index.html"
godot --headless --path game --script res://scripts/dev/licenses.gd -- "$out/THIRD-PARTY-NOTICES.txt"
cp LICENSE "$out/LICENSE.txt"
ls -l "$out"
