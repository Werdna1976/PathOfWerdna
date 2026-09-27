class_name Inventory
extends Node
## A PoE-style grid inventory. Items occupy base.size cells; currency stacks.
## New items fill column by column from the top-left, like PoE.

signal changed

const WIDTH: int = 12
const HEIGHT: int = 5

## Each: {item: Item, pos: Vector2i}
var entries: Array[Dictionary] = []


func items() -> Array[Item]:
	var list: Array[Item] = []
	for e: Dictionary in entries:
		list.append(e["item"])
	return list


func position_of(item: Item) -> Vector2i:
	for e: Dictionary in entries:
		if e["item"] == item:
			return e["pos"]
	return Vector2i(-1, -1)


## The entry covering `cell`, or {}.
func entry_at(cell: Vector2i) -> Dictionary:
	for e: Dictionary in entries:
		if _rect(e["item"], e["pos"]).has_point(cell):
			return e
	return {}


func can_place(item: Item, pos: Vector2i, ignore: Item = null) -> bool:
	var rect: Rect2i = _rect(item, pos)
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > WIDTH or rect.end.y > HEIGHT:
		return false
	for e: Dictionary in entries:
		if e["item"] != ignore and _rect(e["item"], e["pos"]).intersects(rect):
			return false
	return true


## First free position for `item`, scanning columns top to bottom, or (-1, -1).
func find_space(item: Item) -> Vector2i:
	for x: int in WIDTH - item.base.size.x + 1:
		for y: int in HEIGHT - item.base.size.y + 1:
			if can_place(item, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Adds the item, merging currency into existing stacks first. Returns true
## if it was fully added; on false, `item.stack` holds what didn't fit.
func try_add(item: Item) -> bool:
	if item.base.max_stack > 1:
		for e: Dictionary in entries:
			var existing: Item = e["item"]
			if existing.base == item.base and existing.stack < existing.base.max_stack:
				var moved: int = mini(item.stack, existing.base.max_stack - existing.stack)
				existing.stack += moved
				item.stack -= moved
				if item.stack == 0:
					changed.emit()
					return true
	var pos: Vector2i = find_space(item)
	if pos.x < 0:
		changed.emit()
		return false
	entries.append({"item": item, "pos": pos})
	changed.emit()
	return true


func place(item: Item, pos: Vector2i) -> bool:
	if not can_place(item, pos, item):
		return false
	remove(item)
	entries.append({"item": item, "pos": pos})
	changed.emit()
	return true


func remove(item: Item) -> void:
	for i: int in entries.size():
		if entries[i]["item"] == item:
			entries.remove_at(i)
			changed.emit()
			return


func _rect(item: Item, pos: Vector2i) -> Rect2i:
	return Rect2i(pos, item.base.size)
