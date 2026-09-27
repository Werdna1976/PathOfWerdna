class_name ItemGenerator
extends RefCounted
## Rolls items: base choice, rarity, implicit, sockets and affixes.
## Takes its own RandomNumberGenerator so tests can use a fixed seed.
## Crafting orbs (later) reuse add_random_affix() and reroll_affixes().

## Normal / magic / rare / legendary drop weights.
const RARITY_WEIGHTS: Array[float] = [620.0, 300.0, 75.0, 5.0]
## Affix count range per rarity, [min, max]. Limits per kind are in Item.AFFIX_LIMITS.
const AFFIX_COUNTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 2), Vector2i(3, 4), Vector2i(4, 6)]
## Legendary tier bias: weight × (1 + LEGENDARY_BIAS × tier rank).
const LEGENDARY_BIAS: float = 0.5
## Weights for 1, 2, 3, 4 sockets; lower counts are more common.
const SOCKET_WEIGHTS: Array[float] = [40.0, 30.0, 20.0, 10.0]

const NAME_FIRST: Array[String] = [
	"Grim", "Dread", "Blood", "Doom", "Storm", "Ghoul", "Rune", "Viper", "Wrath", "Carrion",
	"Corpse", "Gloom", "Hate", "Kraken", "Oblivion", "Pain", "Rapture", "Shadow", "Skull",
	"Soul", "Sorrow", "Tempest", "Vengeance", "Beast", "Cruel", "Ash", "Bramble", "Dusk",
]
const NAME_SECOND: Dictionary = {
	&"main_hand": ["Bite", "Edge", "Song", "Thirst", "Cleaver", "Hunger", "Fang", "Razor"],
	&"off_hand": ["Bulwark", "Guard", "Aegis", "Wall", "Watch"],
	&"chest": ["Shell", "Mantle", "Cloak", "Ward", "Carapace", "Hide"],
	&"helm": ["Crown", "Visor", "Brow", "Dome", "Halo"],
	&"gloves": ["Grasp", "Hold", "Fist", "Clutch", "Hand"],
	&"boots": ["Stride", "March", "Trail", "Spur", "Track"],
	&"ring": ["Loop", "Coil", "Band", "Knot", "Circle"],
	&"amulet": ["Heart", "Beads", "Pendant", "Locket", "Talisman"],
	&"charm": ["Token", "Totem", "Idol", "Fetish", "Trinket"],
}

var rng: RandomNumberGenerator


func _init(seed_value: int = -1) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## `rarity_bonus` is "increased rarity of items found" in percent; it scales
## the magic, rare and legendary weights.
func roll_rarity(rarity_bonus: float = 0.0) -> Item.Rarity:
	var weights: Array[float] = RARITY_WEIGHTS.duplicate()
	for i: int in range(1, weights.size()):
		weights[i] *= 1.0 + rarity_bonus / 100.0
	return _weighted_index(weights) as Item.Rarity


## Picks a random base that can drop at `ilvl`, either equipment or currency.
func random_base(ilvl: int, currency: bool = false) -> ItemBase:
	var options: Array[ItemBase] = []
	var weights: Array[float] = []
	for b: ItemBase in ItemDB.bases():
		if b.is_currency() == currency and b.drop_level <= ilvl:
			options.append(b)
			weights.append(b.drop_weight)
	return options[_weighted_index(weights)] if not options.is_empty() else null


## Rolls a full item. Pass `rarity` to force one, or -1 to roll it.
func generate(base: ItemBase, ilvl: int, rarity: int = -1, rarity_bonus: float = 0.0) -> Item:
	var item := Item.new()
	item.base = base
	item.ilvl = ilvl
	if base.is_currency():
		return item
	item.rarity = (roll_rarity(rarity_bonus) if rarity < 0 else rarity) as Item.Rarity
	if not base.implicit.is_empty():
		item.implicit_value = rng.randi_range(int(base.implicit["min"]), int(base.implicit["max"]))
	item.sockets = roll_sockets(base.max_sockets)
	reroll_affixes(item)
	return item


## Clears and rerolls all affixes for the item's rarity (Alteration / Chaos).
func reroll_affixes(item: Item) -> void:
	item.affixes.clear()
	var counts: Vector2i = AFFIX_COUNTS[item.rarity]
	var target: int = rng.randi_range(counts.x, counts.y)
	for i: int in target:
		if not add_random_affix(item):
			break
	if item.rarity >= Item.Rarity.RARE:
		item.rare_name = _rare_name(item.base)


## Adds one affix of any open kind. Returns false if nothing can be added.
func add_random_affix(item: Item) -> bool:
	var limit: int = item.affix_limit()
	var open_prefix: bool = item.count_kind(AffixDef.Kind.PREFIX) < limit
	var open_suffix: bool = item.count_kind(AffixDef.Kind.SUFFIX) < limit
	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	for def: AffixDef in ItemDB.affixes():
		if def.kind == AffixDef.Kind.PREFIX and not open_prefix:
			continue
		if def.kind == AffixDef.Kind.SUFFIX and not open_suffix:
			continue
		if item.has_group(def.group):
			continue
		var multiplier: float = def.weight_multiplier(item.base)
		if multiplier <= 0.0:
			continue
		for rank: int in def.tiers.size():
			var tier: Dictionary = def.tiers[rank]
			if tier["ilvl"] > item.ilvl:
				continue
			var weight: float = tier["weight"] * multiplier
			if item.rarity == Item.Rarity.LEGENDARY:
				weight *= 1.0 + LEGENDARY_BIAS * rank
			candidates.append({"def": def, "tier": rank})
			weights.append(weight)
	if candidates.is_empty():
		return false
	var pick: Dictionary = candidates[_weighted_index(weights)]
	var chosen: AffixDef = pick["def"]
	var tier: Dictionary = chosen.tiers[pick["tier"]]
	item.affixes.append({
		"id": chosen.id,
		"tier": pick["tier"],
		"value": rng.randi_range(tier["min"], tier["max"]),
	})
	return true


func roll_sockets(max_sockets: int) -> int:
	if max_sockets <= 0:
		return 0
	return _weighted_index(SOCKET_WEIGHTS.slice(0, max_sockets)) + 1


func _rare_name(base: ItemBase) -> String:
	var seconds: Array = NAME_SECOND.get(base.slot, ["Relic"])
	return "%s %s" % [NAME_FIRST[rng.randi_range(0, NAME_FIRST.size() - 1)],
		seconds[rng.randi_range(0, seconds.size() - 1)]]


func _weighted_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1
