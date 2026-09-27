@tool
class_name BushProp
extends KitProp
## A low bush made of a few lumpy leaf clusters that sway in the wind.
## `dry` makes a brown, thorny-looking scrub bush. Bushes never block movement.

@export var size: float = 0.8:
	set(value):
		size = value
		_queue_rebuild()
@export var dry: bool = false:
	set(value):
		dry = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "bush:%s:%s:%d" % [size, dry, variant]
	add_mesh(KitMesh.cached(key, _mesh), KitMaterials.named("foliage"))


func _mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 613 + (7 if dry else 0)
	var st: SurfaceTool = KitMesh.begin()
	# Vertex colours are linear, so dark foliage needs small values.
	var base: Color = Color(0.07, 0.045, 0.022) if dry else Color(0.025, 0.05, 0.02)
	var count: int = rng.randi_range(3, 5)
	for i: int in count:
		var ang: float = rng.randf() * TAU
		var off := Vector3(cos(ang), 0, sin(ang)) * size * rng.randf_range(0.0, 0.5)
		var r: float = size * rng.randf_range(0.45, 0.7)
		var c: Color = base * rng.randf_range(0.8, 1.8)
		KitMesh.blob(st, off + Vector3(0, r * 0.55, 0), Vector3(r, r * 0.75, r), rng.randi(), 0.45, c, 1, -0.6, 0.05)
	return KitMesh.commit(st)
