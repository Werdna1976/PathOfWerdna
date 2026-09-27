class_name Item
extends RefCounted
## One item instance: a base plus its item level, rarity, rolled implicit and
## affixes, socket count and (for currency) stack size.

enum Rarity { NORMAL, MAGIC, RARE, LEGENDARY }

const RARITY_NAMES: Array[String] = ["Normal", "Magic", "Rare", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),
	Color(0.53, 0.53, 1.0),
	Color(1.0, 1.0, 0.47),
	Color(0.95, 0.55, 0.15),
]
const CURRENCY_COLOR: Color = Color(0.78, 0.72, 0.58)
## Max prefixes and suffixes (each) per rarity.
const AFFIX_LIMITS: Array[int] = [0, 1, 2, 3]

var base: ItemBase
var ilvl: int = 1
var rarity: Rarity = Rarity.NORMAL
## Rolled implicit value (0 if the base has none).
var implicit_value: int = 0
## Each: {id: StringName, tier: int, value: int}
var affixes: Array[Dictionary] = []
var sockets: int = 0
var stack: int = 1
## Generated name for rares and legendaries.
var rare_name: String = ""


func affix_def(roll: Dictionary) -> AffixDef:
	return ItemDB.affix(roll["id"])


func count_kind(kind: AffixDef.Kind) -> int:
	var n: int = 0
	for roll: Dictionary in affixes:
		if affix_def(roll).kind == kind:
			n += 1
	return n


func affix_limit() -> int:
	return AFFIX_LIMITS[rarity]


func has_group(group: StringName) -> bool:
	for roll: Dictionary in affixes:
		if affix_def(roll).group == group:
			return true
	return false


func display_name() -> String:
	if base.is_currency():
		return base.name
	match rarity:
		Rarity.MAGIC:
			var prefix: String = ""
			var suffix: String = ""
			for roll: Dictionary in affixes:
				var def: AffixDef = affix_def(roll)
				var tier_name: String = def.tiers[roll["tier"]]["name"]
				if def.kind == AffixDef.Kind.PREFIX:
					prefix = tier_name + " "
				else:
					suffix = " " + tier_name
			return prefix + base.name + suffix
		Rarity.RARE, Rarity.LEGENDARY:
			return rare_name
	return base.name


func color() -> Color:
	return CURRENCY_COLOR if base.is_currency() else RARITY_COLORS[rarity]


func implicit_text() -> String:
	if base.implicit.is_empty():
		return ""
	return AffixDef.format(base.implicit["text"], implicit_value)


## Affix lines, prefixes first (as PoE shows them).
func affix_lines() -> Array[String]:
	var lines: Array[String] = []
	for kind: AffixDef.Kind in [AffixDef.Kind.PREFIX, AffixDef.Kind.SUFFIX]:
		for roll: Dictionary in affixes:
			var def: AffixDef = affix_def(roll)
			if def.kind == kind:
				lines.append(AffixDef.format(def.text, roll["value"]))
	return lines
