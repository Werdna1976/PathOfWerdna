class_name Health
extends Node
## Life pool for anything that can be damaged. UI and feedback components
## listen to its signals instead of being called by attackers directly.

signal damaged(amount: float)
signal changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current: float


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


func take_damage(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()


func restore_full() -> void:
	current = max_health
	changed.emit(current, max_health)


## Finds the Health component on a body, or null.
static func of(node: Node) -> Health:
	return node.get_node_or_null("Health") as Health if node != null else null
