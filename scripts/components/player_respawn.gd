class_name PlayerRespawn
extends Node
## No death penalty: when the player dies they collapse, then get back up at
## their spawn point with full life after a short delay.

signal respawned

@export var health: Health
@export var movement: NavMovement
@export var melee: MeleeAttack
@export var combat: PlayerCombat
@export var mana: Mana
@export var potions: PotionBelt
## Visual root that tips over on death.
@export var visual: Node3D
@export var respawn_delay: float = 3.0

var _spawn_position: Vector3

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	_spawn_position = _body.global_position
	health.died.connect(_on_died)


## Where the player gets back up: the entry of the zone they're in.
func set_spawn(position: Vector3) -> void:
	_spawn_position = position


func _on_died() -> void:
	melee.cancel()
	combat.clear()
	movement.stop()
	var tween: Tween = create_tween()
	tween.tween_property(visual, "rotation:x", deg_to_rad(-85.0), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(respawn_delay)
	tween.tween_callback(_respawn)


func _respawn() -> void:
	visual.rotation.x = 0.0
	_body.global_position = _spawn_position
	_body.reset_physics_interpolation()
	movement.stop()
	health.restore_full()
	mana.restore_full()
	potions.refill()
	respawned.emit()
