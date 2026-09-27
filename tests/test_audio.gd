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
	game.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
