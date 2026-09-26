class_name WorldHealthBar
extends Node3D
## A screen-space health bar that tracks this node's position above a body.
## Hidden until the body first takes damage, and hidden again on death.

@export var health: Health
@export var bar_size: Vector2 = Vector2(64.0, 7.0)
@export var fill_color: Color = Color(0.75, 0.12, 0.1)

var _root: Control
var _fill: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	layer.add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.75)
	background.size = bar_size + Vector2(2.0, 2.0)
	background.position = -background.size * 0.5
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)

	_fill = ColorRect.new()
	_fill.color = fill_color
	_fill.size = bar_size
	_fill.position = -bar_size * 0.5
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fill)

	health.changed.connect(_on_changed)
	health.died.connect(func() -> void: _root.visible = false)


func _on_changed(current: float, maximum: float) -> void:
	_fill.size.x = bar_size.x * clampf(current / maximum, 0.0, 1.0)
	_root.visible = current > 0.0 and current < maximum


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(global_position):
		_root.position = Vector2(-1000.0, -1000.0)
		return
	_root.position = camera.unproject_position(get_global_transform_interpolated().origin)
