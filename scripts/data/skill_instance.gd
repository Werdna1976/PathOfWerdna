class_name SkillInstance
extends RefCounted
## An active gem combined with the supports linked to it: the numbers the
## skill actually uses. Built by SkillBar from socketed gems; MeleeAttack and
## PlayerCombat read it.

var gem: SkillGem
## The socketed gem item this came from (null for Default Attack).
var gem_item: Item
## Supports that actually apply (compatible with the gem).
var supports: Array[SupportGem] = []

var id: StringName
var display_name: String
var short_name: String
var mana_cost: float
var cooldown: float
var damage_multiplier: float
var more_physical: float = 1.0
var extra_fire_percent: float = 0.0
var no_elemental: bool = false
var windup: float
var recovery: float
var reach: float
var arc_degrees: float
var hits_all: bool
var leap_range: float
var splash_radius: float = 0.0
var splash_damage_percent: float = 60.0
var leech_percent: float = 0.0


func _init(active: SkillGem, linked: Array = [], from_item: Item = null) -> void:
	gem = active
	gem_item = from_item
	id = active.id
	display_name = active.display_name
	short_name = active.short_name
	cooldown = active.cooldown
	reach = active.reach
	arc_degrees = active.arc_degrees
	hits_all = active.hits_all
	leap_range = active.leap_range
	var cost_multiplier: float = 1.0
	var speed: float = 1.0
	var more: float = 1.0
	for support: SupportGem in linked:
		if support == null or not support.can_support(active):
			continue
		supports.append(support)
		cost_multiplier *= support.mana_multiplier
		speed *= 1.0 + support.attack_speed / 100.0
		more *= 1.0 + support.more_damage / 100.0
		more_physical *= 1.0 + support.more_physical / 100.0
		extra_fire_percent += support.extra_fire_percent
		leech_percent += support.leech_percent
		no_elemental = no_elemental or support.no_elemental
		if support.splash_radius > splash_radius:
			splash_radius = support.splash_radius
			splash_damage_percent = support.splash_damage_percent
	mana_cost = roundf(active.mana_cost * cost_multiplier)
	damage_multiplier = active.damage_multiplier * more
	windup = active.windup / speed
	recovery = active.recovery / speed


func is_leap() -> bool:
	return leap_range > 0.0
