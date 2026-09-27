@tool
class_name BarrelProp
extends KitProp
## A bulging wooden barrel with iron bands. Pivot: centre of the base.

@export var height: float = 1.1:
	set(value):
		height = value
		_queue_rebuild()


func _build(rng: RandomNumberGenerator) -> void:
	var tone: Color = Color(0.85, 0.75, 0.65).darkened(rng.randf() * 0.2)
	var key: String = "barrel:%s:%s" % [height, tone.to_html()]
	add_mesh(KitMesh.cached(key, _staves.bind(tone)), KitMaterials.named("planks"))
	add_mesh(KitMesh.cached("barrel:bands:%s" % height, _bands), KitMaterials.iron())
	add_cylinder_collider(height * 0.4, height)


func _staves(tone: Color) -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var r: float = height * 0.36
	var bulge: float = height * 0.43
	var points: Array[Vector3] = [Vector3.ZERO, Vector3(0, height * 0.3, 0), Vector3(0, height * 0.7, 0), Vector3(0, height, 0)]
	var radii: Array[float] = [r, bulge, bulge, r]
	KitMesh.tube(st, points, radii, 12, tone)
	return KitMesh.commit(st)


func _bands() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var r: float = height * 0.36
	var bulge: float = height * 0.43
	for y: float in [0.08, 0.92]:
		KitMesh.cylinder(st, Vector3(0, height * y - 0.03, 0), Vector3(0, height * y + 0.03, 0), r * 1.03 + (bulge - r) * 0.25, r * 1.03 + (bulge - r) * 0.25, 12, Color.WHITE, false, false)
	for y: float in [0.34, 0.66]:
		KitMesh.cylinder(st, Vector3(0, height * y - 0.03, 0), Vector3(0, height * y + 0.03, 0), bulge * 1.02, bulge * 1.02, 12, Color.WHITE, false, false)
	return KitMesh.commit(st)
