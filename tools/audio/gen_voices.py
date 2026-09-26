"""Generate the trial unit responses with a locally running VOICEVOX Nemo engine.

Run: uv run tools/audio/gen_voices.py
The engine's HTTP API must be listening on 127.0.0.1:50021.
Generated voices are credited in README.md and THIRD-PARTY-NOTICES.txt.
"""

import json
import pathlib
import subprocess
import tempfile
import urllib.parse
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "audio" / "voices"
ENGINE = "http://127.0.0.1:50021"

# VOICEVOX Nemo 0.24.0: 男声1 for infantry, 男声3 for the walker radio operator.
LINES = {
    "guard_select_1": (10001, "お呼びですか。", 1.08, False),
    "guard_select_2": (10001, "命令をどうぞ。", 1.08, False),
    "guard_move_1": (10001, "了解、移動します。", 1.13, False),
    "guard_move_2": (10001, "指定地点へ向かいます。", 1.13, False),
    "guard_attack_1": (10001, "攻撃を開始します。", 1.14, False),
    "guard_attack_2": (10001, "目標を制圧します。", 1.14, False),
    "walker_select_1": (10002, "歩行機、待機中。", 1.10, True),
    "walker_select_2": (10002, "指示をどうぞ。", 1.10, True),
    "walker_move_1": (10002, "歩行機、前進。", 1.14, True),
    "walker_move_2": (10002, "指定地点へ移動する。", 1.14, True),
    "walker_attack_1": (10002, "目標を捕捉、攻撃する。", 1.16, True),
    "walker_attack_2": (10002, "砲撃を開始する。", 1.16, True),
}


def post(path: str, params: dict, data: bytes = b"", content_type: str = "") -> bytes:
    url = ENGINE + path + "?" + urllib.parse.urlencode(params)
    headers = {"Content-Type": content_type} if content_type else {}
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def generate(name: str, speaker: int, line: str, speed: float, radio: bool) -> None:
    query = json.loads(post("/audio_query", {"speaker": speaker, "text": line}))
    query["speedScale"] = speed
    query["prePhonemeLength"] = 0.04
    query["postPhonemeLength"] = 0.10
    query["outputSamplingRate"] = 24000
    query["outputStereo"] = False
    wav = post("/synthesis", {"speaker": speaker}, json.dumps(query).encode("utf-8"), "application/json")
    if radio:
        # ffmpeg writes unknown RIFF/data lengths to a pipe, which Godot cannot import.
        with tempfile.TemporaryDirectory() as temp_dir:
            processed = pathlib.Path(temp_dir) / "radio.wav"
            subprocess.run(
                ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0",
                 "-af", "highpass=f=230,lowpass=f=3100,acompressor=threshold=-18dB:ratio=2.2:attack=6:release=55",
                 "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", str(processed)],
                input=wav, capture_output=True, check=True,
            )
            wav = processed.read_bytes()
    (OUT / f"{name}.wav").write_bytes(wav)
    print(f"wrote {name}.wav: {line}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (speaker, line, speed, radio) in LINES.items():
        generate(name, speaker, line, speed, radio)


if __name__ == "__main__":
    main()
