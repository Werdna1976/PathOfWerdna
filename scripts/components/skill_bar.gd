class_name SkillBar
extends Node
## The player's six skill slots: slot 0 is right click, slots 1–5 are Q W E R T.
## Tracks cooldowns and checks mana. Gems come from sockets in Milestone 4;
## until then `known_gems` is the list the slots can be set from.

signal slots_changed
signal use_failed(reason: String)

const SLOT_COUNT: int = 6
const SLOT_ACTIONS: Array[StringName] = [&"attack", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"skill_5"]
const SLOT_KEYS: Array[String] = ["RMB", "Q", "W", "E", "R", "T"]

@export var mana: Mana
@export var known_gems: Array[SkillGem] = []
## Initial loadout by slot. Missing entries are empty.
@export var slots: Array[SkillGem] = []

## Seconds left per gem id.
var _cooldowns: Dictionary = {}


func _ready() -> void:
	slots.resize(SLOT_COUNT)


func gem_in(slot: int) -> SkillGem:
	return slots[slot] if slot >= 0 and slot < SLOT_COUNT else null


func set_slot(slot: int, gem: SkillGem) -> void:
	slots[slot] = gem
	slots_changed.emit()


## Moves the slot to the next known gem, then to empty, then around again.
func cycle_slot(slot: int) -> void:
	var options: Array = known_gems.duplicate()
	options.append(null)
	var index: int = options.find(slots[slot])
	set_slot(slot, options[(index + 1) % options.size()])


func cooldown_left(gem: SkillGem) -> float:
	return _cooldowns.get(gem.id, 0.0) if gem != null else 0.0


## Returns "" when `gem` can be used now, otherwise the reason it can't.
func check(gem: SkillGem) -> String:
	if cooldown_left(gem) > 0.0:
		return "%s is on cooldown" % gem.display_name
	if not mana.has(gem.mana_cost):
		return "Not enough mana"
	return ""


## Pays the gem's cost and starts its cooldown. Call when the skill actually starts.
func commit_use(gem: SkillGem) -> void:
	mana.spend(gem.mana_cost)
	if gem.cooldown > 0.0:
		_cooldowns[gem.id] = gem.cooldown


func report_failure(reason: String) -> void:
	use_failed.emit(reason)


func _physics_process(delta: float) -> void:
	for id: StringName in _cooldowns.keys():
		var left: float = _cooldowns[id] - delta
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left
