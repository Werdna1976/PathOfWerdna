class_name InventoryScreen
extends Control
## PoE-style inventory panel (toggle with I): the 10 equipment slots above
## the 12×5 grid.
## - Left click an item to pick it up onto the cursor; left click again to
##   place it, swap with the item under it, or equip it into a slot.
## - Right click an item in the grid to equip it; right click gear to unequip.
## - Left click the world while holding an item to drop it on the ground.
## Everything is drawn in _draw(); items are coloured boxes with their names.

const CELL: float = 40.0
const PAD: float = 16.0
const TITLE_HEIGHT: float = 30.0
## Equipment layout in cells: slot -> Rect2(position, size), relative to the equipment area.
const EQUIP_LAYOUT: Dictionary = {
	&"main_hand": Rect2(0.5, 0.0, 2, 4),
	&"helm": Rect2(5.0, 0.0, 2, 2),
	&"amulet": Rect2(7.5, 1.0, 1, 1),
	&"chest": Rect2(5.0, 2.2, 2, 3),
	&"ring_left": Rect2(3.5, 3.2, 1, 1),
	&"ring_right": Rect2(7.5, 3.2, 1, 1),
	&"off_hand": Rect2(9.5, 0.0, 2, 4),
	&"gloves": Rect2(1.5, 4.4, 2, 2),
	&"boots": Rect2(8.5, 4.4, 2, 2),
	&"charm": Rect2(5.5, 5.4, 1, 1),
}
const EQUIP_ROWS: float = 6.6
const BG_COLOR: Color = Color(0.05, 0.045, 0.04, 0.96)
const SLOT_COLOR: Color = Color(0.1, 0.09, 0.08)
const CELL_LINE: Color = Color(0.2, 0.18, 0.15)
const VALID_COLOR: Color = Color(0.2, 0.6, 0.2, 0.35)
const INVALID_COLOR: Color = Color(0.7, 0.15, 0.1, 0.35)

var inventory: Inventory
var equipment: Equipment
## Item currently on the cursor.
var held: Item

var _tooltip: ItemTooltip
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	size = Vector2(Inventory.WIDTH * CELL + PAD * 2.0,
		TITLE_HEIGHT + EQUIP_ROWS * CELL + PAD * 3.0 + Inventory.HEIGHT * CELL)
	# Anchored to the right edge, vertically centred (a little above centre to clear the HUD).
	var panel_size: Vector2 = size
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -panel_size.x - 20.0
	offset_right = -20.0
	offset_top = -panel_size.y * 0.5 - 40.0
	offset_bottom = panel_size.y * 0.5 - 40.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_tooltip = ItemTooltip.new()
	_tooltip.top_level = true
	add_child(_tooltip)


func bind(player: Node) -> void:
	inventory = player.get_node("Inventory") as Inventory
	equipment = player.get_node("Equipment") as Equipment
	inventory.changed.connect(queue_redraw)
	equipment.changed.connect(queue_redraw)


func toggle() -> void:
	if visible:
		close()
	else:
		visible = true
		queue_redraw()


func close() -> void:
	# Don't lose a held item: put it back in the bag, or on the ground if full.
	if held != null and not inventory.try_add(held):
		drop_held()
	held = null
	visible = false
	_tooltip.visible = false


# --- Geometry ------------------------------------------------------------------

func grid_origin() -> Vector2:
	return Vector2(PAD, TITLE_HEIGHT + EQUIP_ROWS * CELL + PAD * 2.0)


func equip_origin() -> Vector2:
	return Vector2(PAD, TITLE_HEIGHT + PAD)


func slot_rect(slot: StringName) -> Rect2:
	var r: Rect2 = EQUIP_LAYOUT[slot]
	return Rect2(equip_origin() + r.position * CELL, r.size * CELL)


func grid_cell_at(local: Vector2) -> Vector2i:
	var p: Vector2 = (local - grid_origin()) / CELL
	return Vector2i(floori(p.x), floori(p.y))


func slot_at(local: Vector2) -> StringName:
	for slot: StringName in EQUIP_LAYOUT:
		if slot_rect(slot).has_point(local):
			return slot
	return &""


## Grid position where the held item would go, centred on the mouse like PoE.
func held_grid_pos(local: Vector2) -> Vector2i:
	var top_left: Vector2 = local - Vector2(held.base.size) * CELL * 0.5 + Vector2(CELL, CELL) * 0.5
	return grid_cell_at(top_left)


# --- Actions (also used by tests) ----------------------------------------------

## Left click at a grid cell: pick up, place, or swap.
func click_grid(cell: Vector2i) -> void:
	if held == null:
		var entry: Dictionary = inventory.entry_at(cell)
		if not entry.is_empty():
			held = entry["item"]
			inventory.remove(held)
		return
	var covered: Array[Item] = _items_under(held, cell)
	if covered.size() > 1 or not _in_bounds(held, cell):
		return
	var swapped: Item = covered[0] if covered.size() == 1 else null
	var swapped_pos: Vector2i = inventory.position_of(swapped) if swapped != null else Vector2i.ZERO
	if swapped != null:
		inventory.remove(swapped)
	if inventory.place(held, cell):
		held = swapped
	elif swapped != null:
		inventory.place(swapped, swapped_pos)


## Left click on an equipment slot: equip the held item, or pick up the equipped one.
func click_slot(slot: StringName) -> void:
	if held == null:
		held = equipment.unequip(slot)
		return
	if not equipment.can_equip(held, slot):
		return
	var displaced: Array[Item] = equipment.equip(held, slot)
	held = null
	for i: int in displaced.size():
		# The first displaced item goes to the cursor (a swap); any extra goes to the bag.
		if i == 0:
			held = displaced[i]
		elif not inventory.try_add(displaced[i]):
			_drop(displaced[i])


## Right click in the grid: equip that item, sending anything it replaces to the bag.
func quick_equip(cell: Vector2i) -> void:
	var entry: Dictionary = inventory.entry_at(cell)
	if entry.is_empty():
		return
	var item: Item = entry["item"]
	var slot: StringName = equipment.best_slot(item)
	if not equipment.can_equip(item, slot):
		return
	var pos: Vector2i = entry["pos"]
	inventory.remove(item)
	for displaced: Item in equipment.equip(item, slot):
		if not inventory.place(displaced, pos) and not inventory.try_add(displaced):
			_drop(displaced)


## Right click on gear: move it to the bag if there's room.
func quick_unequip(slot: StringName) -> void:
	var item: Item = equipment.get_item(slot)
	if item != null and inventory.find_space(item).x >= 0:
		inventory.try_add(equipment.unequip(slot))


func drop_held() -> void:
	if held != null:
		_drop(held)
		held = null
		queue_redraw()


func _drop(item: Item) -> void:
	var player: Node3D = inventory.get_parent() as Node3D
	var angle: float = randf() * TAU
	GroundItem.spawn(item, player.get_parent(), player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.8)


func _items_under(item: Item, pos: Vector2i) -> Array[Item]:
	var found: Array[Item] = []
	var rect := Rect2i(pos, item.base.size)
	for e: Dictionary in inventory.entries:
		var other: Item = e["item"]
		if Rect2i(e["pos"], other.base.size).intersects(rect) and not found.has(other):
			found.append(other)
	return found


func _in_bounds(item: Item, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x + item.base.size.x <= Inventory.WIDTH \
		and pos.y + item.base.size.y <= Inventory.HEIGHT


# --- Input -----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		if event is InputEventMouseMotion:
			queue_redraw()
		return
	var local: Vector2 = click.position
	var slot: StringName = slot_at(local)
	var cell: Vector2i = held_grid_pos(local) if held != null else grid_cell_at(local)
	var in_grid: bool = Rect2(grid_origin(), Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL).has_point(local)
	if click.button_index == MOUSE_BUTTON_LEFT:
		if slot != &"":
			click_slot(slot)
		elif in_grid:
			click_grid(cell)
	elif click.button_index == MOUSE_BUTTON_RIGHT and held == null:
		if slot != &"":
			quick_unequip(slot)
		elif in_grid:
			quick_equip(cell)
	accept_event()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and visible:
		close()
		get_viewport().set_input_as_handled()
	elif held != null and event.is_action_pressed("move"):
		# Clicking the world with an item on the cursor drops it instead of walking.
		drop_held()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if held != null:
		queue_redraw()
	_update_tooltip()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.3, 0.22), false, 1.0)
	draw_string(_font, Vector2(PAD, 22.0), "Inventory", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.78, 0.6))

	for slot: StringName in EQUIP_LAYOUT:
		var r: Rect2 = slot_rect(slot)
		draw_rect(r, SLOT_COLOR)
		draw_rect(r, CELL_LINE, false, 1.0)
		var item: Item = equipment.get_item(slot)
		if item != null:
			_draw_item(item, r)
		else:
			draw_string(_font, r.position + Vector2(4.0, r.size.y * 0.5 + 4.0), Equipment.SLOT_NAMES[slot],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8.0, 11, Color(0.4, 0.37, 0.32))

	var origin: Vector2 = grid_origin()
	draw_rect(Rect2(origin, Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL), SLOT_COLOR)
	for x: int in Inventory.WIDTH + 1:
		draw_line(origin + Vector2(x * CELL, 0.0), origin + Vector2(x * CELL, Inventory.HEIGHT * CELL), CELL_LINE)
	for y: int in Inventory.HEIGHT + 1:
		draw_line(origin + Vector2(0.0, y * CELL), origin + Vector2(Inventory.WIDTH * CELL, y * CELL), CELL_LINE)
	for e: Dictionary in inventory.entries:
		var item: Item = e["item"]
		_draw_item(item, Rect2(origin + Vector2(e["pos"]) * CELL, Vector2(item.base.size) * CELL))

	if held != null:
		_draw_held()


func _draw_held() -> void:
	var local: Vector2 = get_local_mouse_position()
	var item_size: Vector2 = Vector2(held.base.size) * CELL
	# Highlight where it would land.
	var slot: StringName = slot_at(local)
	if slot != &"":
		draw_rect(slot_rect(slot), VALID_COLOR if equipment.can_equip(held, slot) else INVALID_COLOR)
	elif Rect2(grid_origin(), Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL).has_point(local):
		var cell: Vector2i = held_grid_pos(local)
		var ok: bool = _in_bounds(held, cell) and _items_under(held, cell).size() <= 1
		draw_rect(Rect2(grid_origin() + Vector2(cell) * CELL, item_size), VALID_COLOR if ok else INVALID_COLOR)
	_draw_item(held, Rect2(local - item_size * 0.5, item_size), 0.85)


func _draw_item(item: Item, r: Rect2, alpha: float = 1.0) -> void:
	var color: Color = item.color()
	var inner: Rect2 = r.grow(-2.0)
	draw_rect(inner, Color(color.darkened(0.75), 0.95 * alpha))
	draw_rect(inner, Color(color, alpha), false, 1.5)
	var label: String = item.base.name
	if item.base.is_currency():
		label = str(item.stack)
	var font_size: int = 11 if r.size.x > CELL else 10
	draw_multiline_string(_font, inner.position + Vector2(3.0, 13.0), label, HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x - 6.0, font_size, 4, Color(color, alpha))
	if item.sockets > 0:
		var dots: String = "o".repeat(item.sockets)
		draw_string(_font, inner.position + Vector2(3.0, inner.size.y - 4.0), dots, HORIZONTAL_ALIGNMENT_CENTER,
			inner.size.x - 6.0, 11, Color(0.7, 0.7, 0.7, alpha))


func _update_tooltip() -> void:
	if not visible or held != null:
		_tooltip.visible = false
		return
	var local: Vector2 = get_local_mouse_position()
	var item: Item = null
	var slot: StringName = slot_at(local)
	if slot != &"":
		item = equipment.get_item(slot)
	else:
		var entry: Dictionary = inventory.entry_at(grid_cell_at(local))
		if not entry.is_empty() and Rect2(Vector2.ZERO, size).has_point(local):
			item = entry["item"]
	if item == null:
		_tooltip.visible = false
		return
	_tooltip.show_item(item, Input.is_action_pressed("show_labels"))
	# Show to the left of the panel, like PoE.
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_tooltip.position = Vector2(
		clampf(global_position.x - _tooltip.size.x - 8.0, 0.0, screen.x - _tooltip.size.x),
		clampf(mouse.y - _tooltip.size.y * 0.5, 0.0, screen.y - _tooltip.size.y))
