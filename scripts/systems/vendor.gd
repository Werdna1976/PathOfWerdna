class_name Vendor
extends StaticBody3D
## A town vendor. Click them to walk over and open their shop.
## - GEAR vendors stock normal and magic items; the stock is rolled whenever
##   the town loads, so it refreshes each time you come back from the wilds.
## - GEM vendors always offer one of every gem (buying never runs them out).
## Placeholder look: a coloured capsule with a floating name.

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
