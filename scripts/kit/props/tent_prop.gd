@tool
class_name TentProp
extends KitProp
## An A-frame canvas tent on wooden poles, open at the front (+Z), with a
## darker doorway. Pivot: centre of the footprint, on the ground.

@export var size: Vector3 = Vector3(3.0, 2.2, 3.4):
	set(value):
		size = value
		_queue_rebuild()
@export var canvas_tint: Color = Color(0.5, 0.4, 0.28):
	set(value):
		canvas_tint = value
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var key: String = "tent:%s:%s:%d" % [size, canvas_tint.to_html(), variant]
	add_mesh(KitMesh.cached(key + ":canvas", _canvas), KitMaterials.named("cloth"))
	add_mesh(KitMesh.cached(key + ":poles", _poles), KitMaterials.named("bark"))
	# A slightly smaller box keeps the navmesh hugging the canvas.
	add_box_collider(Vector3(size.x * 0.9, size.y, size.z * 0.95), Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)))


func _canvas() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var w: float = size.x * 0.5
	var h: float = size.y
	var d: float = size.z * 0.5
	var sag: float = h * 0.06
	var inside := Vector3(0, h * 0.35, 0)
	var ridge_back := Vector3(0, h, -d)
	var ridge_front := Vector3(0, h, d)
	var ridge_mid := Vector3(0, h - sag, 0)
	# Each roof side in two panels so the ridge sags a little in the middle.
	for s: float in [-1.0, 1.0]:
		var eave_back := Vector3(s * w, 0.05, -d)
		var eave_front := Vector3(s * w, 0.05, d)
		var eave_mid := Vector3(s * w * 1.03, 0.05, 0)
		var shade: Color = canvas_tint if s > 0.0 else canvas_tint.darkened(0.12)
		KitMesh.quad(st, eave_back, eave_mid, ridge_mid, ridge_back, shade, inside)
		KitMesh.quad(st, eave_mid, eave_front, ridge_front, ridge_mid, shade.darkened(0.05), inside)
	# Closed back wall, and a front with a dark open doorway.
	KitMesh.tri(st, Vector3(-w, 0.05, -d), Vector3(w, 0.05, -d), ridge_back, canvas_tint.darkened(0.2), inside)
	var door_w: float = w * 0.45
	KitMesh.tri(st, Vector3(-w, 0.05, d), Vector3(-door_w, 0.05, d), Vector3(-door_w * 0.25, h * 0.75, d), canvas_tint.darkened(0.15), inside)
	KitMesh.tri(st, Vector3(w, 0.05, d), Vector3(door_w, 0.05, d), Vector3(door_w * 0.25, h * 0.75, d), canvas_tint.darkened(0.15), inside)
	KitMesh.tri(st, Vector3(-w, 0.05, d), Vector3(-door_w * 0.25, h * 0.75, d), ridge_front, canvas_tint.darkened(0.15), inside)
	KitMesh.tri(st, Vector3(w, 0.05, d), Vector3(door_w * 0.25, h * 0.75, d), ridge_front, canvas_tint.darkened(0.15), inside)
	KitMesh.tri(st, Vector3(-door_w * 0.25, h * 0.75, d), Vector3(door_w * 0.25, h * 0.75, d), ridge_front, canvas_tint.darkened(0.15), inside)
	# The dark interior seen through the door.
	KitMesh.tri(st, Vector3(-door_w, 0.05, d - 0.05), Vector3(door_w, 0.05, d - 0.05), Vector3(0, h * 0.75, d - 0.05),
		Color(0.03, 0.025, 0.02), Vector3(0, h * 0.3, d + 1.0))
	return KitMesh.commit(st)


func _poles() -> ArrayMesh:
	var st: SurfaceTool = KitMesh.begin()
	var h: float = size.y
	var d: float = size.z * 0.5
	var c := Color(0.7, 0.6, 0.5)
	KitMesh.cylinder(st, Vector3(0, 0, d + 0.05), Vector3(0, h + 0.25, d + 0.05), 0.05, 0.04, 5, c)
	KitMesh.cylinder(st, Vector3(0, 0, -d - 0.05), Vector3(0, h + 0.25, -d - 0.05), 0.05, 0.04, 5, c)
	KitMesh.cylinder(st, Vector3(0, h + 0.02, -d - 0.1), Vector3(0, h + 0.02, d + 0.1), 0.035, 0.035, 5, c)
	# Guy-rope pegs.
	for s: float in [-1.0, 1.0]:
		for z: float in [-d * 0.7, d * 0.7]:
			KitMesh.cylinder(st, Vector3(s * (size.x * 0.5 + 0.4), 0, z), Vector3(s * (size.x * 0.5 + 0.38), 0.2, z), 0.03, 0.02, 4, c)
	return KitMesh.commit(st)
