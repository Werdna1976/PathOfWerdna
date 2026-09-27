class_name ItemDB
extends RefCounted
## Loads and caches the item data tables (bases and affixes) from data/items/.

const BASES_PATH: String = "res://data/items/bases.json"
const AFFIXES_PATH: String = "res://data/items/affixes.json"

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
