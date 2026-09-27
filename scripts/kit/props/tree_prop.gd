@tool
class_name TreeProp
extends KitProp
## Low-poly trees:
## - DEAD: a bare, gnarled trunk with crooked branches.
## - PINE: a straight trunk with stacked dark cones that sway in the wind.
## Pivot: the base of the trunk. Only the trunk has a collider.

enum Kind { DEAD, PINE }

@export var kind: Kind = Kind.DEAD:
	set(value):
		kind = value
		_queue_rebuild()
@export var height: float = 4.5:
	set(value):
		height = value
		_queue_rebuild()
## Bark tint, e.g. bleached grey near the sea.
@export var bark_tint: Color = Color(0.8, 0.75, 0.68):
	set(value):
		bark_tint = value
		_queue_rebuild()
@export var foliage_tint: Color = Color(0.13, 0.2, 0.12):
	set(value):
		foliage_tint = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "tree:%d:%s:%d:%s:%s" % [kind, height, variant, bark_tint.to_html(), foliage_tint.to_html()]
	var trunk_r: float = height * 0.045
	if kind == Kind.DEAD:
		add_mesh(KitMesh.cached(key, _dead_mesh), KitMaterials.named("bark"))
	else:
		add_mesh(KitMesh.cached(key + ":trunk", _pine_trunk), KitMaterials.named("bark"))
		add_mesh(KitMesh.cached(key + ":leaves", _pine_leaves), KitMaterials.named("foliage"))
		trunk_r = height * 0.035
	add_cylinder_collider(trunk_r + 0.15, height * 0.6)


func _dead_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 11
	var st: SurfaceTool = KitMesh.begin()
	var base_r: float = height * 0.045
	# Trunk: a few bent segments.
	var points: Array[Vector3] = [Vector3.ZERO]
	var radii: Array[float] = [base_r * 1.3]
	var segs: int = 5
	for i: int in range(1, segs + 1):
		var t: float = float(i) / segs
		var prev: Vector3 = points[-1]
		points.append(prev + Vector3(rng.randf_range(-0.25, 0.25), height / segs, rng.randf_range(-0.25, 0.25)))
		radii.append(base_r * (1.0 - t * 0.85))
	KitMesh.tube(st, points, radii, 7, bark_tint)
	# Roots flaring at the base.
	for i: int in 4:
		var ang: float = TAU * i / 4.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		KitMesh.cylinder(st, Vector3(0, height * 0.12, 0), dir * base_r * 3.0 + Vector3(0, -0.05, 0), base_r * 0.6, base_r * 0.15, 5, bark_tint.darkened(0.1))
	# Branches from the upper trunk, each with a twig or two.
	var branch_count: int = rng.randi_range(4, 6)
	for b: int in branch_count:
		var at: int = rng.randi_range(2, segs - 1)
		var start: Vector3 = points[at]
		var ang: float = rng.randf() * TAU
		var out := Vector3(cos(ang), rng.randf_range(0.5, 1.1), sin(ang)).normalized()
		var length: float = height * rng.randf_range(0.2, 0.35)
		_branch(st, rng, start, out, length, radii[at] * 0.6, 2)
	return KitMesh.commit(st)


func _branch(st: SurfaceTool, rng: RandomNumberGenerator, start: Vector3, dir: Vector3, length: float, radius: float, depth: int) -> void:
	var mid: Vector3 = start + dir * length * 0.5 + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.1, 0.1))
	var tip: Vector3 = start + dir * length + Vector3(0, rng.randf_range(-0.1, 0.2), 0)
	KitMesh.tube(st, [start, mid, tip] as Array[Vector3], [radius, radius * 0.6, radius * 0.15] as Array[float], 5, bark_tint)
	if depth <= 0:
		return
	for i: int in rng.randi_range(1, 2):
		var twist := Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.6), rng.randf_range(-0.8, 0.8))
		_branch(st, rng, mid, (dir + twist).normalized(), length * 0.5, radius * 0.45, depth - 1)


func _pine_trunk() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.cylinder(st, Vector3.ZERO, Vector3(0, height * 0.9, 0), height * 0.035, height * 0.01, 7, bark_tint)
	return KitMesh.commit(st)


func _pine_leaves() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 104729 + 3
	var st: SurfaceTool = KitMesh.begin()
	var tiers: int = 4
	for i: int in tiers:
		var t: float = float(i) / tiers
		var base_y: float = height * (0.25 + t * 0.55)
		var r: float = height * 0.28 * (1.0 - t * 0.7) * rng.randf_range(0.9, 1.1)
		var tip_y: float = base_y + height * 0.32
		var c: Color = foliage_tint.lerp(foliage_tint.lightened(0.25), t).darkened(rng.randf() * 0.15)
		KitMesh.cylinder(st, Vector3(0, base_y, 0), Vector3(rng.randf_range(-0.05, 0.05), tip_y, 0), r, 0.0, 8, c, true, false, rng.randf())
	return KitMesh.commit(st)
