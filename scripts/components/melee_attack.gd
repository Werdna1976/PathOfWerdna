class_name MeleeAttack
extends Node
## A timed melee swing. The body snaps to face the swing direction, and after
## the wind-up the closest living target inside a forward arc takes damage.
##
## Called with a SkillGem, the gem supplies timing, reach, arc and a damage
## multiplier on top of this node's base (weapon) damage. It can hit every
## target in the area, and leap skills carry the body to a landing point
## during the wind-up. Without a gem the exported values are used, which is
## how enemies attack.

signal swing_started
signal swing_hit(target: Node3D, damage: float)
signal swing_finished

enum Phase { IDLE, WINDUP, RECOVERY }

const LEAP_HEIGHT: float = 1.6

## Base damage per hit (the weapon roll).
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
## Raised along an arc while leaping. Optional.
@export var leap_visual: Node3D

var _phase: Phase = Phase.IDLE
var _time_left: float = 0.0
var _skill: SkillGem
var _leap_from: Vector3
var _leap_to: Vector3 = Vector3.INF

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func is_busy() -> bool:
	return _phase != Phase.IDLE


func current_windup() -> float:
	return _skill.windup if _skill != null else windup


func current_recovery() -> float:
	return _skill.recovery if _skill != null else recovery


func current_arc() -> float:
	return _skill.arc_degrees if _skill != null else arc_degrees


## Centre-to-centre distance at which a swing with `skill` is sure to connect.
func approach_distance(skill: SkillGem = null) -> float:
	return (skill.reach if skill != null else reach) + 0.1


## Starts a swing toward `direction`. Returns false if already swinging.
## Pass `leap_to` to carry the body to that point during the wind-up.
func swing(direction: Vector3, skill: SkillGem = null, leap_to: Vector3 = Vector3.INF) -> bool:
	if is_busy():
		return false
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_body.rotation.y = atan2(-direction.x, -direction.z)
	_skill = skill
	_leap_from = _body.global_position
	_leap_to = leap_to
	_phase = Phase.WINDUP
	_time_left = current_windup()
	swing_started.emit()
	return true


func cancel() -> void:
	if not is_busy():
		return
	_phase = Phase.IDLE
	_end_leap()
	swing_finished.emit()


func _physics_process(delta: float) -> void:
	if not is_busy():
		return
	_time_left -= delta
	if _phase == Phase.WINDUP and _leap_to.is_finite():
		_step_leap()
	if _time_left > 0.0:
		return
	if _phase == Phase.WINDUP:
		_end_leap()
		_resolve_hit()
		_phase = Phase.RECOVERY
		_time_left = current_recovery()
	else:
		_phase = Phase.IDLE
		swing_finished.emit()


func _step_leap() -> void:
	var t: float = clampf(1.0 - _time_left / current_windup(), 0.0, 1.0)
	_body.global_position = _leap_from.lerp(_leap_to, t)
	if leap_visual != null:
		leap_visual.position.y = 4.0 * LEAP_HEIGHT * t * (1.0 - t)


func _end_leap() -> void:
	if not _leap_to.is_finite():
		return
	_body.global_position = _leap_to
	_leap_to = Vector3.INF
	if leap_visual != null:
		leap_visual.position.y = 0.0


func _resolve_hit() -> void:
	var multiplier: float = _skill.damage_multiplier if _skill != null else 1.0
	var hit_all: bool = _skill != null and _skill.hits_all
	for target: Node3D in _find_targets(hit_all):
		var damage: float = roundf(randf_range(damage_min, damage_max) * multiplier)
		Health.of(target).take_damage(damage)
		swing_hit.emit(target, damage)


## Living targets in the swing area, closest first. Only the closest unless `hit_all`.
func _find_targets(hit_all: bool) -> Array[Node3D]:
	var shape := SphereShape3D.new()
	shape.radius = _skill.reach if _skill != null else reach
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, _body.global_position + Vector3.UP * strike_height)
	params.collision_mask = target_mask
	params.exclude = [_body.get_rid()]
	var results: Array[Dictionary] = _body.get_world_3d().direct_space_state.intersect_shape(params, 32)

	var forward: Vector3 = -_body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var min_dot: float = cos(deg_to_rad(current_arc() * 0.5))
	var found: Array[Node3D] = []
	var distances: Dictionary = {}
	for result: Dictionary in results:
		var node: Node3D = result["collider"] as Node3D
		var health: Health = Health.of(node)
		if health == null or health.is_dead() or distances.has(node):
			continue
		var to_target: Vector3 = node.global_position - _body.global_position
		to_target.y = 0.0
		var distance: float = to_target.length()
		# Targets standing on top of us always count; otherwise they must be in the arc.
		if distance > 0.05 and forward.dot(to_target / distance) < min_dot:
			continue
		found.append(node)
		distances[node] = distance
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return distances[a] < distances[b])
	if not hit_all and found.size() > 1:
		found.resize(1)
	return found
