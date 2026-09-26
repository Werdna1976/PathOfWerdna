class_name ClickMoveInput
extends Node
## Turns the `move` action into navigation targets by raycasting from the
## active camera to the world. Holding the button keeps updating the target.

const RAY_LENGTH: float = 500.0
const NO_HIT: Vector3 = Vector3.INF

@export var movement: NavMovement
@export_flags_3d_physics var ground_mask: int = 1
@export var marker_scene: PackedScene


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("move"):
		return
	var point: Vector3 = _pick_ground()
	if point.is_finite():
		movement.set_target(point)
		_spawn_marker(point)
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not Input.is_action_pressed("move"):
		return
	var point: Vector3 = _pick_ground()
	if point.is_finite():
		movement.set_target(point)


## Returns the ground point under the mouse, or NO_HIT.
func _pick_ground() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return NO_HIT
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, ground_mask)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		var plane_hit: Variant = Plane.PLANE_XZ.intersects_ray(origin, direction)
		return plane_hit as Vector3 if plane_hit != null else NO_HIT
	var point: Vector3 = hit["position"]
	# The arena floor is flat at y = 0; clicks on obstacles walk toward their base.
	point.y = 0.0
	return point


func _spawn_marker(point: Vector3) -> void:
	if marker_scene == null:
		return
	var marker: Node3D = marker_scene.instantiate() as Node3D
	# Add to the level, not the player, so the marker stays where it was placed.
	get_parent().get_parent().add_child(marker)
	marker.global_position = point + Vector3(0.0, 0.03, 0.0)
