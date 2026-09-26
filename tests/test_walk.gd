extends SceneTree
## Milestone 1 headless test. Run with:
##   godot --headless --path <project> -s res://tests/test_walk.gd
## Exits with 0 when every check passes, 1 otherwise.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const REQUIRED_ACTIONS: Array[String] = [
	"move", "attack",
	"skill_1", "skill_2", "skill_3", "skill_4", "skill_5",
	"potion_1", "potion_2", "potion_3", "potion_4", "potion_5",
	"inventory", "character", "passives", "show_labels", "menu",
]
## Start and target sit on opposite sides of CenterWall, so a straight
## line between them passes through the wall.
const START: Vector3 = Vector3(0.0, 0.0, 5.0)
const TARGET: Vector3 = Vector3(0.0, 0.0, -5.0)
const ARRIVAL_TOLERANCE: float = 0.5
const PLAYER_RADIUS: float = 0.4
const MAX_FRAMES: int = 900  # 15 s of physics at 60 Hz

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_input_actions()

	var arena: Node3D = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	var region: RuntimeNavBaker = arena.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	var polygons: int = region.navigation_mesh.get_polygon_count()
	_check("navmesh baked (%d polygons)" % polygons, polygons > 0)

	var player: CharacterBody3D = arena.get_node("Player") as CharacterBody3D
	var movement: NavMovement = player.get_node("NavMovement") as NavMovement
	var wall_rect: Rect2 = _footprint(region.get_node("CenterWall") as StaticBody3D)
	_check("straight line START->TARGET crosses CenterWall", wall_rect.has_point(Vector2(0.0, 0.0)))

	player.global_position = START
	player.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	movement.set_target(TARGET)

	# The capsule's footprint is a circle; it overlaps the wall when the
	# distance from its centre to the wall rectangle is below its radius.
	var min_clearance: float = INF
	var max_side_offset: float = 0.0
	var frames: int = 0
	while frames < MAX_FRAMES:
		await physics_frame
		frames += 1
		var p: Vector3 = player.global_position
		min_clearance = minf(min_clearance, _distance_to_rect(Vector2(p.x, p.z), wall_rect) - PLAYER_RADIUS)
		max_side_offset = maxf(max_side_offset, absf(p.x))
		if not movement.is_moving():
			break
	var overlapped: bool = min_clearance < 0.0

	var final_pos: Vector3 = player.global_position
	var error: float = Vector2(final_pos.x - TARGET.x, final_pos.z - TARGET.z).length()
	print("  info: stopped after %d frames at %s (%.3f from target), max |x| = %.2f, min wall clearance = %.3f" \
		% [frames, final_pos, error, max_side_offset, min_clearance])
	_check("player reached target within %.2f units" % ARRIVAL_TOLERANCE, error <= ARRIVAL_TOLERANCE)
	_check("player never overlapped CenterWall footprint", not overlapped)
	_check("path went around the wall (|x| exceeded half-width)", max_side_offset > wall_rect.size.x * 0.5)
	_check("player stays on the floor (y ~ 0)", absf(final_pos.y) < 0.1)

	arena.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check_input_actions() -> void:
	for action: String in REQUIRED_ACTIONS:
		var ok: bool = InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty()
		_check("input action '%s' exists and is bound" % action, ok)


func _footprint(body: StaticBody3D) -> Rect2:
	var shape: BoxShape3D = (body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var centre: Vector3 = body.global_position
	var size: Vector2 = Vector2(shape.size.x, shape.size.z)
	return Rect2(Vector2(centre.x, centre.z) - size * 0.5, size)


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var closest: Vector2 = point.clamp(rect.position, rect.end)
	return point.distance_to(closest)


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
