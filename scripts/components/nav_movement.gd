class_name NavMovement
extends Node
## Drives the parent CharacterBody3D along a NavigationAgent3D path.
## Reusable by the player now and by enemies later.

signal destination_reached

@export var agent: NavigationAgent3D
@export var move_speed: float = 5.0
## How quickly the body turns to face its heading (higher = snappier).
@export var turn_sharpness: float = 14.0
@export var gravity: float = 20.0

## While locked (e.g. mid-leap) the body holds still but keeps its target,
## so a move ordered during an action starts as soon as it ends.
var locked: bool = false
## Multiplies move speed; attacks slow the player instead of stopping them.
var speed_scale: float = 1.0
## Keep the current facing while moving (so a swing stays aimed).
var hold_facing: bool = false

var _moving: bool = false

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func set_target(point: Vector3) -> void:
	agent.target_position = point
	_moving = true


func stop() -> void:
	_moving = false
	agent.target_position = _body.global_position


func is_moving() -> bool:
	return _moving


func _physics_process(delta: float) -> void:
	var velocity: Vector3 = Vector3.ZERO
	if _moving and not locked:
		velocity = _step_velocity(delta)
	velocity.y = 0.0 if _body.is_on_floor() else _body.velocity.y - gravity * delta
	_body.velocity = velocity
	_body.move_and_slide()


func _step_velocity(delta: float) -> Vector3:
	if agent.is_navigation_finished():
		_moving = false
		destination_reached.emit()
		return Vector3.ZERO
	var to_next: Vector3 = agent.get_next_path_position() - _body.global_position
	to_next.y = 0.0
	var distance: float = to_next.length()
	if distance < 0.001:
		return Vector3.ZERO
	var direction: Vector3 = to_next / distance
	if not hold_facing:
		_face(direction, delta)
	# Don't overshoot the waypoint on the last step.
	var speed: float = minf(move_speed * speed_scale, distance / delta)
	return direction * speed


func _face(direction: Vector3, delta: float) -> void:
	# The model's forward is -Z.
	var target_yaw: float = atan2(-direction.x, -direction.z)
	var weight: float = 1.0 - exp(-turn_sharpness * delta)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, weight)
