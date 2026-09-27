class_name InventoryScreen
extends Control
## PoE-style inventory panel (toggle with I): the 10 equipment slots above
## the 12×5 grid.
## - Left click an item to pick it up onto the cursor; left click again to
##   place it, swap with the item under it, or equip it into a slot.
## - Right click an item in the grid to equip it; right click gear to unequip.
## - Left click the world while holding an item to drop it on the ground.
## - Sockets are the circles on items. Holding a gem, click a socket to put it
##   in (swapping any gem already there); with nothing held, click a filled
##   socket to take its gem out. Solid dots are active gems; rings are supports.
## - Right click an orb to start crafting with it, then left click an item to
##   apply it. Hold Shift to keep going; right click or Esc stops.
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
const SOCKET_RADIUS: float = 9.0
const SOCKET_COLOR: Color = Color(0.55, 0.5, 0.45)
const ACTIVE_GEM_COLOR: Color = Color(0.85, 0.25, 0.2)
const SUPPORT_GEM_COLOR: Color = Color(0.95, 0.55, 0.5)

## Reports problems (e.g. "Chaos needs a rare item") for the HUD to show.
signal message(text: String)

var inventory: Inventory
var equipment: Equipment
var skill_bar: SkillBar
var melee: MeleeAttack
## Item currently on the cursor.
var held: Item
## Orb stack being applied (it stays in the bag until used up), or null.
var applying: Item

var _generator := ItemGenerator.new()

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
	skill_bar = player.get_node("SkillBar") as SkillBar
	melee = player.get_node("Melee") as MeleeAttack
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
	applying = null
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


## Centre of socket `index` for an item drawn in `r`: two per row, centred.
func socket_center(item: Item, r: Rect2, index: int) -> Vector2:
	var columns: int = mini(item.base.size.x, 2)
	var rows: int = ceili(float(item.sockets) / columns)
	var top: float = (r.size.y - rows * CELL) * 0.5 + CELL * 0.5
	var left: float = (r.size.x - columns * CELL) * 0.5 + CELL * 0.5
	return r.position + Vector2(left + (index % columns) * CELL, top + (index / columns) * CELL)


## The item under `local` (grid or equipment) and where it's drawn: {item, rect}, or {}.
func item_at(local: Vector2) -> Dictionary:
	var slot: StringName = slot_at(local)
	if slot != &"":
		var equipped: Item = equipment.get_item(slot)
		return {"item": equipped, "rect": slot_rect(slot)} if equipped != null else {}
	var entry: Dictionary = inventory.entry_at(grid_cell_at(local))
	if entry.is_empty() or not Rect2(grid_origin(), Vector2(Inventory.WIDTH, Inventory.HEIGHT) * CELL).has_point(local):
		return {}
	var item: Item = entry["item"]
	return {"item": item, "rect": Rect2(grid_origin() + Vector2(entry["pos"]) * CELL, Vector2(item.base.size) * CELL)}


## The socket index under `local` on the item there, or -1.
func socket_at(local: Vector2) -> int:
	var hit: Dictionary = item_at(local)
	if hit.is_empty():
		return -1
	var item: Item = hit["item"]
	for i: int in item.sockets:
		if socket_center(item, hit["rect"], i).distance_to(local) <= SOCKET_RADIUS + 4.0:
			return i
	return -1


# --- Actions (also used by tests) ----------------------------------------------

## Starts applying an orb stack from the bag.
func begin_apply(orb: Item) -> void:
	if Crafting.is_orb(orb):
		applying = orb
		queue_redraw()


## Applies the current orb to `target`. Keeps going afterwards if `keep_going`.
func apply_to(target: Item, keep_going: bool = false) -> bool:
	if applying == null or target == null:
		return false
	var ejected: Array[Item] = []
	var problem: String = Crafting.apply(applying.base.id, target, _generator, ejected)
	if problem != "":
		message.emit(problem)
		return false
	for gem: Item in ejected:
		if not inventory.try_add(gem):
			_drop(gem)
	applying.stack -= 1
	if applying.stack <= 0:
		inventory.remove(applying)
		applying = null
	elif not keep_going:
		applying = null
	if equipment.slot_of(target) != &"":
		equipment.notify_changed()
	inventory.changed.emit()
	_tooltip.visible = false
	queue_redraw()
	return true


## The damage estimate for a socketed active gem in equipped gear: {skill, estimate}, or {}.
func skill_estimate_for(gem_item: Item) -> Dictionary:
	if skill_bar == null:
		return {}
	for skill: SkillInstance in skill_bar.available_skills():
		if skill.gem_item == gem_item:
			return {"skill": skill, "estimate": melee.estimate(skill, skill_bar.cooldown_rate)}
	return {}


## Clicking socket `index` of `item`: socket the held gem (swapping), or take the gem out.
func click_socket(item: Item, index: int) -> void:
	if held != null and held.base.is_gem():
		held = item.socket_gem(index, held)
	elif held == null and item.socketed_gem(index) != null:
		held = item.socket_gem(index, null)
	else:
		return
	if equipment.slot_of(item) != &"":
		equipment.notify_changed()
	queue_redraw()


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
	if applying != null:
		if click.button_index == MOUSE_BUTTON_LEFT:
			var target: Dictionary = item_at(local)
			if not target.is_empty():
				apply_to(target["item"], click.shift_pressed)
		else:
			applying = null
		accept_event()
		queue_redraw()
		return
	if click.button_index == MOUSE_BUTTON_RIGHT and held == null:
		var under: Dictionary = item_at(local)
		if not under.is_empty() and Crafting.is_orb(under["item"]):
			begin_apply(under["item"])
			accept_event()
			return
	var socket: int = socket_at(local)
	var socket_ok: bool = socket >= 0 and ((held != null and held.base.is_gem()) 		or (held == null and (item_at(local)["item"] as Item).socketed_gem(socket) != null))
	if click.button_index == MOUSE_BUTTON_LEFT:
		if socket_ok:
			click_socket(item_at(local)["item"], socket)
		elif slot != &"":
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
	elif event.is_action_pressed("menu") and applying != null:
		applying = null
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and visible:
		close()
		get_viewport().set_input_as_handled()
	elif held != null and event.is_action_pressed("move"):
		# Clicking the world with an item on the cursor drops it instead of walking.
		drop_held()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if held != null or applying != null:
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
	if applying != null:
		var local: Vector2 = get_local_mouse_position()
		var text: String = "%s (%d)" % [applying.base.name, applying.stack]
		draw_string(_font, local + Vector2(14.0, -8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Item.CURRENCY_COLOR)
		draw_circle(local, 6.0, Item.CURRENCY_COLOR)


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
	elif item.base.is_gem():
		label = (item.gem as GemData).short_name
	var font_size: int = 11 if r.size.x > CELL else 8
	draw_multiline_string(_font, inner.position + Vector2(3.0, 13.0), label, HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x - 6.0, font_size, 4, Color(color, alpha))
	for i: int in item.sockets:
		_draw_socket(socket_center(item, r, i), item.socketed_gem(i), alpha)


func _draw_socket(center: Vector2, gem_item: Item, alpha: float) -> void:
	draw_circle(center, SOCKET_RADIUS, Color(0.03, 0.03, 0.03, alpha))
	draw_arc(center, SOCKET_RADIUS, 0.0, TAU, 20, Color(SOCKET_COLOR, alpha), 1.5)
	if gem_item == null:
		return
	if gem_item.gem is SupportGem:
		draw_arc(center, SOCKET_RADIUS - 3.0, 0.0, TAU, 20, Color(SUPPORT_GEM_COLOR, alpha), 3.0)
	else:
		draw_circle(center, SOCKET_RADIUS - 2.5, Color(ACTIVE_GEM_COLOR, alpha))


func _update_tooltip() -> void:
	if not visible or held != null:
		_tooltip.visible = false
		return
	# While crafting, the tooltip shows the item under the cursor as the target.
	var local: Vector2 = get_local_mouse_position()
	var hit: Dictionary = item_at(local)
	var item: Item = hit.get("item")
	# Hovering a filled socket shows that gem instead of the item.
	var socket: int = socket_at(local)
	if socket >= 0 and item.socketed_gem(socket) != null:
		item = item.socketed_gem(socket)
	if item == null:
		_tooltip.visible = false
		return
	var estimate: Dictionary = skill_estimate_for(item) if item.base.is_gem() else {}
	_tooltip.show_item(item, Input.is_action_pressed("show_labels"), estimate)
	# Show to the left of the panel, like PoE.
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_tooltip.position = Vector2(
		clampf(global_position.x - _tooltip.size.x - 8.0, 0.0, screen.x - _tooltip.size.x),
		clampf(mouse.y - _tooltip.size.y * 0.5, 0.0, screen.y - _tooltip.size.y))
