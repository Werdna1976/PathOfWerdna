class_name PlayerCombat
extends Node
## Turns skill-slot input (right click, Q W E R T) into skill use.
## - Melee skills: aimed at an enemy, walk into range and hit it; aimed at the
##   ground, swing in place toward the cursor.
## - Leap skills: jump toward the cursor, up to the skill's range.
## Holding a slot's key keeps using it. Skills work while walking: melee
## swings slow movement (see attack_move_scale) instead of stopping it, and
## while left click is held they hit in place instead of walking to the target.
## A new move click cancels a pending order.

@export var movement: NavMovement
@export var melee: MeleeAttack
@export var health: Health
@export var skill_bar: SkillBar
@export var click_move: ClickMoveInput
## Movement speed multiplier while swinging a melee skill.
@export_range(0.0, 1.0) var attack_move_scale: float = 0.35
@export_flags_3d_physics var enemy_mask: int = 4
@export_flags_3d_physics var ground_mask: int = 1

## Slot of the pending order, or -1.
var _slot: int = -1
## Enemy we're walking toward or striking.
var _target: Node3D
## Ground point to strike toward in place, or NO_HIT.
var _point: Vector3 = CursorRay.NO_HIT

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	melee.swing_started.connect(_on_swing_started)
	melee.swing_finished.connect(_on_swing_finished)
	click_move.move_ordered.connect(clear)


## Orders the skill in `slot` against an enemy (also used by tests).
func order_target(slot: int, enemy: Node3D) -> void:
	_slot = slot
	_target = enemy
	_point = CursorRay.NO_HIT


## Orders the skill in `slot` toward a ground point.
func order_point(slot: int, point: Vector3) -> void:
	_slot = slot
	_target = null
	_point = point


## Right-click (slot 0) shorthands.
func attack_target(enemy: Node3D) -> void:
	order_target(0, enemy)


func attack_point(point: Vector3) -> void:
	order_point(0, point)


func has_order() -> bool:
	return _slot >= 0


func clear() -> void:
	_slot = -1
	_target = null
	_point = CursorRay.NO_HIT


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead():
		return
	for slot: int in SkillBar.SLOT_COUNT:
		if event.is_action_pressed(SkillBar.SLOT_ACTIONS[slot]):
			_order_from_cursor(slot)
			get_viewport().set_input_as_handled()
			return


func _physics_process(_delta: float) -> void:
	if health.is_dead():
		return
	if melee.is_busy():
		return
	var held: int = _held_slot()
	if _slot < 0 and held >= 0:
		_order_from_cursor(held)
	if _slot < 0:
		return
	var gem: SkillInstance = skill_bar.gem_in(_slot)
	if gem == null:
		clear()
		return
	if _target != null and not _is_alive(_target):
		clear()
		return
	var holding: bool = held == _slot
	if gem.is_leap():
		_leap(gem)
	elif _target != null and not click_move.is_holding():
		_pursue(gem, holding)
	else:
		# Strike in place toward the target or point; any walking continues, slowed.
		var aim: Vector3 = _target.global_position if _target != null else _point
		if aim.is_finite():
			_use(gem, aim - _body.global_position)
		clear()


func _pursue(gem: SkillInstance, holding: bool) -> void:
	var offset: Vector3 = _target.global_position - _body.global_position
	offset.y = 0.0
	if offset.length() > melee.approach_distance(gem):
		movement.set_target(_target.global_position)
		return
	movement.stop()
	# A single press is a single use; holding keeps attacking the same target.
	if not _use(gem, offset) or not holding:
		clear()


func _leap(gem: SkillInstance) -> void:
	var aim: Vector3 = _target.global_position if _target != null else _point
	var offset: Vector3 = aim - _body.global_position
	offset.y = 0.0
	# Land in front of a targeted enemy rather than on top of it.
	if _target != null:
		offset = offset.normalized() * maxf(offset.length() - 0.9, 0.0)
	if offset.length() > gem.leap_range:
		offset = offset.normalized() * gem.leap_range
	var map: RID = _body.get_world_3d().navigation_map
	var landing: Vector3 = NavigationServer3D.map_get_closest_point(map, _body.global_position + offset)
	landing.y = _body.global_position.y
	# Holding left click keeps walking after landing; otherwise stand at the landing spot.
	if not click_move.is_holding():
		movement.stop()
	_use(gem, offset, landing)
	clear()


func _on_swing_started() -> void:
	var skill: SkillInstance = melee.current_skill()
	if skill != null and skill.is_leap():
		movement.locked = true  # the leap itself moves the body
	else:
		movement.speed_scale = attack_move_scale
		movement.hold_facing = true


func _on_swing_finished() -> void:
	movement.locked = false
	movement.speed_scale = 1.0
	movement.hold_facing = false


## Starts the skill if it's off cooldown and affordable. Returns whether it started.
func _use(gem: SkillInstance, direction: Vector3, leap_to: Vector3 = Vector3.INF) -> bool:
	if AreaInfo.in_town(get_tree()):
		skill_bar.report_failure("You can't use skills in town")
		return false
	var problem: String = skill_bar.check(gem)
	if problem != "":
		skill_bar.report_failure(problem)
		return false
	if not melee.swing(direction, gem, leap_to):
		return false
	skill_bar.commit_use(gem)
	return true


func _held_slot() -> int:
	for slot: int in SkillBar.SLOT_COUNT:
		if Input.is_action_pressed(SkillBar.SLOT_ACTIONS[slot]):
			return slot
	return -1


func _order_from_cursor(slot: int) -> void:
	var hit: Dictionary = CursorRay.cast(get_viewport(), enemy_mask)
	if not hit.is_empty() and _is_alive(hit["collider"] as Node3D):
		order_target(slot, hit["collider"] as Node3D)
		return
	var point: Vector3 = CursorRay.ground_point(get_viewport(), ground_mask)
	if point.is_finite():
		order_point(slot, point)


func _is_alive(node: Node3D) -> bool:
	if not is_instance_valid(node):
		return false
	var node_health: Health = Health.of(node)
	return node_health != null and not node_health.is_dead()
