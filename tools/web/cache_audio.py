#!/usr/bin/env python3
"""Precache Web audio and keep the Godot PWA shell fresh after deployments."""
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
code = path.read_text(encoding="utf-8")
replacements = [
    (
        '"index.audio.position.worklet.js"];',
        '"index.audio.position.worklet.js","audio_bridge.js","audio/music_battle.mp3","audio/amb_wind.mp3","audio/amb_battle.mp3"];',
    ),
    (
        "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));",
        "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)).then(() => self.skipWaiting()));",
    ),
    (
        "\t).then(function () {\n\t\t// Enable navigation preload",
        "\t).then(() => self.clients.claim()).then(function () {\n\t\t// Enable navigation preload",
    ),
    (
        "\t\tconst isNavigate = event.request.mode === 'navigate';",
        "\t\tconst isNavigate = event.request.mode === 'navigate';\n"
        "\t\t// Always fetch the current HTML. Cached shells can load a newer PCK\n"
        "\t\t// without its matching script tags after a deployment.\n"
        "\t\tif (isNavigate) {\n"
        "\t\t\tevent.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));\n"
        "\t\t\treturn;\n"
        "\t\t}",
    ),
]
for old, new in replacements:
    if code.count(old) != 1:
        raise SystemExit("Unexpected Godot service worker; check PWA cache before publishing")
    code = code.replace(old, new, 1)
path.write_text(code, encoding="utf-8")
