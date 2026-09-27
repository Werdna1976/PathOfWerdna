class_name CharacterStats
extends Node
## Adds up the character's base values, attributes and equipped gear, then
## applies the results to the other components. Recomputes whenever
## equipment changes. `values` holds every final number for the character sheet.
##
## Attributes (DESIGN.md):
##   STR: +0.5 max life and +0.2% melee physical damage per point
##   DEX: +2 accuracy and +0.2% evasion per point
##   INT: +0.5 max mana and +0.2% energy shield per point

signal recomputed

const UNARMED_DAMAGE: Vector2 = Vector2(2.0, 6.0)
const UNARMED_APS: float = 1.2
## Skills' base timings assume a weapon with this many attacks per second.
const REFERENCE_APS: float = 1.5
const BASE_CRIT_CHANCE: float = 5.0
const BASE_CRIT_MULTIPLIER: float = 150.0

@export var base_strength: int = 20
@export var base_dexterity: int = 14
@export var base_intelligence: int = 14
## Life and mana before attributes.
@export var base_life: float = 90.0
@export var base_mana: float = 43.0
@export var base_move_speed: float = 5.0
## Percent of maximum mana regenerated per second.
@export var base_mana_regen_percent: float = 4.0
@export var base_accuracy: float = 50.0

@export var equipment: Equipment
@export var health: Health
@export var mana: Mana
@export var defenses: Defenses
@export var melee: MeleeAttack
@export var movement: NavMovement
@export var potions: PotionBelt
@export var skill_bar: SkillBar

## stat name -> final value
var values: Dictionary = {}
## Global stat totals from gear (before attributes are applied).
var gear: Dictionary = {}


func _ready() -> void:
	add_to_group(PotionBelt.KILL_LISTENERS)
	equipment.changed.connect(recompute)
	melee.swing_hit.connect(_on_swing_hit)
	recompute()


func stat(name: StringName) -> float:
	return values.get(name, 0.0)


func recompute() -> void:
	gear = {}
	var armour: float = 0.0
	var evasion: float = 0.0
	var energy_shield: float = 0.0
	for item: Item in equipment.equipped():
		var totals: Dictionary = item.global_stats()
		for key: StringName in totals:
			gear[key] = gear.get(key, 0) + totals[key]
		armour += item.local_defence(&"armour")
		evasion += item.local_defence(&"evasion")
		energy_shield += item.local_defence(&"energy_shield")

	var v: Dictionary = {}
	v[&"strength"] = base_strength + _g(&"strength")
	v[&"dexterity"] = base_dexterity + _g(&"dexterity")
	v[&"intelligence"] = base_intelligence + _g(&"intelligence")
	v[&"max_life"] = floorf(base_life + _g(&"max_life") + v[&"strength"] * 0.5)
	v[&"max_mana"] = floorf(base_mana + _g(&"max_mana") + v[&"intelligence"] * 0.5)
	v[&"armour"] = roundf(armour)
	v[&"evasion"] = roundf(evasion * (1.0 + v[&"dexterity"] * 0.002))
	v[&"energy_shield"] = roundf(energy_shield * (1.0 + v[&"intelligence"] * 0.002))
	var off_hand: Item = equipment.get_item(&"off_hand")
	v[&"block_chance"] = float(off_hand.base.stats.get("block", 0)) if off_hand != null else 0.0
	for element: StringName in [&"fire", &"cold", &"lightning", &"chaos"]:
		v[StringName(element + "_resistance")] = _g(StringName(element + "_resistance"))

	var weapon: Item = equipment.get_item(&"main_hand")
	var weapon_damage: Vector2 = weapon.weapon_damage() if weapon != null else UNARMED_DAMAGE
	var aps: float = weapon.attacks_per_second() if weapon != null else UNARMED_APS
	var phys_scale: float = 1.0 + v[&"strength"] * 0.002
	var added_phys: float = _g(&"added_phys_attacks")
	var added_fire: float = _g(&"added_fire_attacks")
	v[&"phys_min"] = roundf((weapon_damage.x + added_phys) * phys_scale)
	v[&"phys_max"] = roundf((weapon_damage.y + added_phys * 2.0) * phys_scale)
	v[&"fire_min"] = added_fire
	v[&"fire_max"] = added_fire * 2.0
	v[&"attack_speed_increase"] = _g(&"attack_speed")
	v[&"attacks_per_second"] = aps * (1.0 + v[&"attack_speed_increase"] / 100.0)
	v[&"crit_chance"] = BASE_CRIT_CHANCE * (1.0 + _g(&"crit_chance") / 100.0)
	v[&"crit_multiplier"] = BASE_CRIT_MULTIPLIER + _g(&"crit_multiplier")
	v[&"accuracy"] = base_accuracy + _g(&"accuracy") + v[&"dexterity"] * 2.0
	v[&"area_of_effect"] = _g(&"area_of_effect")
	v[&"move_speed"] = base_move_speed * (1.0 + _g(&"movement_speed") / 100.0)
	v[&"movement_speed_increase"] = _g(&"movement_speed")
	v[&"life_regen"] = _g(&"life_regen")
	v[&"mana_regen"] = v[&"max_mana"] * base_mana_regen_percent / 100.0 * (1.0 + _g(&"mana_regen_percent") / 100.0)
	for key: StringName in [&"life_on_hit", &"bleed_chance", &"stun_duration", &"item_rarity",
			&"item_quantity", &"life_recoup", &"culling_strike", &"cooldown_recovery",
			&"potion_charges_on_kill", &"mana_on_kill", &"avoid_stun", &"avoid_ailments",
			&"explode_on_kill_chance", &"onslaught_on_kill_chance"]:
		v[key] = _g(key)
	values = v
	_apply()
	recomputed.emit()


func _apply() -> void:
	health.set_max_health(values[&"max_life"])
	mana.set_max_mana(values[&"max_mana"])
	mana.regen_per_second = values[&"mana_regen"]

	defenses.armour = values[&"armour"]
	defenses.evasion = values[&"evasion"]
	defenses.block_chance = values[&"block_chance"]
	for element: StringName in [&"fire", &"cold", &"lightning", &"chaos"]:
		defenses.resistances[element] = values[StringName(element + "_resistance")]
	defenses.recoup_percent = values[&"life_recoup"]
	defenses.set_max_energy_shield(values[&"energy_shield"])

	melee.damage_min = values[&"phys_min"] + values[&"fire_min"]
	melee.damage_max = values[&"phys_max"] + values[&"fire_max"]
	melee.speed_multiplier = values[&"attacks_per_second"] / REFERENCE_APS
	melee.crit_chance = values[&"crit_chance"]
	melee.crit_multiplier = values[&"crit_multiplier"]
	melee.area_multiplier = sqrt(1.0 + values[&"area_of_effect"] / 100.0)
	melee.culling_percent = values[&"culling_strike"]

	movement.move_speed = values[&"move_speed"]
	potions.bonus_charges_per_kill = values[&"potion_charges_on_kill"]
	skill_bar.cooldown_rate = 1.0 + values[&"cooldown_recovery"] / 100.0


func _physics_process(delta: float) -> void:
	if values.get(&"life_regen", 0.0) > 0.0:
		health.heal(values[&"life_regen"] * delta)


func on_enemy_killed(_enemy: Node3D) -> void:
	mana.restore(stat(&"mana_on_kill"))


func _on_swing_hit(_target: Node3D, _damage: float, _critical: bool) -> void:
	health.heal(stat(&"life_on_hit"))


func _g(key: StringName) -> float:
	return float(gear.get(key, 0))
