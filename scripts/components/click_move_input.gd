class_name ClickMoveInput
extends Node
## Turns the `move` action into navigation targets by raycasting from the
## active camera to the world. Holding the button keeps updating the target.

@export var movement: NavMovement
@export_flags_3d_physics var ground_mask: int = 1
@export var marker_scene: PackedScene

## True only while a press that reached the world (not the HUD) is held.
var _holding: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("move"):
		return
	_holding = true
	var point: Vector3 = CursorRay.ground_point(get_viewport(), ground_mask)
	if point.is_finite():
		movement.set_target(point)
		_spawn_marker(point)
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not Input.is_action_pressed("move"):
		_holding = false
	if not _holding:
		return
	var point: Vector3 = CursorRay.ground_point(get_viewport(), ground_mask)
	if point.is_finite():
		movement.set_target(point)


func _spawn_marker(point: Vector3) -> void:
	if marker_scene == null:
		return
	var marker: Node3D = marker_scene.instantiate() as Node3D
	# Add to the level, not the player, so the marker stays where it was placed.
	get_parent().get_parent().add_child(marker)
	marker.global_position = point + Vector3(0.0, 0.03, 0.0)
