extends SceneTree
## Town, vendors and zone travel, using the real game scene (main.tscn).
## Run with:
##   godot --headless --path <project> -s res://tests/test_town.gd
## Exits with 0 when every check passes, 1 otherwise.

const MAIN_PATH: String = "res://scenes/main.tscn"

var _failures: int = 0
var _game: Game
var _player: CharacterBody3D
var _inventory: Inventory
var _hud: Hud
var _messages: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = (load(MAIN_PATH) as PackedScene).instantiate() as Game
	root.add_child(_game)
	await _wait_for_zone("Town")
	_player = _game.player
	_inventory = _player.get_node("Inventory") as Inventory
	_hud = _game.hud
	(_player.get_node("SkillBar") as SkillBar).use_failed.connect(func(t: String) -> void: _messages.append(t))
	_hud.vendor_screen.message.connect(func(t: String) -> void: _messages.append(t))

	_test_town_is_safe()
	await _test_vendors()
	await _test_travel()

	_game.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _zone_info() -> AreaInfo:
	return _game.current_zone.get_node("AreaInfo") as AreaInfo


func _wait_for_zone(zone_name: String) -> void:
	for i: int in 300:
		await physics_frame
		if _game.current_zone != null and _game.current_zone.name == zone_name:
			var region: RuntimeNavBaker = _game.current_zone.get_node("NavigationRegion3D") as RuntimeNavBaker
			if region.is_navigation_ready:
				await physics_frame
				return
	_check("zone %s loaded" % zone_name, false)


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _test_town_is_safe() -> void:
	var info: AreaInfo = _zone_info()
	_check("the game starts in Werdna's Camp", info.zone_name == "Werdna's Camp" and info.is_town)
	var entry: Vector3 = _game.current_zone.get_node("Entries/start").global_position
	_check("the player arrives at the town entry", _player.global_position.distance_to(entry) < 0.3)
	_check("the town has two vendors", get_nodes_in_group(Vendor.GROUP).size() == 2)
	_check("the town has no monsters", get_nodes_in_group("enemies").is_empty())
	var combat: PlayerCombat = _player.get_node("PlayerCombat") as PlayerCombat
	var melee: MeleeAttack = _player.get_node("Melee") as MeleeAttack
	combat.order_point(0, _player.global_position + Vector3(0, 0, -2))
	await _frames(3)
	_check("skills can't be used in town", not melee.is_busy() and _messages.has("You can't use skills in town"))
	_check("Werdna starts with 4 Transmutation and 2 Alteration Orbs",
		Shop.count(_inventory, &"orb_transmutation") == 4 and Shop.count(_inventory, &"orb_alteration") == 2)


func _vendor(kind: Vendor.Kind) -> Vendor:
	for node: Node in get_nodes_in_group(Vendor.GROUP):
		if (node as Vendor).kind == kind:
			return node as Vendor
	return null


func _stock_item(vendor: Vendor, predicate: Callable) -> Item:
	for item: Item in vendor.stock:
		if predicate.call(item):
			return item
	return null


func _test_vendors() -> void:
	var gems: Vendor = _vendor(Vendor.Kind.GEMS)
	var gear: Vendor = _vendor(Vendor.Kind.GEAR)
	var npc: NpcInteraction = _player.get_node("NpcInteraction") as NpcInteraction
	npc.request(gems)
	for i: int in 240:
		await physics_frame
		if _hud.vendor_screen.visible:
			break
	_check("clicking a vendor walks over and opens the shop", _hud.vendor_screen.visible and _hud.vendor_screen.vendor == gems)
	_check("the inventory opens beside the shop", _hud.inventory_screen.visible)
	_check("the gem vendor stocks every gem", gems.stock.size() == ItemDB.GEM_PATHS.size())

	var screen: VendorScreen = _hud.vendor_screen
	var cleave: Item = _stock_item(gems, func(i: Item) -> bool: return i.gem.id == &"cleave")
	var bought: bool = screen.buy(cleave)
	_check("buying Cleave costs 1 Transmutation Orb", bought and Shop.count(_inventory, &"orb_transmutation") == 3)
	_check("the bought gem lands in the bag", _inventory.items().any(func(i: Item) -> bool: return i.base.is_gem() and i.gem.id == &"cleave" and i != cleave))
	_check("the gem vendor never runs out", gems.stock.has(cleave))
	var leech: Item = _stock_item(gems, func(i: Item) -> bool: return i.gem.id == &"life_leech")
	_check("supports cost Alteration Orbs", screen.buy(leech) and Shop.count(_inventory, &"orb_alteration") == 1)
	var brutality: Item = _stock_item(gems, func(i: Item) -> bool: return i.gem.id == &"brutality")
	_messages.clear()
	_check("stronger supports cost 2 and are refused when short", not screen.buy(brutality)
		and Shop.count(_inventory, &"orb_alteration") == 1 and _messages.any(func(t: String) -> bool: return t.begins_with("Not enough")))

	# Gear vendor.
	screen.open(gear, _player, _hud.inventory_screen)
	var levels_ok: bool = gear.stock.all(func(i: Item) -> bool: return i.ilvl == 3 and i.rarity <= Item.Rarity.MAGIC and not i.base.is_currency())
	_check("the gear vendor stocks 12 normal/magic items at item level 3", gear.stock.size() == 12 and levels_ok)
	var normal: Item = _stock_item(gear, func(i: Item) -> bool: return i.rarity == Item.Rarity.NORMAL)
	var trans_before: int = Shop.count(_inventory, &"orb_transmutation")
	_check("buying gear takes it out of stock", normal != null and screen.buy(normal) and not gear.stock.has(normal)
		and Shop.count(_inventory, &"orb_transmutation") == trans_before - 1 and _inventory.items().has(normal))

	# Selling: a magic item pays 2 shards; 5 shards become an orb.
	var magic: Item = ItemGenerator.new().generate(ItemDB.base(&"iron_hat"), 3, Item.Rarity.MAGIC)
	_hud.inventory_screen.held = magic
	var shards_before: int = Shop.count(_inventory, Shop.SHARD)
	_check("selling a magic item pays 2 Transmutation Shards", screen.sell_held()
		and Shop.count(_inventory, Shop.SHARD) == shards_before + 2 and _hud.inventory_screen.held == null)
	var orbs_before: int = Shop.count(_inventory, &"orb_transmutation")
	Shop.give(_inventory, Shop.SHARD, 3)
	_check("5 shards combine into an Orb of Transmutation", Shop.count(_inventory, Shop.SHARD) == 0
		and Shop.count(_inventory, &"orb_transmutation") == orbs_before + 1)
	var rare: Item = ItemGenerator.new().generate(ItemDB.base(&"plate_vest"), 3, Item.Rarity.RARE)
	rare.sockets = 2
	rare.socket_gem(0, ItemDB.make_gem(&"cleave"))
	_hud.inventory_screen.held = rare
	var gems_before: int = _inventory.items().filter(func(i: Item) -> bool: return i.base.is_gem()).size()
	var alts_before: int = Shop.count(_inventory, &"orb_alteration")
	screen.sell_held()
	_check("selling a rare pays an Alteration Orb and returns its gems",
		Shop.count(_inventory, &"orb_alteration") == alts_before + 1
		and _inventory.items().filter(func(i: Item) -> bool: return i.base.is_gem()).size() == gems_before + 1)

	_player.global_position = gear.global_position + Vector3(0, 0, 9)
	_player.reset_physics_interpolation()
	await _frames(3)
	_check("walking away closes the shop", not screen.visible)
	_hud.close_panels()


func _test_travel() -> void:
	var town_stock: Array[Item] = _vendor(Vendor.Kind.GEAR).stock.duplicate()
	var bag_size: int = _inventory.items().size()
	var exit: Node3D = _game.current_zone.get_node("Exits/ToShore") as Node3D
	_player.global_position = exit.global_position + Vector3(0, 0.05, 0)
	_player.reset_physics_interpolation()
	await _wait_for_zone("Shore")
	var info: AreaInfo = _zone_info()
	var entry: Vector3 = _game.current_zone.get_node("Entries/from_town").global_position
	_check("walking into the gate travels to the Shore", info.zone_name == "The Goblin Shore" and not info.is_town)
	_check("the player arrives at the Shore's town entrance", _player.global_position.distance_to(entry) < 0.3)
	_check("the Shore is area level 3", info.area_level == 3)
	await _frames(2)
	_check("goblins spawn on the Shore", get_nodes_in_group("enemies").size() == 10)
	_check("the town and its vendors are gone", get_nodes_in_group(Vendor.GROUP).is_empty())
	_check("the inventory carries over", _inventory.items().size() == bag_size)

	var melee: MeleeAttack = _player.get_node("Melee") as MeleeAttack
	(_player.get_node("PlayerCombat") as PlayerCombat).order_point(0, _player.global_position + Vector3(2, 0, 0))
	await _frames(3)
	_check("skills work outside town", melee.is_busy())

	# A dropped item stays in the zone it was dropped in.
	var junk: Item = ItemGenerator.new().generate(ItemDB.base(&"iron_hat"), 3, Item.Rarity.NORMAL)
	_hud.inventory_screen.held = junk
	_hud.inventory_screen.drop_held()
	var ground: Node = get_nodes_in_group(GroundItem.GROUP)[0]
	_check("dropped items belong to the current zone", _game.current_zone.is_ancestor_of(ground))

	# Death respawns at the zone entry.
	var health: Health = Health.of(_player)
	_player.global_position = entry + Vector3(8, 0, -6)
	_player.reset_physics_interpolation()
	health.take_damage(100000.0, &"chaos")
	var respawn: PlayerRespawn = _player.get_node("PlayerRespawn") as PlayerRespawn
	await _frames(int((respawn.respawn_delay + 1.0) * 60.0))
	_check("dying respawns you at the zone entrance", not health.is_dead() and _player.global_position.distance_to(entry) < 0.3)

	var back: Node3D = _game.current_zone.get_node("Exits/ToTown") as Node3D
	_player.global_position = back.global_position + Vector3(0, 0.05, 0)
	_player.reset_physics_interpolation()
	await _wait_for_zone("Town")
	var arrive: Vector3 = _game.current_zone.get_node("Entries/from_shore").global_position
	_check("the Shore gate leads back to town", _player.global_position.distance_to(arrive) < 0.3)
	_check("items left on the Shore are gone", get_nodes_in_group(GroundItem.GROUP).is_empty())
	var fresh: Array[Item] = _vendor(Vendor.Kind.GEAR).stock
	_check("the gear vendor has new stock after a trip", not fresh.any(func(i: Item) -> bool: return town_stock.has(i)))


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
