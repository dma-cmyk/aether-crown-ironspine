#!/usr/bin/env python3
"""Generate the HUD icon set as SVG (64x64 viewBox, ivory/gold line style).

Run: python3 tools/ui/make_icons.py      (stdlib only)
Output: game/assets/ui/icons/*.svg
"""
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[2] / "game" / "assets" / "ui" / "icons"
IVORY = "#efe6d2"
GOLD = "#d0a85c"
DARK = "#1a1f28"
AETHER = "#74d8ff"
RED = "#ff6a50"
SW = 3.2


def svg(body, size=64):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 64 64" '
            'fill="none" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % (size, size, body))


def star(cx, cy, r1, r2, n, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append("%.2f,%.2f" % (cx + math.cos(a) * r, cy + math.sin(a) * r))
    return " ".join(pts)


def poly(points, stroke=IVORY, fill="none", sw=SW):
    return '<polygon points="%s" stroke="%s" fill="%s" stroke-width="%s"/>' % (points, stroke, fill, sw)


def path(d, stroke=IVORY, fill="none", sw=SW):
    return '<path d="%s" stroke="%s" fill="%s" stroke-width="%s"/>' % (d, stroke, fill, sw)


def circle(cx, cy, r, stroke=IVORY, fill="none", sw=SW):
    return '<circle cx="%s" cy="%s" r="%s" stroke="%s" fill="%s" stroke-width="%s"/>' % (cx, cy, r, stroke, fill, sw)


def rect(x, y, w, h, stroke=IVORY, fill="none", sw=SW, rx=0):
    return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" stroke="%s" fill="%s" stroke-width="%s"/>' % (x, y, w, h, rx, stroke, fill, sw)


def gear(cx, cy, r, teeth=10, depth=4, stroke=GOLD, fill="none", sw=SW):
    pts = []
    for i in range(teeth * 4):
        a = math.tau * i / (teeth * 4)
        rr = r if (i % 4) in (0, 1) else r - depth
        pts.append("%.2f,%.2f" % (cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return poly(" ".join(pts), stroke, fill, sw)


ICONS = {
    # resources
    "res_material": path("M32 8 L54 20 L54 44 L32 56 L10 44 L10 20 Z", GOLD, "#4a3622")
    + path("M10 20 L32 32 L54 20 M32 32 L32 56", GOLD) + path("M21 14 L43 26", GOLD, sw=2),
    "res_aether": poly(star(32, 32, 26, 8, 4), AETHER, "#1d5b73") + poly(star(32, 32, 12, 4, 4, -45), "#bff0ff", "#74d8ff", 1.5),
    "res_pop": circle(22, 18, 7, IVORY, "#3a3f4a") + path("M10 50 C10 34 34 34 34 50", IVORY, "#3a3f4a")
    + circle(42, 20, 6, IVORY, "#3a3f4a") + path("M32 48 C32 36 54 34 54 48", IVORY, "#3a3f4a"),
    # commands
    "cmd_move": path("M32 6 L32 58 M6 32 L58 32") + path("M24 14 L32 6 L40 14 M24 50 L32 58 L40 50 M14 24 L6 32 L14 40 M50 24 L58 32 L50 40"),
    "cmd_hold": path("M32 6 L52 13 L52 30 C52 44 42 53 32 58 C22 53 12 44 12 30 L12 13 Z", IVORY, "#2a3040")
    + path("M32 16 L32 46 M22 28 L42 28", GOLD),
    "cmd_attack": path("M12 52 L46 12 M46 12 L52 10 L50 16 M18 42 L24 48 M52 52 L18 12 M18 12 L12 10 L14 16 M40 48 L46 42")
    + path("M9 55 L15 49 M55 55 L49 49", GOLD),
    "cmd_patrol": path("M50 26 A20 20 0 0 0 16 20") + path("M14 38 A20 20 0 0 0 48 44") + path("M16 10 L16 20 L26 20 M48 54 L48 44 L38 44", GOLD),
    "cmd_fortify": path("M14 58 L14 24 L20 24 L20 18 L26 18 L26 24 L38 24 L38 18 L44 18 L44 24 L50 24 L50 58 Z", IVORY, "#2a3040")
    + path("M27 58 L27 44 A5 5 0 0 1 37 44 L37 58", GOLD) + path("M6 58 L58 58"),
    "cmd_repair": path("M14 50 L36 28 M40 12 A10 10 0 0 0 30 26 L36 32 A10 10 0 0 0 50 22 L44 24 L40 20 L42 14 Z")
    + path("M44 44 L52 52 M22 16 L16 10 L10 16 L16 22 Z M16 22 L42 48", GOLD),
    "cmd_deploy": path("M18 12 L32 26 L46 12 M18 24 L32 38 L46 24") + path("M10 50 L54 50 M16 50 L16 42 M48 50 L48 42", GOLD),
    "cmd_special": poly(star(32, 32, 27, 9, 8), GOLD, "#4a3a18") + circle(32, 32, 6, IVORY, IVORY, 1),
    # units
    "unit_aetherguard": path("M16 40 C16 20 48 20 48 40 L48 46 L16 46 Z", IVORY, "#2a3345")
    + path("M20 38 L44 38", AETHER, sw=3) + path("M32 10 L32 22", GOLD, sw=5) + path("M12 52 L52 52", GOLD),
    "unit_artificer": gear(28, 34, 18, 9, 5, GOLD, "#3a2e1c") + circle(28, 34, 6)
    + path("M40 14 L54 28 M50 10 A7 7 0 0 0 44 20 L48 24 A7 7 0 0 0 58 18 L54 18 L52 14 Z"),
    "unit_walker": rect(18, 10, 28, 20, IVORY, "#2a3345", rx=3) + path("M22 20 L42 20", AETHER, sw=3)
    + path("M24 30 L18 44 L22 56 M40 30 L46 44 L42 56 M14 56 L28 56 M36 56 L50 56") + path("M46 14 L58 14 M46 20 L58 20", GOLD),
    "unit_mortar": path("M10 44 L54 44 L50 54 L14 54 Z", IVORY, "#2a3345") + path("M24 44 L24 34 L40 34 L40 44")
    + path("M30 34 L46 12", GOLD, sw=6) + circle(18, 54, 3) + circle(32, 54, 3) + circle(46, 54, 3),
    "unit_airship": path("M8 26 C8 14 52 12 56 24 C52 36 8 36 8 26 Z", IVORY, "#3a3a34")
    + path("M20 36 L22 44 L42 44 L44 36") + path("M18 20 L18 32 M30 17 L30 35 M42 18 L42 33", GOLD, sw=2) + path("M4 18 L10 26 L4 34", GOLD),
    "unit_cerberus": path("M24 36 L25 16 L30 23 L34 23 L39 16 L40 36 L36 44 L28 44 Z", IVORY, "#2a3345")
    + path("M5 46 L7 30 L12 36 L16 36 L20 30 L22 46 L18 52 L10 52 Z", IVORY, "#2a3345")
    + path("M42 46 L44 30 L48 36 L52 36 L57 30 L59 46 L54 52 L46 52 Z", IVORY, "#2a3345")
    + circle(29, 30, 1.6, AETHER, AETHER, 1) + circle(35, 30, 1.6, AETHER, AETHER, 1)
    + circle(11, 41, 1.4, AETHER, AETHER, 1) + circle(53, 41, 1.4, AETHER, AETHER, 1) + path("M10 58 L54 58", GOLD),
    "unit_cyclops": path("M18 52 C12 38 16 16 32 14 C48 16 52 38 46 52 Z", IVORY, "#2a3345")
    + circle(32, 30, 7.5, AETHER, "#1d5b73") + circle(32, 30, 2.6, IVORY, IVORY, 1)
    + path("M21 21 L43 21", IVORY, sw=3.6) + path("M22 18 L15 5 M42 18 L49 5", GOLD)
    + path("M25 46 L27 41 M39 46 L37 41", IVORY, sw=2.4),
    "unit_griffin": path("M12 52 C8 34 22 20 38 21 C47 22 53 27 55 33 L47 36 C48 41 44 44 38 42 C34 50 24 54 12 52 Z", IVORY, "#2a3345")
    + path("M46 27 L59 33 L48 40 Z", GOLD, "#4a3a18") + circle(39, 29, 2.6, AETHER, AETHER, 1)
    + path("M20 46 L28 38 M16 38 L24 30 M26 22 L20 10 M32 21 L30 8", GOLD, sw=2.4),
    "unit_dragon": path("M8 52 C8 36 18 24 32 21 L42 9 L41 21 C49 22 55 28 57 34 L45 36 L50 43 L37 41 C31 48 20 53 8 52 Z", IVORY, "#3a2a2a")
    + circle(40, 28, 2.4, AETHER, AETHER, 1) + path("M28 22 L22 10", GOLD)
    + path("M52 41 C57 45 58 50 56 56 C54 51 50 48 47 47", RED, sw=2.6),
    "unit_mech": path("M21 30 L43 30 L45 48 L19 48 Z", IVORY, "#2a3345") + rect(8, 26, 11, 13, IVORY, "#2a3345", rx=2)
    + rect(45, 26, 11, 13, IVORY, "#2a3345", rx=2) + rect(26, 14, 12, 12, IVORY, "#2a3345", rx=2)
    + path("M28 20 L36 20", AETHER, sw=2.6) + path("M32 15 L23 4 M32 15 L41 4", GOLD, sw=2.6)
    + path("M25 48 L23 60 M39 48 L41 60", IVORY) + circle(32, 38, 2.6, AETHER, AETHER, 1),
    "unit_demon": path("M4 20 L20 36 L18 44 L3 40 L9 33 Z", IVORY, "#3a2a2a") + path("M60 20 L44 36 L46 44 L61 40 L55 33 Z", IVORY, "#3a2a2a")
    + path("M19 58 L21 40 C24 35 40 35 43 40 L45 58 Z", IVORY, "#3a2a2a") + circle(32, 27, 9, IVORY, "#3a2a2a")
    + path("M26 20 C19 17 17 10 20 4 C22 10 25 13 29 16", GOLD, "#4a3a18") + path("M38 20 C45 17 47 10 44 4 C42 10 39 13 35 16", GOLD, "#4a3a18")
    + circle(28.5, 27, 1.8, RED, RED, 1) + circle(35.5, 27, 1.8, RED, RED, 1) + path("M28 33 L36 33", RED, sw=2),
    "unit_angel": path("M27 32 C18 23 9 22 3 30 C10 31 13 37 11 44 C17 39 23 39 27 41", IVORY, "#2a3345")
    + path("M37 32 C46 23 55 22 61 30 C54 31 51 37 53 44 C47 39 41 39 37 41", IVORY, "#2a3345")
    + path("M27 28 L37 28 L43 58 L21 58 Z", IVORY, "#2a3345") + circle(32, 20, 6, IVORY, "#2a3345")
    + path("M23 8 A9 3.2 0 1 0 41 8 A9 3.2 0 1 0 23 8", GOLD) + path("M50 12 L42 58", GOLD, sw=2.6)
    + path("M50 12 L48 4 L54 10 Z", AETHER, AETHER, 1.5),
    # buildings
    "bld_citadel": path("M10 56 L10 30 L16 30 L16 24 L22 24 L22 30 L42 30 L42 24 L48 24 L48 30 L54 30 L54 56 Z", IVORY, "#2a3040")
    + path("M26 30 L26 16 L32 6 L38 16 L38 30", GOLD, "#4a3a18") + circle(32, 21, 3, AETHER, AETHER, 1) + path("M28 56 L28 46 A4 4 0 0 1 36 46 L36 56"),
    "bld_barracks": path("M8 56 L8 32 L30 18 L30 56 Z", IVORY, "#2a3040") + path("M30 56 L30 20 L38 20 L38 56 Z M30 20 L34 8 L38 20", GOLD, "#4a3a18")
    + path("M38 56 L38 34 L56 34 L56 56 Z", IVORY, "#2a3040") + path("M14 42 L14 48 M22 40 L22 48"),
    "bld_foundry": path("M8 56 L8 30 L20 22 L20 30 L32 22 L32 30 L44 22 L44 56 Z", IVORY, "#2a3040")
    + rect(46, 10, 6, 46, GOLD, "#4a3a18") + gear(26, 44, 8, 8, 3, GOLD, "none", 2.4) + path("M49 6 L49 2", RED, sw=3),
    "bld_skyport": path("M26 56 L30 14 L34 14 L38 56") + path("M22 14 L42 14 M24 28 L40 28 M22 42 L42 42", GOLD)
    + circle(32, 9, 4, AETHER, AETHER, 1) + path("M6 56 L58 56") + path("M44 22 C44 16 60 16 60 22 C60 28 44 28 44 22 Z", IVORY, "#3a3a34", 2.2),
    "bld_refinery": path("M16 56 L16 44 L48 44 L48 56 Z", IVORY, "#2a3040") + path("M32 8 L44 22 L40 40 L24 40 L20 22 Z", AETHER, "#1d5b73")
    + path("M18 22 L18 44 M46 22 L46 44", GOLD),
    "bld_habitat": path("M6 56 L6 34 L18 24 L30 34 L30 56 Z", IVORY, "#2a3040") + path("M30 56 L30 28 L44 16 L58 28 L58 56 Z", IVORY, "#2a3040")
    + path("M14 44 L22 44 M40 38 L48 38 M40 46 L48 46", GOLD),
    "bld_bastion": path("M16 58 L18 26 L46 26 L48 58 Z", IVORY, "#2a3040") + path("M16 26 L16 18 L22 18 L22 24 L28 24 L28 18 L36 18 L36 24 L42 24 L42 18 L48 18 L48 26")
    + path("M32 18 L32 10 L54 6", GOLD, sw=5),
    "bld_sanctum": rect(8, 26, 11, 30, IVORY, "#2a3040", rx=2) + rect(45, 26, 11, 30, IVORY, "#2a3040", rx=2)
    + path("M6 24 L21 24 M43 24 L58 24", GOLD) + poly("32,6 41,24 32,44 23,24", AETHER, "#1d5b73")
    + path("M4 58 L60 58", GOLD) + path("M13 36 L13 44 M50 36 L50 44", AETHER, sw=2.4),
    # misc
    "crest": gear(32, 36, 22, 12, 4, GOLD, "#20232b", 2.6) + path("M18 30 L22 16 L28 24 L32 12 L36 24 L42 16 L46 30 Z", GOLD, "#6b5226", 2.4)
    + circle(32, 38, 6, AETHER, "#1d5b73", 2),
    "gear": gear(32, 32, 24, 10, 6, IVORY, "none", 3) + circle(32, 32, 8),
    "flag": path("M16 58 L16 6") + path("M16 8 L50 12 L42 20 L50 28 L16 26 Z", GOLD, "#4a3a18"),
    "idle": circle(32, 20, 8) + path("M20 56 L24 34 L40 34 L44 56") + path("M48 8 L58 8 L48 18 L58 18", GOLD, sw=2.5),
    "army": path("M12 50 L20 30 L28 50 M36 50 L44 30 L52 50 M24 44 L40 44") + path("M20 30 L20 16 M44 30 L44 16", GOLD),
    "alert": path("M32 8 L58 54 L6 54 Z", GOLD, "#4a3a18") + path("M32 24 L32 40 M32 46 L32 48", IVORY, sw=4),
    "check_on": rect(8, 8, 48, 48, GOLD, "#2a2418", rx=4) + path("M18 32 L28 42 L46 20", AETHER, sw=5),
    "check_off": rect(8, 8, 48, 48, GOLD, "#1a1c22", rx=4),
    "check_fail": rect(8, 8, 48, 48, GOLD, "#2a1818", rx=4) + path("M20 20 L44 44 M44 20 L20 44", RED, sw=5),
    "compass": path("M32 4 L40 32 L32 60 L24 32 Z", GOLD, "#4a3a18", 2) + path("M32 4 L40 32 L24 32 Z", GOLD, GOLD, 1),
    "diamond": path("M32 8 L56 32 L32 56 L8 32 Z", GOLD, "#20232b", 3) + path("M32 20 L44 32 L32 44 L20 32 Z", AETHER, AETHER, 1),
    "bld_judgement": path("M24 58 L28 22 L36 22 L40 58 Z", IVORY, "#2a3040") + path("M14 58 L50 58", GOLD)
    + path("M32 4 L39 14 L32 22 L25 14 Z", AETHER, "#1d5b73") + path("M20 14 A12 4 0 1 0 44 14 A12 4 0 1 0 20 14", GOLD)
    + path("M18 58 L26 34 M46 58 L38 34", IVORY),
    "strike": path("M36 4 L22 30 L32 30 L26 60 L44 24 L34 24 L40 4 Z", GOLD, "#4a3a18")
    + path("M10 58 C18 50 46 50 54 58", RED, sw=2.6),
    "cancel": path("M16 16 L48 48 M48 16 L16 48", RED, sw=5),
    "construct": path("M10 54 L30 34 M34 10 L54 30 L44 40 L24 20 Z", IVORY, "#2a3040") + path("M8 58 L58 58", GOLD),
    "units": circle(24, 20, 7) + path("M12 50 L16 32 L32 32 L36 50") + circle(44, 24, 6, GOLD) + path("M36 52 L38 36 L52 36 L54 52", GOLD),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in ICONS.items():
        (OUT / (name + ".svg")).write_text(svg(body, 128), encoding="utf-8")
    print("icons:", len(ICONS))


if __name__ == "__main__":
    main()
