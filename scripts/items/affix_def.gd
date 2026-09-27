class_name AffixDef
extends RefCounted
## A prefix or suffix from data/items/affixes.json, with tiers ordered worst to best.

enum Kind { PREFIX, SUFFIX }

var id: StringName
var kind: Kind
## Only one affix per group can appear on an item.
var group: StringName
var stat: StringName
var text: String
## Item tag -> weight multiplier.
var tag_weights: Dictionary = {}
## Each tier: {name, ilvl, min, max, weight}. Index = tier rank (0 = worst).
var tiers: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> AffixDef:
	var affix := AffixDef.new()
	affix.id = StringName(d["id"])
	affix.kind = Kind.PREFIX if d["kind"] == "prefix" else Kind.SUFFIX
	affix.group = StringName(d.get("group", d["id"]))
	affix.stat = StringName(d["stat"])
	affix.text = d["text"]
	for tag: String in d.get("tags", {}):
		affix.tag_weights[StringName(tag)] = float(d["tags"][tag])
	for tier: Dictionary in d["tiers"]:
		affix.tiers.append({
			"name": tier["name"],
			"ilvl": int(tier["ilvl"]),
			"min": int(tier["min"]),
			"max": int(tier["max"]),
			"weight": float(tier["weight"]),
		})
	return affix


## Highest multiplier among the base's tags, or 0 if the affix can't roll on it.
func weight_multiplier(base: ItemBase) -> float:
	var best: float = 0.0
	for tag: StringName in base.tags:
		best = maxf(best, tag_weights.get(tag, 0.0))
	return best


## Formats a rolled value with this affix's text.
static func format(template: String, value: int) -> String:
	return template.replace("{v2}", str(value * 2)).replace("{v}", str(value))
