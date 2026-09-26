class_name PlayerCombat
extends Node
## Right-click attacks (Heavy Strike for now). Clicking an enemy walks into
## range and strikes it; clicking the ground strikes in place toward the
## cursor. Holding the button keeps attacking. Moving cancels the attack.

@export var movement: NavMovement
@export var melee: MeleeAttack
@export var health: Health
@export_flags_3d_physics var enemy_mask: int = 4
@export_flags_3d_physics var ground_mask: int = 1

## Enemy we're walking toward or striking.
var _target: Node3D
## Ground point to strike toward in place, or NO_HIT.
var _strike_point: Vector3 = CursorRay.NO_HIT

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	melee.swing_started.connect(func() -> void: movement.locked = true)
	melee.swing_finished.connect(func() -> void: movement.locked = false)


## Orders an attack on `enemy` (also used by tests).
func attack_target(enemy: Node3D) -> void:
	_target = enemy
	_strike_point = CursorRay.NO_HIT


## Orders a strike in place toward `point`.
func attack_point(point: Vector3) -> void:
	_target = null
	_strike_point = point


func clear() -> void:
	_target = null
	_strike_point = CursorRay.NO_HIT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not health.is_dead():
		_pick_from_cursor()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if health.is_dead():
		return
	if Input.is_action_pressed("move"):
		clear()
		return
	var holding: bool = Input.is_action_pressed("attack")
	if melee.is_busy():
		return
	if holding and _target == null and not _strike_point.is_finite():
		_pick_from_cursor()

	if _target != null:
		_pursue_target(holding)
	elif _strike_point.is_finite():
		movement.stop()
		melee.swing(_strike_point - _body.global_position)
		_strike_point = CursorRay.NO_HIT


func _pursue_target(holding: bool) -> void:
	if not is_instance_valid(_target) or Health.of(_target) == null or Health.of(_target).is_dead():
		_target = null
		return
	var offset: Vector3 = _target.global_position - _body.global_position
	offset.y = 0.0
	if offset.length() <= melee.approach_distance():
		movement.stop()
		melee.swing(offset)
		# A single click is a single strike; holding keeps swinging.
		if not holding:
			_target = null
	else:
		movement.set_target(_target.global_position)


func _pick_from_cursor() -> void:
	var hit: Dictionary = CursorRay.cast(get_viewport(), enemy_mask)
	if not hit.is_empty():
		var enemy: Node3D = hit["collider"] as Node3D
		var enemy_health: Health = Health.of(enemy)
		if enemy_health != null and not enemy_health.is_dead():
			attack_target(enemy)
			return
	var point: Vector3 = CursorRay.ground_point(get_viewport(), ground_mask)
	if point.is_finite():
		attack_point(point)
