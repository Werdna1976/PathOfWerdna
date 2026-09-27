class_name LootDropper
extends Node
## Drops items and currency where its owner dies. Item level comes from the
## area's level (AreaInfo). Magic/rare monsters will raise these chances later.

@export var health: Health
@export_range(0.0, 1.0) var item_chance: float = 0.35
@export_range(0.0, 1.0) var currency_chance: float = 0.15
## Independent rolls for each chance.
@export var rolls: int = 1
@export var scatter_radius: float = 1.2

@onready var _body: Node3D = get_parent() as Node3D


func _ready() -> void:
	health.died.connect(drop)


func drop() -> Array[GroundItem]:
	var level: int = AreaInfo.level_of(get_tree())
	var generator := ItemGenerator.new()
	# The killer's item quantity and rarity (from charms) improve the drops.
	var quantity: float = 1.0
	var rarity_bonus: float = 0.0
	var player: Node = get_tree().get_first_node_in_group("player")
	var stats: CharacterStats = player.get_node_or_null("CharacterStats") as CharacterStats if player != null else null
	if stats != null:
		quantity += stats.stat(&"item_quantity") / 100.0
		rarity_bonus = stats.stat(&"item_rarity")
	var dropped: Array[GroundItem] = []
	for i: int in rolls:
		if generator.rng.randf() < item_chance * quantity:
			var base: ItemBase = generator.random_base(level)
			dropped.append(_place(generator.generate(base, level, -1, rarity_bonus), generator))
		if generator.rng.randf() < currency_chance * quantity:
			var orb: ItemBase = generator.random_base(level, true)
			dropped.append(_place(generator.generate(orb, level), generator))
	return dropped


func _place(item: Item, generator: ItemGenerator) -> GroundItem:
	var angle: float = generator.rng.randf() * TAU
	var distance: float = generator.rng.randf_range(0.4, scatter_radius)
	var at: Vector3 = _body.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	at.y = 0.0
	# Drop into the level, not the body, so the item outlives the corpse.
	return GroundItem.spawn(item, _body.get_parent(), at)
