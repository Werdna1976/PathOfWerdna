extends Node3D
## Lines up Werdna in each armour style with a different weapon, plus a few
## goblins, on a lit patch of ground. For eyeballing the character models:
##   godot --path <project> -s res://tools/screenshot.gd -- --scene=res://tools/character_preview.tscn --at=0,1,0 --distance=9 --pitch=25 --yaw=0

const LOOKS: Array = [
	# [armour, helm, gloves, boots, weapon kind, two handed, shield kind]
	[WarriorModel.Armour.PLATE, WarriorModel.Armour.PLATE, WarriorModel.Armour.PLATE, WarriorModel.Armour.PLATE, "axe", false, "str"],
	[WarriorModel.Armour.LEATHER, WarriorModel.Armour.LEATHER, WarriorModel.Armour.LEATHER, WarriorModel.Armour.LEATHER, "sword", false, "dex"],
	[WarriorModel.Armour.ROBE, WarriorModel.Armour.ROBE, WarriorModel.Armour.NONE, WarriorModel.Armour.ROBE, "mace", false, "int"],
	[WarriorModel.Armour.SCALE, WarriorModel.Armour.SCALE, WarriorModel.Armour.SCALE, WarriorModel.Armour.NONE, "sword", true, ""],
	[WarriorModel.Armour.CHAIN, WarriorModel.Armour.CHAIN, WarriorModel.Armour.CHAIN, WarriorModel.Armour.CHAIN, "axe", true, ""],
	[WarriorModel.Armour.PADDED, WarriorModel.Armour.NONE, WarriorModel.Armour.NONE, WarriorModel.Armour.PADDED, "mace", true, ""],
	[WarriorModel.Armour.NONE, WarriorModel.Armour.NONE, WarriorModel.Armour.NONE, WarriorModel.Armour.NONE, "", false, "str_int"],
]


func _ready() -> void:
	for i: int in LOOKS.size():
		var look: Array = LOOKS[i]
		var visual := _rig(WarriorModel.new(), Vector3(-6.0 + i * 2.0, 0, 0), 160.0)
		var model: WarriorModel = visual.get_node("Body") as WarriorModel
		model.set_look(look[0], look[1], look[2], look[3])
		var weapon: Node3D = GearModels.weapon(look[4], look[5], float(i) / LOOKS.size()) if look[4] != "" else null
		var shield: Node3D = GearModels.shield(look[6], 0.5) if look[6] != "" else null
		model.set_held(weapon, shield)
	for i: int in 4:
		_rig(GoblinModel.new(), Vector3(-3.0 + i * 2.0, 0, 3.0), 180.0 if i % 2 == 0 else 150.0)


## A Visual node with a WeaponPivot and a model, like the gameplay scenes.
func _rig(model: CharacterModel, at: Vector3, yaw: float) -> Node3D:
	var visual := Node3D.new()
	visual.position = at
	visual.rotation_degrees.y = yaw
	add_child(visual)
	var pivot := Node3D.new()
	pivot.name = "WeaponPivot"
	pivot.position = Vector3(0.3, 1.42, 0) if model is WarriorModel else Vector3(0.22, 0.95, -0.16)
	pivot.rotation_degrees.y = -35.0
	visual.add_child(pivot)
	model.name = "Body"
	visual.add_child(model)
	return visual
