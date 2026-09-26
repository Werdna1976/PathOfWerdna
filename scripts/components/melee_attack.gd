class_name MeleeAttack
extends Node
## A timed melee swing. The body snaps to face the swing direction, and after
## the wind-up the closest living target inside a forward arc takes damage.
## The player uses it for Heavy Strike; enemies use it for their basic attack.

signal swing_started
signal swing_hit(target: Node3D, damage: float)
signal swing_finished

enum Phase { IDLE, WINDUP, RECOVERY }

@export var damage_min: float = 10.0
@export var damage_max: float = 15.0
## How far past the attacker's centre a target's collider can be and still be hit.
@export var reach: float = 1.6
@export_range(0.0, 360.0) var arc_degrees: float = 110.0
## Seconds from the start of the swing until the hit lands.
@export var windup: float = 0.22
## Seconds after the hit before another swing can start.
@export var recovery: float = 0.3
@export_flags_3d_physics var target_mask: int = 4
@export var strike_height: float = 0.9

var _phase: Phase = Phase.IDLE
var _time_left: float = 0.0

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func is_busy() -> bool:
	return _phase != Phase.IDLE


## Centre-to-centre distance at which a swing is sure to connect.
func approach_distance() -> float:
	return reach + 0.1


## Starts a swing toward `direction`. Returns false if already swinging.
func swing(direction: Vector3) -> bool:
	if is_busy():
		return false
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_body.rotation.y = atan2(-direction.x, -direction.z)
	_phase = Phase.WINDUP
	_time_left = windup
	swing_started.emit()
	return true


func cancel() -> void:
	if is_busy():
		_phase = Phase.IDLE
		swing_finished.emit()


func _physics_process(delta: float) -> void:
	if not is_busy():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	if _phase == Phase.WINDUP:
		_resolve_hit()
		_phase = Phase.RECOVERY
		_time_left = recovery
	else:
		_phase = Phase.IDLE
		swing_finished.emit()


func _resolve_hit() -> void:
	var target: Node3D = _find_target()
	if target == null:
		return
	var damage: float = roundf(randf_range(damage_min, damage_max))
	Health.of(target).take_damage(damage)
	swing_hit.emit(target, damage)


func _find_target() -> Node3D:
	var shape := SphereShape3D.new()
	shape.radius = reach
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, _body.global_position + Vector3.UP * strike_height)
	params.collision_mask = target_mask
	params.exclude = [_body.get_rid()]
	var results: Array[Dictionary] = _body.get_world_3d().direct_space_state.intersect_shape(params, 16)

	var forward: Vector3 = -_body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var min_dot: float = cos(deg_to_rad(arc_degrees * 0.5))
	var best: Node3D = null
	var best_distance: float = INF
	for result: Dictionary in results:
		var node: Node3D = result["collider"] as Node3D
		var health: Health = Health.of(node)
		if health == null or health.is_dead():
			continue
		var to_target: Vector3 = node.global_position - _body.global_position
		to_target.y = 0.0
		var distance: float = to_target.length()
		# Targets standing on top of us always count; otherwise they must be in the arc.
		if distance > 0.05 and forward.dot(to_target / distance) < min_dot:
			continue
		if distance < best_distance:
			best = node
			best_distance = distance
	return best
