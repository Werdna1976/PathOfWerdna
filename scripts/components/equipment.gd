class_name Equipment
extends Node
## The 10 gear slots. Enforces slot types and two-handed rules:
## a two-handed weapon uses both hands, so equipping one displaces the
## off-hand, and equipping an off-hand displaces a two-hander.
## Off hands hold shields only for now (no dual wielding yet).

signal changed

const SLOTS: Array[StringName] = [&"main_hand", &"off_hand", &"helm", &"chest", &"gloves",
	&"boots", &"ring_left", &"ring_right", &"amulet", &"charm"]
const SLOT_NAMES: Dictionary = {
	&"main_hand": "Weapon", &"off_hand": "Off Hand", &"helm": "Helm", &"chest": "Body Armour",
	&"gloves": "Gloves", &"boots": "Boots", &"ring_left": "Ring", &"ring_right": "Ring",
	&"amulet": "Amulet", &"charm": "Charm",
}

## Base ids equipped (as normal items) when the character is created.
@export var starting_items: Array[StringName] = []

var _items: Dictionary = {}


func _ready() -> void:
	var generator := ItemGenerator.new()
	for id: StringName in starting_items:
		var item: Item = generator.generate(ItemDB.base(id), 1, Item.Rarity.NORMAL)
		equip(item, best_slot(item))


func get_item(slot: StringName) -> Item:
	return _items.get(slot)


func equipped() -> Array[Item]:
	var list: Array[Item] = []
	for slot: StringName in SLOTS:
		if _items.has(slot):
			list.append(_items[slot])
	return list


func slot_of(item: Item) -> StringName:
	for slot: StringName in _items:
		if _items[slot] == item:
			return slot
	return &""


func can_equip(item: Item, slot: StringName) -> bool:
	if item == null or item.base.is_currency():
		return false
	match slot:
		&"ring_left", &"ring_right":
			return item.base.slot == &"ring"
		&"off_hand":
			return item.base.slot == &"off_hand"
		_:
			return item.base.slot == slot


## The slot `item` would go to on a quick-equip: an empty ring slot if there is one.
func best_slot(item: Item) -> StringName:
	if item.base.slot == &"ring":
		return &"ring_right" if _items.has(&"ring_left") and not _items.has(&"ring_right") else &"ring_left"
	return item.base.slot


## Equips `item` in `slot` and returns whatever it displaced (possibly two
## items, for hand-slot conflicts). Returns [item] unchanged if it can't go there.
func equip(item: Item, slot: StringName) -> Array[Item]:
	var displaced: Array[Item] = []
	if not can_equip(item, slot):
		displaced.append(item)
		return displaced
	if _items.has(slot):
		displaced.append(_items[slot])
	var main: Item = _items.get(&"main_hand")
	if slot == &"main_hand" and item.base.is_two_handed() and _items.has(&"off_hand"):
		displaced.append(_items[&"off_hand"])
		_items.erase(&"off_hand")
	elif slot == &"off_hand" and main != null and main.base.is_two_handed():
		displaced.append(main)
		_items.erase(&"main_hand")
	_items[slot] = item
	changed.emit()
	return displaced


func unequip(slot: StringName) -> Item:
	var item: Item = _items.get(slot)
	if item != null:
		_items.erase(slot)
		changed.emit()
	return item
