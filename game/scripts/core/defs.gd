class_name Defs
extends RefCounted
## Balance and content tables. Incomes are per minute, times in seconds.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const TEAM_NEUTRAL := -1

const FACTIONS := {
	0: {"name": "The Crown", "short": "Crown", "color": Color(0.30, 0.56, 1.0), "glow": Color(0.35, 0.85, 1.0), "cloth": Color(0.11, 0.20, 0.50)},
	1: {"name": "Varkesh Dominion", "short": "Varkesh", "color": Color(0.95, 0.28, 0.22), "glow": Color(1.0, 0.36, 0.18), "cloth": Color(0.46, 0.07, 0.06)},
	-1: {"name": "Neutral", "short": "Neutral", "color": Color(0.8, 0.8, 0.78), "glow": Color(0.9, 0.85, 0.7), "cloth": Color(0.4, 0.38, 0.34)},
}

# Damage multipliers: weapon class -> armor class
const ARMOR_TABLE := {
	"rifle": {"light": 1.0, "heavy": 0.3, "structure": 0.25, "air": 0.55},
	"pistol": {"light": 0.8, "heavy": 0.2, "structure": 0.2, "air": 0.2},
	"cannon": {"light": 0.75, "heavy": 1.25, "structure": 1.2, "air": 0.0},
	"gatling": {"light": 1.15, "heavy": 0.35, "structure": 0.3, "air": 0.9},
	"shell": {"light": 1.1, "heavy": 0.85, "structure": 1.5, "air": 0.0},
	"broadside": {"light": 0.9, "heavy": 1.0, "structure": 1.25, "air": 0.4},
	"flak": {"light": 0.3, "heavy": 0.3, "structure": 0.1, "air": 1.6},
	"lance": {"light": 0.8, "heavy": 1.3, "structure": 1.0, "air": 1.0},
}

const WEAPONS := {
	"rifle_volley": {"class": "rifle", "range": 26.0, "damage": 3.4, "cooldown": 1.5, "fx": "tracer", "air": true, "per_member": true},
	"artificer_pistol": {"class": "pistol", "range": 16.0, "damage": 2.2, "cooldown": 1.3, "fx": "tracer", "air": false, "per_member": true},
	"walker_cannon": {"class": "cannon", "range": 34.0, "damage": 70.0, "cooldown": 3.0, "fx": "shell_flat", "splash": 3.5, "air": false, "muzzle": "cannon"},
	"walker_gatling": {"class": "gatling", "range": 24.0, "damage": 7.5, "cooldown": 0.22, "fx": "tracer", "air": true, "muzzle": "gatling"},
	"mortar_shell": {"class": "shell", "range": 46.0, "deployed_range": 72.0, "min_range": 12.0, "damage": 95.0, "cooldown": 5.2, "fx": "shell_arc", "splash": 5.5, "air": false, "muzzle": "mortar"},
	"broadside": {"class": "broadside", "range": 30.0, "damage": 46.0, "cooldown": 2.4, "fx": "shell_flat", "splash": 3.0, "air": false, "muzzle": "cannon"},
	"flak": {"class": "flak", "range": 32.0, "damage": 18.0, "cooldown": 0.7, "fx": "tracer", "air": true, "air_only": true, "muzzle": "gatling"},
	"tower_cannon": {"class": "cannon", "range": 38.0, "damage": 52.0, "cooldown": 2.3, "fx": "shell_flat", "splash": 3.0, "air": false, "muzzle": "cannon"},
	"aether_lance": {"class": "lance", "range": 40.0, "damage": 60.0, "cooldown": 3.2, "fx": "beam", "air": true, "muzzle": "aether"},
}

const UNITS := {
	"aetherguard": {
		"name": ["Aetherguard Infantry", "Varkesh Raiders"],
		"desc": ["Disciplined. Unyielding.", "Iron and hunger."],
		"jp": "戦列歩兵。対歩兵・対空に強く、構えで守りを固める。",
		"type": "squad", "members": 8, "member_hp": 22.0, "armor": "light",
		"cost": {"material": 90, "aether": 0}, "pop": 4, "build_time": 16.0,
		"speed": 5.4, "radius": 3.2, "vision": 34.0, "weapons": ["rifle_volley"],
		"model": "aetherguard", "commands": ["move", "hold", "attack", "patrol", "fortify", "deploy", "special"],
		"special": "aether_volley", "capture": 1.0, "hotkey": "Q",
	},
	"artificer": {
		"name": ["Artificer Corps", "Varkesh Wrights"],
		"desc": ["Mend, build, endure.", "Scrap becomes steel."],
		"jp": "工兵。建物と機械ユニットを修理し、拠点を素早く占領する。",
		"type": "squad", "members": 4, "member_hp": 20.0, "armor": "light",
		"cost": {"material": 70, "aether": 0}, "pop": 2, "build_time": 12.0,
		"speed": 5.6, "radius": 2.4, "vision": 30.0, "weapons": ["artificer_pistol"],
		"model": "artificer", "commands": ["move", "hold", "attack", "patrol", "repair", "special"],
		"special": "field_repair", "capture": 1.8, "repair_rate": 16.0, "hotkey": "W",
	},
	"walker": {
		"name": ["Ironclad Walker", "Varkesh Juggernaut"],
		"desc": ["The ground shakes where the Crown marches.", "A furnace on legs."],
		"jp": "重装歩行機。大砲と機関砲を持つ主力。建物と装甲に強い。",
		"type": "walker", "hp": 950.0, "armor": "heavy",
		"cost": {"material": 320, "aether": 120}, "pop": 8, "build_time": 38.0,
		"speed": 3.6, "radius": 4.5, "vision": 40.0, "weapons": ["walker_cannon", "walker_gatling"],
		"model": "walker", "commands": ["move", "hold", "attack", "patrol", "fortify", "special"],
		"special": "overcharge", "capture": 0.6, "hotkey": "E",
	},
	"mortar": {
		"name": ["Thunder Mortar", "Varkesh Bombard"],
		"desc": ["Patience, then thunder.", "Walls are only a suggestion."],
		"jp": "自走臼砲。展開すると射程が大きく伸びる。近距離は撃てない。",
		"type": "vehicle", "hp": 340.0, "armor": "heavy",
		"cost": {"material": 220, "aether": 60}, "pop": 5, "build_time": 26.0,
		"speed": 4.0, "radius": 3.0, "vision": 30.0, "weapons": ["mortar_shell"],
		"model": "mortar", "commands": ["move", "hold", "attack", "patrol", "deploy"],
		"special": "", "capture": 0.5, "hotkey": "R",
	},
	"airship": {
		"name": ["Crown Skyfrigate", "Varkesh Warbarge"],
		"desc": ["Above the smoke, the Crown sees all.", "Its shadow arrives first."],
		"jp": "飛行艦。地形を無視して移動し、舷側砲で地上を砲撃する。",
		"type": "air", "hp": 760.0, "armor": "air",
		"cost": {"material": 380, "aether": 200}, "pop": 10, "build_time": 45.0,
		"speed": 6.2, "radius": 6.0, "vision": 56.0, "weapons": ["broadside", "flak"],
		"model": "airship", "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "aether_bombard", "capture": 0.0, "altitude": 26.0, "hotkey": "T",
	},
}

const BUILDINGS := {
	"citadel": {
		"name": ["Crown Citadel", "Varkesh Citadel"], "desc": ["Heart of the Crown.", "Seat of the Dominion."],
		"jp": "本拠地。工兵を生産し、収入と人口上限を与える。破壊されると敗北。",
		"hp": 5200.0, "radius": 13.0, "footprint": 12.0, "cost": {"material": 0, "aether": 0}, "build_time": 1.0,
		"produces": ["artificer"], "pop": 20, "income": {"material": 150, "aether": 45},
		"model": "citadel", "weapons": ["aether_lance"], "buildable": false, "vision": 50.0,
	},
	"barracks": {
		"name": ["Garrison Hall", "Varkesh Warcamp"], "desc": ["Where oaths are forged.", "Where the hungry are armed."],
		"jp": "兵舎。歩兵と工兵を生産する。",
		"hp": 1500.0, "radius": 8.5, "footprint": 8.0, "cost": {"material": 150, "aether": 0}, "build_time": 24.0,
		"produces": ["aetherguard", "artificer"], "pop": 0, "model": "barracks", "buildable": true, "hotkey": "Q", "vision": 30.0,
	},
	"foundry": {
		"name": ["Gearworks Foundry", "Varkesh Forge"], "desc": ["Steel, steam and faith.", "Fire that never sleeps."],
		"jp": "工廠。歩行機と臼砲を生産する。",
		"hp": 1900.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 250, "aether": 60}, "build_time": 34.0,
		"produces": ["walker", "mortar"], "pop": 0, "model": "foundry", "buildable": true, "hotkey": "W", "vision": 30.0,
	},
	"skyport": {
		"name": ["Aerodrome Spire", "Varkesh Skydock"], "desc": ["The sky is Crown territory.", "Chains for the clouds."],
		"jp": "飛行場。飛行艦を生産する。",
		"hp": 1600.0, "radius": 8.5, "footprint": 8.0, "cost": {"material": 300, "aether": 150}, "build_time": 40.0,
		"produces": ["airship"], "pop": 0, "model": "skyport", "buildable": true, "hotkey": "E", "vision": 40.0,
	},
	"refinery": {
		"name": ["Aether Refinery", "Varkesh Siphon"], "desc": ["Light, distilled.", "Drink the sky dry."],
		"jp": "精製所。エーテル収入を増やす。",
		"hp": 950.0, "radius": 6.0, "footprint": 6.0, "cost": {"material": 120, "aether": 0}, "build_time": 20.0,
		"produces": [], "pop": 0, "income": {"material": 0, "aether": 60}, "model": "refinery", "buildable": true, "hotkey": "R", "vision": 24.0,
	},
	"habitat": {
		"name": ["Habitation Block", "Varkesh Barracks-Pit"], "desc": ["Every hearth a soldier.", "Crowded and loyal."],
		"jp": "居住区。人口上限を増やす。",
		"hp": 850.0, "radius": 6.0, "footprint": 6.0, "cost": {"material": 100, "aether": 0}, "build_time": 15.0,
		"produces": [], "pop": 15, "model": "habitat", "buildable": true, "hotkey": "T", "vision": 22.0,
	},
	"bastion": {
		"name": ["Bastion Tower", "Varkesh Spike"], "desc": ["Hold the line.", "Nothing passes."],
		"jp": "防衛塔。近づく敵を砲撃する。",
		"hp": 1300.0, "radius": 4.5, "footprint": 4.5, "cost": {"material": 180, "aether": 40}, "build_time": 24.0,
		"produces": [], "pop": 0, "model": "bastion", "weapons": ["tower_cannon"], "buildable": true, "hotkey": "Y", "vision": 42.0,
	},
	"gate": {
		"name": ["Ironspine Gate", "Varkesh Gate"], "desc": ["Ironspine stands.", "The red door."],
		"jp": "橋頭の城門。二門の砲で橋を守る。",
		"hp": 5000.0, "radius": 11.0, "footprint": 0.0, "cost": {"material": 0, "aether": 0}, "build_time": 1.0,
		"produces": [], "pop": 0, "model": "gate", "weapons": ["tower_cannon", "tower_cannon"], "buildable": false, "vision": 46.0,
	},
}

const BUILD_ORDER := ["barracks", "foundry", "skyport", "refinery", "habitat", "bastion"]

const SPECIALS := {
	"aether_volley": {"name": "Aether Volley", "jp": "エーテル弾：8秒間、射撃速度2倍・装甲貫通。", "cooldown": 40.0, "duration": 8.0},
	"field_repair": {"name": "Field Repair", "jp": "応急修理：周囲の味方機械・建物を即座に回復。", "cooldown": 35.0, "duration": 0.0},
	"overcharge": {"name": "Overcharge", "jp": "過負荷：10秒間、速度と連射が上昇。", "cooldown": 45.0, "duration": 10.0},
	"aether_bombard": {"name": "Aether Bombard", "jp": "エーテル爆撃：指定地点へ爆撃を投下。", "cooldown": 50.0, "duration": 0.0, "targeted": true},
}

const COMMANDS := {
	"move": {"label": "MOVE", "key": "M", "jp": "移動：指定地点へ移動（右クリックでも可）"},
	"hold": {"label": "HOLD", "key": "H", "jp": "待機：その場で停止し、射程内の敵だけを撃つ"},
	"attack": {"label": "ATTACK", "key": "A", "jp": "攻撃移動：進路上の敵と交戦しながら進む"},
	"patrol": {"label": "PATROL", "key": "P", "jp": "巡回：現在地と指定地点を往復する"},
	"fortify": {"label": "FORTIFY", "key": "F", "jp": "構え：移動不可になる代わりに被ダメージ半減・射程増加"},
	"repair": {"label": "REPAIR", "key": "R", "jp": "修理：味方の建物・機械ユニットを修理する"},
	"deploy": {"label": "DEPLOY", "key": "D", "jp": "展開：臼砲は射程延長、歩兵は土嚢を築いて防御"},
	"special": {"label": "SPECIAL", "key": "S", "jp": "特殊能力"},
}


static func unit_name(id: String, team: int) -> String:
	var d: Dictionary = UNITS[id]
	return d["name"][1 if team == TEAM_ENEMY else 0]


static func unit_desc(id: String, team: int) -> String:
	var d: Dictionary = UNITS[id]
	return d["desc"][1 if team == TEAM_ENEMY else 0]


static func building_name(id: String, team: int) -> String:
	var d: Dictionary = BUILDINGS[id]
	return d["name"][1 if team == TEAM_ENEMY else 0]


static func building_desc(id: String, team: int) -> String:
	var d: Dictionary = BUILDINGS[id]
	return d["desc"][1 if team == TEAM_ENEMY else 0]


static func team_color(team: int) -> Color:
	return FACTIONS.get(team, FACTIONS[-1])["color"]


static func team_glow(team: int) -> Color:
	return FACTIONS.get(team, FACTIONS[-1])["glow"]


static func damage_mult(weapon_class: String, armor: String) -> float:
	return ARMOR_TABLE.get(weapon_class, {}).get(armor, 1.0)
