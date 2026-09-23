class_name Scenario
extends RefCounted
## A scenario file: the map to play, starting forces, objectives and scripted events
## (triggers: a condition plus a list of actions). Built-in scenarios live in res://scenarios/,
## player-made ones in user://scenarios/. The format is documented in docs/scenarios.md.

const BUILTIN_DIR := "res://scenarios"
const USER_DIR := "user://scenarios"
const DEFAULT := "res://scenarios/hold_the_gate.json"
const MAPS := {"ironspine": "res://data/map_ironspine.json"}
const CMPS := [">=", ">", "<=", "<", "==", "!="]
const ORDERS := ["move", "attack_move", "patrol", "hold"]
const STATES := ["open", "done", "failed"]
## Required keys per condition / action type.
const CONDITIONS := {
	"time": ["at"], "var": ["name"], "units": [], "buildings": [], "sites": [], "resource": ["team", "kind"],
	"fired": ["trigger"], "objective": ["id"], "all": ["of"], "any": ["of"], "not": ["of"],
}
const ACTIONS := {
	"message": ["text"], "banner": ["title"], "advisor": ["text"], "spawn": ["team", "units", "at"],
	"spawn_building": ["team", "id", "at"], "order": ["order"], "resources": ["team"], "ai": ["aggression"],
	"objectives": ["list"], "objective": ["id", "state"], "set_var": ["name", "value"], "add_var": ["name", "value"],
	"focus": ["at"], "sound": ["name"], "victory": [], "defeat": [],
}

static var _site_cache := {}

var path := ""
var data := {}
var errors := PackedStringArray()
var _fired_refs: Array = []


static func load_file(p: String) -> Scenario:
	var s := Scenario.new()
	s.path = p
	if not FileAccess.file_exists(p):
		s.errors.append("ファイルがありません: %s" % p)
		return s
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		s.errors.append("JSON の書き方の誤り（%d 行目）: %s" % [json.get_error_line(), json.get_error_message()])
		return s
	if not json.data is Dictionary:
		s.errors.append("ファイル全体を { } で囲んでください")
		return s
	s.data = json.data
	s._validate()
	return s


## Built-in scenarios first, then the player's own folder, each sorted by file name.
static func list_all() -> Array[Scenario]:
	var out: Array[Scenario] = []
	for dir: String in [BUILTIN_DIR, USER_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if f.get_extension() == "json":
				out.append(load_file(dir.path_join(f)))
	return out


## Creates the player's scenario folder if needed and returns its absolute path.
static func user_dir() -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	return ProjectSettings.globalize_path(USER_DIR)


func is_valid() -> bool:
	return errors.is_empty() and not data.is_empty()


func is_builtin() -> bool:
	return path.begins_with("res://")


func title() -> String:
	return str(data.get("title", path.get_file().get_basename()))


# ---------------------------------------------------------------- validation
func _err(at: String, msg: String) -> void:
	errors.append(("%s: %s" % [at, msg]) if at != "" else msg)


func _validate() -> void:
	var d := data
	if int(d.get("format", 1)) != 1:
		_err("format", "1 にしてください")
	for key in ["id", "title"]:
		if not d.get(key) is String or str(d[key]).is_empty():
			_err(key, "文字列で書いてください")
	var map_id := str(d.get("map", ""))
	if not MAPS.has(map_id):
		_err("map", "不明なマップ \"%s\"（使えるもの: %s）" % [map_id, ", ".join(MAPS.keys())])
	var teams: Variant = d.get("teams", {})
	if not teams is Dictionary:
		_err("teams", "{ } で書いてください")
	else:
		for t: String in teams:
			if not t in ["0", "1"]:
				_err("teams", "チームは \"0\"（王冠）か \"1\"（ヴァルケシュ）です: \"%s\"" % t)
	var start: Variant = d.get("start", {})
	if not start is Dictionary:
		_err("start", "{ } で書いてください")
		start = {}
	var sb: Variant = start.get("buildings", [])
	var su: Variant = start.get("units", [])
	if not sb is Array or not su is Array:
		_err("start", "buildings と units は [ ] で書いてください")
	else:
		for i in sb.size():
			_check_action("start.buildings[%d]" % i, _with_type(sb[i], "spawn_building"))
		for i in su.size():
			_check_start_unit("start.units[%d]" % i, su[i])
	if d.has("vars") and not d["vars"] is Dictionary:
		_err("vars", "{\"名前\": 数値} で書いてください")
	if d.has("objectives"):
		_check_objectives("objectives", d["objectives"])
	var ids := {}
	var triggers: Variant = d.get("triggers", [])
	if not triggers is Array:
		_err("triggers", "[ ] で書いてください")
		triggers = []
	for i in triggers.size():
		var at := "triggers[%d]" % i
		var tr: Variant = triggers[i]
		if not tr is Dictionary:
			_err(at, "{ } で書いてください")
			continue
		var tid := str(tr.get("id", ""))
		if tid != "":
			if ids.has(tid):
				_err(at, "id \"%s\" が重複しています" % tid)
			ids[tid] = true
		if not tr.has("when"):
			_err(at, "\"when\"（条件）が必要です")
		else:
			_check_condition(at + ".when", tr["when"])
		var acts: Variant = tr.get("do")
		if not acts is Array or acts.is_empty():
			_err(at, "\"do\"（アクションの配列）が必要です")
		else:
			for k in acts.size():
				_check_action("%s.do[%d]" % [at, k], acts[k])
	for key in ["victory", "defeat"]:
		if d.has(key):
			_check_condition(key, d[key])
	for ref: Array in _fired_refs:
		if not ids.has(ref[1]):
			_err(ref[0], "id が \"%s\" のトリガーがありません" % ref[1])


func _with_type(v: Variant, type: String) -> Variant:
	if v is Dictionary:
		var c: Dictionary = v.duplicate()
		c["type"] = type
		return c
	return v


func _check_start_unit(at: String, u: Variant) -> void:
	if not u is Dictionary:
		_err(at, "{ } で書いてください")
		return
	for key in ["id", "team", "at"]:
		if not u.has(key):
			_err(at, "\"%s\" が必要です" % key)
	_check_id(at, u, "id", Defs.UNITS)
	_check_team(at, u)
	_check_pos(at, u, "at")


func _check_condition(at: String, c: Variant) -> void:
	if not c is Dictionary:
		_err(at, "条件は { } で書いてください")
		return
	var type := str(c.get("type", ""))
	if not CONDITIONS.has(type):
		_err(at, "不明な条件 \"%s\"（使えるもの: %s）" % [type, ", ".join(CONDITIONS.keys())])
		return
	for key: String in CONDITIONS[type]:
		if not c.has(key):
			_err(at, "%s には \"%s\" が必要です" % [type, key])
	if c.has("cmp") and not str(c["cmp"]) in CMPS:
		_err(at, "cmp は %s のどれかです" % " ".join(CMPS))
	_check_team(at, c)
	_check_area(at, c)
	match type:
		"all", "any":
			if not c.get("of") is Array:
				_err(at, "of は条件の配列 [ ] です")
			else:
				for i in c["of"].size():
					_check_condition("%s.of[%d]" % [at, i], c["of"][i])
		"not":
			_check_condition(at + ".of", c.get("of"))
		"units":
			_check_id(at, c, "id", Defs.UNITS)
		"buildings":
			_check_id(at, c, "id", Defs.BUILDINGS)
		"sites":
			if c.has("id") and MAPS.has(str(data.get("map", ""))) and not str(c["id"]) in _site_ids():
				_err(at, "このマップに都市 \"%s\" はありません（あるもの: %s）" % [c["id"], ", ".join(_site_ids())])
		"resource":
			if not str(c.get("kind", "")) in ["material", "aether"]:
				_err(at, "kind は material か aether です")
		"fired":
			_fired_refs.append([at, str(c.get("trigger", ""))])
		"objective":
			if c.has("state") and not str(c["state"]) in STATES:
				_err(at, "state は %s のどれかです" % ", ".join(STATES))


func _check_action(at: String, a: Variant) -> void:
	if not a is Dictionary:
		_err(at, "アクションは { } で書いてください")
		return
	var type := str(a.get("type", ""))
	if not ACTIONS.has(type):
		_err(at, "不明なアクション \"%s\"（使えるもの: %s）" % [type, ", ".join(ACTIONS.keys())])
		return
	for key: String in ACTIONS[type]:
		if not a.has(key):
			_err(at, "%s には \"%s\" が必要です" % [type, key])
	_check_team(at, a)
	_check_area(at, a)
	if a.has("at"):
		_check_pos(at, a, "at")
	match type:
		"spawn":
			if not a.get("units") is Dictionary:
				_err(at, "units は {\"ユニット名\": 数} で書いてください")
			else:
				for id: String in a["units"]:
					if not Defs.UNITS.has(id):
						_err(at, "不明なユニット \"%s\"（使えるもの: %s）" % [id, ", ".join(Defs.UNITS.keys())])
			_check_order(at, a)
		"spawn_building":
			_check_id(at, a, "id", Defs.BUILDINGS)
		"order":
			_check_order(at, a)
		"objectives":
			_check_objectives(at, a)
		"objective":
			if not str(a.get("state", "")) in STATES:
				_err(at, "state は %s のどれかです" % ", ".join(STATES))


func _check_objectives(at: String, o: Variant) -> void:
	if not o is Dictionary or not o.get("list") is Array:
		_err(at, "{\"title\": ..., \"list\": [ ... ]} の形で書いてください")
		return
	for i in o["list"].size():
		var item: Variant = o["list"][i]
		var p := "%s.list[%d]" % [at, i]
		if not item is Dictionary or not item.get("text") is String:
			_err(p, "text（文字列）が必要です")
			continue
		for key in ["done_when", "failed_when"]:
			if item.has(key):
				_check_condition(p + "." + key, item[key])
		if item.has("state") and not str(item["state"]) in STATES:
			_err(p, "state は %s のどれかです" % ", ".join(STATES))


func _check_order(at: String, a: Dictionary) -> void:
	if not a.has("order"):
		return
	var kind := str(a["order"])
	if not kind in ORDERS:
		_err(at, "order は %s のどれかです" % ", ".join(ORDERS))
	elif kind != "hold":
		if not a.has("target"):
			_err(at, "order \"%s\" には target [x, z] が必要です" % kind)
		else:
			_check_pos(at, a, "target")


func _check_id(at: String, d: Dictionary, key: String, table: Dictionary) -> void:
	if d.has(key) and not table.has(str(d[key])):
		_err(at, "不明な %s \"%s\"（使えるもの: %s）" % [key, d[key], ", ".join(table.keys())])


func _check_team(at: String, d: Dictionary) -> void:
	if not d.has("team"):
		return
	var t: Variant = d["team"]
	if not (t is float or t is int) or not int(t) in [0, 1]:
		_err(at, "team は 0（王冠）か 1（ヴァルケシュ）です")


func _check_pos(at: String, d: Dictionary, key: String) -> void:
	var v: Variant = d.get(key)
	if not v is Array or v.size() != 2 or not (v[0] is float or v[0] is int) or not (v[1] is float or v[1] is int):
		_err(at, "%s は [x, z] の2つの数で書いてください" % key)
	elif absf(float(v[0])) > 200.0 or absf(float(v[1])) > 200.0:
		_err(at, "%s がマップの外です（x, z は -200〜200）" % key)


func _check_area(at: String, d: Dictionary) -> void:
	if not d.has("area"):
		return
	var v: Variant = d["area"]
	if not v is Array or v.size() != 3:
		_err(at, "area は [x, z, 半径] で書いてください")


func _site_ids() -> PackedStringArray:
	var map_id := str(data.get("map", ""))
	if not _site_cache.has(map_id):
		var ids := PackedStringArray()
		if MAPS.has(map_id):
			var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS[map_id]))
			if layout is Dictionary:
				for s: Dictionary in layout.get("sites", []):
					ids.append(str(s["id"]))
		_site_cache[map_id] = ids
	return _site_cache[map_id]
