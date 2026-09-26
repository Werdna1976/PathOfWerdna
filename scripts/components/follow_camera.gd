class_name FollowCamera
extends Camera3D
## Fixed-angle isometric-style camera that smoothly follows a target.
## It never rotates; only its position changes.

@export var target: Node3D
@export var pitch_degrees: float = 55.0
@export var yaw_degrees: float = 45.0
@export var distance: float = 22.0
## How quickly the camera catches up (higher = tighter follow).
@export var follow_sharpness: float = 8.0

var _offset: Vector3


func _ready() -> void:
	# Moved every rendered frame, so it must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rotation = Vector3(deg_to_rad(-pitch_degrees), deg_to_rad(yaw_degrees), 0.0)
	_offset = basis.z * distance
	snap_to_target()


func snap_to_target() -> void:
	if target != null:
		global_position = _target_point() + _offset


func _process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = _target_point() + _offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_sharpness * delta))


func _target_point() -> Vector3:
	return target.get_global_transform_interpolated().origin
