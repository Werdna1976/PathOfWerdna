extends SceneTree
## Milestone 2 headless test. Run with:
##   godot --headless --path <project> -s res://tests/test_fight.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const GOBLIN_PATH: String = "res://scenes/enemies/goblin.tscn"
## Open ground south of the centre wall, away from crates and pillars.
const DUEL_SPOT: Vector3 = Vector3(0.0, 0.0, 12.0)

var _failures: int = 0
var _arena: Node3D
var _player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_arena = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(_arena)
	var region: RuntimeNavBaker = _arena.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	_player = _arena.get_node("Player") as CharacterBody3D

	var spawner: EnemySpawner = _arena.get_node("GoblinSpawner") as EnemySpawner
	var markers: int = spawner.get_children().filter(func(n: Node) -> bool: return n is Marker3D).size()
	var spawned: int = get_nodes_in_group("enemies").size()
	_check("spawner created one goblin per marker (%d/%d)" % [spawned, markers], spawned == markers and markers > 0)
	spawner.free()

	await _test_goblin_chases()
	await _test_kill_goblin()
	await _test_strike_in_place()
	await _test_death_and_respawn()

	_arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_goblin_chases() -> void:
	_place(_player, DUEL_SPOT)
	var goblin: CharacterBody3D = await _spawn_goblin(DUEL_SPOT + Vector3(8.0, 0.0, 0.0))
	var start_distance: float = _flat_distance(goblin, _player)
	await _frames(120)
	var end_distance: float = _flat_distance(goblin, _player)
	print("  info: goblin distance %.2f -> %.2f after 2 s" % [start_distance, end_distance])
	_check("goblin aggroes and closes distance", end_distance < start_distance - 3.0)
	goblin.free()


func _test_kill_goblin() -> void:
	var player_health: Health = Health.of(_player)
	player_health.restore_full()
	_place(_player, DUEL_SPOT)
	var goblin: CharacterBody3D = await _spawn_goblin(DUEL_SPOT + Vector3(0.0, 0.0, -3.0))
	var goblin_health: Health = Health.of(goblin)
	var died: Array[bool] = [false]
	goblin_health.died.connect(func() -> void: died[0] = true)

	var combat: PlayerCombat = _player.get_node("PlayerCombat") as PlayerCombat
	var frames: int = 0
	# Re-issue the order each time the previous strike lands, like holding the button.
	while frames < 600 and not died[0]:
		if not (_player.get_node("Melee") as MeleeAttack).is_busy():
			combat.attack_target(goblin)
		await physics_frame
		frames += 1
	print("  info: goblin died after %d frames; player life %.0f/%.0f" \
		% [frames, player_health.current, player_health.max_health])
	_check("player walks into range and kills a goblin with Heavy Strike", died[0])
	_check("goblin hit the player back", player_health.current < player_health.max_health)
	_check("dead goblin is no longer targetable", goblin.collision_layer == 0)
	await _frames(300)
	_check("goblin corpse is removed", not is_instance_valid(goblin))


func _test_strike_in_place() -> void:
	var melee: MeleeAttack = _player.get_node("Melee") as MeleeAttack
	var finished: Array[bool] = [false]
	var on_finished := func() -> void: finished[0] = true
	melee.swing_finished.connect(on_finished)
	var combat: PlayerCombat = _player.get_node("PlayerCombat") as PlayerCombat
	var before: Vector3 = _player.global_position
	combat.attack_point(before + Vector3(3.0, 0.0, 0.0))
	await _frames(60)
	melee.swing_finished.disconnect(on_finished)
	var facing: Vector3 = -_player.global_basis.z
	_check("ground strike swings in place", finished[0] and _player.global_position.distance_to(before) < 0.05)
	_check("ground strike faces the clicked point", facing.dot(Vector3.RIGHT) > 0.95)


func _test_death_and_respawn() -> void:
	var health: Health = Health.of(_player)
	var respawn: PlayerRespawn = _player.get_node("PlayerRespawn") as PlayerRespawn
	_place(_player, DUEL_SPOT)
	health.take_damage(10000.0)
	_check("player dies at 0 life", health.is_dead())
	await _frames(int((respawn.respawn_delay + 1.0) * 60.0))
	var spawn: Vector3 = Vector3(0.0, 0.0, 6.0)
	_check("player respawns with full life", health.current == health.max_health)
	_check("player respawns at the start point", _flat_distance_to(_player, spawn) < 0.2)


func _spawn_goblin(at: Vector3) -> CharacterBody3D:
	var goblin: CharacterBody3D = (load(GOBLIN_PATH) as PackedScene).instantiate() as CharacterBody3D
	_arena.add_child(goblin)
	_place(goblin, at)
	await physics_frame
	return goblin


func _place(body: CharacterBody3D, at: Vector3) -> void:
	body.global_position = at
	body.reset_physics_interpolation()
	(body.get_node("NavMovement") as NavMovement).stop()


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return _flat_distance_to(a, b.global_position)


func _flat_distance_to(a: Node3D, point: Vector3) -> float:
	return Vector2(a.global_position.x - point.x, a.global_position.z - point.z).length()


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
