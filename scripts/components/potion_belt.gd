class_name PotionBelt
extends Node
## Potions on keys 1–5. Drinking spends charges and restores life or mana
## over the potion's duration. Kills refill charges; so does respawning.

signal changed
signal drink_failed(reason: String)
signal drank(index: int)

const ACTIONS: Array[StringName] = [&"potion_1", &"potion_2", &"potion_3", &"potion_4", &"potion_5"]
## Called on every node in this group when an enemy dies.
const KILL_LISTENERS: StringName = &"kill_listeners"

@export var potions: Array[PotionData] = []
@export var health: Health
@export var mana: Mana
@export var charges_per_kill: float = 3.0
## Extra charges per kill from gear (charm mods).
var bonus_charges_per_kill: float = 0.0

var charges: Array[float] = []
## Seconds of effect left per potion.
var _active: Array[float] = []


func _ready() -> void:
	add_to_group(KILL_LISTENERS)
	_active.resize(potions.size())
	_active.fill(0.0)
	charges.resize(potions.size())
	refill()


func is_active(index: int) -> bool:
	return _active[index] > 0.0


## Drinks potion `index`. Returns false if there's no potion there or not enough charges.
func drink(index: int) -> bool:
	if index >= potions.size() or health.is_dead():
		return false
	var potion: PotionData = potions[index]
	if charges[index] < potion.charges_per_use:
		drink_failed.emit("%s is empty" % potion.display_name)
		return false
	charges[index] -= potion.charges_per_use
	_active[index] = potion.duration
	changed.emit()
	drank.emit(index)
	return true


func refill() -> void:
	for i: int in potions.size():
		charges[i] = potions[i].max_charges
		_active[i] = 0.0
	changed.emit()


func on_enemy_killed(_enemy: Node3D) -> void:
	for i: int in potions.size():
		charges[i] = minf(charges[i] + charges_per_kill + bonus_charges_per_kill, potions[i].max_charges)
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	for i: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			drink(i)
			get_viewport().set_input_as_handled()
			return


func _physics_process(delta: float) -> void:
	for i: int in potions.size():
		if _active[i] <= 0.0:
			continue
		var potion: PotionData = potions[i]
		var step: float = minf(delta, _active[i])
		_active[i] -= step
		var amount: float = potion.amount * step / potion.duration
		if potion.restores == PotionData.Restores.LIFE:
			health.heal(amount)
		else:
			mana.restore(amount)
