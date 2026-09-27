@tool
class_name WreckProp
extends KitProp
## The broken hull of a small ship: a keel, curved ribs (some snapped off),
## a few remaining hull planks on one side, and a fallen mast.
## `broken_mast` adds the mast lying beside it. The hull runs along X.
## Pivot: centre of the hull, on the ground.

@export var length: float = 7.0:
	set(value):
		length = value
		_queue_rebuild()
@export var broken_mast: bool = true:
	set(value):
		broken_mast = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	add_mesh(KitMesh.cached("wreck:%s:%s:%d" % [length, broken_mast, variant], _mesh), KitMaterials.named("planks"))
	add_box_collider(Vector3(length * 0.95, 1.6, 2.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	if broken_mast:
		add_box_collider(Vector3(length * 0.7, 0.5, 0.5), Transform3D(Basis(Vector3.UP, 0.35), Vector3(length * 0.15, 0.25, 2.2)))


func _mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 733 + 29
	var st: SurfaceTool = KitMesh.begin()
	var wet := Color(0.7, 0.62, 0.55)
	var half: float = length * 0.5
	# Keel, half buried.
	KitMesh.box(st, Vector3(0, 0.12, 0), Vector3(length, 0.3, 0.3), wet.darkened(0.2))
	# Ribs: arcs up either side; the port side (-Z) is broken on some.
	var ribs: int = int(length / 0.9)
	for i: int in ribs:
		var x: float = -half + 0.5 + (length - 1.0) * i / maxf(ribs - 1.0, 1.0)
		var taper: float = 1.0 - pow(absf(x) / half, 2.0) * 0.6
		for side: float in [-1.0, 1.0]:
			if side < 0.0 and rng.randf() < 0.45:
				continue
			var pts: Array[Vector3] = []
			var radii: Array[float] = []
			var segments: int = 4 if side > 0.0 else rng.randi_range(2, 4)
			for s: int in segments + 1:
				var a: float = float(s) / 4.0 * PI * 0.5
				pts.append(Vector3(x, 0.15 + sin(a) * 1.6 * taper, side * (0.15 + (1.0 - cos(a)) * 1.2 * taper + sin(a) * 0.1)))
				radii.append(0.07)
			KitMesh.tube(st, pts, radii, 5, wet)
	# Hull planks along the starboard side (+Z), with gaps.
	for p: int in 4:
		if rng.randf() < 0.25:
			continue
		var a: float = (0.2 + p * 0.22) * PI * 0.5
		var y: float = 0.15 + sin(a) * 1.6 * 0.9
		var z: float = 0.15 + (1.0 - cos(a)) * 1.2 * 0.9 + 0.08
		var plank_len: float = length * rng.randf_range(0.55, 0.85)
		var tilt := Basis(Vector3.RIGHT, -a * 0.9)
		KitMesh.box(st, Vector3(rng.randf_range(-0.5, 0.5), y, z), Vector3(plank_len, 0.35, 0.06), wet.darkened(0.1 * p), tilt)
	# Stem post at the bow.
	KitMesh.cylinder(st, Vector3(half, 0.1, 0), Vector3(half + 0.4, 1.9, 0), 0.12, 0.09, 6, wet)
	if broken_mast:
		var yaw := Basis(Vector3.UP, 0.35)
		KitMesh.cylinder(st, Vector3(length * 0.15, 0.2, 2.2) + yaw * Vector3(-length * 0.35, 0, 0),
			Vector3(length * 0.15, 0.2, 2.2) + yaw * Vector3(length * 0.35, 0, 0), 0.16, 0.1, 7, wet.darkened(0.1))
	return KitMesh.commit(st)
