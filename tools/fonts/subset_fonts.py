# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools[woff]"]
# ///
"""Subset the Noto fonts the UI uses into game/assets/fonts/ as WOFF2.

The Web build cannot reach system fonts, so the game ships its own. The Japanese faces keep
kana and every character in the game's text; rerun this after adding text with new kanji
(tools/export.sh stops when a character is missing).
Needs the Noto fonts installed (Arch: noto-fonts, noto-fonts-cjk).
Usage: uv run tools/fonts/subset_fonts.py
"""
import pathlib

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
OUT = GAME / "assets" / "fonts"
NOTO = pathlib.Path("/usr/share/fonts/noto")
CJK = pathlib.Path("/usr/share/fonts/noto-cjk")

# (output name, source file, face index in a .ttc, keep Japanese)
FACES = [
    ("NotoSerifDisplay-SemiBold", NOTO / "NotoSerifDisplay-SemiBold.ttf", 0, False),
    ("NotoSerif-Medium", NOTO / "NotoSerif-Medium.ttf", 0, False),
    ("NotoSerif-Italic", NOTO / "NotoSerif-Italic.ttf", 0, False),
    ("NotoSansCJKjp-Medium", CJK / "NotoSansCJK-Medium.ttc", 0, True),
    ("NotoSansCJKjp-Bold", CJK / "NotoSansCJK-Bold.ttc", 0, True),
    ("NotoSerifCJKjp-Medium", CJK / "NotoSerifCJK-Medium.ttc", 0, True),
]


def game_text() -> set[int]:
    chars: set[int] = set()
    for ext in ("gd", "json", "tscn", "tres", "cfg"):
        for f in GAME.rglob(f"*.{ext}"):
            if ".godot" not in f.parts:
                chars.update(ord(c) for c in f.read_text(encoding="utf-8", errors="ignore"))
    return {c for c in chars if c >= 0x20}


def blocks(*ranges: tuple[int, int]) -> set[int]:
    return {c for a, b in ranges for c in range(a, b + 1)}


def main() -> None:
    latin = blocks((0x20, 0x7E), (0xA0, 0xFF), (0x2010, 0x2027), (0x2030, 0x203A), (0x2190, 0x2193), (0x20AC, 0x20AC))
    japanese = latin | blocks((0x3000, 0x30FF), (0x31F0, 0x31FF), (0xFF00, 0xFFEF))
    text = game_text()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, src, index, jp in FACES:
        font = TTFont(src, fontNumber=index)
        cmap = font.getBestCmap()
        wanted = (japanese if jp else latin) | text
        keep = sorted(c for c in wanted if c in cmap)
        opts = subset.Options()
        opts.flavor = "woff2"
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.name_languages = ["*"]
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=keep)
        sub.subset(font)
        path = OUT / f"{name}.woff2"
        font.flavor = "woff2"
        font.save(path)
        print(f"{path.relative_to(ROOT)}  {len(keep)} chars  {path.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
