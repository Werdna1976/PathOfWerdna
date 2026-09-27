@tool
class_name MarketStallProp
extends KitProp
## A market stall: a plank counter along the front (+Z), four posts and a
## slanted, striped canvas awning, with a few goods on the counter. A vendor
## stands behind it (at about -Z * depth * 0.4). Only the counter blocks movement.

@export var width: float = 3.0:
	set(value):
		width = value
		_queue_rebuild()
@export var depth: float = 1.8:
	set(value):
		depth = value
		_queue_rebuild()
@export var awning_color: Color = Color(0.45, 0.12, 0.08):
	set(value):
		awning_color = value
		_queue_rebuild()
@export var stripe_color: Color = Color(0.7, 0.62, 0.45):
	set(value):
		stripe_color = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "stall:%s:%s:%s:%s:%d" % [width, depth, awning_color.to_html(), stripe_color.to_html(), variant]
	add_mesh(KitMesh.cached(key + ":wood", _wood), KitMaterials.named("planks"))
	add_mesh(KitMesh.cached(key + ":awning", _awning), KitMaterials.named("cloth"))
	add_mesh(KitMesh.cached(key + ":goods", _goods), KitMaterials.flat(Color(1, 1, 1), 0.7))
	add_box_collider(Vector3(width, 1.0, 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, depth * 0.5 - 0.35)))


func _wood() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var w: float = width * 0.5
	var d: float = depth * 0.5
	var c := Color(0.85, 0.78, 0.7)
	# Counter: a top, a front panel and two legs.
	KitMesh.box(st, Vector3(0, 0.95, d - 0.35), Vector3(width, 0.08, 0.7), c)
	KitMesh.box(st, Vector3(0, 0.47, d - 0.05), Vector3(width - 0.1, 0.9, 0.06), c.darkened(0.15))
	# Posts: taller at the back so the awning slopes forward.
	for x: float in [-w + 0.08, w - 0.08]:
		KitMesh.box(st, Vector3(x, 1.25, d - 0.05), Vector3(0.12, 2.5, 0.12), c.darkened(0.25))
		KitMesh.box(st, Vector3(x, 1.45, -d + 0.05), Vector3(0.12, 2.9, 0.12), c.darkened(0.25))
	return KitMesh.commit(st)


func _awning() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var w: float = width * 0.5 + 0.1
	var d: float = depth * 0.5 + 0.3
	var stripes: int = 6
	var inside := Vector3(0, 0, 0)
	for i: int in stripes:
		var x0: float = -w + width * (1.0 + 0.2 / width) * i / stripes
		var x1: float = -w + width * (1.0 + 0.2 / width) * (i + 1) / stripes
		var c: Color = awning_color if i % 2 == 0 else stripe_color
		KitMesh.quad(st, Vector3(x0, 2.9, -d), Vector3(x1, 2.9, -d), Vector3(x1, 2.45, d), Vector3(x0, 2.45, d), c, inside)
		# Scalloped front valance.
		KitMesh.tri(st, Vector3(x0, 2.45, d), Vector3(x1, 2.45, d), Vector3((x0 + x1) * 0.5, 2.2, d), c.darkened(0.1), Vector3(0, 2.4, 0))
	return KitMesh.commit(st)


func _goods() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 101 + 9
	var st: SurfaceTool = KitMesh.begin()
	var d: float = depth * 0.5
	var x: float = -width * 0.5 + 0.35
	while x < width * 0.5 - 0.3:
		var kind: int = rng.randi_range(0, 2)
		var pos := Vector3(x, 1.0, d - 0.35 + rng.randf_range(-0.12, 0.12))
		match kind:
			0:  # clay jar
				KitMesh.tube(st, [pos, pos + Vector3(0, 0.12, 0), pos + Vector3(0, 0.26, 0), pos + Vector3(0, 0.32, 0)] as Array[Vector3],
					[0.08, 0.13, 0.08, 0.06] as Array[float], 7, Color(0.45, 0.25, 0.15))
			1:  # small chest
				KitMesh.box(st, pos + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.2), Color(0.3, 0.2, 0.12))
			_:  # bundle of cloth
				KitMesh.blob(st, pos + Vector3(0, 0.07, 0), Vector3(0.18, 0.08, 0.14), rng.randi(), 0.2, Color(0.35, 0.3, 0.45), 1)
		x += rng.randf_range(0.35, 0.55)
	return KitMesh.commit(st)
