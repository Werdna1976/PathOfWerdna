class_name SupportGem
extends GemData
## A support gem. It modifies every compatible active gem socketed in the
## same item (all sockets on an item are linked).

## The active gem must have at least one of these tags to be supported.
@export var supported_tags: Array[StringName] = [&"attack"]
## Multiplies the supported skill's mana cost.
@export var mana_multiplier: float = 1.2
## Percent "more" damage (all types).
@export var more_damage: float = 0.0
## Percent "more" physical damage.
@export var more_physical: float = 0.0
## Gain this percent of physical damage as extra fire damage.
@export var extra_fire_percent: float = 0.0
## Percent faster attacks for the supported skill.
@export var attack_speed: float = 0.0
## Strikes also hit enemies within this radius of the target.
@export var splash_radius: float = 0.0
## Splash hits deal this percent of the hit's damage.
@export var splash_damage_percent: float = 60.0
## Percent of damage dealt healed as life.
@export var leech_percent: float = 0.0
## The supported skill deals no elemental damage.
@export var no_elemental: bool = false
## Stat lines shown in the tooltip.
@export var effect_lines: Array[String] = []


func kind() -> Kind:
	return Kind.SUPPORT


func can_support(active: SkillGem) -> bool:
	for tag: StringName in supported_tags:
		if active.tags.has(tag):
			return true
	return false
