extends SceneTree
## Zone playability headless test for the dressed zones: each zone is a kit
## Zone with a biome, its navmesh bakes, every entry can walk to every exit and
## to every spawn point and vendor, no marker sits inside a prop, and the
## scatters actually placed props. Run with:
##   godot --headless --path <project> -s res://tests/test_zones.gd
## Exits with 0 when every check passes, 1 otherwise.

const ZONES: Array[String] = ["res://scenes/levels/town.tscn", "res://scenes/levels/shore.tscn"]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in ZONES:
		await _test_zone(path)
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_zone(path: String) -> void:
	var zone: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(zone)
	var label: String = zone.name
	var start: int = Time.get_ticks_msec()
	var region: RuntimeNavBaker = zone.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	print("  info: %s loaded and baked in %d ms" % [label, Time.get_ticks_msec() - start])
	_check("%s is a kit Zone with a biome" % label, zone is Zone and (zone as Zone).biome != null)
	await physics_frame
	await physics_frame
	var map: RID = region.get_navigation_map()

	var targets: Array[Node3D] = []
	for exit: Node in zone.get_node("Exits").get_children():
		targets.append(exit as Node3D)
	var spawner: Node = zone.get_node_or_null("GoblinSpawner")
	if spawner != null:
		for marker: Node in spawner.get_children():
			if marker is Marker3D:
				targets.append(marker as Node3D)
	for vendor: Node in zone.find_children("*", "StaticBody3D", true, false):
		if vendor is Vendor:
			targets.append(vendor as Node3D)
	var unreachable: Array[String] = []
	for entry: Node in zone.get_node("Entries").get_children():
		var from: Vector3 = (entry as Node3D).global_position
		for target: Node3D in targets:
			var to: Vector3 = target.global_position
			var route: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
			var slack: float = 2.2 if target is Vendor else 1.0
			if route.is_empty() or Vector2(route[-1].x - to.x, route[-1].z - to.z).length() > slack:
				unreachable.append("%s->%s" % [entry.name, target.name])
	_check("%s: every entry reaches every exit, spawn and vendor %s" % [label, unreachable], unreachable.is_empty())

	# No entry or spawn marker may start inside a prop's collider.
	var space: PhysicsDirectSpaceState3D = zone.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var buried: Array[String] = []
	for marker: Node in zone.find_children("*", "Marker3D", true, false):
		query.transform = Transform3D(Basis.IDENTITY, (marker as Node3D).global_position + Vector3(0, 0.9, 0))
		if not space.intersect_shape(query, 4).is_empty():
			buried.append(String(marker.name))
	_check("%s: no marker is inside a prop %s" % [label, buried], buried.is_empty())

	var placed: int = 0
	for scatter: Node in zone.find_children("*", "Node3D", true, false):
		if scatter is PropScatter:
			placed += (scatter as PropScatter).placed_count
	print("  info: %s scatters placed %d props" % [label, placed])
	_check("%s: scatters dressed the zone" % label, placed > 100)
	var lights: int = zone.find_children("*", "OmniLight3D", true, false).size()
	var shadowed: int = zone.find_children("*", "OmniLight3D", true, false).filter(
		func(l: Node) -> bool: return (l as OmniLight3D).shadow_enabled).size()
	print("  info: %s has %d fire lights (%d with shadows)" % [label, lights, shadowed])
	_check("%s: shadowed lights stay within budget" % label, shadowed <= 8)
	zone.queue_free()
	await process_frame
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
