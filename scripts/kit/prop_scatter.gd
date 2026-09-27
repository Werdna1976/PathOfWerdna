@tool
class_name PropScatter
extends Node3D
## Fills a rectangle (`size`, centred on this node) or a polygon with props
## picked by weight from its entries or from the zone's Biome.
##
## - Deterministic: the same seed and settings always give the same layout,
##   in the editor and in game. Change `scatter_seed` for a different layout.
## - Avoids ScatterExclusion areas, every Marker3D in the zone (entries,
##   spawn points), ZoneExits, and nodes in `avoid_groups`.
## - Decorative entries get no colliders. For props that should block
##   movement, put the scatter under the NavigationRegion3D so the navmesh
##   bakes around them.
## Placed props are generated at load and never saved into the scene.

const META: StringName = &"scatter_generated"

enum Source { OWN, BIOME_PROPS, BIOME_SCATTER }

@export_tool_button("Regenerate", "Reload") var regenerate_button: Callable = regenerate

## Where the entries come from: this node's list, or the zone biome's props or scatter.
@export var source: Source = Source.OWN:
	set(value):
		source = value
		_queue_regenerate()
@export var entries: Array[ScatterEntry] = []:
	set(value):
		entries = value
		_queue_regenerate()
@export var scatter_seed: int = 1:
	set(value):
		scatter_seed = value
		_queue_regenerate()
## Props per square metre (before exclusions and spacing reject some).
@export var density: float = 0.05:
	set(value):
		density = value
		_queue_regenerate()
@export var size: Vector2 = Vector2(20, 20):
	set(value):
		size = value
		_queue_regenerate()
## Optional local X/Z polygon; when set it replaces the rectangle.
@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		_queue_regenerate()
@export var max_count: int = 300:
	set(value):
		max_count = value
		_queue_regenerate()
## Clear radius kept around markers, exits and avoided nodes.
@export var marker_margin: float = 2.0:
	set(value):
		marker_margin = value
		_queue_regenerate()
@export var avoid_groups: Array[StringName] = [&"vendors"]:
	set(value):
		avoid_groups = value
		_queue_regenerate()

var placed_count: int = 0
var _pending: bool = false


func _ready() -> void:
	regenerate()


func _queue_regenerate() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		regenerate.call_deferred()


func regenerate() -> void:
	_pending = false
	for child: Node in get_children():
		if child.has_meta(META):
			remove_child(child)
			child.free()
	placed_count = 0
	var list: Array[ScatterEntry] = _entries()
	if list.is_empty():
		return
	var weights: Array[float] = []
	for e: ScatterEntry in list:
		weights.append(e.weight if e.scene != null else 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var bounds: Rect2 = _bounds()
	var area: float = _area(bounds)
	var target: int = mini(int(area * density), max_count)
	var blockers: Array = _blockers()
	var exclusions: Array[ScatterExclusion] = _exclusions()
	var taken: Array[Vector3] = []  # x, z, spacing
	var attempts: int = 0
	while placed_count < target and attempts < target * 10:
		attempts += 1
		# Draw every random number first so each attempt consumes the same amount.
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var entry: ScatterEntry = list[_pick(rng, weights)]
		var yaw: float = rng.randf() * TAU
		var scale_value: float = rng.randf_range(entry.scale_min, entry.scale_max)
		var tilt_x: float = deg_to_rad(rng.randf_range(-entry.tilt, entry.tilt))
		var tilt_z: float = deg_to_rad(rng.randf_range(-entry.tilt, entry.tilt))
		var variant_index: int = rng.randi_range(0, entry.variants - 1)
		if polygon.size() >= 3 and not Geometry2D.is_point_in_polygon(p, polygon):
			continue
		var world: Vector3 = global_transform * Vector3(p.x, 0.0, p.y)
		if _blocked(world, entry.spacing * 0.5, blockers, exclusions):
			continue
		var crowded: bool = false
		for t: Vector3 in taken:
			if Vector2(t.x, t.y).distance_to(p) < (t.z + entry.spacing * scale_value) * 0.5:
				crowded = true
				break
		if crowded:
			continue
		taken.append(Vector3(p.x, p.y, entry.spacing * scale_value))
		var basis := Basis(Vector3.UP, yaw if entry.random_yaw else 0.0) * Basis(Vector3.RIGHT, tilt_x) * Basis(Vector3.BACK, tilt_z)
		_place(entry, Transform3D(basis.scaled(Vector3.ONE * scale_value), Vector3(p.x, 0.0, p.y)), variant_index)
		placed_count += 1


func _place(entry: ScatterEntry, xform: Transform3D, variant_index: int) -> void:
	var node: Node3D = entry.scene.instantiate() as Node3D
	for key: Variant in entry.properties:
		node.set(StringName(str(key)), entry.properties[key])
	if node is KitProp:
		var prop: KitProp = node as KitProp
		prop.variant = variant_index
		if entry.decorative:
			prop.collision = false
	node.transform = xform
	node.set_meta(META, true)
	add_child(node)
	if entry.decorative and not node is KitProp:
		for body: Node in node.find_children("*", "CollisionObject3D", true, false):
			(body as CollisionObject3D).collision_layer = 0


func _entries() -> Array[ScatterEntry]:
	if source == Source.OWN:
		return entries
	var zone: Zone = Zone.of(self)
	if zone == null or zone.biome == null:
		return []
	return zone.biome.props if source == Source.BIOME_PROPS else zone.biome.scatter


func _bounds() -> Rect2:
	if polygon.size() < 3:
		return Rect2(-size * 0.5, size)
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		r = r.expand(p)
	return r


func _area(bounds: Rect2) -> float:
	if polygon.size() < 3:
		return size.x * size.y
	var twice: float = 0.0
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		twice += a.x * b.y - b.x * a.y
	return absf(twice) * 0.5 if twice != 0.0 else bounds.get_area()


## The node whose descendants count as this scatter's zone.
func _zone_root() -> Node:
	var zone: Zone = Zone.of(self)
	if zone != null:
		return zone
	if owner != null:
		return owner
	var n: Node = self
	while n.get_parent() != null and not (n.get_parent() is Window):
		n = n.get_parent()
	return n


func _exclusions() -> Array[ScatterExclusion]:
	var root: Node = _zone_root()
	var list: Array[ScatterExclusion] = []
	for node: Node in get_tree().get_nodes_in_group(ScatterExclusion.GROUP):
		if root.is_ancestor_of(node):
			list.append(node as ScatterExclusion)
	return list


## [position, radius] of every marker, exit and avoided node in the zone.
func _blockers() -> Array:
	var root: Node = _zone_root()
	var list: Array = []
	for node: Node in root.find_children("*", "Marker3D", true, false):
		list.append([(node as Node3D).global_position, marker_margin])
	for node: Node in root.find_children("*", "Area3D", true, false):
		if node is ZoneExit:
			var exit: ZoneExit = node as ZoneExit
			list.append([exit.global_position, maxf(exit.size.x, exit.size.z) * 0.5 + marker_margin])
	for group: StringName in avoid_groups:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node3D and root.is_ancestor_of(node):
				list.append([(node as Node3D).global_position, marker_margin])
	return list


func _blocked(world: Vector3, margin: float, blockers: Array, exclusions: Array[ScatterExclusion]) -> bool:
	for b: Array in blockers:
		var at: Vector3 = b[0]
		if Vector2(at.x - world.x, at.z - world.z).length() < b[1] + margin:
			return true
	for ex: ScatterExclusion in exclusions:
		if ex.excludes(world, margin):
			return true
	return false


func _pick(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1
