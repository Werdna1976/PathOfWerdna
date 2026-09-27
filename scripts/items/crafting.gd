class_name Crafting
extends RefCounted
## Applies crafting orbs to items (DESIGN.md "Crafting orbs"). Upgrade orbs
## keep existing affixes and add new ones; reroll orbs replace them. Every
## roll respects the item's level and mod pools, and legendaries keep their
## tier bias. apply() returns "" on success or the reason it can't be used,
## in which case the item is unchanged and the orb isn't spent.

const ORBS: Array[StringName] = [&"orb_transmutation", &"orb_augmentation", &"orb_alteration",
	&"orb_regal", &"orb_chaos", &"orb_ascension", &"orb_scouring", &"orb_jeweller"]
## Legendaries get this many extra affixes from an Ascension (at least one).
const ASCENSION_EXTRA: Vector2i = Vector2i(1, 2)


static func is_orb(item: Item) -> bool:
	return item != null and ORBS.has(item.base.id)


## Why `orb_id` can't be used on `item`, or "" if it can.
static func check(orb_id: StringName, item: Item) -> String:
	if item == null or item.base.is_currency() or item.base.is_gem():
		return "Can't use that on this item"
	match orb_id:
		&"orb_transmutation":
			return "" if item.rarity == Item.Rarity.NORMAL else "Transmutation needs a normal item"
		&"orb_augmentation":
			if item.rarity != Item.Rarity.MAGIC:
				return "Augmentation needs a magic item"
			return "" if item.affixes.size() < 2 else "This item has no room for another modifier"
		&"orb_alteration":
			return "" if item.rarity == Item.Rarity.MAGIC else "Alteration needs a magic item"
		&"orb_regal":
			return "" if item.rarity == Item.Rarity.MAGIC else "Regal needs a magic item"
		&"orb_chaos":
			return "" if item.rarity >= Item.Rarity.RARE else "Chaos needs a rare or legendary item"
		&"orb_ascension":
			return "" if item.rarity == Item.Rarity.RARE else "Ascension needs a rare item"
		&"orb_scouring":
			return "" if item.rarity != Item.Rarity.NORMAL else "This item has no modifiers to remove"
		&"orb_jeweller":
			return "" if item.base.max_sockets > 1 else "This item can't have more than one socket"
	return "Unknown orb"


## Applies the orb. Returns "" on success, otherwise why not (item unchanged).
## Gems pushed out by a Jeweller's Orb are returned in `ejected`.
static func apply(orb_id: StringName, item: Item, generator: ItemGenerator, ejected: Array[Item] = []) -> String:
	var problem: String = check(orb_id, item)
	if problem != "":
		return problem
	match orb_id:
		&"orb_transmutation":
			item.rarity = Item.Rarity.MAGIC
			generator.reroll_affixes(item)
		&"orb_augmentation":
			if not generator.add_random_affix(item):
				return "No modifier can be added to this item"
		&"orb_alteration":
			generator.reroll_affixes(item)
		&"orb_regal":
			item.rarity = Item.Rarity.RARE
			generator.add_random_affix(item)
			item.rare_name = generator.rare_name(item.base)
		&"orb_chaos":
			generator.reroll_affixes(item)
		&"orb_ascension":
			item.rarity = Item.Rarity.LEGENDARY
			var extra: int = generator.rng.randi_range(ASCENSION_EXTRA.x, ASCENSION_EXTRA.y)
			for i: int in extra:
				if not generator.add_random_affix(item):
					break
		&"orb_scouring":
			item.rarity = Item.Rarity.NORMAL
			item.affixes.clear()
			item.rare_name = ""
		&"orb_jeweller":
			var before: int = item.sockets
			var count: int = before
			# Always change the count when possible, so the orb never feels wasted.
			for attempt: int in 20:
				count = generator.roll_sockets(item.base.max_sockets)
				if count != before:
					break
			item.sockets = count
			for i: int in range(count, item.socketed.size()):
				if item.socketed[i] != null:
					ejected.append(item.socketed[i])
			if item.socketed.size() > count:
				item.socketed.resize(count)
	return ""
