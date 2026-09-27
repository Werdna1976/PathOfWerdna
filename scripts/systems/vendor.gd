class_name Vendor
extends StaticBody3D
## A town vendor. Click them to walk over and open their shop.
## - GEAR vendors stock normal and magic items; the stock is rolled whenever
##   the town loads, so it refreshes each time you come back from the wilds.
## - GEM vendors always offer one of every gem (buying never runs them out).
## Looks: a WarriorModel dressed by `model_armour` / `model_helm`, holding
## `held_weapon` (an axe/sword/mace kind, or empty), facing +Z toward
## customers, with a floating name. Set `model_armour` to -1 for the old
## coloured capsule.

enum Kind { GEAR, GEMS }

const GROUP: StringName = &"vendors"
## Clickable NPC physics layer (layer 6, "npc"), plus world so they block movement.
const NPC_LAYER: int = 32

@export var kind: Kind = Kind.GEAR
@export var vendor_name: String = "Vendor"
@export var body_color: Color = Color(0.5, 0.4, 0.3)
@export var stock_size: int = 12
## Item level of gear stock.
@export var stock_item_level: int = 3
@export_range(0.0, 1.0) var magic_chance: float = 0.35
## WarriorModel.Armour style for the vendor's clothes, or -1 for a capsule.
@export var model_armour: int = WarriorModel.Armour.LEATHER
@export var model_helm: int = WarriorModel.Armour.NONE
## "axe", "sword" or "mace" to hold one, or empty.
@export var held_weapon: String = ""
@export var cape_color: Color = Color(0, 0, 0, 0)

var stock: Array[Item] = []


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 1 | NPC_LAYER
	collision_mask = 0
	_build_body()
	restock()


func restock() -> void:
	stock.clear()
	if kind == Kind.GEMS:
		for id: StringName in ItemDB.GEM_PATHS:
			stock.append(ItemDB.make_gem(id))
		return
	var generator := ItemGenerator.new()
	for i: int in stock_size:
		var base: ItemBase = generator.random_base(stock_item_level)
		var rarity: Item.Rarity = Item.Rarity.MAGIC if generator.rng.randf() < magic_chance else Item.Rarity.NORMAL
		stock.append(generator.generate(base, stock_item_level, rarity))


## Removes a bought item from stock, or hands out a fresh copy for gems.
func take(item: Item) -> Item:
	if kind == Kind.GEMS:
		return ItemDB.make_gem(item.gem.id)
	stock.erase(item)
	return item


## Called by NpcInteraction when the player arrives.
func interact(_player: Node3D) -> void:
	var game: Game = Game.of(get_tree())
	if game != null:
		game.hud.open_vendor(self)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)

	if model_armour >= 0:
		_build_model()
	else:
		var mesh := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.45
		capsule_mesh.height = 1.9
		mesh.mesh = capsule_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = body_color
		material.roughness = 0.8
		mesh.material_override = material
		mesh.position.y = 0.95
		add_child(mesh)

	var label := Label3D.new()
	label.text = vendor_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.85, 0.55)
	label.position.y = 2.4
	add_child(label)


## Same rig as the player: Visual with a WeaponPivot and a WarriorModel.
func _build_model() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation_degrees.y = 180.0  # the model faces -Z; vendors face +Z
	add_child(visual)
	var pivot := Node3D.new()
	pivot.name = "WeaponPivot"
	pivot.position = Vector3(0.3, 1.42, 0)
	pivot.rotation_degrees.y = -35.0
	visual.add_child(pivot)
	var model := WarriorModel.new()
	model.name = "Body"
	model.cape = cape_color.a > 0.0
	model.cape_color = cape_color
	visual.add_child(model)
	model.set_look(model_armour as WarriorModel.Armour, model_helm as WarriorModel.Armour,
		WarriorModel.Armour.NONE, WarriorModel.Armour.NONE)
	if held_weapon != "":
		model.set_held(GearModels.weapon(held_weapon, false, 0.3), null)
		model.right_hand.rotation_degrees.x = 70.0
