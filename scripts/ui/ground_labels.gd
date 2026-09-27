class_name GroundLabels
extends CanvasLayer
## Draws a clickable name label over every GroundItem, PoE style.
## - All items show a label (see HIDE_NORMAL_ITEMS for a simple filter).
## - Labels that would overlap are pushed upward.
## - Clicking a label makes the player walk over and pick the item up.
## - Hovering shows the item tooltip (hold Alt for affix tiers).

const PADDING: Vector2 = Vector2(8.0, 3.0)
const GAP: float = 2.0

## GroundItem -> label Control
var _labels: Dictionary = {}
var _tooltip: ItemTooltip
var _hovered: GroundItem


func _ready() -> void:
	layer = 1
	_tooltip = ItemTooltip.new()
	add_child(_tooltip)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var show_all: bool = Input.is_action_pressed("show_labels")
	var placed: Array[Rect2] = []

	var grounds: Array[Node] = get_tree().get_nodes_in_group(GroundItem.GROUP)
	# Nearest to the bottom of the screen first, so near labels keep their spot.
	var entries: Array[Dictionary] = []
	for node: Node in grounds:
		var ground: GroundItem = node as GroundItem
		var label: Control = _labels.get(ground)
		if label == null:
			label = _make_label(ground)
			_labels[ground] = label
		var visible_now: bool = camera != null and _wants_label(ground, show_all) \
			and not camera.is_position_behind(ground.global_position)
		label.visible = visible_now
		if visible_now:
			entries.append({"label": label, "screen": camera.unproject_position(ground.global_position + Vector3.UP * 0.3)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["screen"].y > b["screen"].y)

	for e: Dictionary in entries:
		var label: Control = e["label"]
		var rect := Rect2(e["screen"] - Vector2(label.size.x * 0.5, label.size.y), label.size)
		for attempt: int in 12:
			var blocker: Rect2 = _overlap(rect, placed)
			if blocker.size == Vector2.ZERO:
				break
			rect.position.y = blocker.position.y - rect.size.y - GAP
		placed.append(rect)
		label.position = rect.position

	# Drop labels whose ground item is gone.
	for ground: Variant in _labels.keys():
		if not is_instance_valid(ground):
			(_labels[ground] as Control).queue_free()
			_labels.erase(ground)
			if _hovered == ground:
				_hovered = null
				_tooltip.visible = false

	if _hovered != null and is_instance_valid(_hovered):
		_tooltip.show_item(_hovered.item, show_all)
		_place_tooltip()


## Every item gets a label for now. Set to true to show normal (white) items
## only while Alt is held, as a simple loot filter.
const HIDE_NORMAL_ITEMS: bool = false


func _wants_label(ground: GroundItem, show_all: bool) -> bool:
	if not HIDE_NORMAL_ITEMS:
		return true
	return show_all or ground.item.base.is_currency() or ground.item.rarity != Item.Rarity.NORMAL


func _overlap(rect: Rect2, placed: Array[Rect2]) -> Rect2:
	for other: Rect2 in placed:
		if other.intersects(rect):
			return other
	return Rect2()


func _make_label(ground: GroundItem) -> Control:
	var item: Item = ground.item
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	if item.base.is_currency() or item.rarity >= Item.Rarity.RARE:
		style.set_border_width_all(1)
		style.border_color = item.color()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var text := Label.new()
	text.text = item.display_name()
	if item.base.is_currency() and item.stack > 1:
		text.text = "%dx %s" % [item.stack, item.display_name()]
	text.add_theme_color_override("font_color", item.color())
	text.add_theme_font_size_override("font_size", 14)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text)

	panel.gui_input.connect(_on_label_input.bind(ground))
	panel.mouse_entered.connect(func() -> void: _hovered = ground)
	panel.mouse_exited.connect(_on_label_exited.bind(ground))
	add_child(panel)
	move_child(_tooltip, -1)
	panel.reset_size()
	return panel


func _on_label_input(event: InputEvent, ground: GroundItem) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	var pickup: ItemPickup = player.get_node_or_null("ItemPickup") as ItemPickup if player != null else null
	if pickup != null:
		pickup.request(ground)
	get_viewport().set_input_as_handled()


# Untyped: the ground item may already be freed (picked up) when the mouse leaves.
func _on_label_exited(ground: Variant) -> void:
	if not is_instance_valid(_hovered) or _hovered == ground:
		_hovered = null
		_tooltip.visible = false


func _place_tooltip() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var pos: Vector2 = mouse + Vector2(18.0, -_tooltip.size.y - 10.0)
	pos.x = clampf(pos.x, 0.0, screen.x - _tooltip.size.x)
	pos.y = clampf(pos.y, 0.0, screen.y - _tooltip.size.y)
	_tooltip.position = pos
