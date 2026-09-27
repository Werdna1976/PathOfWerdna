class_name EquipmentVisuals
extends Node
## Makes a WarriorModel show what is equipped: the weapon model for the main
## hand (axe, sword or mace, one- or two-handed), a shield when one is in the
## off hand, and the armour, helm, glove and boot styles for each defence type
## (AR plate, EV leather, ES robe, and the hybrids). Updates on Equipment.changed.

@export var equipment: Equipment
@export var model: WarriorModel

## The last look applied, for tests: {weapon, two_handed, shield, armour, helm}.
var look: Dictionary = {}


func _ready() -> void:
	equipment.changed.connect(refresh)
	refresh.call_deferred()


func refresh() -> void:
	if model == null:
		return
	var weapon: Item = equipment.get_item(&"main_hand")
	var off_hand: Item = equipment.get_item(&"off_hand")
	model.set_look(_style(&"chest"), _style(&"helm"), _style(&"gloves"), _style(&"boots"))
	model.set_held(GearModels.weapon_for(weapon), GearModels.shield_for(off_hand))
	look = {
		"weapon": _weapon_kind(weapon),
		"two_handed": weapon != null and weapon.base.is_two_handed(),
		"shield": GearModels.defence_kind(off_hand.base) if off_hand != null else "",
		"armour": model.armour,
		"helm": model.helm,
	}


func _style(slot: StringName) -> WarriorModel.Armour:
	var item: Item = equipment.get_item(slot)
	if item == null:
		return WarriorModel.Armour.NONE
	return WarriorModel.STYLE_BY_KIND.get(GearModels.defence_kind(item.base), WarriorModel.Armour.NONE)


func _weapon_kind(item: Item) -> String:
	if item == null:
		return ""
	for kind: String in ["axe", "sword", "mace"]:
		if item.base.has_tag(StringName(kind)):
			return kind
	return "weapon"
