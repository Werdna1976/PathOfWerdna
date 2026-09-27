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


## Stats that modify only this item (weapon damage, armour values) rather than the character.
const LOCAL_STATS: Array[StringName] = [&"local_phys_percent", &"local_added_phys",
	&"armour", &"evasion", &"energy_shield", &"local_defences_percent"]


## Sum of this item's implicit and affix values for `stat`.
func stat_total(stat: StringName) -> int:
	var total: int = 0
	if not base.implicit.is_empty() and StringName(base.implicit["stat"]) == stat:
		total += implicit_value
	for roll: Dictionary in affixes:
		if affix_def(roll).stat == stat:
			total += int(roll["value"])
	return total


## Global (character) stat totals from this item: every stat except local ones.
func global_stats() -> Dictionary:
	var totals: Dictionary = {}
	var add := func(stat: StringName, value: int) -> void:
		if not LOCAL_STATS.has(stat):
			totals[stat] = totals.get(stat, 0) + value
	if not base.implicit.is_empty():
		add.call(StringName(base.implicit["stat"]), implicit_value)
	for roll: Dictionary in affixes:
		add.call(affix_def(roll).stat, int(roll["value"]))
	return totals


## Weapon physical damage after local mods, as (min, max). Zero if not a weapon.
func weapon_damage() -> Vector2:
	if not base.stats.has("phys_min"):
		return Vector2.ZERO
	var added: int = stat_total(&"local_added_phys")
	var scale: float = 1.0 + stat_total(&"local_phys_percent") / 100.0
	return Vector2(roundf((base.stats["phys_min"] + added) * scale), roundf((base.stats["phys_max"] + added * 2) * scale))


func attacks_per_second() -> float:
	return base.stats.get("aps", 0.0)


## Armour, evasion or energy shield on this item after local flat and % mods.
func local_defence(kind: StringName) -> int:
	var flat: int = int(base.stats.get(String(kind), 0)) + stat_total(kind)
	if flat == 0:
		return 0
	return int(roundf(flat * (1.0 + stat_total(&"local_defences_percent") / 100.0)))


## Affix lines, prefixes first (as PoE shows them). Local mods, which only
## change this item's own damage or defences, are marked "(local)".
func affix_lines() -> Array[String]:
	var lines: Array[String] = []
	for kind: AffixDef.Kind in [AffixDef.Kind.PREFIX, AffixDef.Kind.SUFFIX]:
		for roll: Dictionary in affixes:
			var def: AffixDef = affix_def(roll)
			if def.kind == kind:
				var line: String = AffixDef.format(def.text, roll["value"])
				if LOCAL_STATS.has(def.stat):
					line += " (local)"
				lines.append(line)
	return lines
