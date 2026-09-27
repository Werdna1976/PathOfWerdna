class_name SkillBar
extends Node
## The player's six skill slots: slot 0 is right click, slots 1–5 are Q W E R T.
## Skills come from active gems socketed in equipped gear, each supported by
## the support gems in the same item. When gear or gems change, existing
## assignments are kept, new skills fill the first empty slot, and removed
## skills leave their slot empty. An empty right-click slot uses Default Attack.
## Also tracks cooldowns and checks mana.

signal slots_changed
signal use_failed(reason: String)

const SLOT_COUNT: int = 6
const SLOT_ACTIONS: Array[StringName] = [&"attack", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"skill_5"]
const SLOT_KEYS: Array[String] = ["RMB", "Q", "W", "E", "R", "T"]

@export var mana: Mana
@export var equipment: Equipment
@export var default_attack: SkillGem

## Cooldowns tick this much faster (1.25 = 25% increased cooldown recovery).
var cooldown_rate: float = 1.0

## Assigned skills per slot (null = empty).
var _slots: Array[SkillInstance] = []
## Every skill currently granted by equipped gems.
var _available: Array[SkillInstance] = []
var _default: SkillInstance
## Seconds left per skill id.
var _cooldowns: Dictionary = {}


func _ready() -> void:
	_slots.resize(SLOT_COUNT)
	_default = SkillInstance.new(default_attack)
	equipment.changed.connect(rebuild)
	rebuild()


## The skill used by `slot`. Slot 0 falls back to Default Attack.
func gem_in(slot: int) -> SkillInstance:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	if _slots[slot] == null and slot == 0:
		return _default
	return _slots[slot]


func available_skills() -> Array[SkillInstance]:
	return _available


func set_slot(slot: int, skill: SkillInstance) -> void:
	_slots[slot] = skill
	slots_changed.emit()


## Moves the slot to the next available skill, then to empty, then around again.
func cycle_slot(slot: int) -> void:
	var options: Array = _available.duplicate()
	options.append(null)
	var index: int = options.find(_slots[slot])
	set_slot(slot, options[(index + 1) % options.size()])


## Recreates skills from equipped gems, keeping slot assignments by gem item.
func rebuild() -> void:
	var fresh: Array[SkillInstance] = []
	for slot_name: StringName in Equipment.SLOTS:
		var item: Item = equipment.get_item(slot_name)
		if item == null:
			continue
		var supports: Array = []
		for g: Item in item.gems():
			if g.gem is SupportGem:
				supports.append(g.gem)
		for g: Item in item.gems():
			if g.gem is SkillGem:
				fresh.append(SkillInstance.new(g.gem as SkillGem, supports, g))

	var placed: Array[SkillInstance] = []
	for slot: int in SLOT_COUNT:
		var old: SkillInstance = _slots[slot]
		_slots[slot] = null
		if old == null:
			continue
		for skill: SkillInstance in fresh:
			if skill.gem_item == old.gem_item and not placed.has(skill):
				_slots[slot] = skill
				placed.append(skill)
				break
	for skill: SkillInstance in fresh:
		if placed.has(skill) or _had_skill(skill):
			continue
		var empty: int = _slots.find(null)
		if empty >= 0:
			_slots[empty] = skill
			placed.append(skill)
	_available = fresh
	slots_changed.emit()


func cooldown_left(skill: SkillInstance) -> float:
	return _cooldowns.get(skill.id, 0.0) if skill != null else 0.0


## Returns "" when `skill` can be used now, otherwise the reason it can't.
func check(skill: SkillInstance) -> String:
	if cooldown_left(skill) > 0.0:
		return "%s is on cooldown" % skill.display_name
	if not mana.has(skill.mana_cost):
		return "Not enough mana"
	return ""


## Pays the skill's cost and starts its cooldown. Call when the skill actually starts.
func commit_use(skill: SkillInstance) -> void:
	mana.spend(skill.mana_cost)
	if skill.cooldown > 0.0:
		_cooldowns[skill.id] = skill.cooldown


func report_failure(reason: String) -> void:
	use_failed.emit(reason)


## True if this gem was already available before the rebuild (the player
## chose to leave it unassigned), so it shouldn't be auto-slotted again.
func _had_skill(skill: SkillInstance) -> bool:
	for old: SkillInstance in _available:
		if old.gem_item == skill.gem_item:
			return true
	return false


func _physics_process(delta: float) -> void:
	for id: StringName in _cooldowns.keys():
		var left: float = _cooldowns[id] - delta * cooldown_rate
		if left <= 0.0:
			_cooldowns.erase(id)
		else:
			_cooldowns[id] = left
