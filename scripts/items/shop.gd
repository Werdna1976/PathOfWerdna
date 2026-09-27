class_name Shop
extends RefCounted
## Vendor prices and payments. There's no gold: vendors charge orbs, and pay
## for items in Transmutation Shards or orbs. Shards combine into an Orb of
## Transmutation automatically, SHARDS_PER_ORB at a time.

const SHARD: StringName = &"transmutation_shard"
const SHARDS_PER_ORB: int = 5
## Gems that cost more because they're stronger.
const PREMIUM_GEMS: Array[StringName] = [&"leap_slam", &"melee_splash", &"brutality"]


## What a vendor charges for `item`: {id, amount}.
static func price(item: Item) -> Dictionary:
	if item.base.is_gem():
		var id: StringName = &"orb_alteration" if item.gem is SupportGem else &"orb_transmutation"
		return {"id": id, "amount": 2 if PREMIUM_GEMS.has(item.gem.id) else 1}
	if item.rarity == Item.Rarity.MAGIC:
		return {"id": &"orb_alteration", "amount": 1}
	return {"id": &"orb_transmutation", "amount": 1}


## What a vendor pays for `item`: {id, amount}, or {} if it can't be sold.
static func sell_value(item: Item) -> Dictionary:
	if item.base.is_currency():
		return {}
	if item.base.is_gem():
		return {"id": SHARD, "amount": 1}
	match item.rarity:
		Item.Rarity.MAGIC:
			return {"id": SHARD, "amount": 2}
		Item.Rarity.RARE:
			return {"id": &"orb_alteration", "amount": 1}
		Item.Rarity.LEGENDARY:
			return {"id": &"orb_chaos", "amount": 1}
	return {"id": SHARD, "amount": 1}


static func describe(payment: Dictionary) -> String:
	if payment.is_empty():
		return "nothing"
	var name: String = ItemDB.base(payment["id"]).name
	return "%d× %s" % [payment["amount"], name]


## How many of a currency the inventory holds across all stacks.
static func count(inventory: Inventory, id: StringName) -> int:
	var total: int = 0
	for item: Item in inventory.items():
		if item.base.id == id:
			total += item.stack
	return total


## Removes `amount` of a currency. Returns false (removing nothing) if short.
static func spend(inventory: Inventory, id: StringName, amount: int) -> bool:
	if count(inventory, id) < amount:
		return false
	var left: int = amount
	for item: Item in inventory.items():
		if left == 0:
			break
		if item.base.id != id:
			continue
		var take: int = mini(item.stack, left)
		item.stack -= take
		left -= take
		if item.stack == 0:
			inventory.remove(item)
	inventory.changed.emit()
	return true


## Adds `amount` of a currency, combining shards into orbs. Returns false if it didn't all fit.
static func give(inventory: Inventory, id: StringName, amount: int) -> bool:
	var generator := ItemGenerator.new()
	var orb: Item = generator.generate(ItemDB.base(id), 1)
	orb.stack = amount
	var fitted: bool = inventory.try_add(orb)
	if id == SHARD:
		var orbs: int = count(inventory, SHARD) / SHARDS_PER_ORB
		if orbs > 0 and spend(inventory, SHARD, orbs * SHARDS_PER_ORB):
			fitted = give(inventory, &"orb_transmutation", orbs) and fitted
	return fitted
