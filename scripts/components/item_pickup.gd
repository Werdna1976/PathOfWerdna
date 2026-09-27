class_name ItemPickup
extends Node
## Walks the player to a clicked ground item and puts it in the inventory.
## A new move or attack order cancels the pickup.

signal picked_up(item: Item)
signal pickup_failed(reason: String)

@export var movement: NavMovement
@export var inventory: Inventory
@export var health: Health
@export var combat: PlayerCombat
@export var click_move: ClickMoveInput
@export var pickup_range: float = 1.4

var _target: GroundItem

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	click_move.move_ordered.connect(cancel)


func request(ground: GroundItem) -> void:
	if health.is_dead():
		return
	combat.clear()
	_target = ground
	movement.set_target(ground.global_position)


func cancel() -> void:
	_target = null


func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or health.is_dead() or combat.has_order():
		_target = null
		return
	var offset: Vector3 = _target.global_position - _body.global_position
	offset.y = 0.0
	if offset.length() > pickup_range:
		if not movement.is_moving():
			movement.set_target(_target.global_position)
		return
	movement.stop()
	var ground: GroundItem = _target
	_target = null
	if inventory.try_add(ground.item):
		picked_up.emit(ground.item)
		ground.queue_free()
	else:
		pickup_failed.emit("Inventory full")
