class_name EnemyAI
extends Node
## Basic melee monster brain: idle until the player comes near (or hits it),
## then chase and swing whenever in range. Dies by sinking into the floor.

@export var movement: NavMovement
@export var melee: MeleeAttack
@export var health: Health
## Visual root that tips over on death.
@export var visual: Node3D
@export var aggro_range: float = 11.0
## Seconds between path updates while chasing.
@export var repath_interval: float = 0.25
@export var corpse_time: float = 2.5

var _aggroed: bool = false
var _repath_timer: float = 0.0
var _player: Node3D

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	health.damaged.connect(func(_amount: float) -> void: _aggroed = true)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead() or melee.is_busy():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var player_health: Health = Health.of(_player)
	if player_health != null and player_health.is_dead():
		_aggroed = false
		movement.stop()
		return

	var offset: Vector3 = _player.global_position - _body.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance <= melee.approach_distance():
		movement.stop()
		melee.swing(offset)
		return
	if distance <= aggro_range:
		_aggroed = true
	if not _aggroed:
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or not movement.is_moving():
		_repath_timer = repath_interval
		movement.set_target(_player.global_position)


func _on_died() -> void:
	melee.cancel()
	movement.stop()
	# Corpses can't be hit or block anyone; the tween below owns their motion.
	movement.set_physics_process(false)
	_body.collision_layer = 0
	_body.collision_mask = 0
	var tween: Tween = _body.create_tween()
	tween.tween_property(visual, "rotation:z", deg_to_rad(85.0), 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(corpse_time)
	tween.tween_property(_body, "position:y", -1.2, 0.8)
	tween.tween_callback(_body.queue_free)
