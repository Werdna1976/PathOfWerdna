extends SceneTree
## World kit headless test: textures and materials load, every prop builds
## (and drops its colliders when decorative), PropScatter is deterministic and
## respects exclusions, biomes load, and the zone template sets itself up and
## bakes a navmesh. Run with:
##   godot --headless --path <project> -s res://tests/test_kit.gd
## Exits with 0 when every check passes, 1 otherwise.

const PROP_DIR: String = "res://scenes/kit/props/"
const EFFECT_DIR: String = "res://scenes/kit/effects/"
const TEXTURES: Array[String] = ["sand", "wet_sand", "dirt", "packed_earth", "grass", "stone", "cobbles",
	"planks", "cliff_rock", "bark", "cloth"]
const BIOMES: Array[String] = ["camp", "shore", "forest"]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_materials()
	await _test_props()
	await _test_effects()
	await _test_scatter()
	_test_biomes()
	await _test_zone_template()
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_materials() -> void:
	var missing: Array[String] = []
	for t: String in TEXTURES:
		var mat: StandardMaterial3D = load("res://assets/materials/%s.tres" % t) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null or mat.normal_texture == null:
			missing.append(t)
	_check("every kit material has albedo and normal maps %s" % [missing], missing.is_empty())
	var shaders_ok: bool = true
	for m: String in ["water", "foliage", "banner", "ground_camp", "ground_shore", "ground_forest"]:
		var sm: ShaderMaterial = load("res://assets/materials/%s.tres" % m) as ShaderMaterial
		shaders_ok = shaders_ok and sm != null and sm.shader != null
	_check("water, foliage, banner and ground blend shader materials load", shaders_ok)


func _test_props() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(PROP_DIR)
	var holder := Node3D.new()
	root.add_child(holder)
	var empty: Array[String] = []
	var solid_without_body: Array[String] = []
	var decorative_with_body: Array[String] = []
	var count: int = 0
	for f: String in files:
		if not f.ends_with(".tscn"):
			continue
		count += 1
		var prop: Node3D = (load(PROP_DIR + f) as PackedScene).instantiate() as Node3D
		holder.add_child(prop)
		if prop.find_children("*", "MeshInstance3D", true, false).is_empty():
			empty.append(f)
		var kit: KitProp = prop as KitProp
		# Bushes are walk-through and wall torches hang on something solid already.
		var walk_through: bool = f in ["bush.tscn", "dry_bush.tscn", "wall_torch.tscn"]
		if kit != null and kit.collision and not walk_through \
				and kit.find_children("*", "CollisionShape3D", true, false).is_empty():
			solid_without_body.append(f)
		# The same prop as decorative must have no colliders at all.
		var deco: Node3D = (load(PROP_DIR + f) as PackedScene).instantiate() as Node3D
		if deco is KitProp:
			(deco as KitProp).collision = false
		holder.add_child(deco)
		if deco is KitProp and not deco.find_children("*", "CollisionShape3D", true, false).is_empty():
			decorative_with_body.append(f)
	await process_frame
	print("  info: %d prop scenes" % count)
	_check("there are at least 20 kit props", count >= 20)
	_check("every prop builds meshes %s" % [empty], empty.is_empty())
	_check("solid props have colliders %s" % [solid_without_body], solid_without_body.is_empty())
	_check("decorative props have no colliders %s" % [decorative_with_body], decorative_with_body.is_empty())
	var torch: Node3D = (load(PROP_DIR + "torch.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(torch)
	_check("torches have a flickering light and flame, ember and smoke particles",
		torch.find_children("*", "OmniLight3D", true, false).size() == 1
		and torch.find_children("*", "GPUParticles3D", true, false).size() == 3)
	var rock_a: KitProp = (load(PROP_DIR + "boulder.tscn") as PackedScene).instantiate() as KitProp
	var rock_b: KitProp = (load(PROP_DIR + "boulder.tscn") as PackedScene).instantiate() as KitProp
	rock_b.variant = 3
	holder.add_child(rock_a)
	holder.add_child(rock_b)
	var mesh_a: Mesh = (rock_a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var mesh_b: Mesh = (rock_b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	_check("variants give different shapes", mesh_a != mesh_b)
	holder.queue_free()
	await process_frame


func _test_effects() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var ok: bool = true
	var count: int = 0
	for f: String in DirAccess.get_files_at(EFFECT_DIR):
		if not f.ends_with(".tscn"):
			continue
		count += 1
		var fx: AmbientEffect = (load(EFFECT_DIR + f) as PackedScene).instantiate() as AmbientEffect
		holder.add_child(fx)
		ok = ok and fx.process_material != null and fx.draw_pass_1 != null and fx.amount > 0
	_check("all 5 ambient effects set themselves up (%d found)" % count, ok and count == 5)
	holder.queue_free()
	await process_frame


func _scatter_positions(scatter: PropScatter) -> Array[Vector3]:
	var list: Array[Vector3] = []
	for child: Node in scatter.get_children():
		if child.has_meta(PropScatter.META):
			list.append((child as Node3D).position)
	return list


func _make_scatter(parent: Node, seed_value: int, decorative: bool) -> PropScatter:
	var entry := ScatterEntry.new()
	entry.scene = load(PROP_DIR + "boulder.tscn")
	entry.decorative = decorative
	entry.spacing = 1.5
	var scatter := PropScatter.new()
	scatter.entries = [entry]
	scatter.scatter_seed = seed_value
	scatter.density = 0.2
	scatter.size = Vector2(20, 20)
	parent.add_child(scatter)
	return scatter


func _test_scatter() -> void:
	var zone := Node3D.new()
	root.add_child(zone)
	var exclusion := ScatterExclusion.new()
	exclusion.shape = ScatterExclusion.Shape.PATH
	exclusion.radius = 1.5
	exclusion.path_points = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0)])
	zone.add_child(exclusion)
	var marker := Marker3D.new()
	marker.position = Vector3(5, 0, 5)
	zone.add_child(marker)
	var a: PropScatter = _make_scatter(zone, 7, false)
	var b: PropScatter = _make_scatter(zone, 7, false)
	var c: PropScatter = _make_scatter(zone, 8, true)
	var pa: Array[Vector3] = _scatter_positions(a)
	var pb: Array[Vector3] = _scatter_positions(b)
	var pc: Array[Vector3] = _scatter_positions(c)
	print("  info: scatter placed %d props" % pa.size())
	_check("scatter places props", pa.size() > 10)
	_check("the same seed gives the same layout", pa == pb)
	_check("a different seed gives a different layout", pa != pc)
	a.regenerate()
	_check("regenerating keeps the layout", _scatter_positions(a) == pb)
	var in_path: bool = pa.any(func(p: Vector3) -> bool: return absf(p.z) < 1.5)
	var near_marker: bool = pa.any(func(p: Vector3) -> bool: return Vector2(p.x - 5.0, p.z - 5.0).length() < 2.0)
	_check("props avoid the exclusion path and markers", not in_path and not near_marker)
	_check("decorative scatter adds no colliders", c.find_children("*", "CollisionShape3D", true, false).is_empty()
		and not a.find_children("*", "CollisionShape3D", true, false).is_empty())
	var min_gap: float = INF
	for i: int in pa.size():
		for j: int in range(i + 1, pa.size()):
			min_gap = minf(min_gap, pa[i].distance_to(pa[j]))
	_check("props keep their spacing (closest %.2f m)" % min_gap, min_gap >= 1.1)
	zone.queue_free()
	await process_frame


func _test_biomes() -> void:
	var ok: bool = true
	for b: String in BIOMES:
		var biome: Biome = load("res://data/biomes/%s.tres" % b) as Biome
		ok = ok and biome != null and biome.ground_material != null and not biome.props.is_empty() \
			and not biome.scatter.is_empty() and biome.music_id != &"" and biome.make_environment() != null
		if biome != null:
			for e: ScatterEntry in biome.props + biome.scatter:
				ok = ok and e.scene != null
	_check("camp, shore and forest biomes load with ground, props, scatter and music", ok)


func _test_zone_template() -> void:
	var zone: Zone = (load("res://scenes/kit/zone_template.tscn") as PackedScene).instantiate() as Zone
	root.add_child(zone)
	var env: WorldEnvironment = zone.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check("the zone template creates its environment and moonlight from the biome",
		env != null and env.environment != null and zone.get_node_or_null("Moonlight") is DirectionalLight3D)
	var fx: Array[Node] = zone.find_children("*", "GPUParticles3D", false, false)
	_check("the zone spawns the biome's ambient effects", fx.size() == zone.biome.ambient_effects.size())
	var scatter: PropScatter = zone.get_node("NavigationRegion3D/PropScatter") as PropScatter
	var decor: PropScatter = zone.get_node("Decor") as PropScatter
	_check("scatters pull props from the biome (%d props, %d decor)" % [scatter.placed_count, decor.placed_count],
		scatter.placed_count > 5 and decor.placed_count > 50)
	var region: RuntimeNavBaker = zone.get_node("NavigationRegion3D") as RuntimeNavBaker
	if not region.is_navigation_ready:
		await region.navigation_ready
	var map: RID = region.get_navigation_map()
	var from: Vector3 = zone.get_node("Entries/start").global_position
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, Vector3(16, 0, 0), true)
	_check("the template's navmesh bakes and the main path is walkable end to end",
		path.size() > 1 and path[path.size() - 1].distance_to(Vector3(16, 0, 0)) < 1.0)
	zone.queue_free()
	await process_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
