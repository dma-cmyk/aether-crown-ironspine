# Aether Crown: Ironspine

工業と魔導（エーテル）が交わる大地を舞台にした、Godot 4 製の3Dクォータービュー RTS です。
渓谷に架かるアイアンスパイン門を守り抜き、中央ネクサスを奪って、ヴァルケシュ本拠地を破壊します。

![戦闘](docs/screenshots/battle_bridge.png)

| タイトル | 戦闘画面 |
|---|---|
| ![タイトル](docs/screenshots/title.png) | ![HUD](docs/screenshots/hud.png) |

## 起動

```bash
./run.sh            # 初回は自動でアセットをインポートしてから起動
# または
godot --path game
```

- 必要なもの: Godot 4.7（`godot` コマンド）。
- 画質は タイトル → 設定 で「低 / 中 / 高」。内蔵 GPU では「中」で約 50fps（大規模な戦闘中は約 37fps）、「低」で約 65fps（同 約 50fps）。1600x900、Intel Iris Xe、100Hz の垂直同期ありで計測。
- F11 でフルスクリーン切替。

## 遊び方

**キャンペーン（3ミッション）と自由戦**

| ミッション | 内容 |
|---|---|
| アイアンスパインの門 | 4回の攻撃波から門を守り、援軍と合流して敵本拠地を破壊する |
| 北の中継塔 | 前線から北の中継塔を奪い、反撃に耐えて3分間守り抜く |
| 鉄の潮 | 3方向から来る8回の攻勢に耐え、12分間本拠地を守り抜く |
| 自由戦 | 台本なしの通常対戦（敵 AI は最初から攻めてくる） |

勝利すると「次のミッションへ」で続きに進めます。タイトルの「シナリオ」からはどのミッションも選べます。

**第1ミッション「アイアンスパインの門」の流れ**

1. 開始から約5分半、ヴァルケシュ軍が中央の橋から4回攻めてくる。アイアンスパイン門の前で迎え撃つ。
2. 援軍（歩行機・飛行艦など）が到着したら、中央ネクサスを占領する。
3. 橋の先のヴァルケシュ本拠地（北東）を破壊すれば勝利。自軍の本拠地を失うと敗北。

都市のリレー塔の輪に地上部隊を置くと占領でき、資材・エーテル・人口上限が増えます（工兵は占領が速い）。

| 操作 | 内容 |
|---|---|
| 左クリック / 左ドラッグ | 選択（Shift で追加、ダブルクリックで同種を全選択） |
| 右クリック | 移動・攻撃・修理（建物選択中は集結地点）。Shift で経由地点 |
| M / H / A / P | 移動 / 陣地保持 / 攻撃移動 / 巡回 |
| F / R / D / S | 構え / 修理 / 展開（臼砲の射程延長） / 特殊能力 |
| Q W E R T Y | 選択中の建物で生産（本拠地は B で建設メニュー） |
| Ctrl+数字 / 数字 | 部隊登録 / 呼び出し |
| 矢印・画面端・ホイール・中ドラッグ | カメラ移動・ズーム・回転 |
| Home / Space / F1 / F2 / F3 / Esc | 本拠地 / 最新の警報 / 待機ユニット / 全戦闘部隊 / FPS 表示 / メニュー |

ゲーム内の「操作説明」にも同じ内容があります。

## 自作シナリオ

タイトルの「シナリオ」から、内蔵のミッションと自作のシナリオを選んで遊べます。
シナリオは JSON ファイル1つで、マップ・初期部隊・目標・試合中のイベント（「5分たったら援軍」など）を書きます。
書き方は [docs/scenarios.md](docs/scenarios.md)、実例は内蔵の `game/scenarios/hold_the_gate.json` です。

## 構成

```
game/                  Godot プロジェクト（Mobile レンダラー、GDScript）
  data/map_ironspine.json   マップ設計（地形・道・橋・都市・初期配置）の唯一の元データ
  scenarios/           内蔵シナリオ（ミッションの進行・目標・イベント）
  scripts/core|units|buildings|combat|ai|ui|world   ゲームロジックと UI
  shaders/             地形・水・滝・空・粒子・霧・歩兵の頂点アニメ
  assets/              生成済みアセット（terrain / models / textures / fx / ui / audio）
tools/                 アセット生成スクリプト
  blender/terrain/     地形パイプライン（mapgen.py = numpy で高さ場など、build_terrain.py = Blender で .blend/.glb 化）
  blender/models/      環境プロップ・建物・ユニットの手続きモデリング
  textures/            Material Maker（CLI 書き出し）＋ ImageMagick
  ui/make_icons.py     HUD アイコン（SVG）
  audio/gen_audio.py   効果音・環境音・BGM の合成（numpy）
art/blend/             生成された .blend（Blender で開いて確認・編集できる）
docs/                  設計メモとスクリーンショット
```

地形は「Blender Python 地形生成スクリプト → .blend → .glb → Godot」の順に作られます。
高さ場・歩行可能グリッド・地表スプラット・ミニマップ・木や街の配置も同じスクリプトから出力されます。

## アセットの再生成

```bash
tools/build_all.sh            # すべて再生成して Godot へ再インポート
tools/build_all.sh terrain    # 段階を指定: terrain | models | textures | fx | icons | audio | import
```

使用ツール: Blender 5.2、Material Maker 1.7、ImageMagick 7、Inkscape（アイコン確認）、uv（音声合成）、Godot 4.7。
Material Maker は CLI 書き出し後も終了しないため、`build_textures.sh` は出力ファイルを待ってから終了させています。

## 開発用オプション

```bash
# 画面を撮影して終了（平均 FPS と GPU 時間も表示）
godot --path game -- --capture=x --out=/tmp/x.png --frames=400 [--cam=x,z,yaw,dist] [--scenario=showcase] [--quality=0..2]
# プレイヤー側をボットが操作し、ミッションを早回しで最後まで流す（ヘッドレス可）
godot --headless --path game -- --match --autoplay --timescale=10
# 全モデルの確認用ギャラリー
godot --path game -- --gallery=all --out=/tmp/gallery.png
# シナリオファイルの検証（誤りがあると終了コード 1）
godot --headless --path game -- --check-scenarios
```

設計の詳細は [docs/design.md](docs/design.md) を参照。
