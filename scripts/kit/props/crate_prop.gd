@tool
class_name CrateProp
extends KitProp
## A plank crate with a darker frame. `size` is the edge length; variants
## change the tint slightly. Pivot: centre of the base.

@export var size: float = 1.0:
	set(value):
		size = value
		_queue_rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	var tone: Color = Color(0.9, 0.85, 0.8).darkened(rng.randf() * 0.25)
	add_mesh(KitMesh.cached("crate:%s:%s" % [size, tone.to_html()], _mesh.bind(tone)), KitMaterials.named("planks"))
	add_box_collider(Vector3.ONE * size, Transform3D(Basis.IDENTITY, Vector3(0, size * 0.5, 0)))


func _mesh(tone: Color) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var s: float = size
	var h: float = s * 0.5
	var t: float = s * 0.08
	KitMesh.box(st, Vector3(0, h, 0), Vector3(s - t, s - t, s - t), tone)
	var frame: Color = tone.darkened(0.35)
	# The twelve edges of the frame.
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			KitMesh.box(st, Vector3(a * (h - t * 0.5), h, b * (h - t * 0.5)), Vector3(t, s, t), frame)
			KitMesh.box(st, Vector3(0, h + a * (h - t * 0.5), b * (h - t * 0.5)), Vector3(s, t, t), frame)
			KitMesh.box(st, Vector3(a * (h - t * 0.5), h + b * (h - t * 0.5), 0), Vector3(t, t, s), frame)
	# A diagonal brace on two sides.
	for z: float in [-1.0, 1.0]:
		var brace := Basis(Vector3(0, 0, 1), PI * 0.25)
		KitMesh.box(st, Vector3(0, h, z * (h - t * 0.3)), Vector3(s * 1.25, t * 0.9, t * 0.5), frame, brace)
	return KitMesh.commit(st)
