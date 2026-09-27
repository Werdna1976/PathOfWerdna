@tool
class_name SackProp
extends KitProp
## A lumpy tied sack of grain or loot. Small, so decorative by default.

@export var size: float = 0.55:
	set(value):
		size = value
		_queue_rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	var tone: Color = Color(0.85, 0.78, 0.62).darkened(rng.randf() * 0.25)
	add_mesh(KitMesh.cached("sack:%s:%d" % [size, variant], _mesh.bind(tone)), KitMaterials.named("cloth"))
	add_cylinder_collider(size * 0.45, size)


func _mesh(tone: Color) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	KitMesh.blob(st, Vector3(0, size * 0.4, 0), Vector3(size * 0.45, size * 0.42, size * 0.4), variant * 13 + 1, 0.25, tone, 1, -0.75, 0.04)
	KitMesh.cylinder(st, Vector3(0, size * 0.72, 0), Vector3(0, size * 0.95, 0), size * 0.12, size * 0.2, 6, tone.darkened(0.1))
	KitMesh.cylinder(st, Vector3(0, size * 0.76, 0), Vector3(0, size * 0.82, 0), size * 0.14, size * 0.14, 6, Color(0.35, 0.28, 0.18), false, false)
	return KitMesh.commit(st)
