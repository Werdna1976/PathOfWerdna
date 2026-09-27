@tool
class_name PalisadeProp
extends KitProp
## A straight run of sharpened logs held by a cross beam on the inner side
## (-Z). The segment spans `length` metres along X, centred on the pivot, so
## segments can be chained end to end or rotated around a camp.

@export var length: float = 6.0:
	set(value):
		length = value
		_queue_rebuild()
@export var height: float = 2.6:
	set(value):
		height = value
		_queue_rebuild()
@export var log_radius: float = 0.17:
	set(value):
		log_radius = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "palisade:%s:%s:%s:%d" % [length, height, log_radius, variant]
	add_mesh(KitMesh.cached(key, _mesh), KitMaterials.named("bark"))
	add_box_collider(Vector3(length, height, log_radius * 2.6), Transform3D(Basis.IDENTITY, Vector3(0, height * 0.5, 0)))


func _mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 4099 + int(length * 10.0)
	var st: SurfaceTool = KitMesh.begin()
	var count: int = maxi(1, int(round(length / (log_radius * 2.0))))
	var step: float = length / count
	for i: int in count:
		var x: float = -length * 0.5 + step * (i + 0.5)
		var h: float = height + rng.randf_range(-0.25, 0.2)
		var lean := Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.05, 0.05))
		var r: float = log_radius * rng.randf_range(0.85, 1.05)
		var c: Color = Color(0.75, 0.66, 0.56).darkened(rng.randf() * 0.25)
		var base := Vector3(x, -0.1, 0)
		var shaft_top: Vector3 = base + Vector3(0, h - r * 2.5, 0) + lean
		KitMesh.cylinder(st, base, shaft_top, r, r * 0.95, 6, c, false, false, rng.randf())
		KitMesh.cylinder(st, shaft_top, shaft_top + Vector3(0, r * 3.0, 0) + lean, r * 0.95, 0.0, 6, c.lightened(0.1), false, false, rng.randf())
	# Two cross beams lashed on the inside.
	for y: float in [height * 0.3, height * 0.72]:
		KitMesh.cylinder(st, Vector3(-length * 0.5, y, -log_radius * 1.1), Vector3(length * 0.5, y + rng.randf_range(-0.05, 0.05), -log_radius * 1.1),
			log_radius * 0.55, log_radius * 0.55, 6, Color(0.6, 0.52, 0.44))
	return KitMesh.commit(st)
