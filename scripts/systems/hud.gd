class_name Hud
extends CanvasLayer
## Player HUD: a life bar in the bottom-left and a message on death.
## Placeholder until life/mana globes arrive with potions in Milestone 3.

const BAR_SIZE: Vector2 = Vector2(320.0, 26.0)
const MARGIN: float = 24.0

var _fill: ColorRect
var _label: Label
var _death_label: Label


func _ready() -> void:
	var frame := ColorRect.new()
	frame.color = Color(0.0, 0.0, 0.0, 0.8)
	frame.size = BAR_SIZE + Vector2(4.0, 4.0)
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.position = Vector2(MARGIN, -MARGIN - frame.size.y)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_fill = ColorRect.new()
	_fill.color = Color(0.62, 0.08, 0.07)
	_fill.size = BAR_SIZE
	_fill.position = Vector2(2.0, 2.0)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_fill)

	_label = Label.new()
	_label.size = frame.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	frame.add_child(_label)

	_death_label = Label.new()
	_death_label.text = "Werdna has fallen..."
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.add_theme_font_size_override("font_size", 44)
	_death_label.add_theme_color_override("font_color", Color(0.75, 0.1, 0.08))
	_death_label.visible = false
	add_child(_death_label)

	_bind_player.call_deferred()


func _bind_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var health: Health = Health.of(player)
	if health == null:
		push_warning("Hud: no player Health found.")
		return
	health.changed.connect(_on_changed)
	health.died.connect(func() -> void: _death_label.visible = true)
	_on_changed(health.current, health.max_health)


func _on_changed(current: float, maximum: float) -> void:
	_fill.size.x = BAR_SIZE.x * clampf(current / maximum, 0.0, 1.0)
	_label.text = "Life  %d / %d" % [ceili(current), int(maximum)]
	if current > 0.0:
		_death_label.visible = false
