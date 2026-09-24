#!/usr/bin/env bash
# Build the release packages into build/: a Linux .tar.gz and a Windows .zip.
# Needs the Godot 4.7.2 export templates in ~/.local/share/godot/export_templates/4.7.2.stable/
# (the editor's "Manage Export Templates", or the official .tpz unpacked there).
# Usage: tools/export.sh [version]      e.g. tools/export.sh v1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."
ver="${1:-dev}"
name=AetherCrownIronspine
out="$PWD/build"
rm -rf "$out/pkg"
mkdir -p "$out/pkg/linux/$name" "$out/pkg/windows/$name"
godot --headless --path game --import >/dev/null 2>&1
godot --headless --path game --script res://scripts/dev/check_glyphs.gd
godot --headless --path game --export-release "Linux" "$out/pkg/linux/$name/$name.x86_64"
godot --headless --path game --export-release "Windows" "$out/pkg/windows/$name/$name.exe"
godot --headless --path game --script res://scripts/dev/licenses.gd -- "$out/pkg/THIRD-PARTY-NOTICES.txt"
for os in linux windows; do
	cp LICENSE "$out/pkg/$os/$name/LICENSE.txt"
	cp "$out/pkg/THIRD-PARTY-NOTICES.txt" "$out/pkg/$os/$name/"
done
rm -f "$out/$name-$ver-linux-x86_64.tar.gz" "$out/$name-$ver-windows-x86_64.zip"
tar -C "$out/pkg/linux" -czf "$out/$name-$ver-linux-x86_64.tar.gz" "$name"
(cd "$out/pkg/windows" && zip -q -r "$out/$name-$ver-windows-x86_64.zip" "$name")
ls -l "$out/$name-$ver-linux-x86_64.tar.gz" "$out/$name-$ver-windows-x86_64.zip"
