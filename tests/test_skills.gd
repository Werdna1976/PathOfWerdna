extends SceneTree
## Milestone 3 headless test. Run with:
##   godot --headless --path <project> -s res://tests/test_skills.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const GOBLIN_PATH: String = "res://scenes/enemies/goblin.tscn"
## Open ground south of the centre wall, away from crates and pillars.
const OPEN_SPOT: Vector3 = Vector3(0.0, 0.0, 12.0)
const SLOT_HEAVY: int = 0
const SLOT_CLEAVE: int = 1
const SLOT_LEAP: int = 2

var _failures: int = 0
var _arena: Node3D
var _player: CharacterBody3D
var _combat: PlayerCombat
var _melee: MeleeAttack
var _skills: SkillBar
var _mana: Mana
var _health: Health
var _potions: PotionBelt


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
	_combat = _player.get_node("PlayerCombat") as PlayerCombat
	_melee = _player.get_node("Melee") as MeleeAttack
	_skills = _player.get_node("SkillBar") as SkillBar
	_mana = Mana.of(_player)
	_health = Health.of(_player)
	_potions = _player.get_node("PotionBelt") as PotionBelt

	_check_loadout()
	await _test_cleave_hits_several()
	await _test_heavy_strike_single_target()
	await _test_leap_slam()
	await _test_not_enough_mana()
	await _test_mana_regen()
	await _test_potions()

	_arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check_loadout() -> void:
	var names: Array[String] = []
	for slot: int in SkillBar.SLOT_COUNT:
		var gem: SkillGem = _skills.gem_in(slot)
		names.append(gem.display_name if gem != null else "-")
	print("  info: skill bar = %s" % [names])
	_check("default loadout is Heavy Strike / Cleave / Leap Slam on RMB / Q / W",
		names.slice(0, 3) == ["Heavy Strike", "Cleave", "Leap Slam"])
	_check("two potions: health on 1, mana on 2", _potions.potions.size() == 2
		and _potions.potions[0].restores == PotionData.Restores.LIFE
		and _potions.potions[1].restores == PotionData.Restores.MANA)


func _test_cleave_hits_several() -> void:
	await _reset_player()
	# Three goblins fanned out in front (-Z) of the player, all within Cleave's reach.
	var goblins: Array[CharacterBody3D] = []
	for offset: Vector3 in [Vector3(-1.2, 0, -1.2), Vector3(0, 0, -1.6), Vector3(1.2, 0, -1.2)]:
		goblins.append(await _spawn_goblin(OPEN_SPOT + offset))
	var cost: float = _skills.gem_in(SLOT_CLEAVE).mana_cost
	var mana_before: float = _mana.current
	_combat.order_point(SLOT_CLEAVE, OPEN_SPOT + Vector3(0, 0, -3))
	await _frames(40)
	var hit: int = goblins.filter(func(g: CharacterBody3D) -> bool:
		return Health.of(g).current < Health.of(g).max_health).size()
	print("  info: Cleave damaged %d of 3 goblins" % hit)
	_check("Cleave hits every goblin in its arc", hit == 3)
	_check("Cleave spends its mana cost (%.0f)" % cost, is_equal_approx(mana_before - _mana.current, cost)
		or absf((mana_before - _mana.current) - cost) < 1.5)  # regen ticks during the swing
	for g: CharacterBody3D in goblins:
		g.free()


func _test_heavy_strike_single_target() -> void:
	await _reset_player()
	var goblins: Array[CharacterBody3D] = []
	for offset: Vector3 in [Vector3(-0.6, 0, -1.3), Vector3(0.6, 0, -1.3)]:
		goblins.append(await _spawn_goblin(OPEN_SPOT + offset))
	_combat.order_point(SLOT_HEAVY, OPEN_SPOT + Vector3(0, 0, -3))
	await _frames(40)
	var hit: int = goblins.filter(func(g: CharacterBody3D) -> bool:
		return Health.of(g).current < Health.of(g).max_health).size()
	_check("Heavy Strike hits exactly one goblin", hit == 1)
	for g: CharacterBody3D in goblins:
		g.free()


func _test_leap_slam() -> void:
	await _reset_player()
	var leap: SkillGem = _skills.gem_in(SLOT_LEAP)
	var goblin: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(6.0, 0, 0))
	var start: Vector3 = _player.global_position
	_combat.order_target(SLOT_LEAP, goblin)
	await _frames(45)
	var travelled: float = _flat(_player.global_position - start)
	print("  info: leap travelled %.2f units; goblin life %.0f/%.0f" \
		% [travelled, Health.of(goblin).current, Health.of(goblin).max_health])
	_check("Leap Slam carries the player to the target", travelled > 4.5)
	_check("Leap Slam damages enemies at the landing spot", Health.of(goblin).current < Health.of(goblin).max_health)
	_check("Leap Slam goes on cooldown", _skills.cooldown_left(leap) > 0.0)
	_check("player is back on the ground after landing", absf((_player.get_node("Visual") as Node3D).position.y) < 0.01)

	# Using it again during the cooldown must fail without moving.
	var failures: Array[String] = []
	var on_fail := func(reason: String) -> void: failures.append(reason)
	_skills.use_failed.connect(on_fail)
	await _frames(30)  # let recovery finish
	var before: Vector3 = _player.global_position
	_combat.order_point(SLOT_LEAP, before + Vector3(-5.0, 0, 0))
	await _frames(5)
	_skills.use_failed.disconnect(on_fail)
	_check("Leap Slam can't be used while on cooldown",
		not failures.is_empty() and _flat(_player.global_position - before) < 0.05)
	await _frames(int(leap.cooldown * 60.0))
	_check("cooldown expires", _skills.cooldown_left(leap) == 0.0)
	goblin.free()


func _test_not_enough_mana() -> void:
	await _reset_player()
	_mana.current = 2.0
	var failures: Array[String] = []
	var on_fail := func(reason: String) -> void: failures.append(reason)
	_skills.use_failed.connect(on_fail)
	var started: Array[bool] = [false]
	var on_start := func() -> void: started[0] = true
	_melee.swing_started.connect(on_start)
	_combat.order_point(SLOT_CLEAVE, OPEN_SPOT + Vector3(0, 0, -3))
	await _frames(3)
	_skills.use_failed.disconnect(on_fail)
	_melee.swing_started.disconnect(on_start)
	_check("Cleave is refused without enough mana", not started[0] and failures.has("Not enough mana"))

	_combat.order_point(SLOT_HEAVY, OPEN_SPOT + Vector3(0, 0, -3))
	await _frames(3)
	_check("Heavy Strike (no cost) still works at low mana", _melee.is_busy())
	await _frames(40)


func _test_mana_regen() -> void:
	_mana.current = 10.0
	await _frames(60)
	print("  info: mana after 1 s of regen: %.2f" % _mana.current)
	_check("mana regenerates over time", _mana.current > 11.0 and _mana.current < 13.0)


func _test_potions() -> void:
	await _reset_player()
	var life_potion: PotionData = _potions.potions[0]
	_health.take_damage(60.0)
	var life_before: float = _health.current
	_check("health potion drinks", _potions.drink(0))
	await _frames(int(life_potion.duration * 60.0) + 5)
	print("  info: life %.0f -> %.0f after the potion" % [life_before, _health.current])
	_check("health potion restores its amount over its duration",
		absf(_health.current - minf(life_before + life_potion.amount, _health.max_health)) < 1.0)
	_check("drinking spends charges",
		is_equal_approx(_potions.charges[0], life_potion.max_charges - life_potion.charges_per_use))

	_mana.current = 0.0
	_mana.regen_per_second = 0.0
	_potions.drink(1)
	await _frames(int(_potions.potions[1].duration * 60.0) + 5)
	_check("mana potion restores mana", absf(_mana.current - _potions.potions[1].amount) < 1.0)
	_mana.regen_per_second = 2.0

	# Empty the health potion, then check a kill gives charges back.
	_potions.drink(0)
	_potions.drink(0)
	_check("an empty potion can't be drunk", not _potions.drink(0))
	var goblin: CharacterBody3D = await _spawn_goblin(OPEN_SPOT + Vector3(0, 0, -1.3))
	Health.of(goblin).take_damage(1000.0)
	_check("killing an enemy refills potion charges", _potions.charges[0] == _potions.charges_per_kill)
	await _frames(300)


func _reset_player() -> void:
	_combat.clear()
	_melee.cancel()
	_player.global_position = OPEN_SPOT
	_player.rotation.y = 0.0
	_player.reset_physics_interpolation()
	(_player.get_node("NavMovement") as NavMovement).stop()
	_health.restore_full()
	_mana.restore_full()
	_potions.refill()
	await _frames(2)


func _spawn_goblin(at: Vector3) -> CharacterBody3D:
	var goblin: CharacterBody3D = (load(GOBLIN_PATH) as PackedScene).instantiate() as CharacterBody3D
	_arena.add_child(goblin)
	goblin.global_position = at
	goblin.reset_physics_interpolation()
	# Keep test goblins passive so their attacks don't interfere.
	(goblin.get_node("EnemyAI") as EnemyAI).set_physics_process(false)
	await physics_frame
	return goblin


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
