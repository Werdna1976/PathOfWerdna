extends SceneTree
## Crafting orbs and skill damage estimates. Run with:
##   godot --headless --path <project> -s res://tests/test_crafting.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"

var _failures: int = 0
var _gen := ItemGenerator.new(4242)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_orb_rules()
	_test_upgrade_orbs_keep_mods()
	_test_reroll_and_scour()
	_test_jeweller()
	await _test_screen_and_estimates()
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _item(rarity: Item.Rarity, base_id: StringName = &"plate_vest", ilvl: int = 40) -> Item:
	return _gen.generate(ItemDB.base(base_id), ilvl, rarity)


func _ids(item: Item) -> Array:
	return item.affixes.map(func(r: Dictionary) -> StringName: return r["id"])


func _test_orb_rules() -> void:
	var normal: Item = _item(Item.Rarity.NORMAL)
	var magic: Item = _item(Item.Rarity.MAGIC)
	var rare: Item = _item(Item.Rarity.RARE)
	_check("Transmutation only on normal items", Crafting.check(&"orb_transmutation", normal) == ""
		and Crafting.check(&"orb_transmutation", magic) != "")
	_check("Alteration and Regal only on magic items", Crafting.check(&"orb_alteration", magic) == ""
		and Crafting.check(&"orb_regal", rare) != "")
	_check("Chaos only on rare or legendary items", Crafting.check(&"orb_chaos", rare) == ""
		and Crafting.check(&"orb_chaos", magic) != "")
	_check("Ascension only on rare items", Crafting.check(&"orb_ascension", rare) == ""
		and Crafting.check(&"orb_ascension", _item(Item.Rarity.LEGENDARY)) != "")
	_check("orbs can't be used on currency or gems", Crafting.check(&"orb_chaos", _item(Item.Rarity.NORMAL, &"orb_chaos")) != ""
		and Crafting.check(&"orb_transmutation", ItemDB.make_gem(&"cleave")) != "")
	_check("Jeweller's needs an item that can have 2+ sockets", Crafting.check(&"orb_jeweller", _item(Item.Rarity.NORMAL, &"coral_ring")) != "")
	var before: Array = _ids(magic)
	var result: String = Crafting.apply(&"orb_chaos", magic, _gen)
	_check("a refused orb leaves the item unchanged", result != "" and _ids(magic) == before)


func _test_upgrade_orbs_keep_mods() -> void:
	var ok_transmute: bool = true
	var ok_augment: bool = true
	var ok_regal: bool = true
	var ok_ascend: bool = true
	for i: int in 200:
		var item: Item = _item(Item.Rarity.NORMAL)
		Crafting.apply(&"orb_transmutation", item, _gen)
		ok_transmute = ok_transmute and item.rarity == Item.Rarity.MAGIC and item.affixes.size() >= 1
		if item.affixes.size() == 1:
			var kept: Array = _ids(item)
			ok_augment = ok_augment and Crafting.apply(&"orb_augmentation", item, _gen) == "" \
				and item.affixes.size() == 2 and _ids(item).slice(0, 1) == kept
		var magic_ids: Array = _ids(item)
		Crafting.apply(&"orb_regal", item, _gen)
		ok_regal = ok_regal and item.rarity == Item.Rarity.RARE and item.affixes.size() == magic_ids.size() + 1 \
			and _ids(item).slice(0, magic_ids.size()) == magic_ids and item.rare_name != ""
		var rare_ids: Array = _ids(item)
		Crafting.apply(&"orb_ascension", item, _gen)
		ok_ascend = ok_ascend and item.rarity == Item.Rarity.LEGENDARY and item.affixes.size() > rare_ids.size() \
			and _ids(item).slice(0, rare_ids.size()) == rare_ids \
			and item.count_kind(AffixDef.Kind.PREFIX) <= 3 and item.count_kind(AffixDef.Kind.SUFFIX) <= 3
	_check("Transmutation makes a magic item with 1-2 mods", ok_transmute)
	_check("Augmentation adds a mod and keeps the existing one", ok_augment)
	_check("Regal makes it rare, keeps its mods and adds one", ok_regal)
	_check("Ascension makes it legendary, keeps its mods and adds more (max 3/3)", ok_ascend)
	var full: Item = _item(Item.Rarity.MAGIC)
	while full.affixes.size() < 2:
		_gen.add_random_affix(full)
	_check("Augmentation is refused when the magic item is full", Crafting.check(&"orb_augmentation", full) != "")


func _test_reroll_and_scour() -> void:
	var changed: int = 0
	var bad: bool = false
	for i: int in 100:
		var rare: Item = _item(Item.Rarity.RARE, &"rusted_hatchet", 20)
		var before: Array = _ids(rare)
		Crafting.apply(&"orb_chaos", rare, _gen)
		if _ids(rare) != before:
			changed += 1
		bad = bad or rare.rarity != Item.Rarity.RARE or rare.affixes.size() < 3
		for roll: Dictionary in rare.affixes:
			bad = bad or rare.affix_def(roll).tiers[roll["tier"]]["ilvl"] > 20
	_check("Chaos rerolls a rare into a new rare (changed %d/100)" % changed, changed > 90 and not bad)
	var ring: Item = _item(Item.Rarity.RARE, &"coral_ring")
	var implicit: int = ring.implicit_value
	Crafting.apply(&"orb_scouring", ring, _gen)
	_check("Scouring clears mods but keeps the implicit", ring.rarity == Item.Rarity.NORMAL and ring.affixes.is_empty()
		and ring.implicit_value == implicit and ring.display_name() == "Coral Ring")


func _test_jeweller() -> void:
	var vest: Item = _item(Item.Rarity.NORMAL)
	vest.sockets = 4
	for i: int in 4:
		vest.socket_gem(i, ItemDB.make_gem(&"cleave"))
	var ejected: Array[Item] = []
	Crafting.apply(&"orb_jeweller", vest, _gen, ejected)
	print("  info: jeweller 4 -> %d sockets, %d gems ejected" % [vest.sockets, ejected.size()])
	_check("Jeweller's always changes the socket count", vest.sockets != 4 and vest.sockets >= 1)
	_check("gems in removed sockets are ejected", ejected.size() == 4 - vest.sockets and vest.gems().size() == vest.sockets)


func _test_screen_and_estimates() -> void:
	var arena: Node3D = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	arena.get_node("GoblinSpawner").free()
	await process_frame
	await process_frame
	var player: Node = arena.get_node("Player")
	var screen: InventoryScreen = (arena.get_node("Hud") as Hud).inventory_screen
	var inventory: Inventory = player.get_node("Inventory") as Inventory
	var equipment: Equipment = player.get_node("Equipment") as Equipment
	var stats: CharacterStats = player.get_node("CharacterStats") as CharacterStats

	var orbs: Item = _item(Item.Rarity.NORMAL, &"orb_transmutation")
	orbs.stack = 3
	inventory.try_add(orbs)
	var ring: Item = _item(Item.Rarity.NORMAL, &"coral_ring")
	inventory.try_add(ring)
	var messages: Array[String] = []
	screen.message.connect(func(t: String) -> void: messages.append(t))

	screen.begin_apply(orbs)
	_check("right-clicking an orb starts crafting", screen.applying == orbs)
	_check("applying an orb upgrades the target", screen.apply_to(ring) and ring.rarity == Item.Rarity.MAGIC)
	_check("one orb is spent and crafting stops without Shift", orbs.stack == 2 and screen.applying == null)
	screen.begin_apply(orbs)
	_check("a refused orb shows why and isn't spent", not screen.apply_to(ring) and orbs.stack == 2 and not messages.is_empty())

	var boots: Item = _item(Item.Rarity.NORMAL, &"iron_greaves")
	equipment.equip(boots, &"boots")
	screen.begin_apply(orbs)
	screen.apply_to(boots, true)
	_check("Shift keeps the orb on the cursor", screen.applying == orbs and orbs.stack == 1)
	screen.apply_to(_item(Item.Rarity.NORMAL, &"iron_hat"))
	_check("the last orb in a stack leaves the bag", not inventory.items().has(orbs) and screen.applying == null)
	print("  info: crafted boots: %s" % [boots.affix_lines()])
	var granted: Dictionary = boots.global_stats()
	_check("crafting equipped gear refreshes stats", not granted.is_empty() and granted.keys().all(
		func(k: StringName) -> bool: return stats.gear.get(k, 0) == granted[k]))

	# Damage estimates.
	var melee: MeleeAttack = player.get_node("Melee") as MeleeAttack
	melee.damage_min = 10.0
	melee.damage_max = 20.0
	melee.fire_min = 0.0
	melee.fire_max = 0.0
	melee.crit_chance = 10.0
	melee.crit_multiplier = 150.0
	melee.speed_multiplier = 1.0
	var heavy: SkillGem = ItemDB.gem(&"heavy_strike") as SkillGem
	var e: Dictionary = melee.estimate(SkillInstance.new(heavy))
	var expected_hit: float = 15.0 * 1.4 * (1.0 + 0.1 * 0.5)
	var expected_dps: float = expected_hit / (heavy.windup + heavy.recovery)
	print("  info: Heavy Strike estimate: %d-%d per hit, %.2f uses/s, %.1f DPS" % [e["hit_min"], e["hit_max"], e["uses_per_second"], e["dps"]])
	_check("hit range = weapon range x 140%", is_equal_approx(e["hit_min"], 14.0) and is_equal_approx(e["hit_max"], 28.0))
	_check("DPS = average hit x crit factor x uses per second", is_equal_approx(e["dps"], expected_dps))
	var faster: Dictionary = melee.estimate(SkillInstance.new(heavy, [ItemDB.gem(&"faster_attacks")]))
	_check("Faster Attacks raises DPS by 30%", is_equal_approx(faster["dps"], e["dps"] * 1.3))
	var leap: SkillGem = ItemDB.gem(&"leap_slam") as SkillGem
	var leap_e: Dictionary = melee.estimate(SkillInstance.new(leap))
	_check("cooldowns cap uses per second (Leap Slam 1.5 s)", is_equal_approx(leap_e["uses_per_second"], 1.0 / 1.5))
	var tooltip := ItemTooltip.new()
	root.add_child(tooltip)
	tooltip.show_skill(SkillInstance.new(heavy, [ItemDB.gem(&"life_leech")]), e)
	_check("skill tooltips build", tooltip.visible)
	var gem_estimate: Dictionary = screen.skill_estimate_for(equipment.get_item(&"main_hand").socketed_gem(0))
	_check("socketed gems in gear get a damage estimate", not gem_estimate.is_empty() and gem_estimate["estimate"]["dps"] > 0.0)
	tooltip.free()
	arena.queue_free()
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
