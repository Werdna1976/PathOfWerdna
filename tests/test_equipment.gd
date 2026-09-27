extends SceneTree
## Milestone 4b headless test: equipment rules, stat calculation, defences
## and the inventory screen's actions. Run with:
##   godot --headless --path <project> -s res://tests/test_equipment.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const OPEN_SPOT: Vector3 = Vector3(0.0, 0.0, 12.0)

var _failures: int = 0
var _arena: Node3D
var _player: CharacterBody3D
var _equipment: Equipment
var _inventory: Inventory
var _stats: CharacterStats
var _health: Health
var _defenses: Defenses
var _melee: MeleeAttack
var _gen := ItemGenerator.new(99)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_arena = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(_arena)
	_arena.get_node("GoblinSpawner").free()
	var region: RuntimeNavBaker = _arena.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	_player = _arena.get_node("Player") as CharacterBody3D
	_player.global_position = OPEN_SPOT
	_player.reset_physics_interpolation()
	_equipment = _player.get_node("Equipment") as Equipment
	_inventory = _player.get_node("Inventory") as Inventory
	_stats = _player.get_node("CharacterStats") as CharacterStats
	_health = Health.of(_player)
	_defenses = _player.get_node("Defenses") as Defenses
	_melee = _player.get_node("Melee") as MeleeAttack

	_test_starting_character()
	_test_slot_rules()
	_test_attribute_and_life_stats()
	_test_weapon_stats()
	_test_armour()
	await _test_energy_shield()
	_test_block_and_evasion()
	_test_resistances()
	_test_utility_stats()
	await _test_inventory_screen()

	_arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## Builds an item with exact affix values: mods = [[affix_id, value], ...].
func _make(base_id: StringName, rarity: Item.Rarity = Item.Rarity.NORMAL, mods: Array = []) -> Item:
	var item: Item = _gen.generate(ItemDB.base(base_id), 1, Item.Rarity.NORMAL)
	item.rarity = rarity
	item.affixes.clear()
	for mod: Array in mods:
		item.affixes.append({"id": StringName(mod[0]), "tier": 0, "value": int(mod[1])})
	if not item.base.implicit.is_empty():
		item.implicit_value = int(item.base.implicit["max"])
	return item


func _clear_gear() -> void:
	for slot: StringName in Equipment.SLOTS:
		_equipment.unequip(slot)
	_health.restore_full()


func _test_starting_character() -> void:
	var weapon: Item = _equipment.get_item(&"main_hand")
	_check("Werdna starts with a Rusted Hatchet", weapon != null and weapon.base.id == &"rusted_hatchet")
	print("  info: start life %.0f, mana %.0f, damage %d-%d, aps %.2f" % [_stats.stat(&"max_life"),
		_stats.stat(&"max_mana"), _stats.stat(&"phys_min"), _stats.stat(&"phys_max"), _stats.stat(&"attacks_per_second")])
	_check("base life 100 and mana 50 (90 + 20 STR / 2, 43 + 14 INT / 2)",
		_stats.stat(&"max_life") == 100.0 and _stats.stat(&"max_mana") == 50.0 and _health.max_health == 100.0)
	_check("melee damage comes from the weapon", _melee.damage_min == _stats.stat(&"phys_min") and _melee.damage_max > _melee.damage_min)


func _test_slot_rules() -> void:
	_clear_gear()
	var ring: Item = _make(&"coral_ring")
	var orb: Item = _make(&"orb_chaos")
	_check("rings can't go in the helm slot", not _equipment.can_equip(ring, &"helm"))
	_check("rings fit either ring slot", _equipment.can_equip(ring, &"ring_left") and _equipment.can_equip(ring, &"ring_right"))
	_check("currency can't be equipped", not Equipment.SLOTS.any(func(s: StringName) -> bool: return _equipment.can_equip(orb, s)))
	_equipment.equip(ring, &"ring_left")
	_check("quick-equip picks the empty ring slot", _equipment.best_slot(_make(&"iron_ring")) == &"ring_right")

	var hatchet: Item = _make(&"rusted_hatchet")
	var shield: Item = _make(&"splintered_tower_shield")
	var axe2h: Item = _make(&"stone_axe")
	_equipment.equip(hatchet, &"main_hand")
	_equipment.equip(shield, &"off_hand")
	var displaced: Array[Item] = _equipment.equip(axe2h, &"main_hand")
	_check("a two-hander displaces both the one-hander and the shield",
		displaced.has(hatchet) and displaced.has(shield) and _equipment.get_item(&"off_hand") == null)
	displaced = _equipment.equip(shield, &"off_hand")
	_check("equipping a shield displaces a two-hander", displaced == [axe2h] and _equipment.get_item(&"main_hand") == null)
	_check("one-handed weapons can't go in the off hand yet", not _equipment.can_equip(hatchet, &"off_hand"))


func _test_attribute_and_life_stats() -> void:
	_clear_gear()
	_equipment.equip(_make(&"coral_ring", Item.Rarity.MAGIC, [["max_life", 15]]), &"ring_left")  # +30 implicit +15
	_check("ring implicit and affix add life (100 + 30 + 15)", _stats.stat(&"max_life") == 145.0 and _health.max_health == 145.0)
	_equipment.equip(_make(&"amber_amulet"), &"amulet")  # +30 STR
	_check("STR from gear adds life at 0.5 per point", _stats.stat(&"strength") == 50.0 and _stats.stat(&"max_life") == 160.0)
	_equipment.equip(_make(&"lapis_amulet", Item.Rarity.MAGIC, [["max_mana", 20]]), &"amulet")  # +30 INT, +20 mana
	_check("INT and flat mana add mana (43 + 44 / 2 + 20)", _stats.stat(&"max_mana") == 85.0)
	_health.restore_full()
	_health.take_damage(45.0)
	var before: float = _health.current / _health.max_health
	_equipment.unequip(&"ring_left")
	_check("losing max life keeps the same life percentage",
		absf(_health.current / _health.max_health - before) < 0.02 and _health.max_health == 100.0)


func _test_weapon_stats() -> void:
	_clear_gear()
	var sword: Item = _make(&"rusted_sword", Item.Rarity.RARE, [["local_phys_percent", 50], ["local_added_phys", 2], ["attack_speed", 10]])
	_equipment.equip(sword, &"main_hand")
	# (5 + 2) * 1.5 = 10.5 -> 11 ; (9 + 4) * 1.5 = 19.5 -> 20 ; then STR 20 = +4%
	_check("local phys mods raise the weapon's damage (11-20)", sword.weapon_damage() == Vector2(11, 20))
	_check("STR adds 0.2% melee physical damage per point", _stats.stat(&"phys_min") == roundf(11 * 1.04) and _stats.stat(&"phys_max") == roundf(20 * 1.04))
	_check("attack speed = weapon APS x increases (1.6 x 1.1)", is_equal_approx(_stats.stat(&"attacks_per_second"), 1.76))
	_check("faster attacks shorten swings", is_equal_approx(_melee.speed_multiplier, 1.76 / 1.5))
	_equipment.equip(_make(&"iron_ring", Item.Rarity.MAGIC, [["added_fire_attacks", 3]]), &"ring_left")
	_check("added fire to attacks joins melee damage", _stats.stat(&"fire_min") == 3.0 and _stats.stat(&"fire_max") == 6.0
		and _melee.fire_max == 6.0 and _melee.damage_max == _stats.stat(&"phys_max"))
	_equipment.unequip(&"main_hand")
	_equipment.unequip(&"ring_left")  # its implicit adds physical damage to attacks
	_check("unarmed damage is 2-6", _stats.stat(&"phys_min") == 2.0 and _stats.stat(&"phys_max") == 6.0)
	_equipment.equip(_make(&"stone_axe"), &"main_hand")
	_check("a slow two-hander slows swings", _melee.speed_multiplier < 1.0)


func _test_armour() -> void:
	_clear_gear()
	var vest: Item = _make(&"plate_vest", Item.Rarity.MAGIC, [["flat_armour", 10], ["increased_defences", 50]])
	_equipment.equip(vest, &"chest")
	_check("body armour = (20 + 10) x 1.5 = 45", _stats.stat(&"armour") == 45.0 and _defenses.armour == 45.0)
	var reduction: float = _defenses.armour_reduction(10.0)
	_check("armour reduces a 10-damage hit by 45 / (45 + 50) = 47%", is_equal_approx(reduction, 45.0 / 95.0))
	_check("big hits get through armour better", _defenses.armour_reduction(100.0) < reduction)
	_health.restore_full()
	_health.take_damage(10.0)
	_check("a hit loses its armour share", absf((_health.max_health - _health.current) - 10.0 * (1.0 - reduction)) < 0.01)


func _test_energy_shield() -> void:
	_clear_gear()
	_equipment.equip(_make(&"simple_robe", Item.Rarity.MAGIC, [["flat_energy_shield", 8]]), &"chest")
	var es: float = _stats.stat(&"energy_shield")
	_check("ES = (12 + 8) x (1 + 14 INT x 0.2 percent) = 21", es == 21.0 and _defenses.max_energy_shield == 21.0)
	_health.restore_full()
	_health.take_damage(15.0)
	_check("energy shield absorbs damage before life", _health.current == _health.max_health and _defenses.energy_shield == 6.0)
	_health.take_damage(10.0)
	_check("damage beyond ES reaches life", _defenses.energy_shield == 0.0 and _health.current == _health.max_health - 4.0)
	for i: int in int((Defenses.ES_RECHARGE_DELAY + 1.0 / Defenses.ES_RECHARGE_RATE + 0.3) * 60.0):
		await physics_frame
	_check("ES recharges fully after 2 s without damage", _defenses.energy_shield == _defenses.max_energy_shield)


func _test_block_and_evasion() -> void:
	_clear_gear()
	_equipment.equip(_make(&"splintered_tower_shield"), &"off_hand")
	var avoided: Array[int] = [0]
	var count := func(_how: String) -> void: avoided[0] += 1
	_defenses.avoided.connect(count)
	for i: int in 2000:
		_health.restore_full()
		_health.take_damage(1.0)
	var block_rate: float = avoided[0] / 2000.0
	print("  info: blocked %.1f%% of hits with a 24%% shield" % (block_rate * 100.0))
	_check("shields block about their block chance", absf(block_rate - 0.24) < 0.04)

	_clear_gear()
	_equipment.equip(_make(&"shabby_jerkin", Item.Rarity.MAGIC, [["flat_evasion", 200]]), &"chest")
	avoided[0] = 0
	var expected: float = _defenses.evade_chance()
	for i: int in 2000:
		_health.restore_full()
		_health.take_damage(1.0)
	var evade_rate: float = avoided[0] / 2000.0
	print("  info: evasion %.0f -> evade chance %.1f%%, observed %.1f%%" % [_defenses.evasion, expected * 100.0, evade_rate * 100.0])
	_check("evasion dodges physical hits at the expected rate", expected > 0.3 and absf(evade_rate - expected) < 0.04)
	avoided[0] = 0
	for i: int in 500:
		_health.restore_full()
		_health.take_damage(1.0, &"fire")
	_check("evasion doesn't dodge elemental damage", avoided[0] == 0)
	_defenses.avoided.disconnect(count)


func _test_resistances() -> void:
	_clear_gear()
	_equipment.equip(_make(&"ruby_ring"), &"ring_left")  # +30% fire
	_equipment.equip(_make(&"ruby_ring", Item.Rarity.MAGIC, [["fire_resistance", 60]]), &"ring_right")  # +90%
	_check("fire resistance adds up past the cap (120)", _stats.stat(&"fire_resistance") == 120.0)
	_health.restore_full()
	_health.take_damage(100.0, &"fire")
	_check("resistance is capped at 75% when taking damage", _health.max_health - _health.current == 25.0)
	_health.restore_full()
	_health.take_damage(20.0, &"cold")
	_check("unresisted cold damage lands in full", _health.max_health - _health.current == 20.0)


func _test_utility_stats() -> void:
	_clear_gear()
	_equipment.equip(_make(&"iron_greaves", Item.Rarity.MAGIC, [["movement_speed", 20]]), &"boots")
	_check("boots movement speed raises move speed (5 x 1.2)", is_equal_approx((_player.get_node("NavMovement") as NavMovement).move_speed, 6.0))
	var charm: Item = _make(&"bone_charm", Item.Rarity.RARE,
		[["charm_culling", 10], ["charm_potion_charges", 2], ["charm_mana_on_kill", 3], ["charm_quantity", 5]])
	_equipment.equip(charm, &"charm")
	_check("charm culling strike reaches the attack", _melee.culling_percent == 10.0)
	_check("charm potion charges reach the potion belt", (_player.get_node("PotionBelt") as PotionBelt).bonus_charges_per_kill == 2.0)
	_check("charm quantity shows on the character", _stats.stat(&"item_quantity") == 5.0)
	var mana: Mana = Mana.of(_player)
	mana.current = 10.0
	get_nodes_in_group(PotionBelt.KILL_LISTENERS)  # warm up
	call_group(PotionBelt.KILL_LISTENERS, "on_enemy_killed", null)
	_check("mana on kill restores mana", mana.current == 13.0)
	_equipment.equip(_make(&"swift_charm", Item.Rarity.MAGIC, [["charm_cooldown", 25]]), &"charm")
	_check("cooldown recovery speeds the skill bar", is_equal_approx((_player.get_node("SkillBar") as SkillBar).cooldown_rate, 1.25))


func _test_inventory_screen() -> void:
	_clear_gear()
	var hud: Hud = _arena.get_node("Hud") as Hud
	await process_frame
	var screen: InventoryScreen = hud.inventory_screen
	_check("the HUD builds the inventory screen", screen != null)
	screen.toggle()
	_check("I opens the inventory", screen.visible)

	_inventory.entries.clear()  # start from an empty bag (no starting gems)
	var vest: Item = _make(&"plate_vest")
	var ring: Item = _make(&"coral_ring")
	_inventory.try_add(vest)
	_inventory.try_add(ring)
	screen.click_grid(Vector2i(0, 1))  # inside the 2x3 vest at (0,0)
	_check("clicking an item picks it up", screen.held == vest and not _inventory.items().has(vest))
	screen.click_slot(&"helm")
	_check("a body armour can't be dropped into the helm slot", screen.held == vest and _equipment.get_item(&"helm") == null)
	screen.click_slot(&"chest")
	_check("clicking the chest slot equips it", _equipment.get_item(&"chest") == vest and screen.held == null)

	var better: Item = _make(&"scale_vest")
	_inventory.try_add(better)
	var pos: Vector2i = _inventory.position_of(better)
	screen.click_grid(pos)
	screen.click_slot(&"chest")
	_check("equipping over gear swaps the old piece onto the cursor", _equipment.get_item(&"chest") == better and screen.held == vest)
	screen.click_grid(Vector2i(6, 0))
	_check("placing the held item in the grid", screen.held == null and _inventory.position_of(vest) == Vector2i(6, 0))

	# Swap: hold the ring and click on the vest.
	screen.click_grid(_inventory.position_of(ring))
	screen.click_grid(Vector2i(6, 0))
	_check("placing onto one item swaps them", screen.held == vest and _inventory.position_of(ring) == Vector2i(6, 0))
	screen.click_grid(Vector2i(0, 0))

	var ring_pos: Vector2i = _inventory.position_of(ring)
	screen.quick_equip(ring_pos)
	_check("right-click equips a ring", _equipment.get_item(&"ring_left") == ring)
	screen.quick_unequip(&"ring_left")
	_check("right-click on gear returns it to the bag", _equipment.get_item(&"ring_left") == null and _inventory.items().has(ring))
	var life_before: float = _stats.stat(&"max_life")
	screen.quick_equip(_inventory.position_of(ring))
	_check("equipping from the screen updates stats", _stats.stat(&"max_life") == life_before + 30.0)

	screen.click_grid(_inventory.position_of(vest))
	screen.drop_held()
	var dropped: bool = get_nodes_in_group(GroundItem.GROUP).any(func(n: Node) -> bool: return (n as GroundItem).item == vest)
	_check("clicking the world while holding drops the item", dropped and screen.held == null)

	screen.click_grid(_inventory.position_of(better) if _inventory.items().has(better) else Vector2i(0, 0))
	screen.close()
	_check("closing returns a held item to the bag", not screen.visible and screen.held == null)


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
