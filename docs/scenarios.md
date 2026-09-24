# シナリオの作り方

シナリオは JSON ファイル1つで、使うマップ、最初の部隊、目標、試合中のイベントを書きます。
内蔵のシナリオ（`game/scenarios/`）も同じ形式なので、実例として参照してください。
「アイアンスパインの門」は時刻で来る攻撃波、「北の中継塔」は占領からの時間制限と `map_start: false` での配置、「鉄の潮」は複数方向からの攻勢の例です。

## 置き場所と確認

- 自作シナリオは、タイトル → シナリオ → 「フォルダを開く」で開く場所に `.json` を置きます。
  Linux では `~/.local/share/godot/app_userdata/Aether Crown- Ironspine/scenarios/` です。
- 一覧は「再読み込み」で更新されます。書き方に誤りがあると、一覧にどこが悪いかが表示されます。
- まとめて確認するには: `godot --headless --path game -- --check-scenarios`（誤りがあると終了コード 1）
- 特定のシナリオで起動するには: `godot --path game -- --match --mission=<ファイルのパス>`

## 最小の例

```json
{
	"id": "bridge_duel",
	"title": "橋の決闘",
	"description": "中央の橋でヴァルケシュの歩行機を3機倒せ。",
	"map": "ironspine",
	"map_start": false,
	"start": {
		"units": [
			{"id": "walker", "team": 0, "at": [-40, 40], "facing": 135},
			{"id": "aetherguard", "team": 0, "at": [-48, 44], "facing": 135}
		]
	},
	"objectives": {"title": "Bridge Duel", "list": [
		{"id": "kill", "text": "敵の歩行機を倒す（残り {units:1:duel}）"}
	]},
	"triggers": [
		{"id": "go", "when": {"type": "time", "at": 5}, "do": [
			{"type": "spawn", "team": 1, "units": {"walker": 3}, "at": [30, -30], "facing": -135, "tag": "duel",
			 "order": "attack_move", "target": [-40, 40]},
			{"type": "banner", "title": "DUEL", "text": "橋を守れ。"}
		]},
		{"id": "win", "when": {"type": "all", "of": [
			{"type": "fired", "trigger": "go"},
			{"type": "units", "team": 1, "tag": "duel", "cmp": "==", "value": 0}
		]}, "do": [
			{"type": "objective", "id": "kill", "state": "done"},
			{"type": "victory"}
		]}
	],
	"defeat": {"type": "units", "team": 0, "cmp": "==", "value": 0}
}
```

## 全体の項目

| 項目 | 内容 |
|---|---|
| `id` `title`（必須） | 識別名と一覧に出す名前。`subtitle` `description` は一覧の補足。 |
| `order` | 一覧での並び順（小さいほど上、既定 100）。 |
| `next` | 勝利画面の「次のミッションへ」で始めるシナリオ（同じフォルダのファイル名。`.json` は省略可）。 |
| `victory_text` `defeat_text` | 勝利画面・敗北画面の一文。 |
| `map`（必須） | 今は `"ironspine"` のみ。 |
| `map_start` | `false` にするとマップの初期配置（本拠地・兵舎・初期部隊）を置かない。都市と城門は常に置かれる。 |
| `teams` | `{"0": {...}, "1": {...}}`。`material` `aether` で初期資源、チーム 1 の `aggression` で敵 AI の攻撃性（0 で攻めてこない、1 が標準）。 |
| `start` | 追加で置く `units` と `buildings` の配列（書き方は下の spawn_building と同じ。ユニットは `id` `team` `at` `facing` `tag`）。 |
| `vars` | シナリオ用の数値の変数と初期値。 |
| `objectives` | 右上の目標欄。`title` `subtitle` と `list`（`id` `text`、条件付きなら `done_when` `failed_when`）。 |
| `triggers` | イベントの配列。`id`、`when`（条件）、`do`（アクションの配列）。既定は1回だけ。`"repeat": true` と `cooldown`（秒）で繰り返す。 |
| `victory` `defeat` | 勝敗の条件。省略すると「最初に本拠地を持つ側は、それを失うと負け」。アクションの victory / defeat でも終えられる。 |

座標は `[x, z]`（メートル、-200〜200）。王冠の本拠地は南西 `[-152, 152]`、ヴァルケシュの本拠地は北東 `[152, -152]`、
アイアンスパイン門は `[-51.5, 51.5]`、中央ネクサスは `[0, 0]`。チームは 0 が王冠（プレイヤー）、1 がヴァルケシュ。

## 条件（`when` `done_when` `failed_when` `victory` `defeat`）

数を比べる条件は `cmp`（`>=` `>` `<=` `<` `==` `!=`、既定 `>=`）と `value`（既定 1）を使います。

| type | 意味 | 項目 |
|---|---|---|
| `time` | 開始から `at` 秒たった（`since` にトリガーの id を書くと、そのトリガーから `at` 秒後） | `at`、`since` |
| `var` | 変数の値 | `name` |
| `units` | 生きているユニットの数 | 絞り込み: `team` `id` `tag` `area`（`[x, z, 半径]`） |
| `buildings` | 建物の数 | 絞り込み: `team` `id` `tag` `area` |
| `sites` | 都市の数 | `team`（持ち主）、`id`（特定の都市） |
| `resource` | 資源の量 | `team`、`kind`（`material` か `aether`） |
| `fired` | そのトリガーがすでに起きた | `trigger` |
| `objective` | 目標の状態 | `id`、`state`（既定 `done`） |
| `all` `any` | すべて／どれかが成り立つ | `of`（条件の配列） |
| `not` | 成り立たない | `of`（条件1つ） |

## アクション（`do`）

| type | 内容 | 項目 |
|---|---|---|
| `message` | 左の通知欄に表示（`at` があれば Space でその場所へ）。`touch_text` はタッチ操作のときに `text` の代わりに出す | `text`、`at`、`sound`、`touch_text` |
| `banner` | 画面中央の大見出し | `title`、`text`、`seconds` |
| `advisor` | 右下の標語 | `text` |
| `spawn` | ユニットを出す | `team`、`units`（`{"walker": 2}`）、`at`、`facing`（度）、`columns` `spacing` `rotate`（隊形）、`tag`、`difficulty_scale`（難易度で数を 0.75〜1.35 倍）、`order` `target` `spread` |
| `spawn_building` | 建物を置く | `team`、`id`、`at`、`facing`、`built`（false で建設途中）、`tag` |
| `order` | 条件に合うユニットに命令 | `order`（`move` `attack_move` `patrol` `hold`）、`target`、`spread`、絞り込み `team` `id` `tag` `area` |
| `resources` | 資源を増やす（負の数で減らす） | `team`、`material`、`aether` |
| `ai` | 敵 AI の攻撃性を変える | `aggression` |
| `objectives` / `objective` | 目標欄を差し替える／1つの状態を変える | `title` `subtitle` `list` ／ `id` `state`（`open` `done` `failed`） |
| `set_var` / `add_var` | 変数を設定／加算 | `name`、`value` |
| `focus` | Space キーで飛ぶ場所 | `at` |
| `sound` | 効果音 | `name`（`alert` `objective` `capture` `build_done` `unit_ready` `special` など） |
| `site` | 都市の持ち主を変える（通知なし。開始時の設定に使う） | `id`、`team`（-1 で中立） |
| `victory` / `defeat` | 勝利／敗北で終える | なし |

文章の中の `{var:名前}` は変数の値、`{countdown:秒}` はその時刻までの残り時間（分:秒）、`{timer:トリガー:秒}` はそのトリガーから数えた残り時間、
`{sites:チーム}` はそのチームの都市の数、
`{units:チーム}` `{units:チーム:タグ}` はそのチーム（とタグ）の生きているユニットの数に置き換わります。
条件付きの目標は条件に合わせて状態が毎回変わり、条件のない目標はアクションで設定した状態を保ちます。

## 使える ID

- ユニット: `aetherguard`（歩兵）、`artificer`（工兵）、`walker`（歩行機）、`mortar`（臼砲）、`airship`（飛行艦）、
  `cerberus`（ケルベロス）、`cyclops`（サイクロプス）、`griffin`（グリフォン）、`dragon`（ドラゴン）、`demon`（悪魔）、`angel`（天使）、`mech`（機動兵）
- 建物: `citadel` `barracks` `foundry` `skyport` `refinery` `habitat` `bastion` `sanctum_cerberus` `sanctum_cyclops` `sanctum_griffin` `sanctum_dragon` `sanctum_demon` `sanctum_angel`（種類ごとの祠） `judgement`（天罰の塔） `gate`。`sanctum` は全種を呼べる旧版の祠で、建設メニューには出ない
- 都市: `central_nexus` `brassholm` `west_foundry` `south_works` `aether_works` `east_bastion` `north_relay`
