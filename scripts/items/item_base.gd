class_name ItemBase
extends RefCounted
## An item type from data/items/bases.json, e.g. "Plate Vest" or "Rusted Hatchet".

var id: StringName
var name: String
## "main_hand", "off_hand", "chest", "helm", "gloves", "boots", "ring", "amulet", "charm", "currency"
var slot: StringName
var tags: Array[StringName] = []
var size: Vector2i = Vector2i.ONE
var drop_level: int = 1
var max_sockets: int = 0
var max_stack: int = 1
var drop_weight: float = 100.0
var description: String = ""
## Base stats: phys_min, phys_max, aps, armour, evasion, energy_shield, block.
var stats: Dictionary = {}
## {stat, min, max, text}, or empty.
var implicit: Dictionary = {}


static func from_dict(d: Dictionary) -> ItemBase:
	var base := ItemBase.new()
	base.id = StringName(d["id"])
	base.name = d["name"]
	base.slot = StringName(d["slot"])
	for tag: String in d.get("tags", []):
		base.tags.append(StringName(tag))
	var s: Array = d.get("size", [1, 1])
	base.size = Vector2i(int(s[0]), int(s[1]))
	base.drop_level = int(d.get("drop_level", 1))
	base.max_sockets = int(d.get("sockets", 0))
	base.max_stack = int(d.get("stack", 1))
	base.drop_weight = float(d.get("drop_weight", 100.0))
	base.description = d.get("description", "")
	if d.has("phys"):
		base.stats["phys_min"] = int(d["phys"][0])
		base.stats["phys_max"] = int(d["phys"][1])
		base.stats["aps"] = float(d.get("aps", 1.0))
	for key: String in ["armour", "evasion", "energy_shield", "block"]:
		if d.has(key):
			base.stats[key] = int(d[key])
	base.implicit = d.get("implicit", {})
	return base


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func is_currency() -> bool:
	return slot == &"currency"


func is_weapon() -> bool:
	return has_tag(&"weapon")


func is_two_handed() -> bool:
	return has_tag(&"two_hand")
