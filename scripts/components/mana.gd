class_name Mana
extends Node
## Mana pool with passive regeneration. Skills spend it; potions restore it.

signal changed(current: float, maximum: float)

@export var max_mana: float = 50.0
@export var regen_per_second: float = 2.0

var current: float


func _ready() -> void:
	current = max_mana


func has(amount: float) -> bool:
	return current >= amount


## Spends `amount` if available. Returns false (and spends nothing) otherwise.
func spend(amount: float) -> bool:
	if not has(amount):
		return false
	if amount > 0.0:
		current -= amount
		changed.emit(current, max_mana)
	return true


func restore(amount: float) -> void:
	if amount <= 0.0 or current >= max_mana:
		return
	current = minf(current + amount, max_mana)
	changed.emit(current, max_mana)


## Changes maximum mana, keeping the same fraction of mana filled.
func set_max_mana(value: float) -> void:
	var fraction: float = current / max_mana if max_mana > 0.0 else 1.0
	max_mana = value
	current = roundf(value * fraction)
	changed.emit(current, max_mana)


func restore_full() -> void:
	current = max_mana
	changed.emit(current, max_mana)


func _physics_process(delta: float) -> void:
	restore(regen_per_second * delta)


## Finds the Mana component on a body, or null.
static func of(node: Node) -> Mana:
	return node.get_node_or_null("Mana") as Mana if node != null else null
