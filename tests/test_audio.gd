extends SceneTree
## Audio headless test (nothing is heard): the Audio autoload and bus layout
## exist, every sound effect, music track and ambience loop loads, the loops
## loop and have the right lengths, and zone changes switch the music.
## Run with:
##   godot --headless --path <project> -s res://tests/test_audio.gd
## Exits with 0 when every check passes, 1 otherwise.

const SFX_IDS: Array[StringName] = [&"swing", &"hit_flesh", &"hit_armour", &"crit", &"block", &"evade",
	&"goblin_grunt", &"goblin_death", &"player_hurt", &"player_death", &"drop_normal", &"drop_magic",
	&"drop_rare", &"drop_legendary", &"orb_drop", &"pickup", &"potion_drink", &"skill_fail", &"zone_travel",
	&"vendor_buy", &"vendor_sell", &"ui_click", &"inventory_open", &"inventory_close", &"footstep_sand",
	&"footstep_dirt"]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio: Node = root.get_node_or_null("Audio")
	_check("the Audio autoload exists", audio != null)
	if audio == null:
		quit(1)
		return
	var buses_ok: bool = true
	for bus: String in ["Master", "Music", "SFX", "Ambience"]:
		buses_ok = buses_ok and AudioServer.get_bus_index(bus) >= 0
	_check("buses Master, Music, SFX and Ambience exist", buses_ok)
	_check("music is quieter than sound effects",
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) < AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))

	var missing: Array[String] = []
	for id: StringName in SFX_IDS:
		if not audio.has_sound(id):
			missing.append(String(id))
			continue
		var player: Node = audio.play(id, Vector3.ZERO)
		var stream: AudioStream = player.get("stream") if player != null else null
		if stream == null or stream.get_length() <= 0.0:
			missing.append(String(id))
	_check("every sound effect loads and plays %s" % [missing], missing.is_empty())
	_check("variants are grouped under one id (3 swings)", audio._sounds[&"swing"].size() == 3)

	for track: Array in [["town", 90.0, 150.0], ["shore", 90.0, 150.0]]:
		var stream: AudioStreamWAV = audio.load_loop(audio.MUSIC_DIR, StringName(track[0])) as AudioStreamWAV
		_check("music '%s' loads, loops and is %d-%d s" % track, stream != null
			and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
			and stream.get_length() >= track[1] and stream.get_length() <= track[2])
	for loop: String in ["campfire", "sea", "wind"]:
		var stream: AudioStreamWAV = audio.load_loop(audio.AMBIENCE_DIR, StringName(loop)) as AudioStreamWAV
		_check("ambience '%s' loads and loops" % loop, stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED)

	_check_recipes(audio)

	# In the game, zones pick their music and ambience.
	var game: Game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	for i: int in 60:
		await physics_frame
	_check("Werdna's Camp plays the town music and campfire ambience",
		audio.current_music == &"town" and audio.current_ambience == &"campfire")
	game.change_zone("res://scenes/levels/shore.tscn", &"from_town")
	for i: int in 30:
		await physics_frame
	_check("the Shore crossfades to its music and sea ambience",
		audio.current_music == &"shore" and audio.current_ambience == &"sea" and audio.footstep_surface == "sand")
	await physics_frame
	var player_melee: MeleeAttack = game.player.get_node("Melee") as MeleeAttack
	_check("Werdna's hatchet plays axe hits and swings", audio.weapon_class(player_melee) == "axe")
	var goblins: Array[Node] = game.get_tree().get_nodes_in_group("enemies")
	_check("goblins (no gear) hit with club sounds", not goblins.is_empty()
		and audio.weapon_class(goblins[0].get_node("Attack") as MeleeAttack) == "club")
	var equipment: Equipment = game.player.get_node("Equipment") as Equipment
	var fired: Array[Item] = []
	equipment.item_equipped.connect(func(item: Item, _slot: StringName) -> void: fired.append(item))
	var boots: Item = ItemGenerator.new().generate(ItemDB.base(&"iron_greaves"), 1, Item.Rarity.NORMAL)
	equipment.equip(boots, &"boots")
	_check("equipping gear signals which item went on", fired == [boots])
	game.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## Every sample recipe resolves its files, loads them, and plays; each
## weapon class has a hit and a swing; equip sounds map by item type.
func _check_recipes(audio: Node) -> void:
	var empty: Array[String] = []
	var broken: Array[String] = []
	for id: StringName in audio._recipes:
		for layer: Dictionary in audio._recipes[id]:
			if (layer["files"] as Array).is_empty():
				empty.append(String(id))
		for path: Variant in audio.recipe_files(id):
			var stream: AudioStream = path if path is AudioStream else load(path)
			if stream == null or stream.get_length() <= 0.0:
				broken.append(String(id))
	_check("every recipe layer matches sample files %s" % [empty], empty.is_empty())
	_check("every recipe sample loads %s" % [broken], broken.is_empty())
	var missing: Array[String] = []
	for kind: String in ["sword", "axe", "mace", "dagger", "club", "fist"]:
		for prefix: String in ["hit_", "swing_"]:
			if not audio.has_recipe(StringName(prefix + kind)):
				missing.append(prefix + kind)
	_check("each weapon class has a hit and a swing %s" % [missing], missing.is_empty())
	var hit: Node = audio.play(&"hit_mace", Vector3.ZERO)
	_check("playing a recipe starts a sample", hit != null and hit.get("stream") != null)
	var gen := ItemGenerator.new()
	var cases: Dictionary = {&"plate_vest": &"equip_plate", &"shabby_jerkin": &"equip_leather",
		&"simple_robe": &"equip_cloth", &"rusted_sword": &"equip_blade", &"driftwood_club": &"equip_blunt",
		&"goathide_buckler": &"equip_shield", &"coral_ring": &"equip_trinket", &"bone_charm": &"equip_trinket"}
	var wrong: Array[String] = []
	for base_id: StringName in cases:
		var sound: StringName = audio.equip_sound(gen.generate(ItemDB.base(base_id), 1, Item.Rarity.NORMAL))
		if sound != cases[base_id] or not audio.has_recipe(sound):
			wrong.append("%s->%s" % [base_id, sound])
	_check("equip sounds follow the item type %s" % [wrong], wrong.is_empty())


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
