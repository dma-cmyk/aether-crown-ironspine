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

# Damage multipliers: weapon class -> armor class ("beast" = cyclops and cerberus hide)
const ARMOR_TABLE := {
	"rifle": {"light": 1.0, "heavy": 0.3, "structure": 0.25, "air": 0.55, "beast": 0.75},
	"pistol": {"light": 0.8, "heavy": 0.2, "structure": 0.2, "air": 0.2, "beast": 0.45},
	"cannon": {"light": 0.75, "heavy": 1.25, "structure": 1.2, "air": 0.0, "beast": 1.0},
	"gatling": {"light": 1.15, "heavy": 0.35, "structure": 0.3, "air": 0.9, "beast": 0.75},
	"shell": {"light": 1.1, "heavy": 0.85, "structure": 1.5, "air": 0.0, "beast": 0.9},
	"broadside": {"light": 0.9, "heavy": 1.0, "structure": 1.25, "air": 0.4, "beast": 0.9},
	"flak": {"light": 0.3, "heavy": 0.3, "structure": 0.1, "air": 1.6, "beast": 0.3},
	"lance": {"light": 0.8, "heavy": 1.3, "structure": 1.0, "air": 1.0, "beast": 1.1},
	"club": {"light": 1.0, "heavy": 0.9, "structure": 1.6, "air": 0.0, "beast": 1.0},
	"boulder": {"light": 1.0, "heavy": 1.0, "structure": 1.6, "air": 0.0, "beast": 1.0},
	"fang": {"light": 1.2, "heavy": 0.7, "structure": 0.3, "air": 0.0, "beast": 1.0},
	"flame": {"light": 1.35, "heavy": 0.6, "structure": 1.1, "air": 0.5, "beast": 1.0},
	"talon": {"light": 0.8, "heavy": 0.5, "structure": 0.25, "air": 1.6, "beast": 0.9},
	"hellclaw": {"light": 1.2, "heavy": 1.0, "structure": 1.3, "air": 0.0, "beast": 1.0},
	"titan": {"light": 1.2, "heavy": 1.2, "structure": 1.0, "air": 1.0, "beast": 1.1},
	"missile": {"light": 0.35, "heavy": 0.9, "structure": 1.8, "air": 0.0, "beast": 0.7},
	"holy": {"light": 1.0, "heavy": 0.8, "structure": 0.5, "air": 1.2, "beast": 1.35},
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
	# creatures: "delay" is when the blow lands after the attack animation starts
	"cyclops_club": {"class": "club", "range": 6.5, "damage": 95.0, "cooldown": 2.8, "fx": "smash", "splash": 4.5, "delay": 0.6, "air": false},
	"cerberus_bite": {"class": "fang", "range": 3.0, "damage": 11.0, "cooldown": 0.45, "fx": "bite", "air": false},
	"dragon_breath": {"class": "flame", "range": 16.0, "damage": 60.0, "cooldown": 2.4, "fx": "flame", "splash": 5.0, "delay": 0.35, "air": true},
	"griffin_talons": {"class": "talon", "range": 7.0, "damage": 24.0, "cooldown": 0.9, "fx": "talon", "delay": 0.25, "air": true},
	"demon_claws": {"class": "hellclaw", "range": 5.5, "damage": 62.0, "cooldown": 1.5, "fx": "rend", "splash": 3.2, "delay": 0.32, "air": false},
	"titan_beam": {"class": "titan", "range": 34.0, "damage": 150.0, "cooldown": 4.5, "fx": "titan_beam", "splash": 6.0, "air": true},
	"mech_missiles": {"class": "missile", "range": 30.0, "damage": 56.0, "cooldown": 2.6, "fx": "missile", "splash": 2.8, "air": false},
	"angel_lance": {"class": "holy", "range": 28.0, "damage": 30.0, "cooldown": 1.5, "fx": "beam", "air": true},
}

const UNITS := {
	"aetherguard": {
		"name": ["エーテル近衛歩兵", "ヴァルケシュ略奪兵"], "short": "歩兵",
		"jp": "戦列歩兵。対歩兵・対空に強く、構えで守りを固める。",
		"type": "squad", "members": 8, "member_hp": 22.0, "armor": "light",
		"cost": {"material": 90, "aether": 0}, "pop": 4, "build_time": 16.0,
		"speed": 5.4, "radius": 3.2, "vision": 34.0, "weapons": ["rifle_volley"],
		"model": "aetherguard", "commands": ["move", "hold", "attack", "patrol", "fortify", "deploy", "special"],
		"special": "aether_volley", "capture": 1.0, "hotkey": "Q",
	},
	"artificer": {
		"name": ["工兵隊", "ヴァルケシュ工匠"], "short": "工兵",
		"jp": "工兵。建物と機械ユニットを修理し、拠点を素早く占領する。",
		"type": "squad", "members": 4, "member_hp": 20.0, "armor": "light",
		"cost": {"material": 70, "aether": 0}, "pop": 2, "build_time": 12.0,
		"speed": 5.6, "radius": 2.4, "vision": 30.0, "weapons": ["artificer_pistol"],
		"model": "artificer", "commands": ["move", "hold", "attack", "patrol", "repair", "special"],
		"special": "field_repair", "capture": 1.8, "repair_rate": 16.0, "hotkey": "W",
	},
	"walker": {
		"name": ["装甲歩行機", "ヴァルケシュ重機兵"], "short": "歩行機",
		"jp": "重装歩行機。大砲と機関砲を持つ主力。建物と装甲に強い。",
		"type": "walker", "hp": 950.0, "armor": "heavy",
		"cost": {"material": 260, "aether": 160}, "pop": 8, "build_time": 38.0,
		"speed": 3.6, "radius": 4.5, "vision": 40.0, "weapons": ["walker_cannon", "walker_gatling"],
		"model": "walker", "commands": ["move", "hold", "attack", "patrol", "fortify", "special"],
		"special": "overcharge", "capture": 0.6, "hotkey": "E",
	},
	"mortar": {
		"name": ["雷鳴臼砲", "ヴァルケシュ砲台"], "short": "臼砲",
		"jp": "自走臼砲。展開すると射程が大きく伸びる。近距離は撃てない。",
		"type": "vehicle", "hp": 340.0, "armor": "heavy",
		"cost": {"material": 170, "aether": 90}, "pop": 5, "build_time": 26.0,
		"speed": 4.0, "radius": 3.0, "vision": 30.0, "weapons": ["mortar_shell"],
		"model": "mortar", "commands": ["move", "hold", "attack", "patrol", "deploy"],
		"special": "", "capture": 0.5, "hotkey": "R",
	},
	"airship": {
		"name": ["王冠の飛行艦", "ヴァルケシュ戦艦"], "short": "飛行艦",
		"jp": "飛行艦。地形を無視して移動し、舷側砲で地上を砲撃する。",
		"type": "air", "hp": 760.0, "armor": "air",
		"cost": {"material": 300, "aether": 240}, "pop": 10, "build_time": 45.0,
		"speed": 6.2, "radius": 4.6, "vision": 56.0, "weapons": ["broadside", "flak"],
		"model": "airship", "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "aether_bombard", "capture": 0.0, "altitude": 17.0, "hotkey": "T",
	},
	# the titan: one at a time, built at the citadel; it comes apart as it lives ("decay" HP/s)
	"titan": {
		"name": ["巨神", "ヴァルケシュの巨神"], "short": "巨神",
		"jp": "山のような巨神。口から光線を放って周りをまとめて焼き払う。とても強いが体が少しずつ崩れていき、やがて倒れる（同時に1体まで）。特殊能力は一直線をなぎ払う巨神の光。",
		"type": "giant", "hp": 6000.0, "armor": "beast",
		"cost": {"material": 900, "aether": 900}, "pop": 16, "build_time": 120.0,
		"speed": 3.4, "radius": 5.0, "vision": 48.0, "weapons": ["titan_beam"],
		"model": "titan", "visual": "titan", "portrait": [40.0, 10.5], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "titan_ray", "capture": 2.0, "decay": 9.0, "height": 15.5, "turn": 1.0, "aim": 0.35, "limit": 1, "hotkey": "W",
	},
	# a flying mech: missiles for buildings, little use against infantry, easy prey for flak
	"mech": {
		"name": ["王冠の機動兵", "ヴァルケシュ機動兵"], "short": "機動兵",
		"jp": "空を飛ぶ人型の機動兵器。肩のミサイルで建物と拠点を壊すのが得意。歩兵には効きにくく、対空攻撃に弱い。特殊能力はミサイル一斉射撃。",
		"type": "air", "hp": 700.0, "armor": "air",
		"cost": {"material": 260, "aether": 200}, "pop": 6, "build_time": 38.0,
		"speed": 9.0, "radius": 2.6, "vision": 40.0, "weapons": ["mech_missiles"],
		"model": "mech", "visual": "mech", "portrait": [11.0, 0.4], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "missile_salvo", "capture": 0.0, "altitude": 10.0, "height": 6.8, "hotkey": "W",
	},
	# creatures of the Beast Sanctum: not machines, so they cannot be repaired but heal
	# themselves ("regen" HP/s) once out of combat. "aim" = how squarely they must face prey.
	"cerberus": {
		"name": ["番犬ケルベロス", "ヴァルケシュのケルベロス"], "short": "ケルベロス",
		"jp": "三つ首の猟犬。地上で最も速く、歩兵と砲兵に食らいつく。都市の占領も速い。",
		"type": "beast", "hp": 440.0, "armor": "beast",
		"cost": {"material": 140, "aether": 50}, "pop": 4, "build_time": 20.0,
		"speed": 8.2, "radius": 2.4, "vision": 38.0, "weapons": ["cerberus_bite"],
		"model": "cerberus", "visual": "cerberus", "portrait": [8.5, 1.9], "call": "howl", "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "frenzy", "capture": 1.5, "regen": 4.0, "height": 3.2, "turn": 6.0, "aim": 0.8, "hotkey": "Q",
	},
	"cyclops": {
		"name": ["嵐眼のサイクロプス", "ヴァルケシュのサイクロプス"], "short": "サイクロプス",
		"jp": "一つ目の巨人。棍棒で周りの敵をまとめて打ち倒し、建物に強い。特殊能力は大岩投げ。",
		"type": "giant", "hp": 1500.0, "armor": "beast",
		"cost": {"material": 240, "aether": 180}, "pop": 8, "build_time": 40.0,
		"speed": 4.6, "radius": 3.6, "vision": 36.0, "weapons": ["cyclops_club"],
		"model": "cyclops", "visual": "cyclops", "portrait": [19.0, 5.2], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "boulder_hurl", "capture": 1.0, "regen": 10.0, "height": 8.3, "turn": 2.4, "aim": 0.5, "hotkey": "W",
	},
	"griffin": {
		"name": ["王家のグリフォン", "ヴァルケシュのグリフォン"], "short": "グリフォン",
		"jp": "グリフォン。最速の飛行ユニットで、空の敵に強い。特殊能力で視界を広げる。",
		"type": "flyer", "hp": 380.0, "armor": "air",
		"cost": {"material": 160, "aether": 110}, "pop": 5, "build_time": 24.0,
		"speed": 10.5, "radius": 3.0, "vision": 46.0, "weapons": ["griffin_talons"],
		"model": "griffin", "visual": "griffin", "portrait": [15.0, 0.4], "call": "screech", "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "keen_sight", "capture": 0.0, "regen": 3.0, "altitude": 11.0, "height": 3.0, "turn": 3.2, "aim": 0.9, "hotkey": "E",
	},
	"dragon": {
		"name": ["エーテルドラゴン", "ヴァルケシュのドラゴン"], "short": "ドラゴン",
		"jp": "ドラゴン。炎の息で地上をまとめて焼き払う。対空攻撃に弱い。特殊能力は火炎の嵐。",
		"type": "flyer", "hp": 1000.0, "armor": "air",
		"cost": {"material": 300, "aether": 300}, "pop": 10, "build_time": 50.0,
		"speed": 8.0, "radius": 4.8, "vision": 52.0, "weapons": ["dragon_breath"],
		"model": "dragon", "visual": "dragon", "portrait": [27.0, 0.6], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "inferno", "capture": 0.0, "regen": 6.0, "altitude": 14.0, "height": 4.0, "turn": 1.8, "aim": 0.6, "hotkey": "R",
	},
	"demon": {
		"name": ["契約の悪魔", "ヴァルケシュの悪魔"], "short": "悪魔",
		"jp": "角と翼を持つ悪魔。燃える爪で周りの敵をまとめて引き裂き、建物にも強い。空は攻撃できない。特殊能力は周りを焼き払う業火。",
		"type": "giant", "hp": 1250.0, "armor": "beast",
		"cost": {"material": 250, "aether": 200}, "pop": 8, "build_time": 42.0,
		"speed": 5.6, "radius": 3.0, "vision": 36.0, "weapons": ["demon_claws"],
		"model": "demon", "visual": "demon", "portrait": [15.0, 4.0], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "hellfire", "capture": 1.0, "regen": 8.0, "height": 6.6, "turn": 2.8, "aim": 0.6, "hotkey": "Q",
	},
	"angel": {
		"name": ["守護天使", "ヴァルケシュの堕天使"], "short": "天使",
		"jp": "光の翼を持つ天使。空から光の槍を放ち、空の敵にも神獣にも強い。特殊能力で周りの味方を回復する。",
		"type": "flyer", "hp": 560.0, "armor": "air",
		"cost": {"material": 200, "aether": 220}, "pop": 6, "build_time": 36.0,
		"speed": 8.4, "radius": 2.6, "vision": 44.0, "weapons": ["angel_lance"],
		"model": "angel", "visual": "angel", "portrait": [11.0, 0.2], "commands": ["move", "hold", "attack", "patrol", "special"],
		"special": "blessing", "capture": 0.0, "regen": 5.0, "altitude": 12.0, "height": 4.6, "turn": 3.0, "aim": 0.8, "hotkey": "Q",
	},
}

const BUILDINGS := {
	"citadel": {
		"name": ["王冠の本拠地", "ヴァルケシュ本拠地"], "short": "本拠地",
		"jp": "本拠地。工兵と巨神を生産し、収入と人口上限を与える。破壊されると敗北。",
		"hp": 5200.0, "radius": 13.0, "footprint": 12.0, "cost": {"material": 0, "aether": 0}, "build_time": 1.0,
		"produces": ["artificer", "titan"], "pop": 20, "income": {"material": 185, "aether": 40},
		"model": "citadel", "weapons": ["aether_lance"], "buildable": false, "vision": 50.0,
	},
	"barracks": {
		"name": ["兵舎", "ヴァルケシュ兵営"], "short": "兵舎",
		"jp": "兵舎。歩兵と工兵を生産する。",
		"hp": 1500.0, "radius": 8.5, "footprint": 8.0, "cost": {"material": 150, "aether": 0}, "build_time": 24.0,
		"produces": ["aetherguard", "artificer"], "pop": 0, "model": "barracks", "buildable": true, "hotkey": "Q", "vision": 30.0,
	},
	"foundry": {
		"name": ["歯車工廠", "ヴァルケシュ鍛冶場"], "short": "工廠",
		"jp": "工廠。歩行機と臼砲を生産する。",
		"hp": 1900.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 220, "aether": 80}, "build_time": 34.0,
		"produces": ["walker", "mortar"], "pop": 0, "model": "foundry", "buildable": true, "hotkey": "W", "vision": 30.0,
	},
	"skyport": {
		"name": ["飛行場", "ヴァルケシュ空港"], "short": "飛行場",
		"jp": "飛行場。飛行艦と機動兵を生産する。",
		"hp": 1600.0, "radius": 8.5, "footprint": 8.0, "cost": {"material": 240, "aether": 180}, "build_time": 40.0,
		"produces": ["airship", "mech"], "pop": 0, "model": "skyport", "buildable": true, "hotkey": "E", "vision": 40.0,
	},
	"refinery": {
		"name": ["エーテル精製所", "ヴァルケシュ吸引塔"], "short": "精製所",
		"jp": "精製所。エーテル収入を増やす。",
		"hp": 950.0, "radius": 6.0, "footprint": 6.0, "cost": {"material": 120, "aether": 0}, "build_time": 20.0,
		"produces": [], "pop": 0, "income": {"material": 0, "aether": 50}, "model": "refinery", "buildable": true, "hotkey": "R", "vision": 24.0,
	},
	"habitat": {
		"name": ["居住区", "ヴァルケシュ兵舎街"], "short": "居住区",
		"jp": "居住区。人口上限を増やす。",
		"hp": 850.0, "radius": 6.0, "footprint": 6.0, "cost": {"material": 100, "aether": 0}, "build_time": 15.0,
		"produces": [], "pop": 15, "model": "habitat", "buildable": true, "hotkey": "T", "vision": 22.0,
	},
	"bastion": {
		"name": ["防衛塔", "ヴァルケシュ棘塔"], "short": "防衛塔",
		"jp": "防衛塔。近づく敵を砲撃する。",
		"hp": 1300.0, "radius": 4.5, "footprint": 4.5, "cost": {"material": 150, "aether": 70}, "build_time": 24.0,
		"produces": [], "pop": 0, "model": "bastion", "weapons": ["tower_cannon"], "buildable": true, "hotkey": "Y", "vision": 42.0,
	},
	"gate": {
		"name": ["アイアンスパイン門", "ヴァルケシュ門"], "short": "城門",
		"jp": "橋頭の城門。二門の砲で橋を守る。",
		"hp": 5000.0, "radius": 11.0, "footprint": 0.0, "cost": {"material": 0, "aether": 0}, "build_time": 1.0,
		"produces": [], "pop": 0, "model": "gate", "weapons": ["tower_cannon", "tower_cannon"], "buildable": false, "vision": 46.0,
		# towers and wall stubs either side of the arch; the road runs through the middle
		"walls": [[-9.0, 0.0, 4.9, 4.9], [9.0, 0.0, 4.9, 4.9], [-17.0, -1.0, 4.9, 2.0], [17.0, -1.0, 4.9, 2.0]], "wall_cover": 10.0,
	},
	# the one-beast shrines of an earlier version: out of the build menu, kept for saves and scenarios.
	# "icon" is the card picture
	"sanctum_cerberus": {
		"name": ["ケルベロスの祠", "ヴァルケシュの猟犬穴"], "short": "ケルベロス",
		"jp": "ケルベロスの祠。三つ首の猟犬ケルベロスを呼び出す。",
		"hp": 1400.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 150, "aether": 60}, "build_time": 30.0,
		"produces": ["cerberus"], "pop": 0, "model": "sanctum", "icon": "unit_cerberus", "buildable": false, "vision": 32.0,
	},
	"sanctum_cyclops": {
		"name": ["サイクロプスの祠", "ヴァルケシュの巨人穴"], "short": "サイクロプス",
		"jp": "サイクロプスの祠。一つ目の巨人サイクロプスを呼び出す。",
		"hp": 1600.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 200, "aether": 120}, "build_time": 36.0,
		"produces": ["cyclops"], "pop": 0, "model": "sanctum", "icon": "unit_cyclops", "buildable": false, "vision": 32.0,
	},
	"sanctum_griffin": {
		"name": ["グリフォンの祠", "ヴァルケシュのグリフォン巣"], "short": "グリフォン",
		"jp": "グリフォンの祠。空の騎士グリフォンを呼び出す。",
		"hp": 1400.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 200, "aether": 120}, "build_time": 36.0,
		"produces": ["griffin"], "pop": 0, "model": "sanctum", "icon": "unit_griffin", "buildable": false, "vision": 32.0,
	},
	"sanctum_dragon": {
		"name": ["ドラゴンの祠", "ヴァルケシュの竜穴"], "short": "ドラゴン",
		"jp": "ドラゴンの祠。炎の息を吐くドラゴンを呼び出す。",
		"hp": 1800.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 240, "aether": 180}, "build_time": 44.0,
		"produces": ["dragon"], "pop": 0, "model": "sanctum", "icon": "unit_dragon", "buildable": false, "vision": 32.0,
	},
	"sanctum_demon": {
		"name": ["悪魔の祠", "ヴァルケシュの魔窟"], "short": "悪魔の祠",
		"jp": "悪魔の祠。燃える爪の悪魔を呼び出す。",
		"hp": 1600.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 240, "aether": 180}, "build_time": 42.0,
		"produces": ["demon"], "pop": 0, "model": "sanctum", "icon": "unit_demon", "buildable": true, "hotkey": "W", "vision": 32.0,
	},
	"sanctum_angel": {
		"name": ["天使の祠", "ヴァルケシュの堕天の祭壇"], "short": "天使の祠",
		"jp": "天使の祠。光の槍と癒しの力を持つ天使を呼び出す。",
		"hp": 1400.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 220, "aether": 200}, "build_time": 40.0,
		"produces": ["angel"], "pop": 0, "model": "sanctum", "icon": "unit_angel", "buildable": true, "hotkey": "E", "vision": 32.0,
	},
	# the superweapon: one per side, charges for four minutes, then strikes anywhere on the map
	# after a warning both sides can see. Citadels and gates lose at most "cap" of their health.
	"judgement": {
		"name": ["天罰の塔", "ヴァルケシュ滅びの塔"], "short": "天罰の塔",
		"jp": "天罰の塔。約4分ごとに、マップのどこへでも巨大な光の柱を落とせる（1人1基まで）。発射すると相手にも着弾地点が知らされ、10秒後に着弾する。",
		"hp": 3200.0, "radius": 8.0, "footprint": 7.5, "cost": {"material": 600, "aether": 600}, "build_time": 90.0,
		"produces": [], "pop": 0, "model": "judgement", "buildable": true, "hotkey": "R", "vision": 40.0, "limit": 1,
		"superweapon": {"charge": 240.0, "delay": 10.0, "radius": 22.0, "damage": 1400.0, "cap": 0.3},
	},
	# three shrines: the beasts share one, demons and angels have their own
	"sanctum": {
		"name": ["神獣の祠", "ヴァルケシュの獣穴"], "short": "神獣の祠",
		"jp": "神獣の祠。ケルベロス・サイクロプス・グリフォン・ドラゴンを呼び出す。",
		"hp": 1800.0, "radius": 9.5, "footprint": 9.0, "cost": {"material": 220, "aether": 150}, "build_time": 40.0,
		"produces": ["cerberus", "cyclops", "griffin", "dragon"], "pop": 0, "model": "sanctum", "buildable": true, "hotkey": "Q", "vision": 32.0,
	},
}

## The citadel's build menu; its seventh button opens the shrines.
const BUILD_ORDER := ["barracks", "foundry", "skyport", "refinery", "habitat", "bastion"]
const SHRINES := ["sanctum", "sanctum_demon", "sanctum_angel"]
## The second page of the build menu: the shrines and the Tower of Judgement.
const SPECIAL_BUILDS := ["sanctum", "sanctum_demon", "sanctum_angel", "judgement"]

const SPECIALS := {
	"aether_volley": {"name": "Aether Volley", "jp": "エーテル弾：8秒間、射撃速度2倍・装甲貫通。", "cooldown": 40.0, "duration": 8.0},
	"field_repair": {"name": "Field Repair", "jp": "応急修理：周囲の味方機械・建物を即座に回復。", "cooldown": 35.0, "duration": 0.0},
	"overcharge": {"name": "Overcharge", "jp": "過負荷：10秒間、速度と連射が上昇。", "cooldown": 45.0, "duration": 10.0},
	"aether_bombard": {"name": "Aether Bombard", "jp": "エーテル爆撃：指定地点へ爆撃を投下。", "cooldown": 50.0, "duration": 0.0, "targeted": true},
	"boulder_hurl": {"name": "Boulder Hurl", "jp": "大岩投げ：指定地点へ大岩を投げつける（射程 48m、建物に強い）。", "cooldown": 30.0, "duration": 0.0, "targeted": true, "range": 48.0},
	"frenzy": {"name": "Frenzy", "jp": "狂乱：8秒間、速度と攻撃速度が上昇。", "cooldown": 35.0, "duration": 8.0},
	"keen_sight": {"name": "Keen Sight", "jp": "鷹の目：15秒間、視界が2倍に広がる。", "cooldown": 40.0, "duration": 15.0},
	"titan_ray": {"name": "Titan's Light", "jp": "巨神の光：力を溜めてから、指定した方向へ 90m の光線で一直線になぎ払う（本拠地・城門へのダメージは上限あり）。", "cooldown": 90.0, "duration": 0.0, "targeted": true, "range": 90.0, "damage": 520.0, "width": 7.0, "cap": 0.2},
	"missile_salvo": {"name": "Missile Salvo", "jp": "ミサイル一斉射撃：指定地点へ12発のミサイルを撃ち込む（射程 40m、建物に強い）。", "cooldown": 45.0, "duration": 0.0, "targeted": true, "range": 40.0},
	"hellfire": {"name": "Hellfire", "jp": "業火：自分の周りを炎で焼き払う（地上の敵に大ダメージ）。", "cooldown": 35.0, "duration": 0.0, "radius": 10.0, "damage": 130.0},
	"blessing": {"name": "Blessing", "jp": "祝福：周りの味方ユニットの体力を回復する。", "cooldown": 30.0, "duration": 0.0, "radius": 18.0, "heal": 220.0},
	"inferno": {"name": "Inferno", "jp": "火炎の嵐：指定地点へ飛び、辺り一帯を炎で焼き払う。", "cooldown": 45.0, "duration": 0.0, "targeted": true},
}

const COMMANDS := {
	"move": {"label": "移動", "key": "M", "jp": "移動：指定地点へ移動（右クリックでも可）"},
	"hold": {"label": "待機", "key": "H", "jp": "待機：その場で停止し、射程内の敵だけを撃つ"},
	"attack": {"label": "攻撃移動", "key": "A", "jp": "攻撃移動：進路上の敵と交戦しながら進む"},
	"patrol": {"label": "巡回", "key": "P", "jp": "巡回：現在地と指定地点を往復する"},
	"fortify": {"label": "構え", "key": "F", "jp": "構え：移動不可になる代わりに被ダメージ半減・射程増加"},
	"repair": {"label": "修理", "key": "R", "jp": "修理：味方の建物・機械ユニットを修理する"},
	"deploy": {"label": "展開", "key": "D", "jp": "展開：臼砲は射程延長、歩兵は土嚢を築いて防御"},
	"special": {"label": "特殊", "key": "S", "jp": "特殊能力"},
}


static func unit_name(id: String, team: int) -> String:
	var d: Dictionary = UNITS[id]
	return d["name"][1 if team == TEAM_ENEMY else 0]


## The first sentence of the Japanese description ("戦列歩兵。").
static func unit_desc(id: String, _team: int) -> String:
	return first_sentence(UNITS[id]["jp"])


static func unit_short(id: String) -> String:
	return UNITS[id]["short"]


static func building_name(id: String, team: int) -> String:
	var d: Dictionary = BUILDINGS[id]
	return d["name"][1 if team == TEAM_ENEMY else 0]


static func building_desc(id: String, _team: int) -> String:
	return first_sentence(BUILDINGS[id]["jp"])


static func building_short(id: String) -> String:
	return BUILDINGS[id]["short"]


## Specials are named by the part of "jp" before the colon ("エーテル弾").
static func special_name(sid: String) -> String:
	return str(SPECIALS[sid]["jp"]).get_slice("：", 0)


static func first_sentence(t: String) -> String:
	var i := t.find("。")
	return t if i < 0 else t.substr(0, i + 1)


static func building_icon(id: String) -> String:
	return BUILDINGS[id].get("icon", "bld_" + id)


static func team_color(team: int) -> Color:
	return FACTIONS.get(team, FACTIONS[-1])["color"]


static func team_glow(team: int) -> Color:
	return FACTIONS.get(team, FACTIONS[-1])["glow"]


static func damage_mult(weapon_class: String, armor: String) -> float:
	return ARMOR_TABLE.get(weapon_class, {}).get(armor, 1.0)
