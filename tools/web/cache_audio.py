#!/usr/bin/env python3
"""Precache the external Web audio needed by the Godot PWA."""
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
code = path.read_text(encoding="utf-8")
old = '"index.audio.position.worklet.js"];'
new = '"index.audio.position.worklet.js","audio_bridge.js","audio/music_battle.mp3","audio/amb_wind.mp3","audio/amb_battle.mp3"];'
if code.count(old) != 1:
    raise SystemExit("Unexpected Godot service worker; check PWA cache before publishing")
path.write_text(code.replace(old, new, 1), encoding="utf-8")
