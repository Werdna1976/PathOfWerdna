class_name VendorScreen
extends Control
## Shop window shown on the left while the inventory is open on the right.
## - Left click an item in the vendor's stock to buy it (paid in orbs).
## - Pick up an item in your inventory and click the Sell box to sell it.
##   Gems socketed in a sold item go back to your bag.
## Closes with Esc, or when the player walks away from the vendor.

signal message(text: String)

const CELL: float = 40.0
const PAD: float = 16.0
const TITLE_HEIGHT: float = 34.0
const COLUMNS: int = 12
const ROWS: int = 8
const SELL_HEIGHT: float = 64.0
const CLOSE_DISTANCE: float = 6.0
const PRICE_SHORT: Dictionary = {&"orb_transmutation": "Trans", &"orb_alteration": "Alt", &"orb_chaos": "Chaos"}

var vendor: Vendor
var inventory: Inventory
var inventory_screen: InventoryScreen

## Stock laid out in the grid: [{item, pos}]
var _layout: Array[Dictionary] = []
var _player: Node3D
var _tooltip: ItemTooltip
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var panel_size := Vector2(COLUMNS * CELL + PAD * 2.0, TITLE_HEIGHT + ROWS * CELL + PAD * 3.0 + SELL_HEIGHT)
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = 20.0
	offset_right = 20.0 + panel_size.x
	offset_top = -panel_size.y * 0.5 - 40.0
	offset_bottom = panel_size.y * 0.5 - 40.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_tooltip = ItemTooltip.new()
	_tooltip.top_level = true
	add_child(_tooltip)


func open(shop: Vendor, player: Node3D, screen: InventoryScreen) -> void:
	vendor = shop
	_player = player
	inventory_screen = screen
	inventory = screen.inventory
	_relayout()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	vendor = null
	_tooltip.visible = false


# --- Geometry ------------------------------------------------------------------

func stock_origin() -> Vector2:
	return Vector2(PAD, TITLE_HEIGHT + PAD)


func sell_rect() -> Rect2:
	return Rect2(Vector2(PAD, TITLE_HEIGHT + ROWS * CELL + PAD * 2.0), Vector2(COLUMNS * CELL, SELL_HEIGHT))


func stock_entry_at(local: Vector2) -> Dictionary:
	for e: Dictionary in _layout:
		var item: Item = e["item"]
		if Rect2(stock_origin() + Vector2(e["pos"]) * CELL, Vector2(item.base.size) * CELL).has_point(local):
			return e
	return {}


# --- Actions (also used by tests) ----------------------------------------------

## Buys `item` from the vendor. Returns true if it was bought.
func buy(item: Item) -> bool:
	var price: Dictionary = Shop.price(item)
	if Shop.count(inventory, price["id"]) < price["amount"]:
		message.emit("Not enough: costs %s" % Shop.describe(price))
		return false
	if inventory.find_space(item).x < 0:
		message.emit("Inventory full")
		return false
	Shop.spend(inventory, price["id"], price["amount"])
	inventory.try_add(vendor.take(item))
	_relayout()
	queue_redraw()
	return true


## Sells the item on the inventory cursor. Returns true if it was sold.
func sell_held() -> bool:
	var item: Item = inventory_screen.held
	if item == null:
		return false
	var value: Dictionary = Shop.sell_value(item)
	if value.is_empty():
		message.emit("The vendor won't buy that")
		return false
	inventory_screen.held = null
	for gem: Item in item.gems():
		if not inventory.try_add(gem):
			inventory_screen.held = gem
	item.socketed.clear()
	if not Shop.give(inventory, value["id"], value["amount"]):
		message.emit("Inventory full: some payment was lost")
	queue_redraw()
	return true


func _relayout() -> void:
	_layout.clear()
	var taken: Array[Rect2i] = []
	for item: Item in vendor.stock:
		var pos: Vector2i = _find_space(item, taken)
		if pos.x < 0:
			continue
		_layout.append({"item": item, "pos": pos})
		taken.append(Rect2i(pos, item.base.size))


func _find_space(item: Item, taken: Array[Rect2i]) -> Vector2i:
	for x: int in COLUMNS - item.base.size.x + 1:
		for y: int in ROWS - item.base.size.y + 1:
			var rect := Rect2i(Vector2i(x, y), item.base.size)
			if not taken.any(func(r: Rect2i) -> bool: return r.intersects(rect)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# --- Input -----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		if event is InputEventMouseMotion:
			queue_redraw()
		return
	if sell_rect().has_point(click.position):
		sell_held()
	elif inventory_screen.held == null:
		var entry: Dictionary = stock_entry_at(click.position)
		if not entry.is_empty():
			buy(entry["item"])
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("menu"):
		close()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(vendor) or not inventory_screen.visible \
			or _player.global_position.distance_to(vendor.global_position) > CLOSE_DISTANCE:
		close()
		return
	if inventory_screen.held != null:
		queue_redraw()
	_update_tooltip()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if vendor == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.04, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.3, 0.22), false, 1.0)
	draw_string(_font, Vector2(PAD, 24.0), vendor.vendor_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.85, 0.55))
	var origin: Vector2 = stock_origin()
	draw_rect(Rect2(origin, Vector2(COLUMNS, ROWS) * CELL), Color(0.1, 0.09, 0.08))
	for e: Dictionary in _layout:
		var item: Item = e["item"]
		var r := Rect2(origin + Vector2(e["pos"]) * CELL, Vector2(item.base.size) * CELL)
		var inner: Rect2 = r.grow(-2.0)
		InventoryScreen.draw_item_tile(self, _font, item, r)
		var price: Dictionary = Shop.price(item)
		var price_text: String = "%d %s" % [price["amount"], PRICE_SHORT.get(price["id"], "?")]
		var price_pos: Vector2 = inner.position + Vector2(2.0, inner.size.y - 3.0)
		draw_string_outline(_font, price_pos, price_text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 4.0, 9, 4, Color.BLACK)
		draw_string(_font, price_pos, price_text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 4.0, 9, Item.CURRENCY_COLOR)

	var sell: Rect2 = sell_rect()
	var held: Item = inventory_screen.held
	var hovering: bool = held != null and sell.has_point(get_local_mouse_position())
	draw_rect(sell, Color(0.12, 0.1, 0.07) if not hovering else Color(0.2, 0.16, 0.08))
	draw_rect(sell, Color(0.55, 0.45, 0.25), false, 1.0)
	var text: String = "Sell: pick up an item in your inventory and click here"
	if held != null:
		var value: Dictionary = Shop.sell_value(held)
		text = "Sell %s for %s" % [held.display_name(), Shop.describe(value)] if not value.is_empty() else "The vendor won't buy that"
	draw_string(_font, sell.position + Vector2(10.0, sell.size.y * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT,
		sell.size.x - 20.0, 13, Color(0.85, 0.8, 0.65))


func _update_tooltip() -> void:
	var local: Vector2 = get_local_mouse_position()
	var entry: Dictionary = stock_entry_at(local) if inventory_screen.held == null else {}
	if entry.is_empty():
		_tooltip.visible = false
		return
	var item: Item = entry["item"]
	var price: Dictionary = Shop.price(item)
	var footer: String = "Price: %s (you have %d)" % [Shop.describe(price), Shop.count(inventory, price["id"])]
	_tooltip.show_item(item, Input.is_action_pressed("show_labels"), {}, footer)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_tooltip.position = Vector2(clampf(global_position.x + size.x + 8.0, 0.0, screen.x - _tooltip.size.x),
		clampf(mouse.y - _tooltip.size.y * 0.5, 0.0, screen.y - _tooltip.size.y))
