class_name Health
extends Node
## Life pool for anything that can be damaged. UI and feedback components
## listen to its signals instead of being called by attackers directly.

signal damaged(amount: float)
signal changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
## Optional. When set, hits go through block, evasion, armour, resistances and energy shield.
@export var defenses: Defenses

var current: float


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


## Deals a hit of `damage_type` (physical, fire, cold, lightning, chaos).
## `damaged` reports the damage after mitigation, including any taken by energy shield.
func take_damage(amount: float, damage_type: StringName = &"physical") -> void:
	if is_dead() or amount <= 0.0:
		return
	var to_life: float = amount
	if defenses != null:
		amount = defenses.mitigate(amount, damage_type)
		if amount < 0.0:
			return
		to_life = defenses.absorb(amount)
	current = maxf(current - to_life, 0.0)
	damaged.emit(amount)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0 or current >= max_health:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)


## Changes maximum life, keeping the same fraction of life filled.
func set_max_health(value: float) -> void:
	var fraction: float = current / max_health if max_health > 0.0 else 1.0
	max_health = value
	if not is_dead():
		current = clampf(roundf(value * fraction), 1.0, value)
	changed.emit(current, max_health)


func restore_full() -> void:
	if defenses != null:
		defenses.restore_full()
	current = max_health
	changed.emit(current, max_health)


## Finds the Health component on a body, or null.
static func of(node: Node) -> Health:
	return node.get_node_or_null("Health") as Health if node != null else null
