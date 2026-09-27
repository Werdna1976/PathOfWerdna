extends SceneTree
## Milestone 4c headless test: gem items, sockets, supports and the skill bar
## built from socketed gems. Run with:
##   godot --headless --path <project> -s res://tests/test_gems.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const GOBLIN_PATH: String = "res://scenes/enemies/goblin.tscn"
const OPEN_SPOT: Vector3 = Vector3(0.0, 0.0, 12.0)

var _failures: int = 0
var _arena: Node3D
var _player: CharacterBody3D
var _equipment: Equipment
var _inventory: Inventory
var _skills: SkillBar
var _melee: MeleeAttack
var _screen: InventoryScreen


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
	_skills = _player.get_node("SkillBar") as SkillBar
	_melee = _player.get_node("Melee") as MeleeAttack
	await process_frame
	_screen = (_arena.get_node("Hud") as Hud).inventory_screen

	_test_starting_kit()
	_test_socketing_and_supports()
	_test_skill_bar_follows_gems()
	await _test_support_damage()
	await _test_splash_and_leech()
	_test_default_attack()
	_test_gem_items()

	_arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _bag_gem(id: StringName) -> Item:
	for item: Item in _inventory.items():
		if item.base.is_gem() and item.gem.id == id:
			return item
	return null


func _slot_names() -> Array[String]:
	var names: Array[String] = []
	for slot: int in SkillBar.SLOT_COUNT:
		var s: SkillInstance = _skills.gem_in(slot)
		names.append(s.display_name if s != null else "-")
	return names


func _test_starting_kit() -> void:
	var weapon: Item = _equipment.get_item(&"main_hand")
	var chest: Item = _equipment.get_item(&"chest")
	_check("the hatchet holds Heavy Strike and Cleave", weapon.sockets == 2
		and weapon.socketed_gem(0).gem.id == &"heavy_strike" and weapon.socketed_gem(1).gem.id == &"cleave")
	_check("the vest holds Leap Slam with two free sockets", chest.sockets == 3
		and chest.socketed_gem(0).gem.id == &"leap_slam" and chest.gems().size() == 1)
	var bag_supports: int = _inventory.items().filter(func(i: Item) -> bool: return i.base.is_gem() and i.gem is SupportGem).size()
	_check("all five supports start in the bag", bag_supports == 5)
	print("  info: skill bar = %s" % [_slot_names()])
	_check("socketed actives fill the skill bar in gear order", _slot_names().slice(0, 3) == ["Heavy Strike", "Cleave", "Leap Slam"])


func _test_socketing_and_supports() -> void:
	var chest: Item = _equipment.get_item(&"chest")
	var leap_before: SkillInstance = _skills.gem_in(2)
	var faster: Item = _bag_gem(&"faster_attacks")
	_screen.held = faster
	_inventory.remove(faster)
	_screen.click_socket(chest, 1)
	_check("clicking a socket with a gem sockets it", chest.socketed_gem(1) == faster and _screen.held == null)
	var leap: SkillInstance = _skills.gem_in(2)
	print("  info: Leap Slam with Faster Attacks: cost %d, wind-up %.3f s (was %d, %.3f s)" \
		% [leap.mana_cost, leap.windup, leap_before.mana_cost, leap_before.windup])
	_check("the skill keeps its slot when a support is added", leap.gem_item == leap_before.gem_item)
	_check("Faster Attacks makes Leap Slam 30% faster", is_equal_approx(leap.windup, leap_before.windup / 1.3))
	_check("supports multiply mana cost (10 x 1.2 = 12)", leap.mana_cost == 12.0)

	var splash: Item = _bag_gem(&"melee_splash")
	_inventory.remove(splash)
	_screen.held = splash
	_screen.click_socket(chest, 2)
	_check("Melee Splash doesn't support Leap Slam (not a strike)", not _skills.gem_in(2).supports.any(
		func(s: SupportGem) -> bool: return s.id == &"melee_splash"))

	var brutality: Item = _bag_gem(&"brutality")
	_inventory.remove(brutality)
	_screen.held = brutality
	_screen.click_socket(chest, 1)
	_check("socketing onto a filled socket swaps the gems", chest.socketed_gem(1) == brutality and _screen.held == faster)
	_inventory.try_add(_screen.held)
	_screen.held = null
	_screen.click_socket(chest, 1)
	_check("clicking a filled socket takes the gem out", _screen.held == brutality and chest.socketed_gem(1) == null)
	_inventory.try_add(_screen.held)
	_screen.held = null


func _test_skill_bar_follows_gems() -> void:
	var chest: Item = _equipment.get_item(&"chest")
	_screen.click_socket(chest, 0)
	var leap_gem: Item = _screen.held
	_check("removing Leap Slam empties its slot", _skills.gem_in(2) == null and _skills.available_skills().size() == 2)
	_screen.click_socket(chest, 0)
	_check("socketing it back fills the first empty slot", _skills.gem_in(2) != null and _skills.gem_in(2).gem_item == leap_gem)
	_skills.set_slot(2, null)
	_skills.rebuild()
	_check("a slot the player cleared stays clear after a rebuild", _skills.gem_in(2) == null)
	_skills.cycle_slot(2)
	_check("cycling a slot offers the socketed skills", _skills.gem_in(2) != null)

	# Unequipping the weapon removes its skills; re-equipping brings them back.
	var weapon: Item = _equipment.unequip(&"main_hand")
	_check("unequipping the weapon removes Heavy Strike and Cleave", not _slot_names().has("Cleave"))
	_equipment.equip(weapon, &"main_hand")
	_check("re-equipping restores them", _slot_names().has("Heavy Strike") and _slot_names().has("Cleave"))


func _test_support_damage() -> void:
	var heavy: SkillGem = ItemDB.gem(&"heavy_strike") as SkillGem
	var added_fire: SupportGem = ItemDB.gem(&"added_fire") as SupportGem
	var brutality: SupportGem = ItemDB.gem(&"brutality") as SupportGem
	# Fixed rolls: 10 physical, 4 fire, no crits.
	_melee.damage_min = 10.0
	_melee.damage_max = 10.0
	_melee.fire_min = 4.0
	_melee.fire_max = 4.0
	_melee.crit_chance = 0.0
	var plain: float = await _hit_goblin(SkillInstance.new(heavy))
	var fire: float = await _hit_goblin(SkillInstance.new(heavy, [added_fire]))
	var brutal: float = await _hit_goblin(SkillInstance.new(heavy, [brutality]))
	print("  info: Heavy Strike hits: plain %.0f, Added Fire %.0f, Brutality %.0f" % [plain, fire, brutal])
	_check("plain Heavy Strike: (10 + 4) x 1.4 = 20", plain == 20.0)
	_check("Added Fire: (10 + 4 + 25% of 10) x 1.4 = 23", fire == 23.0)
	_check("Brutality: 10 x 1.4 more x 1.4, no fire = 20", brutal == 20.0)


func _test_splash_and_leech() -> void:
	var heavy: SkillGem = ItemDB.gem(&"heavy_strike") as SkillGem
	var splash: SupportGem = ItemDB.gem(&"melee_splash") as SupportGem
	var leech: SupportGem = ItemDB.gem(&"life_leech") as SupportGem
	var target: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(0, 0, -1.3))
	var neighbour: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(1.2, 0, -2.4))
	var far: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(0, 0, -6.0))
	await _swing(SkillInstance.new(heavy, [splash]))
	var main_damage: float = _lost(target)
	var splash_damage: float = _lost(neighbour)
	print("  info: splash: target %.0f, neighbour %.0f, far %.0f" % [main_damage, splash_damage, _lost(far)])
	_check("Melee Splash hits a neighbour of the target", splash_damage > 0.0)
	_check("splash hits deal 60% damage", absf(splash_damage - main_damage * 0.6) <= 1.0)
	_check("splash doesn't reach enemies far from the target", _lost(far) == 0.0)
	for g: Node in [target, neighbour, far]:
		g.free()

	var health: Health = Health.of(_player)
	health.restore_full()
	health.current = 50.0
	var victim: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(0, 0, -1.3))
	await _swing(SkillInstance.new(heavy, [leech]))
	var dealt: float = _lost(victim)
	print("  info: leech: dealt %.0f, healed %.2f" % [dealt, health.current - 50.0])
	_check("Life Leech heals 5% of damage dealt", absf((health.current - 50.0) - dealt * 0.05) < 0.1)
	victim.free()


func _test_default_attack() -> void:
	var weapon: Item = _equipment.unequip(&"main_hand")
	var rmb: SkillInstance = _skills.gem_in(0)
	_check("with no skill on right click, Default Attack is used", rmb != null and rmb.id == &"default_attack")
	_equipment.equip(weapon, &"main_hand")


func _test_gem_items() -> void:
	var gem: Item = ItemDB.make_gem(&"cleave")
	_check("gems are 1x1 teal items", gem.base.size == Vector2i.ONE and gem.color() == Item.GEM_COLOR)
	_check("gems can't be equipped as gear", not Equipment.SLOTS.any(func(s: StringName) -> bool: return _equipment.can_equip(gem, s)))
	var tooltip := ItemTooltip.new()
	root.add_child(tooltip)
	tooltip.show_item(gem)
	tooltip.show_item(_bag_gem(&"life_leech"))
	tooltip.show_item(_equipment.get_item(&"main_hand"))
	_check("gem and socketed-item tooltips build", tooltip.visible)
	tooltip.free()


func _hit_goblin(skill: SkillInstance) -> float:
	var goblin: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(0, 0, -1.3))
	await _swing(skill)
	var lost: float = _lost(goblin)
	goblin.free()
	return lost


## Swings forward once, waiting for any earlier swing to finish first and for this one to end.
func _swing(skill: SkillInstance) -> void:
	while _melee.is_busy():
		await physics_frame
	_player.rotation.y = 0.0
	_check_started(_melee.swing(Vector3.FORWARD, skill))
	while _melee.is_busy():
		await physics_frame


func _check_started(started: bool) -> void:
	if not started:
		_check("swing started", false)


func _lost(goblin: Node) -> float:
	var h: Health = Health.of(goblin)
	return h.max_health - h.current


func _spawn_goblin(at: Vector3) -> CharacterBody3D:
	var goblin: CharacterBody3D = (load(GOBLIN_PATH) as PackedScene).instantiate() as CharacterBody3D
	_arena.add_child(goblin)
	goblin.global_position = at
	goblin.reset_physics_interpolation()
	(goblin.get_node("EnemyAI") as EnemyAI).set_physics_process(false)
	Health.of(goblin).max_health = 500.0
	Health.of(goblin).current = 500.0
	await physics_frame
	return goblin


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
