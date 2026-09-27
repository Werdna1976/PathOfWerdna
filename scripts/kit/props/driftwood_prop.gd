@tool
class_name DriftwoodProp
extends KitProp
## A sea-bleached, crooked log lying on the ground, with a broken branch stub.
## Pivot: middle of the log, on the ground; the log runs along X.

@export var length: float = 2.4:
	set(value):
		length = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	add_mesh(KitMesh.cached("driftwood:%s:%d" % [length, variant], _mesh), KitMaterials.named("bark"))
	add_box_collider(Vector3(length, 0.35, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)))


func _mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 211 + 17
	var st: SurfaceTool = KitMesh.begin()
	var bleached := Color(1.15, 1.1, 1.05)
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	var segs: int = 4
	for i: int in segs + 1:
		var t: float = float(i) / segs
		points.append(Vector3(-length * 0.5 + length * t, 0.14 + rng.randf_range(-0.03, 0.05), rng.randf_range(-0.12, 0.12)))
		radii.append(lerpf(0.16, 0.07, t) * rng.randf_range(0.85, 1.1))
	KitMesh.tube(st, points, radii, 6, bleached)
	var at: Vector3 = points[1]
	KitMesh.cylinder(st, at, at + Vector3(rng.randf_range(-0.2, 0.2), 0.35, rng.randf_range(0.2, 0.35)), 0.06, 0.02, 5, bleached)
	return KitMesh.commit(st)
