"""Generate distinct unit responses with a locally running VOICEVOX Nemo engine.

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

# VOICEVOX Nemo 0.24.0: three male and six female voices. Every unit has its own
# combination of speaker, delivery, pitch and acoustic treatment.
PROFILES = {
    "aetherguard": {
        "speaker": 10001, "speed": 1.08, "pitch": 1.0, "effect": "plain",
        "select": ("お呼びですか。", "命令をどうぞ。"),
        "move": ("了解、移動します。", "指定地点へ向かいます。"),
        "attack": ("攻撃を開始します。", "目標を制圧します。"),
    },
    "artificer": {
        "speaker": 10005, "speed": 1.13, "pitch": 1.02, "effect": "field",
        "select": ("工兵隊、準備よし。", "修理のご用命ですか。"),
        "move": ("現場へ急ぎます。", "工具を持って行きます。"),
        "attack": ("障害を排除します。", "援護射撃します。"),
    },
    "walker": {
        "speaker": 10002, "speed": 1.10, "pitch": 1.0, "effect": "radio",
        "select": ("歩行機、待機中。", "指示をどうぞ。"),
        "move": ("歩行機、前進。", "指定地点へ移動する。"),
        "attack": ("目標を捕捉、攻撃する。", "砲撃を開始する。"),
    },
    "mortar": {
        "speaker": 10000, "speed": 1.02, "pitch": 0.94, "effect": "radio",
        "select": ("臼砲隊、待機中。", "射撃指示を待つ。"),
        "move": ("陣地を移す。", "砲を牽引する。"),
        "attack": ("座標を確認、撃て。", "砲撃、開始。"),
    },
    "airship": {
        "speaker": 10007, "speed": 1.08, "pitch": 1.0, "effect": "captain",
        "select": ("飛行艦、航行中。", "艦長、指示をどうぞ。"),
        "move": ("進路を変更します。", "風を捉えて向かいます。"),
        "attack": ("舷側砲、撃ち方始め。", "敵艦を捉えました。"),
    },
    "titan": {
        "speaker": 10000, "speed": 0.95, "pitch": 0.78, "effect": "heavy",
        "select": ("巨神、目覚めた。", "命を告げよ。"),
        "move": ("大地を進む。", "そこへ向かおう。"),
        "attack": ("光を放つ。", "敵を焼き払う。"),
    },
    "mech": {
        "speaker": 10004, "speed": 1.16, "pitch": 1.02, "effect": "synthetic",
        "select": ("機体、起動中。", "指示を待機。"),
        "move": ("巡航に移る。", "目標へ接近。"),
        "attack": ("照準、固定。", "ミサイルを放つ。"),
    },
    "strider": {
        "speaker": 10001, "speed": 1.18, "pitch": 1.09, "effect": "radio",
        "select": ("疾走機、準備よし。", "すぐに走れる。"),
        "move": ("一気に駆ける。", "先行する。"),
        "attack": ("敵を捉えた。", "走りながら撃つ。"),
    },
    "quadwalker": {
        "speaker": 10002, "speed": 0.98, "pitch": 0.87, "effect": "radio",
        "select": ("四脚砲、配置よし。", "砲身、安定。"),
        "move": ("重砲を移す。", "四脚、前進。"),
        "attack": ("二門とも発射する。", "標的を砕く。"),
    },
    "dreadnought": {
        "speaker": 10003, "speed": 0.98, "pitch": 0.97, "effect": "captain",
        "select": ("空中戦艦、応答。", "全砲門、待機中。"),
        "move": ("艦隊を進めます。", "航路を合わせて。"),
        "attack": ("全砲門、敵を狙え。", "砲撃を始めます。"),
    },
    "colossus": {
        "speaker": 10001, "speed": 0.91, "pitch": 0.73, "effect": "heavy",
        "select": ("鋼の巨兵、起動。", "命令を受けた。"),
        "move": ("重脚、前進。", "進路を確保する。"),
        "attack": ("エーテル砲、充填。", "目標を貫く。"),
    },
    "cerberus": {
        "speaker": 10002, "speed": 1.13, "pitch": 0.82, "effect": "beast",
        "select": ("主の声だ。", "我ら、待つ。"),
        "move": ("狩りに出る。", "駆けるぞ。"),
        "attack": ("牙を立てる。", "食らい尽くす。"),
    },
    "cyclops": {
        "speaker": 10000, "speed": 0.93, "pitch": 0.83, "effect": "beast",
        "select": ("誰を潰す。", "命じろ。"),
        "move": ("そこへ行く。", "岩を越える。"),
        "attack": ("砕いてやる。", "敵、見つけた。"),
    },
    "griffin": {
        "speaker": 10008, "speed": 1.16, "pitch": 1.08, "effect": "wing",
        "select": ("翼は備えた。", "風が呼ぶ。"),
        "move": ("空へ。", "ひと飛びだ。"),
        "attack": ("爪を立てる。", "獲物を捉えた。"),
    },
    "dragon": {
        "speaker": 10001, "speed": 0.91, "pitch": 0.76, "effect": "flame",
        "select": ("我を呼んだか。", "聞いている。"),
        "move": ("空を支配する。", "炎を運ぶ。"),
        "attack": ("燃え尽きよ。", "灰となれ。"),
    },
    "demon": {
        "speaker": 10002, "speed": 0.94, "pitch": 0.75, "effect": "dark",
        "select": ("契約を聞こう。", "望みを言え。"),
        "move": ("そこへ行こう。", "代償は後だ。"),
        "attack": ("魂を寄越せ。", "業火をくれてやる。"),
    },
    "angel": {
        "speaker": 10006, "speed": 1.03, "pitch": 1.02, "effect": "holy",
        "select": ("お呼びでしょうか。", "あなたを守ります。"),
        "move": ("光のもとへ。", "導きましょう。"),
        "attack": ("邪を払います。", "加護をここに。"),
    },
}
ACTIONS = ("select", "move", "attack")

# Treatments are gentle enough to keep the words intelligible.
FILTERS = {
    "plain": "",
    "field": "highpass=f=130,lowpass=f=6000",
    "radio": "highpass=f=230,lowpass=f=3100,acompressor=threshold=-18dB:ratio=2.2:attack=6:release=55",
    "captain": "highpass=f=150,lowpass=f=4600,acompressor=threshold=-20dB:ratio=1.8:attack=8:release=70",
    "synthetic": "highpass=f=230,lowpass=f=3700,aecho=0.8:0.18:22:0.14",
    "heavy": "lowpass=f=4300,aecho=0.8:0.20:48:0.15",
    "beast": "lowpass=f=4400,aecho=0.8:0.17:35:0.12",
    "wing": "highpass=f=230,lowpass=f=6000,aecho=0.8:0.12:95:0.10",
    "flame": "lowpass=f=3900,aecho=0.8:0.22:75:0.18",
    "dark": "lowpass=f=3900,aecho=0.8:0.25:85:0.20",
    "holy": "highpass=f=160,lowpass=f=6500,aecho=0.8:0.16:125:0.18",
}


def post(path: str, params: dict, data: bytes = b"", content_type: str = "") -> bytes:
    url = ENGINE + path + "?" + urllib.parse.urlencode(params)
    headers = {"Content-Type": content_type} if content_type else {}
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def process(wav: bytes, pitch: float, effect: str) -> bytes:
    filters = []
    if pitch != 1.0:
        filters.append(f"rubberband=pitch={pitch}")
    if FILTERS[effect]:
        filters.append(FILTERS[effect])
    if not filters:
        return wav
    # ffmpeg writes unknown RIFF/data lengths to a pipe; Godot cannot import that WAV.
    with tempfile.TemporaryDirectory() as temp_dir:
        processed = pathlib.Path(temp_dir) / "voice.wav"
        subprocess.run(
            ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0",
             "-af", ",".join(filters), "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", str(processed)],
            input=wav, capture_output=True, check=True,
        )
        return processed.read_bytes()


def generate(unit_id: str, action: str, index: int, profile: dict) -> None:
    speaker = profile["speaker"]
    line = profile[action][index - 1]
    query = json.loads(post("/audio_query", {"speaker": speaker, "text": line}))
    query["speedScale"] = profile["speed"] + (0.04 if action == "attack" else 0.0)
    query["prePhonemeLength"] = 0.04
    query["postPhonemeLength"] = 0.10
    query["outputSamplingRate"] = 24000
    query["outputStereo"] = False
    wav = post("/synthesis", {"speaker": speaker}, json.dumps(query).encode("utf-8"), "application/json")
    wav = process(wav, profile["pitch"], profile["effect"])
    prefix = "guard" if unit_id == "aetherguard" else unit_id
    (OUT / f"{prefix}_{action}_{index}.wav").write_bytes(wav)
    print(f"wrote {prefix}_{action}_{index}.wav: {line}", flush=True)


def main() -> None:
    with urllib.request.urlopen(ENGINE + "/speakers", timeout=20) as response:
        available = {style["id"] for speaker in json.load(response) for style in speaker["styles"]}
    missing = {p["speaker"] for p in PROFILES.values()} - available
    if missing:
        raise RuntimeError(f"VOICEVOX Nemo speaker IDs unavailable: {sorted(missing)}")
    OUT.mkdir(parents=True, exist_ok=True)
    for unit_id, profile in PROFILES.items():
        for action in ACTIONS:
            for index in (1, 2):
                generate(unit_id, action, index, profile)


if __name__ == "__main__":
    main()
