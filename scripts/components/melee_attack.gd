class_name MeleeAttack
extends Node
## A timed melee swing. The body snaps to face the swing direction, and after
## the wind-up the closest living target inside a forward arc takes damage.
##
## Called with a SkillInstance (a gem plus its supports), the skill supplies timing, reach, arc and a damage
## multiplier on top of this node's base (weapon) damage. It can hit every
## target in the area, and leap skills carry the body to a landing point
## during the wind-up. Without a gem the exported values are used, which is
## how enemies attack.

signal swing_started
signal swing_hit(target: Node3D, damage: float, critical: bool)
signal swing_finished

enum Phase { IDLE, WINDUP, RECOVERY }

const LEAP_HEIGHT: float = 1.6

## Base physical damage per hit (the weapon roll).
@export var damage_min: float = 10.0
@export var damage_max: float = 15.0
## Added fire damage per hit (from gear).
@export var fire_min: float = 0.0
@export var fire_max: float = 0.0
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

## Set by CharacterStats for the player; enemies keep the defaults.
## Divides wind-up and recovery (2.0 = twice as fast).
var speed_multiplier: float = 1.0
## Percent chance, and damage percent on a critical strike.
var crit_chance: float = 0.0
var crit_multiplier: float = 150.0
## Scales the radius of area skills (Cleave, Leap Slam).
var area_multiplier: float = 1.0
## Hits that leave a target below this percent of its life kill it.
var culling_percent: float = 0.0

var _phase: Phase = Phase.IDLE
var _time_left: float = 0.0
var _skill: SkillInstance
var _leap_from: Vector3
var _leap_to: Vector3 = Vector3.INF

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func is_busy() -> bool:
	return _phase != Phase.IDLE


## The gem being used, or null for a plain (enemy) swing.
func current_skill() -> SkillInstance:
	return _skill if is_busy() else null


func current_windup() -> float:
	return (_skill.windup if _skill != null else windup) / speed_multiplier


func current_recovery() -> float:
	return (_skill.recovery if _skill != null else recovery) / speed_multiplier


func current_arc() -> float:
	return _skill.arc_degrees if _skill != null else arc_degrees


## Centre-to-centre distance at which a swing with `skill` is sure to connect.
func approach_distance(skill: SkillInstance = null) -> float:
	return (skill.reach if skill != null else reach) + 0.1


## Expected numbers for `skill` with the current weapon, gear and supports,
## using the same formula as a real hit. `cooldown_rate` comes from the skill bar.
## Keys: hit_min, hit_max, average_hit, crit_chance, crit_multiplier,
## uses_per_second, dps, area_radius, leech_per_hit.
func estimate(skill: SkillInstance, cooldown_rate: float = 1.0) -> Dictionary:
	var phys_lo: float = damage_min * skill.more_physical
	var phys_hi: float = damage_max * skill.more_physical
	var fire_lo: float = fire_min + damage_min * skill.extra_fire_percent / 100.0
	var fire_hi: float = fire_max + damage_max * skill.extra_fire_percent / 100.0
	if skill.no_elemental:
		fire_lo = 0.0
		fire_hi = 0.0
	var lo: float = (phys_lo + fire_lo) * skill.damage_multiplier
	var hi: float = (phys_hi + fire_hi) * skill.damage_multiplier
	var average: float = (lo + hi) * 0.5
	var crit_factor: float = 1.0 + crit_chance / 100.0 * (crit_multiplier / 100.0 - 1.0)
	var uses: float = speed_multiplier / (skill.windup + skill.recovery)
	if skill.cooldown > 0.0:
		uses = minf(uses, cooldown_rate / skill.cooldown)
	return {
		"hit_min": lo,
		"hit_max": hi,
		"average_hit": average * crit_factor,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"uses_per_second": uses,
		"dps": average * crit_factor * uses,
		"area_radius": skill.reach * (area_multiplier if skill.hits_all else 1.0),
		"leech_per_hit": average * crit_factor * skill.leech_percent / 100.0,
	}


## Starts a swing toward `direction`. Returns false if already swinging.
## Pass `leap_to` to carry the body to that point during the wind-up.
func swing(direction: Vector3, skill: SkillInstance = null, leap_to: Vector3 = Vector3.INF) -> bool:
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
	var hit_all: bool = _skill != null and _skill.hits_all
	var targets: Array[Node3D] = _find_targets(hit_all)
	for target: Node3D in targets:
		_hit(target, 1.0)
	# Melee Splash: single-target strikes also hit enemies around the target.
	if _skill != null and _skill.splash_radius > 0.0 and not hit_all and not targets.is_empty():
		for other: Node3D in _enemies_near(targets[0].global_position, _skill.splash_radius * area_multiplier):
			if other != targets[0]:
				_hit(other, _skill.splash_damage_percent / 100.0)


## Rolls and deals one hit. `scale` reduces splash hits.
func _hit(target: Node3D, scale: float) -> void:
	var phys: float = randf_range(damage_min, damage_max)
	var fire: float = randf_range(fire_min, fire_max)
	var multiplier: float = 1.0
	if _skill != null:
		fire += phys * _skill.extra_fire_percent / 100.0
		phys *= _skill.more_physical
		if _skill.no_elemental:
			fire = 0.0
		multiplier = _skill.damage_multiplier
	var damage: float = (phys + fire) * multiplier * scale
	var critical: bool = randf() * 100.0 < crit_chance
	if critical:
		damage *= crit_multiplier / 100.0
	var health: Health = Health.of(target)
	health.take_damage(roundf(damage))
	if culling_percent > 0.0 and not health.is_dead() 			and health.current < health.max_health * culling_percent / 100.0:
		health.take_damage(health.current + 1.0, &"culling")
	if _skill != null and _skill.leech_percent > 0.0:
		var own: Health = Health.of(_body)
		if own != null:
			own.heal(damage * _skill.leech_percent / 100.0)
	swing_hit.emit(target, damage, critical)


func _enemies_near(center: Vector3, radius: float) -> Array[Node3D]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * strike_height)
	params.collision_mask = target_mask
	params.exclude = [_body.get_rid()]
	var found: Array[Node3D] = []
	for result: Dictionary in _body.get_world_3d().direct_space_state.intersect_shape(params, 32):
		var node: Node3D = result["collider"] as Node3D
		var health: Health = Health.of(node)
		if health != null and not health.is_dead() and not found.has(node):
			found.append(node)
	return found


## Living targets in the swing area, closest first. Only the closest unless `hit_all`.
func _find_targets(hit_all: bool) -> Array[Node3D]:
	var shape := SphereShape3D.new()
	shape.radius = _skill.reach if _skill != null else reach
	if hit_all:
		shape.radius *= area_multiplier
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
