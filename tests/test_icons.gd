extends SceneTree
## Item icon headless test: every item base, orb and gem resolves to a real
## icon, types get the right defaults, per-base overrides win, icons show on
## ground items and labels. Run with:
##   godot --headless --path <project> -s res://tests/test_icons.gd
## Exits with 0 when every check passes, 1 otherwise.

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var unknown: Array[String] = []
	var missing: Array[String] = []
	for base: ItemBase in ItemDB.bases():
		var id: String = ItemIcons.icon_id(base)
		if id == "unknown":
			unknown.append(String(base.id))
		if ItemIcons.texture_for_base(base) == null:
			missing.append(String(base.id))
	_check("every item base has an icon %s" % [unknown], unknown.is_empty())
	_check("every icon loads as a texture %s" % [missing], missing.is_empty())

	var gem_ids: Dictionary = {}
	for id: StringName in ItemDB.GEM_PATHS:
		var gem: Item = ItemDB.make_gem(id)
		gem_ids[ItemIcons.icon_id(gem.base)] = true
	_check("every gem has its own icon", gem_ids.size() == ItemDB.GEM_PATHS.size() and not gem_ids.has("unknown"))
	var orb_ids: Dictionary = {}
	var orbs: int = 0
	for base: ItemBase in ItemDB.bases():
		if base.is_currency():
			orbs += 1
			orb_ids[ItemIcons.icon_id(base)] = true
	_check("every orb and the shard have distinct icons", orb_ids.size() == orbs)

	var expect: Dictionary = {
		&"rusted_hatchet": "axe_1h", &"double_axe": "axe_2h", &"sabre": "sword_1h", &"highland_blade": "sword_2h",
		&"tribal_club": "mace_1h", &"great_mallet": "mace_2h", &"goathide_buckler": "shield_dex",
		&"plank_kite_shield": "shield_str_int", &"full_plate": "chest_str", &"padded_vest": "chest_dex_int",
		&"vine_circlet": "helm_int", &"chain_gloves": "gloves_str_int", &"wool_shoes": "boots_int",
		&"coral_ring": "ring", &"gold_amulet": "amulet", &"grim_bone_charm": "charm_bone", &"swift_charm": "charm_swift",
	}
	var wrong: Array[String] = []
	for base_id: StringName in expect:
		if ItemIcons.icon_id(ItemDB.base(base_id)) != expect[base_id]:
			wrong.append("%s=%s" % [base_id, ItemIcons.icon_id(ItemDB.base(base_id))])
	_check("bases get icons by slot, type and defence %s" % [wrong], wrong.is_empty())

	var custom := ItemBase.from_dict({"id": "test_custom_base", "name": "Custom", "slot": "ring", "tags": ["ring"],
		"icon": "orb_chaos"})
	_check("an explicit icon field overrides the type default", ItemIcons.icon_id(custom) == "orb_chaos")
	var fallback := ItemBase.from_dict({"id": "test_new_boots", "name": "New Boots", "slot": "boots",
		"tags": ["armour", "boots", "dex_armour"]})
	_check("a new base with no art gets its type's icon", ItemIcons.icon_id(fallback) == "boots_dex")

	var holder := Node3D.new()
	root.add_child(holder)
	var ground: GroundItem = GroundItem.spawn(ItemGenerator.new(1).generate(ItemDB.base(&"iron_hat"), 1), holder, Vector3.ZERO)
	var sprite: Sprite3D = ground.find_child("Icon", true, false) as Sprite3D
	_check("ground items show a floating icon", sprite != null and sprite.texture != null)
	var labels := GroundLabels.new()
	root.add_child(labels)
	for i: int in 3:
		await process_frame
	var has_icon: bool = not labels.find_children("*", "TextureRect", true, false).is_empty()
	_check("ground labels start with the item icon", has_icon)
	holder.queue_free()
	labels.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
