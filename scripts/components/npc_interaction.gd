class_name NpcInteraction
extends Node
## Walks the player to a clicked NPC (e.g. a vendor) and calls its
## interact() on arrival. A new move click cancels it.

@export var movement: NavMovement
@export var health: Health
@export var interact_range: float = 2.4

var _target: Node3D

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D


func request(npc: Node3D) -> void:
	if health.is_dead():
		return
	_target = npc
	movement.set_target(npc.global_position)


func cancel() -> void:
	_target = null


func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or health.is_dead():
		_target = null
		return
	var offset: Vector3 = _target.global_position - _body.global_position
	offset.y = 0.0
	if offset.length() > interact_range:
		if not movement.is_moving():
			movement.set_target(_target.global_position)
		return
	movement.stop()
	var npc: Node3D = _target
	_target = null
	if npc.has_method("interact"):
		npc.call("interact", _body)
