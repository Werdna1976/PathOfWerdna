class_name ItemDB
extends RefCounted
## Loads and caches the item data tables (bases and affixes) from data/items/.

const BASES_PATH: String = "res://data/items/bases.json"
const AFFIXES_PATH: String = "res://data/items/affixes.json"
## Every gem resource, by id. Default Attack isn't a gem item and is loaded by SkillBar.
const GEM_PATHS: Dictionary = {
	&"heavy_strike": "res://data/gems/heavy_strike.tres",
	&"cleave": "res://data/gems/cleave.tres",
	&"leap_slam": "res://data/gems/leap_slam.tres",
	&"added_fire": "res://data/gems/added_fire.tres",
	&"melee_splash": "res://data/gems/melee_splash.tres",
	&"faster_attacks": "res://data/gems/faster_attacks.tres",
	&"life_leech": "res://data/gems/life_leech.tres",
	&"brutality": "res://data/gems/brutality.tres",
}

static var _bases: Dictionary = {}
static var _base_list: Array[ItemBase] = []
static var _affixes: Dictionary = {}
static var _affix_list: Array[AffixDef] = []


static func base(id: StringName) -> ItemBase:
	_ensure_loaded()
	return _bases.get(id)


static func bases() -> Array[ItemBase]:
	_ensure_loaded()
	return _base_list


static func affix(id: StringName) -> AffixDef:
	_ensure_loaded()
	return _affixes.get(id)


static func affixes() -> Array[AffixDef]:
	_ensure_loaded()
	return _affix_list


static func gem(id: StringName) -> GemData:
	return load(GEM_PATHS[id]) as GemData if GEM_PATHS.has(id) else null


static var _gem_bases: Dictionary = {}


## The (cached) item base used for gem items of this gem.
static func gem_base(data: GemData) -> ItemBase:
	if not _gem_bases.has(data.id):
		var b := ItemBase.new()
		b.id = StringName("gem_" + String(data.id))
		b.name = data.display_name
		b.slot = &"gem"
		b.tags = [&"gem"]
		b.size = Vector2i.ONE
		b.description = data.description
		_gem_bases[data.id] = b
	return _gem_bases[data.id]


## A new gem item for the gem with this id.
static func make_gem(id: StringName) -> Item:
	var data: GemData = gem(id)
	var item := Item.new()
	item.base = gem_base(data)
	item.gem = data
	return item


static func _ensure_loaded() -> void:
	if not _base_list.is_empty():
		return
	for d: Dictionary in _read_json(BASES_PATH).get("bases", []):
		var b: ItemBase = ItemBase.from_dict(d)
		_bases[b.id] = b
		_base_list.append(b)
	for d: Dictionary in _read_json(AFFIXES_PATH).get("affixes", []):
		var a: AffixDef = AffixDef.from_dict(d)
		_affixes[a.id] = a
		_affix_list.append(a)


static func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ItemDB: can't open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("ItemDB: %s is not a JSON object" % path)
	return {}
