@tool
class_name GrassProp
extends KitProp
## A clump of grass blades (or reeds, with `height` up) that sway in the wind.
## Decorative: never has a collider.

@export var height: float = 0.45:
	set(value):
		height = value
		_queue_rebuild()
@export var blades: int = 12:
	set(value):
		blades = value
		_queue_rebuild()
@export var base_color: Color = Color(0.08, 0.1, 0.05):
	set(value):
		base_color = value
		_queue_rebuild()
@export var tip_color: Color = Color(0.3, 0.32, 0.16):
	set(value):
		tip_color = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "grass:%s:%d:%d:%s:%s" % [height, blades, variant, base_color.to_html(), tip_color.to_html()]
	add_mesh(KitMesh.cached(key, _mesh), KitMaterials.named("foliage"), Transform3D.IDENTITY, false)


func _mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 389 + blades
	var st: SurfaceTool = KitMesh.begin()
	for i: int in blades:
		var ang: float = rng.randf() * TAU
		var root := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.0, 0.18)
		var h: float = height * rng.randf_range(0.6, 1.15)
		var lean := Vector3(cos(ang), 0, sin(ang)) * h * rng.randf_range(0.15, 0.45)
		var side := Vector3(-sin(ang), 0, cos(ang)) * rng.randf_range(0.02, 0.035)
		var tip: Vector3 = root + Vector3(0, h, 0) + lean
		# Normals point up so blades catch light like the ground around them.
		for v: Array in [[root - side, base_color, Vector2(0, 1)], [tip, tip_color, Vector2(0.5, 0)],
				[root + side, base_color, Vector2(1, 1)]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.set_uv(v[2])
			st.add_vertex(v[0])
	st.generate_tangents()
	return st.commit()
