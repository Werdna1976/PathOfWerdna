extends SceneTree
## Character model headless test: Werdna's and the goblin's models build on
## the Visual/Body/WeaponPivot contract, Werdna's look follows his equipment,
## the procedural animation reacts to movement, and hit flashes cover the
## whole model. Run with:
##   godot --headless --path <project> -s res://tests/test_models.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const GOBLIN_PATH: String = "res://scenes/enemies/goblin.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena: Node3D = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	arena.get_node("GoblinSpawner").free()
	var region: RuntimeNavBaker = arena.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	var player: CharacterBody3D = arena.get_node("Player") as CharacterBody3D
	await physics_frame
	await _test_player(player)
	await _test_goblin(arena)
	arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_player(player: CharacterBody3D) -> void:
	var model: WarriorModel = player.get_node("Visual/Body") as WarriorModel
	var pivot: Node3D = player.get_node("Visual/WeaponPivot")
	_check("Werdna's Visual/Body is a WarriorModel with meshes", model != null
		and model.find_children("*", "MeshInstance3D", true, false).size() > 10)
	_check("his right arm and hand live in the WeaponPivot", model.arm_r != null and pivot.is_ancestor_of(model.right_hand))
	var visuals: EquipmentVisuals = player.get_node("EquipmentVisuals") as EquipmentVisuals
	var equipment: Equipment = player.get_node("Equipment") as Equipment
	_check("the starting hatchet shows as a one-handed axe and the Plate Vest as plate armour",
		visuals.look.get("weapon") == "axe" and not visuals.look.get("two_handed")
		and model.armour == WarriorModel.Armour.PLATE and model.held_weapon() != null
		and model.right_hand.is_ancestor_of(model.held_weapon()))

	var gen := ItemGenerator.new(3)
	equipment.equip(gen.generate(ItemDB.base(&"corroded_blade"), 1, Item.Rarity.NORMAL), &"main_hand")
	_check("a two-handed sword swaps the weapon model", visuals.look.get("weapon") == "sword" and visuals.look.get("two_handed"))
	equipment.equip(gen.generate(ItemDB.base(&"driftwood_club"), 1, Item.Rarity.NORMAL), &"main_hand")
	equipment.equip(gen.generate(ItemDB.base(&"goathide_buckler"), 1, Item.Rarity.NORMAL), &"off_hand")
	_check("a mace and buckler show a mace and a shield in the left hand", visuals.look.get("weapon") == "mace"
		and visuals.look.get("shield") == "dex" and model.held_shield() != null
		and model.left_hand.is_ancestor_of(model.held_shield()))
	var styles: Dictionary = {&"shabby_jerkin": WarriorModel.Armour.LEATHER, &"simple_robe": WarriorModel.Armour.ROBE,
		&"scale_vest": WarriorModel.Armour.SCALE, &"chainmail_vest": WarriorModel.Armour.CHAIN,
		&"padded_vest": WarriorModel.Armour.PADDED, &"plate_vest": WarriorModel.Armour.PLATE}
	var styled: bool = true
	for base_id: StringName in styles:
		equipment.equip(gen.generate(ItemDB.base(base_id), 1, Item.Rarity.NORMAL), &"chest")
		styled = styled and model.armour == styles[base_id]
	_check("each body armour type (AR, EV, ES and hybrids) has its own style", styled)
	equipment.equip(gen.generate(ItemDB.base(&"iron_hat"), 1, Item.Rarity.NORMAL), &"helm")
	_check("a helm shows on his head", model.helm == WarriorModel.Armour.PLATE and model.head.get_child_count() >= 3)
	equipment.unequip(&"off_hand")
	equipment.unequip(&"main_hand")
	_check("unequipping clears the held models", model.held_weapon() == null and model.held_shield() == null)
	equipment.equip(gen.generate(ItemDB.base(&"rusted_hatchet"), 1, Item.Rarity.NORMAL), &"main_hand")

	# Walking animates the legs; standing still doesn't swing them.
	var movement: NavMovement = player.get_node("NavMovement") as NavMovement
	movement.set_target(player.global_position + Vector3(0, 0, 6))
	var max_leg: float = 0.0
	for i: int in 40:
		await process_frame
		max_leg = maxf(max_leg, absf(model.leg_l.rotation.x))
	movement.stop()
	for i: int in 60:
		await process_frame
	_check("walking swings the legs (%.2f rad)" % max_leg, max_leg > 0.2)
	_check("standing still settles the legs", absf(model.leg_l.rotation.x) < 0.05)
	_check("the animator never moves Visual itself", (player.get_node("Visual") as Node3D).position.is_zero_approx())

	# A hit flashes every mesh, then clears the overlay.
	Health.of(player).take_damage(1.0)
	var flashed: int = 0
	for node: Node in player.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).material_overlay != null:
			flashed += 1
	for i: int in 30:
		await process_frame
	var still: int = 0
	for node: Node in player.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).material_overlay != null:
			still += 1
	_check("a hit flashes the whole model (%d meshes) and then clears" % flashed, flashed > 10 and still == 0)


func _test_goblin(arena: Node3D) -> void:
	var goblin: CharacterBody3D = (load(GOBLIN_PATH) as PackedScene).instantiate() as CharacterBody3D
	arena.add_child(goblin)
	goblin.global_position = Vector3(10, 0, 10)
	await process_frame
	var model: GoblinModel = goblin.get_node("Visual/Body") as GoblinModel
	var pivot: Node3D = goblin.get_node("Visual/WeaponPivot")
	_check("the goblin's Visual/Body is a GoblinModel with ears, nose and a club", model != null
		and model.find_children("*", "MeshInstance3D", true, false).size() > 10
		and model.right_hand != null and pivot.is_ancestor_of(model.right_hand))
	Health.of(goblin).take_damage(1000.0)
	for i: int in 10:
		await process_frame
	_check("goblin death still tips the visual over", absf((goblin.get_node("Visual") as Node3D).rotation.x) > 0.01
		or absf((goblin.get_node("Visual") as Node3D).rotation.z) > 0.01 or not is_instance_valid(goblin))


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
