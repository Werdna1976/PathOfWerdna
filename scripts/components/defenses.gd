class_name Defenses
extends Node
## Turns a character's defensive stats into damage taken, PoE style:
## 1. Block (shields) stops the whole hit.
## 2. Evasion can dodge physical attacks entirely.
## 3. Armour reduces physical hits: reduction = A / (A + 5 × damage), max 90%.
##    Big hits get through armour better than small ones.
## 4. Resistances reduce elemental and chaos damage (capped at 75%).
## 5. Energy shield absorbs what's left before life, and recharges after
##    ES_RECHARGE_DELAY seconds without taking damage.
## 6. Life recoup heals back a share of damage taken over RECOUP_TIME seconds.

signal avoided(how: String)
signal energy_shield_changed(current: float, maximum: float)

const MAX_ARMOUR_REDUCTION: float = 0.9
const RESIST_CAP: float = 75.0
const MAX_EVADE_CHANCE: float = 0.75
const ES_RECHARGE_DELAY: float = 2.0
## Fraction of maximum energy shield restored per second while recharging.
const ES_RECHARGE_RATE: float = 0.33
const RECOUP_TIME: float = 4.0

@export var health: Health

var armour: float = 0.0
var evasion: float = 0.0
## Percent (0–75).
var block_chance: float = 0.0
## Damage type -> percent. Values above RESIST_CAP are kept but capped when used.
var resistances: Dictionary = {&"fire": 0.0, &"cold": 0.0, &"lightning": 0.0, &"chaos": 0.0}
var max_energy_shield: float = 0.0
var energy_shield: float = 0.0
## Percent of damage taken recouped as life.
var recoup_percent: float = 0.0

var _since_hit: float = 999.0
## Pending recoup: [{amount_per_second, time_left}]
var _recoup: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func evade_chance() -> float:
	return minf(evasion / (evasion + 250.0), MAX_EVADE_CHANCE) if evasion > 0.0 else 0.0


func armour_reduction(damage: float) -> float:
	if armour <= 0.0 or damage <= 0.0:
		return 0.0
	return minf(armour / (armour + 5.0 * damage), MAX_ARMOUR_REDUCTION)


func set_max_energy_shield(value: float) -> void:
	var was_full: bool = energy_shield >= max_energy_shield
	max_energy_shield = value
	energy_shield = value if was_full else minf(energy_shield, value)
	energy_shield_changed.emit(energy_shield, max_energy_shield)


## Returns the damage left after avoidance and mitigation, or -1 if avoided.
func mitigate(amount: float, damage_type: StringName) -> float:
	if block_chance > 0.0 and _rng.randf() * 100.0 < block_chance:
		avoided.emit("Block")
		return -1.0
	if damage_type == &"physical":
		if _rng.randf() < evade_chance():
			avoided.emit("Evade")
			return -1.0
		return amount * (1.0 - armour_reduction(amount))
	var resist: float = minf(resistances.get(damage_type, 0.0), RESIST_CAP)
	return amount * (1.0 - resist / 100.0)


## Soaks damage with energy shield. Returns the part that reaches life.
func absorb(amount: float) -> float:
	_since_hit = 0.0
	if recoup_percent > 0.0:
		_recoup.append({"rate": amount * recoup_percent / 100.0 / RECOUP_TIME, "left": RECOUP_TIME})
	if energy_shield <= 0.0:
		return amount
	var soaked: float = minf(energy_shield, amount)
	energy_shield -= soaked
	energy_shield_changed.emit(energy_shield, max_energy_shield)
	return amount - soaked


func restore_full() -> void:
	energy_shield = max_energy_shield
	_recoup.clear()
	energy_shield_changed.emit(energy_shield, max_energy_shield)


func _physics_process(delta: float) -> void:
	_since_hit += delta
	if _since_hit >= ES_RECHARGE_DELAY and energy_shield < max_energy_shield:
		energy_shield = minf(energy_shield + max_energy_shield * ES_RECHARGE_RATE * delta, max_energy_shield)
		energy_shield_changed.emit(energy_shield, max_energy_shield)
	for i: int in range(_recoup.size() - 1, -1, -1):
		var entry: Dictionary = _recoup[i]
		var step: float = minf(delta, entry["left"])
		health.heal(entry["rate"] * step)
		entry["left"] -= step
		if entry["left"] <= 0.0:
			_recoup.remove_at(i)
