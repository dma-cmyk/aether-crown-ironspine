#!/usr/bin/env python3
"""Adjust Godot .import settings for generated textures.

Run after `godot --headless --path game --import` has created the .import
files; then import again so the new settings take effect.
  3D material textures : VRAM compressed, mipmaps, max 1024 px
  textures/units/      : the same without the size cap (baked at the size they are meant for)
  *_normal.png         : + normal-map compression
  terrain/splat.png    : lossless + mipmaps (masks must stay exact)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2] / "game"


def patch(path, values):
    text = path.read_text(encoding="utf-8")
    changed = False
    for key, val in values.items():
        pat = re.compile(r"^%s=.*$" % re.escape(key), re.M)
        line = "%s=%s" % (key, val)
        if pat.search(text):
            new = pat.sub(line, text)
        else:
            new = text.rstrip("\n") + "\n" + line + "\n"
        if new != text:
            text = new
            changed = True
    if changed:
        path.write_text(text, encoding="utf-8")
    return changed


def main():
    n = 0
    for imp in sorted((ROOT / "assets" / "textures").glob("*.png.import")):
        vals = {"compress/mode": "2", "mipmaps/generate": "true", "process/size_limit": "1024",
                "detect_3d/compress_to": "0"}
        if imp.name.endswith("_normal.png.import"):
            vals["compress/normal_map"] = "1"
        n += patch(imp, vals)
    for imp in sorted((ROOT / "assets" / "textures" / "units").glob("*.png.import")):
        vals = {"compress/mode": "2", "mipmaps/generate": "true", "process/size_limit": "0",
                "detect_3d/compress_to": "0", "compress/normal_map": "1" if imp.name.endswith("_normal.png.import") else "0"}
        n += patch(imp, vals)
    splat = ROOT / "assets" / "terrain" / "splat.png.import"
    if splat.exists():
        n += patch(splat, {"compress/mode": "0", "mipmaps/generate": "true", "detect_3d/compress_to": "0"})
    for name in ("minimap.png", "nav.png"):
        f = ROOT / "assets" / "terrain" / (name + ".import")
        if f.exists():
            n += patch(f, {"compress/mode": "0", "mipmaps/generate": "false", "detect_3d/compress_to": "0"})
    print("patched", n, "import files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
