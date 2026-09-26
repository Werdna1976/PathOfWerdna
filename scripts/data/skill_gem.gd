class_name SkillGem
extends GemData
## An active melee skill. Damage is the wielder's weapon roll times
## `damage_multiplier`. A skill with `leap_range` > 0 jumps to the cursor and
## hits everything within `reach` of the landing spot.

@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var damage_multiplier: float = 1.0
## Seconds from the start of the skill until the hit lands.
@export var windup: float = 0.22
## Seconds after the hit before the next action.
@export var recovery: float = 0.3
## How far past the user's centre a target's collider can be and still be hit.
@export var reach: float = 1.6
@export_range(0.0, 360.0) var arc_degrees: float = 110.0
## Hit every target in the area instead of only the closest one.
@export var hits_all: bool = false
@export var leap_range: float = 0.0


func is_leap() -> bool:
	return leap_range > 0.0
