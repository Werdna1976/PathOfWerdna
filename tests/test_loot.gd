extends SceneTree
## Milestone 4a headless test: item data, affix rolling rules, inventory grid,
## drops and pickup. Run with:
##   godot --headless --path <project> -s res://tests/test_loot.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const GOBLIN_PATH: String = "res://scenes/enemies/goblin.tscn"
const OPEN_SPOT: Vector3 = Vector3(0.0, 0.0, 12.0)
const SAMPLES: int = 3000

var _failures: int = 0
var _gen: ItemGenerator


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_gen = ItemGenerator.new(12345)
	_test_data()
	_test_rarity_rules()
	_test_weapon_identity()
	_test_charms()
	_test_ilvl_gating()
	_test_legendary_bias()
	_test_sockets()
	_test_names()
	_test_inventory()
	await _test_drop_and_pickup()
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	var bases: Array[ItemBase] = ItemDB.bases()
	var affixes: Array[AffixDef] = ItemDB.affixes()
	print("  info: %d bases, %d affixes" % [bases.size(), affixes.size()])
	_check("item data loads", bases.size() >= 40 and affixes.size() >= 30)
	var slots: Dictionary = {}
	for b: ItemBase in bases:
		slots[b.slot] = true
	_check("every gear slot has bases", [&"main_hand", &"off_hand", &"chest", &"helm", &"gloves",
		&"boots", &"ring", &"amulet", &"charm", &"currency"].all(func(s: StringName) -> bool: return slots.has(s)))
	var bad_tiers: Array[String] = []
	for a: AffixDef in affixes:
		for i: int in range(1, a.tiers.size()):
			if a.tiers[i]["ilvl"] < a.tiers[i - 1]["ilvl"] or a.tiers[i]["min"] < a.tiers[i - 1]["min"]:
				bad_tiers.append(String(a.id))
	_check("affix tiers are ordered worst to best %s" % [bad_tiers], bad_tiers.is_empty())
	var missing: Array[String] = []
	for b: ItemBase in bases:
		if b.is_currency():
			continue
		var p: bool = false
		var s: bool = false
		for a: AffixDef in affixes:
			if a.weight_multiplier(b) > 0.0:
				p = p or a.kind == AffixDef.Kind.PREFIX
				s = s or a.kind == AffixDef.Kind.SUFFIX
		if not (p and s):
			missing.append(String(b.id))
	_check("every base can roll both prefixes and suffixes %s" % [missing], missing.is_empty())

	# Base ladders: each weapon class and each armour type per slot has several
	# tiers spread over drop levels, and base stats grow with drop level.
	var ladders: Dictionary = {}
	for b: ItemBase in bases:
		if b.is_currency() or b.slot in [&"ring", &"amulet", &"charm"]:
			continue
		var key: String = b.type_name() if b.is_weapon() else "%s %s" % [b.slot, _defence_kind(b)]
		if not ladders.has(key):
			ladders[key] = []
		ladders[key].append(b)
	var short: Array[String] = []
	var not_scaling: Array[String] = []
	for key: String in ladders:
		var ladder: Array = ladders[key]
		ladder.sort_custom(func(a: ItemBase, b: ItemBase) -> bool: return a.drop_level < b.drop_level)
		var top: ItemBase = ladder[-1]
		if ladder.size() < 3 or top.drop_level < 50:
			short.append(key)
		if _base_power(top) <= _base_power(ladder[0]):
			not_scaling.append(key)
	print("  info: %d base ladders" % ladders.size())
	_check("every weapon class and armour type has 3+ bases up to level 50+ %s" % [short], short.is_empty())
	_check("base stats grow with drop level %s" % [not_scaling], not_scaling.is_empty())
	var low_top: Array[String] = []
	for a: AffixDef in affixes:
		if a.tiers[-1]["ilvl"] < 75 or a.tiers[-1]["ilvl"] > 84:
			low_top.append(String(a.id))
	_check("every affix's top tier needs item level 75-84 %s" % [low_top], low_top.is_empty())

	# The single-defence % mods only scale their own defence.
	var hybrid := Item.new()
	hybrid.base = ItemDB.base(&"scale_vest")
	hybrid.affixes = [{"id": &"local_armour_percent", "tier": 0, "value": 50}]
	_check("% increased Armour is local and only scales armour",
		hybrid.local_defence(&"armour") == 18 and hybrid.local_defence(&"evasion") == 12 and hybrid.global_stats().is_empty())


func _defence_kind(b: ItemBase) -> String:
	var kinds: Array[String] = []
	for tag: String in ["str_armour", "dex_armour", "int_armour"]:
		if b.has_tag(StringName(tag)):
			kinds.append(tag)
	return "/".join(kinds)


func _base_power(b: ItemBase) -> float:
	if b.is_weapon():
		return (b.stats["phys_min"] + b.stats["phys_max"]) * b.stats["aps"]
	return b.stats.get("armour", 0) + b.stats.get("evasion", 0) + b.stats.get("energy_shield", 0) * 2.0


func _test_rarity_rules() -> void:
	var problems: Dictionary = {}
	var counts: Array[int] = [0, 0, 0, 0]
	for i: int in SAMPLES:
		var ilvl: int = _gen.rng.randi_range(1, 85)
		var item: Item = _gen.generate(_gen.random_base(ilvl), ilvl)
		counts[item.rarity] += 1
		var p: int = item.count_kind(AffixDef.Kind.PREFIX)
		var s: int = item.count_kind(AffixDef.Kind.SUFFIX)
		var limit: int = Item.AFFIX_LIMITS[item.rarity]
		if p > limit or s > limit:
			problems["too many prefixes/suffixes"] = true
		match item.rarity:
			Item.Rarity.NORMAL:
				if p + s != 0: problems["normal item has affixes"] = true
			Item.Rarity.MAGIC:
				if p + s < 1: problems["magic item without affixes"] = true
		var groups: Dictionary = {}
		for roll: Dictionary in item.affixes:
			var def: AffixDef = item.affix_def(roll)
			var tier: Dictionary = def.tiers[roll["tier"]]
			if groups.has(def.group): problems["duplicate affix group"] = true
			groups[def.group] = true
			if tier["ilvl"] > item.ilvl: problems["tier above item level"] = true
			if roll["value"] < tier["min"] or roll["value"] > tier["max"]: problems["value out of range"] = true
			if def.weight_multiplier(item.base) <= 0.0: problems["affix on a disallowed base"] = true
		if item.base.is_weapon() == false and item.base.slot != &"charm" and item.implicit_value == 0 \
				and not item.base.implicit.is_empty():
			problems["implicit not rolled"] = true
	print("  info: rarity counts over %d drops (N/M/R/L) = %s" % [SAMPLES, counts])
	_check("rarity weights roughly 62/30/7.5/0.5 percent", counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3])
	_check("all rolled items obey the affix rules %s" % [problems.keys()], problems.is_empty())

	# Forced rarities fill the expected counts.
	var ok: bool = true
	for i: int in 300:
		var rare: Item = _gen.generate(ItemDB.base(&"plate_vest"), 60, Item.Rarity.RARE)
		var legendary: Item = _gen.generate(ItemDB.base(&"plate_vest"), 60, Item.Rarity.LEGENDARY)
		ok = ok and rare.affixes.size() >= 3 and rare.affixes.size() <= 4
		ok = ok and legendary.affixes.size() >= 4 and legendary.affixes.size() <= 6
		ok = ok and legendary.count_kind(AffixDef.Kind.PREFIX) <= 3 and legendary.count_kind(AffixDef.Kind.SUFFIX) <= 3
	_check("rares roll 3-4 affixes; legendaries 4-6 (max 3/3)", ok)


func _test_weapon_identity() -> void:
	var seen: Dictionary = {}
	for base_id: StringName in [&"rusted_hatchet", &"rusted_sword", &"driftwood_club", &"plate_vest"]:
		var stats: Dictionary = {}
		for i: int in 600:
			var item: Item = _gen.generate(ItemDB.base(base_id), 70, Item.Rarity.RARE)
			for roll: Dictionary in item.affixes:
				stats[item.affix_def(roll).id] = true
		seen[base_id] = stats
	_check("bleed rolls on axes and swords", seen[&"rusted_hatchet"].has(&"bleed_chance") and seen[&"rusted_sword"].has(&"bleed_chance"))
	_check("bleed never rolls on maces", not seen[&"driftwood_club"].has(&"bleed_chance"))
	_check("stun rolls on maces only", seen[&"driftwood_club"].has(&"stun_duration")
		and not seen[&"rusted_hatchet"].has(&"stun_duration") and not seen[&"rusted_sword"].has(&"stun_duration"))
	_check("weapon mods never roll on armour", not seen[&"plate_vest"].has(&"local_phys_percent")
		and not seen[&"plate_vest"].has(&"attack_speed"))
	_check("armour rolls life and resistances", seen[&"plate_vest"].has(&"max_life") and seen[&"plate_vest"].has(&"fire_resistance"))


func _test_charms() -> void:
	var charm_only: bool = true
	var no_charm_on_gear: bool = true
	var bone_seen: Dictionary = {}
	for i: int in 600:
		var charm: Item = _gen.generate(ItemDB.base(&"bone_charm"), 70, Item.Rarity.RARE)
		for roll: Dictionary in charm.affixes:
			var id: String = String(charm.affix_def(roll).id)
			bone_seen[id] = true
			charm_only = charm_only and id.begins_with("charm_")
		var ring: Item = _gen.generate(ItemDB.base(&"coral_ring"), 70, Item.Rarity.RARE)
		for roll: Dictionary in ring.affixes:
			no_charm_on_gear = no_charm_on_gear and not String(ring.affix_def(roll).id).begins_with("charm_")
	_check("charms roll only charm mods", charm_only)
	_check("gear never rolls charm mods", no_charm_on_gear)
	_check("bone charms favour culling strike and explosions", bone_seen.has("charm_culling") and bone_seen.has("charm_explode"))


func _test_ilvl_gating() -> void:
	var max_life: AffixDef = ItemDB.affix(&"max_life")
	var highest_low: int = 0
	var highest_high: int = 0
	for i: int in 800:
		for pair: Array in [[5, "low"], [84, "high"]]:
			var item: Item = _gen.generate(ItemDB.base(&"coral_ring"), pair[0], Item.Rarity.RARE)
			for roll: Dictionary in item.affixes:
				if item.affix_def(roll) == max_life:
					if pair[1] == "low": highest_low = maxi(highest_low, roll["tier"])
					else: highest_high = maxi(highest_high, roll["tier"])
	_check("ilvl 5 can't roll high life tiers (best tier rank %d)" % highest_low, highest_low == 0)
	_check("ilvl 84 can roll the top life tier (best tier rank %d)" % highest_high, highest_high == max_life.tiers.size() - 1)
	var early_bases: bool = true
	for i: int in 400:
		early_bases = early_bases and _gen.random_base(1).drop_level <= 1
	_check("area level 1 only drops level-1 bases", early_bases)


func _test_legendary_bias() -> void:
	var rare_sum: float = 0.0
	var legendary_sum: float = 0.0
	var rare_n: int = 0
	var legendary_n: int = 0
	for i: int in 1500:
		for rarity: Item.Rarity in [Item.Rarity.RARE, Item.Rarity.LEGENDARY]:
			var item: Item = _gen.generate(ItemDB.base(&"plate_vest"), 80, rarity)
			for roll: Dictionary in item.affixes:
				var fraction: float = float(roll["tier"]) / maxf(item.affix_def(roll).tiers.size() - 1, 1.0)
				if rarity == Item.Rarity.RARE:
					rare_sum += fraction
					rare_n += 1
				else:
					legendary_sum += fraction
					legendary_n += 1
	var rare_avg: float = rare_sum / rare_n
	var legendary_avg: float = legendary_sum / legendary_n
	print("  info: average tier position rare %.3f vs legendary %.3f" % [rare_avg, legendary_avg])
	_check("legendaries roll higher tiers on average", legendary_avg > rare_avg + 0.05)


func _test_sockets() -> void:
	var histogram: Array[int] = [0, 0, 0, 0, 0]
	var ring_sockets: int = 0
	for i: int in 2000:
		histogram[_gen.generate(ItemDB.base(&"plate_vest"), 30).sockets] += 1
		ring_sockets += _gen.generate(ItemDB.base(&"coral_ring"), 30).sockets
	var helm_max: int = 0
	for i: int in 500:
		helm_max = maxi(helm_max, _gen.generate(ItemDB.base(&"iron_hat"), 30).sockets)
	print("  info: body armour sockets 1/2/3/4 = %s" % [histogram.slice(1)])
	_check("body armour sockets are biased toward fewer", histogram[0] == 0 and histogram[1] > histogram[2]
		and histogram[2] > histogram[3] and histogram[3] > histogram[4] and histogram[4] > 0)
	_check("helms never exceed 2 sockets", helm_max == 2)
	_check("rings have no sockets", ring_sockets == 0)


func _test_names() -> void:
	var magic: Item = _gen.generate(ItemDB.base(&"plate_vest"), 40, Item.Rarity.MAGIC)
	var rare: Item = _gen.generate(ItemDB.base(&"plate_vest"), 40, Item.Rarity.RARE)
	print("  info: magic '%s', rare '%s'" % [magic.display_name(), rare.display_name()])
	_check("magic names include the base name", magic.display_name().contains("Plate Vest"))
	_check("rares get a two-word name", rare.display_name().split(" ").size() == 2)
	var ring: Item = _gen.generate(ItemDB.base(&"iron_ring"), 1, Item.Rarity.NORMAL)
	_check("implicit text formats 'Adds X to Y'", ring.implicit_text().begins_with("Adds ") and ring.implicit_text().contains(" to "))
	_check("item types name hands and weapon class", ItemDB.base(&"rusted_hatchet").type_name() == "One Handed Axe"
		and ItemDB.base(&"driftwood_maul").type_name() == "Two Handed Mace" and ItemDB.base(&"plate_vest").type_name() == "Body Armour"
		and ItemDB.base(&"goathide_buckler").type_name() == "Shield")
	var gloves: Item = _gen.generate(ItemDB.base(&"rawhide_gloves"), 1, Item.Rarity.MAGIC)
	gloves.affixes = [{"id": &"increased_defences", "tier": 0, "value": 18}, {"id": &"max_life", "tier": 0, "value": 12}]
	var lines: Array[String] = gloves.affix_lines()
	_check("local mods are marked (local); global ones aren't", lines[0].ends_with("(local)") and not lines[1].ends_with("(local)"))


func _test_inventory() -> void:
	var inv := Inventory.new()
	var two_hander: Item = _gen.generate(ItemDB.base(&"stone_axe"), 1, Item.Rarity.NORMAL)
	_check("a 2x4 weapon goes in the top-left corner", inv.try_add(two_hander) and inv.position_of(two_hander) == Vector2i(0, 0))
	var ring: Item = _gen.generate(ItemDB.base(&"coral_ring"), 1, Item.Rarity.NORMAL)
	inv.try_add(ring)
	_check("the next item fills below it in the same column", inv.position_of(ring) == Vector2i(0, 4))
	var added: int = 0
	while inv.try_add(_gen.generate(ItemDB.base(&"plate_vest"), 1, Item.Rarity.NORMAL)):
		added += 1
	print("  info: fit %d more 2x3 chests" % added)
	_check("the grid fills and then refuses items", added == 5)
	var cell_ok: bool = not inv.can_place(ring, Vector2i(0, 0)) and not inv.can_place(ring, Vector2i(12, 0))
	_check("placement rejects overlaps and out-of-bounds cells", cell_ok)

	var stacks := Inventory.new()
	var orb_a: Item = _gen.generate(ItemDB.base(&"orb_chaos"), 10)
	orb_a.stack = 7
	var orb_b: Item = _gen.generate(ItemDB.base(&"orb_chaos"), 10)
	orb_b.stack = 5
	stacks.try_add(orb_a)
	stacks.try_add(orb_b)
	_check("currency merges into existing stacks up to the stack limit",
		stacks.entries.size() == 2 and orb_a.stack == 10 and orb_b.stack == 2)
	inv.free()
	stacks.free()


func _test_drop_and_pickup() -> void:
	var arena: Node3D = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	arena.get_node("GoblinSpawner").free()
	var region: RuntimeNavBaker = arena.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	var player: CharacterBody3D = arena.get_node("Player") as CharacterBody3D
	player.global_position = OPEN_SPOT
	player.reset_physics_interpolation()

	var goblin: CharacterBody3D = (load(GOBLIN_PATH) as PackedScene).instantiate() as CharacterBody3D
	arena.add_child(goblin)
	goblin.global_position = OPEN_SPOT + Vector3(4.0, 0.0, 0.0)
	(goblin.get_node("EnemyAI") as EnemyAI).set_physics_process(false)
	var dropper: LootDropper = goblin.get_node("LootDropper") as LootDropper
	dropper.item_chance = 1.0
	dropper.currency_chance = 1.0
	await physics_frame
	Health.of(goblin).take_damage(1000.0)
	await physics_frame
	var grounds: Array[Node] = get_nodes_in_group(GroundItem.GROUP)
	_check("a dying goblin drops an item and currency", grounds.size() == 2)
	var levels_ok: bool = grounds.all(func(g: Node) -> bool: return (g as GroundItem).item.ilvl == 5)
	_check("drops use the area level (5) as item level", levels_ok)

	var pickup: ItemPickup = player.get_node("ItemPickup") as ItemPickup
	var inventory: Inventory = player.get_node("Inventory") as Inventory
	inventory.entries.clear()  # drop the starting gems so only picked-up items count
	for node: Node in grounds:
		pickup.request(node as GroundItem)
		for i: int in 240:
			await physics_frame
			if not is_instance_valid(node):
				break
	await physics_frame
	_check("clicking a label walks over and picks items up", get_nodes_in_group(GroundItem.GROUP).is_empty()
		and inventory.entries.size() == 2)
	arena.queue_free()
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
